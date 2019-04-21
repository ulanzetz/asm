.model tiny

space_char equ ' '
esc_scan_code equ 01h

CR equ 0Dh

LF equ 0Ah

buff_len equ 4h

.data
	hex_chars db "0123456789ABCDEF"
	buffer db buff_len dup(0)
	original_9h dd 0h
	buff_head db 0h
	buff_tail db 0h
.code
.radix 16
org 100

start:
	mov ax, 3509h
	int 21h
	mov word ptr original_9h, bx
	mov word ptr original_9h + 2, es

	mov ax, 2509h
	mov dx, offset int9h_handler
	int 21h

_loop:
	call read_key
	cmp ah, 0h
	je _loop
	cmp al, esc_scan_code
	je exit

	call print_hex
		
	mov al, CR
	call print_char

	mov al, LF
	call print_char
	
	jmp _loop

; al - byte to print 
print_hex:
	lea bx, hex_chars
	
	mov cl, al
	shr al, 4h
	xlat
	call print_char
	
	mov al, cl
	and al, 0fh
	xlat
	call print_char
	
	ret

; al - char to print
print_char:
	mov dl, al
	mov ah, 02h
	int 21h
	ret

exit:
	mov ax, 2509h
	mov dx, word ptr original_9h
	mov bx, word ptr original_9h + 2
	push ds
	mov ds, bx
	int 21h
	pop ds

	mov ax, 4c00h
	int 21h
	ret

int9h_handler:
	push ax

	in al, 60h
	call write_key

	in al, 61h
	mov ah, al
	or al, 80h
	out 61h, al
	xchg ah, al
	out 61h, al
	mov al, 20h
	out 20h, al

	pop ax
	iret

; ah - 0 if empty, al - scan_code if is not empty
read_key:
	push bx
	mov bl, [buff_head]
	mov bh, [buff_tail]
	cmp bl, bh
	je empty_read
	xor bh, bh
	mov al, [buffer + bx]
	inc bl
	cmp bl, buff_len
	je head_reset
	jmp read_key_end

	empty_read:
		xor ah, ah
		jmp read_key_exit

	head_reset:
		xor bl, bl

	read_key_end:
		mov ah, 01h
		mov [buff_head], bl

	read_key_exit:

	pop bx
	ret

; al - scan_code to write
write_key:
	push bx
	xor bx, bx
	mov bl, [buff_tail]
	mov [buffer + bx], al
	inc bl
	cmp bl, buff_len
	je tail_reset
	jmp write_key_end

	tail_reset:
		xor bl, bl

	write_key_end:
		mov [buff_tail], bl

	pop bx
	ret


end start