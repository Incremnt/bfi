#================================#
# Project: Brainfuck interpreter #
# File: Makefile		         #
# Author: Incremnt		         #
#================================#


# tools
ASM = fasm
RM = rm -f

# targets
BFI_TARGET = bin/bfi
EMB_TARGET = bin/embed_bfi.elf

# sources
BFI_SRC = src/bfi.asm
EMB_SRC = src/embed_bfi.asm

# installation paths
EMB_INSTALL_DIR = /usr/local/share/bfi
BFI_INSTALL_DIR = /usr/local/bin

all: $(BFI_TARGET) $(EMB_TARGET)

$(BFI_TARGET): $(BFI_SRC)
	$(ASM) $< $@
	chmod +x $@

$(EMB_TARGET): $(EMB_SRC)
	$(ASM) $< $@

install: all
	mkdir $(EMB_INSTALL_DIR)
	chmod 1777 $(EMB_INSTALL_DIR)
	cp $(EMB_TARGET) $(EMB_INSTALL_DIR)
	cp $(BFI_TARGET) $(BFI_INSTALL_DIR)

clean:
	$(RM) $(BFI_TARGET) $(EMB_TARGET)

.PHONY: all install clean
