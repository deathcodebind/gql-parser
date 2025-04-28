module gql_parser.gql_types.schema;

import std.sumtype;
import std.algorithm : canFind;
import std.format;
import std.traits;

import gql_parser.gql_types;

struct Schema
{
    static immutable string[string] builtinTypes = builtinScalars;
    Scalar[string] scalars;
    Interface_[string] interfaces;
    Union_[string] unions;
    Enum_[string] enums;
    Input[string] inputs;
    // Framgment[] fragments;
    Object_[string] types;
    Request[string] query;
    Request[string] mutation;
}

Schema newSchemaWith(Schema schema, Scalar[string] scalars)
{
    return Schema(scalars,
        schema.interfaces,
        schema.unions,
        schema.enums,
        schema.inputs,
        /*schema.fragments,*/
        schema.types,
        schema.query,
        schema.mutation
    );
}

Schema newSchemaWith(Schema schema, Input[string] inputs)
{
    return Schema(schema.scalars,
        schema.interfaces,
        schema.unions,
        schema.enums,
        inputs,
        /*schema.fragments,*/
        schema.types,
        schema.query,
        schema.mutation
    );
}

Schema newSchemaWith(Schema schema, Interface_[string] interfaces) {
    return Schema(schema.scalars,
    interfaces,
    schema.unions, 
    schema.enums, 
    schema.inputs, 
    // schema.fragments,
    schema.types,
    schema.query,
    schema.mutation
    );
}

Schema newSchemaWith(Schema schema, Union_[string] unions) {
    return Schema(schema.scalars,
    schema.interfaces,
    unions, 
    schema.enums, 
    schema.inputs, 
    // schema.fragments,
    schema.types,
    schema.query,
    schema.mutation
    );
}

Schema newSchemaWith(Schema schema, Enum_[string] enums) {
    return Schema(schema.scalars,
    schema.interfaces,
    schema.unions, 
    enums, 
    schema.inputs, 
    // schema.fragments,
    schema.types,
    schema.query,
    schema.mutation
    );
}

// Schema newSchemaWith(Schema schema, Framgment[] fragments) {
//     return Schema(schema.scalars,
//     schema.interfaces,
//     schema.unions, 
//     schema.enums, 
//     schema.inputs, 
//     fragments,
//     schema.types,
//     schema.query,
//     schema.mutation
//     );
// }

Schema newSchemaWith(Schema schema, Object_[string] types)
{
    return Schema(schema.scalars,
        schema.interfaces,
        schema.unions,
        schema.enums,
        schema.inputs,
        // schema.fragments,
        types,
        schema.query,
        schema.mutation
    );
}
Schema newSchemaWith(bool isQuery)(Schema schema, Request[string] request)
{
    static if (isQuery) {
        return Schema(schema.scalars,
            schema.interfaces,
            schema.unions,
            schema.enums,
            schema.inputs,
            // schema.fragments,
            schema.types,
            request,
            schema.mutation
        );
    } else {
        return Schema(schema.scalars,
            schema.interfaces,
            schema.unions,
            schema.enums,
            schema.inputs,
            // schema.fragments,
            schema.types,
            schema.query,
            request
        );
    }
}

GQLType isKnownType(Schema schema, T_)()
{
    alias T = RemoveAllArrayQualifiersAndOption!T_[0];
    static if (!(isScalar!T || isCustomType!T || isSumType!T || isEnum!T))
    {
        static assert(isBuiltin!T,
            format(
                "type %s is not builtin type should be one of the scalar, input, object union enum or interface",
                    T_.stringof));
        return GQLType.BUILTIN;
    }
    else
    {
        static if (isScalar!T)
        {
            static if (canFind(schema.scalars.keys, T.stringof))
            {
                return GQLType.SCALAR;
            }
        }
        static if (isCustomType!T)
        {
            static if (isInputType!T)
            {
                static if (canFind(schema.inputs.keys, T.stringof))
                {
                    return GQLType.INPUT;
                }
            }
            static if (isObject!T)
            {
                static if (canFind(schema.types.keys, T.stringof))
                {
                    return GQLType.OBJECT;
                }
            }
            static if (isInterface!T)
            {
                static if (canFind(schema.interfaces.keys, T.stringof))
                {
                    return GQLType.INTERFACE;
                }  
            }
        }
        // static if (isUnion!T) {
        //     static if(canFind(schema.unions.keys, T.stringof)) {
        //         return GQLType.UNION;
        //     }
        // }
        static if (isEnum!T) {
            static if(canFind(schema.enums.keys, T.stringof)) {
                return GQLType.ENUM;
            }
        }
        return GQLType.UNKNOWN;
    }
}


string getTypeName(Schema schema, T_)()
{
    alias T = RemoveAllArrayQualifiersAndOption!T_[0];
    enum gqlType = isKnownType!(schema, T);
    enum typeFormatter = typeNameFormatter!T;
    static assert(gqlType != GQLType.UNKNOWN,
        format("type %s is a unknown type,
this might only happened when you use a type without any attribute to identify it", T.stringof));
    static if (gqlType == GQLType.BUILTIN)
        return format(typeFormatter, schema.builtinTypes[T.stringof]);
    static if (gqlType == GQLType.SCALAR)
        return format(typeFormatter, schema.scalars[T.stringof].name);
    static if (gqlType == GQLType.INPUT)
    {
        static assert(canFind(schema.inputs.keys, T.stringof), "unknown input type");
        return format(typeFormatter, schema.inputs[T.stringof].name);
    }
    static if (gqlType == GQLType.OBJECT)
    {
        static assert(canFind(schema.types.keys, T.stringof) /*|| canFind(schema.interfaces.keys, T.stringof)*/ ,
            "unknown return type");
        return format(typeFormatter, schema.types[T.stringof].name);
    }
    static if (gqlType == GQLType.INTERFACE)
        return format(typeFormatter, schema.interfaces[T.stringof]);
    static if (gqlType == GQLType.ENUM)
        return format(typeFormatter, schema.enums[T.stringof]);
    static if (gqlType == GQLType.UNION)
        return format(typeFormatter, schema.unions[T.stringof]);
}

Schema registerNewType(Schema schema, T_)()
{
    alias T = RemoveAllArrayQualifiersAndOption!T_[0];
    static assert(isKnownType!(schema, T) == GQLType.UNKNOWN,
        format("type %s is already a known type by schema", T.stringof));
    static if (isScalar!T)
    {
        static if(schema.scalars.length > 0) {
            return newSchemaWith(schema, AppendAssocArray(schema.scalars, T.stringof, scalarFromDtype!T));
        } else {
            return newSchemaWith(schema, [T.stringof: scalarFromDtype!T]);
        }
    }
    static if (isInputType!T)
    {
        return inputTypeFromDtype!(schema, T);
    }
    static if (isObject!T)
    {
        return objectFromDType!(schema, T);
    }
    static if (isInterface!T)
    {
        return interfaceFromDType!(schema, T);
    }
    static if (isEnum!T)
    {
        return enumFromDType!(schema, T);
    }
    return schema;
}

string parseSchema(Schema schema)() {
    import std.conv : text;
    import std.algorithm : map;
    import std.array : join;
    static if(schema.scalars.values.length == 0 || schema.scalars.values == null) {
        enum scalarStr = "";
    } else {
        enum scalarStr = parseScalars!(schema.scalars.values);
    }
    static if(schema.inputs.values.length == 0 || schema.inputs.values == null) {
        enum inputStr = "";
    } else {
        enum inputStr = parseInputs!(schema.inputs.values);
    }
    static if(schema.interfaces.values.length == 0 || schema.interfaces.values == null) {
        enum interfaceStr = "";
    } else {
        enum interfaceStr = parseInterfaces!(schema.interfaces.values);
    }
    static if(schema.types.values.length == 0 || schema.types.values == null) {
        enum objectStr = "";
    } else {
    enum objectStr = parseObjects!(schema.types.values);
    }
    static if(schema.enums.values.length == 0 || schema.enums.values == null) {
        enum enumStr = "";
    } else {
        enum enumStr = parseEnums!(schema.enums.values);
    }
    static if(schema.unions.values.length == 0 || schema.unions.values == null) {
        enum unionStr = "";
    } else {
        enum unionStr = parseUnions!(schema.unions.values);
    }
    // enum fragmentStr = schema.fragments.map!(f => parseFragment(f)).join("\n");
    enum queryStr = parseQueryOrMutation(schema.query.values);
    enum mutationStr = parseQueryOrMutation(schema.mutation.values, false);
    return text(
        scalarStr,
        inputStr,
        interfaceStr,
        objectStr,
        enumStr,
        unionStr,
        // fragmentStr,
        queryStr,
        "\n",
        mutationStr
    );
}
// subscription not supported yet
template readSchema(Query, Mutation) {
    enum schema_empty = Schema();
    enum schemaWithQuery = requestsFromAClass!(schema_empty, Query);
    enum schemaWithMutation = requestsFromAClass!(schemaWithQuery, Mutation, false);
    enum readSchema = schemaWithMutation;
}

unittest
{
    import gql_parser.attributes : scalar_;

    @scalar_("AAA") class A
    {

    }

    enum schema = Schema(["A": Scalar("A")], null, null, null, null, null);
    static assert(isKnownType!(schema, A) == GQLType.SCALAR);
}

unittest
{
    import gql_parser.attributes;
    @object_("ObjectA") @document("
This is the documentation of ObjectA.
It can have multiple lines.
") class A
    {
        int a;
        this()
        {
            a = 0;
        }
    }

    @input("InputB") class B
    {
        string b;
        this()
        {
            b = "";
        }
    }

    @scalar_("CustomScalar_____1") struct CustomScalar
    {
        int c;
    }
    @enum_("CustomEnum_____1") enum CustomEnum: string
    {
        A = "A",
        B = "B",
        C = "C"
    }
    class Query
    {
        string hello(string name)
        {
            return "hello " ~ name;
        }

        A getA()
        {
            return new A();
        }
    }

    class Mutation
    {
        void addB(B[] b)
        {
            b ~= new B();
        }
    }
    enum schema = readSchema!(Query, Mutation);
    static assert(schema.types.length == 1);
    static assert(schema.scalars.length == 0);
    static assert(schema.inputs.length == 1);
    static assert(schema.enums.length == 0);
    enum schemaWithEnum = registerNewType!(schema, CustomEnum);
    static assert(schemaWithEnum.enums.length == 1);
    static assert(schemaWithEnum.types.length == 1);
    static assert(schemaWithEnum.scalars.length == 0);
    static assert(schemaWithEnum.inputs.length == 1);
    enum schemaWithScalar = registerNewType!(schemaWithEnum, CustomScalar);
    static assert(schemaWithScalar.enums.length == 1);
    static assert(schemaWithScalar.types.length == 1);
    static assert(schemaWithScalar.scalars.length == 1);
    static assert(schemaWithScalar.inputs.length == 1);
    pragma(msg, parseSchema!(schemaWithScalar));
}
