.global read_int
.text

.set x, 120
.set space, 32
.set minus_char, 45
.set newline_char, 10
.set abs_char, 124
.set sign_char, 60
.set sign_end_char, 62

# read int from rax and stdin
# abs in rax
# sign in r15
read_int:
	xor %rbx, %rbx
	mov %al, %bl
	mov %rbx, %rax

_read_int:
	cmpb $minus_char, %al
	je add_minus
	cmpb $abs_char, %al
	je abs_op
	cmpb $sign_char, %al
	je sign_op
	xor %r15, %r15

read_unsigned_int:
	cmpb $48, %al
	jne read_dec
	call read
	cmpb $space, %al
	je return_zero
	cmpb $0, %al
	je end_char_zero
	cmpb $newline_char, %al
	je end_char_zero
	cmpb $sign_end_char, %al
	je return_zero_r
	cmpb $abs_char, %al
	je return_zero_r
	cmpb $x, %al
	je read_hex
	cmpb $58, %al
	jl read_dec
	call parsing_operand_error

end_char_zero:
	mov $1, %r10
	jmp return_zero

return_zero_r:
	call read
	jmp return_zero

add_minus:
	mov $1, %r15
	call read
	jmp read_unsigned_int

abs_op:
	call read
	cmpb $minus_char, %al
	je skip_minus
	jmp read_unsigned_int

skip_minus:
	call read
	jmp read_unsigned_int

sign_op:
	call read
	call _read_int
	cmpb $0, %al
	je return_zero
	mov $1, %rax
	ret

return_minus:
	mov $1, %r15
	mov $1, %rax
	ret

return_zero:
	xor %rax, %rax
	xor %rbx, %rbx
	ret

read_dec:
	mov $10, %r14
	xor %r12, %r12
	mov $1, %r13
	call read_common
	ret

read_hex:
	mov $16, %r14
	xor %r12, %r12
	mov $1, %r13
	call read
	call read_common
	ret

read_common:
	call parse_num	
	push %rax
	inc %r12
	call read
	cmpb $space, %al
	je end_read
	cmpb $newline_char, %al
	je end_read_f
	cmpb $0, %al
	je end_read_f
	cmpb $abs_char, %al
	je end_read_r
	cmpb $sign_end_char, %al
	je end_read_r
	jmp read_common

end_read_f:
	mov $1, %r10
	jmp end_read

end_read_r:
	call read
	jmp end_read

end_read:
	xor %rax, %rax

collect:
	pop %rbx
	imul %r13, %rbx
	imul %r14, %r13
	add %rbx, %rax
	dec %r12
	cmp $0, %r12
	jne collect
	ret

parse_num:
	cmpb $58, %al
	jl parse_dec_num
	cmp $16, %r14
	jne hex_in_dec_error
	cmpb $64, %al
	jg parse_hex_num

parse_dec_num:
	cmpb $47, %al
	jg parse_dec_sub
	call parsing_operand_error
	ret

parse_dec_sub:
	sub $48, %rax
	ret

parse_hex_num:
	cmpb $71, %al
	jl parse_hex_sub
	call parsing_operand_error
	ret

parse_hex_sub:
	sub $55, %rax
	ret

parsing_operand_error:
	mov $parsing_operand_error_msg, %rax
	mov $parsing_operand_error_msg_len, %rbx
	call error
	ret

hex_in_dec_error:
	mov $hex_in_dec_error_msg, %rax
	mov $hex_in_dec_error_len, %rbx
	call error
	ret

.data
	parsing_operand_error_msg:
		.ascii "Operand contains incorrect char\n"
		.set parsing_operand_error_msg_len, . - parsing_operand_error_msg
	hex_in_dec_error_msg:
		.ascii "Hex symbols in dec number\n"
		.set hex_in_dec_error_len, . - hex_in_dec_error_msg 
