package main

import "asmGen"
import "emit"
import "lexer"
import "parser"
import "tacky"

import "core:flags"
import "core:fmt"
import "core:os"

main :: proc() {
	Options :: struct {
		emit_only: bool,
	}

	opts: Options
	err := flags.parse(&opts, os.args[1:])
	if err != nil {
		fmt.eprintf("failed to parse arguments: %v\n", err)
		os.exit(1)
	}

	handle, open_err := os.open("tests/binary_expr.lang")
	defer os.close(handle)

	if open_err != os.ERROR_NONE {
		panic("failed to open file")
	}

	buf, read_err := os.read_entire_file_from_handle_or_err(handle)
	if read_err != os.ERROR_NONE {
		panic("failed to read file")
	}
	defer delete(buf)

	if !opts.emit_only {
		fmt.println(cast(string)buf)
	}

	t := lexer.make_tokenizer(buf)
	token_list := lexer.tokenize(&t)

	if !opts.emit_only {
		for token in token_list {
			fmt.println(token)
		}
		fmt.println()
	}

	p := parser.make_parser(t, token_list)
	ast_list := parser.parse(&p)
    fmt.println(ast_list)

	if !opts.emit_only {
		parser.print_ast(ast_list)
		fmt.println()
	}

	g := tacky.make_generator(ast_list, token_list, t)
	tacky_list := tacky.generate(&g)

	if !opts.emit_only {
		tacky.print_tacky_list(tacky_list)
		fmt.println()
	}

	a := asmGen.make_generator(&g)
	asm_list := asmGen.generate(&a, tacky_list)

	if !opts.emit_only {
		asmGen.print_asm_list(asm_list)
		fmt.println()
	}

	asmGen.replace_pseudos(&a, asm_list)

	if !opts.emit_only {
		asmGen.print_asm_list(asm_list)
		fmt.println()
	}

	asmGen.find_min_offset_and_allocate(&a, asm_list)

	if !opts.emit_only {
		asmGen.print_asm_list(asm_list)
		fmt.println()
	}

	asmGen.replace_memory_op(&asm_list)

	if !opts.emit_only {
		asmGen.print_asm_list(asm_list)
		fmt.println()
	}

	e := emit.make_emitter()
	emit.emit(&e, asm_list)
}
