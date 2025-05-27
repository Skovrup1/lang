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
			fmt.println("section .note.GNU-stack,\"\",@progbits")
			fmt.println("    global _start\n")
			fmt.println("section .text\n")
			fmt.println("_start:")
			fmt.println("    call main")
			fmt.println("    mov  edi, eax")
			fmt.println("    mov  eax, 60")
			fmt.println("    syscall\n")
			emit(e, v.func, indent)
		case asmGen.Func:
			fmt.printfln("    global %v", v.ident)
			fmt.printfln("%v:", v.ident)
			fmt.println("    push rbp")
			fmt.println("    mov  rbp, rsp")

			emit(e, v.body, indent + 4)
		case asmGen.Add:
			result := convert_to_str(v.result)
			arg := convert_to_str(v.arg)

			_, result_is_stack := v.result.(asmGen.Stack)
			_, arg_is_integer := v.arg.(asmGen.Integer)
			if result_is_stack && arg_is_integer {
				fmt.printfln("add  DWORD %v, %v", result, arg)
			} else {
				fmt.printfln("add  %v, %v", result, arg)
			}
		case asmGen.Sub:
			result := convert_to_str(v.result)
			arg := convert_to_str(v.arg)

			_, result_is_stack := v.result.(asmGen.Stack)
			_, arg_is_integer := v.arg.(asmGen.Integer)
			if result_is_stack && arg_is_integer {
				fmt.printfln("sub  DWORD %v, %v", result, arg)
			} else {
				fmt.printfln("sub  %v, %v", result, arg)
			}
		case asmGen.Mul:
			result := convert_to_str(v.result)
			arg := convert_to_str(v.arg)

			fmt.printfln("imul %v, %v", result, arg)
		case asmGen.Div:
			arg := convert_to_str(v.arg)

			fmt.println("cdq")
			print_spaces(indent)
			_, arg_is_stack := v.arg.(asmGen.Stack)
			if arg_is_stack {
				fmt.printfln("idiv DWORD %v", arg)
			} else {
				fmt.printfln("idiv %v", arg)
			}
		case asmGen.BitAnd:
			result := convert_to_str(v.result)
			arg := convert_to_str(v.arg)

			fmt.printfln("and  %v, %v", result, arg)
		case asmGen.BitOr:
			result := convert_to_str(v.result)
			arg := convert_to_str(v.arg)

			fmt.printfln("or   %v, %v", result, arg)
		case asmGen.BitXor:
			result := convert_to_str(v.result)
			arg := convert_to_str(v.arg)

			fmt.printfln("xor  %v, %v", result, arg)
		case asmGen.LShift:
			result := convert_to_str(v.result)
			arg := convert_to_str(v.arg)

			fmt.printfln("sal  %v, %v", result, arg)
		case asmGen.RShift:
			result := convert_to_str(v.result)
			arg := convert_to_str(v.arg)

			fmt.printfln("sar  %v, %v", result, arg)
		case asmGen.Not:
			arg := convert_to_str(v.arg)

			fmt.printfln("not %v", arg)
		case asmGen.Neg:
			arg := convert_to_str(v.arg)

			fmt.printfln("neg %v", arg)
		case asmGen.Mov:
			dst := convert_to_str(v.dst)
			src := convert_to_str(v.src)

			_, src_is_integer := v.src.(asmGen.Integer)
			_, dst_is_stack := v.dst.(asmGen.Stack)

			if src_is_integer && dst_is_stack {
				fmt.printfln("mov  DWORD %v, %v", dst, src)
			} else {
				fmt.printfln("mov  %v, %v", dst, src)
			}
		case asmGen.Return:
			fmt.println("mov  rsp, rbp")
			print_spaces(indent)
			fmt.println("pop  rbp")
			print_spaces(indent)
			fmt.println("ret")
		case asmGen.AllocateStack:
			fmt.printfln("sub  rsp, %v", v.size)
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
