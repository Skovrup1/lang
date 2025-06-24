package parser

import "core:fmt"
import "core:strconv"

import "../lexer"

TokenKind_Set :: bit_set[lexer.TokenKind]

NodeIndex :: distinct i32
INVALID_NODE: NodeIndex : -1

NodeKind :: enum i32 {
	ProgDef,
	FuncDef,
	BlockStmt,
	ReturnStmt,
	VarStmt,
	IfStmt,
	AssignStmt,
	IntExpr,
	VarExpr,
	MulExpr,
	//DivExpr,
	//ModExpr,
	AddExpr,
	//SubExpr,
	//LShiftExpr,
	//RShiftExpr,
	//LessExpr,
	//LessEqualExpr,
	//GreaterExpr,
	//GreaterEqualExpr,
	//EqualExpr,
	//NotEqualExpr,
	//BitAndExpr,
	//BitXorExpr,
	//BitOrExpr,
	//AndExpr,
	//OrExpr,
	NegateExpr,
	//NotExpr,
	//bitNotExpr,
}

Node :: struct {
	kind:       NodeKind,
	main_token: lexer.TokenIndex,
	data:       struct {
		lhs: NodeIndex,
		rhs: NodeIndex,
	},
}

Parser :: struct {
	current:    lexer.TokenIndex,
	previous:   lexer.TokenIndex,
	source:     []u8,
	tokens:     [dynamic]lexer.Token,
	nodes:      [dynamic]Node,
	extra_data: [dynamic]NodeIndex,
}

make_parser :: proc(source: []u8, tokens: [dynamic]lexer.Token) -> Parser {
	return Parser{0, 0, source, tokens, make([dynamic]Node), make([dynamic]NodeIndex)}
}

advance :: proc(p: ^Parser) {
	p.previous = p.current
	p.current += 1
}

peek :: proc(p: ^Parser) -> lexer.TokenKind {
	return p.tokens[p.current].kind
}

peek_next :: proc(p: ^Parser) -> lexer.TokenKind {
	return p.tokens[p.current + 1].kind
}

expect :: proc(p: ^Parser, expected: lexer.TokenKind, loc := #caller_location) {
	actual := peek(p)

	if actual != expected {
		msg := fmt.aprintf("expected %s, got %s, at %s", expected, actual, loc)
		panic(msg)
	}

	advance(p)
}

option :: proc(p: ^Parser, expected: lexer.TokenKind) {
	if peek(p) == expected {
		advance(p)
	}
}

parse :: proc(p: ^Parser) -> [dynamic]Node {
	token := p.current
	func := parse_function(p)
	append(&p.nodes, Node{.ProgDef, token, {func, INVALID_NODE}})

	return p.nodes
}

parse_function :: proc(p: ^Parser) -> NodeIndex {
	ident := p.current
	expect(p, .Identifier)
	expect(p, .Colon)
	expect(p, .Colon)
	expect(p, .LParen)
	expect(p, .RParen)
	expect(p, .Minus)
	expect(p, .Greater)
	expect(p, .I32)

	proto := INVALID_NODE
	stmt := parse_statement(p)
	append(&p.nodes, Node{.FuncDef, ident, {proto, stmt}})

	return NodeIndex(len(p.nodes) - 1)
}

parse_statement :: proc(p: ^Parser) -> NodeIndex {
	#partial switch peek(p) {
	case .LBrace:
		token := p.current
		advance(p) // {
		// note: currently this does not allow empty blocks
		first := NodeIndex(len(p.extra_data))
		for peek(p) != .RBrace {
			append(&p.extra_data, parse_statement(p))
		}
		last := NodeIndex(len(p.extra_data) - 1)
		advance(p) // }
		append(&p.nodes, Node{.BlockStmt, token, {first, last}})
	case .If:
		panic("todo")
	/*
		advance(p) // .If
		condition := parse_expression()
		if_body := parse_statement()
		else_body: NodeIndex
		if peek(p) == .Else {
			advance(p)
			else_body = parse_statement()
		}
        append(&p.nodes, Node{.IfStmt, p.current, {cond, body, else_body}}
        */
	case .While:
		panic("todo")
	case .Return:
		token := p.current
		advance(p)
		expr := parse_expression(p)
		append(&p.nodes, Node{.ReturnStmt, token, {expr, INVALID_NODE}})
	case .Identifier:
		token := p.current
		advance(p)
		if peek(p) == .Init {
			advance(p)
			expr := parse_expression(p)
			append(&p.nodes, Node{.VarStmt, token, {expr, INVALID_NODE}})
		} else if peek(p) == .Assign {
			advance(p)
			expr := parse_expression(p)
			append(&p.nodes, Node{.AssignStmt, token, {expr, INVALID_NODE}})
		} else {
			panic("oops")
		}
	case:
		// expression stmt
		expr := parse_expression(p)
		expect(p, .Semicolon)
	}

	return NodeIndex(len(p.nodes) - 1)
}

parse_expression :: proc(p: ^Parser) -> NodeIndex {
	return parse_logical_or(p)
}

parse_logical_or :: proc(p: ^Parser) -> NodeIndex {
	return parse_logical_and(p)
}

parse_logical_and :: proc(p: ^Parser) -> NodeIndex {
	return parse_equality(p)
}

parse_equality :: proc(p: ^Parser) -> NodeIndex {
	return parse_comparison(p)
}

parse_comparison :: proc(p: ^Parser) -> NodeIndex {
	return parse_term(p)
}

is_term :: proc(kind: lexer.TokenKind) -> bool {
	term_set: TokenKind_Set = {.Plus}

	return kind in term_set
}

parse_term :: proc(p: ^Parser) -> NodeIndex {
	left := parse_factor(p)

	for is_term(peek(p)) {
		op := peek(p)
		token := p.current
		advance(p)

		right := parse_factor(p)
		#partial switch op {
		case .Plus:
			append(&p.nodes, Node{.AddExpr, token, {left, right}})
		case .Minus:
			panic("todo")
		}

		left = NodeIndex(len(&p.nodes) - 1)
	}

	return left
}

is_factor :: proc(kind: lexer.TokenKind) -> bool {
	term_set: TokenKind_Set = {.Asterisk}

	return kind in term_set
}

parse_factor :: proc(p: ^Parser) -> NodeIndex {
	left := parse_primary(p)

	for is_factor(peek(p)) {
		op := peek(p)
		token := p.current
		advance(p)

		right := parse_primary(p)
		#partial switch op {
		case .Asterisk:
			append(&p.nodes, Node{.MulExpr, token, {left, right}})
		case .Slash:
			panic("todo")
		}

		left = NodeIndex(len(&p.nodes) - 1)
	}

	return left
}

parse_primary :: proc(p: ^Parser) -> NodeIndex {
	#partial switch peek(p) {
	case .Identifier:
		advance(p)
		append(&p.nodes, Node{.VarExpr, p.previous, {}})
	case .Integer:
		advance(p)
		append(&p.nodes, Node{.IntExpr, p.previous, {}})
	case .LParen:
		advance(p)
		token := p.previous
		expr := parse_expression(p)
		expect(p, .RParen)
	case .Minus:
		advance(p)
		token := p.previous
		expr := parse_expression(p)
		append(&p.nodes, Node{.NegateExpr, token, {expr, INVALID_NODE}})
	}

	return NodeIndex(len(p.nodes) - 1)
}

print_ast :: proc(p: ^Parser, indent: int = 0) {
	print_indent :: proc(indent: int) {
		for _ in 0 ..< indent {
			fmt.print("  ")
		}
	}

	print_node :: proc(p: ^Parser, index: NodeIndex, indent: int = 0) {
		print_indent(indent)

		node := p.nodes[index]
		switch node.kind {
		case .ProgDef:
			fmt.printf("ProgDef\n")
			print_node(p, node.data.lhs, indent + 2)
		case .FuncDef:
			fmt.printf("FuncDef\n")
			print_node(p, node.data.rhs, indent + 2)
		case .BlockStmt:
			fmt.printf("BlockStmt\n")
			first := node.data.lhs
			last := node.data.rhs
			for i in first ..< last {
				stmt_index := p.extra_data[i]
				print_node(p, stmt_index, indent + 2)
			}
		case .ReturnStmt:
			fmt.printf("ReturnStmt\n")
			print_node(p, node.data.lhs, indent + 2)
		case .IfStmt:
			fmt.printf("IfStmt\n")
		case .VarStmt:
			fmt.printf("VarStmt\n")
			print_node(p, node.data.lhs, indent + 2)
		case .AssignStmt:
			fmt.printf("AssignStmt\n")
			print_node(p, node.data.lhs, indent + 2)
		case .IntExpr:
			fmt.printf("IntExpr\n")
		case .VarExpr:
			fmt.printf("VarExpr\n")
		case .AddExpr:
			fmt.printf("AddExpr\n")
			print_node(p, node.data.lhs, indent + 2)
			print_node(p, node.data.rhs, indent + 2)
		case .MulExpr:
			fmt.printf("MulExpr\n")
			print_node(p, node.data.lhs, indent + 2)
			print_node(p, node.data.rhs, indent + 2)
		case .NegateExpr:
			fmt.printf("NegateExpr\n")
		}
	}

	print_node(p, NodeIndex(len(p.nodes) - 1), indent)
}
