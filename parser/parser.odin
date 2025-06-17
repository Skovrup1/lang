package parser

import "core:fmt"

import "../lexer"

TokenKind_Set :: bit_set[lexer.TokenKind]

NodeIndex :: distinct u32
INVALID_NODE_INDEX :: max(NodeIndex)

NodeKind :: enum u8 {
	Root,
	FuncDecl,
	VarDecl,
	BlockStmt,
	ReturnStmt,
	IfStmt,
	IfSimpleStmt, // no else
	WhileStmt,
	ForStmt,
	AssignExpr,
	ExprStmt,
	//CallExpr,
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
	EqualExpr,
	//NotEqualExpr,
	//BitAndExpr,
	//BitXorExpr,
	//BitOrExpr,
	//AndExpr,
	//OrExpr,
	NegateExpr,
	//NotExpr,
	//BitNotExpr,
	IntLit,
	IdentLit,
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
	tokens:     []lexer.Token,
	nodes:      [dynamic]Node,
	extra_data: [dynamic]NodeIndex,
}

make_parser :: proc(source: []u8, tokens: []lexer.Token) -> Parser {
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
	append(&p.nodes, Node{.Root, token, {func, INVALID_NODE_INDEX}})

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

	proto := INVALID_NODE_INDEX
	stmt := parse_statement(p)
	append(&p.nodes, Node{.FuncDecl, ident, {proto, stmt}})

	return NodeIndex(len(p.nodes) - 1)
}

parse_statement :: proc(p: ^Parser) -> NodeIndex {
	#partial switch peek(p) {
	case .LBrace:
		token := p.current
		advance(p) // {
		stmts := make([dynamic]NodeIndex, 0, 1, context.temp_allocator)
		for peek(p) != .RBrace {
			append(&stmts, parse_statement(p))
		}
		first := NodeIndex(len(p.extra_data))
		append(&p.extra_data, ..stmts[:])
		last := NodeIndex(len(p.extra_data))
		advance(p) // }
		append(&p.nodes, Node{.BlockStmt, token, {first, last}})
	case .If:
		token := p.current
		advance(p) // .If
		condition := parse_expression(p)
		then_body := parse_statement(p)
		if peek(p) == .Else {
			advance(p) // .Else
			else_body := parse_statement(p)
			extra_index := NodeIndex(len(p.extra_data))
			append(&p.extra_data, then_body)
			append(&p.extra_data, else_body)
			append(&p.nodes, Node{.IfStmt, token, {condition, extra_index}})
		} else {
			append(&p.nodes, Node{.IfSimpleStmt, token, {condition, then_body}})
		}
	case .While:
		panic("todo")
	case .For:
		token := p.current
		advance(p) // .For
		init := parse_statement(p)
		cond := parse_expression(p)
		expect(p, .Semicolon)
		incr := parse_expression(p)
		body := parse_statement(p)

		extra_index := NodeIndex(len(p.extra_data))
		append(&p.extra_data, init)
		append(&p.extra_data, cond)
		append(&p.extra_data, incr)
		append(&p.nodes, Node{.ForStmt, token, {body, extra_index}})
	case .Return:
		token := p.current
		advance(p) // .Return
		expr := parse_expression(p)
		append(&p.nodes, Node{.ReturnStmt, token, {expr, INVALID_NODE_INDEX}})
		expect(p, .Semicolon)
	case .Identifier:
		token := p.current
		advance(p) // .Identifier
		if peek(p) == .Init {
			advance(p) // Init
			expr := parse_expression(p)
			append(&p.nodes, Node{.VarDecl, token, {expr, INVALID_NODE_INDEX}})
			expect(p, .Semicolon)
		} else {
			// expression statement
			p.current = token // backtrack
			expr := parse_expression(p)
			append(&p.nodes, Node{.ExprStmt, token, {expr, INVALID_NODE_INDEX}})
			expect(p, .Semicolon)
		}
	}

	return NodeIndex(len(p.nodes) - 1)
}

parse_expression :: proc(p: ^Parser) -> NodeIndex {
	return parse_assignment(p)
}

parse_assignment :: proc(p: ^Parser) -> NodeIndex {
	expr := parse_logical_or(p)

	if peek(p) == .Assign {
		token := p.current
		advance(p)
		value := parse_assignment(p)
		append(&p.nodes, Node{.AssignExpr, token, {expr, value}})
		return NodeIndex(len(p.nodes) - 1)
	}

	return expr
}

parse_logical_or :: proc(p: ^Parser) -> NodeIndex {
	#partial switch (peek(p)) {
	case .Or:
		panic("todo")
	}

	return parse_logical_and(p)
}

parse_logical_and :: proc(p: ^Parser) -> NodeIndex {
	#partial switch (peek(p)) {
	case .And:
		panic("todo")
	}

	return parse_equality(p)
}

parse_equality :: proc(p: ^Parser) -> NodeIndex {
	left := parse_comparison(p)

	for peek(p) == .Equal || peek(p) == .NotEqual {
		op := peek(p)
		token := p.current
		advance(p)

		right := parse_comparison(p)
		#partial switch op {
		case .Equal:
			append(&p.nodes, Node{.EqualExpr, token, {left, right}})
		case .NotEqual:
			panic("todo")
		}

		left = NodeIndex(len(&p.nodes) - 1)
	}

	return left
}

parse_comparison :: proc(p: ^Parser) -> NodeIndex {
	#partial switch (peek(p)) {
	case .Less:
		panic("todo")
	case .LessEqual:
		panic("todo")
	case .Greater:
		panic("todo")
	case .GreaterEqual:
		panic("todo")
	}
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
		append(&p.nodes, Node{.IdentLit, p.previous, {}})
	case .Integer:
		advance(p)
		append(&p.nodes, Node{.IntLit, p.previous, {}})
	case .LParen:
		advance(p)
		token := p.previous
		expr := parse_expression(p)
		expect(p, .RParen)
	case .Minus:
		advance(p)
		token := p.previous
		expr := parse_expression(p)
		append(&p.nodes, Node{.NegateExpr, token, {expr, INVALID_NODE_INDEX}})
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
		case .Root:
			fmt.printf("Root\n")
			print_node(p, node.data.lhs, indent + 2)
		case .FuncDecl:
			fmt.printf("FuncDecl\n")
			print_node(p, node.data.rhs, indent + 2)
		case .BlockStmt:
			fmt.printf("BlockStmt\n")
			first := node.data.lhs
			last := node.data.rhs
			for i in first ..= last - 1 {
				stmt_index := p.extra_data[i]
				print_node(p, stmt_index, indent + 2)
			}
		case .ForStmt:
			fmt.printf("ForStmt\n")
		case .WhileStmt:
			fmt.printf("WhileStmt\n")
		case .ReturnStmt:
			fmt.printf("ReturnStmt\n")
			print_node(p, node.data.lhs, indent + 2)
		case .IfSimpleStmt:
			fmt.printf("IfStmt\n")
			cond_node := node.data.lhs
			then_node := node.data.rhs
			print_node(p, cond_node, indent + 2)
			print_node(p, then_node, indent + 2)
		case .IfStmt:
			fmt.printf("IfStmt\n")
			cond_node := node.data.lhs
			extra_node := node.data.rhs
			then_node := p.extra_data[extra_node]
			else_node := p.extra_data[extra_node + 1]
			print_node(p, cond_node, indent + 2)
			print_node(p, then_node, indent + 2)
			print_node(p, else_node, indent + 2)
		case .VarDecl:
			fmt.printf("VarDecl\n")
			print_node(p, node.data.lhs, indent + 2)
		case .AssignExpr:
			fmt.printf("AssignExpr\n")
			print_node(p, node.data.lhs, indent + 2)
			print_node(p, node.data.rhs, indent + 2)
		case .ExprStmt:
			fmt.printf("ExprStmt\n")
			print_node(p, node.data.lhs, indent + 2)
		case .IntLit:
			fmt.printf("IntLit\n")
		case .IdentLit:
			fmt.printf("IdentLit\n")
		case .EqualExpr:
			fmt.printf("EqualExpr\n")
			print_node(p, node.data.lhs, indent + 2)
			print_node(p, node.data.rhs, indent + 2)
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
