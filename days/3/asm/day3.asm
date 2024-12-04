SECTION .data
multxt:         db    "mul("
mullen: equ $ - multxt
eqmsg:  db "equal", 10, 0
neqmsg:  db "not equal", 10, 0
newline: db 10
message db "Value = %d", 10, 0
; dotxt:          db    "do()"
; donttxt:        db    "don't()"

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

; Arguments
;   rax: Pointer to null-terminated string
; Returns
;   rax: Length of string
strlen:
    push    rbx
    mov     rbx, rax    
.nextchar:
    cmp     byte [rax], 0
    jz      .finished
    inc     rax
    jmp     .nextchar
.finished:
    sub     rax, rbx
    pop     rbx
    ret


; Arguments
;   rax: Pointer to null-terminated string
print:
    push rax
    push rdi
    push rsi
    push rdx

    mov     rsi, rax    ; string arg

    mov     rsi, rax
    call    strlen
    mov     rdx, rax    ; Put length of string into rdx

    mov     rdi, 1      ; stdin
    mov     rax, 1      ; write
    syscall

    pop rdx
    pop rsi
    pop rdi
    pop rax

    ret

print_w_len:
    push rax
    push rdi
    push rsi
    push rdx

    mov     rsi, rax    ; string arg in rax
    mov     rdx, rdi    ; length arg in rdi
    mov     rdi, 1      ; stdin
    mov     rax, 1      ; write
    syscall

    pop rdx
    pop rsi
    pop rdi
    pop rax

    ret

print_nl:
    push rax
    push rdi
    push rsi
    push rdx

    mov     rsi, newline
    mov     rdx, 1      ; length 1
    mov     rdi, 1      ; stdin
    mov     rax, 1      ; write
    syscall

    pop rdx
    pop rsi
    pop rdi
    pop rax

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
    ; mov rax, sinput
    ; call print

    mov rbx, 1          ; enabled = true
    mov rbp, 0          ; state = 0
    mov r12, 0          ; idx = 0
    mov r13, 0          ; total = 0
    ; r14, r15 used for left/right number value

.check_tok:
    ; Make sure we stay in bounds?
    cmp BYTE [sinput + r12*1], 0
    je .finished

    ; mov rax, sinput
    ; add rax, r12
    ; mov rdi, 4
    ; call print_w_len
    ; call print_nl

    ; We can always start by checking for mul
    ; MUL START
    mov eax, [multxt]
    mov edi, [sinput + r12*1]
    cmp edi, eax
    jne .check_left

; ; debug
; mov rax, eqmsg
; call print

    mov rbp, 1      ; state = 1
    add r12, 4      ; idx += 4
    jmp .check_tok  ; continue

.check_left:
    cmp rbp, 1
    jne .check_comma

    call parse_num  ; parse num into rax, set to 1000 if not a num
    cmp rax, 1000
    je .reset_state
    mov r14, rax    ; store parsed num in left
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
    mov r15, rax    ; store parsed num in right
    mov rbp, 4      ; state = 4
    jmp .check_tok

.check_close:
    cmp rbp, 4
    jne .junk

    cmp byte [sinput + r12*1], ")"
    jne .reset_state
.fuck:
    mov rax, r14
    call print_int
    mov rax, r15
    call print_int
    call print_nl
    mov rax, r14
    mul r15         ; rax = r14 * r15
    add r13, rax    ; r13 += rax
    inc r12         ; idx += 1
    jmp .reset_state

.junk:
    inc r12
    jmp .reset_state

.reset_state:
    mov rbp, 0
    jmp .check_tok

.finished:
    mov rax, r13
    call print_int

    mov rax, 60         ; exit(
    mov rdi, 0          ;   EXIT_SUCCESS
    syscall             ; );
