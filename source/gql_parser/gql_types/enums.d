module gql_parser.gql_types.enums;

import std.traits;
import std.range : zip;
import std.array :assocArray, join;
import std.format;
import std.meta;
import std.conv : text;

import gql_parser.gql_types;
import gql_parser.attributes : enum_;

struct Enum_ {
    string name;
    string[] fields;
    string comment = null;
}

template enumFields(T, int index = 0) if(is(T == enum)){
    enum efs = EnumMembers!T;
    static assert(efs.length > 0, "empty enum is not allowed");
    static if(index >= efs.length) {
        alias enumFields = AliasSeq!();
    } else {
        alias enumFields = AliasSeq!(efs[index], enumFields!(T, index + 1));
    }
}

// since enum should not contain any unknown types, so just one template is enough
Schema enumFromDType(Schema schema, T)() {
    static assert(isConvertibleToString!T, format("type %s does not extend string"));
    alias fields = enumFields!T;
    enum enum_udas = getUDAs!(T, enum_);
    static assert(enum_udas.length == 1, "one and only one enum_ attribute is needed for a enum type");
    static if(enum_udas[0].name != null) {
        enum name = enum_udas[0].name;
    } else {
        enum name = T.stringof;
    }
    enum e = Enum_(name, [fields], handleDocument!T);
    static if(schema.enums == null || schema.enums.length == 0) {
        return newSchemaWith(schema, [T.stringof: e]);
    } else {
        return newSchemaWith(schema, AppendAssocArray!Enum_.impl!(schema.enums, T.stringof, e));
    }    
}

string parseEnum(Enum_ enum_)() {
    return text(
        "enum ",
        enum_.name,
        " {\n",
        "    ",
        enum_.fields.join("\n    "),
        "\n}"
    );
}

template parseEnums(Enum_[] enums, int index = 0)
{
    static if(index >= enums.length)
    {
        alias parseEnums = AliasSeq!();
    }
    else
    {
        enum parseEnums = text(
            parseEnum!(enums[index]),
            "\n",
            parseEnums!(enums, index + 1)
        );
    }
}


unittest
{
    @enum_() enum E1 : string{
        A = "a",
        B = "b",
        C = "c"
    }
    @enum_() enum E2 : string{
        A = "a",
        B = "b",
        C = "c"
    }
    enum schema = Schema();
    enum schema2 = enumFromDType!(schema, E1);
    enum schema3 = enumFromDType!(schema2, E2);
    static assert(schema2.enums.length == 1);
    static assert(schema3.enums.length == 2);
}