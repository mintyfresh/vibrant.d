
module vibrant.parameter;

import std.algorithm;
import std.conv;
import std.regex;
import std.string;
import std.traits;
import std.typetuple;

import vibe.d;

class ParameterMissing : Exception
{

	this(string name)
	{
		super("Missing parameter: " ~ name);
	}

}

class Parameter
{
	private
	{
		string _value;

		Parameter[] _array;

		Parameter[string] _assoc;
	}

	this()
	{
	}

	/+ Helpers +/

	private
	{
		Parameter opAssign(string param)
		{
			_value = param;
			return this;
		}

		Parameter opOpAssign(string op : "~")(string param)
		{
			Parameter element = new Parameter();
			this ~= (element = param);
			return this;
		}

		Parameter opOpAssign(string op : "~")(Parameter param)
		{
			_array ~= param;
			return this;
		}

		Parameter opIndexAssign(string param, string index)
		{
			Parameter element = new Parameter();
			this[index] = (element = param);
			return this;
		}

		Parameter opIndexAssign(Parameter param, string index)
		{
			_assoc[index] = param;
			return this;
		}

		Parameter opIndexOpAssign(string op : "~")(string param, string index)
		{
			Parameter element = new Parameter();
			this[index] ~= (element = param);
			return this;
		}

		Parameter opIndexOpAssign(string op : "~")(Parameter param, string index)
		{
			_assoc[index] ~= param;
			return this;
		}

		Parameter opIndexOpAssign(string op : "|")(lazy Parameter param, string index)
		{
			if(index !in _assoc)
			{
				this[index] = param;
			}

			return this;
		}
	}

	/+ Properties +/

	@property
	string value()
	{
		return _value;
	}

	@property
	Parameter[] array()
	{
		return _array;
	}

	@property
	Parameter[string] assoc()
	{
		return _assoc;
	}

	@property
	bool isA(Type)()
	{
		try
		{
			cast(Type)this;
			return true;
		}
		catch(ConvException e)
		{
			return false;
		}
	}

	@property
	alias isAn(Type) = isA!Type;

	@property
	Type as(Type)()
	{
		return cast(Type)this;
	}

	/+ Operators +/

	Parameter *opBinaryRight(string op : "in")(string index)
	{
		return index in _assoc;
	}

	bool opBinaryRight(string op : "!in")(string index)
	{
		return index !in _assoc;
	}

	/++
	 + Unspecialized type cast.
	 ++/
	Type opCast(Type)()
	{
		return _value.to!Type;
	}

	string opCast(Type : string)()
	{
		return _value;
	}

	Parameter opCast(Type : Parameter)()
	{
		return this;
	}

	string[] opCast(Type : string[])()
	{
		string[] elements;

		foreach(element; _array)
		{
			elements ~= element;
		}

		return elements;
	}

	Parameter[] opCast(Type : Parameter[])()
	{
		return _array;
	}

	string[string] opCast(Type : string[string])()
	{
		string[string] elements;

		foreach(key, element; _assoc)
		{
			elements[key] = element;
		}

		return elements;
	}

	Parameter[string] opCast(Type : Parameter[string])()
	{
		return _assoc;
	}

	Parameter opIndex(size_t index)
	{
		if(index < _array.length)
		{
			return _array[index];
		}
		else
		{
			return null;
		}
	}

	Parameter opIndex(string index)
	{
		auto ptr = index in this;
		return ptr ? *ptr : null;
	}

	/+ Functions +/

	Parameter require(string key)
	{
		auto ptr = key in this;

		if(ptr is null)
		{
			throw new ParameterMissing(key);
		}
		else
		{
			return *ptr;
		}
	}

	/++
	 + Returns a JSON-like string representation of the parameter.
	 ++/
	string toPrettyString()
	{
		string[] buffer;

		// Include value component.
		if(_value !is null)
		{
			buffer ~= format(`"%s"`, _value);
		}

		// Include array component.
		if(_array.length > 0)
		{
			string[] tmp;

			foreach(element; _array)
			{
				tmp ~= element.toPrettyString;
			}

			buffer ~= "[ " ~ tmp.joiner(", ").text ~ " ]";
		}

		// Include assoc component.
		if(_assoc.length > 0)
		{
			string[] tmp;

			foreach(key, element; _assoc)
			{
				tmp ~= "\"" ~ key ~ "\" : " ~ element.toPrettyString;
			}

			buffer ~= "{ " ~ tmp.joiner(", ").text ~ " }";
		}

		return buffer.joiner(", ").text;
	}

	override string toString()
	{
		return _value;
	}
}

Parameter normalizeParameters(Parameter param, string name, string value)
{
	static auto r1 = ctRegex!(r"^([^\[\]]+)");
	static auto r2 = ctRegex!(r"^\[([^\[\]]+)\]");
	static auto r3 = ctRegex!(r"^(?:\[\])+");

	Captures!string captures;

	// Check for assoc or named parameters.
	if(!(captures = name.matchFirst(r1)).empty ||
		!(captures = name.matchFirst(r2)).empty)
	{
		string key = captures[1];
		string after = captures.post;

		// Create a parameter if it doesn't exist.
		param[key] |= new Parameter();

		param[key] = normalizeParameters(
			param[key], after, value
		);
	}
	// Check for array parameters.
	else if(!(captures = name.matchFirst(r3)).empty)
	{
		Parameter target = null;
		string after = captures.post;

		// Check if the array is empty.
		if(param._array.length > 0)
		{
			// Check if the next parameter is an assoc.
			if(!(captures = after.matchFirst(r2)).empty)
			{
				Parameter last = param._array[$ - 1];

				// Check if we should complete the last array.
				if(captures[1] !in last)
				{
					target = last;
				}
			}
		}

		// Check if we have a target.
		if(target is null)
		{
			// Create a new element and append it.
			param ~= normalizeParameters(
				new Parameter(), after, value
			);
		}
		else
		{
			// Add to the existing array.
			normalizeParameters(
				target, after, value
			);
		}
	}
	// Plain parameter.
	else
	{
		param = value;
	}
	
	return param;
}

@property
Parameter createParameters(string[] params, string[] values)
{
	auto assoc = new Parameter();

	foreach(idx, param; params)
	{
		normalizeParameters(assoc, param, values[idx]);
	}

	return assoc;
}

@property
Parameter createParameters(HTTPServerRequest request)
{
	auto assoc = new Parameter();

	// Include form parameters.
	foreach(key, value; request.form)
	{
		normalizeParameters(assoc, key, value);
	}

	// Include request parameters.
	foreach(key, value; request.query)
	{
		normalizeParameters(assoc, key, value);
	}

	// Include URL parameters.
	foreach(key, value; request.params)
	{
		normalizeParameters(assoc, key, value);
	}

	return assoc;
}
