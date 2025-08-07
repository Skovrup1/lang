package tir

import "../hir"
import "../lexer"
import "../parser"

import "core:fmt"

InstIndex :: distinct u32
INVALID_INST_INDEX :: max(InstIndex)

ExtraIndex :: distinct u32
INVALID_EXTRA_INDEX :: max(ExtraIndex)

InstKind :: enum u8 {
	Constant,
	Label,
	Jump,
	Branch,
	Return,
	Alloc,
	Load,
	Store,
	Call,
	Arg,
	Equal,
	Add,
	Mul,
}

Inst :: struct {
	kind: InstKind,
	data: u32,
}

ValueKind :: enum {
	I32,
}

Value :: struct {
	kind: ValueKind,
}

TypeKind :: enum {
	None,
	I32,
	Bool,
	F32,
}

Type :: struct {
	kind: TypeKind,
}

TypedValue :: struct {
	ty:  Type,
	val: Value,
}

TIR :: struct {
	instructions: [dynamic]Inst,
	extra:        [dynamic]u32,
	values:       [dynamic]Value,
}

Analyzer :: struct {
	tir: TIR,
	g:   ^hir.Generator,
}

make_analyzer :: proc(g: ^hir.Generator) -> Analyzer {
	instructions := make([dynamic]Inst)
	extra := make([dynamic]u32)
	values := make([dynamic]Value)
	tir := TIR{instructions, extra, values}
	return Analyzer{tir, g}
}

analyze :: proc(g: ^hir.Generator) -> TIR {
	analyzer := make_analyzer(g)

	for inst in g.instructions {
		analyze_inst(&analyzer, inst)
	}

	return analyzer.tir
}

analyze_inst :: proc(a: ^Analyzer, inst: hir.Inst) {

}

get_type_from_node :: proc(g: ^hir.Generator, node_index: parser.NodeIndex) -> TypeKind {
	node := g.nodes[node_index]
	if node.kind == .TypeSpec {
		token_kind := g.tokens[node.main_token].kind
		#partial switch token_kind {
		case .I32:
			return .I32
		case .F32:
			return .F32
		case .Bool:
			return .Bool
		}
	}

	return .None
}
