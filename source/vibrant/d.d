
module vibrant.d;

import std.algorithm;
import std.conv;
import std.functional;
import std.traits;
import std.typecons;
import std.typetuple;

public import vibe.d;

private
{

	/++
	 + An internal throwable type used to halt execution.
	 ++/
	class HaltThrowable : Throwable
	{

		/++
		 + The status code sent in the response.
		 ++/
		private int status;

		/++
		 + Constructs a HaltThrowable.
		 +
		 + Params:
		 +     status = The status code to send to the client.
		 +     msg    = A message body to include in the response.
		 ++/
		this(int status, string msg)
		{
			super(msg);
			this.status = status;
		}

	}

	/++
	 + The URL router that manages Vibrant's routes.
	 ++/
	URLRouter router;

	/++
	 + A saved listener, used to stop and restart the server.
	 ++/
	Nullable!HTTPListener savedListener;

	/++
	 + Filter callbacks invoked before a route handler.
	 ++/
	VoidCallback[][string] beforeCallbacks;

	/++
	 + Filter callbacks invoked after a route handler.
	 ++/
	VoidCallback[][string] afterCallbacks;

	/++
	 + A table storing exception callbacks.
	 ++/
	ExceptionCallback[ClassInfo] exceptionCallbacks;

	/++
	 + Response callback with no return value.
	 ++/
	alias VoidCallback = void delegate(
		HTTPServerRequest, HTTPServerResponse
	);

	/++
	 + Response callback with a string return value.
	 ++/
	alias StringCallback = string delegate(
		HTTPServerRequest, HTTPServerResponse
	);

	/++
	 + Response callback for catching exceptions.
	 ++/
	alias ExceptionCallback = void delegate(
		Throwable, HTTPServerRequest, HTTPServerResponse
	);

	/++
	 + Transformer callback for turning objects to strings.
	 ++/
	alias TransformerCallback = string delegate(
		Object
	);
}

/++
 + Module initializer.
 ++/
shared static this()
{
	router = new URLRouter;

	// Preload the HaltThrowable handler.
	Catch(HaltThrowable.classinfo, (t, req, res) {
		// Get the HaltThrowable object.
		HaltThrowable ht = cast(HaltThrowable)t;

		// Check for a status code.
		if(ht.status != 0)
		{
			res.statusCode = ht.status;
		}

		// Write the response body.
		res.writeBody(ht.msg);
	});
}

/++
 + Matches a path and method type using a string callback.
 +
 + Params:
 +     method      = The HTTP method matched.
 +     path        = The path assigned to this route.
 +     contentType = The content type of the response.
 +     callback    = A string callback handler for the route.
 ++/
private void Match(
	HTTPMethod method, string path, string contentType,
	StringCallback callback)
{
	router.match(method, path, (req, res) {
		try
		{
			// Invoke before-filters.
			Filter(beforeCallbacks, path, req, res);

			string result = callback(req, res);

			// Invoke after-filters.
			Filter(afterCallbacks, path, req, res);

			if(contentType !is null)
			{
				// Override the content type if given one.
				res.writeBody(result, contentType);
			}
			else
			{
				// Just send the response.
				res.writeBody(result);
			}
		}
		catch(Throwable t)
		{
			Handle(t, req, res);
		}
	});
}

/++
 + Matches a path and method type using a typed callback.
 +
 + Params:
 +     method      = The HTTP method matched.
 +     path        = The path assigned to this route.
 +     contentType = The content type of the response.
 +     callback    = A typed callback handler for the route.
 +     transformer = A transformer that converts the handler's output to a string.
 ++/
private void Match(T)(
	HTTPMethod method, string path, string contentType,
	T delegate(HTTPServerRequest, HTTPServerResponse) callback,
	string delegate(T) transformer)
{
	router.match(method, path, (req, res) {
		try
		{
			// Invoke before-filters.
			Filter(beforeCallbacks, path, req, res);

			// Transform the result into a string.
			string result = transformer(callback(req, res));

			// Invoke after-filters.
			Filter(afterCallbacks, path, req, res);

			if(contentType !is null)
			{
				// Override the content type if given one.
				res.writeBody(result, contentType);
			}
			else
			{
				// Just send the response.
				res.writeBody(result);
			}
		}
		catch(Throwable t)
		{
			Handle(t, req, res);
		}
	});
}

/++
 + Matches a filter to a path and invokes matched callbacks.
 +
 + Params:
 +     table = The table of callbacks to scan.
 +     path  = The path to be matched.
 +     req   = The server request object.
 +     res   = The server response object. 
 ++/
private void Filter(
	ref VoidCallback[][string] table, string path,
	HTTPServerRequest req, HTTPServerResponse res)
{
	foreach(callbackPath, callbacks; table)
	{
		bool matches = true;

		if(callbackPath !is null)
		{
			// Substitue wildwards.
			import std.array : replace;
			string pattern = callbackPath.replace("*", ".*?");

			// Check the pattern for a match.
			import std.regex : matchFirst;
			matches = !path.matchFirst(pattern).empty;
		}

		if(matches)
		{
			// Invoke matched callbacks.
			foreach(callback; callbacks)
			{
				callback(req, res);
			}
		}
	}
}

// TODO : This is probably a hack.
extern(C) int _d_isbaseof(ClassInfo oc, ClassInfo c);

/++
 + Matches a throwable type and invokes its handler.
 +
 + Params:
 +     t   = The throwable being matched.
 +     req = The server request object.
 +     res = The server response object.
 ++/
private void Handle(Throwable t, HTTPServerRequest req, HTTPServerResponse res)
{
	foreach(typeinfo, handler; exceptionCallbacks)
	{
		if(_d_isbaseof(t.classinfo, typeinfo))
		{
			// Forward error to handler.
			handler(t, req, res);
			return;
		}
	}

	// Rethrow.
	throw t;
}

/++
 + Starts the server on the given port and addresses.
 + Defaults to port 8085, binding to addresses ["0.0.0.0", "::"].
 +
 + Params:
 +     port          = The port to start the server on.
 +     bindAddresses = A list of addresses to bind to.
 ++/
void start(ushort port = 8085, string[] bindAddresses = ["0.0.0.0", "::"]...)
{
	auto settings = new HTTPServerSettings;
	settings.bindAddresses = bindAddresses;
	settings.port = port;
	settings.start;
}

/++
 + Starts the server using the specified settings.
 +
 + Params:
 +     settings = The settings for the HTTP server.
 ++/
void start(HTTPServerSettings settings)
{
	// Check if a server is already running.
	if(!savedListener.isNull)
	{
		throw new Exception("Server already running.");
	}

	// Start listening.
	savedListener = listenHTTP(settings, router);
}

/++
 + Stops the server.
 ++/
void stop()
{
	savedListener.get.stopListening;
	savedListener.nullify;
}

/++
 + Halt execution of a route or filter handler.
 + Halt uses a HaltThrowable. If caught, it should be re-thrown
 + to properly stop exection of a callback.
 +
 + Params:
 +     message = A message body to optionally include. Defaults to empty.
 ++/
void halt(string message = "")
{
	throw new HaltThrowable(0, message);
}

/++
 + Halt execution of a route or filter handler.
 + Halt uses a HaltThrowable. If caught, it should be re-thrown
 + to properly stop exection of a callback.
 +
 + Params:
 +     status  = The status code sent with the message.
 +     message = A message body to optionally include. Defaults to empty.
 ++/
void halt(int status, string message = "")
{
	throw new HaltThrowable(status, message);
}

/++
 + Attaches a handler to an exception type.
 +
 + Params:
 +     type     = The type of exception to catch.
 +     callback = The handler for the exception.
 ++/
void Catch(ClassInfo type, ExceptionCallback callback)
{
	// Add the callback to the type list.
	exceptionCallbacks[type] = callback;
}

/++
 + Adds a filter to a filter callback table.
 +
 + Params:
 +     filterTable = The table to add the callback to.
 +     path        = The path the callback runs on.
 +     callback    = The callback to add.
 ++/
private void AddFilter(
	ref VoidCallback[][string] filterTable,
	/+ @Nullable +/ string path,
	VoidCallback callback)
{
	// Check if the path has callbacks.
	auto ptr = path in filterTable;

	if(ptr is null)
	{
		filterTable[path] = [ callback ];
	}
	else
	{
		*ptr ~= callback;
	}
}

/++
 + Adds a filter to all paths which is called before the handler.
 +
 + Params:
 +     callback = The filter that handles the event.
 ++/
void Before(VoidCallback callback)
{
	AddFilter(beforeCallbacks, null, callback);
}

/++
 + Adds a filter to the given path which is called before the handler.
 +
 + Params:
 +     path     = The path that this filter is specific to.
 +     callback = The filter that handles the event.
 ++/
void Before(string path, VoidCallback callback)
{
	AddFilter(beforeCallbacks, path, callback);
}

/++
 + Adds a filter to all paths which is called after the handler.
 +
 + Params:
 +     callback = The filter that handles the event.
 ++/
void After(VoidCallback callback)
{
	AddFilter(afterCallbacks, null, callback);
}

/++
 + Adds a filter to the given path which is called after the handler.
 +
 + Params:
 +     path     = The path that this filter is specific to.
 +     callback = The filter that handles the event.
 ++/
void After(string path, VoidCallback callback)
{
	AddFilter(afterCallbacks, path, callback);
}

/++
 + Adds a handler for all method types on the given path.
 +
 + Params:
 +     path     = The path that gets handled.
 +     callback = The handler that gets called for requests.
 ++/
void Any(string path, StringCallback callback)
{
	Any(path, null, callback);
}

/++
 + Adds a handler for all method types on the given path.
 +
 + Params:
 +     path        = The path that gets handled.
 +     contentType = The value for the HTTP content type header.
 +     callback    = The handler that gets called for requests.
 ++/
void Any(string path, string contentType, StringCallback callback)
{
	import std.traits : EnumMembers;
	auto methods = EnumMembers!HTTPMethod;

	foreach(method; methods)
	{
		// Match each HTTP method type.
		Match(method, path, contentType, callback);
	}
}

/++
 + Adds a handler for all method types on the given path.
 +
 + Params:
 +     path        = The path that gets handled.
 +     callback    = The handler that gets called for requests.
 +     transformer = The transformer function that converts output to a string.
 ++/
void Any(T)(
	string path,
	T delegate(HTTPServerRequest, HTTPServerResponse) callback,
	string delegate(T) transformer)
{
	Any!T(path, null, callback, transformer);
}

/++
 + Adds a handler for all method types on the given path.
 +
 + Params:
 +     path        = The path that gets handled.
 +     contentType = The value for the HTTP content type header.
 +     callback    = The handler that gets called for requests.
 +     transformer = The transformer function that converts output to a string.
 ++/
void Any(T)(
	string path, string contentType,
	T delegate(HTTPServerRequest, HTTPServerResponse) callback,
	string delegate(T) transformer)
{
	import std.traits : EnumMembers;
	auto methods = EnumMembers!HTTPMethod;

	foreach(method; methods)
	{
		// Match each HTTP method type.
		Match!T(method, path, contentType, callback, transformer);
	}
}

/++
 + A template that generates the source for a methods.
 +
 + Params:
 +     method = The name of the method to produce.
 ++/
private template MethodCode(string method)
{
	import std.string;

	enum MethodCode = format(`
		void %1$s(string path, StringCallback callback)
		{
			Match(HTTPMethod.%2$s, path, null, callback);
		}

		void %1$s(string path, string contentType, StringCallback callback)
		{
			Match(HTTPMethod.%2$s, path, contentType, callback);
		}

		void %1$s(T)(
			string path,
			T delegate(HTTPServerRequest, HTTPServerResponse) callback,
			string delegate(T) transformer)
		{
			Match!T(HTTPMethod.%2$s, path, null, callback, transformer);
		}

		void %1$s(T)(
			string path, string contentType,
			T delegate(HTTPServerRequest, HTTPServerResponse) callback,
			string delegate(T) transformer)
		{
			Match!T(HTTPMethod.%2$s, path, contentType, callback, transformer);
		}
	`, 
		method[0 .. 1].toUpper ~ method[1 .. $].toLower,
		method.toUpper
	);
}

// Generate methods.
mixin(
	joiner([
		staticMap!(
			MethodCode,
			"GET", "POST", "PUT", "PATCH", "DELETE",
			"HEAD", "OPTIONS", "LOCK", "UNLOCK",
			"MOVE", "COPY", "CONNECT", "TRACE"
		)
	]).text
);
