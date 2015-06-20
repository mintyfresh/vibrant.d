vibrant.d - A Sinatra-like framework for vibe.d
===============================================

vibrant.d is a light routing framework that mimicks the style of frameworks like Sinatra and Spark.

Hello World
-----------

```d
import vibrant.d;

shared static this()
{
    with(Vibrant(8080))
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
    with(Vibrant(8080))
    {
        Get("/hello/:name", (req, res) => "Hello " ~ req.params["name"]);
    }
}
```

vibe.d style URL routing, vibrant.d style simplicity.

### Hit the road Jack

```d
import vibrant.d;

shared static this()
{
    with(Vibrant(8080))
    {
        Before("/hello/:name", (req, res) {
            if(req.params["name"] == "Jack")
            {
                halt("Don't come back.");
            }
        });

        Get("/hello/:name", (req, res) => "Hello " ~ req.params["name"]);
    }
}
```

Also comes in `halt()`, `halt(403)`, and `halt(403, "...")` flavours.

### Exceptions Handled

```d
import vibrant.d;

shared static this()
{
    with(Vibrant(8080))
    {
        Catch(Exception.classinfo, (ex, req, res) {
            res.statusCode = 500;
            res.writeBody(ex.msg);
        });

        Get("/hello/:name", (req, res) => throw new Exception("Whoops!"));
    }
}
```

Exceptions are better when they're simple.

### Route More

```d
import vibrant.d;

shared static this()
{
    with(Vibrant(8080))
    {
        Get("/hello/:name", (req, res) => "Hello " ~ req.params["name"]);
    }

    with(Vibrant(8081))
    {
        Get("/hello/:name", (req, res) => "Goodbye " ~ req.params["name"]);
    }
}
```

`Vibrant()` also happily accepts vibe.d's `HTTPServerSettings` objects.

### Serve More

```d
import vibrant.d;

shared static this()
{
    with(Vibrant(8080))
    {
        Get!Json("/hello/:name",
        (req, res) {
            res.contentType = "application/json";

            return Json([
                "greeting" : Json("Hello " ~ req.params["name"])
            ]);
        },
        (json) => // Optional!
            json.toPrettyString
        );
    }
}
```

If you don't give vibrant a second delegate, the value is converted with `std.conv.to!string`.

### Comes With Options

```d
import vibrant.d;

shared static this()
{
    with(Vibrant(8080))
    {
        Get("/hello", (req, res) { . . . });

        Post("/hello", (req, res) { . . . });

        Put("/hello", (req, res) { . . . });

        // Patch, Delete, Head, Options, Connect, Trace
    }
}
```

Or use `Vibrant!true(8080)` to include all methods supported by vibe.d.

### And Stop

```d
import vibrant.d;

shared static this()
{
    with(Vibrant(8080))
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

License
-------

MIT
