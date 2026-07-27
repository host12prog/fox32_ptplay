	pop [stream_ptr]
	pop [filename]
	cmp [filename], 0
	ifz rjmp arg_error
	call get_current_disk_id
	mov r1, r0
	mov r0, [filename]
	mov r2, file_struct
	call open ; open file pointer
	cmp r0, 0
	ifz rjmp file_error
	mov r0, file_struct
	call get_size
	mov.32 r5, r0 ; backup size
	call allocate_memory
	mov.32 [mem_ptr], r0
	mov.32 r0, r5
	mov.32 r1, file_struct
	mov.32 r2, [mem_ptr]
	call read
msg:
	mov r0, str
	call m_print
	mov r0, [mem_ptr]
	call m_print
	mov r0, new_line
	call m_print
m_init:
	mov.32 r0, [mem_ptr]
	mov.32 r1, 0 ; starting order
	mov.32 r2, 1 ; interrupt flag
	call mt_init
yield_loop:
	rcall check_key
	call yield_task
	rjmp yield_loop

check_key:
	mov.32 r0, 1
	mov.32 r1, [stream_ptr]
	mov.32 r2, key_buff
	call read
	movz.8 r0, [r2]
	cmp.8 r0, 113
	ifz rjmp exit
	cmp.8 r0, 51
	ifz rjmp exit
	ret

file_error:
	mov r0, err_str2
	rjmp error
arg_error:
	mov r0, err_str
	rjmp error
error:
	call m_print
	call end_current_task
	
exit:
	call mt_exit
	mov.32 r0, [mem_ptr]
	call free_memory
	call end_current_task

m_print:
	mov r2, r0
	call string_length
	mov r1, [stream_ptr]
	call write
	ret

stream_ptr: data.32 0
filename: data.32 0
file_struct: data.fill 0, 32
key_buff: data.8 0
mem_ptr: data.32 0

str: data.str "press q to exit..." data.8 10 data.str "song name: " data.8 0
new_line: data.8 10 data.8 0
err_str: data.str "error: no file provided" data.8 10 data.8 0
err_str2: data.str "error: could not open file" data.8 10 data.8 0

	#include "ptplayer.asm"
	#include ".\fox32os.def"
	#include ".\fox32rom.def"