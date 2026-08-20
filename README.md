# Unbricked

A simple Game Boy game.

## References

* [GB ASM Tutorial](https://gbdev.io/gb-asm-tutorial/index.html)
* [RGBDS](https://rgbds.gbdev.io/) (a free assembler/linker package for the Game Boy and Game Boy Color)

## Build

    rgbasm -o main.o main.asm
    rgbasm -o input.o input.asm
    rgblink -o unbricked.gb main.o input.o
    rgbfix -v -p 0xFF unbricked.gb
