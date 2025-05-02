package parser

import "core:fmt"
import "core:strconv"

import "ast"
import tok "tokenizer"

Parser :: struct {
	current:    ast.TokenIndex,
	previous:   ast.TokenIndex,
	list:       [dynamic]ast.Node,
	tokenizer:  tok.Tokenizer,
	token_list: #soa[dynamic]tok.Token,
}

make_parser :: proc(tokenizer: tok.Tokenizer, token_list: #soa[dynamic]tok.Token) -> Parser {
	list: [dynamic]ast.Node

	return Parser{0, 0, list, tokenizer, token_list}
}

parse :: proc(p: ^Parser) -> [dynamic]ast.Node {
	using ast

	parse_program(p)

	return p.list
}

parse_program :: proc(p: ^Parser) {
	using ast

	func := parse_function(p)
	append(&p.list, Node{AstProgDef{node = func}})
}

parse_function :: proc(p: ^Parser) -> ast.NodeIndex {
	using ast

	name_index := p.current
	expect(p, .IDENTIFIER)
	expect(p, .COLON)
	expect(p, .COLON)
	expect(p, .LPAREN)
	expect(p, .RPAREN)
	expect(p, .MINUS)
	expect(p, .GREATER)
	expect(p, .I32)

	stmt := parse_statement(p)
	append(&p.list, Node{AstFuncDef{name = name_index, node = stmt}})

	return cast(NodeIndex)len(p.list) - 1
}

parse_statement :: proc(p: ^Parser) -> ast.NodeIndex {
	using ast

	expect(p, .LBRACE)
	expect(p, .RETURN)

	expr := parse_expression(p)

	expect(p, .SEMICOLON)
	expect(p, .RBRACE)

	append(&p.list, Node{AstReturnStmt{node = expr}})

	return cast(NodeIndex)len(p.list) - 1
}

parse_expression :: proc(p: ^Parser) -> ast.NodeIndex {
	return parse_equality(p)
}

parse_equality :: proc(p: ^Parser) -> ast.NodeIndex {
	return parse_comparison(p)
}

parse_comparison :: proc(p: ^Parser) -> ast.NodeIndex {
	return parse_term(p)
}

parse_term :: proc(p: ^Parser) -> ast.NodeIndex {
	using ast

	left := parse_factor(p)

	for peek(p) == .PLUS || peek(p) == .MINUS {
		op := peek(p)
		advance(p)

		right := parse_factor(p)
		#partial switch op {
		case .PLUS:
			append(&p.list, Node{AstAddExpr{left = left, right = right}})
		case .MINUS:
			append(&p.list, Node{AstSubExpr{left = left, right = right}})
		}
		left = cast(ast.NodeIndex)len(p.list) - 1
	}

	return left
}

parse_factor :: proc(p: ^Parser) -> ast.NodeIndex {
	using ast

	left := parse_primary(p)

	for peek(p) == .ASTERISK || peek(p) == .SLASH {
		op := peek(p)
		advance(p)

		right := parse_primary(p)
		#partial switch op {
		case .ASTERISK:
			append(&p.list, Node{AstMulExpr{left = left, right = right}})
		case .SLASH:
			append(&p.list, Node{AstDivExpr{left = left, right = right}})
		}
		left = cast(ast.NodeIndex)len(p.list) - 1
	}

	return left
}

parse_primary :: proc(p: ^Parser) -> ast.NodeIndex {
	using ast

	#partial switch peek(p) {
	case .TILDE:
		advance(p)
		op := parse_primary(p)
		append(&p.list, Node{AstBitCompExpr{node = op}})

		return cast(ast.NodeIndex)len(p.list) - 1
	case .INTEGER:
		advance(p)

		append(&p.list, Node{kind = AstIntLiteral{value = p.previous}})
		return cast(ast.NodeIndex)len(p.list) - 1
	}

	panic("reached end of primary")
}

advance :: proc(p: ^Parser) {
	p.previous = p.current
	p.current += 1
}

peek :: proc(p: ^Parser) -> tok.TokenKind {
	return p.token_list[p.current].kind
}

expect :: proc(p: ^Parser, expected: tok.TokenKind) {
	actual := p.token_list[p.current].kind

	if actual != expected {
		msg := fmt.aprintf("expected %s, got %s", expected, actual)
		panic(msg)
	}

	advance(p)
}
