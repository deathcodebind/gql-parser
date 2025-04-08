module gql_parser.schema;

static struct Schema
{
    import std.traits;
    import std.meta;
    import std.stdio;
    import std.conv : to;
    import std.format;
    import std.algorithm : find, map, canFind;
    import std.range : zip, repeat, take;
    import std.array : assocArray, replace, split, join;
    import std.sumtype;
    import gql_parser.attributes;
    import gql_parser.types;
    import gql_parser.utils;

    enum ParsePosition {
        FunctionParam,
        ClassFieldForInput,
        ClassFieldForObject,
        FunctionReturnType,
        ArrayElement,
        NotInsideAnything,
    }


    template IdentifierTypeToValidator(IdentifierType it)
    {
        static if (it == IdentifierType.SCALAR)
        {
            alias Validator(T) = isScalar!T;
        }
        static if (it == IdentifierType.ENUM)
        {
            alias Validator(T) = isEnum!T;
        }
        static if (it == IdentifierType.OBJECT)
        {
            alias Validator(T) = isObject!T;
        }
        static if (it == IdentifierType.UNION)
        {
            alias Validator(T) = isUnion!T;
        }
        static if (it == IdentifierType.INPUT_OBJECT)
        {
            alias Validator(T) = isInputType!T;
        }
        alias IdentifierTypeToValidator = Validator;
    }

    static string[string] genTypeContext(IdentifierType it, Types...)()
    {
        static assert(Types.length > 0, "Types should not be empty");
        alias Validator = IdentifierTypeToValidator!it;
        string[] typeNames;
        string[] customNames;
        static foreach (i, t_; Types)
        {
            static if (Validator!t_)
            {
                typeNames ~= t_.stringof;
                customNames ~= getCustomName!(it, t_)();
            }
        }
        return assocArray(zip(typeNames, customNames));
    }

    static bool isInputType(T)()
    {
        static immutable input_udas = getUDAs!(T, input);
        return input_udas.length == 1;
    }

    alias genInputTypesContext(Types...) = genTypeContext!(IdentifierType.INPUT_OBJECT, Types);

    static bool isObject(T)()
    {
        enum object_udas = getUDAs!(T, object_);
        return object_udas.length == 1;
    }

    alias genObjectTypesContext(Types...) = genTypeContext!(IdentifierType.OBJECT, Types);

    alias isUnion(T) = isSumType!T;

    alias genUnionTypesContext(Types...) = genTypeContext!(IdentifierType.UNION, Types);

    static bool isEnum(T)()
    {
        return is(T == enum);
    }

    alias genEnumTypesContext(Types...) = genTypeContext!(IdentifierType.ENUM, Types);

    static bool isScalar(T)()
    {
        enum scalar_udas = getUDAs!(T, scalar_);
        return scalar_udas.length == 1;
    }

    alias genScalarTypesContext(Types...) = genTypeContext!(IdentifierType.SCALAR, Types);

    template Context(Types...)
    {
        enum input_types = genInputTypesContext!Types;
        enum object_types = genObjectTypesContext!Types;
        enum union_types = genUnionTypesContext!Types;
        enum enum_types = genEnumTypesContext!Types;
        enum uds = genScalarTypesContext!Types;
        enum scalars = compileTimeCombineTwoSSMap!(uds, builtinScalars);
        enum Context = ParserContext(input_types, object_types, union_types, enum_types, scalars);
    }

    static char[] parseOption(ParserContext ctx, T, ParsePosition where, Outer)()
    {
        static if (isOption!T)
        {
            return dTypeToGQLType!(ctx, T.Types[0], true, where, Outer)();
        }
        else
        {
            return dTypeToGQLType!(ctx, T, true, where, Outer)() ~ "!";
        }
    }

    static char[] innerTypeToGQL(ParserContext ctx, T, ParsePosition where, Outer)()
    {
        string result;
        static if (isIntegral!T)
        {
            result = ctx.scalars["int"];
        }
        static if (isFloatingPoint!T)
        {
            result = ctx.scalars["float"];
        }
        static if (isBoolean!T)
        {
            result = ctx.scalars["bool"];
        }
        static if (is(T == string) || isSomeString!T)
        {
            result = ctx.scalars["string"];
        }
        static if (is(T == void))
        {
            result = ctx.scalars["void"];
        }
        static if (isArray!T && !is(T == string))
        {
            alias E = ArrayElemType!T;
            return to!(char[])("[" ~ parseOption!(ctx, E, where, T)() ~ "]");
        }
        static if (is(T == class) || is(T == struct) || isSumType!T)
        {
            static if (where == ParsePosition.FunctionParam) {
                static assert(isInputType!T && canFind(ctx.input_types.keys, T.stringof),
                format("type %s as a function param should be an input object"));
                result = ctx.input_types[T.stringof];
            }
            static if(where == ParsePosition.FunctionReturnType) {
                static assert(isObject!T && canFind(ctx.object_types.keys, T.stringof),
                 "return type should be an object type");
                result = ctx.object_types[T.stringof];
            }
            static if(where == ParsePosition.ClassFieldForInput) {
                static if (isScalarType!T) {
                    result = ctx.scalars[T.stringof];
                } else {
                    static assert(isInputType!T && canFind(ctx.input_types.keys, T.stringof), 
                    "if the outer type is a input object and the field type is not a scalar, then it should be a input object too");
                    result = ctx.inputs[T.stringof];
                }
            }
            static if(where == ParsePosition.ClassFieldForObject) {
                static if (isScalarType!T) {
                    result = ctx.scalars[T.stringof];
                } else {
                    static assert(isObject!T && canFind(ctx.objects.keys, T.stringof), 
                    "if the outer type is a object and the field type is not a scalar, then it should be a object too");
                    result = ctx.objects[T.stringof];
                }
            }
        }
        static if(isEnum!T) {
            result = ctx.enums[T.stringof];
        }
        return to!(char[])(result);
    }

    static char[] dTypeToGQLType(
        ParserContext ctx, T, 
        bool isInner = false, 
        ParsePosition where = ParsePosition.NotInsideAnything, 
        Outer = void
    )
    ()
    {
        static if (!isInner) {
            static assert(where == ParsePosition.NotInsideAnything,
            "When you say that we are not parsing a inner type, ParsePosition should be NotInsideAnything"               
            );
        }
        static if (isInner)
        {
            static assert(!is(Outer == void) && !is(Outer == typeof(null)), 
            "Parsing some inner type needs a Outer type that is not void or typeof(null)");
            return to!(char[])(innerTypeToGQL!(ctx, T, where, Outer));
        }
        else
        {
            static if ((is(T == class) || is(T == struct)))
            {
                return parseDClass!(ctx, T)();
            }
            static if (isSumType!T)
            {
                return parseSumTypeToGQLUnion!T();
            }
            static if (isScalar!T) {
                return to!(char[])(format("scalar %s\n", ctx.scalars[T.stringof]));
            }
            static if (isEnum!T) {
                return parseEnumToGQLEnum!T();
            }
        }
    }
    static char[] parseEnumToGQLEnum(T)()
    {
        // dlang doesn't support to check a enum's super types, will find a way in the future
        // enum baseTypes = compileTimeTypeTupleToTypeNameStringArray!(BaseTypeTuple!T);
        // static assert(canFind(baseTypes, "string"),
        // format("enum %s should extend string to enable parsing from d to gql or back"));
        auto result = format("enum %s {\n", getCustomName!(IdentifierType.ENUM, T));
        enum members = to!(string[])([EnumMembers!T]);
        static foreach(i, member; members) {
            result ~= format("\t%s\n", member);
        }
        return to!(char[])(result ~ "}\n");
    }

    static char[] parseDClass(ParserContext ctx, T)()
    {
        enum input = getUDAs!(T, input);
        enum object = getUDAs!(T, object_);
        enum interface_ = getUDAs!(T, interface_);
        enum scalar_ = getUDAs!(T, scalar_);
        static assert(input.length == 1 || object.length == 1 || interface_.length == 1 || scalar_.length == 1,
            format("type %s need one of input, object, interface or scalar as marker", T.stringof));
        static assert((input.length == 1 || object.length == 1 && interface_.length != 1)
                || (interface_.length == 1 && input.length != 1 && object.length != 1 
                || scalar_.length == 1 && interface_.length != 1 && input.length != 1 && object.length != 1),
                "interface could not bet attached together with input or object");
        string result;
        static if (input.length == 1)
        {
            result ~= parseDClasstoGQLInputObject!(ctx, T, input[0].name != null ? input[0].name
                    : T
                    .stringof)();
        }
        static if (object.length == 1)
        {
            result ~= parseDClasstoGQLType!(ctx, T, object[0].name != null ? object[0].name
                    : T.stringof)();
        }
        // not implemented yet
        // static if (interface_.length == 1)
        // {
        //     result ~= parseDClasstoGQLInterface!T(interface_[0].name);
        // }
        return to!(char[])(result);

    }

    static char[] parseDClassFields(ParserContext ctx, T, ParsePosition where)()
    {
        string result;
        auto field_names = FieldNameTuple!T;
        static foreach (i, field_name; field_names)
        {
            result ~= format("\t%s: %s", field_name, parseOption!(ctx, Fields!T[i], where, T)());
        }
        return to!(char[])(result);
    }

    static char[] parseDClasstoGQLInputObject(ParserContext ctx, T, string name = null)()
    {
        enum typeName = name != null ? name : ("Input" ~ T.stringof);
        auto reuslt = format("input %s {\n", typeName);
        auto fields = parseDClassFields!(ctx, T, ParsePosition.ClassFieldForInput)();
        return to!(char[])(format("%s%s\n}\n", reuslt, fields));
    }

    static char[] parseDClasstoGQLType(ParserContext ctx, T, string name = null)()
    {
        enum typeName = name != null ? name : T.stringof;
        string result;
        result ~= format("type %s {\n", typeName);
        auto fields = parseDClassFields!(ctx, T, ParsePosition.ClassFieldForObject)();
        return to!(char[])(format("%s%s\n}\n", result, fields));
    }

    static char[] parseDClasstoGQLInterface(ParserContext ctx, T, string name = null)()
    {
        static assert(0, "not implemented parse option");
        return "";
    }

    static char[] parseSumTypeToGQLUnion(T)()
    {
        auto result = format("union %s = ", getCustomName!T);
        static foreach (i, type; T.Types)
        {
            result ~= type.stringof;
            if (i != T.Types.length - 1)
            {
                result ~= " | ";
            }
        }
        return to!(char[])(result ~ "\n");
    }

    static char[] parseFunctionToGQLQueryOrMutation(ParserContext ctx, T, string funcName)()
    {
        alias queryFuncs = MemberFunctionsTuple!(T, funcName);
        static assert(queryFuncs.length == 1,
            "query function should have unique name, since gql doesn't support function override");
        alias T = queryFuncs[0];
        alias STC = ParameterStorageClass;
        alias params = Parameters!T;
        alias paramNames = ParameterIdentifierTuple!T;
        alias paramStorages = ParameterStorageClassTuple!T;
        alias rt = ReturnType!T;
        auto result = format("%s(", funcName);
        static foreach (i, param; params)
        {
            static assert(paramStorages[i] != STC.out_, "gql doesn't support out parameter in query or mutation");
            result ~= format("%s: %s", paramNames[i], parseOption!(ctx, param, ParsePosition.FunctionParam, FunctionTypeOf!T));
            if (i != params.length - 1)
            {
                result ~= ", ";
            }
        }
        return to!(char[])(format("%s): %s\n", result, parseOption!(ctx, rt, ParsePosition.FunctionReturnType, FunctionTypeOf!T)));
    }

    static char[] parseQueryOrMutation(ParserContext ctx, T, bool isQuery = true)()
    {
        enum string[] queries = [__traits(derivedMembers, T)];
        static assert(queries.length > 0, "we need at least one query function");
        auto result = format("type %s {\n", isQuery ? "query" : "mutation");
        static foreach (query; queries)
        {
            result ~= format("\t%s", parseFunctionToGQLQueryOrMutation!(ctx, T, query)());
        }
        return to!(char[])(format("%s}", result));
    }

    static string getCustomName(IdentifierType it, T)()
    {
        string customName;
        static if (it == IdentifierType.ENUM)
        {
            customName = T.stringof;
        }
        static if (it == IdentifierType.OBJECT)
        {
            enum object_udas = getUDAs!(T, object_);
            customName = object_udas[0].name;
        }
        static if (it == IdentifierType.INPUT_OBJECT)
        {
            enum input_udas = getUDAs!(T, input);
            customName = input_udas[0].name;
        }
        static if (it == IdentifierType.UNION)
        {
            alias allPossibleInAnUnion = T.Types;
            customName = join(compileTimeTypeTupleToTypeNameStringArray!allPossibleInAnUnion, "or");
        }
        static if (it == IdentifierType.SCALAR)
        {
            alias scalar_udas = getUDAs!(T, scalar_);
            customName = scalar_udas[0].name;
        }
        return customName;
    }

    static string[] typesToCustomNames(Types...)()
    {
        string[] result;
        static foreach (i, type; Types)
        {
            result ~= getCustomName!type();
        }
        return result;
    }

    static char[] parseSchema(Query, Mutation, Subscription, Types...)()
    {
        static assert(!is(Query == void) || !is(Mutation == void) || !is(Subscription == void),
            "we need at least one of Query, Mutation or Subscription");
        enum ctx = Context!(Types);
        auto result = "";
        static foreach (type; Types)
        {
            result ~= format("%s\n", dTypeToGQLType!(ctx, type)());
        }
        static if (!is(Query == void))
        {
            enum queryGQLString = parseQueryOrMutation!(ctx, Query)();
        }
        else
        {
            enum queryGQLString = "";
        }
        static if (!is(Mutation == void))
        {
            enum mutationGQLString = parseQueryOrMutation!(ctx, Mutation, false);
        }
        else
        {
            enum mutationGQLString = "";
        }
        return to!(char[])(format("%s%s\n%s", result, queryGQLString, mutationGQLString));
    }
}

unittest
{
    import gql_parser.attributes;

    @object_("ObjectA") class A
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

    @scalar_("CustomScalar") struct CustomScalar
    {
        int c;
    }
    @enum_("CustomEnum") enum CustomEnum: string
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
    // to ensure that all parsing is pure compile-time
    static assert(__traits(compiles, Schema.parseSchema!(Query, Mutation, void, A, B, CustomEnum, CustomScalar)()));
}
