module gql_parser.types;

import std.sumtype;
import std.meta;

alias Option(T) = SumType!(T, typeof(null));
enum isOption(T) = is(T : Option!Arg, Arg);
template ArrayElemType(T)
{
    static if (is(T : E[], E))
    {
        alias ArrayElemType = E;
    }
}

static immutable builtinScalars = [
    "int": "Int", 
    "float": "Float", 
    "bool": "Boolean", 
    "string": "String", 
    "void": "Void"
];

static struct ParserContext {
    string[string] input_types;
    string[string] object_types;
    string[string] unions;
    string[string] enums;
    string[string] scalars;
}

enum IdentifierType {
    SCALAR,
    ENUM,
    OBJECT,
    UNION,
    INPUT_OBJECT
}