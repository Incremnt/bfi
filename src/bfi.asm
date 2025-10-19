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
; File: bfi.asm                  ;
; Author: Incremnt               ;
; Compiled file: bfi             ;
; License: GPLv3                 ;
;================================;

format ELF64 executable
entry _start

;--------------;
;--- macros ---;
;--------------;
macro SYSCALL_3 num, arg1, arg2, arg3 {         ; syscall macro for me and your eyes :3    
  mov rax, num                                                                      
  mov rdi, arg1
  mov rsi, arg2
  mov rdx, arg3
  syscall
}

macro SYSCALL_1 num, arg1 {
  mov rax, num
  mov rdi, arg1                                                  
  syscall                                                                            
}                                                                                  

SYS_READ  = 0
SYS_WRITE = 1
SYS_OPEN  = 2
SYS_CLOSE = 3
SYS_BRK   = 12
SYS_EXIT  = 60

O_RDONLY       = 0x0000
O_WRONLY       = 0x0001
O_CREAT        = 0x0040
O_TRUNC        = 0x0200
O_APPEND       = 0x0400
IN_FILE_FLAGS  = O_RDONLY
OUT_FILE_FLAGS = O_WRONLY + O_CREAT + O_TRUNC + O_APPEND
BFI_FILE_FLAGS = O_RDONLY

E_SUCCESS   = 0     ; success
E_USAGE     = 64    ; too many/few arguments
E_DATAERR   = 65    ; unbalanced brackets
E_NOINPUT   = 66    ; can't open input file
E_CANTCREAT = 73    ; can't create output file(embed mode)

BF_TAPE_SIZE    = 30000
BF_CODE_SIZE    = 65536
EMBED_CODE_SIZE = 2634

BF_MAX_CELL   = 29999
BF_FIRST_CELL = 0

;--------------------;
;--- text segment ---;
;--------------------;
;
; register usage:
; r15 - pointer to the brainfuck code
; r14 - pointer to the brainfuck tape (in normal), pointer to the embedded code (in embed mode)
; r13 - pointer to the first cell
; r12 - pointer to the max cell
; rcx - counter
; rbx - buffer
;
segment readable executable
_start:
  SYSCALL_1 SYS_BRK, 0      ; get current heap pointer
  mov rbx, rax
  add rbx, BF_CODE_SIZE + BF_TAPE_SIZE
  SYSCALL_1 SYS_BRK, rbx    ; allocate memory for the code and tape arrays

  sub rbx, BF_CODE_SIZE + BF_TAPE_SIZE    ; set pointers
  mov [bf_code_ptr], rbx
  add rbx, BF_CODE_SIZE
  mov [bf_tape_ptr], rbx
  mov r15, qword [bf_code_ptr]
  mov r14, qword [bf_tape_ptr]
  mov r12, r14
  mov r13, r14
  add r13, BF_MAX_CELL

  cmp qword [rsp], 1
  je usage_err

  mov rbx, [rsp + 16]                   ; second argument pointer in rbx
  mov rbx, qword [rbx]                  ; string with this address in rbx
  cmp rbx, qword [embed_flag]		
  je embed_mode                         ; interpret in embedded mode if "--embed" flag enabled
                                   
  cmp qword [rsp], 2                    ; exit with error if argc != 2                      
  jne usage_err       	                                                 
  mov rbx, [rsp + 16]                   ; input file pointer in rbx

  SYSCALL_3 SYS_OPEN, rbx, IN_FILE_FLAGS, 0  ; open input file in read only mode
  cmp rax, -1				
  jle noinput_err                            ; handle file open error

  mov rbx, rax                                          ; file descriptor in rbx
  SYSCALL_3 SYS_READ, rbx, r15, BF_CODE_SIZE            ; read code from input file
  SYSCALL_1 SYS_CLOSE, rbx                              ; close input file

  mov qword [jump_table + 0 * 8], success_exit          ; init jump table
  mov qword [jump_table + '+' * 8], inc_cell
  mov qword [jump_table + '-' * 8], dec_cell
  mov qword [jump_table + '>' * 8], next_cell
  mov qword [jump_table + '<' * 8], prev_cell
  mov qword [jump_table + ',' * 8], cell_in
  mov qword [jump_table + '.' * 8], cell_out
  mov qword [jump_table + '[' * 8], bf_loop_start
  mov qword [jump_table + ']' * 8], bf_loop_end

  mov r15, qword [bf_code_ptr]
  mov r14, qword [bf_tape_ptr]
  xor rcx, rcx

.bracket_check_loop:                    ; unbalanced brackets check
  cmp byte [r15], '['
  je .inc_rcx
  cmp byte [r15], ']'
  je .dec_rcx
  cmp byte [r15], 0
  je .is_balanced
  inc r15
  jmp .bracket_check_loop
.inc_rcx:
  inc rcx
  inc r15
  jmp .bracket_check_loop
.dec_rcx:
  dec rcx
  inc r15
  test rcx, rcx
  js dataerr_err
  jmp .bracket_check_loop
.is_balanced:
  test rcx, rcx
  jnz dataerr_err

  mov r15, qword [bf_code_ptr]
  mov r14, qword [bf_tape_ptr]
  dec r15

mainloop:
  inc r15
  xor rbx, rbx
  mov bl, byte [r15]
  jmp [jump_table + rbx * 8]

;--------------------------------------;
;--- brainfuck instruction handlers ---;
;--------------------------------------;
inc_cell:               ; increment cell
  inc byte [r14]
  jmp mainloop

dec_cell:               ; decrement cell
  dec byte [r14]
  jmp mainloop

next_cell:              ; increment bf_tape pointer
  cmp r14, r13
  jge .to_first_cell
  inc r14
  jmp mainloop
.to_first_cell:
  mov r14, r12
  jmp mainloop

prev_cell:              ; decrement bf_tape pointer
  cmp r14, r12
  jle .to_max_cell
  dec r14
  jmp mainloop
.to_max_cell:
  mov r14, r13
  jmp mainloop

cell_in:                ; read cell from stdin
  xor rax, rax
  xor rdi, rdi
  lea rsi, [r14]
  xor rdx, rdx
  inc rdx
  syscall
  jmp mainloop

cell_out:               ; write cell to stdout
  xor rax, rax
  inc rax
  xor rdi, rdi
  inc rdi
  lea rsi, [r14]
  xor rdx, rdx
  inc rdx
  syscall
  jmp mainloop

bf_loop_start:                    ; start loop
  cmp byte [r14], 0
  je .init_skip_loop              ; skip if cell = 0
  cmp word [r15 + 1], '-]'        ; [-] pattern optimization
  je .clear_cell
  push r15                        ; save code pointer in stack
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
  xor rcx, rcx
  sub r15, 2
  jmp mainloop
.clear_cell:
  mov byte [r14], 0
  add r15, 2
  jmp mainloop

bf_loop_end:
  cmp byte [r14], 0                     ; skip if cell = 0
  je mainloop
  pop r15                               ; '[' code pointer in r15
  dec r15
  jmp mainloop

;-------------------------------;
;--- embedded mode interpret ---;
;-------------------------------;
embed_mode:
  SYSCALL_1 SYS_BRK, 0      ; get current heap pointer
  mov rbx, rax
  push rbx
  add rbx, BF_CODE_SIZE + EMBED_CODE_SIZE
  SYSCALL_1 SYS_BRK, rbx    ; allocate memory for the code, embed code and tape arrays

  pop rbx
  mov [bf_code_ptr], rbx    ; set pointers
  add rbx, BF_CODE_SIZE
  mov [embed_code_ptr], rbx
  mov r15, qword [bf_code_ptr]
  mov r14, qword [embed_code_ptr]

  cmp qword [rsp], 4                    ; exit with error if argc != 4                      
  jne usage_err            				
  mov rbx, [rsp + 24]                   ; input file pointer in rbx

  SYSCALL_3 SYS_OPEN, rbx, IN_FILE_FLAGS, 0               ; open input file in read only mode
  cmp rax, -1					
  jle noinput_err                                         ; handle file open error

  mov rbx, rax                                          ; file descriptor in rbx
  SYSCALL_3 SYS_READ, rbx, r15, BF_CODE_SIZE            ; read code from input file
  SYSCALL_1 SYS_CLOSE, rbx                              ; close input file

  mov r14, qword [embed_code_ptr]
  mov r15, qword [bf_code_ptr]
  xor rcx, rcx
  push r15

.bracket_check_loop:                                    ; unbalanced brackets check
  cmp byte [r15], '['
  je .inc_rcx
  cmp byte [r15], ']'
  je .dec_rcx
  cmp byte [r15], 0
  je .is_balanced
  inc r15
  jmp .bracket_check_loop
.inc_rcx:
  inc rcx
  inc r15
  jmp .bracket_check_loop
.dec_rcx:
  dec rcx
  inc r15
  test rcx, rcx
  js dataerr_err
  jmp .bracket_check_loop
.is_balanced:
  test rcx, rcx
  jnz dataerr_err

  pop r15
  mov rbx, [rsp + 32]                                     ; output file pointer in rbx
  SYSCALL_3 SYS_OPEN, rbx, OUT_FILE_FLAGS, 0755o          ; open output file with O_WRONLY, O_TRUNC, O_APPEND, O_CREAT flags
  cmp rax, -1						  
  jle cantcreat_err                                       ; handle file open error
  push rax                                                ; save output file descriptor

  SYSCALL_3 SYS_OPEN, embed_interpreter_dir, BFI_FILE_FLAGS, 0  ; open embedded interpreter file
  cmp rax, -1						  
  jle noinput_err                                               ; handle file open error
  mov rbx, rax                                                  ; fd in rax
  SYSCALL_3 SYS_READ, rbx, r14, EMBED_CODE_SIZE                 ; read binary code from file
  SYSCALL_1 SYS_CLOSE, rbx                                      ; close interpreter file

  pop rbx                                                       ; output file descriptor in rbx
  SYSCALL_3 SYS_WRITE, rbx, r14, EMBED_CODE_SIZE                ; write interpreter binary code to output file
  SYSCALL_3 SYS_WRITE, rbx, r15, BF_CODE_SIZE                   ; write brainfuck code to output file
  SYSCALL_1 SYS_CLOSE, rbx                                      ; close output file
  SYSCALL_1 SYS_EXIT, E_SUCCESS                                 ; finally exit!!! :D

;--------------;
;--- errors ---;
;--------------;
success_exit:
  SYSCALL_1 SYS_EXIT, E_SUCCESS

noinput_err:
  SYSCALL_1 SYS_EXIT, E_NOINPUT

cantcreat_err:
  SYSCALL_1 SYS_EXIT, E_CANTCREAT

usage_err:
  SYSCALL_1 SYS_EXIT, E_USAGE

dataerr_err:
  SYSCALL_1 SYS_EXIT, E_DATAERR

;--------------------;
;--- data segment ---;
;--------------------;
segment readable writable
jump_table dq 256 dup(mainloop)

embed_flag db "--embed", 0
embed_interpreter_dir db "/usr/local/share/bfi/embed_bfi.elf", 0    

bf_tape_ptr dq 0  
bf_code_ptr dq 0   
embed_code_ptr dq 0 
