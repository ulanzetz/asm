.model tiny

esc_scan_code equ 01h
space_scan_code equ 39h

buff_len equ 4h

play_buff_len equ 30h

song_len equ 14

.data
	buffer db buff_len dup(0)
	original_9h dd 0h
	buff_head db 0h
	buff_tail db 0h
	freqs dw 7902d, 7458d, 7040d, 6645d, 6271d, 5920d, 5588d, 5274d, 4978d, 4698d, 4434d, 4186d, 3951d, 3729d, 3520d, 3322d, 3135d, 2960d, 2794d, 2637d, 2489d, 2349d, 2217d, 2093d, 1975d, 1864d, 1760d, 1661d, 1568d, 1480d, 1397d, 1318d, 1244d, 1174d, 1109d, 1046d
	play_buffer db play_buff_len dup(0)
	play_buff_next dw 0h
	play_buff_curr dw 0h
	song dw 440, 5, 349, 4, 523, 1, 440, 1, 349, 4, 523, 3, 440, 6 
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
	jmp _loop

exit:
	call off_sound
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

delay:
	push ax
	push cx

	mov cx, 01h
	mov dx, 86a0h
	mov ah, 86h
	int 15h

	pop cx
	pop ax
	ret

n_delay:
	call delay
	dec ax
	cmp ax, 0h
	je delay_end
	jmp delay

	delay_end:
		ret

song_play:
	xor bx, bx
	song_play_loop:
		mov ax, [song + bx]
		call play_freq
		add bx, 2h
		mov ax, [song + bx]
		call n_delay
		add bx, 2h
		cmp bx, song_len * 2
		jl song_play_loop
		call off_sound
		ret

call_song:
	call song_play

_loop:
	call read_key
	cmp ah, 0h
	je _loop
	cmp al, esc_scan_code
	je exit
	cmp al, space_scan_code
	je call_song

	mov ah, al
	and ah, 10000000b
	cmp ah, 0h
	jne delete_from_play_buff
	call parse_octave_and_note
	cmp bl, 0h
	je _loop
	push ax

	mov al, bh
	call in_buffer
	cmp ah, 1h
	je _loop
	mov bx, play_buff_next
	mov [play_buffer + bx], al
	mov play_buff_curr, bx
	inc bx
	cmp bx, play_buff_len
	jne set_next
	xor bx, bx
	set_next:
		mov play_buff_next, bx
		pop ax
		call play_note
		jmp _loop

	delete_from_play_buff:
		sub al, 80h
		call parse_octave_and_note
		cmp bl, 0h
		je _loop
		mov al, bh
		xor bx, bx
		delete_from_play_buff_loop:
			cmp bx, play_buff_len
			je no_sound; buff overflow
			cmp al, [play_buffer + bx]
			je delete_from_play_buff_end
			inc bx
			jmp delete_from_play_buff_loop

		delete_from_play_buff_end:
			mov [play_buffer + bx], 0h
			mov bx, play_buff_curr
			mov cx, bx

		play_last:
			mov al, [play_buffer + bx]
			cmp al, 0h
			jne playing
			cmp bx, 0h
			je set_bx_max
			dec bx
			check_play_buff_end:
			cmp bx, cx
			je no_sound
			jmp play_last

		set_bx_max:
			mov bx, play_buff_len - 1
			jmp check_play_buff_end

		playing:
			mov play_buff_curr, bx
			mov al, [play_buffer + bx]
			call parse_octave_and_note
			call play_note
			inc bx
			mov play_buff_next, bx
			jmp _loop

		no_sound:
			mov play_buff_next, 0h
			mov play_buff_curr, 0h 
			call off_sound
			jmp _loop

	jmp _loop

in_buffer:
	push bx
	xor bx, bx
	in_buffer_loop:
		cmp al, [play_buffer + bx]
		je in_buffer_suc
		inc bx
		cmp bx, play_buff_len
		je in_buffer_no
		jmp in_buffer_loop

 	in_buffer_no:
 		mov ah, 0h
 		jmp in_buffer_end

	in_buffer_suc:
		mov ah, 1h

	in_buffer_end:
		pop bx
		ret

; ah - octave, al - note
; bl - 0 if none, 1 if some, bh - original scan_code
parse_octave_and_note:
	mov bh, al
	cmp al, 3bh
	jge maybe_zero
	cmp al, 10h
	jge maybe_second
	cmp al, 2h
	jge maybe_first
	jmp none_ret

	maybe_zero:
		cmp al, 44h
		jle zero_norm
		cmp al, 57h
		jle zero_ext
		cmp al, 58h
		jle zero_ext
		jmp none_ret

	zero_norm:
		xor ah, ah
		sub al, 3bh
		jmp some_ret

	zero_ext:
		xor ah, ah
		sub al, 4dh
		jmp some_ret

	maybe_second:
		cmp al, 1bh
		jg none_ret
		mov ah, 2h
		sub al, 10h
		jmp some_ret

	maybe_first:
		cmp al, 0dh
		jg none_ret
		mov ah, 1h
		sub al, 02h
		jmp some_ret

	some_ret:
		mov bl, 1h
		ret

	none_ret:
		mov bl, 0h
		ret

; ax - freq
play_freq:
	out 42h, al
	mov al, ah
	out 42h, al

	in al, 61h
	or al, 11b
	out 61h, al

	ret

; ah - octave, al - note
play_note:
	push bx

	; set note freq to ax
	mov bl, al
	mov bh, 0ch
	mov al, ah
	xor ah, ah
	imul bh
	xor bh, bh
	add bx, ax

	shl bl, 1
	mov ax, [freqs + bx]

	call play_freq

	pop bx
	ret

off_sound:
	push ax

	in al, 61h
	and al, not 11b
	out 61h, al

	pop ax
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