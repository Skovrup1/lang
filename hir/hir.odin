package hir

import "../lexer"
import "../parser"

import "core:fmt"
import "core:strconv"
import "core:strings"

InstIndex :: distinct u32

ExtraIndex :: distinct u32
INVALID_EXTRA_INDEX :: max(ExtraIndex)

InstKind :: enum u8 {
	Label,
	Return,
	Equal,
	Add,
	Mul,
	Int,
	Jump,
	Branch,
	Alloc,
	Load,
	Store,
	Call,
	Arg,
}

Inst :: struct {
	kind: InstKind,
	data: u32,
}

Scope :: map[string]InstIndex

SymbolTable :: struct {
	scopes: [dynamic]Scope,
}

Generator :: struct {
	instructions: [dynamic]Inst,
	extra:        [dynamic]u32,
	label_names:  map[InstIndex]string,
	symbol_table: SymbolTable,
	label_count:  int,
	param_count:  int,
	source:       []u8,
	tokens:       []lexer.Token,
	nodes:        []parser.Node,
	extra_data:   []parser.NodeIndex,
}

make_generator :: proc(
	source: []u8,
	tokens: []lexer.Token,
	nodes: []parser.Node,
	extra_data: []parser.NodeIndex,
) -> Generator {
	instructions := make([dynamic]Inst)
	extra := make([dynamic]u32)
	label_names := make(map[InstIndex]string)
	symbol_table := SymbolTable{make([dynamic]Scope)}

	return Generator {
		instructions,
		extra,
		label_names,
		symbol_table,
		0,
		0,
		source,
		tokens,
		nodes,
		extra_data,
	}
}

enter_scope :: proc(g: ^Generator) {
	append(&g.symbol_table.scopes, make(Scope))
}

leave_scope :: proc(g: ^Generator) {
	pop(&g.symbol_table.scopes)
}

find_symbol :: proc(g: ^Generator, name: string) -> (InstIndex, bool) {
	#reverse for scope, i in g.symbol_table.scopes {
		if val, ok := scope[name]; ok {
			return val, true
		}
	}

	return InstIndex(0), false
}

add_symbol :: proc(g: ^Generator, name: string, inst: InstIndex) {
	g.symbol_table.scopes[len(g.symbol_table.scopes) - 1][name] = inst
}

generate :: proc(g: ^Generator) {
	enter_scope(g)
	generate_node(g, g.nodes[len(g.nodes) - 1])
	leave_scope(g)
}

generate_node :: proc(g: ^Generator, node: parser.Node) -> InstIndex {
	switch node.kind {
	case .Root:
		first := node.data.lhs
		last := node.data.rhs
		for i in first ..< last {
			func_index := g.extra_data[i]
			generate_node(g, g.nodes[func_index])
		}
		return InstIndex(INVALID_EXTRA_INDEX)
	case .FuncDecl:
		label_index := InstIndex(len(g.instructions))
		append(&g.instructions, Inst{.Label, u32(INVALID_EXTRA_INDEX)})

		name_token := g.tokens[node.main_token]
		name := cast(string)g.source[name_token.start:name_token.end]
		g.label_names[label_index] = name
		add_symbol(g, name, label_index)

		enter_scope(g)
		g.param_count = 0

		if node.data.lhs != parser.INVALID_NODE_INDEX {
			generate_node(g, g.nodes[node.data.lhs])
		}

		generate_node(g, g.nodes[node.data.rhs])
		leave_scope(g)

		return label_index
	case .ParamList:
		first := node.data.lhs
		last := node.data.rhs
		for i in first ..< last {
			param_index := g.extra_data[i]
			generate_node(g, g.nodes[param_index])
		}
	case .ParamDecl:
		token := g.tokens[node.main_token]
		name := cast(string)g.source[token.start:token.end]

		arg_inst := InstIndex(len(g.instructions))
		append(&g.instructions, Inst{.Arg, u32(g.param_count)})
		g.param_count += 1

		alloc := InstIndex(len(g.instructions))
		append(&g.instructions, Inst{.Alloc, u32(arg_inst)})
		add_symbol(g, name, alloc)
	case .VarDecl:
		token := g.tokens[node.main_token]
		str := cast(string)g.source[token.start:token.end]
		expr := get_lhs(g, node)

		alloc := InstIndex(len(g.instructions))
		append(&g.instructions, Inst{.Alloc, u32(expr)})
		add_symbol(g, str, alloc)
	case .BlockStmt:
		enter_scope(g)
		stmts := get_block_slice(g, node)
		for stmt_index in stmts {
			stmt_node := g.nodes[stmt_index]
			generate_node(g, stmt_node)
		}
		leave_scope(g)
	case .ExprStmt:
		get_lhs(g, node)
	case .ForStmt:
		enter_scope(g)

		extra_data_index := node.data.rhs
		init_node := g.nodes[g.extra_data[extra_data_index]]
		cond_node := g.nodes[g.extra_data[extra_data_index + 1]]
		incr_node := g.nodes[g.extra_data[extra_data_index + 2]]
		body_node := g.nodes[node.data.lhs]

		generate_node(g, init_node)

		cond_label := InstIndex(len(g.instructions))
		append(&g.instructions, Inst{.Label, u32(INVALID_EXTRA_INDEX)})
		g.label_names[cond_label] = new_label(g)
		cond_val := generate_node(g, cond_node)

		branch := InstIndex(len(g.instructions))
		append(&g.instructions, Inst{.Branch, u32(INVALID_EXTRA_INDEX)})

		body_label := InstIndex(len(g.instructions))
		append(&g.instructions, Inst{.Label, u32(INVALID_EXTRA_INDEX)})
		g.label_names[body_label] = new_label(g)
		generate_node(g, body_node)
		generate_node(g, incr_node)

		append(&g.instructions, Inst{.Jump, u32(cond_label)})

		exit_label := InstIndex(len(g.instructions))
		append(&g.instructions, Inst{.Label, u32(INVALID_EXTRA_INDEX)})
		g.label_names[exit_label] = new_label(g)

		g.instructions[branch].data = u32(len(g.extra))
		append(&g.extra, u32(cond_val))
		append(&g.extra, u32(body_label))
		append(&g.extra, u32(exit_label))

		leave_scope(g)
	case .WhileStmt:
		panic("todo")
	case .ReturnStmt:
		expr := get_lhs(g, node)
		append(&g.instructions, Inst{.Return, u32(expr)})
	case .IfSimpleStmt:
		condition := get_lhs(g, node)

		branch := InstIndex(len(g.instructions))
		append(&g.instructions, Inst{.Branch, u32(INVALID_EXTRA_INDEX)})

		then_node := g.nodes[node.data.rhs]

		then_label := InstIndex(len(g.instructions))
		append(&g.instructions, Inst{.Label, u32(INVALID_EXTRA_INDEX)})
		g.label_names[then_label] = new_label(g)
		generate_node(g, then_node)

		then_is_not_return := g.instructions[len(g.instructions) - 1].kind != .Return
		end_jump: InstIndex
		if then_is_not_return {
			end_jump = InstIndex(len(g.instructions))
			append(&g.instructions, Inst{.Jump, u32(INVALID_EXTRA_INDEX)})
		}

		end_label := InstIndex(len(g.instructions))
		append(&g.instructions, Inst{.Label, u32(INVALID_EXTRA_INDEX)})
		g.label_names[end_label] = new_label(g)

		if then_is_not_return {
			g.instructions[end_jump].data = u32(end_label)
		}

		g.instructions[branch].data = u32(len(g.extra))
		append(&g.extra, u32(condition))
		append(&g.extra, u32(then_label))
		append(&g.extra, u32(end_label))
	case .IfStmt:
		condition := get_lhs(g, node)

		branch := InstIndex(len(g.instructions))
		append(&g.instructions, Inst{.Branch, u32(INVALID_EXTRA_INDEX)})

		extra_data_index := parser.NodeIndex(node.data.rhs)
		then_node := g.nodes[g.extra_data[extra_data_index]]
		else_node := g.nodes[g.extra_data[extra_data_index + 1]]

		then_label := InstIndex(len(g.instructions))
		append(&g.instructions, Inst{.Label, u32(INVALID_EXTRA_INDEX)})
		g.label_names[then_label] = new_label(g)
		generate_node(g, then_node)

		then_is_not_return := g.instructions[len(g.instructions) - 1].kind != .Return
		then_jump: InstIndex
		if then_is_not_return {
			then_jump = InstIndex(len(g.instructions))
			append(&g.instructions, Inst{.Jump, u32(INVALID_EXTRA_INDEX)})
		}

		else_label := InstIndex(len(g.instructions))
		append(&g.instructions, Inst{.Label, u32(INVALID_EXTRA_INDEX)})
		g.label_names[else_label] = new_label(g)
		generate_node(g, else_node)

		else_is_not_return := g.instructions[len(g.instructions) - 1].kind != .Return
		else_jump: InstIndex
		if else_is_not_return {
			else_jump = InstIndex(len(g.instructions))
			append(&g.instructions, Inst{.Jump, u32(INVALID_EXTRA_INDEX)})
		}

		merge_label: InstIndex
		if then_is_not_return || else_is_not_return {
			merge_label = InstIndex(len(g.instructions))
			append(&g.instructions, Inst{.Label, u32(INVALID_EXTRA_INDEX)})
			g.label_names[merge_label] = new_label(g)
		}

		if then_is_not_return {
			g.instructions[then_jump].data = u32(merge_label)
		}
		if else_is_not_return {
			g.instructions[else_jump].data = u32(merge_label)
		}

		g.instructions[branch].data = u32(len(g.extra))
		append(&g.extra, u32(condition))
		append(&g.extra, u32(then_label))
		append(&g.extra, u32(else_label))
	case .AssignExpr:
		val := get_rhs(g, node)
		lhs := g.nodes[node.data.lhs]
		if lhs.kind == .IdentLit {
			token := g.tokens[lhs.main_token]
			ident := cast(string)g.source[token.start:token.end]
			alloc, _ := find_symbol(g, ident)
			append(&g.instructions, Inst{.Store, u32(len(g.extra))})
			append(&g.extra, u32(alloc))
			append(&g.extra, u32(val))
		} else {
			panic("cannot assign to non-identifier")
		}
	case .EqualExpr:
		lhs, rhs := get_bin(g, node)
		extra_index := u32(len(g.extra))
		append(&g.extra, u32(lhs))
		append(&g.extra, u32(rhs))
		append(&g.instructions, Inst{.Equal, extra_index})
	case .MulExpr:
		lhs, rhs := get_bin(g, node)
		extra_index := u32(len(g.extra))
		append(&g.extra, u32(lhs))
		append(&g.extra, u32(rhs))
		append(&g.instructions, Inst{.Mul, extra_index})
	case .AddExpr:
		lhs, rhs := get_bin(g, node)
		extra_index := u32(len(g.extra))
		append(&g.extra, u32(lhs))
		append(&g.extra, u32(rhs))
		append(&g.instructions, Inst{.Add, extra_index})
	case .NegateExpr:
	case .CallExpr:
		name_token := g.tokens[node.main_token]
		name := cast(string)g.source[name_token.start:name_token.end]

		label, ok := find_symbol(g, name)
		if !ok {
			panic("could not find function")
		}

		args_start := node.data.lhs
		args_end := node.data.rhs
		args := g.extra_data[args_start:args_end]

		arg_insts := make([dynamic]u32, len(args))
		for arg, i in args {
			arg_insts[i] = u32(generate_node(g, g.nodes[arg]))
		}

		extra_index := u32(len(g.extra))
		append(&g.extra, u32(label))
		append(&g.extra, ..arg_insts[:])

		append(&g.instructions, Inst{.Call, extra_index})
	case .IntLit:
		token := g.tokens[node.main_token]
		str := cast(string)g.source[token.start:token.end]
		value := strconv.atoi(str)
		append(&g.instructions, Inst{.Int, u32(value)})
	case .IdentLit:
		token := g.tokens[node.main_token]
		ident := cast(string)g.source[token.start:token.end]
		alloc, _ := find_symbol(g, ident)
		append(&g.instructions, Inst{.Load, u32(alloc)})
	}

	return InstIndex(len(g.instructions) - 1)
}

new_label :: proc(g: ^Generator) -> string {
	label := fmt.tprintf("L%d", g.label_count)
	g.label_count += 1
	return label
}

get_lhs :: proc(g: ^Generator, node: parser.Node) -> InstIndex {
	return generate_node(g, g.nodes[node.data.lhs])
}

get_rhs :: proc(g: ^Generator, node: parser.Node) -> InstIndex {
	return generate_node(g, g.nodes[node.data.rhs])
}

get_bin :: proc(g: ^Generator, node: parser.Node) -> (InstIndex, InstIndex) {
	lhs := generate_node(g, g.nodes[node.data.lhs])
	rhs := generate_node(g, g.nodes[node.data.rhs])
	return lhs, rhs
}

get_block_slice :: proc(g: ^Generator, node: parser.Node) -> []parser.NodeIndex {
	first := node.data.lhs
	last := node.data.rhs
	return g.extra_data[first:last]
}

print :: proc(g: ^Generator) {
	for inst, i in g.instructions {
		#partial switch inst.kind {
		case .Label:
			name, ok := g.label_names[InstIndex(i)]
			if ok {
				fmt.printf("%v:\n", name)
			} else {
				fmt.printf("$%v:\n", i)
			}
		case .Jump:
			jump_label := g.label_names[InstIndex(inst.data)]
			fmt.printf("    jump %v\n", jump_label)
		case .Branch:
			extra_index := inst.data
			condition := InstIndex(g.extra[extra_index])
			then_inst := InstIndex(g.extra[extra_index + 1])
			else_inst := InstIndex(g.extra[extra_index + 2])
			then_label := g.label_names[then_inst]
			else_label := g.label_names[else_inst]
			fmt.printf("    branch t%v, %v, %v\n", condition, then_label, else_label)
		case .Int:
			fmt.printf("    t%v = int %v\n", i, inst.data)
		case .Equal:
			extra_index := inst.data
			lhs_inst := InstIndex(g.extra[extra_index])
			rhs_inst := InstIndex(g.extra[extra_index + 1])
			fmt.printf("    t%v = t%v == t%v\n", i, lhs_inst, rhs_inst)
		case .Add:
			extra_index := inst.data
			lhs_inst := InstIndex(g.extra[extra_index])
			rhs_inst := InstIndex(g.extra[extra_index + 1])
			fmt.printf("    t%v = t%v + t%v\n", i, lhs_inst, rhs_inst)
		case .Mul:
			extra_index := inst.data
			lhs_inst := InstIndex(g.extra[extra_index])
			rhs_inst := InstIndex(g.extra[extra_index + 1])
			fmt.printf("    t%v = t%v * t%v\n", i, lhs_inst, rhs_inst)
		case .Alloc:
			fmt.printf("    t%v = alloc t%v\n", i, inst.data)
		case .Load:
			fmt.printf("    t%v = load t%v\n", i, inst.data)
		case .Store:
			extra_index := inst.data
			alloc_inst := InstIndex(g.extra[extra_index])
			val_inst := InstIndex(g.extra[extra_index + 1])
			fmt.printf("    store t%v, t%v\n", alloc_inst, val_inst)
		case .Return:
			ret_inst := inst.data
			fmt.printf("    return t%v\n", ret_inst)
		case .Arg:
			fmt.printf("    t%v = arg %v\n", i, inst.data)
		case .Call:
			extra_index := inst.data
			label := InstIndex(g.extra[extra_index])

			name, ok := g.label_names[label]
			if !ok {
				panic("could not find function name")
			}

			args_start := extra_index + 1
			args_end := u32(len(g.extra))

			fmt.printf("    t%v = call %v(", i, name)
			for arg_index in args_start ..= args_end - 1 {
				fmt.printf("t%v", g.extra[arg_index])
				if arg_index != args_end - 1 {
					fmt.printf(", ")
				}
			}
			fmt.printf(")\n")
		}
	}
}
