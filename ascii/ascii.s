.global _start
.text
_start:
	push $0
	xor %rbx, %rbx
	jmp turn
	
turn:
	pop %rax
	push %rax
	cmp $32, %rax
	jl stub
	cmp $126, %rax
	jg stub
	mov %rsp, %rsi
	jmp print

stub:
	mov $dot, %rsi
	jmp print

print:
	mov $1, %rax
	mov $1, %rdi
	mov $1, %rdx
	syscall
	jmp newturn

newturn:
	pop %rax
	cmp $255, %rax
	jne inc
	jmp end

inc:
	inc %rax
	push %rax
	cmp $15, %rbx
	je newline
	inc %rbx
	jmp turn

newline:
	push $10
	mov %rsp, %rsi
	mov $1, %rax
	mov $1, %rdi
	mov $1, %rdx
	syscall
	pop %rbx
	xor %rbx, %rbx
	jmp turn

end:
	mov $60, %rax
	xor %rdi, %rdi
	syscall

.data
 dot:
 	.ascii "."
