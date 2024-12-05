SECTION .data
multxt:         db    "mul("
dotxt:          db    "do()"
donttxt:        db    "don't()"
newline: db 10
message db "Value = %d", 10, 0

SECTION .bss
sinput:     resb 0x8000  ; 32 KB for problem input

SECTION .text
extern printf
global main

; Argument order:
; rdi, rsi, rdx, rcx

readinput:
    mov     rdx, 0x8000
    mov     rsi, sinput ; destination buffer
    mov     rdi, 0      ; stdin
    mov     rax, 0      ; write
    syscall
    ret

print_int:
    mov rdi, message
    mov rsi, rax
    call printf
    ret

; Parses number into rax, increments idx.
; If the parsing fails, rax is set to 1000.
; The problem only has 3 digit integers so this is a valid sentinel value.
parse_num:
    mov rax, 0
    mov r11, 10

    ; first digit
    movzx r10, byte [sinput + r12*1]
    cmp r10, "0"
    jl .fail
    cmp r10, "9"
    jg .fail
    sub r10, "0"
    add rax, r10
    inc r12

    ; second digit
    movzx r10, byte [sinput + r12*1]
    cmp r10, "0"
    jl .return
    cmp r10, "9"
    jg .return
    sub r10, "0"
    mul r11
    add rax, r10
    inc r12

    ; third digit
    movzx r10, byte [sinput + r12*1]
    cmp r10, "0"
    jl .return
    cmp r10, "9"
    jg .return
    sub r10, "0"
    mul r11
    add rax, r10
    inc r12

    ; done
.return:
    ret
.fail:
    mov rax, 1000
    ret

main:
    call readinput      ; reads stdin into sinput

    mov rbx, 1          ; enabled = true
    mov rbp, 0          ; state = 0
    mov r12, 0          ; idx = 0
    mov r13, 0          ; total = 0
    mov r14, 0          ; total2 = 0

.check_tok:
    ; Make sure we stay in bounds?
    cmp BYTE [sinput + r12*1], 0
    je .finished

    ; check DO
    mov eax, [dotxt]
    mov edi, [sinput + r12*1]
    cmp edi, eax
    jne .check_dont
    mov rbx, 1
    add r12, 4
    mov rbp, 0
    jmp .check_tok
.check_dont:
    mov eax, [donttxt]
    mov edi, [sinput + r12*1]
    cmp edi, eax
    jne .mul
    ; check for t
    mov rdi, r12
    add rdi, 4
    mov al, "t"
    mov dil, [sinput + rdi*1]
    cmp al, dil
    jne .mul
    ; check for (
    mov rdi, r12
    add rdi, 5
    mov al, "("
    mov dil, [sinput + rdi*1]
    cmp al, dil
    jne .mul
    ; check for )
    mov rdi, r12
    add rdi, 6
    mov al, ")"
    mov dil, [sinput + rdi*1]
    cmp al, dil
    jne .mul
    mov rbx, 0
    add r12, 7
    mov rbp, 0
    jmp .check_tok

.mul:
    ; We can always start by checking for mul
    ; MUL START
    mov eax, [multxt]
    mov edi, [sinput + r12*1]
    cmp edi, eax
    jne .check_left

    mov rbp, 1      ; state = 1
    add r12, 4      ; idx += 4
    jmp .check_tok  ; continue

.check_left:
    cmp rbp, 1
    jne .check_comma

    call parse_num  ; parse num into rax, set to 1000 if not a num
    cmp rax, 1000
    je .reset_state

    push rax        ; store parsed num in stack

    mov rbp, 2      ; state = 2
    jmp .check_tok

.check_comma:
    cmp rbp, 2
    jne .check_right

    cmp BYTE [sinput + r12*1], ","
    jne .reset_state
    inc r12
    mov rbp, 3          ; state = 3
    jmp .check_tok

.check_right:
    cmp rbp, 3
    jne .check_close

    call parse_num
    cmp rax, 1000
    je .reset_state

    push rax        ; store parsed num in stack

    mov rbp, 4      ; state = 4
    jmp .check_tok

.check_close:
    cmp rbp, 4
    jne .junk

    cmp byte [sinput + r12*1], ")"
    jne .reset_state

    ; pop left and right nums from stack, multiply in rax
    pop rax
    pop r15
    mul r15

    add r13, rax    ; r13 += rax
    cmp rbx, 1
    jne .not_enabled
    add r14, rax
.not_enabled:
    inc r12         ; idx += 1
    
    ; hack because reset state will pop two values
    push rax
    push rax

    jmp .reset_state

.junk:
    inc r12
    jmp .reset_state

.reset_state:
    ; we need to reset the stack too
    cmp rbp, 2
    jl .reset_state_jmp
    pop rax
    cmp rbp, 3
    jl .reset_state_jmp
    pop rax
.reset_state_jmp:
    mov rbp, 0
    jmp .check_tok

.finished:
    mov rax, r13
    call print_int
    mov rax, r14
    call print_int

    mov rax, 60         ; exit(
    mov rdi, 0          ;   EXIT_SUCCESS
    syscall             ; );
