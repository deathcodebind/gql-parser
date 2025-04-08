module gql_parser.lexer;
///not ready to be used yet

enum TokenType {
    Query,
    Mutation,
    Subscription,
    Identifier,
    LBrace,
    RBrace,
    LBracket,
    RBracket,
    Colon,
    LComma,
    RComma,
    LQoute,
    RQoute,
    Value,
    On,
    Fragment,
    TripleDot,
}

struct Token {
    TokenType type;
    string value;
    size_t start_pos;
    size_t end_pos;
}


class GQLLexer 
{

private:
    Token[] tokens;
    size_t current_pos;
    size_t read_pos;
    char[] source;
    Token last_token;
    Token current_token;
    void stripWhitespaces() {
        while(current_pos < source.length && source[current_pos] == ' ') {
            current_pos++;
        }
    }
    void stripComments() {
        // remeber that if last token is a left quote, then means we are inside a string then # is valid
        if(current_pos < source.length && source[current_pos] == '#' && last_token.type != TokenType.LQoute) {
            while(current_pos < source.length && source[current_pos]!= '\n') {
                current_pos++;
            }
        }
    }
}