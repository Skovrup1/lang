package lexer

import "core:fmt"

TokenIndex :: distinct u32
INVALID_TOKEN_INDEX :: max(TokenIndex)

Tokenizer :: struct {
	start:   int,
	current: int,
	line:    int,
	source:  []u8,
}

TokenKind :: enum u8 {
	Null = 0,
	Eof,
	Error,
	// literals
	Identifier,
	Integer,
	Float,
	Char,
	String,
	// symbols
	Hash, // #
	Dollar, // $
	Comma, // ,
	Period, // .
	Colon, // :
	Semicolon, // ;
	LParen, // (
	RParen, // )
	LBracket, // [
	RBracket, // ]
	LBrace, // {
	RBrace, // }
	Or, // ||
	And, // &&
	Less, // <
	LessEqual, // <=
	Greater, // >
	GreaterEqual, // >=
	Init, // :=
	Assign, // =
	Equal, // ==
	Plus, // +
	Minus, // -
	Asterisk, // *
	Slash, // /
	Percent, // %
	Not, // !
	NotEqual, // !=
	Tilde, // ~
	Ampersand, // &
	Pipe, // |
	Hat, // ^
	LShift, // <<
	RShift, // >>

	// keywords
	Return = 64,
	For,
	While,
	If,
	Else,
	Struct,
	I32,
	True,
	False,
}

Token :: struct {
	kind:  TokenKind,
	start: TokenIndex,
	end:   TokenIndex,
}

make_tokenizer :: proc(buf: []u8, start := 0, current := 0, line := 1) -> Tokenizer {
	return Tokenizer{start, current, line, buf}
}

make_token :: proc(t: ^Tokenizer, kind: TokenKind) -> Token {
	return Token{kind, TokenIndex(t.start), TokenIndex(t.current)}
}

peek :: proc(t: ^Tokenizer) -> u8 {
	if is_at_end(t) {
		return 0
	}

	return t.source[t.current]
}

peek_next :: proc(t: ^Tokenizer) -> u8 {
	if is_at_end(t) {
		return 0
	}

	return t.source[t.current + 1]
}

advance :: proc(t: ^Tokenizer) -> u8 {
	t.current += 1
	return t.source[t.current - 1]
}

is_at_end :: proc(t: ^Tokenizer) -> bool {
	return t.current >= len(t.source)
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
	str := t.source[t.start:t.current]

	keywords := [?]string{"return", "for", "while", "if", "else", "struct", "I32", "true", "false"}

	for _, i in keywords {
		if keywords[i] == transmute(string)str {
			return cast(TokenKind)(cast(int)TokenKind.Return + i)
		}
	}

	return TokenKind.Identifier
}

is_alpha :: proc(r: u8) -> bool {
	return (r >= 'a' && r <= 'z') || (r >= 'A' && r <= 'Z') || r == '_'
}

is_digit :: proc(r: u8) -> bool {
	return r >= '0' && r <= '9'
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

	return make_token(t, TokenKind.Integer)
}

next_token :: proc(t: ^Tokenizer) -> Token {
	skip_whitespace(t)

	t.start = t.current

	if is_at_end(t) {
		return make_token(t, TokenKind.Eof)
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
			return make_token(t, TokenKind.NotEqual)
		}
		return make_token(t, TokenKind.Not)
	case '#':
		return make_token(t, TokenKind.Hash)
	case '$':
		return make_token(t, TokenKind.Dollar)
	case '%':
		return make_token(t, TokenKind.Percent)
	case '&':
		if peek(t) == '&' {
			advance(t)
			return make_token(t, TokenKind.And)
		}
		return make_token(t, TokenKind.Ampersand)
	case '(':
		return make_token(t, TokenKind.LParen)
	case ')':
		return make_token(t, TokenKind.RParen)
	case '*':
		return make_token(t, TokenKind.Asterisk)
	case '+':
		return make_token(t, TokenKind.Plus)
	case ',':
		return make_token(t, TokenKind.Comma)
	case '-':
		return make_token(t, TokenKind.Minus)
	case '.':
		return make_token(t, TokenKind.Period)
	case '/':
		return make_token(t, TokenKind.Slash)
	case ':':
		if peek(t) == '=' {
			advance(t)
			return make_token(t, TokenKind.Init)
		}
		return make_token(t, TokenKind.Colon)
	case ';':
		return make_token(t, TokenKind.Semicolon)
	case '=':
		if peek(t) == '=' {
			advance(t)
			return make_token(t, TokenKind.Equal)
		}
		return make_token(t, TokenKind.Assign)
	case '<':
		if peek(t) == '<' {
			advance(t)
			return make_token(t, TokenKind.LShift)
		}
		if peek(t) == '=' {
			advance(t)
			return make_token(t, TokenKind.LessEqual)
		}
		return make_token(t, TokenKind.Less)
	case '>':
		if peek(t) == '>' {
			advance(t)
			return make_token(t, TokenKind.RShift)
		}
		if peek(t) == '=' {
			advance(t)
			return make_token(t, TokenKind.GreaterEqual)
		}
		return make_token(t, TokenKind.Greater)
	case '[':
		return make_token(t, TokenKind.LBracket)
	case ']':
		return make_token(t, TokenKind.RBracket)
	case '^':
		return make_token(t, TokenKind.Hat)
	case '{':
		return make_token(t, TokenKind.LBrace)
	case '}':
		return make_token(t, TokenKind.RBrace)
	case '~':
		return make_token(t, TokenKind.Tilde)
	case '|':
		return make_token(t, TokenKind.Pipe)
	}

	return make_token(t, TokenKind.Error)
}

tokenize :: proc(t: ^Tokenizer) -> [dynamic]Token {
	list: [dynamic]Token

	for tok := next_token(t); tok.kind != TokenKind.Eof; tok = next_token(t) {
		append(&list, tok)
	}

	return list
}
