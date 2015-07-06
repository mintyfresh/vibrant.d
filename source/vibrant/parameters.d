
module vibrant.parameters;

import std.algorithm;
import std.array;
import std.regex;
import std.string;

import vibe.d;

/++
 + Returns true if the parameters is a plain value.
 ++/
@property
bool isPlainParam(Parameters parameters)
{
	return cast(PlainParameters)parameters !is null;
}

/++
 + Returns true if the parameters is an array of values.
 ++/
@property
bool isArrayParam(Parameters parameters)
{
	return cast(ArrayParameters)parameters !is null;
}

/++
 + Returns true if the parameters is an associative array of values.
 ++/
@property
bool isAssocParam(Parameters parameters)
{
	return cast(AssocParameters)parameters !is null;
}

class ParametersMissing : Exception
{

	this(string name)
	{
		super("Missing parameters: " ~ name);
	}

}

abstract class Parameters
{

	private
	{
		string _name;
		bool _permitted;
	}

	this()
	{
	}

	this(string name)
	{
		this._name = name;
	}

	@property
	abstract Parameters dup();

	@property
	final string name()
	{
		return _name;
	}

	abstract int opApply(scope int delegate(Parameters) dg);

	abstract int opApply(scope int delegate(string, Parameters) dg);

	Parameters *opBinaryRight(string op : "in")(string key)
	{
		return null;
	}

	bool opBinaryRight(string op : "!in")(string key)
	{
		return true;
	}

	Parameters opIndex(string key)
	{
		return null;
	}

	Parameters permit()
	{
		_permitted = true;
		return this;
	}

	private
	{
		import std.traits;

		static void _permit(T)(Parameters current, T key)
		if(isSomeString!T)
		{
			if(current is null) return;
			auto target = current[key];

			if(target !is null && !target.isAssocParam)
			{
				target.permit;
			}
		}

		static void _permit(T)(Parameters current, T keys)
		if(isArray!T && !isSomeString!T)
		{
			if(current is null) return;

			foreach(key; keys)
			{
				_permit(current, key);
			}
		}

		static void _permit(T)(Parameters current, T keys)
		if(isAssociativeArray!T)
		{
			if(current is null) return;

			foreach(key, value; keys)
			{
				auto target = current[key];

				if(target !is null)
				{
					_permit(target, value);
				}
			}
		}
	}

	Parameters permit(TList...)(TList keys)
	if(TList.length > 0)
	{
		auto copy = dup;

		foreach(key; keys)
		{
			_permit(copy, key);
		}

		copy.permit;
		return copy;
	}

	@property
	bool permitted()
	{
		return _permitted;
	}

	@property
	protected void permitted(bool permitted)
	{
		this._permitted = permitted;
	}

	Parameters remove(string key)
	{
		return null;
	}

	Parameters require(string key)
	{
		auto required = this[key];

		if(required is null)
		{
			throw new ParametersMissing(key);
		}
		else
		{
			return required;
		}
	}

}

class PlainParameters : Parameters
{

	protected
	{
		string _value;
	}

	alias value this;

	this(string value)
	{
		this._value = value;
	}

	this(string name, string value)
	{
		super(name);
		this._value = value;
	}

	override int opApply(scope int delegate(Parameters) dg)
	{
		return dg(this);
	}

	override int opApply(scope int delegate(string, Parameters) dg)
	{
		return dg(name, this);
	}

	@property
	override Parameters dup()
	{
		auto dupped = new PlainParameters(name, value);
		dupped.permitted = permitted;
		return dupped;
	}

	@property
	string value()
	{
		return _value;
	}

	override string toString()
	{
		return value;
	}

}

class ArrayParameters : Parameters
{

	protected
	{
		Parameters[] _values;
	}

	alias value this;

	this()
	{
	}

	this(string name)
	{
		super(name);
	}

	protected
	{
		/++
		 + Add unnamed a plain parameters to this array.
		 ++/
		void opOpAssign(string op : "~")(string plain)
		{
			_values ~= new PlainParameters(plain);
		}

		/++
		 + Add unnamed a plain parameters to this array.
		 ++/
		void opOpAssign(string op : "~")(Parameters param)
		{
			_values ~= param;
		}
	}

	override int opApply(scope int delegate(Parameters) dg)
	{
		int result = 0;

		foreach(value; _values)
		{
			result = dg(value);
			if(result) break;
		}

		return result;
	}

	override int opApply(scope int delegate(string, Parameters) dg)
	{
		int result = 0;

		foreach(value; _values)
		{
			result = dg(name, value);
			if(result) break;
		}

		return result;
	}

	@property
	override Parameters dup()
	{
		auto dupped = new ArrayParameters(name);
		auto copies = new Parameters[_values.length];

		foreach(idx, value; _values)
		{
			copies[idx] = value.dup;
		}

		dupped.permitted = permitted;
		dupped._values = copies;
		return dupped;
	}

	@property
	auto value()
	{
		return _values.filter!(
			parameters => parameters.permitted
		).array;
	}

	override string toString()
	{
		return format("[ %(%s, %) ]", value);
	}

}

class AssocParameters : Parameters
{

	protected
	{
		Parameters[string] _values;
	}

	alias value this;

	this()
	{
	}

	this(string name)
	{
		super(name);
	}

	protected
	{
		/++
		 + Add a plain parameters with a given name.
		 ++/
		void opIndexAssign(string plain, string name)
		{
			// Add the new parameters.
			_values[name] = new PlainParameters(name, plain);
		}

		/++
		 + Add a lazy parameters, if one doesn't already exist.
		 ++/
		void opIndexOpAssign(string op : "|")(lazy Parameters param, string name)
		{
			auto ptr = name in _values;

			if(ptr is null)
			{
				// Add the new parameters.
				_values[name] = param;
			}
		}

		/++
		 + Appends a plain parameters to an array at the given index.
		 ++/
		void opIndexOpAssign(string op : "~")(string plain, string name)
		{
			auto ptr = name in _values;

			if(ptr !is null)
			{
				auto array = cast(ArrayParameters)*ptr;
				if(array !is null) array ~= plain;
			}
			else
			{
				auto array = new ArrayParameters(name);
				_values[name] = array;
				array ~= plain;
			}
		}

		void opIndexOpAssign(string op : "~")(Parameters param, string name)
		{
			auto ptr = name in _values;

			if(ptr !is null)
			{
				auto array = cast(ArrayParameters)*ptr;
				if(array !is null) array ~= param;
			}
			else
			{
				auto array = new ArrayParameters(name);
				_values[name] = array;
				array ~= param;
			}
		}

		/++
		 + Add an assoc parameters with a given name.
		 ++/
		void opIndexAssign(AssocParameters value, string name)
		{
			AssocParameters assoc;
			auto ptr = name in _values;

			if(ptr !is null)
			{
				// Fetch the existing assoc parameters.
				assoc = cast(AssocParameters)*ptr;
				if(assoc is null) return;

				// Merge in the values.
				foreach(key, val; value._values)
				{
					assoc._values[key] = val;
				}
			}
			else
			{
				// Add the new assoc parameters.
				_values[name] = value;
			}
		}
	}

	override int opApply(scope int delegate(Parameters) dg)
	{
		int result = 0;

		foreach(value; _values)
		{
			result = dg(value);
			if(result) break;
		}

		return result;
	}

	override int opApply(scope int delegate(string, Parameters) dg)
	{
		int result = 0;

		foreach(key, value; _values)
		{
			result = dg(key, value);
			if(result) break;
		}

		return result;
	}

	@property
	override Parameters dup()
	{
		auto dupped = new AssocParameters(name);
		Parameters[string] copies;

		foreach(key, value; _values)
		{
			copies[key] = value.dup;
		}

		dupped.permitted = permitted;
		dupped._values = copies;
		return dupped;
	}

	@property
	auto value()
	{
		Parameters[string] result;

		foreach(key, value; _values)
		{
			if(value.permitted)
			{
				result[key] = value;
			}
		}

		return result;
	}

	override Parameters *opBinary(string op : "in")(string key)
	{
		return key in _values;
	}

	override auto opBinary(string op : "!in")(string key)
	{
		return key !in _values;
	}

	override Parameters opIndex(string key)
	{
		auto ptr = key in _values;
		return ptr ? *ptr : null;
	}

	override Parameters remove(string key)
	{
		auto ptr = key in this;

		if(ptr !is null)
		{
			auto value = *ptr;
			_values.remove(key);
			return value;
		}
		else
		{
			return null;
		}
	}

	override string toString()
	{
		return format("{ %(%s : %s, %) }", value);
	}

}

AssocParameters normalizeParameters(AssocParameters params, string name, string value)
{
	static auto r1 = ctRegex!(r"^[\[\]]*([^\[\]]+)\]*");
	static auto r2 = ctRegex!(r"^\[\]\[([^\[\]]+)\]$");
	static auto r3 = ctRegex!(r"^\[\](.+)$");

	Captures!string captures;
	if((captures = name.matchFirst(r1)).empty)
	{
		return params;
	}

	string key = captures[1];
	string after = captures.post;

	if(!after || after == "")
	{
		// Normal parameters.
		params[key] = value;
	}
	else if(after == "[]")
	{
		// Create if not exists and append.
		params[key] |= new ArrayParameters(key);
		params[key] ~= value;
	}
	else if(
		// Check for an assoc parameters.
		!(captures = after.matchFirst(r2)).empty ||
		!(captures = after.matchFirst(r3)).empty)
	{
		string child = captures[1];
		string rest = captures.post;

		// Create if not exists.
		params[key] |= new AssocParameters(key);
		if(
			// Check if an existing param is referenced.
			params[key].isAssocParam &&
			child in cast(AssocParameters)params[key])
		{
			// Append data for the existing parameters.
			auto param = cast(AssocParameters)params[key];
			normalizeParameters(param, child ~ rest, value);
		}
		else
		{
			// Create a new assoc parameters.
			auto param = new AssocParameters(key);
			params[key] = normalizeParameters(param, child ~ rest, value);
		}
	}
	else
	{
		params[key] |= new AssocParameters(key);
		params[key] = normalizeParameters(
			cast(AssocParameters)params[key], after, value
		);
	}

	return params;
}

@property
Parameters createParameters(string[string] params)
{
	auto assoc = new AssocParameters;

	foreach(key, value; params)
	{
		normalizeParameters(assoc, key, value);
	}

	return assoc;
}

@property
Parameters createParameters(HTTPServerRequest request)
{
	auto assoc = new AssocParameters;

	// Include URL parameters.
	foreach(key, value; request.params)
	{
		normalizeParameters(assoc, key, value);
	}

	// Include request parameters.
	foreach(key, value; request.query)
	{
		normalizeParameters(assoc, key, value);
	}

	// Include form parameters.
	foreach(key, value; request.query)
	{
		normalizeParameters(assoc, key, value);
	}

	return assoc;
}
