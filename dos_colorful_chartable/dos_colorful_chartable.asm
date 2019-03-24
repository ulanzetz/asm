.model tiny

start_row_small equ 04h

start_row_big equ 16h

start_column_small equ 04h

start_column_big equ 04h

esc_scan_code equ 1bh

default_color equ 0fh

.data
	help_msg db "Usage: video.com [MODE] [PAGE]", 0Dh, 0Ah, "Mode should be in range 0-3", 0Dh, 0Ah, "Page should be in range 0-7 for 0 and 1 modes, in range 0-3 for 2 and 3 modes", 0Dh, 0Ah, "$"

	mode_number db 0
	
	page_number db 0

	ctx_mode db 0

	ctx_page db 0

	start_row db 0

	color_state db 0fh

	font_state db 00h

	last_column db 00h
.code
.radix 16
org 100

start:
	; check arguments size
	mov al, ds:[80h] 
	cmp al, 4h
	jne help

	; check spaces
	mov al, ds:[81h] 
	cmp al, 20h
	jne help
	mov al, ds:[83h]
	cmp al, 20h
	jne help

	; read mode and page
	mov al, ds:[82h]
	sub al, 30h
	cmp al, 3h
	jg help
	mov [mode_number], al
	mov bl, ds:[84h]
	sub bl, 30h
	cmp bl, 7h
	jg help
	mov [page_number], bl
	cmp al, 2h
	jl setup
	cmp bl, 3h
	jg help
	jmp setup

help:
	mov dx, offset help_msg
	mov ah, 09h
	int 21h

exit:
	mov ax, 4c00h
	int 21h
	ret

setup:
	; save context
	mov ah, 0fh
	int 10h
	mov [ctx_mode], al
	mov [ctx_page], bh

	; set mode
	xor ah, ah
	mov al, [mode_number]
	int 10h

	; set page
	mov ah, 05h
	mov al, [page_number]
	int 10h

	; set cursor to start pos
	mov bh, [page_number]
	mov al, [mode_number]
	cmp al, 02h
	jl set_small_start_column
	mov [start_row], start_row_big
	mov dh, start_column_big
	jmp call_set_cursor
	
	set_small_start_column:
		mov [start_row], start_row_small
		mov dh, start_column_small
	
	call_set_cursor:
		mov dl, start_row
		mov ah, 02h
		int 10h

	mov cx, 0101h
	; row in cl, column in ch
	xor ax, ax

print_loop:
	cmp cl, 11h
	je new_column
	call print_char
	inc cl
	inc ax
	add dl, 2h
	jmp print_loop

	new_column:
		cmp ch, 10h
		je last_print
		inc ch
		inc dh
		mov cl, 01h
		mov dl, start_row
		jmp print_loop

	print_char:
		push cx
		push ax
		
		; print_char
		mov ah, 09h
		call set_color
		mov cx, 0001h
		int 10h

		; set_pos
		mov ah, 02h
		int 10h

		pop ax		
		pop cx
		ret

	last_print:
		call print_char

wait_for_esc:
	xor ax, ax
	int 16h
	cmp al, esc_scan_code
	jne wait_for_esc

return_ctx:
	mov ah, 05h
	mov al, [ctx_page]
	int 10h

	xor ah, ah
	mov al, [ctx_mode]
	int 10h

	jmp exit

set_color:
	cmp ch, 01h
	je color_and_font
	cmp ch, 03h
	je only_font
	cmp ch, 10h
	jge color_and_font_and_blink
	mov bl, default_color
	ret

	color_and_font_and_blink:
		cmp [last_column], 02h
		jl set_first_blink_state
		jmp color_and_font

		set_first_blink_state:
			cmp [last_column], 01h
			jne continue
			mov [font_state], 90h
			mov [last_column], 02h
			jmp color_and_font
			continue:
				mov [last_column], 01h
				mov bl, default_color
				mov [color_state], 0fh
				ret

	color_and_font:
		mov bl, [color_state]
		add bl, [font_state]
		dec [color_state]
		jmp set_font_state

	only_font:
		mov bl, default_color
		add bl, [font_state]
	 	
	set_font_state:
		cmp [font_state], 70h
		je reset_font
		cmp [font_state], 0f0h
		je reset_blink_font
		add [font_state], 10h
		ret
		reset_font:
			mov [font_state], 00h
			ret
		reset_blink_font:
			mov [font_state], 90h
			ret
end start