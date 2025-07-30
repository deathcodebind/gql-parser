module gql_parser.serialize.json;

import std.json;
import std.traits;
import std.stdio;
import std.algorithm;
import std.conv : to;

mixin template Serialize(T)
{
    JSONValue serialize()
    {
        auto eo = JSONValue.emptyObject;
        foreach (index, field; FieldNameTuple!T)
        {
            eo[field] = this.tupleof[index];
        }

        return eo;
    }
}

string dTypeNameToJSONTypeName(T)()
{
    static if (isUnsigned!T)
    {
        return ".uinteger()";
    }
    else static if (isIntegral!T)
    {
        return ".integer()";
    }
    else static if (isFloatingPoint!T)
    {
        return ".floating()";
    }
    else static if (isBoolean!T)
    {
        return ".boolean()";
    }
    else static if (isSomeString!T)
    {
        return ".str()";
    }
    else
    {
        return "";
    }
}

mixin template Deserialize(T)
{
    void deserialize(JSONValue json)
    {
        alias FieldTypes = FieldTypeTuple!T;
        if (json.type != JSONType.object)
        {
            throw new Exception("JSON value is not an object");
        }
        foreach (index, fieldName; FieldNameTuple!T)
        {
            if (!json.object.keys.canFind(fieldName))
            {
                throw new Exception("JSON object is missing field: " ~ fieldName);
            }
            mixin("this.tupleof[index] = to!(" ~ FieldTypes[index].stringof ~ ")(json[fieldName]" ~ dTypeNameToJSONTypeName!(
                    FieldTypes[index]) ~ ");");
        }
    }
}

unittest
{
    struct S
    {
        int a;
        string b;
        bool c;
        mixin Serialize!S;
        mixin Deserialize!S;
    }

    S s = S(1, "hello", true);
    auto serialized = s.serialize();
    assert(serialized.toString() == "{\"a\":1,\"b\":\"hello\",\"c\":true}");
    serialized["a"] = 2;
    s.deserialize(serialized);
    assert(s.a == 2);
}
