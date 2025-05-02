package main

import tok "parser/tokenizer"
import par "parser"
import "tacky"

import "core:fmt"
import "core:os"
import "core:unicode/utf8"

main :: proc() {
    handle, open_err := os.open("tests/unary_expr.lang")
    defer os.close(handle);

    if open_err != os.ERROR_NONE {
        panic("failed to open file")
    }

    buf, read_err := os.read_entire_file_from_handle_or_err(handle);
    if read_err != os.ERROR_NONE {
        panic("failed to read file")
    }
    defer delete(buf)

    fmt.print(transmute(string) buf)


    t := tok.make_tokenizer(buf)

    token_list := tok.tokenize(&t)

    fmt.println("Tokens")
    for token in token_list {
        fmt.println(token)
    }

    p := par.make_parser(t, token_list)

    node_list := par.parse(&p)

    fmt.println("Ast")
    for node in node_list {
        fmt.println(node)
    }

    fmt.println("Ast list")
    fmt.println(node_list)

    g := tacky.make_generator()
    tacky_list := tacky.generate(&g)

    fmt.println("Tacky")
    fmt.println(tacky_list)
}
