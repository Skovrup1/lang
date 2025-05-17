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

BitCompOp :: struct {
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

ReturnOp :: struct {
	arg: Val,
}

Tac :: union {
	ProgOp,
	FuncOp,
	AddOp,
	SubOp,
	MulOp,
	DivOp,
	NegOp,
	BitCompOp,
	ReturnOp,
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
		case AstBitCompExpr:
			result := Var{make_tmp(g)}
			arg := pop(&g.val_list)

			append(&output, BitCompOp{result, arg})
			append(&g.val_list, result)
		case AstNegExpr:
			result := Var{make_tmp(g)}
			arg := pop(&g.val_list)

			append(&output, NegOp{result, arg})
			append(&g.val_list, result)
		case AstMulExpr:
			result := Var{make_tmp(g)}
			arg1 := pop(&g.val_list)
			arg2 := pop(&g.val_list)

			append(&output, MulOp{result, arg1, arg2})
			append(&g.val_list, result)
		case AstDivExpr:
			result := Var{make_tmp(g)}
			arg1 := pop(&g.val_list)
			arg2 := pop(&g.val_list)

			append(&output, DivOp{result, arg1, arg2})
			append(&g.val_list, result)
		case AstAddExpr:
			result := Var{make_tmp(g)}
			arg1 := pop(&g.val_list)
			arg2 := pop(&g.val_list)

			append(&output, AddOp{result, arg1, arg2})
			append(&g.val_list, result)
		case AstSubExpr:
			result := Var{make_tmp(g)}
			arg1 := pop(&g.val_list)
			arg2 := pop(&g.val_list)

			append(&output, SubOp{result, arg1, arg2})
			append(&g.val_list, result)
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

		switch o in node {
		case ProgOp:
			print_tacky_list(o.func, indent)
		case FuncOp:
			fmt.printfln("%v:", o.ident)
			print_tacky_list(o.body, indent + 4)
		case NegOp:
			fmt.printfln("%v = -%v", o.result, o.arg)
		case BitCompOp:
			fmt.printfln("%v = ~%v", o.result, o.arg)
		case AddOp:
			fmt.printfln("%v = %v + %v", o.result, o.arg1, o.arg2)
		case SubOp:
			fmt.printfln("%v = %v - %v", o.result, o.arg1, o.arg2)
		case MulOp:
			fmt.printfln("%v = %v * %v", o.result, o.arg1, o.arg2)
		case DivOp:
			fmt.printfln("%v = %v / %v", o.result, o.arg1, o.arg2)
		case ReturnOp:
			fmt.printfln("return %v", o.arg)
		}
	}
}
