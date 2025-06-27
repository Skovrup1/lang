package hir

import "../lexer"
import "../parser"

import "core:fmt"
import "core:strconv"

InstIndex :: distinct u32
INVALID_INST_INDEX :: max(InstIndex)

InstKind :: enum u8 {
	Return,
	Int,
	Add,
	Mul,
	Label,
}

Inst :: struct {
	kind: InstKind,
	data: struct {
		src1: InstIndex,
		src2: InstIndex,
	},
}

Generator :: struct {
	instructions: [dynamic]Inst,
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

	return Generator{instructions, source, tokens, nodes, extra_data}
}

generate :: proc(g: ^Generator) {
	generate_node(g, g.nodes[len(g.nodes) - 1])
}

generate_node :: proc(g: ^Generator, node: parser.Node) -> InstIndex {
	switch node.kind {
	case .Root:
		lhs_node := g.nodes[node.data.lhs]
		generate_node(g, lhs_node)
	case .FuncDecl:
		label_index := InstIndex(len(g.instructions))
		append(&g.instructions, Inst{.Label, {INVALID_INST_INDEX, INVALID_INST_INDEX}})
		rhs_node := g.nodes[node.data.rhs]
		rhs := generate_node(g, rhs_node)
		return rhs
	case .VarDecl:
	case .BlockStmt:
		first := node.data.lhs
		last := node.data.rhs
		stmts := g.extra_data[first:last]
		for node_i in stmts {
			stmt_node := g.nodes[node_i]
			generate_node(g, stmt_node)
		}
	case .ReturnStmt:
		expr_i := node.data.lhs
		expr := generate_node(g, g.nodes[expr_i])
		append(&g.instructions, Inst{.Return, {expr, INVALID_INST_INDEX}})
	case .IfStmt:
	case .AssignStmt:
	case .MulExpr:
		lhs := generate_node(g, g.nodes[node.data.lhs])
		rhs := generate_node(g, g.nodes[node.data.rhs])
		append(&g.instructions, Inst{.Mul, {lhs, rhs}})
	case .AddExpr:
		lhs := generate_node(g, g.nodes[node.data.lhs])
		rhs := generate_node(g, g.nodes[node.data.rhs])
		append(&g.instructions, Inst{.Add, {lhs, rhs}})
	case .NegateExpr:
	case .IntLit:
		token := g.tokens[node.main_token]
		str := cast(string)g.source[token.start:token.end]
		value := strconv.atoi(str)
		append(&g.instructions, Inst{.Int, {InstIndex(value), INVALID_INST_INDEX}})
	case .IdentLit:
	}

	return InstIndex(len(g.instructions) - 1)
}
