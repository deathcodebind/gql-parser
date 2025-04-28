module gql_parser.gql_types.common;

import std.traits;
import std.format;
import std.typetuple;
import std.sumtype;
import std.array : assocArray, appender;
import std.range : zip;
import std.conv : text;

import gql_parser.attributes;

alias Option(T) = SumType!(T, typeof(null));
enum isOption(T) = is(T : Option!Arg, Arg);
template ArrayElemType(T)
{
    static if (is(T : E[], E))
    {
        alias ArrayElemType = E;
    }
}

enum GQLType
{
    BUILTIN,
    SCALAR,
    ENUM,
    INPUT,
    OBJECT,
    UNION,
    INTERFACE,
    FRAGMENT,
    UNKNOWN
}

string documentUDAToString(document uda)()
{
    import std.array : split;
    import std.format;

    string comment_;
    enum doc_detail = uda.description;
    enum doc_lines = split(doc_detail, "\n");
    foreach (i, line; doc_lines)
    {
        if (line == "")
            continue;
        comment_ ~= format("# %s", line);
        if (i != doc_lines.length - 1)
            comment_ ~= "\n";
    }
    return comment_;
}

string handleDocument(alias T)()
{

    enum docUDAs = getUDAs!(T, document);
    static if (docUDAs.length == 1)
    {
        return documentUDAToString!(docUDAs[0]);
    }
    static if (docUDAs.length > 1)
    {
        pragma(msg,
            "[WARNING]: multi-line documentation only needs one document attribute.
using multiple document attributes will be invalid in the future version");
        string result;
        foreach (i, uda; docUDAs)
        {
            if (i < docUDAs.length && i != 0)
            {
                result ~= "\n";
            }
            result ~= documentUDAToString!uda;
        }
        return result;
    }
    return null;
}

struct Field
{
    string name;
    string typeName;
    /** 
     * even when we don't use the is_optional while schema building,
     * we still will need this when parsing query from client,
     * since the optional field could be not provided in the query.
     */
    bool is_optional;
}

template isScalar(T)
{
    enum scalar_udas = getUDAs!(T, scalar_);
    enum isScalar = scalar_udas.length == 1;
}

template isEnum(T)
{
    enum isEnum = is(T == enum);
}

template isUnion(T)
{
    enum isUnion = isSumType!T && !isOption!T;
}

template ArrayElemTypeUntilElemTypeIsNotArray(T, int depth = 0)
{
    static if (isArray!T && !is(T == string))
    {
        alias ArrayElemTypeUntilElemTypeIsNotArray = ArrayElemTypeUntilElemTypeIsNotArray!(
            ArrayElemType!T, depth + 1);
    }
    else
    {
        alias ArrayElemTypeUntilElemTypeIsNotArray = TypeTuple!(T, depth);
    }
}

template OptionElemTypeUntilElemTypeIsNotOption(T, int depth = 0)
{
    static if (isOption!T)
    {
        alias OptionElemTypeUntilElemTypeIsNotOption = OptionElemTypeUntilElemTypeIsNotOption!(T.Types[0], depth + 1);
    }
    else
    {
        alias OptionElemTypeUntilElemTypeIsNotOption = TypeTuple!(T, depth);
    }
}

template OptionOrArray(T)
{
    static if (isOption!T)
    {
        alias OptionOrArray =
            OptionElemTypeUntilElemTypeIsNotOption!T[0];
    }
    else
    {
        alias OptionOrArray =
            ArrayElemTypeUntilElemTypeIsNotArray!T[0];
    }
}

template RemoveAllArrayQualifiersAndOption(T, int depth = 0)
{
    static if (!(isOption!T || isArray!T) || is(T == string) || isConvertibleToString!T)
    {
        alias RemoveAllArrayQualifiersAndOption = TypeTuple!(T, depth);
    }
    else
    {
        alias RemoveAllArrayQualifiersAndOption = RemoveAllArrayQualifiersAndOption!(OptionOrArray!T, depth + 1);
    }

}
template typeNameFormatterImpl(T) {
    static if(isArray!T && !is(T == string)) {
        enum typeNameFormatterImpl = text("[", typeNameFormatter!(ArrayElemType!T), "]");
    } else {
        enum typeNameFormatterImpl = "%s";
    }
}
template typeNameFormatter(T) {
    static if(!isOption!T) {
        enum typeNameFormatter = text(typeNameFormatterImpl!(T), "!");
    } else {
        enum typeNameFormatter = typeNameFormatterImpl!(T.Types[0]);
    }
}

unittest
{
    alias A = int[];
    static assert(typeNameFormatter!A == "[%s!]!");
    alias B = string[][][][];
    static assert(typeNameFormatter!B == "[[[[%s!]!]!]!]!");
}


template getInnerTypeName(T) {
    enum getInnerTypeName = (RemoveAllArrayQualifiersAndOption!T)[0].stringof;
}

template isBuiltin(T)
{
    enum isBuiltin = isNumeric!T || isSomeString!T || isBoolean!T || is(T == string) || is(T == void) || isSomeChar!T;
}

template isInputType(T)
{
    enum input_udas = getUDAs!(T, input);
    enum isInputType = input_udas.length == 1;
}

template isObject(T)
{
    enum object_udas = getUDAs!(T, object_);
    enum isObject = object_udas.length == 1;
}

template isInterface(T)
{
    enum interface_udas = getUDAs!(T, interface_);
    enum isInterface = interface_udas.length == 1;
}
// only use this if you're sure that the type has a field of this name
template getFieldType(T, string name) {
    import std.traits;
    alias fields = Fields!(T);
    enum fieldNames = [FieldNameTuple!T];
    static foreach(i, name_; fieldNames) {
        static if(name_ == name) {
            alias getFieldType = fields[i];
        }
    }
}

unittest
{
    alias A = int[];
    static assert(is(ArrayElemType!A == int));
    static assert(isBuiltin!((ArrayElemTypeUntilElemTypeIsNotArray!A)[0]));
    alias B = string[][][][];
    static assert(is(ArrayElemType!B == string[][][]));
    static assert(isBuiltin!((ArrayElemTypeUntilElemTypeIsNotArray!B)[0]));
    alias C = int[2][3];
    static assert(is(ArrayElemType!C == int[2]));
    static assert(isBuiltin!((ArrayElemTypeUntilElemTypeIsNotArray!C)[0]));
}

string inputAttrToString(T)()
{
    static assert(isInputType!T, format("type %s is not a input type", T.stringof));
    enum input_udas = getUDAs!(T, input);
    static assert(input_udas.length == 1, "input type should have only one input attribute");
    return input_udas[0].name;
}

static immutable builtinScalars = [
    "int": "Int",
    "float": "Float",
    "bool": "Boolean",
    "string": "String",
    "void": "Void"
];

struct ArrayToAliasSeq(T) {
    template impl(T[] arr, int index = 0)
    {
        static if(index >= arr.length)
        {
            alias impl = AliasSeq!();
        }
        else
        {
            alias impl = AliasSeq!(arr[index], impl!(arr, index + 1));
        }
    }
}

struct AppendAssocArray(T) {
    static T[string] impl(T[string] arr, string key, T value)() {
        static if(arr.length == 0) {
            return assocArray(zip([key], [value]));
        } else {
            return assocArray(zip(
                [AliasSeq!(ArrayToAliasSeq!string.impl!(arr.keys), key)],
                [AliasSeq!(ArrayToAliasSeq!T.impl!(arr.values), value)]));
        }
    }
}

unittest
{
    enum arr = ["a": 1, "b": 2, "c": 3];
    enum arr2 = AppendAssocArray!int.impl!(arr, "d", 4);
    static assert(arr2.length == 4);
    static assert(arr2["a"] == 1);
    static assert(arr2["b"] == 2);
    static assert(arr2["c"] == 3);
    static assert(arr2["d"] == 4);
}

