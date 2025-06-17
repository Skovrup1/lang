package hir

import "../lexer"
import "../parser"

import "core:fmt"
import "core:strconv"
import "core:strings"

Value :: int

BlockLabel :: int

Constant :: struct {
	dst:   Value,
	value: int,
}

Unary :: struct {
	dst: Value,
	src: Value,
}

Binary :: struct {
	dst: Value,
	lhs: Value,
	rhs: Value,
}

Instruction :: struct {
	tag:  enum {
		Neg,
		Add,
		Equal,
		Constant,
	},
	data: union #no_nil {
		Constant,
		Unary,
		Binary,
	},
}

Return :: struct {
	val: Value,
}

BranchCond :: struct {
	cond:       Value,
	true_dst:   BlockLabel,
	true_args:  [dynamic]Value,
	false_dst:  BlockLabel,
	false_args: [dynamic]Value,
}

BranchUncond :: struct {
	dst:  BlockLabel,
	args: [dynamic]Value,
}

Terminator :: union {
	Return,
	BranchCond,
	BranchUncond,
}

BasicBlock :: struct {
	label:        BlockLabel,
	args:         [dynamic]Value,
	instructions: [dynamic]Instruction,
	terminator:   Terminator,
}

Function :: struct {
	name:   string,
	blocks: [dynamic]BasicBlock,
}

Converter :: struct {
	// input
	source:              []u8,
	tokens:              []lexer.Token,
	ast:                 []parser.Ast,

	// output ir
	function:            ^Function,
	current_block:       ^BasicBlock,

	// state
	value_counter:       int,
	block_label_counter: int,

	// maps an ast node to the ssa value it produced.
	ast_to_value:        map[parser.AstIndex]Value,
}

lookup :: proc(c: ^Converter, value: lexer.TokenIndex) -> int {
	token := c.tokens[value]
	str := c.source[token.start:token.end]
	value, ok := strconv.parse_int(cast(string)str)
	assert(ok, "failed to parse int")

	return value
}

new_value :: proc(c: ^Converter) -> Value {
	val := Value(c.value_counter)
	c.value_counter += 1
	return val
}

new_basic_block :: proc(c: ^Converter) -> ^BasicBlock {
	label := BlockLabel(c.block_label_counter)
	c.block_label_counter += 1

	block := new(BasicBlock)
	block.label = label
	append(&c.function.blocks, block^)

	return &c.function.blocks[len(c.function.blocks) - 1]
}

convert_node :: proc(c: ^Converter, node_index: parser.AstIndex) -> (val: Value, ok: bool) {
	// check memoization table first
	if v, v_ok := c.ast_to_value[node_index]; v_ok {
		return v, true
	}

	node := c.ast[node_index]
	#partial switch n in node {
	case parser.FuncDef:
		c.function.name = "main"
		entry_block := new_basic_block(c)
		c.current_block = entry_block
		return convert_node(c, n.node)

	case parser.ProgDef:
		return convert_node(c, n.node)

	case parser.IntLiteral:
		dst := new_value(c)
		value := lookup(c, n.value)
		const_inst := Instruction{.Constant, Constant{dst, value}}
		append(&c.current_block.instructions, const_inst)
		c.ast_to_value[node_index] = dst
		return dst, true

	case parser.ReturnStmt:
		val, ok := convert_node(c, n.node)
		if !ok {return {}, false}
		c.current_block.terminator = Return{val}

		c.ast_to_value[node_index] = val
		return val, true

	case parser.BlockStmt:
		last_val: Value
		has_value := false
		for stmt in n.stmts {
			v, ok := convert_node(c, stmt)
			if ok {
				last_val = v
				has_value = true
			}
		}
		if has_value {
			c.ast_to_value[node_index] = last_val
			return last_val, true
		}
		return {}, false

	case parser.IfExpr:
		entry_block := c.current_block

		cond_val, cond_ok := convert_node(c, n.cond)
		if !cond_ok {return {}, false}

		then_block := new_basic_block(c)
		else_block: ^BasicBlock = new_basic_block(c)
		merge_block: ^BasicBlock = new_basic_block(c)

		// set up entry to condition block
		entry_block.terminator = BranchCond {
			cond       = cond_val,
			true_dst   = then_block.label,
			true_args  = make([dynamic]Value, 0, 0),
			false_dst  = else_block.label,
			false_args = make([dynamic]Value, 0, 0),
		}

		// then block
		c.current_block = then_block
		then_val, then_ok := convert_node(c, n.then_block)
		if !then_ok {return {}, false}
		then_block.terminator = BranchUncond {
			dst  = merge_block.label,
			args = make([dynamic]Value, 0, 1),
		}
		then_branch := then_block.terminator.(BranchUncond)
		append(&then_branch.args, then_val)
		then_block.terminator = then_branch

		// else block
		c.current_block = else_block
		else_val, else_ok := convert_node(c, n.else_block)
		if !else_ok {return {}, false}
		else_block.terminator = BranchUncond {
			dst  = merge_block.label,
			args = make([dynamic]Value, 0, 1),
		}
		else_branch := else_block.terminator.(BranchUncond)
		append(&else_branch.args, else_val)
		else_block.terminator = else_branch

		// merge block
		c.current_block = merge_block
		merge_val := new_value(c)
		append(&merge_block.args, merge_val)

		// note: temporary hack
		merge_block.terminator = Return{merge_val}

		c.ast_to_value[node_index] = merge_val
		return merge_val, true

	case parser.NegExpr:
		arg_val, arg_ok := convert_node(c, n.node)
		if !arg_ok {return {}, false}

		dst_val := new_value(c)

		neg_inst := Instruction{.Neg, Unary{dst_val, arg_val}}
		append(&c.current_block.instructions, neg_inst)

		return dst_val, true

	case parser.EqualExpr:
		lhs_val, l_ok := convert_node(c, n.left)
		if !l_ok {return {}, false}

		rhs_val, r_ok := convert_node(c, n.right)
		if !r_ok {return {}, false}

		dst_val := new_value(c)

		equal_inst := Instruction{.Equal, Binary{dst_val, lhs_val, rhs_val}}
		append(&c.current_block.instructions, equal_inst)
		return dst_val, true

	case parser.AddExpr:
		lhs_val, l_ok := convert_node(c, n.left)
		if !l_ok {return {}, false}

		rhs_val, r_ok := convert_node(c, n.right)
		if !r_ok {return {}, false}

		dst_val := new_value(c)

		add_inst := Instruction{.Add, Binary{dst_val, lhs_val, rhs_val}}

		append(&c.current_block.instructions, add_inst)
		c.ast_to_value[node_index] = dst_val
		return dst_val, true

	case parser.AndExpr:
		panic("todo!")
	}

	return {}, false
}

print_function :: proc(f: ^Function) {
	fmt.printf("%s:\n", f.name)
	for block in f.blocks {
		fmt.printf("L%v", block.label)
		if len(block.args) > 0 {
			fmt.printf("(")
			for param, i in block.args {
				fmt.printf("%%%v", param)
				if i < len(block.args) - 1 {
					fmt.printf(", ")
				}
			}
			fmt.printf(")")
		}

		fmt.printf(":\n")
		for inst in block.instructions {
			switch inst.tag {
			case .Constant:
				const_inst := inst.data.(Constant)
				fmt.printf("  %%%v = const %v\n", const_inst.dst, const_inst.value)

			case .Neg:
				unary_inst := inst.data.(Unary)
				tag_name, _ := fmt.enum_value_to_string(inst.tag)
				tag_name = strings.to_lower(tag_name)
				fmt.printf("  %%%v = %v %%%v\n", unary_inst.dst, tag_name, unary_inst.src)

			case .Equal, .Add:
				binary_inst := inst.data.(Binary)
				tag_name, _ := fmt.enum_value_to_string(inst.tag)
				tag_name = strings.to_lower(tag_name)
				fmt.printf(
					"  %%%v = %%%v %v %%%v\n",
					binary_inst.dst,
					binary_inst.lhs,
					tag_name,
					binary_inst.rhs,
				)
			}
		}

		switch t in block.terminator {
		case Return:
			fmt.printf("  return %%%v\n", t.val)

		case BranchUncond:
			fmt.printf("  jmp L%v", t.dst)
			if len(t.args) > 0 {
				fmt.printf("(")
				for arg, i in t.args {
					fmt.printf("%%%v", arg)
					if i < len(t.args) - 1 {
						fmt.printf(", ")
					}
				}
				fmt.printf(")")
			}
			fmt.println()

		case BranchCond:
			fmt.printf("  branch %%%v, L%v, L%v", t.cond, t.true_dst, t.false_dst)
			if len(t.false_args) > 0 {
				fmt.printf("(")
				for arg, i in t.false_args {
					fmt.printf("%%%v", arg)
					if i < len(t.false_args) - 1 {fmt.printf(", ")}
				}
				fmt.printf(")")
			}
			fmt.println()
		}
	}
}
