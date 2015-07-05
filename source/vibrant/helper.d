
module vibrant.helper;

import std.regex;
import std.string;
import std.traits;

import vibe.d;

struct ParameterWrapper
{

	private HTTPServerRequest request;

	void opAssign(HTTPServerRequest request)
	{
		this.request = request;
	}

	/++
	 + Returns the wrapped url parameters.
	 ++/
	@property
	auto urlParams()
	{
		return request.params;
	}

	/++
	 + Returns the wrapped query parameters.
	 ++/
	@property
	auto queryParams()
	{
		return request.query;
	}

	string get(string index, string fallback)
	{
		// Check URL parameters first.
		auto ptr = index in request.params;
		if(ptr !is null) return *ptr;

		// Then check query parameters.
		return request.query.get(index, fallback);
	}

	string opIndex(string index)
	{
		// Check URL parameters first.
		auto ptr = index in request.params;
		if(ptr !is null) return *ptr;

		// Then check query parameters.
		return request.query[index];
	}

	bool opBinaryRight(string op : "in")(string index)
	{
		// Check if the index exists in URL or query parameters.
		return index in request.params || index in request.query;
	}

}

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

string toSnakeCase(Str)(Str str)
if(isSomeString!Str)
{
	auto r1 = ctRegex!(r"([A-Z]+)([A-Z][a-z])");
	auto r2 = ctRegex!(r"([a-z\d])([A-Z])");
	
	return str
		.replaceAll(r1, "$1_$2")
		.replaceAll(r2, "$1_$2")
		.toLower;
}

string stripPrefix(string Prefix, Str)(Str str)
if(isSomeString!Str)
{
	auto r1 = ctRegex!("^" ~ Prefix);
	return str.replaceAll(r1, "");
}

string stripSuffix(string Suffix, Str)(Str str)
if(isSomeString!Str)
{
	auto r1 = ctRegex!(Suffix ~ "$");
	return str.replaceAll(r1, "");
}
