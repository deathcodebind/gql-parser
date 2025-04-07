module gql_parser.attributes;

struct input
{
    string name;
}

struct object_
{
    string name;
}

struct interface_
{
    string name;
}

enum AttributeType
{
    Input,
    Object,
    Interface
}
