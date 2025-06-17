package main

import "hir"
import "lexer"
import "parser"

import "core:flags"
import "core:fmt"
import "core:os"

main :: proc() {
	Options :: struct {
		E: bool,
	}

	opts: Options
	err := flags.parse(&opts, os.args[1:], .Unix)
	if err != nil {
		fmt.eprintf("failed to parse arguments: %v\n", err)
		os.exit(1)
	}

	handle, open_err := os.open("tests/binary_expr.lang")
	defer os.close(handle)

	if open_err != os.ERROR_NONE {
		fmt.eprintf("failed to open file: %v\n", open_err)
		os.exit(1)
	}

	buf, read_err := os.read_entire_file_from_handle_or_err(handle)
	defer delete(buf)

	if read_err != os.ERROR_NONE {
		fmt.eprintf("failed to read file: %v\n", read_err)
		os.exit(1)
	}

	fmt.println(cast(string)buf)

	t := lexer.make_tokenizer(buf)
	token_list := lexer.tokenize(&t)

	for token in token_list {
		fmt.println(token.kind)
	}
	fmt.println()

	p := parser.make_parser(buf, token_list)
	ast_list := parser.parse(&p)

	parser.print_ast(&p, ast_list)

	c := hir.Converter {
		source       = buf,
		tokens       = token_list[:],
		ast          = ast_list[:],
		ast_to_value = make(map[parser.AstIndex]hir.Value),
		function     = new(hir.Function),
	}

	hir.convert_node(&c, parser.AstIndex(len(ast_list) - 1))

	hir.print_function(c.function)
}
