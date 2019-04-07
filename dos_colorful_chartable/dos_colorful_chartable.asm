.model tiny

system_segment equ 0040h

start_video_offset equ 4eh

row_count_offset equ 4ah

column_count_offset equ 84h

esc_scan_code equ 1bh

enter_scan_code equ 0dh

default_color equ 0fh

b_char equ 'b'

b_cap_char equ 'B'

m_char equ 'm'

m_cap_char equ 'M'

p_char equ 'p'

p_cap_char equ 'P'

space_char equ ' '

slash_char equ '/'

min_char equ '-'

wait_key equ 0h

wait_mode equ 1h

wait_page equ 2h

symbols_in_column equ 20h

ctx_line_msg_len equ 8h

.data
	help_msg db "Usage: video.com /m [MODE] /p [PAGE] {/b}", 0Dh, 0Ah, "Mode should be in range 0-3 or 7", 0Dh, 0Ah, "Page should be in range 0-7", 0Dh, 0Ah, "Optional /b flag for global blink mode", 0Dh, 0Ah, "$"

	mode_number db 9
	
	page_number db 9

	ctx_mode db 0

	ctx_page db 0

	newline_shift dw 0

	color_state db 0fh

	font_state db 00h

	last_column db 00h

	global_blink db 00h

	video_offset dw 00h

	video_segment dw 0b800h
.code
.radix 16
org 100

start:
	mov ch, ds:[80h]
	mov di, 81h
	mov ah, wait_key
	
	parse_loop:
		cmp ch, 0h
		je check_and_setup
		mov al, ds:[di]
		inc di
		dec ch

		cmp al, space_char
		je parse_loop

		cmp al, slash_char
		je parse_loop

		cmp al, min_char
		je parse_loop

		cmp ah, wait_key
		je parse_key

	parse_arg:
		cmp ah, wait_mode
		je mode_parse
		cmp ah, wait_page
		je page_parse
		jmp help; should never happen

	parse_key:
		cmp al, m_char
		je set_mode_parse
		cmp al, m_cap_char
		je set_mode_parse
		cmp al, p_char
		je set_page_parse
		cmp al, p_cap_char
		je set_page_parse
		cmp al, b_char
		je blink_parse
		cmp al, b_cap_char
		je blink_parse
		jmp help

		set_mode_parse:
			mov ah, wait_mode
			jmp parse_loop

		set_page_parse:
			mov ah, wait_page
			jmp parse_loop

		blink_parse:
			mov [global_blink], 1h
			jmp parse_loop

	mode_parse:
		sub al, 30h
		cmp al, 3h
		jg seven_mode
		jmp mode_parse_end

		seven_mode:
			cmp al, 7h
			jne help
			mov [video_segment], 0b000h

		mode_parse_end:
			mov [mode_number], al
			mov ah, wait_key
			jmp parse_loop

	page_parse:
		sub al, 30h
		cmp al, 7h
		jg help
		mov [page_number], al
		mov ah, wait_key
		jmp parse_loop

	check_and_setup:
		cmp [mode_number], 9h
		je exit
		cmp [page_number], 9h
		je exit
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
	mov cx, system_segment
	mov es, cx

	; save context
	mov ah, 0fh
	int 10h
	mov [ctx_mode], al
	mov [ctx_page], bh

	mov bl, al
	mov ax, es:[row_count_offset]
	mov di, es:[start_video_offset]
	call print_ctx
	
	wait_for_enter:
		xor ax, ax
		int 16h
		cmp al, enter_scan_code
		jne wait_for_enter

	mov cx, system_segment
	mov es, cx

	; set mode
	xor ah, ah
	mov al, [mode_number]
	int 10h

	; set page
	mov ah, 05h
	mov al, [page_number]
	int 10h

	; set blink flag
	mov ax, 1003h
	mov bl, [global_blink]
	xor bh, bh
	int 10h
	
	xor cx, cx
	mov cl, es:[column_count_offset]
	sub cl, 4h
	mov ax, es:[row_count_offset]
	mov bx, ax
	sar ax, 1h
	mul cx
	mov cx, es:[start_video_offset]

	push ax
	push bx
	push cx

	mov ax, bx
	mov di, cx
	mov bl, [mode_number]
	mov bh, [page_number]
	call print_ctx

	pop cx
	pop bx
	pop ax

	add ax, cx
	sub bx, symbols_in_column
	add ax, bx
	sal bx, 1h
	mov [newline_shift], bx
	mov [video_offset], ax

	mov cx, 0101h
	; row in cl, column in ch
	xor ax, ax
	jmp print_loop

; bl - mode, bh - page, di - start_offset, ax - rows 
print_ctx:
	mov cx, [video_segment]
	mov es, cx
	mov cx, ax
	sal cx, 1h
	push di
	sub ax, ctx_line_msg_len
	add di, ax

	mov byte ptr es:[di], 'M'
	add di, 2
	mov byte ptr es:[di], 'O'
	add di, 2
	mov byte ptr es:[di], 'D'
	add di, 2
	mov byte ptr es:[di], 'E'
	add di, 2
	mov byte ptr es:[di], ':'
	add di, 2
	add bl, 30h
	mov es:[di], bl

	pop di
	add di, cx
	add di, ax

	mov byte ptr es:[di], 'P'
	add di, 2
	mov byte ptr es:[di], 'A'
	add di, 2
	mov byte ptr es:[di], 'G'
	add di, 2
	mov byte ptr es:[di], 'E'
	add di, 2
	mov byte ptr es:[di], ':'
	add di, 2
	add bh, 30h
	mov es:[di], bh
	
	ret

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
		je wait_for_esc
		inc ch
		inc dh
		mov cl, 01h
		mov bx, [newline_shift]
		add [video_offset], bx
		jmp print_loop

	print_char:
		push cx
		push ax
		push es
		push di
		
		; print_char
		call set_color
		mov ah, bl
		mov cx, [video_segment]
		mov es, cx
		mov di, [video_offset]
		mov es:[di], ax

		; set_pos
		add [video_offset], 4h

		pop di
		pop es
		pop ax		
		pop cx
		ret

wait_for_esc:
	xor ax, ax
	int 16h
	cmp al, esc_scan_code
	jne wait_for_esc

return_ctx:
	xor ah, ah
	mov al, [ctx_mode]
	int 10h

	mov ah, 05h
	mov al, [ctx_page]
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