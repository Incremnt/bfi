; Copyright (C) 2025 Denis Bazhenov
;
; This program is free software: you can redistribute it and/or modify
; it under the terms of the GNU General Public License as published by
; the Free Software Foundation, either version 3 of the License, or
; (at your option) any later version.
;
; This program is distributed in the hope that it will be useful,
; but WITHOUT ANY WARRANTY; without even the implied warranty of
; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
; GNU General Public License for more details.
;
; You should have received a copy of the GNU General Public License
; along with this program.  If not, see <https://www.gnu.org/licenses/>.
;
;================================;
; Project: Brainfuck Interpreter ;
; File: embed_bfi.asm            ;
; Compiled file: embed_bfi.elf   ;
; Author: Incremnt               ;
; License: GPLv3                 ;
;================================;

format ELF64 executable
entry _start

;--------------;
;--- macros ---;
;--------------;
macro SYSCALL_1 num, arg1 {      ; syscall macro for me and your eyes :3
  mov rdi, arg1
  mov rax, num
  syscall
}

macro SYSCALL_3 num, arg1, arg2, arg3 {
  mov rdi, arg1
  mov rsi, arg2
  mov rdx, arg3
  mov rax, num
  syscall
}

SYS_WRITE = 1
SYS_BRK   = 12
SYS_EXIT  = 60

E_SUCCESS = 0

BF_TAPE_SIZE = 30000
BF_CODE_SIZE = 65537

BF_MAX_CELL  = 29999

;--------------------;
;--- text segment ---;
;--------------------;
segment readable executable
_start:
  mov qword [jump_table + 0 * 8], exit          ; init jump table
  mov qword [jump_table + '+' * 8], inc_cell
  mov qword [jump_table + '-' * 8], dec_cell
  mov qword [jump_table + '>' * 8], next_cell
  mov qword [jump_table + '<' * 8], prev_cell
  mov qword [jump_table + ',' * 8], cell_in
  mov qword [jump_table + '.' * 8], cell_out
  mov qword [jump_table + '[' * 8], bf_loop_start
  mov qword [jump_table + ']' * 8], bf_loop_end
  
  SYSCALL_1 SYS_BRK, 0      ; current heap address in rbx
  mov rbx, rax
  push rbx
  add rbx, BF_TAPE_SIZE
  SYSCALL_1 SYS_BRK, rbx    ; allocate memory for the brainfuck tape
  pop rbx
  mov [bf_tape_ptr], rbx    ; set pointer

  mov r12, qword [bf_tape_ptr]
  mov r13, qword [bf_tape_ptr]
  add r13, BF_MAX_CELL
  mov r14, qword [bf_tape_ptr]
  mov r15, bf_code
  dec r15

mainloop: 		; jump to label in jump table
  inc r15
  xor rbx, rbx
  mov bl, byte [r15]
  jmp qword [jump_table + rbx * 8]

;--------------------------------------;
;--- brainfuck instruction handlers ---;
;--------------------------------------;
inc_cell:
  inc byte [r14]
  jmp mainloop

dec_cell:
  dec byte [r14]
  jmp mainloop

next_cell:		; increment bf_code pointer and go to the first cell if current cell is max
  cmp r14, r13
  je .to_first_cell
  inc r14
  jmp mainloop
.to_first_cell:
  mov r14, r12
  jmp mainloop

prev_cell:		; decrement bf_code pointer and go to the max cell if curren cell is first
  cmp r14, r12
  je .to_max_cell
  dec r14
  jmp mainloop
.to_max_cell:
  mov r14, r13
  jmp mainloop

cell_in:		; read cell from stdin
  xor rax, rax
  xor rdi, rdi
  mov rsi, r14
  mov rdx, 1
  syscall
  jmp mainloop

cell_out:		; write cell to stdout
  SYSCALL_3 SYS_WRITE, 1, r14, 1
  jmp mainloop

bf_loop_start:              ; save r15 in stack and skip loop if cell = 0
  cmp byte [r14], 0
  je .init_skip_loop
  cmp word [r15 + 1], '-]'     ; [-] pattern optimization
  je .clear_cell
  push r15
  jmp mainloop
.init_skip_loop:
  xor rcx, rcx
.skip_loop:
  cmp byte [r15], '['
  je .inc_rcx
  cmp byte [r15], ']'
  je .dec_rcx
  inc r15
  test rcx, rcx
  jnz .skip_loop
  jmp .exit_skip_loop
.inc_rcx:
  inc rcx
  inc r15
  jmp .skip_loop
.dec_rcx:
  dec rcx
  inc r15
  jmp .skip_loop
.exit_skip_loop:
  sub r15, 2
  jmp mainloop
.clear_cell:
  mov byte [r14], 0
  add r15, 2
  jmp mainloop

bf_loop_end:             ; restore r15 and skip if cell = 0
  cmp byte [r14], 0
  je mainloop
  pop r15
  dec r15
  jmp mainloop

exit:			; exit :]
  SYSCALL_1 SYS_EXIT, E_SUCCESS

;--------------------;
;--- data segment ---;
;--------------------;
segment readable writable
jump_table dq 256 dup(mainloop)

bf_tape_ptr dq 0
bf_code = $         ; it's just a pointer
