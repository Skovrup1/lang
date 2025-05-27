package asmGen

import "../tacky"

import "core:fmt"

RegName :: enum {
	R10D,
	R11D,
	EAX,
	EDX,
	CL,
}

Reg :: struct {
	name: RegName,
}

Stack :: struct {
	offset: int,
}

Pseudo :: struct {
	id: int,
}

Integer :: struct {
	value: int,
}

Val :: union {
	Reg,
	Stack,
	Pseudo,
	Integer,
}

Prog :: struct {
	func: [dynamic]Asm,
}

Func :: struct {
	ident: string,
	body:  [dynamic]Asm,
}

Not :: struct {
	arg: Val,
}

Neg :: struct {
	arg: Val,
}

Add :: struct {
	result: Val,
	arg:    Val,
}

Sub :: struct {
	result: Val,
	arg:    Val,
}

Mul :: struct {
	result: Val,
	arg:    Val,
}

Div :: struct {
	arg: Val,
}

Mov :: struct {
	dst: Val,
	src: Val,
}

BitOr :: struct {
	result: Val,
	arg:    Val,
}

BitAnd :: struct {
	result: Val,
	arg:    Val,
}

BitXor :: struct {
	result: Val,
	arg:    Val,
}

LShift :: struct {
	result: Val,
	arg:    Val,
}

RShift :: struct {
	result: Val,
	arg:    Val,
}

Return :: struct {
}

AllocateStack :: struct {
	size: int,
}

Asm :: union {
	Prog,
	Func,
	Add,
	Sub,
	Mul,
	Div,
	Not,
	Neg,
	Mov,
	BitOr,
	BitAnd,
    BitXor,
	LShift,
	RShift,
	Return,
	AllocateStack,
}

Generator :: struct {
	tmp_count: int,
}

make_generator :: proc(g: ^tacky.Generator) -> Generator {
	return Generator{g.tmp_count}
}

make_tmp :: proc(g: ^Generator) -> int {
	tmp := g.tmp_count
	g.tmp_count += 1
	return tmp
}

generate :: proc(g: ^Generator, tacky_list: [dynamic]tacky.Tac) -> [dynamic]Asm {
	output := make([dynamic]Asm)

	for node in tacky_list {
		switch v in node {
		case tacky.ProgOp:
			append(&output, Prog{generate(g, v.func)})
		case tacky.FuncOp:
			append(&output, Func{v.ident, generate(g, v.body)})
		case tacky.NegOp:
			arg := convert_val(v.arg)
			result := convert_val(v.result)

			append(&output, Mov{result, arg})
			append(&output, Neg{result})
		case tacky.NotOp:
			arg := convert_val(v.arg)
			result := convert_val(v.result)

			append(&output, Mov{result, arg})
			append(&output, Not{result})
		case tacky.AddOp:
			result := convert_val(v.result)
			arg1 := convert_val(v.arg1)
			arg2 := convert_val(v.arg2)

			append(&output, Mov{result, arg1})
			append(&output, Add{result, arg2})
		case tacky.SubOp:
			result := convert_val(v.result)
			arg1 := convert_val(v.arg1)
			arg2 := convert_val(v.arg2)

			append(&output, Mov{result, arg1})
			append(&output, Sub{result, arg2})
		case tacky.MulOp:
			result := convert_val(v.result)
			arg1 := convert_val(v.arg1)
			arg2 := convert_val(v.arg2)

			append(&output, Mov{Reg{RegName.EAX}, arg1})
			append(&output, Mul{Reg{RegName.EAX}, arg2})
			append(&output, Mov{result, Reg{RegName.EAX}})
		case tacky.DivOp:
			result := convert_val(v.result)
			arg1 := convert_val(v.arg1)
			arg2 := convert_val(v.arg2)

			append(&output, Mov{Reg{RegName.EAX}, arg1})
			append(&output, Div{arg2})
			append(&output, Mov{result, Reg{RegName.EAX}})
		case tacky.ModOp:
			result := convert_val(v.result)
			arg1 := convert_val(v.arg1)
			arg2 := convert_val(v.arg2)

			append(&output, Mov{Reg{RegName.EAX}, arg1})
			append(&output, Div{arg2})
			append(&output, Mov{result, Reg{RegName.EDX}})
		case tacky.BitAndOp:
			result := convert_val(v.result)
			arg1 := convert_val(v.arg1)
			arg2 := convert_val(v.arg2)

			append(&output, Mov{Reg{RegName.EAX}, arg1})
			append(&output, BitAnd{Reg{RegName.EAX}, arg2})
			append(&output, Mov{result, Reg{RegName.EAX}})
		case tacky.BitOrOp:
			result := convert_val(v.result)
			arg1 := convert_val(v.arg1)
			arg2 := convert_val(v.arg2)

			append(&output, Mov{Reg{RegName.EAX}, arg1})
			append(&output, BitOr{Reg{RegName.EAX}, arg2})
			append(&output, Mov{result, Reg{RegName.EAX}})
		case tacky.BitXorOp:
			result := convert_val(v.result)
			arg1 := convert_val(v.arg1)
			arg2 := convert_val(v.arg2)

			append(&output, Mov{Reg{RegName.EAX}, arg1})
			append(&output, BitXor{Reg{RegName.EAX}, arg2})
			append(&output, Mov{result, Reg{RegName.EAX}})
		case tacky.LShiftOp:
			result := convert_val(v.result)
			arg1 := convert_val(v.arg1)
			arg2 := convert_val(v.arg2)

			append(&output, Mov{Reg{RegName.EAX}, arg1})
			append(&output, LShift{Reg{RegName.EAX}, arg2})
			append(&output, Mov{result, Reg{RegName.EAX}})
		case tacky.RShiftOp:
			result := convert_val(v.result)
			arg1 := convert_val(v.arg1)
			arg2 := convert_val(v.arg2)

			append(&output, Mov{Reg{RegName.EAX}, arg1})
			append(&output, RShift{Reg{RegName.EAX}, arg2})
			append(&output, Mov{result, Reg{RegName.EAX}})
		case tacky.ReturnOp:
			arg := convert_val(v.arg)

			append(&output, Mov{Reg{RegName.EAX}, arg})
			append(&output, Return{})
		}
	}

	return output
}

convert_val :: proc(node: tacky.Val) -> Val {
	switch v in node {
	case tacky.Var:
		return Pseudo{v.id}
	case tacky.Integer:
		return Integer{v.value}
	case:
		panic("failed to convert")
	}
}

replace_pseudos :: proc(g: ^Generator, asm_list: [dynamic]Asm) {
	replace_if :: proc(value: Val) -> Val {
		if p, ok := value.(Pseudo); ok {
			return Stack{-4 * p.id - 4}
		}
		return value
	}

	for &node in asm_list {
		switch &v in node {
		case Prog:
			replace_pseudos(g, v.func)
		case Func:
			replace_pseudos(g, v.body)
		case Not:
			v.arg = replace_if(v.arg)
		case Neg:
			v.arg = replace_if(v.arg)
		case Add:
			v.result = replace_if(v.result)
			v.arg = replace_if(v.arg)
		case Sub:
			v.result = replace_if(v.result)
			v.arg = replace_if(v.arg)
		case Mul:
			v.result = replace_if(v.result)
			v.arg = replace_if(v.arg)
		case Div:
			v.arg = replace_if(v.arg)
		case BitAnd:
			v.result = replace_if(v.result)
			v.arg = replace_if(v.arg)
		case BitOr:
			v.result = replace_if(v.result)
			v.arg = replace_if(v.arg)
		case BitXor:
			v.result = replace_if(v.result)
			v.arg = replace_if(v.arg)
		case LShift:
			v.result = replace_if(v.result)
			v.arg = replace_if(v.arg)
		case RShift:
			v.result = replace_if(v.result)
			v.arg = replace_if(v.arg)
		case Mov:
			v.dst = replace_if(v.dst)
			v.src = replace_if(v.src)
		case Return, AllocateStack:
		}
	}
}

find_min_offset_and_allocate :: proc(g: ^Generator, list: [dynamic]Asm) {
	// todo: naming :D
	foo :: proc(a: int, b: Val) -> int {
		if s, ok := b.(Stack); ok {
			return min(a, s.offset)
		}
		return a
	}

	find_min_offset :: proc(nodes: [dynamic]Asm) -> int {
		min_offset := 0
		for node in nodes {
			switch v in node {
			case Not:
				min_offset = foo(min_offset, v.arg)
			case Neg:
				min_offset = foo(min_offset, v.arg)
			case Add:
				min_offset = foo(min_offset, v.result)
				min_offset = foo(min_offset, v.arg)
			case Sub:
				min_offset = foo(min_offset, v.result)
				min_offset = foo(min_offset, v.arg)
			case Mul:
				min_offset = foo(min_offset, v.result)
				min_offset = foo(min_offset, v.arg)
			case Div:
				min_offset = foo(min_offset, v.arg)
			case BitAnd:
				min_offset = foo(min_offset, v.result)
				min_offset = foo(min_offset, v.arg)
			case BitOr:
				min_offset = foo(min_offset, v.result)
				min_offset = foo(min_offset, v.arg)
			case BitXor:
				min_offset = foo(min_offset, v.result)
				min_offset = foo(min_offset, v.arg)
			case LShift:
				min_offset = foo(min_offset, v.result)
				min_offset = foo(min_offset, v.arg)
			case RShift:
				min_offset = foo(min_offset, v.result)
				min_offset = foo(min_offset, v.arg)
			case Mov:
				min_offset = foo(min_offset, v.dst)
				min_offset = foo(min_offset, v.src)
			case Prog, Func, Return, AllocateStack:
			}
		}
		return min_offset
	}

	for &node in list {
		#partial switch &v in node {
		case Prog:
			find_min_offset_and_allocate(g, v.func)
		case Func:
			min_offset := find_min_offset(v.body)
			if min_offset < 0 {
				size := -min_offset
				align := 16
				aligned_size := (size + (align - 1)) & ~(align - 1)

				inject_at(&v.body, 0, AllocateStack{aligned_size})
			}
		}
	}
}

replace_memory_op :: proc(list: ^[dynamic]Asm) {
	for &node, i in list {
		#partial switch &v in node {
		case Prog:
			replace_memory_op(&v.func)
		case Func:
			replace_memory_op(&v.body)
		case Mov:
			_, dst_is_stack := v.src.(Stack)
			_, src_is_stack := v.dst.(Stack)

			if src_is_stack && dst_is_stack {
				tmp := v.dst
				v.dst = Reg{RegName.R10D}
				inject_at(list, i + 1, Mov{tmp, v.dst})
			}
		case Add:
			_, result_is_stack := v.result.(Stack)
			_, arg_is_stack := v.arg.(Stack)

			if arg_is_stack && result_is_stack {
				tmp := v.result
				v.result = Reg{RegName.R10D}
				inject_at(list, i + 1, Mov{tmp, v.result})
			}
		case Div:
			_, arg_is_integer := v.arg.(Integer)

			if arg_is_integer {
				tmp := v.arg
				v.arg = Reg{RegName.R11D}
				inject_at(list, i, Mov{v.arg, tmp})
			}
		case LShift:
			_, arg_is_Stack := v.arg.(Stack)

			if arg_is_Stack {
				tmp := v.arg
				v.arg = Reg{RegName.CL}
				inject_at(list, i, Mov{v.arg, tmp})
			}
		case RShift:
			_, arg_is_Stack := v.arg.(Stack)

			if arg_is_Stack {
				tmp := v.arg
				v.arg = Reg{RegName.CL}
				inject_at(list, i, Mov{v.arg, tmp})
			}
		}
	}
}

print_asm_list :: proc(list: [dynamic]Asm, indent := 0) {
	for node, i in list {
		for i in 0 ..< indent {
			fmt.print(' ')
		}

		switch v in node {
		case Prog:
			print_asm_list(v.func, indent)
		case Func:
			fmt.printfln("%s:", v.ident)
			print_asm_list(v.body, indent + 4)
		case Not:
			fmt.printfln("not: %v", v.arg)
		case Neg:
			fmt.printfln("neg: %v", v.arg)
		case Add:
			fmt.printfln("add: %v, %v", v.result, v.arg)
		case Sub:
			fmt.printfln("sub: %v, %v", v.result, v.arg)
		case Mul:
			fmt.printfln("mul: %v, %v", v.result, v.arg)
		case Div:
			fmt.printfln("div: %v", v.arg)
		case BitOr:
			fmt.printfln("bitor: %v, %v", v.result, v.arg)
		case BitAnd:
			fmt.printfln("bitand: %v, %v", v.result, v.arg)
		case BitXor:
			fmt.printfln("bitxor: %v, %v", v.result, v.arg)
		case LShift:
			fmt.printfln("lshift: %v, %v", v.result, v.arg)
		case RShift:
			fmt.printfln("rshift: %v, %v", v.result, v.arg)
		case Mov:
			fmt.printfln("mov: %v, %v", v.dst, v.src)
		case Return:
			fmt.printfln("return:")
		case AllocateStack:
			fmt.printfln("allocateStack: %v", v.size)
		}
	}
}
