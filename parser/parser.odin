package parser

import "core:fmt"

import "../lexer"

TokenKind_Set :: bit_set[lexer.TokenKind]

NodeIndex :: distinct u32
INVALID_NODE_INDEX :: max(NodeIndex)

Type :: enum u8 {
	None,
	Real,
	Integer,
	I32,
	F32,
}

NodeKind :: enum u8 {
	Root,
	IntLit,
	IdentLit,
	FuncDecl,
	ParamListDecl,
	ParamDecl,
	VarDecl,
	BlockStmt,
	ReturnStmt,
	IfElseStmt,
	IfStmt,
	WhileStmt,
	ForStmt,
	AssignExpr,
	ExprStmt,
	CallExpr,
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
}

Node :: struct {
	kind:       NodeKind,
	type:       Type,
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

	funcs := make([dynamic]NodeIndex, 0, 1)
	for peek(p) != .Eof {
		append(&funcs, parse_function(p))
	}

	first := NodeIndex(len(p.extra_data))
	append(&p.extra_data, ..funcs[:])
	last := NodeIndex(len(p.extra_data))

	append(&p.nodes, Node{.Root, .None, token, {first, last}})

	return p.nodes
}

parse_function :: proc(p: ^Parser) -> NodeIndex {
	ident := p.current
	expect(p, .Identifier)
	expect(p, .Colon)
	expect(p, .Colon)
	expect(p, .LParen)
	param_list := parse_parameter_list(p)
	expect(p, .RParen)
	expect(p, .Minus)
	expect(p, .Greater)
	return_type := parse_type(p)
	stmt := parse_statement(p)

	append(&p.nodes, Node{.FuncDecl, return_type, ident, {param_list, stmt}})

	return NodeIndex(len(p.nodes) - 1)
}

parse_parameter_list :: proc(p: ^Parser) -> NodeIndex {
	token := p.current
	params_start := NodeIndex(len(p.extra_data))
	for peek(p) != .RParen {
		param_ident := p.current
		expect(p, .Identifier)
		expect(p, .Colon)
		param_type := NodeIndex(parse_type(p))
		append(&p.nodes, Node{.ParamDecl, .None, param_ident, {param_type, INVALID_NODE_INDEX}})
		append(&p.extra_data, NodeIndex(len(p.nodes) - 1))

		if peek(p) == .Comma {
			advance(p)
		} else {
			break // no comma
		}
	}
	params_end := NodeIndex(len(p.extra_data))

	if params_start != params_end {
		append(&p.nodes, Node{.ParamListDecl, .None, token, {params_start, params_end}})
		return NodeIndex(len(p.nodes) - 1)
	}

	return INVALID_NODE_INDEX
}

parse_statement :: proc(p: ^Parser) -> NodeIndex {
	#partial switch peek(p) {
	case .LBrace:
		token := p.current
		advance(p) // {
		stmts := make([dynamic]NodeIndex, 0, 1)
		for peek(p) != .RBrace {
			append(&stmts, parse_statement(p))
		}
		first := NodeIndex(len(p.extra_data))
		append(&p.extra_data, ..stmts[:])
		last := NodeIndex(len(p.extra_data))
		advance(p) // }
		append(&p.nodes, Node{.BlockStmt, .None, token, {first, last}})
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
			append(&p.nodes, Node{.IfElseStmt, .None, token, {condition, extra_index}})
		} else {
			append(&p.nodes, Node{.IfStmt, .None, token, {condition, then_body}})
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
		append(&p.nodes, Node{.ForStmt, .None, token, {body, extra_index}})
	case .Return:
		token := p.current
		advance(p) // .Return
		expr := parse_expression(p)
		append(&p.nodes, Node{.ReturnStmt, .None, token, {expr, INVALID_NODE_INDEX}})
		expect(p, .Semicolon)
	case .Identifier:
		// `ident : type = ...` or `ident : type`
		if peek_next(p) == .Colon {
			// make sure this isn't a function declaration `::`
			p.current += 2
			is_not_func_decl := peek(p) != .Colon
			p.current -= 2

			if is_not_func_decl {
				token := p.current
				advance(p) // ident
				advance(p) // colon
				type_node := NodeIndex(parse_type(p))
				expr_node := INVALID_NODE_INDEX
				if peek(p) == .Assign {
					advance(p)
					expr_node = parse_expression(p)
				}
				append(&p.nodes, Node{.VarDecl, .None, token, {expr_node, type_node}})
				expect(p, .Semicolon)
				return NodeIndex(len(p.nodes) - 1)
			}
		}

		// `ident := ...`
		if peek_next(p) == .Init {
			token := p.current
			advance(p) // ident
			advance(p) // init
			expr := parse_expression(p)
			append(&p.nodes, Node{.VarDecl, .None, token, {expr, INVALID_NODE_INDEX}})
			expect(p, .Semicolon)
			return NodeIndex(len(p.nodes) - 1)
		}

		// expression statement
		token := p.current
		expr := parse_expression(p)
		append(&p.nodes, Node{.ExprStmt, .None, token, {expr, INVALID_NODE_INDEX}})
		expect(p, .Semicolon)
	}

	return NodeIndex(len(p.nodes) - 1)
}

parse_type :: proc(p: ^Parser) -> Type {
	token := p.current
	#partial switch peek(p) {
	case .I32:
		advance(p)
		return Type.I32
	case .F32:
		advance(p)
		return Type.F32
	case .Bool:
	}
	msg := fmt.tprintf("expected a type, got %s", peek(p))
	panic(msg)
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
		append(&p.nodes, Node{.AssignExpr, .None, token, {expr, value}})
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
			append(&p.nodes, Node{.EqualExpr, .None, token, {left, right}})
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
			append(&p.nodes, Node{.AddExpr, .None, token, {left, right}})
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
			append(&p.nodes, Node{.MulExpr, .None, token, {left, right}})
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
		if peek_next(p) == .LParen {
			return parse_call_expression(p)
		}
		token := p.current
		advance(p)
		append(&p.nodes, Node{.IdentLit, .None, token, {}})
	case .Integer:
		token := p.current
		advance(p)
		append(&p.nodes, Node{.IntLit, .Integer, token, {}})
	case .LParen:
		token := p.current
		advance(p)
		expr := parse_expression(p)
		expect(p, .RParen)
	case .Minus:
		token := p.current
		advance(p)
		expr := parse_expression(p)
		append(&p.nodes, Node{.NegateExpr, .None, token, {expr, INVALID_NODE_INDEX}})
	}

	return NodeIndex(len(p.nodes) - 1)
}

parse_call_expression :: proc(p: ^Parser) -> NodeIndex {
	token := p.current
	advance(p) // identifier
	advance(p) // lparen

	args_start := NodeIndex(len(p.extra_data))
	for peek(p) != .RParen {
		append(&p.extra_data, parse_expression(p))
		if peek(p) == .Comma {
			advance(p)
		}
	}
	args_end := NodeIndex(len(p.extra_data))
	expect(p, .RParen)

	append(&p.nodes, Node{.CallExpr, .None, token, {args_start, args_end}})
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
			first := node.data.lhs
			last := node.data.rhs
			for i in first ..= last - 1 {
				func_index := p.extra_data[i]
				print_node(p, func_index, indent + 2)
			}
		case .FuncDecl:
			fmt.printf("FuncDecl, return_type = %v\n", node.type)
			param_list := node.data.lhs
			body_node := node.data.rhs
			if param_list != INVALID_NODE_INDEX {
				print_node(p, param_list, indent + 2)
			}
			print_node(p, body_node, indent + 2)
		case .ParamListDecl:
			fmt.printf("ParamList\n")
			first := node.data.lhs
			last := node.data.rhs
			for i in first ..< last {
				param_index := p.extra_data[i]
				print_node(p, param_index, indent + 2)
			}
		case .ParamDecl:
			fmt.printf("ParamDecl, type = %v\n", node.type)
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
			fmt.printf("ReturnStmt, type = %v\n", node.type)
			print_node(p, node.data.lhs, indent + 2)
		case .IfStmt:
			fmt.printf("IfStmt\n")
			cond_node := node.data.lhs
			then_node := node.data.rhs
			print_node(p, cond_node, indent + 2)
			print_node(p, then_node, indent + 2)
		case .IfElseStmt:
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
			if node.data.rhs != INVALID_NODE_INDEX {
				print_node(p, node.data.rhs, indent + 2)
			}
			if node.data.lhs != INVALID_NODE_INDEX {
				print_node(p, node.data.lhs, indent + 2)
			}
		case .AssignExpr:
			fmt.printf("AssignExpr\n")
			print_node(p, node.data.lhs, indent + 2)
			print_node(p, node.data.rhs, indent + 2)
		case .ExprStmt:
			fmt.printf("ExprStmt\n")
			print_node(p, node.data.lhs, indent + 2)
		case .IntLit:
			fmt.printf("IntLit, type = %v\n", node.type)
		case .IdentLit:
			fmt.printf("IdentLit, type = %v\n", node.type)
		case .EqualExpr:
			fmt.printf("EqualExpr\n")
			print_node(p, node.data.lhs, indent + 2)
			print_node(p, node.data.rhs, indent + 2)
		case .AddExpr:
			fmt.printf("AddExpr, type = %v\n", node.type)
			print_node(p, node.data.lhs, indent + 2)
			print_node(p, node.data.rhs, indent + 2)
		case .MulExpr:
			fmt.printf("MulExpr, type = %v\n", node.type)
			print_node(p, node.data.lhs, indent + 2)
			print_node(p, node.data.rhs, indent + 2)
		case .CallExpr:
			fmt.printf("CallExpr, type = %v\n", node.type)
			first := node.data.lhs
			last := node.data.rhs
			for i in first ..= last - 1 {
				arg_index := p.extra_data[i]
				print_node(p, arg_index, indent + 2)
			}
		case .NegateExpr:
			fmt.printf("NegateExpr\n")
		}
	}

	print_node(p, NodeIndex(len(p.nodes) - 1), indent)
}
