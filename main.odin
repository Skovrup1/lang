package main

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

	source, read_err := os.read_entire_file_from_handle_or_err(handle)
	defer delete(source)

	if read_err != os.ERROR_NONE {
		fmt.eprintf("failed to read file: %v\n", read_err)
		os.exit(1)
	}

	fmt.println(cast(string)source)

	t := lexer.make_tokenizer(source)
	token_list := lexer.tokenize(&t)

	for token in token_list {
		fmt.println(token.kind)
	}
	fmt.println()

	p := parser.make_parser(source, token_list)
	nodes := parser.parse(&p)

	for node in nodes {
		fmt.println(node)
	}

	parser.print_ast(&p)
}
