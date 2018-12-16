.global read
.global write
.global error
.global newline
.global exit
.global print_dec
.text

# read 1 byte from stdin to rax
read:
    sub $8, %rsp
	xor %rax, %rax
    xor %rdi, %rdi
    mov %rsp, %rsi
    mov $1, %edx
    syscall
    pop %rax
    ret

# write 1 byte from rax to stdout
write:
	push %rax
	mov %rsp, %rsi
	mov $1, %rax
	mov $1, %rdx
	mov $1, %rdi
	push %rcx
	syscall
	pop %rcx
	pop %rax
	ret

# write to stdout rax msg with rbx len and exit
error:
	call newline
	mov %rax, %rsi
	mov $1, %rax
	mov $1, %rdi
	mov %rbx, %rdx
	syscall
	call exit
	ret

# write \n to stdout
newline:
	push %rax
	push %rbx
	mov $10, %rax
	call write
	pop %rbx
	pop %rax
	ret

# print in decimial from rax
# sign in r15
print_dec:
	push %rax
	mov $10, %rbx
	xor %rcx, %rcx

	cmp $0, %rax
	je print_zero
	cmp $1, %r15
	je print_neg

	print_dec_loop_div:
		cmp $0, %rax
		je print_dec_loop_write
		xor %rdx, %rdx
		div %rbx
		add $48, %rdx
		push %rdx
		inc %rcx
		jmp print_dec_loop_div

	print_dec_loop_write:
		pop %rax
		call write
		dec %rcx
		cmp $0, %rcx
		jne print_dec_loop_write
		jmp print_dec_exit

	print_zero:
		xor $48, %rax
		call write

	print_dec_exit:
		pop %rax
		ret

	print_neg:
		push %rax
		mov $45, %rax
		call write
		pop %rax
		jmp print_dec_loop_div

exit:
	mov $60, %rax
	xor %rdi, %rdi
	syscall
	ret
