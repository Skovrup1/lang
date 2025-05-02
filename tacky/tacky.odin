package tacky

Generator :: struct {

}

make_generator :: proc() -> Generator {
    return Generator {}
}

generate :: proc(g: ^Generator) -> []u8 {
    return {}
}
