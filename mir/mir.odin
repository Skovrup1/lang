package tacky

import "../lexer"
import "../parser"

import "core:fmt"
import "core:strconv"

MirTag :: enum {
	File,
	Func,
}

MirNode :: struct {
	tag:  MirTag,
	data: union {
	},
}

Generator :: struct {
	source:    []u8,
	tokens:    [dynamic]lexer.Token,
	ast:       [dynamic]parser.Ast,
	tmp_count: int,
}

make_generator :: proc(
	source: []u8,
	tokens: [dynamic]lexer.Token,
	ast: [dynamic]parser.Ast,
) -> Generator {
	return Generator{source, tokens, ast, 0}
}

make_tmp :: proc(g: ^Generator) -> int {
	tmp := g.tmp_count
	g.tmp_count += 1
	return tmp
}

generate :: proc(g: ^Generator) -> [dynamic]MirNode {
	using parser

	output := make([dynamic]MirNode)


	return output
}
