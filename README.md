vibrant.d - A Sinatra-like framework for vibe.d
===============================================

vibrant.d is a light routing framework that mimicks the style of frameworks like Sinatra and Spark.

Hello World
-----------

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

vibrant.d includes `Get`, `Post`, `Put`, `Patch`, `Delete`, `Head`, `Options`, `Connect`, and `Trace` by default.

Or use `Vibrant!true` to include all methods supported by vibe.d.

### And Stop

```d
import vibrant.d;

shared static this()
{
    with(Vibrant)
    {
        Post("/admin/shutdown", (req, res) {
            bool authenticated;
            // Authenticate . . .

            if(authenticated)
            {
                Stop; // Stop the server.
            }
        });
    }
}
```

### Being Resourceful

```d
import vibrant.d;

class BookController
{
    mixin Routes;

    void index()
    {
        Book[] books = Book.all;

        render!JSON = books.toJson;
    }

    void show()
    {
        string id = params["id"];
        Book book = Book.find(id);

        render!JSON = book.toJson;
    }

    void destroy()
    {
        string id = params["id"];
        Book book = Book.find(id);

        render!EMPTY = 201;
    }
}
```

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
