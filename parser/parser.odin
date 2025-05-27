package parser

import "core:fmt"
import "core:strconv"

import "../lexer"

AstIndex :: int
TokenIndex :: int

AstProgDef :: struct {
	node: AstIndex,
}

AstFuncDef :: struct {
	ident: TokenIndex,
	node:  AstIndex,
}

AstReturnStmt :: struct {
	node: AstIndex,
}

AstNegExpr :: struct {
	node: AstIndex,
}

AstBitNotExpr :: struct {
	node: AstIndex,
}

AstParenExpr :: struct {
	node: AstIndex,
}

AstBitAndExpr :: struct {
	left:  AstIndex,
	right: AstIndex,
}

AstBitOrExpr :: struct {
	left:  AstIndex,
	right: AstIndex,
}

AstBitXorExpr :: struct {
	left:  AstIndex,
	right: AstIndex,
}

AstMulExpr :: struct {
	left:  AstIndex,
	right: AstIndex,
}

AstDivExpr :: struct {
	left:  AstIndex,
	right: AstIndex,
}

AstModExpr :: struct {
	left:  AstIndex,
	right: AstIndex,
}

AstAddExpr :: struct {
	left:  AstIndex,
	right: AstIndex,
}

AstSubExpr :: struct {
	left:  AstIndex,
	right: AstIndex,
}

AstLShiftExpr :: struct {
	left:  AstIndex,
	right: AstIndex,
}

AstRShiftExpr :: struct {
	left:  AstIndex,
	right: AstIndex,
}

AstIntLiteral :: struct {
	value: TokenIndex,
}

Ast :: union {
	// definitions
	AstProgDef,
	AstFuncDef,
	// statements
	AstReturnStmt,
	// expressions
	// unary
	AstParenExpr,
	AstBitNotExpr,
	AstNegExpr,
	// binary
	AstBitAndExpr,
	AstBitOrExpr,
	AstBitXorExpr,
	AstMulExpr,
	AstDivExpr,
	AstModExpr,
	AstAddExpr,
	AstSubExpr,
	AstLShiftExpr,
	AstRShiftExpr,
	// literals
	AstIntLiteral,
}

Parser :: struct {
	current:    TokenIndex,
	previous:   TokenIndex,
	list:       [dynamic]Ast,
	tokenizer:  lexer.Tokenizer,
	token_list: [dynamic]lexer.Token,
}

make_parser :: proc(tokenizer: lexer.Tokenizer, token_list: [dynamic]lexer.Token) -> Parser {
	list: [dynamic]Ast

	return Parser{0, 0, list, tokenizer, token_list}
}

parse :: proc(p: ^Parser) -> [dynamic]Ast {
	parse_program(p)

	return p.list
}

parse_program :: proc(p: ^Parser) {
	func := parse_function(p)
	append(&p.list, AstProgDef{node = func})
}

parse_function :: proc(p: ^Parser) -> AstIndex {
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

parse_statement :: proc(p: ^Parser) -> AstIndex {
	expect(p, .LBRACE)
	expect(p, .RETURN)

	expr := parse_expression(p)

	expect(p, .SEMICOLON)
	expect(p, .RBRACE)

	append(&p.list, AstReturnStmt{node = expr})

	return len(p.list) - 1
}

parse_expression :: proc(p: ^Parser) -> AstIndex {
	return parse_equality(p)
}

parse_equality :: proc(p: ^Parser) -> AstIndex {
	return parse_comparison(p)
}

parse_comparison :: proc(p: ^Parser) -> AstIndex {
	return parse_term(p)
}

parse_term :: proc(p: ^Parser) -> AstIndex {
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

parse_factor :: proc(p: ^Parser) -> AstIndex {
	left := parse_primary(p)

	for peek(p) == .ASTERISK ||
	    peek(p) == .SLASH ||
	    peek(p) == .PERCENT ||
	    peek(p) == .LSHIFT ||
	    peek(p) == .RSHIFT ||
	    peek(p) == .AMPERSAND ||
	    peek(p) == .PIPE ||
	    peek(p) == .HAT {
		op := peek(p)
		advance(p)

		right := parse_primary(p)
		#partial switch op {
		case .ASTERISK:
			append(&p.list, AstMulExpr{left = left, right = right})
		case .SLASH:
			append(&p.list, AstDivExpr{left = left, right = right})
		case .PERCENT:
			append(&p.list, AstModExpr{left = left, right = right})
		case .LSHIFT:
			append(&p.list, AstLShiftExpr{left = left, right = right})
		case .RSHIFT:
			append(&p.list, AstRShiftExpr{left = left, right = right})
		case .AMPERSAND:
			append(&p.list, AstBitAndExpr{left = left, right = right})
		case .PIPE:
			append(&p.list, AstBitOrExpr{left = left, right = right})
		case .HAT:
			append(&p.list, AstBitXorExpr{left = left, right = right})
		}
		left = len(p.list) - 1
	}

	return left
}

parse_primary :: proc(p: ^Parser) -> AstIndex {
	#partial switch peek(p) {
	case .INTEGER:
		advance(p)
		append(&p.list, AstIntLiteral{value = p.previous})

		return len(p.list) - 1
	case .LPAREN:
		advance(p)
		expr := parse_expression(p)
		expect(p, .RPAREN)
		append(&p.list, AstParenExpr{node = expr})

		return len(p.list) - 1
	case .TILDE:
		advance(p)
		op := parse_primary(p)
		append(&p.list, AstBitNotExpr{node = op})

		return len(p.list) - 1
	case .MINUS:
		advance(p)
		op := parse_primary(p)
		append(&p.list, AstNegExpr{node = op})

		return len(p.list) - 1
	}

	panic(fmt.tprintf("peek() = %v", peek(p)))
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

print_ast :: proc(ast_list: [dynamic]Ast, indent: int = 0) {
	print_spaces :: proc(n: int) {
		for i in 0 ..< n {
			fmt.print(' ')
		}
	}

	print_node :: proc(list: [dynamic]Ast, index: AstIndex, indent: int) {
		if index < 0 || index >= len(list) {
			print_spaces(indent)
			fmt.println("<invalid ast index>")
			return
		}

		node := list[index]
		print_spaces(indent)

		switch v in node {
		case AstProgDef:
			fmt.println("AstProgDef")
			print_node(list, v.node, indent + 2)
		case AstFuncDef:
			fmt.printfln("AstFuncDef")
			print_node(list, v.node, indent + 2)
		case AstReturnStmt:
			fmt.println("AstReturnStmt")
			print_node(list, v.node, indent + 2)
		case AstBitNotExpr:
			fmt.println("AstBitNotExpr")
			print_node(list, v.node, indent + 2)
		case AstNegExpr:
			fmt.println("AstNegExpr")
			print_node(list, v.node, indent + 2)
		case AstParenExpr:
			fmt.println("AstParenExpr")
			print_node(list, v.node, indent + 2)
		case AstBitAndExpr:
			fmt.println("AstBitAndExpr")
			print_node(list, v.left, indent + 2)
			print_node(list, v.right, indent + 2)
		case AstBitOrExpr:
			fmt.println("AstBitOrExpr")
			print_node(list, v.left, indent + 2)
			print_node(list, v.right, indent + 2)
		case AstBitXorExpr:
			fmt.println("AstBitXorExpr")
			print_node(list, v.left, indent + 2)
			print_node(list, v.right, indent + 2)
		case AstMulExpr:
			fmt.println("AstMulExpr")
			print_node(list, v.left, indent + 2)
			print_node(list, v.right, indent + 2)
		case AstDivExpr:
			fmt.println("AstDivExpr")
			print_node(list, v.left, indent + 2)
			print_node(list, v.right, indent + 2)
		case AstModExpr:
			fmt.println("AstModExpr")
			print_node(list, v.left, indent + 2)
			print_node(list, v.right, indent + 2)
		case AstAddExpr:
			fmt.println("AstAddExpr")
			print_node(list, v.left, indent + 2)
			print_node(list, v.right, indent + 2)
		case AstSubExpr:
			fmt.println("AstSubExpr")
			print_node(list, v.left, indent + 2)
			print_node(list, v.right, indent + 2)
		case AstLShiftExpr:
			fmt.println("AstLShiftExpr")
			print_node(list, v.left, indent + 2)
			print_node(list, v.right, indent + 2)
		case AstRShiftExpr:
			fmt.println("AstLShiftExpr")
			print_node(list, v.left, indent + 2)
			print_node(list, v.right, indent + 2)
		case AstIntLiteral:
			fmt.printfln("AstIntLiteral")
		}
	}

	if len(ast_list) > 0 {
		print_node(ast_list, len(ast_list) - 1, indent) // start from the root
	}
}
