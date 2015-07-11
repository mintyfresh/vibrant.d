
module vibrant.d;

public import vibe.d;

public import vibrant.helper;
public import vibrant.parameter;
public import vibrant.router;
public import vibrant.routes;

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
