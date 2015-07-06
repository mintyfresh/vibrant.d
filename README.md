vibrant.d - A light framework on top of vibe.d
==============================================

vibrant.d is a light routing framework that mimicks the style of frameworks like Sinatra and Spark.

Hello World
-----------

A plain 'Hello World!' application in vibe.d alone might look something like this,

```d
import vibe.d;

shared static this()
{
    auto settings = new HTTPServerSettings;
    settings.port = 8085;

    listenHTTP(settings, &handleRequest);
}

void handleRequest(HTTPServerRequest req, HTTPServerResponse res)
{
    if(req.path == "/")
    {
        res.writeBody("Hello World!", "text/plain");
    }
}
```

With vibrant.d, we can trim things down a bit. Vibrant provides URL routing out of the box, and some reasonable defaults to get things moving.

```d
import vibrant.d;

shared static this()
{
    with(Vibrant)
    {
        Get("/hello", (req, res) => "Hello World!");
    }
}
```

Bye-bye boilerplate, hello world.

### Personalized Greeting

```d
import vibrant.d;

shared static this()
{
    with(Vibrant)
    {
        Get("/hello/:name", (req, res) =>
            "Hello " ~ req.params["name"]
        );
    }
}
```

vibe.d style URL routing, vibrant.d style simplicity.

### Hit the road Jack

```d
import vibrant.d;

shared static this()
{
    with(Vibrant)
    {
        Before("/hello/:name", (req, res) {
            if(req.params["name"] == "Jack")
            {
                halt("Don't come back.");
            }
        });

        Get("/hello/:name", (req, res) =>
            "Hello " ~ req.params["name"]
        );
    }
}
```

Also comes in `halt()`, `halt(403)`, and `halt(403, "...")` flavours.

### Exceptions Handled

```d
import vibrant.d;

shared static this()
{
    with(Vibrant)
    {
        Catch(Exception.classinfo, (ex, req, res) {
            res.statusCode = 500;
            res.writeBody(ex.msg);
        });

        Get("/hello/:name", (req, res) {
            throw new Exception("Whoops!");
        });
    }
}
```

Exceptions are better when they're simple.

### Route More

```d
import vibrant.d;

shared static this()
{
    // Run on port 8080
    with(Vibrant(8080))
    {
        Get("/hello/:name", (req, res) =>
            "Hello " ~ req.params["name"]
        );
    }

    // Run on port 8081
    with(Vibrant(8081))
    {
        Get("/hello/:name", (req, res) =>
            "Goodbye " ~ req.params["name"]
        );
    }
}
```

`Vibrant()` also happily accepts vibe.d's `HTTPServerSettings` objects.

### Serve More

```d
import vibrant.d;

shared static this()
{
    with(Vibrant)
    {
        Get!Json("/hello/:name", "application/json",
            (req, res) =>
                Json([
                    "greeting" : Json("Hello " ~ req.params["name"])
                ]),
            (json) =>
                json.toPrettyString
        );
    }
}
```

vibrant.d is perfectly fine with producing `string`, `ubyte[]`, and `const(ubyte[])` output.

### Scope More

```d
import vibrant.d;

shared static this()
{
    with(Vibrant)
    {
        // Path : /hello
        Get("/hello", (req, res) => "Hello user!");

        with(Scope("/api"))
        {
            // Path : /api/hello
            Get("/hello", (req, res) => "Hello developer!");

            with(Scope("/admin"))
            {
                // Path : /api/admin/hello
                Get("/hello", (req, res) => "Hello admin!");
            }
        }
    }
}
```

vibrant.d scopes can break up messy APIs into a neat hierarchy.

### Comes With Options

vibrant.d includes methods for `Get`, `Post`, `Put`, `Patch`, `Delete`, `Head`, `Options`, `Connect`, and `Trace` by default.

```d
import vibrant.d;

shared static this()
{
    with(Vibrant)
    {
        Get("/hello", (req, res) {
            // showWorld();
        });

        Post("/hello", (req, res) {
            // createWorld();
        });

        Put("/hello", (req, res) {
            // updateWorld();
        });

        Delete("/hello", (req, res) {
            // deleteWorld();
        });

        Connect("/hello", (req, res) {
            // tunnelIntoWorld();
        });
    }
}
```

Or use `Vibrant!true` to include all methods supported by vibe.d.

### Be Resourceful

vibrant.d ships with a mixin `Routes` for adding Rails styled actions to controller classes.

```d
import vibrant.d;

class BookController
{
    mixin Routes;

    // GET /book
    void index()
    {
        Book[] books = Book.all;

        render!JSON = books.toJson;
    }

    // GET /book/:id
    void show()
    {
        string id = params["id"];
        Book book = Book.find(id);

        render!JSON = book.toJson;
    }

    // DELETE /book/:id
    void destroy()
    {
        string id = params["id"];
        Book.destroy(id);

        render!EMPTY = 201;
    }
}
```

Routes also adds the fields `request` and `response` which store the associated request and response objects, and `params` which provides access to both URL and query parameters. 

Installing a controller into vibrant is as simple as,

```d
shared static this()
{
    with(Vibrant)
    {
        Resource!BookController;
    }
}
```

License
-------

MIT
