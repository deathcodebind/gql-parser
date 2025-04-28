module gql_parser.gql_types.custom_type;

import std.traits;
import std.format;
import std.array : assocArray, join;
import std.range : zip;
import std.bitmanip;
import std.algorithm : canFind, find;
import std.meta;
import std.conv : text;

import gql_parser.gql_types.common;
import gql_parser.gql_types.schema;
import gql_parser.attributes : input, object_, impls, interface_, document;

void interfaceCheker(T)()
{
    import std.format;
    import std.traits;
    import std.algorithm : canFind;

    enum udas = getUDAs!(T, impls);
    static assert(udas.length != 0,
        format("type %s is not implement anything, maybe you don't needed to check that", T
            .stringof));
    enum fieldNames = [FieldNameTuple!T];
    alias fields = Fields!(T);
    static foreach (uda; udas)
    {
        static foreach (i, name; FieldNameTuple!(uda.Inner))
        {
            static assert(canFind(fieldNames, name),
                format("type %s doesn't have field %s", T.stringof, name));
            static assert(is(getFieldType!(T, name) == Fields!(uda.Inner)[i]),
                format("field %s from interface is type %s, not %s",
                    name, Fields!(uda.Inner)[i].stringof, getFieldType!(T, name).stringof));
        }
    }
}

enum ValidCustomType : int
{
    Input = 0,
    Object,
    Interface,
    InValid
}

enum ValidCustomTypes : int
{
    RequestParam = 0,
    ResponseParam,
    Invalid
}
/*
  CustomType mixin template
  also a fragment in dlang lol
*/
mixin template CustomType()
{
    string name;
    Field[] fields;
    string comment = null;
}

template parseFieldsImpl(Field[] fields, int index) {
    static if(index >= fields.length) {
        alias parseFieldsImpl = AliasSeq!();
    } else {
        enum current = text(
            fields[index].typeName, " ",
            fields[index].name
        );
        alias parseFieldsImpl = AliasSeq!(current, parseFieldsImpl!(fields, index + 1));
    }
}

string parseFields(Field[] fields)()
{
    static assert(fields.length > 0, "fields is empty");
    alias fields_parsed = parseFieldsImpl!(fields, 0);
    return join([fields_parsed], "\n");
}

struct Input
{
    mixin CustomType;
}

string parseInput(Input input)()
{
    enum fields_parsed = parseFields!(input.fields);
    static if (input.comment == null)
    {
        return format("input %s{\n    %s\n}", input.name, fields_parsed);
    }
    else
    {
        return format("%s\ninput %s{
    %s
}", input.comment, input.name, fields_parsed);
    }
}

template parseInputs(Input[] inputs, int index = 0)
{
    static if(index >= inputs.length)
    {
        alias parseInputs = AliasSeq!();
    }
    else 
    {
        enum parseInputs = text(parseInput!(inputs[index]), "\n", parseInputs!(inputs, index + 1));
    }
}

unittest
{
    @input("3A") class AAA {
        int a;
    }
    enum schema = Schema();
    enum schema_ = inputTypeFromDtype!(schema, AAA);
    enum parsed = parseInput!(schema_.inputs[AAA.stringof]);
    enum expected = "input 3A{\n    Int! a\n}";
    static assert(parsed == expected);
}

unittest
{
    @input("3A") @document("comment") class AAA {
        int a;
    }
    enum schema = Schema();
    enum schema_ = inputTypeFromDtype!(schema, AAA);
    enum parsed = parseInput!(schema_.inputs[AAA.stringof]);
    enum expected = "# comment\ninput 3A{\n    Int! a\n}";
    static assert(parsed == expected);
}

struct Interface_
{
    Interface_[] interfaces;
    mixin CustomType;
}

string parseInterface(Interface_ interface_)() {
    enum fields_parsed = parseFields!(interface_.fields);
    static if (interface_.comment == null)
    {
        return format("interface %s{\n    %s\n}", interface_.name, fields_parsed);
    }
    else
    {
        return format("%s\ninterface %s{
    %s
}", interface_.comment, interface_.name, fields_parsed);
    }
}

template parseInterfaces(Interface_[] interfaces, int index = 0)
{
    static if(index >= interfaces.length)
    {
        alias parseInterfaces = AliasSeq!();
    }
    else 
    {
        enum parseInterfaces = text(parseInterface!(interfaces[index]), "\n", parseInterfaces!(interfaces, index + 1));
    }
}

unittest
{
    @interface_("3A") @document("comment") class AAA {
        int a;
    }
    enum schema = Schema();
    enum schema_ = interfaceFromDType!(schema, AAA);
    enum parsed = parseInterface!(schema_.interfaces[AAA.stringof]);
    enum expected = "# comment\ninterface 3A{\n    Int! a\n}";
    static assert(parsed == expected);
}

struct Object_
{
    Interface_[] interfaces;
    mixin CustomType;
}

string parseObject(Object_ object_)() {
    enum fields_parsed = parseFields!(object_.fields);
    static if (object_.comment == null)
    {
        return format("type %s{\n    %s\n}", object_.name, fields_parsed);
    }
    else
    {
        return format("%s\ntype %s{
    %s
}", object_.comment, object_.name, fields_parsed);
    }
}

template parseObjects(Object_[] objects, int index = 0)
{
    static if(index >= objects.length)
    {
        alias parseObjects = AliasSeq!();
    }
    else 
    {
        enum parseObjects = text(parseObject!(objects[index]), "\n", parseObjects!(objects, index + 1));
    }
}

unittest
{
    @object_("3A") @document("comment") class AAA {
        int a;
    }
    enum schema = Schema();
    enum schema_ = objectFromDType!(schema, AAA);
    enum parsed = parseObject!(schema_.types[AAA.stringof]);
    enum expected = "# comment\ntype 3A{\n    Int! a\n}";
    static assert(parsed == expected);
}
/*
  Fragments usually is generated using template
  so don't worry about the original type's corrections
*/
struct Fragment
{
    /* the name of the original type of this fragment*/
    string origin;
    mixin CustomType;
}

template isCustomType(T)
{
    enum isCustomType = (is(T == class) || is(T == struct)) && !isScalar!T;
}

template getAllUnknowTypes(Schema schema, T, int index = 0)
{
    alias fields_ = Fields!T;
    alias fieldNames = FieldNameTuple!T;
    static if (index >= fieldNames.length) {
        alias getAllUnknowTypes = AliasSeq!();
    } else {
        static if (isKnownType!(schema, fields_[index]) != GQLType.UNKNOWN)
        {
            alias getAllUnknowTypes = AliasSeq!(getAllUnknowTypes!(schema, T, index + 1));
        }
        else
        {
            alias getAllUnknowTypes = AliasSeq!(index, getAllUnknowTypes!(schema, T, index + 1));
        }
    }
}


unittest
{
    @input() class A
    {
        int a;
    }

    @input() class AAA
    {
        A a;
    }

    enum schema = Schema();
    enum unknowns = getAllUnknowTypes!(schema, AAA);
    static assert(unknowns[0] == 0);
}

bool handleUnknownTypes(Schema schema, T)()
{
    enum unknownTypes = getAllUnknowTypes!(schema, T);
    return unknownTypes.length != 0;
}

template registerAllUnknowTypes(Schema schema, T, int index = 0)
{
    alias fields_ = Fields!T;
    enum fieldNames = FieldNameTuple!T;
    enum unknowns = getAllUnknowTypes!(schema, T);
    static if(index >= unknowns.length)
    {
        alias registerAllUnknowTypes = schema;
    } else {
        enum unknowns_index = unknowns[index];
        alias unknownType = fields_[unknowns_index];
        alias registerAllUnknowTypes = 
            registerAllUnknowTypes!(registerNewType!(schema, unknownType), T, index + 1);
    }
}

unittest
{
    @input() class A
    {
        int a;
    }

    @input() class AAA
    {
        A a;
        int b;
    }

    enum schema = Schema();
    enum schema_ = inputTypeFromDtype!(schema, AAA);
    static assert(schema_.inputs.length == 2);
}

template genFields(Schema schema, T, int index = 0)
{
    alias fields_ = Fields!T;
    alias fieldNames = FieldNameTuple!T;
    static if(index >= fields_.length)
    {
        alias genFields = AliasSeq!();
    } else {
        enum isOptional = isOption!(fields_[index]);
        enum field = Field(fieldNames[index], getTypeName!(schema, fields_[index]), isOptional);
        alias genFields = AliasSeq!(field, genFields!(schema, T, index + 1));
    }
}

unittest
{
    @input() class A
    {
        int a;
    }

    @input() class AAA
    {
        A a;
        int b;
    }

    enum schema = Schema();
    enum schema_ = registerAllUnknowTypes!(schema, AAA);
    enum fields = genFields!(schema_, AAA);
    static assert(fields.length == 2);
    static assert(fields[0].name == "a" && fields[0].typeName == "A!" && fields[0].is_optional == false);
    static assert(fields[1].name == "b" && fields[1].typeName == "Int!" && fields[1].is_optional == false);
}

private Input inputWithoutUnknownType(Schema schema, T, string name)()
{
    alias fields_ = Fields!T;
    alias fieldNames = FieldNameTuple!T;
    Input result = Input(name, [genFields!(schema, T)], handleDocument!T);
    return result;
}

Schema inputTypeFromDtype(Schema schema, T)()
{
    enum input_udas = getUDAs!(T, input);
    static assert(input_udas.length == 1,
        "one and only one input attribute is needed to mark this type as a input type");
    static if (handleUnknownTypes!(schema, T))
    {
        enum schemaTypeFixed = registerAllUnknowTypes!(schema, T);
    }
    else
    {
        enum schemaTypeFixed = schema;
    }
    return newSchemaWith(schemaTypeFixed, 
        AppendAssocArray!Input.impl!(schemaTypeFixed.inputs, T.stringof,inputWithoutUnknownType!(
            schemaTypeFixed, T, input_udas[0].name == "" ? T.stringof : input_udas[0].name)));
    // return newSchemaWith(schemaTypeFixed,
    //     assocArray(zip((schemaTypeFixed.inputs.keys == null ? [] : schemaTypeFixed.inputs.keys) ~ T.stringof,
    //         (schemaTypeFixed.inputs.values == null ? [] : schemaTypeFixed.inputs.values) ~
    //         inputWithoutUnknownType!(
    //         schemaTypeFixed, T, input_udas[0].name == "" ? T.stringof : input_udas[0].name))));
}

unittest
{
    @input("3A") class AAA
    {
        int a;
    }

    enum schema = Schema();
    enum schema_ = inputTypeFromDtype!(schema, AAA);
    static assert(schema_.inputs.length == 1);
}

Schema interfacesFromDType(Schema schema, T, int index = 0)()
{
    enum interface_udas = getUDAs!(T, impls);
    static if(index >= interface_udas.length) {
        return schema;
    } else {
        static if(!canFind(schema.interfaces.keys, interface_udas[index].Inner.stringof)) {
            enum newSchema = registerNewType!(schema, interface_udas[index].Inner);
        } else {
            enum newSchema = schema;
        }
        return interfacesFromDType!(newSchema, T, index + 1);
    }
}
template getInterfacesImpl(Schema schema, T, int index = 0)
{
    enum interface_udas = getUDAs!(T, impls);
    static if(index >= interface_udas.length) {
        alias getInterfacesImpl = AliasSeq!();
    } else {
        static if(!canFind(schema.interfaces.keys, interface_udas[index].Inner.stringof)) {
            alias getInterfacesImpl = AliasSeq!(interface_udas[index].Inner, getInterfacesImpl!(schema, T, index + 1));
        } else {
            alias getInterfacesImpl = AliasSeq!(getInterfacesImpl!(schema, T, index + 1));
        }
    }
}

Interface_[] getInterfaces(Schema schema, T)()
{
    alias interfaces = getInterfacesImpl!(schema, T);
    return [interfaces];
}

Interface_ interfaceWithoutUnknownType(Schema schema, T)()
{
    enum interface_udas = getUDAs!(T, impls);
    static if (interface_udas.length >= 1)
    {
        interfaceCheker!T;
    }
    alias fields_ = Fields!T;
    alias fieldNames = FieldNameTuple!T;
    enum name_udas = getUDAs!(T, interface_);
    static if(name_udas.length == 1) {
        enum name = name_udas[0].name == "" ? T.stringof : name_udas[0].name;
    } else {
        enum name = T.stringof;
    }
    Interface_ result = Interface_(getInterfaces!(schema, T), name, [genFields!(schema, T)], handleDocument!T);
    return result;
}

Schema interfaceFromDType(Schema schema, T)()
{
    enum interface_udas = getUDAs!(T, interface_);
    static assert(interface_udas.length == 1,
        "one and only one interface attribute is needed to mark this type as a interface type");
    static if (!handleUnknownTypes!(schema, T))
    {
        enum schemaTypeFixed = registerAllUnknowTypes!(schema, T);
    }
    else
    {
        enum schemaTypeFixed = schema;
    }
    enum schemaAllFixed = interfacesFromDType!(schemaTypeFixed, T);
    static if(schemaAllFixed.interfaces.length > 0) {
        return newSchemaWith(schemaAllFixed,
            AppendAssocArray!Interface_.impl!(
                schemaAllFixed.interfaces, T.stringof, interfaceWithoutUnknownType!(schemaAllFixed, T)));
    } else {
        return newSchemaWith(schemaAllFixed, [T.stringof: interfaceWithoutUnknownType!(schemaAllFixed, T)]);
    }
}

unittest
{
    enum schema = Schema();
    @interface_() class A
    {
        int a;
    }

    @impls!A() @interface_() class B
    {
        int a;
        int b;
    }

    enum schema_ = interfaceFromDType!(schema, B);
    static assert(schema_.interfaces.length == 2);
}

Object_ objectWithoutUnknownType(Schema schema, T)()
{
    enum object_udas = getUDAs!(T, object_);
    alias fields_ = Fields!T;
    alias fieldNames = FieldNameTuple!T;
    Object_ result = Object_(getInterfaces!(schema, T), object_udas[0].name, [genFields!(schema, T)], handleDocument!T);
    return result;
}

Schema objectFromDType(Schema schema, T)()
{
    static assert(isObject!T, format("type %s is not an object type", T.stringof));
    static if (handleUnknownTypes!(schema, T))
    {
        enum schemaTypeFixed = registerAllUnknowTypes!(schema, T);
    }
    else
    {
        enum schemaTypeFixed = schema;
    }
    enum schemaAllFixed = interfacesFromDType!(schemaTypeFixed, T);
    static if(schemaAllFixed.types.length > 0) {
        return newSchemaWith(schemaAllFixed,
            AppendAssocArray!Object_.impl!(
                schemaAllFixed.types, T.stringof, objectWithoutUnknownType!(schemaAllFixed, T)));
    } else {
        return newSchemaWith(schemaAllFixed, [T.stringof: objectWithoutUnknownType!(schemaAllFixed, T)]);
    }
}

unittest
{
    enum schema = Schema();
    @interface_() class A
    {
        int a;
    }

    @impls!A() @interface_() class B
    {
        int a;
        int b;
    }

    @impls!B() @object_() class C
    {
        int a;
        int b;
    }

    enum schema_ = objectFromDType!(schema, C);
    static assert(schema_.types.length == 1);
    static assert(schema_.interfaces.length == 2);
}

unittest
{
    enum schema = Schema();
    @interface_() class A
    {
        int a;
    }

    @interface_() class B
    {
        int b;
    }

    @impls!A() @impls!B() @object_() class C
    {
        int a;
        int b;
    }

    enum schema_ = objectFromDType!(schema, C);
    static assert(schema_.types.length == 1);
    static assert(schema_.interfaces.length == 2);
}
