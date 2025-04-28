module gql_parser.gql_types.scalar;

import std.traits : getUDAs;
import std.format;
import std.meta;
import std.conv : text;

import gql_parser.attributes : scalar_;
import gql_parser.gql_types.common : handleDocument;

struct Scalar {
    string name;
    string comment = null;
}

Scalar scalarFromDtype(T)() {
    enum scalarUDAs = getUDAs!(T, scalar_);
    static assert(scalarUDAs.length == 1, "Scalar type must have exactly one scalar_ attribute");
    return Scalar(scalarUDAs[0].name, handleDocument!T);
}

string parseScalar(Scalar scalar)() {
    return format("%s\nscalar %s", scalar.comment, scalar.name);
}

template parseScalars(Scalar[] scalars, int index = 0)
{
    static if(index >= scalars.length)
    {
        alias parseScalars = AliasSeq!();
    }
    else
    {
        enum parseScalars = text(parseScalar!(scalars[index]), "\n", parseScalars!(scalars, index + 1));
    }
}