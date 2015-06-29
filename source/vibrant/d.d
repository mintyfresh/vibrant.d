
module vibrant.d;

import std.algorithm;
import std.conv;
import std.functional;
import std.traits;
import std.typecons;
import std.typetuple;

public import vibe.d;

// TODO : This is probably a hack.
extern(C) int _d_isbaseof(ClassInfo oc, ClassInfo c);

/++
 + The vibrant router class.
 ++/
class VibrantRouter(bool GenerateAll = false) : HTTPServerRequestHandler
{

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
		 + Response callback for catching exceptions.
		 ++/
		alias ExceptionCallback = void delegate(
			Throwable, HTTPServerRequest, HTTPServerResponse
		);

		/++
		 + Tests if a type is a valid result from a callback.
		 ++/
		template isValidResultType(Result)
		{
			enum isValidResultType =
				is(Result == const(ubyte[])) ||
				is(Result == ubyte[]) ||
				is(Result == string) ||
				is(Result == void);
		}

		/++
		 + Tests if a type is a valid result from a transform function.
		 ++/
		template isValidTransformedType(Temp)
		{
			enum isValidTransformedType =
				is(Temp == const(ubyte[])) ||
				is(Temp == ubyte[]) ||
				is(Temp == string);
		}

	}

	/++
	 + Constructs a new vibrant router.
	 +
	 + Params:
	 +     router = A URLRouter to forward requests to.
	 ++/
	private this(URLRouter router)
	{
		this.router = router;

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
	 + Constructs a new vibrant router and starts listening for connections.
	 +
	 + Params:
	 +     settings = The settings for the HTTP server.
	 +     prefix   = The prefix to place all routes at.
	 ++/
	private this(HTTPServerSettings settings, string prefix)
	{
		this(new URLRouter(prefix));
		savedListener = listenHTTP(settings, router);
	}

	/++
	 + Forwards a requrest to the internal URLRouter.
	 +
	 + Params:
	 +     req = The HTTPServerRequest object.
	 +     res = The HTTPServerResponse object.
	 ++/
	void handleRequest(HTTPServerRequest req, HTTPServerResponse res)
	{
		router.handleRequest(req, res);
	}

	/++
	 + Produces a child of the current scope with the given prefix.
	 +
	 + Params:
	 +     prefix = The prefix the scope operates from.
	 +
	 + Returns:
	 +     A new VibrantRouter object.
	 ++/
	auto Scope(string prefix)
	{
		// Create a subrouter and forward requests that match its prefix.
		auto subrouter = new URLRouter(router.prefix ~ prefix);
		router.any("*", subrouter);

		// Create a new child vibrant router, and pass along the listener.
		auto newRouter = new VibrantRouter!GenerateAll(subrouter);
		newRouter.savedListener = savedListener;
		return newRouter;
	}

	/++
	 + Instantly updates the installed routes (instead of lazily).
	 ++/
	void Flush()
	{
		router.rebuild;
	}

	/++
	 + Instantly stops the server.
	 ++/
	void Stop()
	{
		savedListener.get.stopListening;
		savedListener.nullify;
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
	 + Adds a filter to all paths which is called before the handler.
	 +
	 + Params:
	 +     callback = The filter that handles the event.
	 ++/
	void Before(VoidCallback callback)
	{
		addFilterCallback(beforeCallbacks, null, callback);
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
		addFilterCallback(beforeCallbacks, path, callback);
	}

	/++
	 + Adds a filter to all paths which is called after the handler.
	 +
	 + Params:
	 +     callback = The filter that handles the event.
	 ++/
	void After(VoidCallback callback)
	{
		addFilterCallback(afterCallbacks, null, callback);
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
		addFilterCallback(afterCallbacks, path, callback);
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
	 + Adds a handler for all method types on the given path.
	 +
	 + Params:
	 +     path     = The path that gets handled.
	 +     callback = The handler that gets called for requests.
	 ++/
	void Any(Result)(string path,
		Result function(HTTPServerRequest, HTTPServerResponse) callback)
	if(isValidResultType!Result)
	{
		return Any!(Result)(path, null, callback);
	}

	/++
	 + Adds a handler for all method types on the given path.
	 +
	 + Params:
	 +     path        = The path that gets handled.
	 +     contentType = The content type header to include in the response.
	 +     callback    = The handler that gets called for requests.
	 ++/
	void Any(Result)(string path, string contentType,
		Result function(HTTPServerRequest, HTTPServerResponse) callback)
	if(isValidResultType!Result)
	{
		foreach(method; EnumMembers!HTTPMethod)
		{
			// Match each HTTP method type.
			Match(method, path, contentType, callback);
		}
	}

	/++
	 + Adds a handler for all method types on the given path.
	 +
	 + Params:
	 +     path     = The path that gets handled.
	 +     callback = The handler that gets called for requests.
	 ++/
	void Any(Result)(string path, string contentType,
		Result delegate(HTTPServerRequest, HTTPServerResponse) callback)
	if(isValidResultType!Result)
	{
		return Any!(Result)(path, null, callback);
	}

	/++
	 + Adds a handler for all method types on the given path.
	 +
	 + Params:
	 +     path        = The path that gets handled.
	 +     contentType = The content type header to include in the response.
	 +     callback    = The handler that gets called for requests.
	 ++/
	void Any(Result)(string path, string contentType,
		Result delegate(HTTPServerRequest, HTTPServerResponse) callback)
	if(isValidResultType!Result)
	{
		foreach(method; EnumMembers!HTTPMethod)
		{
			// Match each HTTP method type.
			Match(method, path, contentType, callback);
		}
	}

	template Any(Temp)
	if(isValidTransformedType!Result)
	{
		static if(!is(Temp == void))
		{
			/++
			 + Adds a handler for all method types on the given path.
			 +
			 + Params:
			 +     path        = The path that gets handled.
			 +     callback    = The handler that gets called for requests.
			 +     transformer = The transformer function that converts output.
			 ++/
			void Any(Result = string)(string path,
				Temp function(HTTPServerRequest, HTTPServerResponse) callback,
				Result function(Temp) transformer)
			if(isValidTransformedType!Result)
			{
				return Any!(Result)(path, null, callback, transformer);
			}

			/++
			 + Adds a handler for all method types on the given path.
			 +
			 + Params:
			 +     path        = The path that gets handled.
	 		 +     contentType = The content type header to include in the response.
			 +     callback    = The handler that gets called for requests.
			 +     transformer = The transformer function that converts output.
			 ++/
			void Any(Result = string)(string path, string contentType,
				Temp function(HTTPServerRequest, HTTPServerResponse) callback,
				Result function(Temp) transformer)
			if(isValidTransformedType!Result)
			{
				foreach(method; EnumMembers!HTTPMethod)
				{
					// Match each HTTP method type.
					Match!(Temp)(method, path, contentType, callback, transformer);
				}
			}

			/++
			 + Adds a handler for all method types on the given path.
			 +
			 + Params:
			 +     path        = The path that gets handled.
			 +     callback    = The handler that gets called for requests.
			 +     transformer = The transformer delegate that converts output.
			 ++/
			void Any(Result = string)(string path,
				Temp delegate(HTTPServerRequest, HTTPServerResponse) callback,
				Result delegate(Temp) transformer)
			if(isValidTransformedType!Result)
			{
				return Any!(Result)(path, null, callback, transformer);
			}

			/++
			 + Adds a handler for all method types on the given path.
			 +
			 + Params:
			 +     path        = The path that gets handled.
	 		 +     contentType = The content type header to include in the response.
			 +     callback    = The handler that gets called for requests.
			 +     transformer = The transformer delegate that converts output.
			 ++/
			void Any(Result = string)(string path, string contentType,
				Temp delegate(HTTPServerRequest, HTTPServerResponse) callback,
				Result delegate(Temp) transformer)
			if(isValidTransformedType!Result)
			{
				foreach(method; EnumMembers!HTTPMethod)
				{
					// Match each HTTP method type.
					Match!(Temp)(method, path, contentType, callback, transformer);
				}
			}
		}
	}

	/++
	 + A template that generates the source for HTTP methods.
	 +
	 + Params:
	 +     method = The name of the method to produce.
	 ++/
	private template GetHTTPMethodCode(string method)
	{
		import std.string;

		enum GetHTTPMethodCode = format(`
			void %1$s(Result)(string path,
				Result function(HTTPServerRequest, HTTPServerResponse) callback)
			if(isValidResultType!Result)
			{
				%1$s!(Result)(path, null, callback);
			}

			void %1$s(Result)(string path, string contentType,
				Result function(HTTPServerRequest, HTTPServerResponse) callback)
			if(isValidResultType!Result)
			{
				Match(HTTPMethod.%2$s, path, contentType, callback);
			}

			void %1$s(Result)(string path,
				Result delegate(HTTPServerRequest, HTTPServerResponse) callback)
			if(isValidResultType!Result)
			{
				%1$s!(Result)(path, null, callback);
			}

			void %1$s(Result)(string path, string contentType,
				Result delegate(HTTPServerRequest, HTTPServerResponse) callback)
			if(isValidResultType!Result)
			{
				Match(HTTPMethod.%2$s, path, contentType, callback);
			}

			template %1$s(Temp)
			if(!is(Temp == void))
			{
				static if(!is(Temp == void))
				{
					void %1$s(Result = string)(string path,
						Temp function(HTTPServerRequest, HTTPServerResponse) callback,
						Result function(Temp) transformer)
					if(isValidTransformedType!Result)
					{
						%1$s!(Result)(path, null, callback, transformer);
					}

					void %1$s(Result = string)(string path, string contentType,
						Temp function(HTTPServerRequest, HTTPServerResponse) callback,
						Result function(Temp) transformer)
					if(isValidTransformedType!Result)
					{
						Match!(Temp)(
							HTTPMethod.%2$s, path, contentType, callback, transformer
						);
					}

					void %1$s(Result = string)(string path,
						Temp delegate(HTTPServerRequest, HTTPServerResponse) callback,
						Result delegate(Temp) transformer)
					if(isValidTransformedType!Result)
					{
						%1$s!(Result)(path, null, callback, transformer);
					}

					void %1$s(Result = string)(string path, string contentType,
						Temp delegate(HTTPServerRequest, HTTPServerResponse) callback,
						Result delegate(Temp) transformer)
					if(isValidTransformedType!Result)
					{
						Match!(Temp)(
							HTTPMethod.%2$s, path, contentType, callback, transformer
						);
					}
				}
			}
		`,
			// The Titlecase function name.
			method[0 .. 1].toUpper ~ method[1 .. $].toLower,
			// The UPPERCASE HTTP method name.
			method.toUpper
		);
	}

	static if(GenerateAll)
	{
		// Include all supported methods.
		private enum HTTPEnabledMethodList = __traits(allMembers, HTTPMethod);
	}
	else
	{
		// Include only common methods.
		private enum HTTPEnabledMethodList = TypeTuple!(
			"GET", "POST", "PUT", "PATCH", "DELETE",
			"HEAD", "OPTIONS", "CONNECT", "TRACE"
		);
	}

	// Generate methods.
	mixin(
		joiner([
			staticMap!(
				GetHTTPMethodCode,
				HTTPEnabledMethodList
			)
		]).text
	);

	/++
	 + Matches a path and method type using a function callback.
	 +
	 + Params:
	 +     method   = The HTTP method matched.
	 +     path     = The path assigned to this route.
	 +     callback = A function callback handler for the route.
	 ++/
	void Match(Result)(HTTPMethod method, string path,
		Result function(HTTPServerRequest, HTTPServerResponse) callback)
	if(isValidResultType!Result)
	{
		// Wrap the function in a delegate.
		Match!(Result)(method, path, null, callback);
	}

	/++
	 + Matches a path and method type using a function callback.
	 +
	 + Params:
	 +     method      = The HTTP method matched.
	 +     path        = The path assigned to this route.
	 +     contentType = The content type header to include in the response.
	 +     callback    = A function callback handler for the route.
	 ++/
	void Match(Result)(HTTPMethod method, string path, string contentType,
		Result function(HTTPServerRequest, HTTPServerResponse) callback)
	if(isValidResultType!Result)
	{
		// Wrap the function in a delegate.
		Match!(Result)(method, path, contentType, toDelegate(callback));
	}

	/++
	 + Matches a path and method type using a delegate callback.
	 +
	 + Params:
	 +     method   = The HTTP method matched.
	 +     path     = The path assigned to this route.
	 +     callback = A delegate callback handler for the route.
	 ++/
	void Match(Result)(HTTPMethod method, string path,
		Result delegate(HTTPServerRequest, HTTPServerResponse) callback)
	if(isValidResultType!Result)
	{
		return Match!(Result)(method, path, null, callback);
	}

	/++
	 + Matches a path and method type using a delegate callback.
	 +
	 + Params:
	 +     method      = The HTTP method matched.
	 +     path        = The path assigned to this route.
	 +     contentType = The content type header to include in the response.
	 +     callback    = A delegate callback handler for the route.
	 ++/
	void Match(Result)(HTTPMethod method, string path, string contentType,
		Result delegate(HTTPServerRequest, HTTPServerResponse) callback)
	if(isValidResultType!Result)
	{
		router.match(method, path, (req, res) {
			try
			{
				// Invoke before-filters.
				applyFilterCallback(beforeCallbacks, path, req, res);
				
				static if(!is(Result == void))
				{
					// Call the callback and save the result.
					auto result = callback(req, res);
				}
				else
				{
					// Call the callback; no result.
					callback(req, res);
					auto result = "";
				}

				// Invoke after-filters.
				applyFilterCallback(afterCallbacks, path, req, res);

				// Just send an empty response.
				res.writeBody(result, contentType);
			}
			catch(Throwable t)
			{
				handleException(t, req, res);
			}
		});
	}

	template Match(Temp)
	if(!is(Temp == void))
	{
		static if(!is(Temp == void))
		{
			/++
			 + Matches a path and method type using a function callback.
			 +
			 + Params:
			 +     method      = The HTTP method matched.
			 +     path        = The path assigned to this route.
			 +     callback    = A function callback handler for the route.
			 +     transformer = A transformer that converts the handler's output.
			 ++/
			void Match(Result = string)(HTTPMethod method, string path,
				Temp function(HTTPServerRequest, HTTPServerResponse) callback,
				Result function(Temp) transformer)
			if(isValidTransformedType!Result)
			{
				Match!(Result)(method, path, null, callback, transformer);
			}

			/++
			 + Matches a path and method type using a function callback.
			 +
			 + Params:
			 +     method      = The HTTP method matched.
			 +     path        = The path assigned to this route.
	 		 +     contentType = The content type header to include in the response.
			 +     callback    = A function callback handler for the route.
			 +     transformer = A transformer that converts the handler's output.
			 ++/
			void Match(Result = string)(HTTPMethod method, string path, string contentType,
				Temp function(HTTPServerRequest, HTTPServerResponse) callback,
				Result function(Temp) transformer)
			if(isValidTransformedType!Result)
			{
				// Wrap the function in a delegate.
				Match!(Result)(
					method, path, contentType, toDelegate(callback), toDelegate(transformer)
				);
			}

			/++
			 + Matches a path and method type using a delegate callback.
			 +
			 + Params:
			 +     method      = The HTTP method matched.
			 +     path        = The path assigned to this route.
			 +     callback    = A delegate callback handler for the route.
			 +     transformer = A transformer that converts the handler's output.
			 ++/
			void Match(Result = string)(HTTPMethod method, string path,
				Temp delegate(HTTPServerRequest, HTTPServerResponse) callback,
				Result delegate(Temp) transformer)
			if(isValidTransformedType!Result)
			{
				Match!(Result)(method, path, null, callback, transformer);
			}

			/++
			 + Matches a path and method type using a delegate callback.
			 +
			 + Params:
			 +     method      = The HTTP method matched.
			 +     path        = The path assigned to this route.
	 		 +     contentType = The content type header to include in the response.
			 +     callback    = A delegate callback handler for the route.
			 +     transformer = A transformer that converts the handler's output.
			 ++/
			void Match(Result = string)(HTTPMethod method, string path, string contentType,
				Temp delegate(HTTPServerRequest, HTTPServerResponse) callback,
				Result delegate(Temp) transformer)
			if(isValidTransformedType!Result)
			{
				router.match(method, path, (req, res) {
					try
					{
						// Invoke before-filters.
						applyFilterCallback(beforeCallbacks, path, req, res);

						// Transform the result into a string.
						string result = transformer(callback(req, res));

						// Invoke after-filters.
						applyFilterCallback(afterCallbacks, path, req, res);

						// Just send the response.
						res.writeBody(result, contentType);
					}
					catch(Throwable t)
					{
						handleException(t, req, res);
					}
				});
			}
		}
	}

	private
	{

		/++
		 + Adds a filter to a filter callback table.
		 +
		 + Params:
		 +     filterTable = The table to add the callback to.
		 +     path        = The path the callback runs on.
		 +     callback    = The callback to add.
		 ++/
		void addFilterCallback(ref VoidCallback[][string] filterTable,
			/+ @Nullable +/ string path, VoidCallback callback)
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
		 + Matches a filter to a path and invokes matched callbacks.
		 +
		 + Params:
		 +     table = The table of callbacks to scan.
		 +     path  = The path to be matched.
		 +     req   = The server request object.
		 +     res   = The server response object. 
		 ++/
		void applyFilterCallback(ref VoidCallback[][string] table, string path,
			HTTPServerRequest req, HTTPServerResponse res)
		{
			// Search for matching callbacks.
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

		/++
		 + Matches a throwable type and invokes its handler.
		 +
		 + Params:
		 +     t   = The throwable being matched.
		 +     req = The server request object.
		 +     res = The server response object.
		 ++/
		void handleException(Throwable t, HTTPServerRequest req, HTTPServerResponse res)
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

	}

}

/++
 + Starts a vibrant router on port 8085.
 +
 + Params:
 +     prefix = The route prefix for all routes.
 +
 + Returns:
 +     An instance of the vibrant router.
 ++/
VibrantRouter!GenerateAll Vibrant(bool GenerateAll = false)(
	string prefix = null)
{
	return Vibrant!GenerateAll(8085u, prefix);
}

/++
 + Starts a vibrant router on the given port.
 + Defaults to port 8085 if none is provided.
 +
 + Params:
 +     port   = The port number to start the server on.
 +     prefix = The route prefix for all routes.
 +
 + Returns:
 +     An instance of the vibrant router.
 ++/
VibrantRouter!GenerateAll Vibrant(bool GenerateAll = false)(
	ushort port, string prefix = null)
{
	HTTPServerSettings settings = new HTTPServerSettings;
	settings.port = port;

	return new VibrantRouter!GenerateAll(settings, prefix);
}

/++
 + Starts a vibrant server with http settings.
 +
 + Params:
 +     settings = The HTTP server settings object.
 +     prefix   = The route prefix for all routes.
 +
 + Returns:
 +     An instance of the vibrant router.
 ++/
VibrantRouter!GenerateAll Vibrant(bool GenerateAll = false)(
	HTTPServerSettings settings, string prefix = null)
{
	return new VibrantRouter!GenerateAll(settings, prefix);
}
