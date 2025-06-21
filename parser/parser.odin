package parser

import "core:fmt"
import "core:strconv"

import "../lexer"

AstIndex :: int
INVALID_AST_INDEX: AstIndex : -1

ProgDef :: struct {
	node: AstIndex,
}

FuncDef :: struct {
	ident: lexer.TokenIndex,
	node:  AstIndex,
}

BlockStmt :: struct {
	stmts: [dynamic]AstIndex,
}

ReturnStmt :: struct {
	node: AstIndex,
}

InitStmt :: struct {
	ident: lexer.TokenIndex,
	expr:  AstIndex,
}

AssignStmt :: struct {
	ident: lexer.TokenIndex,
	expr:  AstIndex,
}

VarExpr :: struct {
	ident: lexer.TokenIndex,
}

IfExpr :: struct {
	cond:       AstIndex,
	then_block: AstIndex,
	else_block: AstIndex,
}

NotExpr :: struct {
	node: AstIndex,
}

NegExpr :: struct {
	node: AstIndex,
}

BitNotExpr :: struct {
	node: AstIndex,
}

ParenExpr :: struct {
	node: AstIndex,
}

BitAndExpr :: struct {
	left:  AstIndex,
	right: AstIndex,
}

BitOrExpr :: struct {
	left:  AstIndex,
	right: AstIndex,
}

BitXorExpr :: struct {
	left:  AstIndex,
	right: AstIndex,
}

MulExpr :: struct {
	left:  AstIndex,
	right: AstIndex,
}

DivExpr :: struct {
	left:  AstIndex,
	right: AstIndex,
}

ModExpr :: struct {
	left:  AstIndex,
	right: AstIndex,
}

AddExpr :: struct {
	left:  AstIndex,
	right: AstIndex,
}

SubExpr :: struct {
	left:  AstIndex,
	right: AstIndex,
}

LShiftExpr :: struct {
	left:  AstIndex,
	right: AstIndex,
}

RShiftExpr :: struct {
	left:  AstIndex,
	right: AstIndex,
}

AndExpr :: struct {
	left:  AstIndex,
	right: AstIndex,
}

OrExpr :: struct {
	left:  AstIndex,
	right: AstIndex,
}

EqualExpr :: struct {
	left:  AstIndex,
	right: AstIndex,
}

NotEqualExpr :: struct {
	left:  AstIndex,
	right: AstIndex,
}

LessExpr :: struct {
	left:  AstIndex,
	right: AstIndex,
}

LessEqualExpr :: struct {
	left:  AstIndex,
	right: AstIndex,
}

GreaterExpr :: struct {
	left:  AstIndex,
	right: AstIndex,
}

GreaterEqualExpr :: struct {
	left:  AstIndex,
	right: AstIndex,
}

IntLiteral :: struct {
	value: lexer.TokenIndex,
}

Ast :: union {
	// definitions
	ProgDef,
	FuncDef,
	// statements
	BlockStmt,
	ReturnStmt,
	InitStmt,
	AssignStmt,
	// expressions
	// unary
	IfExpr,
	ParenExpr,
	NegExpr,
	NotExpr,
	BitNotExpr,
	// binary
	AndExpr,
	OrExpr,
	//AstXorExpr,
	EqualExpr,
	NotEqualExpr,
	LessExpr,
	LessEqualExpr,
	GreaterExpr,
	GreaterEqualExpr,
	BitAndExpr,
	BitOrExpr,
	BitXorExpr,
	LShiftExpr,
	RShiftExpr,
	MulExpr,
	DivExpr,
	ModExpr,
	AddExpr,
	SubExpr,
	// literals
	IntLiteral,
	VarExpr,
}

Parser :: struct {
	current:    lexer.TokenIndex,
	previous:   lexer.TokenIndex,
	source:     []u8,
	token_list: [dynamic]lexer.Token,
	list:       [dynamic]Ast,
}

make_parser :: proc(source: []u8, token_list: [dynamic]lexer.Token) -> Parser {
	list: [dynamic]Ast

	return Parser{0, 0, source, token_list, list}
}

parse :: proc(p: ^Parser) -> [dynamic]Ast {
	parse_program(p)

	return p.list
}

parse_program :: proc(p: ^Parser) {
	func := parse_function(p)
	append(&p.list, ProgDef{node = func})
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
	append(&p.list, FuncDef{ident = ident_i, node = stmt})

	return len(p.list) - 1
}

parse_statement :: proc(p: ^Parser) -> AstIndex {
	#partial switch peek(p) {
	case .LBRACE:
		advance(p) // consume LBRACE
		// this is likely wrong, what happens if temp allocator frees itself
		stmts := make([dynamic]AstIndex, 0, 4, context.temp_allocator)
		for peek(p) != .RBRACE {
			stmt := parse_statement(p)
			append(&stmts, stmt)
		}
		advance(p) // consume RBRACE
		append(&p.list, BlockStmt{stmts})
	case .IDENTIFIER:
		#partial switch peek_next(p) {
		case .INIT:
			ident := p.current
			advance(p) // consume IDENTIFIER
			advance(p) // consume INIT
			expr := parse_expression(p)
			append(&p.list, InitStmt{ident, expr})
			expect(p, .SEMICOLON)
		case .ASSIGN:
			ident := p.current
			advance(p) // consume IDENTIFIER
			advance(p) // consume ASSIGN
			expr := parse_expression(p)
			append(&p.list, AssignStmt{ident, expr})
			expect(p, .SEMICOLON)
		}
	case .RETURN:
		advance(p) // consume RETURN
		expr := parse_expression(p)
		append(&p.list, ReturnStmt{node = expr})
		expect(p, .SEMICOLON)
	case:
		expr := parse_expression(p)
	}

	return len(p.list) - 1
}

parse_expression :: proc(p: ^Parser) -> AstIndex {
	return parse_logical_or(p)
}

parse_logical_or :: proc(p: ^Parser) -> AstIndex {
	left := parse_logical_and(p)

	for peek(p) == .OR {
		op := peek(p)
		advance(p)

		right := parse_logical_and(p)
		append(&p.list, OrExpr{left = left, right = right})
		left = len(p.list) - 1
	}

	return left
}

parse_logical_and :: proc(p: ^Parser) -> AstIndex {
	left := parse_equality(p)

	for peek(p) == .AND {
		op := peek(p)
		advance(p)

		right := parse_equality(p)
		append(&p.list, AndExpr{left = left, right = right})
		left = len(p.list) - 1
	}

	return left
}

parse_equality :: proc(p: ^Parser) -> AstIndex {
	left := parse_comparison(p)

	for peek(p) == .EQUAL || peek(p) == .NOT_EQUAL {
		op := peek(p)
		advance(p)

		right := parse_comparison(p)
		#partial switch op {
		case .EQUAL:
			append(&p.list, EqualExpr{left = left, right = right})
		case .NOT_EQUAL:
			append(&p.list, NotEqualExpr{left = left, right = right})
		}

		left = len(p.list) - 1
	}

	return left
}

parse_comparison :: proc(p: ^Parser) -> AstIndex {
	left := parse_term(p)

	for peek(p) == .LESS ||
	    peek(p) == .LESS_EQUAL ||
	    peek(p) == .GREATER ||
	    peek(p) == .GREATER_EQUAL {
		op := peek(p)
		advance(p)

		right := parse_term(p)
		#partial switch op {
		case .LESS:
			append(&p.list, LessExpr{left = left, right = right})
		case .LESS_EQUAL:
			append(&p.list, LessEqualExpr{left = left, right = right})
		case .GREATER:
			append(&p.list, GreaterExpr{left = left, right = right})
		case .GREATER_EQUAL:
			append(&p.list, GreaterEqualExpr{left = left, right = right})
		}

		left = len(p.list) - 1
	}

	return left
}

parse_term :: proc(p: ^Parser) -> AstIndex {
	left := parse_factor(p)

	for peek(p) == .PLUS || peek(p) == .MINUS {
		op := peek(p)
		advance(p)

		right := parse_factor(p)
		#partial switch op {
		case .PLUS:
			append(&p.list, AddExpr{left = left, right = right})
		case .MINUS:
			append(&p.list, SubExpr{left = left, right = right})
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
			append(&p.list, MulExpr{left = left, right = right})
		case .SLASH:
			append(&p.list, DivExpr{left = left, right = right})
		case .PERCENT:
			append(&p.list, ModExpr{left = left, right = right})
		case .LSHIFT:
			append(&p.list, LShiftExpr{left = left, right = right})
		case .RSHIFT:
			append(&p.list, RShiftExpr{left = left, right = right})
		case .AMPERSAND:
			append(&p.list, BitAndExpr{left = left, right = right})
		case .PIPE:
			append(&p.list, BitOrExpr{left = left, right = right})
		case .HAT:
			append(&p.list, BitXorExpr{left = left, right = right})
		}

		left = len(p.list) - 1
	}

	return left
}

parse_if_expr :: proc(p: ^Parser) -> AstIndex {
	expect(p, .IF)
	cond := parse_expression(p)
	then_block := parse_statement(p)
	else_block := INVALID_AST_INDEX
	if peek(p) == .ELSE {
		advance(p)
		else_block = parse_statement(p)
	}
	append(&p.list, IfExpr{cond, then_block, else_block})
	return len(p.list) - 1
}

parse_primary :: proc(p: ^Parser) -> AstIndex {
	#partial switch peek(p) {
	case .IDENTIFIER:
		advance(p)
		append(&p.list, VarExpr{ident = p.previous})
		return len(p.list) - 1
	case .INTEGER:
		advance(p)
		append(&p.list, IntLiteral{value = p.previous})
		return len(p.list) - 1
	case .LPAREN:
		advance(p)
		expr := parse_expression(p)
		expect(p, .RPAREN)
		append(&p.list, ParenExpr{node = expr})
		return len(p.list) - 1
	case .NOT:
		advance(p)
		op := parse_primary(p)
		append(&p.list, NotExpr{node = op})
		return len(p.list) - 1
	case .TILDE:
		advance(p)
		op := parse_primary(p)
		append(&p.list, BitNotExpr{node = op})
		return len(p.list) - 1
	case .MINUS:
		advance(p)
		op := parse_primary(p)
		append(&p.list, NegExpr{node = op})
		return len(p.list) - 1
	case .IF:
		return parse_if_expr(p)
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

peek_next :: proc(p: ^Parser) -> lexer.TokenKind {
	return p.token_list[p.current + 1].kind
}

expect :: proc(p: ^Parser, expected: lexer.TokenKind, loc := #caller_location) {
	actual := p.token_list[p.current].kind

	if actual != expected {
		msg := fmt.aprintf("expected %s, got %s, at %s", expected, actual, loc)
		panic(msg)
	}

	advance(p)
}

option :: proc(p: ^Parser, expected: lexer.TokenKind) -> bool {
	if peek(p) == expected {
		advance(p)
		return true
	}
	return false
}

print_spaces :: proc(n: int) {
	for i in 0 ..< n {
		fmt.print(' ')
	}
}

print_node :: proc(p: ^Parser, list: [dynamic]Ast, index: AstIndex, indent: int) {
	if index < 0 || index >= len(list) {
		print_spaces(indent)
		fmt.println("<invalid ast index>")
		return
	}

	node := list[index]
	print_spaces(indent)

	switch v in node {
	case ProgDef:
		fmt.println("ProgDef")
		print_node(p, list, v.node, indent + 2)
	case FuncDef:
		fmt.printfln("FuncDef")
		print_node(p, list, v.node, indent + 2)
	case BlockStmt:
		fmt.println("BlockStmt")
		for stmt in v.stmts {
			print_node(p, list, stmt, indent + 2)
		}
	case InitStmt:
		fmt.println("InitStmt")
		print_spaces(indent + 2)
		token := p.token_list[v.ident]
		ident := cast(string)p.source[token.start:token.end]
		fmt.printf("ident = %v\n", ident)
		print_node(p, list, v.expr, indent + 2)
	case AssignStmt:
		fmt.println("AssignStmt")
		print_spaces(indent + 2)
		token := p.token_list[v.ident]
		ident := cast(string)p.source[token.start:token.end]
		fmt.printf("ident = %v\n", ident)
		print_node(p, list, v.expr, indent + 2)
	case ReturnStmt:
		fmt.println("ReturnStmt")
		print_node(p, list, v.node, indent + 2)
	case IfExpr:
		fmt.println("IfExpr")
		print_node(p, list, v.cond, indent + 2)
		print_node(p, list, v.then_block, indent + 2)
		if v.else_block != INVALID_AST_INDEX {
			print_node(p, list, v.else_block, indent + 2)
		}
	case NotExpr:
		fmt.println("NotExpr")
		print_node(p, list, v.node, indent + 2)
	case BitNotExpr:
		fmt.println("BitNotExpr")
		print_node(p, list, v.node, indent + 2)
	case NegExpr:
		fmt.println("NegExpr")
		print_node(p, list, v.node, indent + 2)
	case ParenExpr:
		fmt.println("ParenExpr")
		print_node(p, list, v.node, indent + 2)
	case BitAndExpr:
		fmt.println("BitAndExpr")
		print_node(p, list, v.left, indent + 2)
		print_node(p, list, v.right, indent + 2)
	case BitOrExpr:
		fmt.println("BitOrExpr")
		print_node(p, list, v.left, indent + 2)
		print_node(p, list, v.right, indent + 2)
	case BitXorExpr:
		fmt.println("BitXorExpr")
		print_node(p, list, v.left, indent + 2)
		print_node(p, list, v.right, indent + 2)
	case MulExpr:
		fmt.println("MulExpr")
		print_node(p, list, v.left, indent + 2)
		print_node(p, list, v.right, indent + 2)
	case DivExpr:
		fmt.println("DivExpr")
		print_node(p, list, v.left, indent + 2)
		print_node(p, list, v.right, indent + 2)
	case ModExpr:
		fmt.println("ModExpr")
		print_node(p, list, v.left, indent + 2)
		print_node(p, list, v.right, indent + 2)
	case AddExpr:
		fmt.println("AddExpr")
		print_node(p, list, v.left, indent + 2)
		print_node(p, list, v.right, indent + 2)
	case SubExpr:
		fmt.println("SubExpr")
		print_node(p, list, v.left, indent + 2)
		print_node(p, list, v.right, indent + 2)
	case LShiftExpr:
		fmt.println("LShiftExpr")
		print_node(p, list, v.left, indent + 2)
		print_node(p, list, v.right, indent + 2)
	case RShiftExpr:
		fmt.println("LShiftExpr")
		print_node(p, list, v.left, indent + 2)
		print_node(p, list, v.right, indent + 2)
	case AndExpr:
		fmt.println("AndExpr")
		print_node(p, list, v.left, indent + 2)
		print_node(p, list, v.right, indent + 2)
	case OrExpr:
		fmt.println("OrExpr")
		print_node(p, list, v.left, indent + 2)
		print_node(p, list, v.right, indent + 2)
	case EqualExpr:
		fmt.println("EqualExpr")
		print_node(p, list, v.left, indent + 2)
		print_node(p, list, v.right, indent + 2)
	case NotEqualExpr:
		fmt.println("NotEqualExpr")
		print_node(p, list, v.left, indent + 2)
		print_node(p, list, v.right, indent + 2)
	case LessExpr:
		fmt.println("LessExpr")
		print_node(p, list, v.left, indent + 2)
		print_node(p, list, v.right, indent + 2)
	case LessEqualExpr:
		fmt.println("LessEqualExpr")
		print_node(p, list, v.left, indent + 2)
		print_node(p, list, v.right, indent + 2)
	case GreaterExpr:
		fmt.println("GreaterExpr")
		print_node(p, list, v.left, indent + 2)
		print_node(p, list, v.right, indent + 2)
	case GreaterEqualExpr:
		fmt.println("GreaterEqualExpr")
		print_node(p, list, v.left, indent + 2)
		print_node(p, list, v.right, indent + 2)
	case IntLiteral:
		fmt.printfln("IntLiteral")
	case VarExpr:
		fmt.printfln("VarExpr")
	}

}

print_ast :: proc(p: ^Parser, ast_list: [dynamic]Ast, indent: int = 0) {
	if len(ast_list) > 0 {
		print_node(p, ast_list, len(ast_list) - 1, indent) // start from the root
	}
	fmt.println()
}
