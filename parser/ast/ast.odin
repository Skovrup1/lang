package ast

Node :: struct {
	kind: NodeKind,
}

NodeKind :: union {
	// definitions
	AstProgDef,
	AstFuncDef,
	// statements
	AstReturnStmt,
	// expressions
	AstBitCompExpr,
	AstMulExpr,
	AstDivExpr,
	AstAddExpr,
	AstSubExpr,
	// literals
	AstIntLiteral,
}

NodeIndex :: distinct int
TokenIndex :: distinct int

AstProgDef :: struct {
	node: NodeIndex,
}

AstFuncDef :: struct {
	name: TokenIndex,
	node: NodeIndex,
}

AstReturnStmt :: struct {
	node: NodeIndex,
}

AstBitCompExpr :: struct {
	node: NodeIndex,
}

AstUnExpr :: struct {
	node: NodeIndex,
}

AstMulExpr :: struct {
	left:  NodeIndex,
	right: NodeIndex,
}

AstDivExpr :: struct {
	left:  NodeIndex,
	right: NodeIndex,
}

AstAddExpr :: struct {
	left:  NodeIndex,
	right: NodeIndex,
}

AstSubExpr :: struct {
	left:  NodeIndex,
	right: NodeIndex,
}

AstIntLiteral :: struct {
	value: TokenIndex,
}
