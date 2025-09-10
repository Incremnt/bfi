# Brainfuck interpreter for Linux x86_64 by Incremnt
A simple and fast Brainfuck interpreter written in assembly language (FASM).

## License
This project is licensed under the **GNU General Public License v3.0 (GPL-3.0)**.
See the [`LICENSE`](LICENSE) file for the full text.

## Building from source
To build the interpreter, you need **Flat Assembler (FASM)**.

1.  **Install FASM**:
    *   On Arch Linux and derivatives, install from the official repos:
        ```bash
        sudo pacman -S fasm
        ```
    *   For other distributions, download the Linux version from the [official FASM website](https://flatassembler.net/).

2.  **Clone this repository** and compile the source:
    ```bash
    fasm source.asm bfi
    ```
3.  The resulting executable `bfi` will be ready to use.


