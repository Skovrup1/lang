package main

import "asmGen"
import "lexer"
import "parser"
import "tacky"

import "core:fmt"
import "core:os"

main :: proc() {
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

	fmt.print(transmute(string)buf)

	t := lexer.make_tokenizer(buf)

	token_list := lexer.tokenize(&t)

	fmt.println("\nTokens")
	for token in token_list {
		fmt.println(token)
	}

	p := parser.make_parser(t, token_list)

	node_list := parser.parse(&p)

	fmt.println("\nAst")
	fmt.println(node_list)

	for node in node_list {
		fmt.println(node)
	}

	g := tacky.make_generator(node_list, token_list, t)
	tacky_list := tacky.generate(&g)

	fmt.println("\nTacky")
	fmt.println(tacky_list)

	for tac in tacky_list {
		#partial switch v in tac {
		case tacky.ProgOp:
		case tacky.FuncOp:
			fmt.printfln("%s:", v.ident)
			for op in v.body {
				fmt.printf("  ")
				#partial switch o in op {
				case tacky.AddOp:
					fmt.printfln("t%d = t%d + t%d", o.result, o.arg1, o.arg2)
				case tacky.SubOp:
					fmt.printfln("t%d = t%d - t%d", o.result, o.arg1, o.arg2)
				case tacky.MulOp:
					fmt.printfln("t%d = t%d * t%d", o.result, o.arg1, o.arg2)
				case tacky.DivOp:
					fmt.printfln("t%d = t%d / t%d", o.result, o.arg1, o.arg2)
				case tacky.BitCompOp:
					fmt.printfln("t%d = ~t%d", o.result, o.arg)
				case tacky.ReturnOp:
					fmt.printfln("return t%d", o.result)
				case tacky.IntOp:
					fmt.printfln("t%d = %d", o.result, o.arg)
				}
			}
		}
	}

	fmt.println("\nasmGen")
	a := asmGen.make_generator(tacky_list)
	asm_list := asmGen.generate(&a)
}
