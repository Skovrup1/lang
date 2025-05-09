package tacky

import "../lexer"
import "../parser"

import "core:fmt"
import "core:strconv"

Constant :: struct {
	value: int,
}

Var :: struct {
	ident: string,
}

Val :: union {
	Var,
	Constant,
}

ProgOp :: struct {
	func: [dynamic]Tac,
}

FuncOp :: struct {
	ident: string,
	body:  [dynamic]Tac,
}

AddOp :: struct {
	result: int,
	arg1:   int,
	arg2:   int,
}

SubOp :: struct {
	result: int,
	arg1:   int,
	arg2:   int,
}

MulOp :: struct {
	result: int,
	arg1:   int,
	arg2:   int,
}

DivOp :: struct {
	result: int,
	arg1:   int,
	arg2:   int,
}

BitCompOp :: struct {
	result: int,
	arg:    int,
}

ReturnOp :: struct {
	result: int,
}

IntOp :: struct {
	result: int,
	arg:    int,
}

Tac :: union {
	ProgOp,
	FuncOp,
	AddOp,
	SubOp,
	MulOp,
	DivOp,
	BitCompOp,
	ReturnOp,
	IntOp,
}

Generator :: struct {
	ast_list:   [dynamic]parser.Node,
	token_list: #soa[dynamic]lexer.Token,
	tokenizer:  lexer.Tokenizer,
}

make_generator :: proc(
	ast_list: [dynamic]parser.Node,
	token_list: #soa[dynamic]lexer.Token,
	tokenizer: lexer.Tokenizer,
) -> Generator {
	return Generator{ast_list, token_list, tokenizer}
}

generate :: proc(g: ^Generator) -> []Tac {
	using parser

	output := make([dynamic]Tac)

	tmp := 0

	for node in g.ast_list {
		switch v in node {
		case AstProgDef:
		case AstFuncDef:
			token := g.token_list[v.ident]
			str := g.tokenizer.buf[token.start:token.end]
			body := output
			output = make([dynamic]Tac)
			append(&output, FuncOp{ident = cast(string)str, body = body})
		case AstReturnStmt:
			append(&output, ReturnOp{result = tmp - 1})
			tmp += 1
		case AstParenExpr:
		case AstBitCompExpr:
			append(&output, BitCompOp{result = tmp, arg = tmp - 1})
			tmp += 1
		case AstMulExpr:
			append(&output, MulOp{result = tmp, arg1 = tmp - 1, arg2 = tmp - 2})
			tmp += 1
		case AstDivExpr:
			append(&output, DivOp{result = tmp, arg1 = tmp - 1, arg2 = tmp - 2})
			tmp += 1
		case AstAddExpr:
			append(&output, AddOp{result = tmp, arg1 = tmp - 1, arg2 = tmp - 2})
			tmp += 1
		case AstSubExpr:
			append(&output, SubOp{result = tmp, arg1 = tmp - 1, arg2 = tmp - 2})
			tmp += 1
		case AstIntLiteral:
			token := g.token_list[v.value]
			str := g.tokenizer.buf[token.start:token.end]
			value := strconv.atoi(cast(string)str)

			append(&output, IntOp{result = tmp, arg = value})
			tmp += 1
		}
	}

	return output[:]
}
