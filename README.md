# Brainfuck interpreter for Linux x86_64 by Incremnt
A simple and fast Brainfuck interpreter with embedded mode written in assembly language (FASM).

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

2.  **Build the repository**
   ```bash
   sudo make all
   ```

## Usage
To interpret the code from the input file, you need to execute interpreter with the input file.
1.  **Normal mode**:
   ```bash
   ./bfi input.bf
   ```
2.  **Embedded mode**:
   ```bash
   ./bfi --embed input.bf out.a
   ```

 
