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

;--- bf interpreter for Linux x86_64 by Incremnt (fasm btw) ---;
format ELF64 executable
entry _start
                                                               
                                                                                   
                                                                                   
;--- text segment ---;                                                             
segment readable executable                                                        
macro syscall_3 num, arg1, arg2, arg3 {         ; macro for me and your eyes :3    
mov rax, num                                                                      
mov rdi, arg1
mov rsi, arg2
mov rdx, arg3
syscall
}

macro syscall_1 num, arg1 {
mov rax, num
mov rdi, arg1                                                  
syscall                                                                            
}                                                                                  
                                                                                   
_start:                                                                            
cmp qword [rsp], 3              ; exit with error if argc > 2                      
jge too_many_args                                                                 
mov rbx, [rsp + 16]     ; input file in rbx
cmp rbx, 0
je no_arg               ; exit with error if you forgog arguments
syscall_3 2, rbx, 0, 0
cmp rax, -1
jle no_file             ; exit with error if you forgor input file
mov r15, rax
syscall_3 0, r15, code, 20000
cmp byte [code + 19999], 0
jne code_too_long
cmp byte [code], 0
je empty_file
syscall_1 3, r15
pop r15                 ; stack clear
pop r14                 ; stack clear
xor r15, r15            ; code element
xor r14, r14            ; bf tape element and [ counter in bracket check loop
xor r13, r13            ; ] counter in bracket check loop

mov qword [jump_table + 43 * 8], plus    ; init jump table
mov qword [jump_table + 45 * 8], minus
mov qword [jump_table + 62 * 8], next
mov qword [jump_table + 60 * 8], back
mov qword [jump_table + 44 * 8], char_in
mov qword [jump_table + 46 * 8], char_out
mov qword [jump_table + 91 * 8], loop_start
mov qword [jump_table + 93 * 8], loop_end

bracket_check_loop:     ; unbalanced brackets check
cmp byte [code + r15], 91
je inc_bracket1_count
cmp byte [code + r15], 93
je inc_bracket2_count
inc r15
cmp byte [code + r15], 0
je check_bracket_count
jmp bracket_check_loop

jmp mainloop

to_loop:
inc r15
mainloop:               ; cmp bf instructions and code from input file
xor rax, rax
mov al, byte [code + r15]
test al, al
jz exit
jmp [jump_table + rax * 8]

;--- bf instructions and more ---;
plus:
inc byte [arr + r14]
jmp to_loop

minus:
dec byte [arr + r14]
jmp to_loop

next:
cmp r14, 29999
jge to_zero
inc r14
jmp to_loop

back:
cmp r14, 0
jle to_max
dec r14
jmp to_loop

char_in:                ; rbx as char buffer
mov rbx, arr
add rbx, r14
syscall_3 0, 0, rbx, 1
cmp rax, 1
je to_loop
cmp rax, 0
je eof
jmp input_error

eof:
mov byte [arr + r14], 0
jmp to_loop

char_out:               ; rbx as char buffer
mov rbx, arr
add rbx, r14
syscall_3 1, 1, rbx, 1
cmp rax, -1
jle output_error
jmp to_loop

loop_start:
cmp byte [arr + r14], 0
je skip_loop
cmp word [code + r15 + 1], 0x5d2d        ; [-] pattern optimization
je clear_current_cell
push r15
jmp to_loop

loop_end:
cmp byte [arr + r14], 0
je to_loop
pop r15
jmp mainloop

skip_loop:
inc r15
cmp byte [code + r15], 91
je inc_nesting
cmp byte [code + r15], 93
je dec_nesting
cmp byte [code + r15], 0
je exit
jmp skip_loop

inc_nesting:
inc r13
jmp skip_loop

dec_nesting:
dec r13
jmp skip_loop

to_zero:
mov r14, 0
jmp to_loop

to_max:
mov r14, 29999
jmp to_loop

clear_current_cell:
mov byte [arr + r14], 0
add r15, 3
jmp mainloop

exit:
syscall_1 60, 0

;--- errors ---;
exit_err:
syscall_1 60, 1

no_arg:
syscall_3 1, 2, no_arg_msg, no_arg_msg_len
jmp exit_err

no_file:
syscall_3 1, 2, no_file_msg, no_file_msg_len
jmp exit_err

unbalanced_brackets:
syscall_3 1, 2, unbal_brack_msg, unbal_brack_msg_len
jmp exit_err

inc_bracket1_count:
inc r14
inc r15
jmp bracket_check_loop

inc_bracket2_count:
inc r13
inc r15
jmp bracket_check_loop

check_bracket_count:
cmp r13, r14
jne unbalanced_brackets
xor r13, r13
xor r14, r14
xor r15, r15
jmp mainloop

code_too_long:
syscall_3 1, 2, code_too_long_msg, code_too_long_msg_len
jmp exit_err

empty_file:
syscall_3 1, 2, empty_file_msg, empty_file_msg_len
jmp exit_err

input_error:
syscall_3 1, 2, input_error_msg, input_error_msg_len
jmp exit_err

output_error:
syscall_3 1, 2, output_error_msg, output_error_msg_len
jmp exit_err

too_many_args:
syscall_3 1, 2, too_many_args_msg, too_many_args_msg_len
jmp exit_err



;--- data segment ---;
segment readable writable
arr db 30000 dup(0)     ; bf tape
code db 20000 dup(0)    ; bf code from input file
no_arg_msg db 27, '[31m', "[Error]: Arguments, please.", 27, '[0m', 10
no_arg_msg_len = $ - no_arg_msg
no_file_msg db 27, '[31m', "[Error]: Create this file first.", 27, '[0m', 10
no_file_msg_len = $ - no_file_msg
unbal_brack_msg db 27, '[31m', "[Error]: Unbalanced brackets.", 27, '[0m', 10                                                
unbal_brack_msg_len = $ - unbal_brack_msg                                                      
code_too_long_msg db 27, '[31m', "[Error]: Code is too long.", 27, '[0m', 10                                                                                 
code_too_long_msg_len = $ - code_too_long_msg                                                  
empty_file_msg db 27, '[31m', "[Error]: Input file is empty.", 27, '[0m', 10                                                                                 
empty_file_msg_len = $ - empty_file_msg                                                        
input_error_msg db 10, 27, '[31m', "[Error]: Input error.", 27, '[0m', 10                                                                                  
input_error_msg_len = $ - input_error_msg
output_error_msg db 10, 27, '[31m', "[Error]: Output error.", 27, '[0m', 10
output_error_msg_len = $ - output_error_msg
too_many_args_msg db 27, '[31m', "[Error]: Too many arguments.", 27, '[0m', 10
too_many_args_msg_len = $ - too_many_args_msg

jump_table dq 256 dup(to_loop)
