package parser

import "core:fmt"
import "core:strconv"

import "../lexer"

Node :: union {
	// definitions
	AstProgDef,
	AstFuncDef,
	// statements
	AstReturnStmt,
	// expressions
	AstBitCompExpr,
	AstMulExpr,
	AstDivExpr,
	AstAddExpr,
	AstSubExpr,
	AstParenExpr,
	// literals
	AstIntLiteral,
}

NodeIndex :: int
TokenIndex :: int

AstProgDef :: struct {
	node: NodeIndex,
}

AstFuncDef :: struct {
	ident: TokenIndex,
	node:  NodeIndex,
}

AstReturnStmt :: struct {
	node: NodeIndex,
}

AstBitCompExpr :: struct {
	node: NodeIndex,
}

AstParenExpr :: struct {
	node: NodeIndex,
}

AstMulExpr :: struct {
	left:  NodeIndex,
	right: NodeIndex,
}

AstDivExpr :: struct {
	left:  NodeIndex,
	right: NodeIndex,
}

AstAddExpr :: struct {
	left:  NodeIndex,
	right: NodeIndex,
}

AstSubExpr :: struct {
	left:  NodeIndex,
	right: NodeIndex,
}

AstIntLiteral :: struct {
	value: TokenIndex,
}

Parser :: struct {
	current:    TokenIndex,
	previous:   TokenIndex,
	list:       [dynamic]Node,
	tokenizer:  lexer.Tokenizer,
	token_list: #soa[dynamic]lexer.Token,
}

make_parser :: proc(tokenizer: lexer.Tokenizer, token_list: #soa[dynamic]lexer.Token) -> Parser {
	list: [dynamic]Node

	return Parser{0, 0, list, tokenizer, token_list}
}

parse :: proc(p: ^Parser) -> [dynamic]Node {
	parse_program(p)

	return p.list
}

parse_program :: proc(p: ^Parser) {
	func := parse_function(p)
	append(&p.list, AstProgDef{node = func})
}

parse_function :: proc(p: ^Parser) -> NodeIndex {
	ident_i := p.current
	expect(p, .IDENTIFIER)
	expect(p, .COLON)
	expect(p, .COLON)
	expect(p, .LPAREN)
	expect(p, .RPAREN)
	expect(p, .MINUS)
	expect(p, .GREATER)
	expect(p, .I32)

	stmt := parse_statement(p)
	append(&p.list, AstFuncDef{ident = ident_i, node = stmt})

	return len(p.list) - 1
}

parse_statement :: proc(p: ^Parser) -> NodeIndex {
	expect(p, .LBRACE)
	expect(p, .RETURN)

	expr := parse_expression(p)

	expect(p, .SEMICOLON)
	expect(p, .RBRACE)

	append(&p.list, AstReturnStmt{node = expr})

	return len(p.list) - 1
}

parse_expression :: proc(p: ^Parser) -> NodeIndex {
	return parse_equality(p)
}

parse_equality :: proc(p: ^Parser) -> NodeIndex {
	return parse_comparison(p)
}

parse_comparison :: proc(p: ^Parser) -> NodeIndex {
	return parse_term(p)
}

parse_term :: proc(p: ^Parser) -> NodeIndex {
	left := parse_factor(p)

	for peek(p) == .PLUS || peek(p) == .MINUS {
		op := peek(p)
		advance(p)

		right := parse_factor(p)
		#partial switch op {
		case .PLUS:
			append(&p.list, AstAddExpr{left = left, right = right})
		case .MINUS:
			append(&p.list, AstSubExpr{left = left, right = right})
		}
		left = len(p.list) - 1
	}

	return left
}

parse_factor :: proc(p: ^Parser) -> NodeIndex {
	left := parse_primary(p)

	for peek(p) == .ASTERISK || peek(p) == .SLASH {
		op := peek(p)
		advance(p)

		right := parse_primary(p)
		#partial switch op {
		case .ASTERISK:
			append(&p.list, AstMulExpr{left = left, right = right})
		case .SLASH:
			append(&p.list, AstDivExpr{left = left, right = right})
		}
		left = len(p.list) - 1
	}

	return left
}

parse_primary :: proc(p: ^Parser) -> NodeIndex {
	#partial switch peek(p) {
	case .LPAREN:
		advance(p)
		expr := parse_expression(p)
		expect(p, .RPAREN)
		append(&p.list, AstParenExpr{node = expr})

		return len(p.list) - 1
	case .TILDE:
		advance(p)
		op := parse_primary(p)
		append(&p.list, AstBitCompExpr{node = op})

		return len(p.list) - 1
	case .INTEGER:
		advance(p)

		append(&p.list, AstIntLiteral{value = p.previous})
		return len(p.list) - 1
	}

	panic("reached end of primary")
}

advance :: proc(p: ^Parser) {
	p.previous = p.current
	p.current += 1
}

peek :: proc(p: ^Parser) -> lexer.TokenKind {
	return p.token_list[p.current].kind
}

expect :: proc(p: ^Parser, expected: lexer.TokenKind) {
	actual := p.token_list[p.current].kind

	if actual != expected {
		msg := fmt.aprintf("expected %s, got %s", expected, actual)
		panic(msg)
	}

	advance(p)
}
