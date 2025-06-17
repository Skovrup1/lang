package lexer

import "core:fmt"

is_alpha :: proc(r: u8) -> bool {
	return (r >= 'a' && r <= 'z') || (r >= 'A' && r <= 'Z') || r == '_'
}

is_digit :: proc(r: u8) -> bool {
	return r >= '0' && r <= '9'
}

TokenIndex :: int

Tokenizer :: struct {
	start:   int,
	current: int,
	line:    int,
	buf:     []u8,
}

TokenKind :: enum {
	NULL = 0,
	EOF,
	ERROR,
	// literals
	IDENTIFIER,
	INTEGER,
	FLOAT,
	CHAR,
	STRING,
	// symbols
	HASH, // #
	DOLLAR, // $
	COMMA, // ,
	PERIOD, // .
	COLON, // :
	SEMICOLON, // ;
	LPAREN, // (
	RPAREN, // )
	LBRACKET, // [
	RBRACKET, // ]
	LBRACE, // {
	RBRACE, // }
	OR, // ||
	AND, // &&
	LESS, // <
	LESS_EQUAL, // <=
	GREATER, // >
	GREATER_EQUAL, // >=
	INIT, // :=
	ASSIGN, // =
	EQUAL, // ==
	PLUS, // +
	MINUS, // -
	ASTERISK, // *
	SLASH, // /
	PERCENT, // %
	NOT, // !
	NOT_EQUAL, // !=
	TILDE, // ~
	AMPERSAND, // &
	PIPE, // |
	HAT, // ^
	LSHIFT, // <<
	RSHIFT, // >>

	// keywords
	RETURN = 128,
	FOR,
	WHILE,
	IF,
	ELSE,
	STRUCT,
	I32,
    TRUE,
    FALSE,
}

Token :: struct {
	kind:  TokenKind,
	start: int,
	end:   int,
}

make_tokenizer :: proc(buf: []u8, start := 0, current := 0, line := 1) -> Tokenizer {
	return Tokenizer{start, current, line, buf}
}

make_token :: proc(t: ^Tokenizer, kind: TokenKind) -> Token {
	return Token{kind, t.start, t.current}
}

peek :: proc(t: ^Tokenizer) -> u8 {
	if is_at_end(t) {
		return 0
	}

	return t.buf[t.current]
}

peek_next :: proc(t: ^Tokenizer) -> u8 {
	if is_at_end(t) {
		return 0
	}

	return t.buf[t.current + 1]
}

advance :: proc(t: ^Tokenizer) -> u8 {
	t.current += 1
	return t.buf[t.current - 1]
}

is_at_end :: proc(t: ^Tokenizer) -> bool {
	return t.current >= len(t.buf)
}

skip_whitespace :: proc(t: ^Tokenizer) {
	for {
		r := peek(t)
		switch r {
		case ' ', '\r', '\t':
			advance(t)
		case '\n':
			t.line += 1
			advance(t)
		case '/':
			if peek_next(t) == '/' {
				for peek(t) != '\n' && !is_at_end(t) {
					advance(t)
				}
			} else {
				return
			}
		case:
			return
		}
	}
}

identifier_type :: proc(t: ^Tokenizer) -> TokenKind {
	str := t.buf[t.start:t.current]

	keywords := [?]string{"return", "for", "while", "if", "else", "struct", "I32", "true", "false"}

	for _, i in keywords {
		if keywords[i] == transmute(string)str {
			return cast(TokenKind)(cast(int)TokenKind.RETURN + i)
		}
	}

	return TokenKind.IDENTIFIER
}

identifier :: proc(t: ^Tokenizer) -> Token {
	for is_alpha(peek(t)) || is_digit(peek(t)) {
		advance(t)
	}

	return make_token(t, identifier_type(t))
}

integer :: proc(t: ^Tokenizer) -> Token {
	for is_digit(peek(t)) {
		advance(t)
	}

	if peek(t) == '.' && is_digit(peek_next(t)) {
		advance(t)

		for is_digit(peek(t)) {
			advance(t)
		}
	}

	return make_token(t, TokenKind.INTEGER)
}

next_token :: proc(t: ^Tokenizer) -> Token {
	skip_whitespace(t)

	t.start = t.current

	if is_at_end(t) {
		return make_token(t, TokenKind.EOF)
	}

	r := advance(t)

	if is_alpha(r) {
		return identifier(t)
	}
	if is_digit(r) {
		return integer(t)
	}

	switch r {
	case '!':
		if peek(t) == '=' {
			advance(t)
			return make_token(t, TokenKind.NOT_EQUAL)
		}
		return make_token(t, TokenKind.NOT)
	case '#':
		return make_token(t, TokenKind.HASH)
	case '$':
		return make_token(t, TokenKind.DOLLAR)
	case '%':
		return make_token(t, TokenKind.PERCENT)
	case '&':
		if peek(t) == '&' {
			advance(t)
			return make_token(t, TokenKind.AND)
		}
		return make_token(t, TokenKind.AMPERSAND)
	case '(':
		return make_token(t, TokenKind.LPAREN)
	case ')':
		return make_token(t, TokenKind.RPAREN)
	case '*':
		return make_token(t, TokenKind.ASTERISK)
	case '+':
		return make_token(t, TokenKind.PLUS)
	case ',':
		return make_token(t, TokenKind.PLUS)
	case '-':
		return make_token(t, TokenKind.MINUS)
	case '.':
		return make_token(t, TokenKind.PERIOD)
	case '/':
		return make_token(t, TokenKind.SLASH)
	case ':':
		if peek(t) == '=' {
			advance(t)
			return make_token(t, TokenKind.INIT)
		}
		return make_token(t, TokenKind.COLON)
	case ';':
		return make_token(t, TokenKind.SEMICOLON)
	case '=':
		if peek(t) == '=' {
			advance(t)
			return make_token(t, TokenKind.EQUAL)
		}
		return make_token(t, TokenKind.ASSIGN)
	case '<':
		if peek(t) == '<' {
			advance(t)
			return make_token(t, TokenKind.LSHIFT)
		}
		if peek(t) == '=' {
			advance(t)
			return make_token(t, TokenKind.LESS_EQUAL)
		}
		return make_token(t, TokenKind.LESS)
	case '>':
		if peek(t) == '>' {
			advance(t)
			return make_token(t, TokenKind.RSHIFT)
		}
		if peek(t) == '=' {
			advance(t)
			return make_token(t, TokenKind.GREATER_EQUAL)
		}
		return make_token(t, TokenKind.GREATER)
	case '[':
		return make_token(t, TokenKind.LBRACKET)
	case ']':
		return make_token(t, TokenKind.RBRACKET)
	case '^':
		return make_token(t, TokenKind.HAT)
	case '{':
		return make_token(t, TokenKind.LBRACE)
	case '}':
		return make_token(t, TokenKind.RBRACE)
	case '~':
		return make_token(t, TokenKind.TILDE)
	case '|':
		return make_token(t, TokenKind.PIPE)
	}

	return make_token(t, TokenKind.ERROR)
}

tokenize :: proc(t: ^Tokenizer) -> [dynamic]Token {
	list: [dynamic]Token

	for tok := next_token(t); tok.kind != TokenKind.EOF; tok = next_token(t) {
		append(&list, tok)
	}

	return list
}
