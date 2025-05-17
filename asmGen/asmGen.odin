package asmGen

import "../tacky"

import "core:fmt"

RegName :: enum {
	R10D,
	EAX,
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

BitComp :: struct {
	arg: Val,
}

Neg :: struct {
	arg: Val,
}

Add :: struct {
	result: Val,
	arg1:   Val,
	arg2:   Val,
}

Sub :: struct {
	result: Val,
	arg1:   Val,
	arg2:   Val,
}

Mul :: struct {
	result: Val,
	arg1:   Val,
	arg2:   Val,
}

Div :: struct {
	result: Val,
	arg1:   Val,
	arg2:   Val,
}

Mov :: struct {
	dst: Val,
	src: Val,
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
	BitComp,
	Neg,
	Mov,
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
		case tacky.BitCompOp:
			arg := convert_val(v.arg)
			result := convert_val(v.result)

			append(&output, Mov{result, arg})
			append(&output, BitComp{result})
		case tacky.AddOp:
			result := convert_val(v.result)
			arg1 := convert_val(v.arg1)
			arg2 := convert_val(v.arg2)

			append(&output, Add{result, arg1, arg2})
		case tacky.SubOp:
			result := convert_val(v.result)
			arg1 := convert_val(v.arg1)
			arg2 := convert_val(v.arg2)

			append(&output, Sub{result, arg1, arg2})
		case tacky.MulOp:
			result := convert_val(v.result)
			arg1 := convert_val(v.arg1)
			arg2 := convert_val(v.arg2)

			append(&output, Mul{result, arg1, arg2})
		case tacky.DivOp:
			result := convert_val(v.result)
			arg1 := convert_val(v.arg1)
			arg2 := convert_val(v.arg2)

			append(&output, Div{result, arg1, arg2})
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
		case BitComp:
			v.arg = replace_if(v.arg)
		case Neg:
			v.arg = replace_if(v.arg)
		case Add:
			v.result = replace_if(v.result)
			v.arg1 = replace_if(v.arg1)
			v.arg2 = replace_if(v.arg2)
		case Sub:
			v.result = replace_if(v.result)
			v.arg1 = replace_if(v.arg1)
			v.arg2 = replace_if(v.arg2)
		case Mul:
			v.result = replace_if(v.result)
			v.arg1 = replace_if(v.arg1)
			v.arg2 = replace_if(v.arg2)
		case Div:
			v.result = replace_if(v.result)
			v.arg1 = replace_if(v.arg1)
			v.arg2 = replace_if(v.arg2)
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
			case BitComp:
				min_offset = foo(min_offset, v.arg)
			case Neg:
				min_offset = foo(min_offset, v.arg)
			case Add:
				min_offset = foo(min_offset, v.result)
				min_offset = foo(min_offset, v.arg1)
				min_offset = foo(min_offset, v.arg2)
			case Sub:
				min_offset = foo(min_offset, v.result)
				min_offset = foo(min_offset, v.arg1)
				min_offset = foo(min_offset, v.arg2)
			case Mul:
				min_offset = foo(min_offset, v.result)
				min_offset = foo(min_offset, v.arg1)
				min_offset = foo(min_offset, v.arg2)
			case Div:
				min_offset = foo(min_offset, v.result)
				min_offset = foo(min_offset, v.arg1)
				min_offset = foo(min_offset, v.arg2)
			case Mov:
				min_offset = foo(min_offset, v.dst)
				min_offset = foo(min_offset, v.src)
			case Prog, Func, Return, AllocateStack:
			}
		}
		return min_offset
	}

	for &node in list {
		switch &v in node {
		case Prog:
			find_min_offset_and_allocate(g, v.func)
		case Func:
			min_offset := find_min_offset(v.body)
			if min_offset < 0 {
				alloc_size := -min_offset

				inject_at(&v.body, 0, AllocateStack{size = alloc_size})
			}
		case BitComp, Neg, Add, Sub, Mul, Div, Return, AllocateStack, Mov:
		// no recursive processing needed
		}
	}
}

replace_dual_stack_mov :: proc(list: ^[dynamic]Asm) {
	for &node, i in list {
		#partial switch &v in node {
		case Prog:
			replace_dual_stack_mov(&v.func)
		case Func:
			replace_dual_stack_mov(&v.body)
		case Mov:
			_, dst_is_stack := v.src.(Stack)
			_, src_is_stack := v.dst.(Stack)

			if src_is_stack && dst_is_stack {
				tmp := v.dst
				v.dst = Reg{RegName.R10D}
				inject_at(list, i + 1, Mov{tmp, v.dst})
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
		case BitComp:
			fmt.printfln("bitComp: %v", v.arg)
		case Neg:
			fmt.printfln("neg: %v", v.arg)
		case Add:
			fmt.printfln("add: %v, %v, %v", v.result, v.arg1, v.arg2)
		case Sub:
			fmt.printfln("sub: %v, %v, %v", v.result, v.arg1, v.arg2)
		case Mul:
			fmt.printfln("mul: %v, %v, %v", v.result, v.arg1, v.arg2)
		case Div:
			fmt.printfln("div: %v, %v, %v", v.result, v.arg1, v.arg2)
		case Mov:
			fmt.printfln("mov: %v, %v", v.dst, v.src)
		case Return:
			fmt.printfln("return:")
		case AllocateStack:
			fmt.printfln("allocateStack: %v", v.size)
		}
	}
}
