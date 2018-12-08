.global _start
.text

.set SYS_EXIT, 60
.set SYS_READ, 0
.set SYS_WRITE, 1
.set SYS_OPEN, 2
.set SYS_CLOSE, 3

.set BUFFSIZE, 5

_start:
    add $16, %rsp

    mov (%rsp), %rax

    jmp parse_byte

parse_byte_end:
    add $8, %rsp

    mov $SYS_OPEN, %rax
    pop %rdi
    xor %rsi, %rsi
    syscall

    mov %rax, %r10

    mov $SYS_OPEN, %rax
    pop %rdi
    mov $101, %rsi
    syscall

    mov %rax, %r12

loop:
    mov $SYS_READ, %rax
    mov %r10, %rdi
    mov $buffer, %rsi
    mov $BUFFSIZE, %rdx
    syscall

    mov %rax, %r9

    call xor_buff

    mov $SYS_WRITE, %rax
    mov %r12, %rdi
    mov $buffer, %rsi
    mov %r9, %rdx
    syscall

    cmp $BUFFSIZE, %r9
    je loop

end:
    mov $SYS_CLOSE, %rax
    mov %r10, %rdi
    syscall

    mov $SYS_CLOSE, %rax
    mov %r11, %rdi
    syscall

    mov $SYS_EXIT, %rax
    xor %rdi, %rdi
    syscall 

xor_buff:
    xor %rcx, %rcx
    mov $buffer, %rax

xor_buff_loop:
    cmp $BUFFSIZE, %rcx
    jne xor_buff_op
    ret

xor_buff_op:
    xor %rbx, %rbx
    mov %r15, %rbx
    xorb %bl, (%rax)
    inc %rcx
    inc %rax
    jmp xor_buff_loop

parse_byte:
    xor %rcx, %rcx

parse_byte_push:
    cmpb $57, (%rax)
    jg parse_byte_pop_start
    push (%rax)
    inc %rax
    inc %rcx
    jmp parse_byte_push

parse_byte_pop_start:
    dec %rcx
    pop %r15
    xor %r15, %r15
    mov $1, %r10
    mov %rcx, %r11
    
parse_byte_pop:
    cmp $0, %r11
    je parse_byte_end
    pop %r9
    sub $48, %r9
    imul %r10, %r9
    add %r9, %r15
    imul $10, %r10
    dec %r11
    jmp parse_byte_pop

.data
    buffer:
        .space BUFFSIZE
