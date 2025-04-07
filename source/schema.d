module gql_parser.schema;

import gql_parser.attributes;
import gql_parser.types;

static struct Schema {
    import std.traits;
    import std.meta;
    import std.stdio;
    import std.conv : to;
    import std.format;
    import std.algorithm : find, map, canFind;
    import std.range : zip, repeat, take;
    import std.array : assocArray, replace, split, join;
    import std.sumtype;
    template Context(string[] names, Types...) {
        static assert(Types.length >= names.length, "names should have less or same length with Types");
        enum typeNames_left_striped = replace(Types.stringof, "(", "");
        enum typeNames_striped = replace(typeNames_left_striped, ")", "");
        enum typeNames = to!(string[])(split(typeNames_striped, ", "));
        static immutable builtins = ["int", "float", "bool", "string", "void"];
        static foreach(builtin; builtins) {
            static assert(!canFind(typeNames, builtin), 
            format("%s is a builtin type, you don't need to parse that", builtin));
        }
        static immutable int length_reduced = typeNames.length - names.length;
        enum Context = assocArray(zip(typeNames, names ~ typeNames[$-length_reduced..$]));
    }
    static char[] parseOption(string[string] ctx, T)()
    {
        static if (isOption!T)
        {
            return dTypeToGQLType!(ctx, T.Types[0], true)();
        }
        else
        {
            return dTypeToGQLType!(ctx, T, true)() ~ "!";
        }
    }
    static char[] innerTypeToGQL(string[string] ctx, T)()
    {

        string result;
        static if (isIntegral!T)
        {
            result = ctx["int"];
        }
        static if (isFloatingPoint!T)
        {
           result = ctx["float"];
        }
        static if (isBoolean!T)
        {
            result = ctx["bool"];
        }
        static if (is(T == string) || isSomeString!T)
        {
            result = ctx["string"];
        }
        static if (is(T == void))
        {
            result = ctx["void"];
        }
        static if (isArray!T && !is(T == string))
        {
            alias E = ArrayElemType!T;
            return to!(char[])("[" ~ parseOption!(ctx, E)() ~ "]");
        }
        static if (is(T == class) || is(T == struct) || isSumType!T)
        {
            static assert(canFind(ctx.keys, T.stringof),
                format("type %s is not a parsed type, maybe you forget to add this type to parser?", T
                    .stringof));
            result = ctx[T.stringof];
        }
        return to!(char[])(result);
    }

    static char[] dTypeToGQLType(string[string] ctx, T, bool isInner = false)()
    {

        static if (isInner)
        {
            return to!(char[])(innerTypeToGQL!(ctx, T));
        }
        else
        {
            static if (is(T == class) || is(T == struct))
            {
                return parseDClass!(ctx, T)();
            }
            static if (isSumType!T)
            {
                return parseSumTypeToGQLUnion!T();
            }
        }
    }

    static char[] parseDClass(string[string] ctx, T)()
    {
        enum input = getUDAs!(T, input);
        enum object = getUDAs!(T, object_);
        enum interface_ = getUDAs!(T, interface_);
        static assert(input.length == 1 || object.length == 1 || interface_.length == 1,
            "need one of input, object or interface as marker");
        static assert((input.length == 1 || object.length == 1 && interface_.length != 1)
                || (interface_.length == 1 && input.length != 1 && object.length != 1),
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
            result ~= parseDClasstoGQLType!(ctx, T, object[0].name != null ? object[0].name : T.stringof)();
        }
        // not implemented yet
        // static if (interface_.length == 1)
        // {
        //     result ~= parseDClasstoGQLInterface!T(interface_[0].name);
        // }
        return to!(char[])(result);

    }

    static char[] parseDClassFields(string[string] ctx, T)()
    {
        string result;
        auto field_names = FieldNameTuple!T;
        static foreach (i, field_name; field_names)
        {
            result ~= format("\t%s: %s", field_name, parseOption!(ctx, Fields!T[i])());
        }
        return to!(char[])(result);
    }

    static char[] parseDClasstoGQLInputObject(string[string] ctx, T, string name = null)()
    {
        enum typeName = name != null ? name : ("Input" ~ T.stringof);
        auto reuslt = format("input %s {\n", typeName);
        auto fields = parseDClassFields!(ctx, T)();
        return to!(char[])(format("%s%s\n}\n", reuslt, fields));
    }

    static char[] parseDClasstoGQLType(string[string] ctx, T, string name = null)()
    {
        enum typeName = name != null ? name : T.stringof;
        string result;
        result ~= format("type %s {\n", typeName);
        auto fields = parseDClassFields!(ctx, T)();
        return to!(char[])(format("%s%s\n}\n", result, fields));
    }

    static char[] parseDClasstoGQLInterface(string[string] ctx, T, string name = null)()
    {
        static assert(0, "not implemented parse option");
        return "";
    }

    static char[] parseSumTypeToGQLUnion(T, string name)()
    {
        auto result = format("union %s = ", name);
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

    static char[] parseFunctionToGQLQueryOrMutation(string[string] ctx, T, string funcName)()
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
            result ~= format("%s: %s", paramNames[i], parseOption!(ctx, param));
            if (i != params.length - 1)
            {
                result ~= ", ";
            }
        }
        return to!(char[])(format("%s): %s\n", result, parseOption!(ctx, rt)));
    }

    static char[] parseQueryOrMutation(string[string] ctx, T, bool isQuery = true)()
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
    static string getCustomName(T)() {
        enum input = getUDAs!(T, input);
        enum object = getUDAs!(T, object_);
        enum interface_ = getUDAs!(T, interface_);
        static assert(input.length == 1 || object.length == 1 || interface_.length == 1,
            "need one of input, object or interface as marker");
        static assert((input.length == 1 || object.length == 1 && interface_.length != 1)
                || (interface_.length == 1 && input.length != 1 && object.length != 1),
                "interface could not bet attached together with input or object");
        string result;
        static if (input.length == 1 && input[0].name != "") {
            result = input[0].name;
        }
        static if (object.length == 1 && object[0].name != "") {
            result = object[0].name;
        }
        return result;
    }

    static string[] typesToCustomNames(Types...)() {
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
        enum ctx_raw = Context!(typesToCustomNames!(Types), Types);
        enum ctx = assocArray(zip(
            split(
                (join(ctx_raw.keys, ",") ~ "," ~ join(builtinTypes.keys, ",")),
                ",")
            , split(join(ctx_raw.values, ",") ~ "," ~ join(builtinTypes.values, ","), ",")));
        auto result = "";
        static foreach (type; Types)
        {
            result ~= format("%s\n", parseDClass!(ctx, type)());
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

unittest {
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
    enum schema = Schema.parseSchema!(Query, Mutation, void, A, B)();
    // to ensure that all parsing is pure compile-time, so we do pragma
    pragma(msg, schema);
}