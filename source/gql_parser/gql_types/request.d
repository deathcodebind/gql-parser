module gql_parser.gql_types.request;

import std.typetuple;
import std.format;
import std.algorithm;
import std.range;
import std.traits;

import gql_parser.attributes;
import gql_parser.gql_types.common;
import gql_parser.gql_types.schema;
import gql_parser.gql_types.custom_type;

struct Request
{
    string name;
    Field[] params;
    string returnTypeName;
    bool returnTypeRequired;
    string comment = null;
}

string parseParam(Field param)
{
    return format("%s: %s%s", param.name, param.typeName, param.is_optional ? "" : "!");
}

string parseRequest_impl(Request query)
{
    return format(
        "%s(%s): %s",
        query.name,
        join(map!(element => parseParam(element))(query.params), ", "),
        query.returnTypeName);
}

string parseRequest(Request query)
{
    if (query.comment)
        return format("%s\n    %s", query.comment, parseRequest_impl(query));
    return parseRequest_impl(query);
}

string parseQueryOrMutation(Request[] queries, bool isQuery = true)
{
    return format(isQuery? "type Query {\n    %s\n}": "type Mutation {\n    %s\n}", 
        join(map!(query => parseRequest(query))(queries), "\n    "));
}

template requestParamsToFields(Schema schema, string[] paramNames, int index = 0, params...) {
    static if (index >= params.length) {
        alias requestParamsToFields = AliasSeq!(schema);
    } else {
        static assert(isInputType!(params[index]) || isScalar!(params[index]) ||
        isEnum!(params[index]) || isBuiltinType!(params[index]), "only enum, scalar or input type is allowed to be a request parameter");
        enum schemaFixed = registerAllUnknowTypes!(schema, params[index]);
        static if(isKnownType!(schemaFixed, params[index]) == GQLType.UNKNOWN) {
            pragma(msg, params[index]);
            enum schemaFinal = registerNewType!(schemaFixed, params[index]);
        } else {
            enum schemaFinal = schemaFixed;
        }
        enum paramName = paramNames[index];
        enum isOptional_ = isOption!(params[index]);
        alias requestParamsToFields = AliasSeq!(
            requestParamsToFields!(schemaFinal, paramNames, index + 1, params),
            Field(paramName, getTypeName!(schemaFinal, params[index]), isOptional_));
    }
}

Schema requestFromOneMemberFunction(Schema schema, Parent, string funcName, bool isQuery = true)()
{
    alias queryFuncs = MemberFunctionsTuple!(Parent, funcName);
    static assert(queryFuncs.length == 1,
        "query function should have unique name, since gql doesn't support function override");
    alias T = queryFuncs[0];
    alias params = Parameters!T;
    alias paramNames = ParameterIdentifierTuple!T;
    alias paramStorages = ParameterStorageClassTuple!T;
    alias rt = ReturnType!T;
    enum schemaAndparamsArr = requestParamsToFields!(schema, [paramNames], 0, params);
    enum schemaFixed = schemaAndparamsArr[0];
    alias paramsArr = schemaAndparamsArr[1..$];
    enum isOptional_rt = isOption!rt;
    static assert(isObject!rt || isScalar!rt || isEnum!rt || isUnion!rt || isInterface!rt || isBuiltinType!rt,
    "only object, scalar, enum, union or interface is allowed to be a return type of a request");
    enum schemaFixed_rt = registerAllUnknowTypes!(schemaFixed, rt);
    static if(isKnownType!(schemaFixed_rt, rt) == GQLType.UNKNOWN) {
        enum schemaFinal = registerNewType!(schemaFixed_rt, rt);
    } else {
        enum schemaFinal = schemaFixed_rt;
    }
    alias returnTypeName = getTypeName!(schemaFinal, rt);
    return newSchemaWith!isQuery(
        schemaFinal, 
        AppendAssocArray!Request.impl!(
            schemaFinal.query, rt.stringof, 
            Request(funcName, [paramsArr], returnTypeName, isOptional_rt, handleDocument!T)));
}

template requestsFromAClass(Schema schema, T, bool queryOrMutation = true, int index = 0)
{
    static assert(is(T == class), 
    "error: only class type is allowed to be a set of request
    also known as query, mutation or subscription
");
    static immutable funcs = [__traits(derivedMembers, T)];
    static if(index >= funcs.length) {
        alias requestsFromAClass = schema;
    } else {
        enum newSchema = requestFromOneMemberFunction!(schema, T, funcs[index]);
        alias requestsFromAClass = requestsFromAClass!(newSchema, T, queryOrMutation, index + 1);
    }
}

unittest
{
    enum Schema schema = Schema();
    class Query
    {
        string hello(string name) @document("returns hello {your_name}!") 
        {
            return "Hello, " ~ name ~ "!";
        }
    }
    enum schema_ = requestsFromAClass!(schema, Query);
    pragma(msg, parseQueryOrMutation(schema_.query.values));
}