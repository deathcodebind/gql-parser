module gql_parser.attributes;

struct input
{
    string name;
}

struct object_
{
    string name;
}

struct impls(T) {
    alias Inner = T;
    string interface_ = T.stringof;
}

struct interface_
{
    string name;
}

struct scalar_
{
    string name;
}

struct enum_
{
    string name;
}
/* this attibute is going to be used as a custom documentation
* just some libs provided """ in a schema
*/
struct document {
    string description;
}



enum AttributeType
{
    Input,
    Object,
    Interface
}
