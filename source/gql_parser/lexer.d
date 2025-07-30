module gql_parser.lexer;
// ///not ready to be used yet

// import std.meta : AliasSeq;

// alias Position = AliasSeq!(size_t, size_t);

// enum TokenType {
//     Keyword,
//     Identifier,
//     LBrace,
//     RBrace,
//     LBracket,
//     RBracket,
//     Colon,
//     LComma,
//     RComma,
//     LQoute,
//     RQoute,
//     Value,
//     TripleDot,
// }

// enum KeywordType {
//     Query,
//     Mutation,
//     Subscription,
//     Fragment,
//     On,
// }

// struct Token {
//     TokenType type;
//     string value;
//     Position position;
//     Position end_pos;
// }


// class GQLLexer 
// {

// private:
//     Token[] tokens;
//     size_t current_pos;
//     size_t read_pos;
//     char[] source;
//     Token current_token;
//     void stripWhitespaces() {
//         while(current_pos < source.length && source[current_pos] == ' ') {
//             current_pos++;
//         }
//     }
//     // once it is a comment, skip until the end of line
//     void stripComments() {
//         while(current_pos < source.length && source[current_pos] != '\n') {
//             current_pos++;
//         }
//     }

//     void readIdentifier() {
//         while(current_pos < source.length && (isLetter(source[current_pos]) || isDigit(source[current_pos]))) {
//             current_pos++;
//         }
//         current_token.value = source[read_pos..current_pos];
//         current_token.type = TokenType.Identifier;
//     }


// }