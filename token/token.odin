package token

import "core:fmt"

is_alpha :: proc(r: u8) -> bool {
	return (r >= 'a' && r <= 'z') || (r >= 'A' && r <= 'Z') || r == '_'
}

is_digit :: proc(r: u8) -> bool {
	return r >= '0' && r <= '9'
}

Tokenizer :: struct {
	start:   int,
	current: int,
	line:    int,
	buf:     []u8,
}

TokenType :: enum {
	NULL = 0,
	EOF,
	ERROR,
	// literals
	INTEGER,
	IDENTIFIER,
	// symbols
	SEMICOLON, // ;
	LPAREN, // (
	RPAREN, // )
	LBRACE, // [
	RBRACE, // ]
	LBRACKET, // {
	RBRACKET, // }
	TILDE, // ~
	HYPHEN, // =
	HYPHEN_HYPHEN, // ==
	// keywords
	INT = 256,
	VOID,
	RETURN,
}

Token :: struct {
	type:  TokenType,
	start: int,
	end:   int,
}

make_tokenizer :: proc(buf: []u8, start := 0, current := 0, line := 1) -> Tokenizer {
	return Tokenizer{start, current, line, buf}
}

make_token :: proc(t: ^Tokenizer, type: TokenType) -> Token {
	return Token{type, t.start, t.current}
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
			}
		case:
			return
		}
	}
}

identifier_type :: proc(t: ^Tokenizer) -> TokenType {
	str := t.buf[t.start:t.current]

	keywords := [?]string{"int", "void", "return"}

    for _, i in keywords {
        if keywords[i] == transmute(string) str {
            return transmute(TokenType)(256 + i)
        }
    }

	return TokenType.IDENTIFIER
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

	return make_token(t, TokenType.INTEGER)
}

next_token :: proc(t: ^Tokenizer) -> Token {
	skip_whitespace(t)

	t.start = t.current

	if is_at_end(t) {
		return make_token(t, TokenType.EOF)
	}

	r := advance(t)

	if is_alpha(r) {
		return identifier(t)
	}
	if is_digit(r) {
		return integer(t)
	}

	switch r {
	case '(':
		return make_token(t, TokenType.LPAREN)
	case ')':
		return make_token(t, TokenType.RPAREN)
	case '{':
		return make_token(t, TokenType.LBRACE)
	case '}':
		return make_token(t, TokenType.RBRACE)
	case '[':
		return make_token(t, TokenType.LBRACKET)
	case ']':
		return make_token(t, TokenType.RBRACKET)
	case ';':
		return make_token(t, TokenType.SEMICOLON)
	case '~':
		return make_token(t, TokenType.TILDE)
	case '-':
		if peek_next(t) == '-' {
			return make_token(t, TokenType.HYPHEN_HYPHEN)
		} else {
			return make_token(t, TokenType.HYPHEN)
		}
	}

	return make_token(t, TokenType.ERROR)
}
