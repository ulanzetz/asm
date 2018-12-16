.global postfix
.set plus_sign, 43
.set minus_sign, 45
.set mul_sign, 42
.set div_sign, 47
.set mod_sign, 37
.set abs_char, 124
.set sign_char, 60
.set space, 32
.set newline_char, 10

postfix:
	xor %r10, %r10
	xor %r9, %r9
	xor %r8, %r8

postfix_loop:
	xor %rcx, %rcx
	cmp $1, %r10
	je output
	
	call read

	#out end
	cmpb $newline_char, %al
	je output
	cmpb $0, %al
	je output

	cmpb $space, %al
	je postfix_loop
	cmpb $abs_char, %al
	je number
	cmpb $sign_char, %al
	je number
	cmpb $47, %al
	jg number_or_word

	#ops
	cmpb $plus_sign, %al
	je plus_op
	cmpb $minus_sign, %al
	je min_sign
	cmpb $mul_sign, %al
	je mul_op
	cmpb $div_sign, %al
	je div_op
	cmpb $mod_sign, %al
	je mod_op

	call parsing_atom_error

min_sign:
	call read
	cmpb $space, %al
	je sub_op
	cmpb $newline_char, %al
	je sub_op
	cmpb $0, %al
	je sub_op
	mov $1, %rcx
	cmpb $47, %al
	jg number_or_word
	call parsing_atom_error

number_or_word:
	cmpb $58, %al
	jl number
	jmp output

number:
	mov $1, %r9
	push %rcx
	call read_int
	pop %rcx
	inc %r8
	push %rax
	push %r15
	cmp $1, %rcx
	je replace_min
	jmp postfix_loop

replace_min:
	pop %rcx
	push $1
	jmp postfix_loop

end_op:
	dec %r8
	jmp postfix_loop

plus_op:
	cmp $2, %r8
	jl invalid_statement_error

	pop %r14
	pop %rbx
	pop %r13
	pop %rax

plus_after_pop:
	cmp $0, %r14
	jne plus_op_first_neg

	cmp $0, %r13
	jne plus_op_sec_neg

	add %rbx, %rax
	push %rax
	push $0

	jmp end_op

	plus_op_first_neg:
		cmp $0, %r13
		jne plus_op_both_neg
		cmp %rbx, %rax
		jge plus_op_rax_gr
		sub %rax, %rbx
		push %rbx
		push $1
		jmp end_op

	plus_op_both_neg:
		add %rbx, %rax
		push %rax
		push $1
		jmp end_op

	plus_op_rax_gr:
		sub %rbx, %rax
		push %rax
		push $0
		jmp end_op

	plus_op_sec_neg:
		mov %r14, %rcx
		mov %r13, %r14
		mov %rcx, %r13
		mov %rax, %rcx
		mov %rbx, %rax
		mov %rcx, %rbx
		jmp plus_op_first_neg

sub_op:
	cmp $2, %r8
	jl invalid_statement_error

	pop %r14
	pop %rbx
	pop %r13
	pop %rax

	cmp $0, %r14
	je sub_op_1
	xor %r14, %r14
	jmp plus_after_pop

	sub_op_1:
		mov $1, %r14
		jmp plus_after_pop

mul_op:
	cmp $2, %r8
	jl invalid_statement_error

	pop %r14
	pop %rbx
	pop %r13
	pop %rax
	imul %rbx, %rax
	push %rax

	cmp $0, %r14
	je mul_op_first_pos
	cmp $0, %r13
	je mul_op_ret_min
	push $0

	jmp end_op

	mul_op_ret_min:
		push $1
		jmp end_op

	mul_op_first_pos:
		cmp $0, %r13
		jne mul_op_ret_min
		push $0
		jmp end_op

div_op:
	cmp $2, %r8
	jl invalid_statement_error

	pop %r14
	pop %rbx
	cmp $0, %rbx
	je div_zero_error
	pop %r13
	pop %rax
	xor %rdx, %rdx
	div %rbx
	push %rax

	cmp $0, %r14
	je div_op_first_pos
	cmp $0, %r13
	je div_op_ret_min
	push $0

	jmp end_op

	div_op_ret_min:
		push $1
		jmp end_op

	div_op_first_pos:
		cmp $0, %r13
		jne div_op_ret_min
		push $0
		jmp end_op

mod_op:
	cmp $2, %r8
	jl invalid_statement_error

	pop %r14
	pop %rbx
	pop %r13
	pop %rax
	xor %rdx, %rdx

	cmp $0, %r14
	jne mod_op_first_neg

	cmp $0, %r13
	jne mod_op_sec_neg_first_pos

	mod_op_with_plus:
		div %rbx
		push %rdx
		push $0
		jmp end_op

	mod_op_first_neg:
		cmp $0, %r13
		jne mod_op_with_neg
		mod_op_sub_sec:
			cmp %rbx, %rax
			jle mod_op_sub_minus
			sub %rbx, %rax
			jmp mod_op_sub_sec

	mod_op_sec_neg_first_pos:
		cmp %rbx, %rax
		jle mod_op_sub_plus
		sub %rbx, %rax
		jmp mod_op_sec_neg_first_pos

	mod_op_sub_plus:
		sub %rax, %rbx
		push %rbx
		push $0
		jmp end_op

	mod_op_sub_minus:
		sub %rax, %rbx
		push %rbx
		push $1
		jmp end_op

	mod_op_with_neg:
		div %rbx
		push %rdx
		push $1
		jmp end_op

output:
	cmp $1, %r9
	jne empty_statement_error
	cmp $1, %r8
	jne invalid_statement_error
	pop %r15
	pop %rax
	call print_dec
	call newline
	call exit

parsing_atom_error:
	mov $parsing_atom_error_msg, %rax
	mov $parsing_atom_error_len, %rbx
	call error
	ret

empty_statement_error:
	mov $empty_statement_error_msg, %rax
	mov $empty_statement_error_len, %rbx
	call error
	ret

invalid_statement_error:
	mov $invalid_statement_error_msg, %rax
	mov $invalid_statement_error_len, %rbx
	call error
	ret

div_zero_error:
	mov $div_zero_error_msg, %rax
	mov $div_zero_error_msg_len, %rbx
	call error
	ret

.data
	parsing_atom_error_msg:
		.ascii "Atom contains incorrect char\n"
		.set parsing_atom_error_len, . - parsing_atom_error_msg 
	empty_statement_error_msg:
		.ascii "Statement shouldn't be empty\n"
		.set empty_statement_error_len, . - empty_statement_error_msg 
	invalid_statement_error_msg:
		.ascii "Statement is invalid\n"
		.set invalid_statement_error_len, . - invalid_statement_error_msg
	div_zero_error_msg:
		.ascii "Can't divide to zero\n"
		.set div_zero_error_msg_len, . - div_zero_error_msg

