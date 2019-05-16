.model tiny

esc_scan_code equ 01h
space_scan_code equ 39h
w_scan_code equ 11h
a_scan_code equ 1eh
s_scan_code equ 1fh
d_scan_code equ 20h
minus_scan_code equ 0ch
plus_scan_code equ 0dh
f1_scan_code equ 3bh

snake_unit_size equ 20d
wall_width equ 20d

snake_max_len equ 30h

key_buff_len equ 4h

min_snake_delay equ 1h
max_snake_delay equ 10h

death_wall_color equ 12d
portal_wall_color equ 2h
switch_wall_color equ 3h

left_wall_color equ death_wall_color
right_wall_color equ portal_wall_color
bottom_wal_color equ switch_wall_color

none_intersect equ 0h
death_intersect equ 1h
cut_intersect equ 2h

screen_width equ 640d
screen_height equ 480d

circle_radius equ 10d

apple_color equ 4h

cut_color equ 6h

death_color equ 12d

width_cells equ 31d

height_cells equ 23d

apple_freq equ 7902d
cut_freq equ 4978d

death_song_len equ 7d

.data
	ctx_mode db 0h
	ctx_page db 0h

	curr_page db 0h

	snake_len db 5h
	snake_buff dw snake_max_len * 8 dup(0)

	snake_x_dir dw 0h
	snake_y_dir dw snake_unit_size

	snake_start_x dw 100d
	snake_start_y dw 300d

	old_tail_x dw 0h
	old_tail_y dw 0h

	snake_color db 5h

	paused db 1h

	speed db 5h

	key_buffer db key_buff_len dup(0)
	original_9h dd 0h
	key_buff_head db 0h
	key_buff_tail db 0h

	snake_delay db 5h
	current_snake_delay db 0h

	top_wall_color db switch_wall_color

	intersect_mode db none_intersect

	apple_x dw 200d
	apple_y dw 200d

	sec_apple_x dw 200d
	sec_apple_y dw 200d

	cut_x dw 300d
	cut_y dw 400d

	death_x dw 500d
	death_y dw 100d

	max_snake_len db 0h

	score db 0h

	exit_by_key db 0h

	help_msg db "Usage: snake {/h} {/t [S|D|P]} {/i [N|D|C]} {/l [LENGTH]} {/a [APPLES]}", 0Dh, 0Ah, "/h - for help", 0Dh, 0Ah, "/t for top-wall type (D - Death, S - Switch, P - Portal). Switch by default", 0Dh, 0Ah, "/i for intersect mode (N - None, D - Death, C - Cut). None by default", 0Dh, 0Ah, "/l for snake start length (2 - 9), 5 by default", 0Dh, 0Ah, "/a for apples start count (1-2). 1 by default", 0Dh, 0Ah, "$"

	game_help_msg db "Control:", 0Dh, 0Ah, "W-A-S-D for moving", 0Dh, 0Ah, "+- to control speed", 0Dh, 0Ah, "Space to pause", 0Dh, 0Ah, "Esc for exit", 0Dh, 0Ah, "Press any key to continue game", 0Dh, 0Ah, "$"

	game_over_msg db "             Game Over", 0Dh, 0Ah

	score_msg db "Score: $"

	length_msg db "Length: $"

	max_length_msg db "Max length: $"

	newline db 0Dh, 0Ah, "$"

	final_msg db "Good luck in new game$"

	death_song dw 2637, 24, 2093, 12, 2637, 12, 3136, 12, 2637, 24, 1760, 12, 2637, 14 
.code
.radix 16
org 100

start:
	xor bl, bl
	mov ch, ds:[80h]
	mov di, 81h

	parse_loop:
		cmp ch, 0h
		je _init_game
		mov al, ds:[di]
		inc di
		dec ch

		cmp al, ' '
		je parse_loop

		cmp al, '/'
		je parse_loop

		cmp al, '-'
		je parse_loop

		cmp bl, 0h
		jne parse_arg

		cmp al, 'h'
		je help

		cmp al, 't'
		je set_t_parsing

		cmp al, 'i'
		je set_i_parsing

		cmp al, 'l'
		je set_l_parsing

		cmp al, 'a'
		je set_a_parsing

		jmp help

	help:
		mov dx, offset help_msg
		mov ah, 09h
		int 21h

		call direct_exit

	_init_game:
		jmp init_game

	set_t_parsing:
		mov bl, 't'
		jmp parse_loop

	set_i_parsing:
		mov bl, 'i'
		jmp parse_loop

	set_l_parsing:
		mov bl, 'l'
		jmp parse_loop

	set_a_parsing:
		mov bl, 'a'
		jmp parse_loop

	parse_arg:
		cmp bl, 't'
		je t_arg_parse
		cmp bl, 'i'
		je i_arg_parse
		cmp bl, 'l'
		je l_arg_parse
		cmp bl, 'a'
		je a_arg_parse

		jmp help

	t_arg_parse:
		cmp al, 'S'
		je t_arg_switch
		cmp al, 'D'
		je t_arg_death
		cmp al, 'P'
		je t_arg_portal
		jmp help

		t_arg_switch:
			mov [top_wall_color], switch_wall_color
			xor bl, bl
			jmp parse_loop

		t_arg_death:
			mov [top_wall_color], death_wall_color
			xor bl, bl
			jmp parse_loop

		t_arg_portal:
			mov [top_wall_color], portal_wall_color
			xor bl, bl
			jmp parse_loop

	help_jump:
		jmp help

	i_arg_parse:
		cmp al, 'N'
		je i_arg_none
		cmp al, 'D'
		je i_arg_death
		cmp al, 'C'
		je i_arg_cut
		jmp help

		i_arg_none:
			mov [intersect_mode], none_intersect
			xor bl, bl
			jmp parse_loop

		i_arg_death:
			mov [intersect_mode], death_intersect
			xor bl, bl
			jmp parse_loop

		i_arg_cut:
			mov [intersect_mode], cut_intersect
			xor bl, bl
			jmp parse_loop

	l_arg_parse:
		sub al, 30h
		cmp al, 9h
		jg help_jump
		cmp al, 3h
		jl help_jump
		mov [snake_len], al
		xor bl, bl 
		jmp parse_loop

	a_arg_parse:
		sub al, 30h
		cmp al, 2h
		jg help_jump
		cmp al, 1h
		jl help_jump
		cmp al, 1h
		je remove_sec_apple
		jmp a_arg_parse_end

		remove_sec_apple:
			mov [sec_apple_x], 0h
			mov [sec_apple_y], 0h

		a_arg_parse_end:
			xor bl, bl
			jmp parse_loop		

init_game:
	; save page and mode
	mov ah, 0fh
	int 10h
	mov [ctx_mode], al
	mov [ctx_page], bh

	; change video mode
	xor ah, ah
	mov al, 12h
	int 10h

	; save key handler
	mov ax, 3509h
	int 21h
	mov word ptr original_9h, bx
	mov word ptr original_9h + 2, es

	; change key handler
	mov ax, 2509h
	mov dx, offset int9h_handler
	int 21h

	call draw_walls
	call init_snake
	call draw_snake

	call draw_death
	
	call draw_cut

	call new_coords
	mov [apple_x], cx
	mov [apple_y], dx
	call draw_apple

	cmp [sec_apple_x], 0h
	je game_loop
	call new_coords
	mov [sec_apple_x], cx
	mov [sec_apple_y], dx
	call draw_sec_apple

	mov ah, [snake_len]
	mov [max_snake_len], ah

	jmp game_loop

return_to_game:
	xor ah, ah
	mov al, 12h
	int 10h

	call draw_walls
	call draw_snake
	call draw_death
	call draw_cut
	call draw_apple

	cmp [sec_apple_x], 0h
	je return_to_game_ret
	call draw_sec_apple
	return_to_game_ret:
		ret

init_snake:
	mov ax, [snake_start_x]
	mov dx, [snake_start_y]
	xor ch, ch
	xor bx, bx

	init_snake_loop:
		cmp ch, [snake_len]
		je init_snake_end

		mov [snake_buff + bx], ax
		add bx, 2h
		mov [snake_buff + bx], dx
		add bx, 2h

		sub dx, snake_unit_size
		cmp dx, 0h
		jle init_snake_end
		inc ch
		jmp init_snake_loop

	init_snake_end:
		ret

game_loop:
	call read_key
	cmp ah, 0h
	jne key_handler
	
	game_loop_main:	
		call delay
		cmp [paused], 0h
		jne try_update
		jmp game_loop

	try_update:
		mov ah, [snake_delay]
		cmp [current_snake_delay], ah
		je update_snake
		inc [current_snake_delay]
	
	jmp game_loop

update_snake:
	call move_snake
	call check_collisions
	call redraw_snake
	mov [current_snake_delay], 0h
	jmp game_loop

exit:
	; return key handler
	mov ax, 2509h
	mov dx, word ptr original_9h
	mov bx, word ptr original_9h + 2
	push ds
	mov ds, bx
	int 21h
	pop ds

	; return mode and page
	xor ah, ah
	mov al, [ctx_mode]
	int 10h

	mov ah, 05h
	mov al, [ctx_page]
	int 10h

direct_exit:
	mov ax, 4c00h
	int 21h
	ret

return_to_game_jump:
	jmp return_to_game

game_help_handler:
	xor ah, ah
	mov al, 13h
	int 10h

	mov dx, offset game_help_msg
	mov ah, 09h
	int 21h

	gh_wait_for_key:
		call read_key
		cmp ah, 0h
		je gh_wait_for_key

	gh_wait_for_key2:
		call read_key
		cmp ah, 0h
		je gh_wait_for_key2

	call return_to_game
	jmp scan_code_handler_ret

key_handler:
	cmp al, esc_scan_code
	je game_over_jmp

	cmp al, f1_scan_code
	je game_help_handler

	cmp al, w_scan_code
	je w_scan_code_handler

	cmp al, a_scan_code
	je a_scan_code_handler

	cmp al, s_scan_code
	je s_scan_code_handler

	cmp al, d_scan_code
	je d_scan_code_handler

	cmp al, minus_scan_code
	je minus_scan_code_handler

	cmp al, plus_scan_code
	je plus_scan_code_handler

	cmp al, space_scan_code
	je space_scan_code_handler

	jmp game_loop_main

game_over_jmp:
	mov [exit_by_key], 1h
	jmp game_over

plus_scan_code_handler:
	cmp [snake_delay], min_snake_delay
	je scan_code_handler_ret
	dec [snake_delay]
	jmp scan_code_handler_ret

minus_scan_code_handler:
	cmp [snake_delay], max_snake_delay
	je scan_code_handler_ret
	inc [snake_delay]
	jmp scan_code_handler_ret

w_scan_code_handler:
	cmp [snake_y_dir], snake_unit_size
	je scan_code_handler_ret
	mov [snake_x_dir], 0h
	mov [snake_y_dir], -snake_unit_size
	jmp scan_code_handler_ret

a_scan_code_handler:
	cmp [snake_x_dir], snake_unit_size
	je scan_code_handler_ret
	mov [snake_x_dir], -snake_unit_size
	mov [snake_y_dir], 0h
	jmp scan_code_handler_ret

s_scan_code_handler:
	cmp [snake_y_dir], -snake_unit_size
	je scan_code_handler_ret
	mov [snake_x_dir], 0h
	mov [snake_y_dir], snake_unit_size
	jmp scan_code_handler_ret

d_scan_code_handler:
	cmp [snake_x_dir], -snake_unit_size
	je scan_code_handler_ret
	mov [snake_x_dir], snake_unit_size
	mov [snake_y_dir], 0h
	jmp scan_code_handler_ret

space_scan_code_handler:
	cmp [paused], 0h
	je space_scan_code_handler_true
	mov [paused], 0h
	jmp scan_code_handler_ret

	space_scan_code_handler_true:
		mov [paused], 1h
		jmp scan_code_handler_ret

scan_code_handler_ret:
	jmp game_loop_main

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

; move snake in snake_x_dir, snake_y_dir 
move_snake:
	push ax
	push bx
	push cx
	push dx

	call off_sound

	mov cx, [snake_buff]
	mov dx, [snake_buff + 2]

	mov ax, [snake_x_dir]
	mov bx, [snake_y_dir]

	add [snake_buff], ax 
	add [snake_buff + 2], bx

	mov ah, 1h
	mov bx, 4h

	move_snake_loop:
		cmp ah, [snake_len]
		je move_snake_end

		mov si, [snake_buff + bx]
		mov [snake_buff + bx], cx
		add bx, 2h
		mov di, [snake_buff + bx]
		mov [snake_buff + bx], dx
		add bx, 2h

		mov cx, si
		mov dx, di
		inc ah

		jmp move_snake_loop

	move_snake_end:
		mov [old_tail_x], cx
		mov [old_tail_y], dx

		pop dx
		pop bx
		pop cx
		pop ax

		ret

inscrease_snake:
	xor bh, bh
	mov bl, [snake_len]
	dec bx
	sal bx, 2h

	mov ax, [snake_buff + bx]
	add bx, 2h
	mov cx, [snake_buff + bx]
	sub bx, 6h
	mov dx, [snake_buff + bx]
	add bx, 2h
	mov di, [snake_buff + bx]

	sal ax, 1h
	sal cx, 1h
	sub ax, dx
	sub cx, di

	add bx, 6h
	mov [snake_buff + bx], ax
	add bx, 2h
	mov [snake_buff + bx], cx

	inc [snake_len]
	inc [score]
	mov ah, [snake_len]
	cmp ah, [max_snake_len]
	jle inscrease_snake_end
	mov [max_snake_len], ah

	inscrease_snake_end:
		ret

check_intersaction:
	mov ax, [snake_buff]
	mov dx, [snake_buff + 2]
	mov bx, 4h
	mov cl, 1h

	check_intersaction_loop:
		cmp cl, [snake_len]
		je check_intersaction_end
		cmp [snake_buff + bx], ax
		je check_intersaction_x_true
		add bx, 2h
		jmp check_intersaction_next

		check_intersaction_x_true:
			add bx, 2h
			cmp [snake_buff + bx], dx
			jne check_intersaction_next
			cmp [intersect_mode], death_intersect
			je check_intersaction_death
			cmp [intersect_mode], cut_intersect
			je check_intersaction_cut
			jmp check_intersaction_end

		check_intersaction_next:
			add bx, 2h
			inc cl
			jmp check_intersaction_loop

		check_intersaction_death:
			call game_over
			ret

		check_intersaction_cut:
			mov [snake_len], cl
			ret

	check_intersaction_end:
		ret

check_sec_apple_collision_y:
	mov ax, sec_apple_y
	cmp [snake_buff + 2], ax
	jne check_collisions_after_sec_apple_jump
	call new_coords
	mov [sec_apple_x], cx
	mov [sec_apple_y], dx
	call draw_sec_apple
	call inscrease_snake
	mov ax, apple_freq
	call set_freq
	ret

check_collisions_after_sec_apple_jump:
	jmp check_collisions_after_sec_apple

check_apple_collision_y:
	mov ax, apple_y
	cmp [snake_buff + 2], ax
	jne check_collisions_after_apple_jmp
	call new_coords
	mov [apple_x], cx
	mov [apple_y], dx
	call draw_apple
	call inscrease_snake
	mov ax, apple_freq
	call set_freq
	ret

check_death_collision_y:
	mov ax, death_y
	cmp [snake_buff + 2], ax
	jne check_collisions_after_death_jmp
	call new_coords
	mov [death_x], cx
	mov [death_y], dx
	call draw_death
	call game_over
	ret

check_cut_collision_y:
	mov ax, cut_y
	cmp [snake_buff + 2], ax
	jne check_collisions_after_cut
	cmp [snake_len], 2h
	je call_game_over
	dec [snake_len]
	call new_coords
	mov [cut_x], cx
	mov [cut_y], dx
	call draw_cut
	mov ax, cut_freq
	call set_freq
	ret

	call_game_over:
		call game_over
		ret
check_collisions_after_apple_jmp:
	jmp check_collisions_after_apple

check_collisions_after_death_jmp:
	jmp check_collisions_after_death

check_sec_apple_collision_y_jmp:
	jmp check_sec_apple_collision_y

check_apple_collision_y_jmp:
	jmp check_apple_collision_y

check_death_collision_y_jmp:
	jmp check_death_collision_y

check_collisions:
	cmp [snake_buff], wall_width
	je left_wall_handler

	cmp [snake_buff], screen_width
	je right_wall_handler

	cmp [snake_buff + 2], wall_width
	je top_wall_handler

	cmp [snake_buff + 2], screen_height
	je down_wall_handler

	mov ax, apple_x
	cmp [snake_buff], ax
	je check_apple_collision_y_jmp

	check_collisions_after_apple:

	mov ax, sec_apple_x
	cmp [snake_buff], ax
	je check_sec_apple_collision_y_jmp

	check_collisions_after_sec_apple:

	mov ax, death_x
	cmp [snake_buff], ax
	je check_death_collision_y_jmp

	check_collisions_after_death:

	mov ax, cut_x
	cmp [snake_buff], ax
	je check_cut_collision_y

	check_collisions_after_cut:
	
	cmp [intersect_mode], none_intersect
	jne check_intersaction_call

	ret

check_intersaction_call:
	call check_intersaction
	ret

left_wall_handler:
	call game_over
	ret

right_wall_handler:
	mov [snake_buff], wall_width * 2
	ret

top_wall_handler:
	cmp [top_wall_color], death_wall_color
	je left_wall_handler
	cmp [top_wall_color], switch_wall_color
	je top_wall_switch
	mov [snake_buff + 2], screen_height - wall_width
	jmp top_wall_handler_end

	top_wall_switch:
		call reverse_snake
		mov [snake_y_dir], snake_unit_size

	top_wall_handler_end:
		ret

down_wall_handler:
	call reverse_snake
	mov [snake_y_dir], -snake_unit_size
	ret

game_over:
	xor ah, ah
	mov al, 13h
	int 10h

	mov dx, offset game_over_msg
	mov ah, 09h
	int 21h

	mov dx, offset score_msg
	mov ah, 09h
	int 21h

	xor ah, ah
	mov al, [score]
	call print_dec

	mov dx, offset newline
	mov ah, 09h
	int 21h

	mov dx, offset length_msg
	mov ah, 09h
	int 21h

	xor ah, ah
	mov al, [snake_len]
	call print_dec

	mov dx, offset newline
	mov ah, 09h
	int 21h

	mov dx, offset max_length_msg
	mov ah, 09h
	int 21h

	xor ah, ah
	mov al, [max_snake_len]
	call print_dec

	mov dx, offset newline
	mov ah, 09h
	int 21h

	mov dx, offset final_msg
	mov ah, 09h
	int 21h

	call death_song_play

	cmp [exit_by_key], 0h
	je go_wait_for_key2

	go_wait_for_key:
		call read_key
		cmp ah, 0h
		je go_wait_for_key

	go_wait_for_key2:
		call read_key
		cmp ah, 0h
		je go_wait_for_key2
		cmp al, esc_scan_code
		jne go_wait_for_key2

	jmp exit

; al - char to print
print_char:
	mov dl, al
	mov ah, 02h
	int 21h
	ret

; ax - value to print
print_dec:
	mov cx, 10d
	xor di, di

	div_loop:
		inc di
		xor dx, dx
		div cx
		add dx, 30h
		push dx
		cmp ax, 0h
		jne div_loop

	print_dec_loop:
		cmp di, 0h
		je print_dec_end
		pop ax
		call print_char
		dec di
		jmp print_dec_loop

	print_dec_end:
		ret

; (cx, dx) in free point
new_coords:
	xor	ah, ah
	int 1ah
	mov ax, dx
	mov cx, width_cells
	xor dx, dx
	div cx
	mov ax, dx
	add ax, 2h
	mov cx, snake_unit_size
	imul cx
	push ax

	xor	ah, ah
	int 1ah
	mov ax, dx
	mov cx, height_cells
	xor dx, dx
	div cx
	mov ax, dx
	add ax, 2h
	mov cx, snake_unit_size
	imul cx
	push ax	

	pop dx
	pop cx

	mov ah, 0dh
	mov bh, [curr_page]
	int 10h

	cmp al, 0h
	jne new_coords

	cmp cx, [old_tail_x]
	je new_coords_check_old_tail_y

	new_coords_after_old_tail_check:

	cmp cx, [apple_x]
	je new_coords_check_apple_y

	new_coords_after_apple_check:

	cmp cx, [death_x]
	je new_coords_check_death_y

	new_coords_after_death_check:

	cmp cx, [cut_x]
	je new_coords_check_cut_y

	new_coords_after_cut_check:

	ret

new_coords_check_old_tail_y:
	cmp dx, [old_tail_y]
	je new_coords
	jmp new_coords_after_old_tail_check

new_coords_check_apple_y:
	cmp dx, [apple_y]
	je new_coords
	jmp new_coords_after_apple_check

new_coords_check_death_y:
	cmp dx, [death_y]
	je new_coords
	jmp new_coords_after_death_check

new_coords_check_cut_y:
	cmp dx, [cut_y]
	je new_coords
	jmp new_coords_after_cut_check

reverse_snake:
	push ax
	push bx
	push cx

	xor bx, bx
	mov cl, [snake_len]
	xor ch, ch
	xor ah, ah
	mov al, [snake_len]
	dec ax
	sal ax, 2h

	reverse_snake_loop:
		cmp ch, cl
		jge reverse_snake_end
		
		mov dx, [snake_buff + bx]
		xchg ax, bx
		mov di, [snake_buff + bx]
		mov [snake_buff + bx], dx
		xchg ax, bx
		mov [snake_buff + bx], di
		add bx, 2h
		mov dx, [snake_buff + bx]
		xchg ax, bx
		add bx, 2h
		mov di, [snake_buff + bx]
		mov [snake_buff + bx], dx
		sub bx, 6h
		xchg ax, bx
		mov [snake_buff + bx], di
		add bx, 2h

		add ch, 3h 
		jmp reverse_snake_loop		

	reverse_snake_end:
		pop cx
		pop bx
		pop ax
		ret

; redraw head and tail
redraw_snake:
	cmp [old_tail_y], screen_height
	je redraw_head

	cmp [old_tail_y], snake_unit_size
	je redraw_head

	mov cx, [old_tail_x]
	mov dx, [old_tail_y]
	xor al, al
	mov bx, snake_unit_size
	call draw_box

	redraw_head:
		mov cx, [snake_buff]
		mov dx, [snake_buff + 2]
		mov al, [snake_color]
		mov bx, snake_unit_size
		call draw_box

	ret

; draw full-snake
draw_snake:
	mov al, [snake_color]
	xor bx, bx
	xor ah, ah

	draw_snake_loop:
		mov cx, [snake_buff + bx]
		add bx, 2h
		mov dx, [snake_buff + bx]
		add bx, 2h
		push bx
		mov bx, snake_unit_size
		call draw_box
		pop bx
		inc ah
		cmp ah, [snake_len]
		jne draw_snake_loop
	
	draw_snake_end:
		ret

draw_walls:
	call draw_left_wall
	call draw_right_wall
	call draw_top_wall
	call draw_bottom_wall

	ret

draw_left_wall:
	mov al, left_wall_color
	xor dx, dx
	xor cx, cx
	mov bx, screen_height

	draw_left_wall_loop:
		cmp cx, wall_width
		je draw_left_wall_end
		call draw_ver_line
		inc cx
		jmp draw_left_wall_loop

	draw_left_wall_end:
		ret

draw_right_wall:
	mov al, right_wall_color
	xor dx, dx
	mov cx, screen_width - 1
	mov bx, screen_height

	draw_right_wall_loop:
		cmp cx, screen_width - wall_width - 1
		je draw_left_wall_end
		call draw_ver_line
		dec cx
		jmp draw_right_wall_loop

	draw_right_wall_end:
		ret

draw_top_wall:
	mov al, [top_wall_color]
	xor dx, dx
	xor cx, cx
	mov bx, screen_width

	draw_top_wall_loop:
		cmp dx, wall_width
		je draw_top_wall_end
		call draw_hor_line
		inc dx
		jmp draw_top_wall_loop

	draw_top_wall_end:
		ret

draw_bottom_wall:
	mov al, bottom_wal_color
	mov dx, screen_height
	xor cx, cx
	mov bx, screen_width

	draw_bottom_wall_loop:
		cmp dx, screen_height - wall_width
		je draw_bottom_wall_end
		call draw_hor_line
		dec dx
		jmp draw_bottom_wall_loop

	draw_bottom_wall_end:
		ret

draw_apple:
	mov al, apple_color
	mov cx, [apple_x]
	mov dx, [apple_y]
	call draw_circle
	ret

draw_sec_apple:
	mov al, apple_color
	mov cx, [sec_apple_x]
	mov dx, [sec_apple_y]
	call draw_circle
	ret	

draw_cut:
	mov al, cut_color
	mov cx, [cut_x]
	mov dx, [cut_y]
	call draw_circle
	ret

draw_death:
	mov al, death_color
	mov cx, [death_x]
	mov dx, [death_y]
	call draw_circle
	ret

; al - color, cx - x, dx - y, bx - size
draw_box:
	push di
	push cx
	push dx
	push bx

	mov di, cx
	sub dx, bx
	sub cx, bx

	draw_box_loop:
		call draw_ver_line
		inc cx
		cmp cx, di
		je draw_box_end
		jmp draw_box_loop

	draw_box_end:
		pop bx
		pop dx
		pop cx
		pop di
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

; 10 ms delay
delay:
	push ax
	push cx

	xor cx, cx
	mov dx, 2710h
	mov ah, 86h
	xor al, al
	int 15h

	pop cx
	pop ax
	ret

; ah - 0 if empty, al - scan_code if is not empty
read_key:
	push bx
	mov bl, [key_buff_head]
	mov bh, [key_buff_tail]
	cmp bl, bh
	je empty_read
	xor bh, bh
	mov al, [key_buffer + bx]
	inc bl
	cmp bl, key_buff_len
	je head_reset
	jmp read_key_end

	empty_read:
		xor ah, ah
		jmp read_key_exit

	head_reset:
		xor bl, bl

	read_key_end:
		mov ah, 01h
		mov [key_buff_head], bl

	read_key_exit:

	pop bx
	ret

; al - scan_code to write
write_key:
	push bx
	xor bx, bx
	mov bl, [key_buff_tail]
	mov [key_buffer + bx], al
	inc bl
	cmp bl, key_buff_len
	je tail_reset
	jmp write_key_end

	tail_reset:
		xor bl, bl

	write_key_end:
		mov [key_buff_tail], bl

	pop bx
	ret

; al - color, cx - x of center, dx - y of center
draw_circle:
	sub cx, 10d
	sub dx, 10d

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

; ax - freq
set_freq:
	out 42h, al
	mov al, ah
	out 42h, al

	in al, 61h
	or al, 11b
	out 61h, al

	ret

off_sound:
	push ax

	in al, 61h
	and al, not 11b
	out 61h, al

	pop ax
	ret

death_song_play:
	xor bx, bx
	song_play_loop:
		mov ax, [death_song + bx]
		call set_freq
		add bx, 2h
		mov ax, [death_song + bx]
		call n_delay
		add bx, 2h
		cmp bx, death_song_len * 2
		jl song_play_loop
		call off_sound
		ret

n_delay:
	call delay
	dec ax
	cmp ax, 0h
	je delay_end
	jmp n_delay

	delay_end:
		ret
end start