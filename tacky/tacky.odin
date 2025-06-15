package tacky

import "../lexer"
import "../parser"

import "core:fmt"
import "core:strconv"

Var :: struct {
	id: int,
}

Integer :: struct {
	value: int,
}

Val :: union {
	Var,
	Integer,
}

ProgOp :: struct {
	func: [dynamic]Tac,
}

FuncOp :: struct {
	ident: string,
	body:  [dynamic]Tac,
}

BitAndOp :: struct {
	result: Val,
	arg1:   Val,
	arg2:   Val,
}

BitOrOp :: struct {
	result: Val,
	arg1:   Val,
	arg2:   Val,
}

BitXorOp :: struct {
	result: Val,
	arg1:   Val,
	arg2:   Val,
}

BitNotOp :: struct {
	result: Val,
	arg:    Val,
}

NegOp :: struct {
	result: Val,
	arg:    Val,
}

AddOp :: struct {
	result: Val,
	arg1:   Val,
	arg2:   Val,
}

SubOp :: struct {
	result: Val,
	arg1:   Val,
	arg2:   Val,
}

MulOp :: struct {
	result: Val,
	arg1:   Val,
	arg2:   Val,
}

DivOp :: struct {
	result: Val,
	arg1:   Val,
	arg2:   Val,
}

ModOp :: struct {
	result: Val,
	arg1:   Val,
	arg2:   Val,
}

LShiftOp :: struct {
	result: Val,
	arg1:   Val,
	arg2:   Val,
}

RShiftOp :: struct {
	result: Val,
	arg1:   Val,
	arg2:   Val,
}

ReturnOp :: struct {
	arg: Val,
}

NotOp :: struct {
	result: Val,
	arg:    Val,
}

AndOp :: struct {
	result: Val,
	arg1:   Val,
	arg2:   Val,
}

AndAlsoOp :: struct {
	result: Val,
	arg1:   Val,
	arg2:   Val,
}

OrOp :: struct {
	result: Val,
	arg1:   Val,
	arg2:   Val,
}

OrElseOp :: struct {
	result: Val,
	arg1:   Val,
	arg2:   Val,
}

EqualOp :: struct {
	result: Val,
	arg1:   Val,
	arg2:   Val,
}

NotEqualOp :: struct {
	result: Val,
	arg1:   Val,
	arg2:   Val,
}

LessOp :: struct {
	result: Val,
	arg1:   Val,
	arg2:   Val,
}

LessEqualOp :: struct {
	result: Val,
	arg1:   Val,
	arg2:   Val,
}

GreaterOp :: struct {
	result: Val,
	arg1:   Val,
	arg2:   Val,
}

GreaterEqualOp :: struct {
	result: Val,
	arg1:   Val,
	arg2:   Val,
}

LabelOp :: struct {
}

JmpIfNotZero :: struct {
}

JmpIfZeroOP :: struct {
}

JmpOP :: struct {
}


Tac :: union {
	ProgOp,
	FuncOp,
	ReturnOp,
	AddOp,
	SubOp,
	MulOp,
	DivOp,
	ModOp,
	BitAndOp,
	BitOrOp,
	BitXorOp,
	NegOp,
	LShiftOp,
	RShiftOp,
	BitNotOp,
	NotOp,
	AndOp,
	OrOp,
	EqualOp,
	LabelOp,
	JmpIfNotZero,
	JmpOP,
	JmpIfZeroOP,
	NotEqualOp,
	LessOp,
	LessEqualOp,
	GreaterOp,
	GreaterEqualOp,
}

Generator :: struct {
	ast_list:   [dynamic]parser.Ast,
	token_list: [dynamic]lexer.Token,
	tokenizer:  lexer.Tokenizer,
	tmp_count:  int,
	val_list:   [dynamic]Val,
}

make_generator :: proc(
	ast_list: [dynamic]parser.Ast,
	token_list: [dynamic]lexer.Token,
	tokenizer: lexer.Tokenizer,
) -> Generator {
	val_list := make([dynamic]Val, 8)
	return Generator{ast_list, token_list, tokenizer, 0, val_list}
}

generate :: proc(g: ^Generator) -> [dynamic]Tac {
	using parser

	output := make([dynamic]Tac)

	for node in g.ast_list {
		switch v in node {
		case AstProgDef:
			func := output
			output = make([dynamic]Tac)

			append(&output, ProgOp{func})
		case AstFuncDef:
			token := g.token_list[v.ident]
			str := cast(string)g.tokenizer.buf[token.start:token.end]
			body := output
			output = make([dynamic]Tac)

			append(&output, FuncOp{ident = str, body = body})
		case AstReturnStmt:
			arg := pop(&g.val_list)

			append(&output, ReturnOp{arg})
		case AstParenExpr:
		case AstBitNotExpr:
			result := Var{make_tmp(g)}
			arg := pop(&g.val_list)

			append(&output, BitNotOp{result, arg})
			append(&g.val_list, result)
		case AstNegExpr:
			result := Var{make_tmp(g)}
			arg := pop(&g.val_list)

			append(&output, NegOp{result, arg})
			append(&g.val_list, result)
		case AstNotExpr:
			result := Var{make_tmp(g)}
			arg := pop(&g.val_list)

			append(&output, NotOp{result, arg})
			append(&g.val_list, result)
		case AstBitAndExpr:
			result := Var{make_tmp(g)}
			arg2 := pop(&g.val_list)
			arg1 := pop(&g.val_list)

			append(&output, BitAndOp{result, arg1, arg2})
			append(&g.val_list, result)
		case AstBitOrExpr:
			result := Var{make_tmp(g)}
			arg2 := pop(&g.val_list)
			arg1 := pop(&g.val_list)

			append(&output, BitOrOp{result, arg1, arg2})
			append(&g.val_list, result)
		case AstBitXorExpr:
			result := Var{make_tmp(g)}
			arg2 := pop(&g.val_list)
			arg1 := pop(&g.val_list)

			append(&output, BitXorOp{result, arg1, arg2})
			append(&g.val_list, result)
		case AstMulExpr:
			result := Var{make_tmp(g)}
			arg2 := pop(&g.val_list)
			arg1 := pop(&g.val_list)

			append(&output, MulOp{result, arg1, arg2})
			append(&g.val_list, result)
		case AstDivExpr:
			result := Var{make_tmp(g)}
			arg2 := pop(&g.val_list)
			arg1 := pop(&g.val_list)

			append(&output, DivOp{result, arg1, arg2})
			append(&g.val_list, result)
		case AstModExpr:
			result := Var{make_tmp(g)}
			arg2 := pop(&g.val_list)
			arg1 := pop(&g.val_list)

			append(&output, ModOp{result, arg1, arg2})
			append(&g.val_list, result)
		case AstAddExpr:
			result := Var{make_tmp(g)}
			arg2 := pop(&g.val_list)
			arg1 := pop(&g.val_list)

			append(&output, AddOp{result, arg1, arg2})
			append(&g.val_list, result)
		case AstSubExpr:
			result := Var{make_tmp(g)}
			arg2 := pop(&g.val_list)
			arg1 := pop(&g.val_list)

			append(&output, SubOp{result, arg1, arg2})
			append(&g.val_list, result)
		case AstLShiftExpr:
			result := Var{make_tmp(g)}
			arg2 := pop(&g.val_list)
			arg1 := pop(&g.val_list)

			append(&output, LShiftOp{result, arg1, arg2})
			append(&g.val_list, result)
		case AstRShiftExpr:
			result := Var{make_tmp(g)}
			arg2 := pop(&g.val_list)
			arg1 := pop(&g.val_list)

			append(&output, RShiftOp{result, arg1, arg2})
			append(&g.val_list, result)
		case AstAndExpr:
            panic("todo!")
		case AstOrExpr:
            panic("todo!")
		case AstEqualExpr:
            panic("todo!")
		case AstNotEqualExpr:
            panic("todo!")
		case AstLessExpr:
            panic("todo!")
		case AstLessEqualExpr:
            panic("todo!")
		case AstGreaterExpr:
            panic("todo!")
		case AstGreaterEqualExpr:
            panic("todo!")
		case AstIntLiteral:
			token := g.token_list[v.value]
			str := cast(string)g.tokenizer.buf[token.start:token.end]
			value := strconv.atoi(str)

			append(&g.val_list, Integer{value})
		}
	}

	return output
}

make_tmp :: proc(g: ^Generator) -> int {
	tmp := g.tmp_count
	g.tmp_count += 1
	return tmp
}

print_tacky_list :: proc(list: [dynamic]Tac, indent := 0) {
	for node in list {
		for i in 0 ..< indent {
			fmt.print(' ')
		}

        #partial switch o in node {
		case ProgOp:
			print_tacky_list(o.func, indent)
		case FuncOp:
			fmt.printfln("%v:", o.ident)
			print_tacky_list(o.body, indent + 4)
		case NegOp:
			fmt.printfln("%v = -%v", o.result, o.arg)
		case NotOp:
			fmt.printfln("%v = !%v", o.result, o.arg)
		case BitNotOp:
			fmt.printfln("%v = ~%v", o.result, o.arg)
		case BitAndOp:
			fmt.printfln("%v = %v & %v", o.result, o.arg1, o.arg2)
		case BitOrOp:
			fmt.printfln("%v = %v | %v", o.result, o.arg1, o.arg2)
		case BitXorOp:
			fmt.printfln("%v = %v ^ %v", o.result, o.arg1, o.arg2)
		case AddOp:
			fmt.printfln("%v = %v + %v", o.result, o.arg1, o.arg2)
		case SubOp:
			fmt.printfln("%v = %v - %v", o.result, o.arg1, o.arg2)
		case MulOp:
			fmt.printfln("%v = %v * %v", o.result, o.arg1, o.arg2)
		case DivOp:
			fmt.printfln("%v = %v / %v", o.result, o.arg1, o.arg2)
		case ModOp:
			fmt.printfln("%v = %v %% %v", o.result, o.arg1, o.arg2)
		case LShiftOp:
			fmt.printfln("%v = %v << %v", o.result, o.arg1, o.arg2)
		case RShiftOp:
			fmt.printfln("%v = %v >> %v", o.result, o.arg1, o.arg2)
		case AndOp:
			fmt.printfln("%v = %v and %v", o.result, o.arg1, o.arg2)
		case OrOp:
			fmt.printfln("%v = %v or %v", o.result, o.arg1, o.arg2)
		case EqualOp:
			fmt.printfln("%v = %v == %v", o.result, o.arg1, o.arg2)
		case NotEqualOp:
			fmt.printfln("%v = %v != %v", o.result, o.arg1, o.arg2)
		case LessOp:
			fmt.printfln("%v = %v < %v", o.result, o.arg1, o.arg2)
		case LessEqualOp:
			fmt.printfln("%v = %v <= %v", o.result, o.arg1, o.arg2)
		case GreaterOp:
			fmt.printfln("%v = %v > %v", o.result, o.arg1, o.arg2)
		case GreaterEqualOp:
			fmt.printfln("%v = %v >= %v", o.result, o.arg1, o.arg2)
		case ReturnOp:
			fmt.printfln("return %v", o.arg)
		}
	}
}
