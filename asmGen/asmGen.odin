package asmGen

import "../tacky"

import "core:fmt"

AsmNode :: struct {
}

Generator :: struct {
	tacky_list: []tacky.Tac,
}

make_generator :: proc(tacky_list: []tacky.Tac) -> Generator {
	return Generator{tacky_list = tacky_list}
}

generate :: proc(g: ^Generator) -> []AsmNode {
	using tacky

	for node in g.tacky_list {
		switch v in node {
		case ProgOp:
		case FuncOp:
		case AddOp:
			fmt.printfln("add r%d, r%d, r%d", v.result, v.arg1, v.arg2)
		case SubOp:
			fmt.printfln("sub r%d, r%d, r%d", v.result, v.arg1, v.arg2)
		case MulOp:
			fmt.printfln("mul r%d, r%d, r%d", v.result, v.arg1, v.arg2)
		case DivOp:
			fmt.printfln("div r%d, r%d, r%d", v.result, v.arg1, v.arg2)
		case BitCompOp:
			fmt.printfln("not r%d, r%d", v.result, v.arg)
		case ReturnOp:
			fmt.printfln("mov rax, r%d\nret", v.result)
		case IntOp:
			fmt.printfln("mov r%d, %d", v.result, v.arg)
		}
	}

	return {}
}
