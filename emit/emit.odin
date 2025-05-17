package emit

import "../asmGen"

import "core:fmt"
import "core:strings"

Emitter :: struct {
}

make_emitter :: proc() -> Emitter {
	return Emitter{}
}

emit :: proc(e: ^Emitter, list: [dynamic]asmGen.Asm, indent := 0) {
	print_spaces :: proc(number: int) {
		for i in 0 ..< number {
			fmt.print(' ')
		}
	}

	for node in list {
		print_spaces(indent)

		switch v in node {
		case asmGen.Prog:
			fmt.printfln(".section .note.GNU-stack,\"\",progbits")
			emit(e, v.func, indent)
		case asmGen.Func:
			fmt.printfln("    .globl %v", v.ident)
			fmt.printfln("%v:", v.ident)

			emit(e, v.body, indent + 4)
		case asmGen.Add:
			panic("todo!")
		case asmGen.Sub:
			panic("todo!")
		case asmGen.Mul:
			panic("todo!")
		case asmGen.Div:
			panic("todo!")
		case asmGen.BitComp:
			arg := convert_to_str(v.arg)

			fmt.printfln("notl %v", arg)
		case asmGen.Neg:
			arg := convert_to_str(v.arg)

			fmt.printfln("negl %v", arg)
		case asmGen.Mov:
			dst := convert_to_str(v.dst)
			src := convert_to_str(v.src)

			fmt.printfln("mov  %v, %v", dst, src)
		case asmGen.Return:
			fmt.println("ret")
		case asmGen.AllocateStack:
			fmt.printfln("subq %v, %%rsp", v.size)
		}
	}
}

convert_to_str :: proc(value: asmGen.Val) -> string {
	switch v in value {
	case asmGen.Reg:
		str := fmt.tprintf("%v", v.name)
		return strings.to_lower(str)
	case asmGen.Stack:
		return fmt.tprintf("[rbp%v]", v.offset)
	case asmGen.Pseudo:
		panic("pseudo not valid")
	case asmGen.Integer:
		return fmt.tprintf("%v", v.value)
	case:
		panic("invalid case")
	}
}
