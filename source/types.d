module gql_parser.types;

import std.sumtype;

alias Option(T) = SumType!(T, typeof(null));
enum isOption(T) = is(T : Option!Arg, Arg);
template ArrayElemType(T)
{
    static if (is(T : E[], E))
    {
        alias ArrayElemType = E;
    }
}
static immutable builtinTypes = ["int": "Int", "float": "Float", "bool": "Boolean", "string": "String", "void": "Void"];
