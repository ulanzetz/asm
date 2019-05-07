.model tiny

esc_scan_code equ 01h

system_segment equ 0040h

rect_width equ 150h
rect_height equ 100h
rect_border equ 5h

circle_radius equ 10h

x_delta equ 8h
y_delta equ 8h

min_rect_color equ 1h
max_rect_color equ 4h

min_circle_color equ 5h
max_circle_color equ 9h

screen_width equ 640
screen_height equ 480

.data
	ctx_mode db 0
	ctx_page db 0

	old_rect_x dw 90h
	old_rect_y dw 60h

	rect_x dw 90h
	rect_y dw 60h
	rect_color db min_rect_color

	old_circle_x dw 90h
	old_circle_y dw 60h

	circle_x dw 90h
	circle_y dw 60h
	circle_color db min_circle_color

	mouse_x dw 90h
	mouse_y dw 60h

	is_redraw_rect db 0h

	is_redraw_circle db 0h

	handler_semaphore db 0h

	curr_page db 0h
.code
.radix 16
org 100


start:
	mov cx, system_segment
	mov es, cx

	; save context
	mov ah, 0fh
	int 10h
	mov [ctx_mode], al
	mov [ctx_page], bh

	; change video mode
	mov ah, 00h
	mov al, 12h
	int 10h

	mov [is_redraw_circle], 1h
	mov [is_redraw_rect], 1h
	call redraw

	mov [is_redraw_circle], 0h
	mov [is_redraw_rect], 0h

	; initialize mouse cursor
	xor ax, ax
	int 33h
	mov ax, 0001h
	int 33h

	; set mouse handler
	push cs
	pop es
	mov ax, 0ch
	mov cx, 10111b; move, left, right buttons down
	mov dx, offset mouse_handler
	int 33h

	mov ax, 04h
	mov cx, [mouse_x]
	mov dx, [mouse_y]
	int 33h

wait_for_esc:
	xor ax, ax
	int 16h
	cmp ah, esc_scan_code
	jne wait_for_esc
	jmp exit

exit:
	; reset mouse handler
	mov ax, 0ch
    xor cx, cx
    int 33h

	; return mode and page
	xor ah, ah
	mov al, [ctx_mode]
	int 10h

	mov ah, 05h
	mov al, [ctx_page]
	int 10h

	mov ax, 4c00h
	int 21h
	ret

mouse_handler:
	push ax
	push bx
	push cx
	push dx
	push si
	push di

	cmp [handler_semaphore], 0h
	jne mouse_handler_exit
	mov [handler_semaphore], 1h

	cmp ax, 1b
	je movement_handler
	cmp ax, 10000b
	je change_color_handler
	jmp mouse_handler_end

	movement_handler:
		cmp bx, 1b
		je rect_move_handler
		call circle_move
		jmp mouse_handler_end

	rect_move_handler:
		call rect_move
		jmp mouse_handler_end

	change_color_handler:
		mov ah, 0dh
		mov bh, [curr_page]
		int 10h
		cmp al, [circle_color]
		je change_circle_color
		mov [is_redraw_rect], 1h
		inc [rect_color]
		cmp [rect_color], max_rect_color
		jg minimize_rect_color
		jmp mouse_handler_end

	minimize_rect_color:
		mov [rect_color], min_rect_color
		jmp mouse_handler_end

	change_circle_color:
		mov [is_redraw_circle], 1h
		inc	[circle_color]
		cmp [circle_color], max_circle_color
		jg minimize_circle_color
		jmp mouse_handler_end

	minimize_circle_color:
		mov [circle_color], min_circle_color
		jmp mouse_handler_end

	mouse_handler_end:
		call redraw
		mov [mouse_x], cx
		mov [mouse_y], dx
		mov [is_redraw_circle], 0h
		mov [is_redraw_rect], 0h
		mov [handler_semaphore], 0h

	mouse_handler_exit:
		pop di
		pop si
		pop dx
		pop cx
		pop bx
		pop ax
		retf

; cx - new mouse x, dx - new mouse y 
circle_move:
	push ax
	mov ax, [circle_x]
	mov [old_circle_x], ax
	mov ax, [circle_y]
	mov [old_circle_y], ax
	call calc_move_delta

	circle_move_dx:
		mov ax, [rect_x]
		cmp [circle_x], ax
		je continue_circle_move_dx
		add ax, rect_width
		cmp [circle_x], ax
		je continue_circle_move_dx
	
	circle_move_cx:
		mov ax, [rect_y]
		cmp [circle_y], ax
		je continue_circle_move_cx
		add ax, rect_height
		cmp [circle_y], ax
		je continue_circle_move_cx
		jmp circle_move_end

	continue_circle_move_cx:
		add [circle_x], cx
		
		mov ax, [rect_x]
		cmp [circle_x], ax
		jle set_circle_x_ax

		add ax, rect_width
		cmp [circle_x], ax
		jge set_circle_x_ax
		jmp circle_move_end

	set_circle_x_ax:
		mov [circle_x], ax
		jmp circle_move_end

	continue_circle_move_dx:
		add [circle_y], dx

		mov ax, [rect_y]
		cmp [circle_y], ax
		
		jle set_circle_y_ax
		
		add ax, rect_height
		cmp [circle_y], ax
		jge set_circle_y_ax
		jmp circle_move_end

	set_circle_y_ax:
		mov [circle_y], ax
		jmp circle_move_cx

	circle_move_end:
		mov [is_redraw_circle], 1h
		pop ax
		ret

; cx - new mouse x, dx - new mouse y 
rect_move:
	push ax
	mov ax, [rect_x]
	mov [old_rect_x], ax
	mov ax, [rect_y]
	mov [old_rect_y], ax
	mov ax, [circle_x]
	mov [old_circle_x], ax
	mov ax, [circle_y]
	mov [old_circle_y], ax

	call calc_move_delta
	
	add [rect_x], cx

	mov ax, [old_rect_x]
	cmp [circle_x], ax
	je try_min_by_circle

	cmp [rect_x], rect_border
	jl minimize_rect_x
	cmp [rect_x], screen_width - rect_width - rect_border
	jg maximize_rect_x

	jmp rect_move_set_y

	try_min_by_circle:
		cmp [rect_x], circle_radius
		jg rect_move_set_y
		mov [rect_x], circle_radius
		jmp rect_move_set_y

	minimize_rect_x:
		mov [rect_x], rect_border
		jmp rect_move_set_y

	maximize_rect_x:
		mov [rect_x], screen_width - rect_width - rect_border
		jmp rect_move_set_y

	rect_move_set_y:
		add [rect_y], dx

		mov ax, [old_rect_y]
		add ax, rect_height
		cmp [circle_y], ax
		je try_max_by_circle

		cmp [rect_y], rect_border
		jl minimize_rect_y
		
		cmp [rect_y], screen_height - rect_height - rect_border
		jg maximize_rect_y
		jmp rect_move_circle

	try_max_by_circle:
		cmp [rect_y], screen_height - rect_height - circle_radius
		jl rect_move_circle
		mov [rect_y], screen_height - rect_height - circle_radius
		jmp rect_move_circle

	minimize_rect_y:
		mov [rect_y], rect_border
		jmp rect_move_circle

	maximize_rect_y:
		mov [rect_y], screen_height - rect_height - rect_border
		jmp rect_move_circle 
	
	rect_move_circle:
		mov cx, [rect_x]
		sub cx, [old_rect_x]
		add [circle_x], cx
		mov dx, [rect_y]
		sub dx, [old_rect_y]
		add [circle_y], dx
		mov [is_redraw_rect], 1h
		mov [is_redraw_circle], 1h
		pop ax
		ret

; in - cx - new mouse x, dx - new mouse y
; out - cx - delta x, dx - delta y
calc_move_delta:
	push ax
	sub cx, [mouse_x]
	cmp cx, 1h
	jge norm_plus_cx
	cmp cx, -1h
	jle norm_min_cx
	xor cx, cx
	jmp start_dx

	norm_plus_cx:
		mov cx, 1h
		jmp start_dx

	norm_min_cx:
		mov cx, -1h
		jmp start_dx

	start_dx:
		sub dx, [mouse_y]
		cmp dx, 1h
		jge norm_plus_dx
		cmp dx, -1h
		jle norm_min_dx
		xor dx, dx
		jmp mul_delta

	norm_plus_dx:
		mov dx, 1h
		jmp mul_delta

	norm_min_dx:
		mov dx, -1h
		jmp mul_delta

	mul_delta:
		push dx
		mov ax, x_delta
		mul cx
		mov cx, ax
		pop dx
		mov ax, y_delta
		mul dx
		mov dx, ax
		pop ax
		ret

redraw:
	cmp [is_redraw_rect], 0h
	jne redraw_rect
	jmp draw_rect_redraw

	redraw_rect:
		xor al, al
		mov cx, [old_rect_x]
		mov dx, [old_rect_y]
		mov bx, rect_width
		mov si, rect_height
		mov di, rect_border
		call draw_rect
	
	draw_rect_redraw:
		mov al, [rect_color]
		mov cx, [rect_x]
		mov dx, [rect_y]
		mov bx, rect_width
		mov si, rect_height
		mov di, rect_border
		call draw_rect

		cmp [is_redraw_circle], 0h
		je redraw_circle
	
		xor al, al
		mov cx, [old_circle_x]
		mov dx, [old_circle_y]
		call draw_circle

	redraw_circle:
		mov al, [circle_color]
		mov cx, [circle_x]
		mov dx, [circle_y]
		call draw_circle

	redraw_end:
		ret

; al - color, cx - left top x, dx - left top y, bx - x length, si - y length, di - border width
draw_rect:
	push di

	top_hor_loop:
		cmp di, 0h
		jle top_hor_end
		call draw_hor_line
		dec di
		inc dx
		jmp top_hor_loop

	top_hor_end:
		pop di
		push di
		sub dx, di
		add dx, si
	
	low_hor_loop:
		cmp di, 0h
		jle low_hor_end
		call draw_hor_line
		dec di
		inc dx
		jmp low_hor_loop

	low_hor_end:
		pop di
		push di
		sub dx, di
		sub dx, si
		xchg bx, si

	left_ver_loop:
		cmp di, 0h
		jle left_ver_end
		call draw_ver_line
		dec di
		inc cx
		jmp left_ver_loop

	left_ver_end:
		pop di
		push di
		sub cx, di
		add cx, si
		add bx, di

	right_ver_loop:
		cmp di, 0h
		jle right_ver_end
		call draw_ver_line
		dec di
		inc cx
		jmp right_ver_loop

	right_ver_end:
		pop di
	ret
; al - color, cx - x of center, dx - y of center
draw_circle:
	; (si, di) - center
	mov si, cx
	mov di, dx

	; (cx, dx) - loop cord
	sub cx, circle_radius
	sub dx, circle_radius

	x_loop:
		add si, circle_radius
		cmp si, cx
		je draw_cicle_end
		sub si, circle_radius
		y_loop:
			add di, circle_radius
			cmp di, dx
			je y_loop_end
			sub di, circle_radius
			push ax
			call euсlid_distance_sqaure
			cmp ax, circle_radius * circle_radius
			jl draw_circle_pixel
			pop ax

			y_loop_next:
				inc dx
				jmp y_loop

			draw_circle_pixel:
				pop ax
				call draw_pixel
				jmp y_loop_next

		y_loop_end:
			sub di, circle_radius
			inc cx
			mov dx, di
			sub dx, circle_radius
			jmp x_loop

	draw_cicle_end:
		ret

; ret (si, di), (cx, dx) distance sqaure in ax
euсlid_distance_sqaure:
	push si
	push di
	push cx
	push dx

	cmp si, cx
	jl left_x
	sub si, cx
	jmp start_y
	
	left_x:
		sub cx, si
		mov si, cx

	start_y:
		cmp di, dx
		jl left_y
		sub di, dx
		jmp calc

	left_y:
		sub dx, di
		mov di, dx

	calc:
		mov ax, si
		imul si
		mov si, ax
		mov ax, di
		imul di
		add ax, si

	pop dx
	pop cx
	pop di
	pop si

	ret

; al - color, dx - y, cx - start x; bx - length
draw_hor_line:
	push ax
	push bx
	push cx
	push dx
	draw_hor_line_loop:
		cmp bx, 0h
		je draw_hor_line_end
		call draw_pixel
		inc cx
		dec bx
		jmp draw_hor_line_loop

	draw_hor_line_end:
		pop dx
		pop cx
		pop bx
		pop ax
		ret

; al - color, cx - x, dx - start y; bx - length
draw_ver_line:
	push ax
	push bx
	push cx
	push dx
	draw_ver_line_loop:
		cmp bx, 0h
		je draw_ver_line_end
		call draw_pixel
		inc dx
		dec bx
		jmp draw_ver_line_loop

	draw_ver_line_end:
		pop dx
		pop cx
		pop bx
		pop ax
		ret

; al - color, cx - x, dx - y
draw_pixel:
	push ax
	push bx
	mov bh, [curr_page]
	mov ah, 0ch
	int 10h

	pop bx
	pop ax
	ret

end start