package main

import "token"

import "core:fmt"
import "core:os"
import "core:unicode/utf8"

main :: proc() {
    handle, open_err := os.open("test/main.c")
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

    using token

    t := make_tokenizer(buf);

    for tok := next_token(&t); tok.type != TokenType.EOF; tok = next_token(&t) {
        fmt.println(tok)
    }
}
