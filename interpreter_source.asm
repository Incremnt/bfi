;--- bf interpreter for Linux x86_64 by Denis Bazhenov (fasm btw) ---;
format ELF64 executable
entry _start



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
xor r13, r13            ; nesting degree and ] counter in bracket check loop

bracket_check_loop:     ; unbalanced brackets check
cmp byte [code + r15], 91
je inc_bracket1_count
cmp byte [code + r15], 93
je inc_bracket2_count
inc r15
cmp byte [code + r15], 0
je check_bracket_count
jmp bracket_check_loop

mainloop:               ; cmp bf instructions and code from input file
cmp r15, 20000  ; end if end
jge exit
cmp byte [code + r15], 0
je exit         ; end if end
cmp byte [code + r15], 43        ;  +
je plus
cmp byte [code + r15], 45        ;  -
je minus
cmp byte [code + r15], 62        ;  >
je next
cmp byte [code + r15], 60        ;  <
je back
cmp byte [code + r15], 44        ;  ,
je char_in
cmp byte [code + r15], 46        ;  .
je char_out
cmp byte [code + r15], 91        ;  [
je loop_start
cmp byte [code + r15], 93        ;  ]
je loop_end
to_loop:
inc r15
jmp mainloop

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
je skip_loop_body
inc r13
push r15
jmp to_loop

loop_end:
dec r13
cmp byte [arr + r14], 0
je to_loop
mov r15, qword [rsp + r13 * 8]
mov qword [rsp + r13 * 8], 0
jmp mainloop

skip_loop_body:
mov r13, 1
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
