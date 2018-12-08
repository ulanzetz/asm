.global _start
.text

_start:
	mov %rsp, %r15

read1:
    sub $8, %rsp
	xor %rax, %rax
    xor %rdi, %rdi
    mov %rsp, %rsi
    mov $1, %edx
    syscall
	cmp $48, (%rsp)
	jl collect1
	jmp read1

collect1:
	mov (%rsi), %r14
  	add $8, %rsp
	mov $0, %r8
	mov $1, %r9

add1:
	pop %r10
	sub $48, %r10
	imul %r9, %r10
	add %r10, %r8
	cmp %rsp, %r15
	jne cont1

read2:
    sub $8, %rsp
	xor %rax, %rax
    xor %rdi, %rdi
    mov %rsp, %rsi
    mov $1, %edx
    syscall
	cmp $48, (%rsp)
	jl collect2
	jmp read2

collect2:
  	add $8, %rsp
	mov $0, %r11
	mov $1, %r12

add2:
	pop %r10
	sub $48, %r10
	imul %r12, %r10
	add %r10, %r11
	cmp %rsp, %r15
	jne cont2
	cmp $43, %r14
	je add_op
	cmp $42, %r14
	je mul_op
	cmp $45, %r14
	je min_op
	cmp $47, %r14
	je div_op

add_op:
	add %r11, %r8
	jmp start_print

mul_op:
	imul %r11, %r8
	jmp start_print

min_op:
	sub %r11, %r8
	jmp start_print

div_op:
	push %rax
	mov %r8, %rax
	xor %rdx, %rdx
	div %r11
	mov %rax, %r8
	pop %rax
	jmp start_print

start_print:
	mov %r8, %rax
	mov $10, %rbx
	xor %rcx, %rcx

#print in dec

loop:
	cmp $0, %rax
	je print
	xor %rdx, %rdx
	div %rbx
	add $48, %rdx
	push %rdx
	inc %rcx
	jmp loop

print:
	mov %rsp, %rsi
	mov $1, %rax
	mov $1, %rdx
	mov $1, %rdi
	push %rcx
	syscall
	pop %rcx
	dec %rcx
	pop %rax
	cmp $0, %rcx
	je end
	jmp print

end:
	push $10
	mov %rsp, %rsi
	mov $1, %rax
	mov $1, %rdi
	mov $1, %rdx
	syscall

	mov $60, %rax
	xor %rdi, %rdi
	syscall

cont1:
	imul $10, %r9
	jmp add1

cont2:
	imul $10, %r12
	jmp add2
