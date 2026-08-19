# Unbricked

> A simple Game Boy game made while following the gb-asm-tutorial.

## References

* [https://gbdev.io/gb-asm-tutorial/index.html](https://gbdev.io/gb-asm-tutorial/index.html)

## Build

    rgbasm -o main.o main.asm
    rgbasm -o input.o input.asm
    rgblink -o unbricked.gb main.o input.o
    rgbfix -v -p 0xFF unbricked.gb

