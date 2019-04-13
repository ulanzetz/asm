; Prints to stdout SCAN_CODE, ASCII_CODE, ASCII_CHAR while not ESC key.

.model tiny

space_char equ ' '
esc_scan_code equ 01h

CR equ 0Dh

LF equ 0Ah

.data
	hex_chars db "0123456789ABCDEF"

.code
.radix 16
org 100

start:
	xor ax, ax
	int 16h
	cmp ah, esc_scan_code
	je exit

	mov dh, al
	mov al, ah

	call print_hex
	
	mov al, space_char
	call print_char
	
	mov al, dh
	call print_hex
	
	mov al, space_char
	call print_char
	
	mov al, dh
	call print_char
	
	mov al, CR
	call print_char

	mov al, LF
	call print_char
	
	jmp start

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
	mov ax, 4c00h
	int 21h
	ret	

end start
