module gql_parser.gql_types.unions;

import std.sumtype;
import std.format;
import std.array : join;
import std.meta;
import std.conv : text;

import gql_parser.gql_types;

struct Union_ {
    string name;
    string[] subtypes;
}

template sumTypeSubTypeNames(Schema schema, T, int index = 0) if(isSumType!T) {
    alias subtypes = T.Types;
    static if(index >= subtypes.length) {
        alias sumTypeSubTypeNames = AliasSeq!();
    } else {
        static if(isKnownType!(schema, subtypes[index]) == GQLType.UNKNOWN) {
            enum newSchema = registerNewType!(schema, subtypes[index]);
            enum newSchema_ = registerAllUnknowTypes!(newSchema, subtypes[index]);
        } else {
            enum newSchema_ = registerAllUnknowTypes!(schema, subtypes[index]);
        }
        alias sumTypeSubTypeNames = 
            AliasSeq!(getTypeName!(newSchema_, subtypes[index]), sumTypeSubTypeNames!(newSchema_, T, index + 1));
    }
}

Schema unionFromDSumType(Schema schema, T)() {
    static assert(isSumType!T, format("expect SumType, found %s", T.stringof));
    alias subtypes = T.Types;
    // since sumtype did check the types's length, so we can assume it's not empty
    // first thing first, we make sure that all subtypes are valid types
    alias subs = sumTypeSubTypeNames!(schema, T);
    enum unionName = format("%s", join([subs], "or"));
    static if(schema.unions == null || schema.unions.length == 0) {
        return newSchemaWith(schema, 
            [T.stringof: Union_(unionName, [subs])]);
    } else {
        return newSchemaWith(schema, 
            AppendAssocArray!Union_.impl!(schema.unions, T.stringof, 
                Union_(unionName, [subs])));
    }
}

unittest 
{
    alias AAAA = SumType!(int, string, bool);
    enum schema = Schema();
    enum schema2 = unionFromDSumType!(schema, AAAA);
    static assert(schema2.unions.length == 1);
    alias BBBB = SumType!(int, string, bool, float);
    enum schema3 = unionFromDSumType!(schema2, BBBB);
    static assert(schema3.unions.length == 2);
}

string parseUnion(Union_ union_)() {
    return format("union %s = %s", union_.name, join(union_.subtypes, " | "));
}

template parseUnions(Union_[] unions, int index = 0)
{
    static if(index >= unions.length)
    {
        alias parseUnions = AliasSeq!();
    }
    else
    {
        enum parseUnions = text(
            parseUnion!(unions[index]),
            "\n",
            parseUnions!(unions, index + 1)
        );
    }
}