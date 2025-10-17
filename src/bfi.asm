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

SYS_READ = 0
SYS_WRITE = 1
SYS_OPEN = 2
SYS_CLOSE = 3
SYS_EXIT = 60

O_RDONLY = 0x0000
O_WRONLY = 0x0001
O_CREAT = 0x0040
O_TRUNC = 0x0200
O_APPEND = 0x0400
OUT_FILE_FLAGS = O_WRONLY + O_CREAT + O_TRUNC + O_APPEND

STDERR = 2

BF_TAPE_SIZE = 30000
BF_CODE_SIZE = 20000                                                              
BF_MAX_CELL = 29999
BF_FIRST_CELL = 0

EMBED_CODE_SIZE = 32577



;--------------------;
;--- text segment ---;
;--------------------;

; register usage:
; r15 - pointer to brainfuck code
; r14 - pointer to brainfuck tape
; rcx - counter
; rbx - buffer

segment readable executable
_start:
  cmp qword [rsp], 1
  je no_arg_err

  mov rbx, [rsp + 16]			; second argument pointer in rbx
  mov rbx, qword [rbx]			; string with this address in rbx
  cmp rbx, qword [embed_flag]		
  je embed_mode 			; interpret in embedded mode if "--embed" flag enabled
                                   
  cmp qword [rsp], 3            	; exit with error if argc > 2                      
  jge too_many_args_err             	                                                 
  mov rbx, [rsp + 16]           	; input file pointer in rbx
  cmp rbx, 0				
  je no_arg_err                     	; exit with error if you forgog arguments

  SYSCALL_3 SYS_OPEN, rbx, O_RDONLY, 0  ; open input file in read only mode
  cmp rax, -1				
  jle input_file_err            	; handle file open error

  mov rbx, rax					        ; file descriptor in rbx
  SYSCALL_3 SYS_READ, rbx, bf_code, BF_CODE_SIZE        ; read code from input file
  SYSCALL_1 SYS_CLOSE, rbx              		; close input file
  cmp byte [bf_code + BF_CODE_SIZE - 1], 0
  jne code_too_long_err


  mov qword [jump_table + 0 * 8], exit		; init jump table
  mov qword [jump_table + '+' * 8], inc_cell
  mov qword [jump_table + '-' * 8], dec_cell
  mov qword [jump_table + '>' * 8], next_cell
  mov qword [jump_table + '<' * 8], prev_cell
  mov qword [jump_table + ',' * 8], cell_in
  mov qword [jump_table + '.' * 8], cell_out
  mov qword [jump_table + '[' * 8], bf_loop_start
  mov qword [jump_table + ']' * 8], bf_loop_end

  mov r15, bf_code
  mov r14, bf_tape
  xor rcx, rcx

bracket_check_loop:    		 ; unbalanced brackets check
  cmp byte [r15], '['
  je .inc_rcx
  cmp byte [r15], ']'
  je .inc_rcx
  cmp byte [r15], 0
  je .is_balanced
  inc r15
  jmp bracket_check_loop

.inc_rcx:
  inc rcx
  inc r15
  jmp bracket_check_loop

.is_balanced:
  test rcx, 1
  jnz unbalanced_brackets_err


mov r15, bf_code
dec r15

mainloop:
  inc r15
  xor rbx, rbx
  mov bl, byte [r15]
  jmp [jump_table + rbx * 8]


;--------------------------------------;
;--- brainfuck instruction handlers ---;
;--------------------------------------;

inc_cell:			; increment cell
  inc byte [r14]
  jmp mainloop


dec_cell:			; decrement cell
  dec byte [r14]
  jmp mainloop


next_cell: 		; increment bf_tape pointer
  cmp r14, BF_MAX_CELL + bf_tape
  jge .to_first_cell
  inc r14
  jmp mainloop

.to_first_cell:
  mov r14, BF_FIRST_CELL + bf_tape
  jmp mainloop


prev_cell: 		; decrement bf_tape pointer
  cmp r14, bf_tape + BF_FIRST_CELL
  jle .to_last_cell
  dec r14
  jmp mainloop

.to_last_cell:
  mov r14, BF_MAX_CELL + bf_tape
  jmp mainloop


cell_in:                ; read cell from stdin
  xor rax, rax
  xor rdi, rdi
  lea rsi, [r14]
  xor rdx, rdx
  inc rdx
  syscall
  jmp mainloop


cell_out:		; write cell to stdout
  xor rax, rax
  inc rax
  xor rdi, rdi
  inc rdi
  lea rsi, [r14]
  xor rdx, rdx
  inc rdx
  syscall
  jmp mainloop


bf_loop_start:		          ; start loop
  cmp byte [r14], 0
  je .init_skip_loop		  ; skip if cell = 0
  cmp word [r15 + 1], '-]'        ; [-] pattern optimization
  je .clear_cell
  push r15 		          ; save code pointer in stack
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
  cmp byte [r14], 0		        ; skip if cell = 0
  je mainloop
  pop r15				; '[' code pointer in r15
  dec r15
  jmp mainloop


exit:
  SYSCALL_1 SYS_EXIT, 0


;-------------------------------;
;--- embedded mode interpret ---;
;-------------------------------;

embed_mode:
  cmp qword [rsp], 4            	; exit with error if argc != 4                      
  jg too_many_args_err            
  jl no_arg_err				
  mov rbx, [rsp + 24]           	; input file pointer in rbx
  cmp rbx, 0				
  je no_arg_err                     	; exit with error if you enter not enough arguments

  SYSCALL_3 SYS_OPEN, rbx, O_RDONLY, 0  	; open input file in read only mode
  cmp rax, -1					
  jle input_file_err            		; handle file open error

  mov rbx, rax					        ; file descriptor in rbx
  SYSCALL_3 SYS_READ, rbx, bf_code, BF_CODE_SIZE        ; read code from input file
  SYSCALL_1 SYS_CLOSE, rbx              		; close input file
  cmp byte [bf_code + BF_CODE_SIZE - 1], 0
  jne code_too_long_err

  mov r15, bf_code
  xor rcx, rcx

  bracket_check_loop:    		 ; unbalanced brackets check
  cmp byte [r15], '['
  je .inc_rcx
  cmp byte [r15], ']'
  je .inc_rcx
  cmp byte [r15], 0
  je .is_balanced
  inc r15
  jmp bracket_check_loop

.inc_rcx:
  inc rcx
  inc r15
  jmp bracket_check_loop

.is_balanced:
  test rcx, 1
  jnz unbalanced_brackets_err

  mov rbx, [rsp + 32]					  ; output file pointer in rbx
  SYSCALL_3 SYS_OPEN, rbx, OUT_FILE_FLAGS, 0755o          ; open output file with O_WRONLY, O_TRUNC, O_APPEND, O_CREAT flags
  cmp rax, -1						  
  jle output_file_err 				          ; handle file open error
  push rax						  ; save output file descriptor

  SYSCALL_3 SYS_OPEN, embed_interpreter_dir, O_RDONLY, 0  ; open embedded interpreter file
  cmp rax, -1						  
  jle bfi_file_err				          ; handle file open error
  mov rbx, rax						  ; fd in rax
  SYSCALL_3 SYS_READ, rbx, embedded_code, EMBED_CODE_SIZE ; read binary code from file
  SYSCALL_1 SYS_CLOSE, rbx				  ; close interpreter file

  pop rbx							; output file descriptor in rbx
  SYSCALL_3 SYS_WRITE, rbx, embedded_code, EMBED_CODE_SIZE      ; write interpreter binary code to output file
  SYSCALL_3 SYS_WRITE, rbx, bf_code, BF_CODE_SIZE		; write brainfuck code to output file
  SYSCALL_1 SYS_CLOSE, rbx					; close output file
  SYSCALL_1 SYS_EXIT, 0						; finally exit!!! :D


;--------------;
;--- errors ---;
;--------------;

exit_err:
  SYSCALL_1 SYS_EXIT, 1

input_file_err:
  SYSCALL_3 SYS_WRITE, STDERR, input_file_msg, input_file_msg_len
  jmp exit_err

output_file_err:
  SYSCALL_3 SYS_WRITE, STDERR, output_file_msg, output_file_msg_len
  jmp exit_err

bfi_file_err:
  SYSCALL_3 SYS_WRITE, STDERR, bfi_file_msg, bfi_file_msg_len
  jmp exit_err

no_arg_err:
  SYSCALL_3 SYS_WRITE, STDERR, no_arg_msg, no_arg_msg_len
  jmp exit_err

unbalanced_brackets_err:
  SYSCALL_3 SYS_WRITE, STDERR, unbal_brack_msg, unbal_brack_msg_len
  jmp exit_err

code_too_long_err:
  SYSCALL_3 SYS_WRITE, STDERR, code_too_long_msg, code_too_long_msg_len
  jmp exit_err

too_many_args_err:
  SYSCALL_3 SYS_WRITE, STDERR, too_many_args_msg, too_many_args_msg_len
  jmp exit_err



;--------------------;
;--- data segment ---;
;--------------------;

segment readable writable
bf_tape db BF_TAPE_SIZE dup(0)     ; bf tape
bf_code db BF_CODE_SIZE dup(0)    ; bf code from input file

no_arg_msg db 27, '[31m', "[Error]: More arguments, please.", 27, '[0m', 10
no_arg_msg_len = $ - no_arg_msg

input_file_msg db 27, '[31m', "[Error]: Can't open input file.", 27, '[0m', 10
input_file_msg_len = $ - input_file_msg

output_file_msg db 27, '[31m', "[Error]: Can't open output file.", 27, '[0m', 10
output_file_msg_len = $ - output_file_msg

bfi_file_msg db 27, '[31m', "[Error]: Can't open embedded interpreter file.", 27, '[0m', 10
bfi_file_msg_len = $ - bfi_file_msg

unbal_brack_msg db 27, '[31m', "[Error]: Unbalanced brackets.", 27, '[0m', 10                                                
unbal_brack_msg_len = $ - unbal_brack_msg

code_too_long_msg db 27, '[31m', "[Error]: Code is too long.", 27, '[0m', 10
code_too_long_msg_len = $ - code_too_long_msg                                                  

too_many_args_msg db 27, '[31m', "[Error]: Too many arguments.", 27, '[0m', 10
too_many_args_msg_len = $ - too_many_args_msg

jump_table dq 256 dup(mainloop)

embed_flag db "--embed", 0
embed_interpreter_dir db "/usr/local/share/bfi/embed_bfi.elf", 0
embedded_code db EMBED_CODE_SIZE dup(0)
