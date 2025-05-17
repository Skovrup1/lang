package main

import "lexer"
import "parser"
import "tacky"
import "asmGen"
import "emit"

import "core:fmt"
import "core:os"

main :: proc() {
	handle, open_err := os.open("tests/unary_expr.lang")
	defer os.close(handle)

	if open_err != os.ERROR_NONE {
		panic("failed to open file")
	}

	buf, read_err := os.read_entire_file_from_handle_or_err(handle)
	if read_err != os.ERROR_NONE {
		panic("failed to read file")
	}
	defer delete(buf)

	fmt.println(cast(string)buf)

	t := lexer.make_tokenizer(buf)

	token_list := lexer.tokenize(&t)

	for token in token_list {
		fmt.println(token)
	}
	fmt.println()

	p := parser.make_parser(t, token_list)

	ast_list := parser.parse(&p)

	parser.print_ast(ast_list[:])
	fmt.println()

	g := tacky.make_generator(ast_list, token_list, t)
	tacky_list := tacky.generate(&g)

	tacky.print_tacky_list(tacky_list)
	fmt.println()

	a := asmGen.make_generator(&g)
	asm_list := asmGen.generate(&a, tacky_list)

	asmGen.print_asm_list(asm_list)
	fmt.println()

	asmGen.replace_pseudos(&a, asm_list)

	asmGen.print_asm_list(asm_list)
	fmt.println()

	asmGen.find_min_offset_and_allocate(&a, asm_list)

	asmGen.print_asm_list(asm_list)
	fmt.println()

    asmGen.replace_dual_stack_mov(&asm_list)

	asmGen.print_asm_list(asm_list)
	fmt.println()

    e := emit.make_emitter()
    emit.emit(&e, asm_list)
}
