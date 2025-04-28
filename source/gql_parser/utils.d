module gql_parser.utils;

string[] compileTimeTypeTupleToTypeNameStringArray(Types)()
{
    import std.array : split;
    import std.string : replace;

    enum typeNames = Types.stringof;
    enum typeNames_left_stripped = replace(typeNames, "(", "");
    enum typeNames_right_stripped = replace(typeNames_left_stripped, ")", "");
    return split(typeNames_right_stripped, ", ");
}


string[string] compileTimeCombineTwoSSMap(string[string] map_1, string[string] map_2)() {
    import std.array : join, split, assocArray;
    import std.range : zip;
    enum map_1_ks = join(map_1.keys, ",");
    enum map_2_ks = join(map_2.keys, ",");
    enum combined_ks = map_1_ks ~ "," ~ map_2_ks;
    enum combined_ks_array = split(combined_ks, ",");
    enum map_1_vs = join(map_1.values, ",");
    enum map_2_vs = join(map_2.values, ",");
    enum combined_vs = map_1_vs ~ "," ~ map_2_vs;
    enum combined_vs_array = split(combined_vs, ",");
    enum combined_map = zip(combined_ks_array, combined_vs_array);
    return assocArray(combined_map);
}