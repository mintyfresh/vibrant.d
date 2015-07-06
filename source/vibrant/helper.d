
module vibrant.helper;

import std.regex;
import std.string;
import std.traits;

import vibe.d;

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
