
module vibrant.parameters;

import std.algorithm;
import std.array;
import std.conv;
import std.regex;
import std.string;

import vibe.d;

/++
 + Alias for isA!(Type).
 ++/
@property
alias isAn(Type) = isA!Type;

/++
 + Returns true if the parameter value is convertible to the given type.
 ++/
@property
bool isA(Type)(Parameter parameter)
{
	if(parameter.isPlainParam)
	{
		try
		{
			auto plain = cast(PlainParameter)parameter;
			plain.value.to!Type;
			return true;
		}
		catch(ConvException e)
		{
			return false;
		}
	}
	else if(parameter.isArrayParam)
	{
		return is(Type == ArrayParameter) || is(Type == Parameter[]);
	}
	else if(parameter.isAssocParam)
	{
		return is(Type == AssocParameter) || is(Type == Parameter[string]);
	}
	else
	{
		return false;
	}
}

/++
 + Converts the parameter's value to the given type.
 +
 + Throws:
 +     std.conv.ConvException
 ++/
@property
Type as(Type)(Parameter parameter)
{
	if(parameter.isPlainParam)
	{
		auto plain = cast(PlainParameter)parameter;
		return plain.value.to!Type;
	}
	else if(parameter.isArrayParam)
	{
		auto array = cast(ArrayParameter)parameter;

		static if(is(Type == ArrayParameter))
		{
			return array;
		}
		else static if(is(Type == Parameter[]))
		{
			return array.value;
		}
	}
	else if(parameter.isAssocParam)
	{
		auto assoc = cast(AssocParameter)parameter;

		static if(is(Type == AssocParameter))
		{
			return assoc;
		}
		else static if(is(Type == Parameter[string]))
		{
			return assoc.value;
		}
	}

	// Cannot convert, throw a conversion exception.
	throw new ConvException("Cannot convert to " ~ Type.stringof);
}

/++
 + Returns true if the parameter is a plain value.
 ++/
@property
bool isPlainParam(Parameter parameter)
{
	return cast(PlainParameter)parameter !is null;
}

/++
 + Returns true if the parameter is an array of values.
 ++/
@property
bool isArrayParam(Parameter parameter)
{
	return cast(ArrayParameter)parameter !is null;
}

/++
 + Returns true if the parameter is an associative array of values.
 ++/
@property
bool isAssocParam(Parameter parameter)
{
	return cast(AssocParameter)parameter !is null;
}

class ParameterMissing : Exception
{

	this(string name)
	{
		super("Missing parameter: " ~ name);
	}

}

/++
 + Abstract parameter parent type.
 + Defines functions and properties common to all parameter.
 ++/
abstract class Parameter
{

	private
	{
		/++
		 + The name of the parameter.
		 ++/
		string _name;

		/++
		 + Flag for parameter permitted state.
		 ++/
		bool _permitted;
	}

	/++
	 + Constructs a new unnamed parameter.
	 ++/
	this()
	{
	}

	/++
	 + Constructs a new named parameter.
	 +
	 + Params:
	 +     name = The name of the parameter.
	 ++/
	this(string name)
	{
		this._name = name;
	}

	/+
	 + Impl for permit.
	 +/
	private
	{
		import std.traits;

		/++
		 + Permit a parameter by name.
		 ++/
		static void _permit(T)(Parameter current, T key)
		if(isSomeString!T)
		{
			if(current is null) return;
			auto target = current[key];

			if(target !is null && !target.isAssocParam)
			{
				target.permit;
			}
		}

		/++
		 + Permit parameter by array of names.
		 ++/
		static void _permit(T)(Parameter current, T keys)
		if(isArray!T && !isSomeString!T)
		{
			if(current is null) return;

			foreach(key; keys)
			{
				_permit(current, key);
			}
		}

		/++
		 + Permit parameter by assoc array of names.
		 ++/
		static void _permit(T)(Parameter current, T keys)
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

	abstract
	{

		/++
		 + Returns a copy of the parameter.
		 ++/
		@property
		Parameter dup();

		/++
		 + Iterates over the parameter.
		 ++/
		int opApply(scope int delegate(Parameter) dg);

		/++
		 + Iterates over the parameter.
		 ++/
		int opApply(scope int delegate(string, Parameter) dg);

	}

	/++
	 + Returns the name of the parameter.
	 ++/
	@property
	final string name()
	{
		return _name;
	}

	/++
	 + Returns a pointer to a child parameter at key, if one exists.
	 ++/
	Parameter *opBinaryRight(string op : "in")(string key)
	{
		return null;
	}

	/++
	 + Returns true if no child parameter exists at key.
	 ++/
	bool opBinaryRight(string op : "!in")(string key)
	{
		return true;
	}

	/++
	 + Returns the parameter converted to the given type.
	 ++/
	Type opCast(Type)()
	{
		return this.as!Type;
	}

	/++
	 + Returns the child parameter at key, or null.
	 ++/
	Parameter opIndex(string key)
	{
		return null;
	}

	/++
	 + Permits this parameter.
	 ++/
	Parameter permit()
	{
		_permitted = true;
		return this;
	}

	/++
	 + Permits parameter and their children by name.
	 ++/
	Parameter permit(TList...)(TList keys)
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

	/++
	 + Returns true if the parameter has been permitted.
	 ++/
	@property
	bool permitted()
	{
		return _permitted;
	}

	/++
	 + Sets the permitted state of the parameter.
	 ++/
	@property
	protected void permitted(bool permitted)
	{
		this._permitted = permitted;
	}

	/++
	 + Removes and returns a child parameter at key.
	 ++/
	Parameter remove(string key)
	{
		return null;
	}

	/++
	 + Requires the presence of a parameter denoted by key.
	 + If one exists, it is returned, else ParameterMissing is raised.
	 ++/
	Parameter require(string key)
	{
		auto required = this[key];

		if(required is null)
		{
			throw new ParameterMissing(key);
		}
		else
		{
			return required;
		}
	}

}

class PlainParameter : Parameter
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

	/++
	 + Returns a copy of the parameter.
	 ++/
	@property
	override Parameter dup()
	{
		auto dupped = new PlainParameter(name, value);
		dupped.permitted = permitted;
		return dupped;
	}

	/++
	 + Iterates over the parameter.
	 ++/
	override int opApply(scope int delegate(Parameter) dg)
	{
		return dg(this);
	}

	/++
	 + Iterates over the parameter.
	 ++/
	override int opApply(scope int delegate(string, Parameter) dg)
	{
		return dg(name, this);
	}

	/++
	 + Returns the value of the parameter.
	 ++/
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

class ArrayParameter : Parameter
{

	protected
	{
		Parameter[] _values;
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
		 + Add unnamed a plain parameter to this array.
		 ++/
		void opOpAssign(string op : "~")(string plain)
		{
			_values ~= new PlainParameter(plain);
		}

		/++
		 + Add unnamed a plain parameter to this array.
		 ++/
		void opOpAssign(string op : "~")(Parameter param)
		{
			_values ~= param;
		}
	}

	/++
	 + Returns a copy of the parameter.
	 ++/
	@property
	override Parameter dup()
	{
		auto dupped = new ArrayParameter(name);
		auto copies = new Parameter[_values.length];

		foreach(idx, value; _values)
		{
			copies[idx] = value.dup;
		}

		dupped.permitted = permitted;
		dupped._values = copies;
		return dupped;
	}

	/++
	 + Iterates over the parameter.
	 ++/
	override int opApply(scope int delegate(Parameter) dg)
	{
		int result = 0;

		foreach(value; _values)
		{
			result = dg(value);
			if(result) break;
		}

		return result;
	}

	/++
	 + Iterates over the parameter.
	 ++/
	override int opApply(scope int delegate(string, Parameter) dg)
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
	auto value()
	{
		return _values.filter!(
			parameter => parameter.permitted
		).array;
	}

	override string toString()
	{
		return format("[ %(%s, %) ]", value);
	}

}

class AssocParameter : Parameter
{

	protected
	{
		Parameter[string] _values;
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
		 + Add a plain parameter with a given name.
		 ++/
		void opIndexAssign(string plain, string name)
		{
			// Add the new parameter.
			_values[name] = new PlainParameter(name, plain);
		}

		/++
		 + Add a lazy parameter, if one doesn't already exist.
		 ++/
		void opIndexOpAssign(string op : "|")(lazy Parameter param, string name)
		{
			auto ptr = name in _values;

			if(ptr is null)
			{
				// Add the new parameter.
				_values[name] = param;
			}
		}

		/++
		 + Appends a plain parameter to an array at the given index.
		 ++/
		void opIndexOpAssign(string op : "~")(string plain, string name)
		{
			auto ptr = name in _values;

			if(ptr !is null)
			{
				auto array = cast(ArrayParameter)*ptr;
				if(array !is null) array ~= plain;
			}
			else
			{
				auto array = new ArrayParameter(name);
				_values[name] = array;
				array ~= plain;
			}
		}

		void opIndexOpAssign(string op : "~")(Parameter param, string name)
		{
			auto ptr = name in _values;

			if(ptr !is null)
			{
				auto array = cast(ArrayParameter)*ptr;
				if(array !is null) array ~= param;
			}
			else
			{
				auto array = new ArrayParameter(name);
				_values[name] = array;
				array ~= param;
			}
		}

		/++
		 + Add an assoc parameter with a given name.
		 ++/
		void opIndexAssign(AssocParameter value, string name)
		{
			AssocParameter assoc;
			auto ptr = name in _values;

			if(ptr !is null)
			{
				// Fetch the existing assoc parameter.
				assoc = cast(AssocParameter)*ptr;
				if(assoc is null) return;

				// Merge in the values.
				foreach(key, val; value._values)
				{
					assoc._values[key] = val;
				}
			}
			else
			{
				// Add the new assoc parameter.
				_values[name] = value;
			}
		}
	}

	/++
	 + Returns a copy of the parameter.
	 ++/
	@property
	override Parameter dup()
	{
		auto dupped = new AssocParameter(name);
		Parameter[string] copies;

		foreach(key, value; _values)
		{
			copies[key] = value.dup;
		}

		dupped.permitted = permitted;
		dupped._values = copies;
		return dupped;
	}

	/++
	 + Iterates over the parameter.
	 ++/
	override int opApply(scope int delegate(Parameter) dg)
	{
		int result = 0;

		foreach(value; _values)
		{
			result = dg(value);
			if(result) break;
		}

		return result;
	}

	/++
	 + Iterates over the parameter.
	 ++/
	override int opApply(scope int delegate(string, Parameter) dg)
	{
		int result = 0;

		foreach(key, value; _values)
		{
			result = dg(key, value);
			if(result) break;
		}

		return result;
	}

	/++
	 + Returns child parameters.
	 ++/
	@property
	auto value()
	{
		Parameter[string] result;

		foreach(key, value; _values)
		{
			if(value.permitted)
			{
				result[key] = value;
			}
		}

		return result;
	}

	/++
	 + Returns a pointer to a child parameter at key, if one exists.
	 ++/
	override Parameter *opBinary(string op : "in")(string key)
	{
		return key in _values;
	}

	/++
	 + Returns true if no child parameter exists at key.
	 ++/
	override auto opBinary(string op : "!in")(string key)
	{
		return key !in _values;
	}

	/++
	 + Returns the child parameter at key, or null.
	 ++/
	override Parameter opIndex(string key)
	{
		auto ptr = key in _values;
		return ptr ? *ptr : null;
	}

	/++
	 + Removes and returns a child parameter at key.
	 ++/
	override Parameter remove(string key)
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

AssocParameter normalizeParameters(AssocParameter params, string name, string value)
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
		// Normal parameter.
		params[key] = value;
	}
	else if(after == "[]")
	{
		// Create if not exists and append.
		params[key] |= new ArrayParameter(key);
		params[key] ~= value;
	}
	else if(
		// Check for an assoc parameter.
		!(captures = after.matchFirst(r2)).empty ||
		!(captures = after.matchFirst(r3)).empty)
	{
		string child = captures[1];
		string rest = captures.post;

		// Create if not exists.
		params[key] |= new AssocParameter(key);
		if(
			// Check if an existing param is referenced.
			params[key].isAssocParam &&
			child in cast(AssocParameter)params[key])
		{
			// Append data for the existing parameter.
			auto param = cast(AssocParameter)params[key];
			normalizeParameters(param, child ~ rest, value);
		}
		else
		{
			// Create a new assoc parameter.
			auto param = new AssocParameter(key);
			params[key] = normalizeParameters(param, child ~ rest, value);
		}
	}
	else
	{
		params[key] |= new AssocParameter(key);
		params[key] = normalizeParameters(
			cast(AssocParameter)params[key], after, value
		);
	}

	return params;
}

@property
Parameter createParameters(string[string] params)
{
	auto assoc = new AssocParameter;

	foreach(key, value; params)
	{
		normalizeParameters(assoc, key, value);
	}

	return assoc;
}

@property
Parameter createParameters(HTTPServerRequest request)
{
	auto assoc = new AssocParameter;

	// Include URL parameter.
	foreach(key, value; request.params)
	{
		normalizeParameters(assoc, key, value);
	}

	// Include request parameter.
	foreach(key, value; request.query)
	{
		normalizeParameters(assoc, key, value);
	}

	// Include form parameter.
	foreach(key, value; request.query)
	{
		normalizeParameters(assoc, key, value);
	}

	return assoc;
}
