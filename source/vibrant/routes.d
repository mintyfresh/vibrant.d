
module vibrant.routes;

mixin template Routes(string ResourceName = "")
{

	import std.typetuple;
	import dquery.d;

	private
	{

		/++
		 + The current request parameters.
		 ++/
		Parameter params;

		/++
		 + The current HTTP Request object.
		 ++/
		HTTPServerRequest request;

		/++
		 + The current HTTP Response object.
		 ++/
		HTTPServerResponse response;

		/++
		 + Content type definitions for render!().
		 ++/
		enum
		{
			TEXT  = "text/plain",
			JS    = "application/javascript",
			JSON  = "application/json",
			XML   = "application/xml",
			XHTML = "application/xhtml+xml",
			HTML  = "text/html",
			CSS   = "text/css",
			EMPTY = "@empty"
		}

		@property
		static string resourceName(this This)()
		{
			static if(ResourceName == "")
			{
				// Prefix from type name.
				return "/" ~ This
					.stringof
					.toSnakeCase
					.stripSuffix!"_controller";
			}
			else
			{
				return ResourceName;
			}
		}

		@property
		template hasFunction(This, string name)
		{
			enum hasFunction = Alias!(
				!query!This()
					.functions
					.arity!(0)
					.name!name
					.empty
			);
		}

		@property
		template getFunction(This, string name)
		if(hasFunction!(This, name))
		{
			alias getFunction = Alias!(
				query!This()
					.functions
					.arity!(0)
					.name!name
					.first
					.value
			);
		}

		static VoidCallback createCallback(This, string name)()
		{
			return delegate void(HTTPServerRequest req, HTTPServerResponse res)
			{
				// Create the controller.
				This controller = new This;

				// Setup request and response.
				controller.request = req;
				controller.response = res;
				controller.params = createParameters(req);

				// Call the controller action.
				controller.getFunction!(This, name)();
			};
		}

	}

	/++
	 + Renders a plaintext response.
	 ++/
	@property
	public void render(Body)(Body content)
	{
		return render!(Text, Body)(content);
	}

	/++
	 + Renders a response with a given content type.
	 ++/
	@property
	public void render(string contentType, Body)(Body content)
	if(contentType.length > 0 && contentType[0] != '@')
	{
		import std.conv : to;
		response.writeBody(to!string(content), contentType);
	}

	/++
	 + Renders a response with a given content type and status code.
	 ++/
	@property
	public void render(string contentType, Body)(Body content, int code)
	if(contentType.length > 0 && contentType[0] != '@')
	{
		response.statusCode = code;
		render!(contentType, Body)(content);
	}

	/++
	 + Renders an empty response.
	 ++/
	@property
	public void render(string contentType)()
	if(contentType == EMPTY)
	{
		response.writeBody(""); // Write an empty body.
	}

	/++
	 + Renders an empty response and the given status code.
	 ++/
	@property
	public void render(string contentType)(int code)
	if(contentType == EMPTY)
	{
		response.statusCode = code;
		render!contentType;
	}

	/++
	 + Installs the controller routes into a Vibrant router.
	 ++/
	public static void install(bool Bool)(VibrantRouter!Bool router)
	{
		alias This = Alias!(typeof(this));

		// 'index' route; display all.
		static if(hasFunction!(This, "index"))
		{
			router.Get(resourceName!This, createCallback!(This, "index"));
		}

		// 'me' route; display my object.
		static if(hasFunction!(This, "me"))
		{
			router.Get(resourceName!This, createCallback!(This, "me"));
		}

		// 'new' route; show new form.
		static if(hasFunction!(This, "new"))
		{
			router.Get(resourceName!This ~ "/me", createCallback!(This, "new"));
		}

		// 'create' route; create object.
		static if(hasFunction!(This, "create"))
		{
			router.Post(resourceName!This, createCallback!(This, "create"));
		}

		// 'show' route; display an object.
		static if(hasFunction!(This, "show"))
		{
			router.Get(resourceName!This ~ "/:id", createCallback!(This, "show"));
		}

		// 'edit' route; display edit form.
		static if(hasFunction!(This, "edit"))
		{
			router.Get(resourceName!This ~ "/:id/edit", createCallback!(This, "edit"));
		}

		// 'update' route; edit an object.
		static if(hasFunction!(This, "update"))
		{
			router.Put(resourceName!This ~ "/:id", createCallback!(This, "update"));

			router.Patch(resourceName!This ~ "/:id", createCallback!(This, "update"));
		}

		// 'destroy' route; delete an object.
		static if(hasFunction!(This, "destroy"))
		{
			router.Delete(resourceName!This ~ "/:id", createCallback!(This, "destroy"));
		}
	}

}
