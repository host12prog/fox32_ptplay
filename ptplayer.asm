	; ptplayer - by alex winston
	; fucked up MOD player
	; thankings to: ry and all other fox32 people
	; fuckings to: ProTracker playback quirks
	; will i ever finish this? no
	; will it ever play all MODs reliably? no
	; will i optimise this? no
	; will i rewrite this? probably
	
const AUDIO_SAMPLE_BASE: 0x80000680
const AUDIO_CHANNEL_START:		0x80000600
const AUDIO_CHANNEL_END:	  0x80000601
	; MAGIC_CONST is actually the rounded result of
	; the following expression:
	; (3579545.25 / 48000) * 2^16 = 4887272.45
const MAGIC_CONST: 4887272
; const MAGIC_CONST: 4842261
; const MAGIC_CONST: 4843580

	; mt_init - init player
	; inputs:
	; r0 - ProTracker module address
	; r1 - starting order position
	; r2 - 0 to exit after init, 1 to automatically install ISR
	; outputs: none
mt_init:
	push r0
	push r1
	push r2
	push r3
	push r4
	push r5
	push r6
	push r7
	push r8
	push r9
	push r10
	push r11
	push r12
	push r31
	icl ; suppress any interrupt that may happen mid-init
	cmp.8 r2, 0
	ifz rjmp mt_init_skip_isr
	mov.32 [mt_old_int], [0x3FC] ; VSYNC
	mov.32 [0x3FC], mt_play_int ; install our own interrupt
mt_init_skip_isr:
	mov.8 [mod_order_pos], r1
	mov.32 [mod_ptr], r0
	mov.32 r8, [mod_ptr]
	add.32 r8, 950 ; song-length byte
	mov.8 [mod_songlen], [r8]
	; order list
	movz.8 r31, 128
	mov.32 r7, 0 ; highest pattern number
	add.32 r8, 2 ; +952 - pattern data
mt_L1:
	mov.8 r0, [r8]
	inc.32 r8, 1
	cmp.8 r0, r7
	ifgt movz.8 r7, r0
	rloop mt_L1
	; highest pattern number is in r7
	inc.8 r7, 1 ; adjust
	add.32 r8, 4 ; skip M.K. signature 
	; calculate sample start
	sla.32 r7, 10 ; *1024 (64*4*4)
	add.32 r8, r7
	out AUDIO_SAMPLE_BASE, r8
	
	; calculate sample table
	mov.32 r10, mod_sample_finetune
	mov.32 r9, mod_sample_vol
	mov.32 r8, [mod_ptr] ; now reset for sample table
	add.32 r8, 20 ; ignore song-name
	mov.32 r6, mod_sample_start
	mov.32 r7, mod_sample_end
	mov.32 r5, 0 ; accumulator
	movz.8 r31, 31
mt_L2:
	mov.32 [r6], r5 ; start offset
	movz.8 r1, [r8+25] ; default volume
	mov.8 [r9], r1
	inc.32 r9, 1
	movz.8 r1, [r8+24] ; fine-tune
	and.32 r1, 0x0F
	mov.8 [r10], r1
	inc.32 r10, 1
	movz.16 r0, [r8+22] ; big-endian word
	ror.16 r0, 8 ; little-endian
	sla.32 r0, 1 ; *2
	add.32 r5, r0
	mov.32 [r7], r5 ; end offset
	add.32 r8, 30 ; next sample
	inc.32 r6, 4
	inc.32 r7, 4
	rloop mt_L2
	
	; calculate loop table
	mov.32 r8, [mod_ptr] ; now reset for sample table
	add.32 r8, 20 ; ignore song-name
	mov.32 r6, mod_sample_start
	mov.32 r7, mod_sample_end
	mov.32 r4, mod_loop_start
	mov.32 r3, mod_loop_end
	mov.32 r5, 0 ; accumulator
	movz.8 r31, 31
mt_L3:
	mov.32 [r6], r5
	movz.16 r0, [r8+22] ; sample length
	ror.16 r0, 8 
	sla.32 r0, 1
	movz.16 r1, [r8+26] ; loop start
	ror.16 r1, 8
	sla.32 r1, 1
	movz.16 r2, [r8+28] ; loop length
	ror.16 r2, 8
	sla.32 r2, 1
	; calculate absolute position
	mov.32 r10, r5
	add.32 r10, r1
	mov.32 [r4], r10 ; loop start
	add.32 r10, r2
	mov.32 [r3], r10 ; loop end
	; accumulate
	add.32 r5, r0
	mov.32 [r7], r5
	add.32 r8, 30
	inc.32 r6, 4
	inc.32 r7, 4
	inc.32 r4, 4
	inc.32 r3, 4
	rloop mt_L3
	
	call mt_play_pattern
	
	mov.8  [mod_break_row], 0xFF
	mov.8  [mod_next_order], 0xFF
	mov.8  [mod_counter], 0
	mov.8  [mod_position], 0
	mov.8  [mod_speed], 6
	mov.8  [mod_pattern_delay], 0
	mov.8  [mod_pattern_delay_active], 0
	mov.16 [mod_bpm], 125

	movz.8 r31, 4
	mov.32 r0, mod_channel_volume
	mov.32 r1, mod_channel_loop
	mov.32 r2, mod_channel_effect
	mov.32 r3, mod_channel_param
	mov.32 r4, mod_channel_slide
	mov.32 r5, mod_channel_porta
	mov.32 r6, mod_channel_vol_slide
	mov.32 r7, mod_channel_vib_pos
	mov.32 r8, mod_channel_vib_cmd
	mov.32 r9, mod_channel_offset_val
	mov.32 r10, mod_channel_loop_row
	mov.32 r11, mod_channel_loop_cnt
	mov.32 r12, mod_channel_delay_tick
mt_clear_channels_8:
	mov.8 [r0], 64
	mov.8 [r1], 0
	mov.8 [r2], 0
	mov.8 [r3], 0
	mov.8 [r4], 0
	mov.8 [r5], 0
	mov.8 [r6], 0
	mov.8 [r7], 0
	mov.8 [r8], 0
	mov.8 [r9], 0
	mov.8 [r10], 0
	mov.8 [r11], 0
	mov.8 [r12], 0
	inc.32 r0, 1
	inc.32 r1, 1
	inc.32 r2, 1
	inc.32 r3, 1
	inc.32 r4, 1
	inc.32 r5, 1
	inc.32 r6, 1
	inc.32 r7, 1
	inc.32 r8, 1
	inc.32 r9, 1
	inc.32 r10, 1
	inc.32 r11, 1
	inc.32 r12, 1
	rloop mt_clear_channels_8

	movz.8 r31, 4
	mov.32 r0, mod_channel_period ; these vars are 32-bit
	mov.32 r1, mod_channel_target
	mov.32 r2, mod_channel_sample
	mov.32 r3, mod_channel_delay_row
mt_clear_channels_32:
	mov.32 [r0], 0
	mov.32 [r1], 0
	mov.32 [r2], 0
	mov.32 [r3], 0
	add.32 r0, 4
	add.32 r1, 4
	add.32 r2, 4
	add.32 r3, 4
	rloop mt_clear_channels_32
	
	ise
	pop r31
	pop r12
	pop r11
	pop r10
	pop r9
	pop r8
	pop r7
	pop r6
	pop r5
	pop r4
	pop r3
	pop r2
	pop r1
	pop r0
	ret

	; set order position
mt_play_pattern:
	mov.32 r0, [mod_ptr]
	add.32 r0, 952 ; +952: order-list
	movz.8 r1, [mod_order_pos]
	add.32 r0, r1 ; current order slot
	movz.8 r2, [r0] ; index number
	sla.32 r2, 10 ; *1024
	mov.32 r0, [mod_ptr]
	add.32 r0, 1084 ; base address
	add.32 r0, r2
	mov.32 [mod_pattern_ptr], r0
	
	movz.8 r31, 4
	mov.32 r0, mod_channel_loop_row
mt_reset_loop:
	mov.8 [r0], 0
	inc.32 r0, 1
	rloop mt_reset_loop
	ret
	
mt_play_int:
	push r0
	push r1
	movz.16 r0, [mod_acc]
	movz.16 r1, [mod_bpm]
	add.32 r0, r1
	cmp.32 r0, 150
	iflt rjmp mt_isr_l1
	sub.32 r0, 150
	mov.16 [mod_acc], r0
	call mt_play
	pop r1
	pop r0
	jmp [mt_old_int]
mt_isr_l1:
	mov.16 [mod_acc], r0
	pop r1
	pop r0
	jmp [mt_old_int]
	
	; variables are nearly at the end of the file
	; but i cannot be arsed to scroll down!!!
mod_acc: data.16 0
mt_old_int: data.32 0
	
	; mt_exit - exit routine
	; inputs: none
	; outputs: none
mt_exit:
	push r30
	push r31
	mov r31, 64
mt_e1:
	mov r30, 0x80000600
	add r30, r31
	out r30, 0
	rloop mt_e1
	out 0x80000680, 0
	icl
	mov.32 [0x3FC], [mt_old_int] ; restore old interrupt
	ise
	pop r31
	pop r30
	ret

	; mt_play - play routine
	; inputs: none
	; outputs: none
	; clobbers: r29, r30, r31
	; don't bother pushing r29, r30, r31, it will crash
mt_play:
	push r0
	push r1
	push r2
	push r3
	push r4
	push r5
	push r6
	push r7
	push r8
	push r9
	push r10
	push r11
	push r12
	push r13
	push r14
	push r15
	push r16
	push r17
	push r18
	push r19 
	push r20
	push r21
	push r22
	push r23
	push r24
	push r25
	push r26
	push r27
	push r28
	cmp.8 [mod_counter], 0 ; we process note data on tick 0
	ifgt rjmp mt_tick ; no, skip
	cmp.8 [mod_pattern_delay_active], 0
	ifnz rjmp mt_handle_pattern_delay
	movz.8 r0, [mod_position] ; load row position
	sla.32 r0, 4 ; *16
	mov.32 r9, [mod_pattern_ptr] ; get row data
	add.32 r9, r0
	mov.32 r31, 0 ; channel count
mt_ch_loop:
	mov.32 r0, [r9]
	call mt_parse_row
	cmp.8 r3, 0x0E ; extended command?
	ifnz rjmp mt_not_edx ; no, skip
	mov.32 r10, r4
	srl.32 r10, 4
	and.32 r10, 0x0F
	cmp.32 r10, 0x0D ; is this EDx?
	ifnz rjmp mt_not_edx
	mov.32 r10, r4
	and.32 r10, 0x0F ; get delay value
	cmp.32 r10, 0 ; if 0, skip
	ifz rjmp mt_not_edx
	mov.32 r28, mod_channel_delay_tick
	add.32 r28, r31
	mov.8 [r28], r10 ; store delay target
	mov.32 r28, mod_channel_delay_row
	mov.32 r29, r31
	sla.32 r29, 2
	add.32 r28, r29
	mov.32 [r28], r0
	mov.32 r1, 0
	mov.32 r2, 0
mt_not_edx:
	mov.32 r30, AUDIO_CHANNEL_START
	mov.32 r29, r31 ; channel index * 16
	sla.32 r29, 4
	add.32 r30, r29
	mov.32 r22, mod_channel_loop
	add.32 r22, r31
	movz.8 r18, [r22]
	or.32 r18, 0x017F ; control word
	; note handling
	cmp.32 r2, 0
	ifz rjmp mt_skip_vol_reset
	cmp.32 r3, 0x03
	ifz rjmp mt_skip_vol_reset
	cmp.32 r3, 0x05
	ifz rjmp mt_skip_vol_reset
	mov.32 r23, r2
	sub.32 r23, 1
	mov.32 r20, mod_sample_vol
	add.32 r20, r23
	mov.32 r21, mod_channel_volume
	add.32 r21, r31
	movz.8 r0, [r20]
	mov.8 [r21], r0
mt_skip_vol_reset:
	; portamento check
	cmp.8 r3, 0x03
	ifz rjmp mt_has_portamento
	cmp.8 r3, 0x05
	ifz rjmp mt_has_portamento
	cmp.32 r1, 0
	ifz rjmp mt_has_portamento
	rjmp mt_no_portamento
mt_has_portamento:
	cmp.32 r1, 0
	;ifnz rjmp mt_set_target
	ifz rjmp mt_check_portamento_ins
mt_set_target:
	mov.32 r28, mod_channel_target ; store target period
	mov.32 r29, r31
	sla.32 r29, 2
	add.32 r28, r29
	mov.32 [r28], r1
	;rjmp mt_no_ins
	mov.32 r27, mod_channel_period
	add.32 r27, r29
	mov.32 r26, [r27]
	cmp.32 r26, 0
	ifnz rjmp mt_check_portamento_ins
	mov.32 [r27], r1
mt_check_portamento_ins:
	cmp.32 r2, 0 ; was an instrument specified with 3xx?
	ifz rjmp mt_no_ins
	sub.32 r2, 1
	mov.32 r23, r2
	mov.32 r28, mod_channel_sample
	add.32 r28, r31
	mov.8 [r28], r23 ; swap active sample ID for fine-tune change
	
	mov.32 r20, mod_sample_vol
	add.32 r20, r23
	mov.32 r21, mod_channel_volume
	add.32 r21, r31
	movz.8 r0, [r20]
	mov.8 [r21], r0 ; update volume to new sample default
	rjmp mt_no_ins
mt_no_portamento:
	cmp.32 r1, 0 ; carry sample to next note?
	ifz rjmp mt_no_ins
	cmp.32 r2, 0 ; new instrument?
	ifnz rjmp mt_has_sample
	mov.32 r28, mod_channel_sample
	add.32 r28, r31
	movz.8 r2, [r28]
	inc.32 r2, 1
mt_has_sample:
	cmp.8 [mod_parsed_sample], 0
	ifz rjmp mt_skip_active_reset
	; reset offset
	mov.32 r28, mod_channel_offset_val
	add.32 r28, r31
	mov.8 [r28], 0
mt_skip_active_reset:
	; look up sample
	mov.32 r10, mod_sample_start
	mov.32 r11, mod_sample_end
	sub.32 r2, 1
	mov.32 r23, r2
	mov.32 r28, mod_channel_sample
	add.32 r28, r31
	mov.8 [r28], r23
	sla.32 r2, 2 ; *4
	add.32 r10, r2 ; start offset
	add.32 r11, r2 ; end offset
	mov.32 r12, [r10] ; sample start
	mov.32 r13, [r11] ; sample end
	; 9xx sample offset handle
	mov.32 r24, 0
	cmp.8 [mod_parsed_effect], 0x09 ; if 9xx sample offset
	ifz rjmp mt_offset
	cmp.8 [mod_parsed_sample], 0
	ifnz rjmp mt_reset_offset
	mov.32 r28, mod_channel_offset_val
	add.32 r28, r31
	movz.8 r25, [r28]
	;cmp.32 r25, 0
	;ifz rjmp mt_skip_offset
	rjmp mt_apply_offset
mt_offset:
	cmp.8 [mod_parsed_params], 0
	ifz rjmp mt_recall_offset
	mov.32 r25, r4
	mov.32 r28, mod_channel_offset_mem
	add.32 r28, r31
	mov.8 [r28], r25
	mov.32 r28, mod_channel_offset_val
	add.32 r28, r31
	mov.8 [r28], r25
	rjmp mt_apply_offset
mt_recall_offset:
	mov.32 r28, mod_channel_offset_mem
	add.32 r28, r31
	mov.8 [r28], r25
	rjmp mt_apply_offset
mt_reset_offset:
	mov.32 r25, 0
	mov.32 r28, mod_channel_offset_val
	add.32 r28, r31
	mov.8 [r28], r25
mt_apply_offset:
	sla.32 r25, 8
	add.32 r12, r25
mt_skip_offset:
	; look up loop!
	mov.32 r10, mod_loop_start
	mov.32 r11, mod_loop_end
	add.32 r10, r2 ; start offset
	add.32 r11, r2 ; end offset
	mov.32 r14, [r10] ; loop start
	mov.32 r15, [r11] ; loop end
	; load offsets into audio
	out r30, r12 ; start
	mov.32 r28, r30
	inc.32 r28, 1
	out r28, r13 ; end
	inc.32 r28, 1
	out r28, r14 ; loop start
	inc.32 r28, 1
	out r28, r15 ; loop end
	mov.32 r16, r15 ; test if we must loop
	sub.32 r16, r14
	mov.32 r22, mod_channel_loop
	add.32 r22, r31
	and.32 r18, 0xFF7F
	mov.8 [r22], 0
	cmp.32 r16, 2 ; loop length >2?
	ifgt bse.32 r18, 7 ; loop
	ifgt mov.8 [r22], 0x80 ; loop
mt_no_ins:
mt_skip_note:
	; handle effects here!
	mov.32 r28, mod_channel_effect
	add.32 r28, r31
	mov.8 [r28], r3 ; store effect num
	; THANKS PROTRACKER!!!
	cmp.8 r3, 0x04 ; the following effects have their own handling
	ifz rjmp mt_skip_param_0
	cmp.8 r3, 0x03
	ifz rjmp mt_skip_param_0
	cmp.8 r3, 0x01
	ifz rjmp mt_skip_param_0
	cmp.8 r3, 0x02
	ifz rjmp mt_skip_param_0
	mov.32 r28, mod_channel_param
	add.32 r28, r31
	mov.8 [r28], r4
mt_skip_param_0:
	cmp.8 r3, 0x0A
	ifz rjmp mt_store_a_param
	cmp.8 r3, 0x05
	ifz rjmp mt_store_comb_param
	cmp.8 r3, 0x06
	ifz rjmp mt_store_comb_param
	cmp.8 r4, 0
	ifz rjmp mt_skip_param
	cmp.8 r3, 0x01
	ifz rjmp mt_store_slide_param
	cmp.8 r3, 0x02
	ifz rjmp mt_store_slide_param
	cmp.8 r3, 0x09
	ifz rjmp mt_store_offset_param
	cmp.8 r3, 0x03
	ifz rjmp mt_store_port_param
	cmp.8 r3, 0x04
	ifz rjmp mt_store_vibrato_param
	rjmp mt_skip_param
mt_store_a_param:
	cmp.8 r4, 0
	ifz rjmp mt_clear_a_param
	mov.32 r28, mod_channel_vol_slide
	add.32 r28, r31
	mov.8 [r28], r4
	rjmp mt_skip_param
mt_clear_a_param:
	mov.32 r28, mod_channel_vol_slide
	add.32 r28, r31
	mov.8 [r28], 0
	rjmp mt_skip_param
mt_store_comb_param:
	mov.32 r28, mod_channel_vol_slide
	add.32 r28, r31
	cmp.32 r28, 0
	ifz rjmp mt_skip_param
	mov.8 [r28], r4
	rjmp mt_skip_param
mt_store_vibrato_param:
	cmp.8 r4, 0
	ifz rjmp mt_skip_param
mt_do_store_vib:
	mov.32 r28, mod_channel_vib_cmd
	add.32 r28, r31
	movz.8 r10, [r28]
	mov.32 r11, r4
	srl.32 r11, 4
	and.32 r11, 0x0F  ; r11 - speed
	mov.32 r12, r4
	and.32 r12, 0x0F  ; r12 - depth
	cmp.32 r11, 0
	ifz mov.32 r11, r10
	ifz srl.32 r11, 4
	ifz and.32 r11, 0x0F
	cmp.32 r12, 0
	ifz mov.32 r12, r10
	ifz and.32 r12, 0x0F
	sla.32 r11, 4 ; recombine into 1 byte
	or.32 r11, r12
	mov.8 [r28], r11
	rjmp mt_skip_param
mt_store_slide_param:
	mov.32 r28, mod_channel_slide
	add.32 r28, r31
	mov.8 [r28], r4
	rjmp mt_skip_param
mt_store_offset_param:
	mov.32 r28, mod_channel_offset_val
	add.32 r28, r31
	mov.8 [r28], r4
	rjmp mt_skip_param
mt_store_port_param:
	cmp.8 r4, 0
	ifz rjmp mt_skip_param
	mov.32 r28, mod_channel_porta
	add.32 r28, r31
	mov.8 [r28], r4
	rjmp mt_skip_param
mt_skip_param:
	cmp.8 r3, 0x03
	ifz rjmp mt_skip_period
	cmp.8 r3, 0x05
	ifz rjmp mt_skip_period
	cmp.32 r1, 0 ; new note period?
	ifz rjmp mt_skip_period
	cmp.32 r1, 0
	ifz rjmp mt_skip_period
	mov.32 r28, mod_channel_period
	mov.32 r29, r31
	sla.32 r29, 2
	add.32 r28, r29
	mov.32 [r28], r1
	; reset vibrato
	mov.32 r28, mod_channel_vib_pos
	add.32 r28, r31
	mov.8 [r28], 0
mt_skip_period:
	cmp.8 r3, 0x0E
	ifz rjmp mt_handle_extra
	cmp.8 r3, 0x0A
	ifz rjmp mt_volslide
	cmp.8 r3, 0x0B
	ifz rjmp mt_posjump
	cmp.8 r3, 0x0C
	ifz rjmp mt_volume
	cmp.8 r3, 0x0D
	ifz rjmp mt_pattbreak
	cmp.8 r3, 0x0F
	ifz rjmp mt_speed
	rjmp mt_no_effect
mt_handle_extra:
	mov.32 r10, r4
	srl.32 r10, 4
	and.32 r10, 0x0F
	sla.32 r10, 2
	mov.32 r11, mod_e_table_1
	add.32 r11, r10
	mov.32 r12, [r11]
	jmp r12
	; Exy effects here
mt_e_delay_handler:
mt_e_unused:
	rjmp mt_no_effect
mt_e_fine_porta_up:
	mov.32 r28, mod_channel_period
	mov.32 r29, r31
	sla.32 r29, 2
	add.32 r28, r29
	mov.32 r1, [r28]
	mov.32 r10, r4
	and.32 r10, 0x0F
	sub.32 r1, r10 ; subtract delta
	cmp.32 r1, 113 ; clamp to highest note
	iflt mov.32 r1, 113 ; B-3 period 856
	mov.32 [r28], r1
	rjmp mt_next
mt_e_fine_porta_dn:
	mov.32 r28, mod_channel_period
	mov.32 r29, r31
	sla.32 r29, 2
	add.32 r28, r29
	mov.32 r1, [r28]
	mov.32 r10, r4
	and.32 r10, 0x0F
	add.32 r1, r10 ; add delta
	cmp.32 r1, 856 ; clamp to lowest note
	ifgt mov.32 r1, 856 ; C-1 period 856
	mov.32 [r28], r1
	rjmp mt_next
mt_e_fine_vol_up:
	mov.32 r10, mod_channel_volume
	add.32 r10, r31
	movz.8 r0, [r10]
	mov.32 r11, r4
	and.32 r11, 0x0F
	add.32 r0, r11
	cmp.32 r0, 64
	ifgt mov.32 r0, 64
	mov.8 [r10], r0
	rjmp mt_had_effect
mt_e_fine_vol_dn:
	mov.32 r10, mod_channel_volume
	add.32 r10, r31
	movz.8 r0, [r10]
	mov.32 r11, r4
	and.32 r11, 0x0F
	cmp.32 r0, r11
	iflt mov.32 r0, r11
	sub.32 r0, r11
	mov.8 [r10], r0
	rjmp mt_had_effect
mt_e_pattern_loop:
	cmp.8 [mod_counter], 0
	ifgt rjmp mt_no_effect
	mov.32 r28, mod_channel_param
	add.32 r28, r31
	movz.8 r4, [r28]
	mov.32 r10, r4
	and.32 r10, 0x0F
	mov.32 r28, mod_channel_loop_cnt
	add.32 r28, r31
	movz.8 r11, [r28]
	cmp.32 r10, 0
	ifz rjmp mt_e_set_loop_marker
mt_e_do_loop:
	cmp.32 r11, 0
	ifnz rjmp mt_e_check_loop_rem
	mov.8 [r28], r10
	rjmp mt_e_jump_to_marker
mt_e_check_loop_rem:
	dec.8 r11, 1
	mov.8 [r28], r11
	cmp.8 r11, 0
	ifz rjmp mt_no_effect
mt_e_jump_to_marker:
	mov.32 r28, mod_channel_loop_row
	add.32 r28, r31
	movz.8 r0, [r28]
	dec.8 r0, 1
	mov.8 [mod_position], r0
	rjmp mt_had_effect
mt_e_set_loop_marker:
	mov.32 r28, mod_channel_loop_row
	add.32 r28, r31
	movz.8 r0, [mod_position]
	mov.8 [r28], r0
	rjmp mt_had_effect
mt_e_pattern_delay:
	mov.32 r10, r4
	and.32 r10, 0x0F
	mov.8 [mod_pattern_delay], r10
	rjmp mt_had_effect
mt_e_retrig_note:
	mov.32 r10, r4
	and.32 r10, 0x0F
	ifz rjmp mt_no_effect
	movz.8 r11, [mod_speed]
	movz.8 r12, [mod_counter]
	sub.32 r11, r12
	ifz rjmp mt_no_effect
	div.32 r11, r10
	cmp.32 r1, 0
	ifnz rjmp mt_no_effect
	rjmp mt_trigger
mt_volslide:
	;cmp.8 r4, 0
	;ifz rjmp mt_had_effect
	;mov.32 r28, mod_channel_vol_slide
	;add.32 r28, r31
	;mov.8 [r28], r4
	rjmp mt_had_effect
mt_speed:
	cmp.8 r4, 0x1F
	ifgt rjmp mt_tempo
	mov.8 [mod_speed], r4
	rjmp mt_had_effect
mt_tempo:
	and.32 r4, 0xFF
	mov.16 [mod_bpm], r4
	rjmp mt_had_effect
mt_volume:
	mov.32 r20, mod_channel_volume
	add.32 r20, r31
	cmp.32 r4, 64
	ifgt mov.32 r4, 64
	mov.8 [r20], r4
	rjmp mt_had_effect
mt_pattbreak:
	mov.32 r10, r4 ; BCD integers :broken_heart:
	srl.32 r10, 4
	and.32 r10, 0x0F ; high Nibble
	mul.32 r10, 10 ; high Nibble * 10
	mov.32 r11, r4
	and.32 r11, 0x0F ; low nibble
	add.32 r10, r11
	cmp.32 r10, 63
	ifgt mov.32 r10, 63
	mov.8 [mod_break_row], r10
	rjmp mt_had_effect
mt_posjump:
	mov.8 [mod_next_order], r4
	mov.8 [mod_position], 64 ; force new pattern
	rjmp mt_had_effect
mt_had_effect:
mt_no_effect:
	mov.32 r10, mod_channel_volume ; get virtual volume
	add.32 r10, r31
	movz.8 r19, [r10]
	sla.32 r19, 2 ; scale to 8-bit
	cmp.32 r19, 255
	ifgt mov.32 r19, 255
	
	; handle channel mask
	bts.8 [mod_chan_mask], r31
	ifz mov.32 r19, 0
	
	;cmp.32 r31, 2
	cmp.32 r31, 1
	ifz rjmp mt_pan_right
	cmp.32 r31, 2
	ifz rjmp mt_pan_right
mt_pan_left:
	mov.32 r18, r19 ; copy volume
	srl.32 r18, 2 ; divide by 4 (~25% volume for right side)
	sla.32 r19, 8 ; shift original to left side (~100% volume)
	and.32 r19, 0xFF00
	or.32 r19, r18
	rjmp mt_apply_volume
mt_pan_right:
	mov.32 r18, r19 ; copy volume
	srl.32 r18, 2 ; divide by 4 (~25% volume for left side)
	sla.32 r18, 8 ; shift to left side
	and.32 r19, 0x00FF ; original right side (~100% volume)
	or.32 r19, r18
mt_apply_volume:
	mov.32 r28, r30
	add.32 r28, 6
	out r28, r19 ; new volume
	cmp.8 r3, 0x03
	ifz rjmp mt_trigger
	cmp.8 r3, 0x05
	ifz rjmp mt_trigger
	cmp.32 r1, 0 ; new note?
	ifz rjmp mt_next
mt_trigger:
	; get stored period
	mov.32 r28, mod_channel_period
	mov.32 r29, r31
	sla.32 r29, 2
	add.32 r28, r29
	mov.32 r1, [r28]
	cmp.32 r1, 0
	ifz rjmp mt_next
	mov.32 r17, MAGIC_CONST ; magic number spooky
	;mov.32 r17, 4888164 ; magic number spooky
	div.32 r17, r1 ; native fox32 frequency
	; get active sample
	mov.32 r10, mod_channel_sample
	add.32 r10, r31
	movz.8 r23, [r10]
	; fine-tune calculation
	mov.32 r10, mod_sample_finetune
	add.32 r10, r23 ; sample fine-tune in r10
	movz.8 r10, [r10]
	mov.32 r11, mod_finetune_table
	sla.32 r10, 2
	add.32 r11, r10
	mov.32 r12, [r11] ; 16.16 fraction
	mul.32 r17, r12 ; freq * finetune
	srl.32 r17, 16 ; /65536
	mov.32 r28, r30
	add.32 r28, 4
	out r28, r17 ; rate
	cmp.8 r3, 0x03 ; tone portamento should skip control
	ifz rjmp mt_next
	cmp.8 r3, 0x05 ; tone portamento should skip control
	ifz rjmp mt_next
mt_control:
	mov.32 r22, mod_channel_loop ; looped sample / one-shot
	add.32 r22, r31
	movz.8 r18, [r22]
	or.32 r18, 0x017F ; or bit 8 into control word
	mov.32 r28, r30
	add.32 r28, 5
	out r28, r18 ; control
mt_next:
	mov.32 r28, 0
	add.32 r9, 4 ; next channel
	add.32 r31, 1
	cmp.32 r31, 4 ; all 4 channels?
	iflt rjmp mt_ch_loop
	mov.8 r0, [mod_speed]
	dec.8 r0, 1
	mov.8 [mod_counter], r0 ; reload speed counter
	; check EEx pattern delay
	cmp.8 [mod_pattern_delay], 0
	ifz rjmp mt_no_patt_delay
	dec.8 [mod_pattern_delay], 1
	mov.8 [mod_pattern_delay_active], 1
	rjmp mt_advance_row_only
mt_no_patt_delay:
	mov.8 [mod_pattern_delay_active], 0
mt_advance_row_only:
	cmp.8 [mod_break_row], 0xFF ; FF = no break pending
	ifnz rjmp mt_do_pattern_break
	movz.8 r0, [mod_position] ; load row position
	add.8 r0, 1
	cmp.8 r0, 64 ; only 64 rows, so check here
	iflt rjmp mt_no_wrap
	mov.8 r0, 0 ; wrap around and get new pattern
	;rjmp mt_advance_order
mt_advance_order:
	mov.8 [mod_position], r0
	; check if Bxx was executed
	cmp.8 [mod_next_order], 0xFF
	ifnz rjmp mt_jump_order
	movz.8 r1, [mod_order_pos]
	; increment order
	add.8 r1, 1
	cmp.8 r1, [mod_songlen]
	ifgteq mov.8 r1, 0 ; wrap if exceed the song length
	mov.8 [mod_order_pos], r1
	call mt_play_pattern
	rjmp mt_ret
mt_jump_order:
	mov.8 r1, [mod_next_order]
	mov.8 [mod_next_order], 0xFF   ; consume the jump flag
	mov.8 [mod_order_pos], r1
	call mt_play_pattern
	rjmp mt_ret
mt_no_wrap:
	mov.8 [mod_position], r0
	rjmp mt_ret
mt_do_pattern_break:
	movz.8 r0, [mod_break_row] ; get target row
	mov.8 [mod_break_row], 0xFF ; reset
	rjmp mt_advance_order

mt_handle_pattern_delay:
	mov.8 r0, [mod_speed]
	dec.8 r0, 1
	mov.8 [mod_counter], r0
	cmp.8 [mod_pattern_delay], 0
	ifz rjmp mt_stop_patt_delay
	dec.8 [mod_pattern_delay], 1
	rjmp mt_ret
mt_stop_patt_delay:
	mov.8 [mod_pattern_delay_active], 0
	rjmp mt_ret

mt_tick:
	dec.8 [mod_counter], 1
	; effect handling begins here
	mov.32 r31, 0 ; channel count
mt_tick_ch_loop:
	; EDx handling
	mov.32 r28, mod_channel_delay_tick
	add.32 r28, r31
	movz.8 r10, [r28]
	ifz rjmp mt_no_edx_tick
	
	movz.8 r11, [mod_speed]
	dec.8 r11, 1
	movz.8 r12, [mod_counter]
	sub.32 r11, r12
	cmp.32 r11, r10 ; current tick = target tick
	ifnz rjmp mt_no_edx_tick
	
	mov.8 [r28], 0 ; clear pending delay
	mov.32 r28, mod_channel_delay_row
	mov.32 r29, r31
	sla.32 r29, 2
	add.32 r28, r29
	mov.32 r0, [r28]
	call mt_parse_row
	
	mov.32 r30, AUDIO_CHANNEL_START
	mov.32 r29, r31
	sla.32 r29, 4
	add.32 r30, r29
	
	cmp.32 r2, 0 ; sample number specified?
	ifz rjmp mt_edx_no_ins
	
	; do the sample loading thing
	; code duplication and DRY be damned
	mov.32 r10, mod_sample_start
	mov.32 r11, mod_sample_end
	sub.32 r2, 1
	mov.32 r23, r2
	mov.32 r28, mod_channel_sample
	add.32 r28, r31
	mov.8 [r28], r23
	sla.32 r2, 2
	add.32 r10, r2
	add.32 r11, r2
	mov.32 r12, [r10]
	mov.32 r13, [r11]
	
	mov.32 r10, mod_loop_start
	mov.32 r11, mod_loop_end
	add.32 r10, r2
	add.32 r11, r2
	mov.32 r14, [r10]
	mov.32 r15, [r11]
	
	out r30, r12 ; start
	mov.32 r28, r30
	inc.32 r28, 1
	out r28, r13 ; end
	inc.32 r28, 1
	out r28, r14 ; loop start
	inc.32 r28, 1
	out r28, r15 ; loop end
	
	mov.32 r20, mod_sample_vol
	add.32 r20, r23
	mov.32 r21, mod_channel_volume
	add.32 r21, r31
	movz.8 r0, [r20]
	mov.8 [r21], r0
mt_edx_no_ins:
	mov.32 r28, mod_channel_sample
	add.32 r28, r31
	movz.8 r23, [r28] ; carry forward the currently active sample

	mov.32 r10, mod_sample_start
	mov.32 r11, mod_sample_end
	mov.32 r2, r23
	sla.32 r2, 2
	add.32 r10, r2
	add.32 r11, r2
	mov.32 r12, [r10]
	mov.32 r13, [r11]

	mov.32 r10, mod_loop_start
	mov.32 r11, mod_loop_end
	add.32 r10, r2
	add.32 r11, r2
	mov.32 r14, [r10]
	mov.32 r15, [r11]

	out r30, r12 ; start
	mov.32 r28, r30
	inc.32 r28, 1
	out r28, r13 ; end
	inc.32 r28, 1
	out r28, r14 ; loop start
	inc.32 r28, 1
	out r28, r15 ; loop end
	
	cmp.32 r1, 0
	ifz rjmp mt_no_edx_tick
	
	mov.32 r28, mod_channel_period
	mov.32 r29, r31
	sla.32 r29, 2
	add.32 r28, r29
	mov.32 [r28], r1
	
	mov.32 r10, mod_channel_volume
	add.32 r10, r31
	movz.8 r19, [r10]
	sla.32 r19, 2
	cmp.32 r19, 255
	ifgt mov.32 r19, 255
	
	cmp.32 r31, 1
	ifz rjmp mt_edx_pan_right
	cmp.32 r31, 2
	ifz rjmp mt_edx_pan_right
mt_edx_pan_left:
	mov.32 r18, r19
	srl.32 r18, 2
	sla.32 r19, 8
	and.32 r19, 0xFF00
	or.32 r19, r18
	rjmp mt_edx_apply_vol
mt_edx_pan_right:
	mov.32 r18, r19
	sla.32 r18, 8
	and.32 r18, 0xFF00
	srl.32 r18, 2
	and.32 r19, 0x00FF
	or.32 r19, r18
mt_edx_apply_vol:
	mov.32 r28, r30
	add.32 r28, 6
	out r28, r19
	
	mov.32 r17, MAGIC_CONST
	div.32 r17, r1
	mov.32 r10, mod_channel_sample
	add.32 r10, r31
	movz.8 r23, [r10]
	mov.32 r10, mod_sample_finetune
	add.32 r10, r23
	movz.8 r10, [r10]
	mov.32 r11, mod_finetune_table
	sla.32 r10, 2
	add.32 r11, r10
	mov.32 r12, [r11]
	mul.32 r17, r12
	srl.32 r17, 16
	
	mov.32 r28, r30
	add.32 r28, 4
	out r28, r17
	
	mov.32 r22, mod_channel_loop
	add.32 r22, r31
	movz.8 r18, [r22]
	or.32 r18, 0x017F
	mov.32 r28, r30
	add.32 r28, 5
	out r28, r18
mt_no_edx_tick:
	mov.32 r28, mod_channel_effect
	add.32 r28, r31
	movz.8 r3, [r28]
	
	cmp.8 r3, 0x0A
	ifz rjmp mt_tick_volume_slide
	cmp.8 r3, 0x05
	ifz rjmp mt_tick_volume_slide
	cmp.8 r3, 0x06
	ifz rjmp mt_tick_volume_slide
	
	cmp.8 r3, 0x03
	ifz rjmp mt_tick_portamento
	cmp.8 r3, 0x01
	ifz rjmp mt_tick_slide_up
	cmp.8 r3, 0x02
	ifz rjmp mt_tick_slide_down
	cmp.8 r3, 0x0A
	ifz rjmp mt_tick_volume_slide
	cmp.8 r3, 0x04
	ifz rjmp mt_tick_vibrato
	cmp.8 r3, 0x00
	ifz rjmp mt_tick_arpeggio
	cmp.8 r3, 0x0E
	ifz rjmp mt_tick_extra
	rjmp mt_tick_next_ch
mt_tick_arpeggio:
	movz.8 r11, [mod_speed]
	movz.8 r12, [mod_counter]
	sub.32 r11, r12
mt_arp_mod3:
	cmp.32 r11, 3
	iflt rjmp mt_arp_phase
	sub.32 r11, 3
	rjmp mt_arp_mod3
mt_arp_phase:
	mov.32 r28, mod_channel_period
	mov.32 r29, r31
	sla.32 r29, 2
	add.32 r28, r29
	mov.32 r1, [r28]
	cmp.32 r11, 0
	ifz rjmp mt_tick_recalc_pitch
	mov.32 r28, mod_channel_param
	add.32 r28, r31
	movz.8 r4, [r28]
	cmp.32 r11, 1
	ifz rjmp mt_arp_x
mt_arp_y:
	and.32 r4, 0x0F
	rjmp mt_arp_apply
mt_arp_x:
	srl.32 r4, 4
	and.32 r4, 0x0F
mt_arp_apply:
	ifz rjmp mt_tick_recalc_pitch
	mov.32 r5, 0
	mov.32 r6, mt_arp_period_table
mt_arp_find_loop:
	movz.16 r7, [r6]
	cmp.32 r1, r7
	ifgteq rjmp mt_arp_found
	inc.32 r5, 1
	add.32 r6, 2
	cmp.32 r5, 36
	iflt rjmp mt_arp_find_loop
	dec.32 r5, 1
mt_arp_found:
	add.32 r5, r4
	cmp.32 r5, 35
	ifgt mov.32 r5, 35
	mov.32 r6, mt_arp_period_table
	sla.32 r5, 1
	add.32 r6, r5
	movz.16 r1, [r6]
	rjmp mt_tick_recalc_pitch	 ; Jump to engine's pitch register writer

mt_tick_extra:
	mov.32 r28, mod_channel_param
	add.32 r28, r31
	movz.8 r4, [r28]
	
	mov.32 r10, r4
	srl.32 r10, 4
	and.32 r10, 0x0F ; extract E command sub-type
	cmp.32 r10, 0x09 ; E9x
	ifz rjmp mt_tick_retrig
	cmp.32 r10, 0x0C ; ECx
	ifz rjmp mt_tick_notecut
	rjmp mt_tick_next_ch
mt_tick_notecut:
	movz.8 r11, [mod_speed]
	dec.8 r11, 1
	movz.8 r12, [mod_counter]
	sub.32 r11, r12			 ; r11 = current tick
	mov.32 r10, r4
	and.32 r10, 0x0F		  ; r10 = x
	cmp.32 r11, r10
	ifnz rjmp mt_tick_next_ch
	mov.32 r10, mod_channel_volume
	add.32 r10, r31
	mov.8 [r10], 0			   ; cut volume
	mov.32 r30, AUDIO_CHANNEL_START
	mov.32 r29, r31
	sla.32 r29, 4
	add.32 r30, r29
	
	mov.32 r19, 0
	mov.32 r28, r30
	add.32 r28, 6
	out r28, r19
	rjmp mt_tick_next_ch
mt_tick_retrig:
	movz.8 r11, [mod_speed]
	dec.8 r11, 1
	movz.8 r12, [mod_counter]
	sub.32 r11, r12	 ; r11 = current tick
	
	mov.32 r10, r4
	and.32 r10, 0x0F ; r10 = retrigger interval 
	ifz rjmp mt_tick_next_ch ; if interval == 0, don't retrigger
mt_tick_retrig_mod:
	cmp.32 r11, r10
	iflt rjmp mt_tick_retrig_check
	sub.32 r11, r10
	rjmp mt_tick_retrig_mod
	
mt_tick_retrig_check:
	cmp.32 r11, 0
	ifnz rjmp mt_tick_next_ch
	
	mov.32 r30, AUDIO_CHANNEL_START
	mov.32 r29, r31
	sla.32 r29, 4
	add.32 r30, r29
	
	mov.32 r10, mod_channel_sample
	add.32 r10, r31
	movz.8 r2, [r10]
	
	mov.32 r10, mod_sample_start
	mov.32 r11, mod_sample_end
	sla.32 r2, 2
	add.32 r10, r2
	add.32 r11, r2
	mov.32 r12, [r10]
	mov.32 r13, [r11]
	
	mov.32 r10, mod_loop_start
	mov.32 r11, mod_loop_end
	add.32 r10, r2
	add.32 r11, r2
	mov.32 r14, [r10]
	mov.32 r15, [r11]
	
	out r30, r12 ; start
	mov.32 r28, r30
	inc.32 r28, 1
	out r28, r13 ; end
	inc.32 r28, 1
	out r28, r14 ; loop start
	inc.32 r28, 1
	out r28, r15 ; loop end
	
	mov.32 r22, mod_channel_loop
	add.32 r22, r31
	movz.8 r18, [r22]
	or.32 r18, 0x017F
	mov.32 r28, r30
	add.32 r28, 5
	out r28, r18
	
	rjmp mt_tick_next_ch	

mt_tick_vibrato:
	mov.32 r28, mod_channel_vib_cmd
	add.32 r28, r31
	movz.8 r4, [r28]
	mov.32 r5, r4 ; speed
	srl.32 r5, 4
	and.32 r5, 0x0F
	mov.32 r6, r4 ; depth
	and.32 r6, 0x0F
	
	mov.32 r28, mod_channel_vib_pos
	add.32 r28, r31
	movz.8 r7, [r28] ; get vib phase
	
	mov.32 r8, r7
	and.32 r8, 31 ; modulo 32
	mov.32 r9, mt_vibrato_sine_table
	add.32 r9, r8 ; read depth value
	movz.8 r10, [r9]
	
	mul.32 r10, r6
	srl.32 r10, 7 ; /128 - otherwise vibrato too strong
	
	mov.32 r28, mod_channel_period
	mov.32 r29, r31
	sla.32 r29, 2
	add.32 r28, r29
	mov.32 r1, [r28]
	
	and.32 r7, 32
	ifnz rjmp mt_vib_pitch_down
	
mt_vib_pitch_up:
	sub.32 r1, r10
	rjmp mt_vib_apply_limits
	
mt_vib_pitch_down:
	add.32 r1, r10
	
mt_vib_apply_limits:
	cmp.32 r1, 113
	iflt mov.32 r1, 113
	cmp.32 r1, 856
	ifgt mov.32 r1, 856

	mov.32 r28, mod_channel_vib_pos
	add.32 r28, r31
	movz.8 r7, [r28]
	add.32 r7, r5
	and.32 r7, 63
	mov.8 [r28], r7
	
	rjmp mt_tick_recalc_pitch
	
mt_tick_volume_slide:
	mov.32 r28, mod_channel_vol_slide
	add.32 r28, r31
	movz.8 r4, [r28]
	
	mov.32 r10, mod_channel_volume
	add.32 r10, r31
	movz.8 r0, [r10]

mt_tick_common_slide:
	mov.32 r1, r4
	srl.32 r1, 4
	mov.32 r2, r4
	and.32 r2, 0x0F

	cmp.32 r1, 0
	ifgt rjmp mt_vol_slide_up
	
mt_vol_slide_down:
	cmp.32 r0, r2
	iflt mov.32 r0, r2 ; vol <15? force to 15
	sub.32 r0, r2
	rjmp mt_vol_slide_save

mt_vol_slide_up:
	add.32 r0, r1
	cmp.32 r0, 64
	ifgt mov.32 r0, 64
mt_vol_slide_save:
	mov.8 [r10], r0
	movz.8 r19, r0
	sla.32 r19, 2
	cmp.32 r19, 255
	ifgt mov.32 r19, 255
	; handle channel mask
	bts.8 [mod_chan_mask], r31
	ifz mov.32 r19, 0
	mov.32 r30, AUDIO_CHANNEL_START
	mov.32 r29, r31
	sla.32 r29, 4
	add.32 r30, r29

	;cmp.32 r31, 2
	cmp.32 r31, 1
	ifz rjmp mt_tick_vol_pan_right
	cmp.32 r31, 2
	ifz rjmp mt_tick_vol_pan_right
mt_tick_vol_pan_left:
	mov.32 r18, r19
	srl.32 r18, 2 ; ~25% opposite side
	sla.32 r19, 8 ; ~100% dominant side
	and.32 r19, 0xFF00
	or.32 r19, r18
	rjmp mt_tick_vol_apply
mt_tick_vol_pan_right:
	mov.32 r18, r19
	srl.32 r18, 2
	sla.32 r18, 8 ; ~25% opposite side
	and.32 r19, 0x00FF ; ~100% dominant side
	or.32 r19, r18
mt_tick_vol_apply:
	mov.32 r28, r30
	add.32 r28, 6
	out r28, r19
	
	mov.32 r28, mod_channel_effect
	add.32 r28, r31
	movz.8 r3, [r28]

	cmp.8 r3, 0x05
	ifz rjmp mt_tick_portamento
	cmp.8 r3, 0x06
	ifz rjmp mt_tick_vibrato
	rjmp mt_tick_next_ch

mt_tick_portamento:
	mov.32 r28, mod_channel_porta
	add.32 r28, r31
	movz.8 r4, [r28]
	cmp.8 r4, 0
	ifz rjmp mt_tick_next_ch
	;cmp.8 r3, 0x03
	;ifz cmp.8 r4, 0
	;ifz rjmp mt_tick_next_ch
	mov.32 r28, mod_channel_period
	mov.32 r29, r31
	sla.32 r29, 2
	add.32 r28, r29
	mov.32 r1, [r28]
	cmp.32 r1, 0
	ifz rjmp mt_tick_next_ch
	mov.32 r26, mod_channel_target
	add.32 r26, r29
	mov.32 r2, [r26]
	cmp.32 r2, 0
	ifz rjmp mt_tick_next_ch
	cmp.32 r1, r2
	;ifz mov.32 [r26], 0
	ifz rjmp mt_tick_next_ch
	iflt rjmp mt_tp_slide_down
	ifgt rjmp mt_tp_slide_up
	rjmp mt_tick_next_ch
mt_tp_slide_up:
	mov.32 r10, r1
	sub.32 r10, r2
	cmp.32 r10, r4
	iflt mov.32 r4, r10
	sub.32 r1, r4
	mov.32 [r28], r1
	cmp.32 r1, r2
	ifz mov.32 [r26], 0
	rjmp mt_tick_recalc_pitch
mt_tp_slide_down:
	mov.32 r10, r2
	sub.32 r10, r1
	cmp.32 r10, r4
	iflt mov.32 r4, r10
	add.32 r1, r4
	mov.32 [r28], r1
	cmp.32 r1, r2
	ifz mov.32 [r26], 0
	rjmp mt_tick_recalc_pitch

mt_tick_slide_up:
	mov.32 r28, mod_channel_slide
	add.32 r28, r31
	movz.8 r4, [r28]
	
	mov.32 r28, mod_channel_period
	mov.32 r29, r31
	sla.32 r29, 2
	add.32 r28, r29
	mov.32 r1, [r28]
	sub.32 r1, r4
	
	cmp.32 r1, 113 ; PT safe upper note limit
	iflt mov.32 r1, 113
	mov.32 [r28], r1 ; store back into memory
	rjmp mt_tick_recalc_pitch

mt_tick_slide_down:
	mov.32 r28, mod_channel_slide
	add.32 r28, r31
	movz.8 r4, [r28]

	mov.32 r28, mod_channel_period
	mov.32 r29, r31
	sla.32 r29, 2
	add.32 r28, r29
	mov.32 r1, [r28]
	add.32 r1, r4
	
	cmp.32 r1, 856 ; PT safe lower note limit
	ifgt mov.32 r1, 856
	mov.32 [r28], r1
mt_tick_recalc_pitch:
	cmp.32 r1, 0
	ifz rjmp mt_tick_next_ch
	mov.32 r30, AUDIO_CHANNEL_START
	mov.32 r29, r31
	sla.32 r29, 4
	add.32 r30, r29
	
	mov.32 r17, MAGIC_CONST 
	div.32 r17, r1
	
	mov.32 r10, mod_channel_sample
	add.32 r10, r31
	movz.8 r23, [r10]
	
	mov.32 r10, mod_sample_finetune
	add.32 r10, r23
	movz.8 r10, [r10] ; fine-tune adjustments
	mov.32 r11, mod_finetune_table
	sla.32 r10, 2
	add.32 r11, r10
	mov.32 r12, [r11] 
	mul.32 r17, r12 ; perhaps this much mul/div isn't healthy
	srl.32 r17, 16
	
	mov.32 r28, r30
	add.32 r28, 4
	out r28, r17
mt_tick_next_ch:
	add.32 r31, 1
	cmp.32 r31, 4
	iflt rjmp mt_tick_ch_loop
mt_ret:
	pop r28
	pop r27
	pop r26
	pop r25
	pop r24
	pop r23
	pop r22
	pop r21
	pop r20
	pop r19
	pop r18
	pop r17
	pop r16
	pop r15
	pop r14
	pop r13
	pop r12
	pop r11
	pop r10
	pop r9
	pop r8
	pop r7
	pop r6
	pop r5
	pop r4
	pop r3
	pop r2
	pop r1
	pop r0
	ret
	
mt_parse_row:
	; accounting for little-endian architecture:
	; 01 53 1F 06 (SP PP SE AA) -> 06 1F 53 01 (AA SE PP SP)
	; extract period value
	mov.32 r1, r0
	srl.32 r1, 8
	and.32 r1, 0xFF ; lower 8 bits
	mov.32 r2, r0
	and.32 r2, 0x00F
	sla.32 r2, 8 ; upper 4 bits
	or.32 r1, r2 ; r1 - Amiga period
	mov.16 [mod_parsed_period], r1
	; extract sample number
	mov.32 r2, r0
	and.32 r2, 0xF0 ; upper nibble
	mov.32 r3, r0
	srl.32 r3, 16
	and.32 r3, 0xF0
	srl.32 r3, 4 ; lower nibble
	or.32 r2, r3 ; r2 - sample number
	mov.8 [mod_parsed_sample], r2
	; extract effect number
	mov.32 r3, r0
	srl.32 r3, 16
	and.32 r3, 0x0F ; r3 - effect number
	mov.8 [mod_parsed_effect], r3
	; extract effect parameter
	mov.32 r4, r0
	srl.32 r4, 24
	and.32 r4, 0xFF ; r4 - effect parameter
	mov.8 [mod_parsed_params], r4
	ret
	
	; song information
mod_songlen: data.8 0
mod_ptr: data.32 0
mod_bpm: data.16 125
	; sample table
mod_sample_start: data.fill 0, 124
mod_sample_end: data.fill 0, 124
mod_loop_start: data.fill 0, 124
mod_loop_end: data.fill 0, 124
mod_sample_vol: data.fill 0, 31
mod_sample_finetune: data.fill 0, 31
	; song properties
mod_break_row: data.8 0xFF
mod_next_order: data.8 0xFF
mod_counter: data.8 0
mod_position: data.8 0 ; row
mod_speed: data.8 6
mod_pattern_ptr: data.32 0
mod_order_pos: data.8 0
mod_chan_mask: data.8 0x0F ; 0000 4321
	; niceties
mod_parsed_period: data.16 0
mod_parsed_sample: data.8 0
mod_parsed_effect: data.8 0
mod_parsed_params: data.8 0
	; channel state
mod_channel_volume: data.fill 64, 4
mod_channel_loop: data.fill 0, 4
mod_channel_effect: data.fill 0, 4
mod_channel_param: data.fill 0, 4
mod_channel_slide: data.fill 0, 4
mod_channel_porta: data.fill 0, 4
mod_channel_period: data.fill 0, 16
mod_channel_target: data.fill 0, 16
mod_channel_sample: data.fill 0, 4
mod_channel_vol_slide: data.fill 0, 4
mod_channel_vib_pos:   data.fill 0, 4
mod_channel_vib_cmd:   data.fill 0, 4
mod_channel_delay_tick: data.fill 0, 4
mod_channel_delay_row:	data.fill 0, 16
mod_channel_offset_val: data.fill 0, 4
mod_channel_offset_mem: data.fill 0, 4 ; playback quirks be fucked >:(
mod_channel_loop_row:  data.fill 0, 4
mod_channel_loop_cnt:  data.fill 0, 4
mod_pattern_delay: data.8 0
mod_pattern_delay_active: data.8 0
mt_vibrato_sine_table:
	data.8	 0 data.8 24  data.8 49	 data.8 74	data.8 97  data.8 120 data.8 141 data.8 161
	data.8 180 data.8 197 data.8 212 data.8 224 data.8 235 data.8 244 data.8 250 data.8 253
	data.8 255 data.8 253 data.8 250 data.8 244 data.8 235 data.8 224 data.8 212 data.8 197
	data.8 180 data.8 161 data.8 141 data.8 120 data.8 97  data.8 74  data.8 49	 data.8 24
mt_arp_period_table:
	data.16 856 data.16 808 data.16 762 data.16 720 data.16 678 data.16 640 data.16 604 data.16 570 data.16 538 data.16 508 data.16 480 data.16 453
	data.16 428 data.16 404 data.16 381 data.16 360 data.16 339 data.16 320 data.16 302 data.16 285 data.16 269 data.16 254 data.16 240 data.16 226
	data.16 214 data.16 202 data.16 190 data.16 180 data.16 170 data.16 160 data.16 151 data.16 143 data.16 135 data.16 127 data.16 120 data.16 113
mod_finetune_table:
	; sample fine-tune is signed 4-bit in steps of 1/8th semitone
	; 1.007246 is approximately 96th root of 2
	; or 8th root of the 12th root of 2
	data.32 65536  ;  0:  0
	data.32 66011  ;  1: +1 (1.007246^1 * 65536)
	data.32 66489  ;  2: +2 
	data.32 66970  ;  3: +3 
	data.32 67454  ;  4: +4 
	data.32 67941  ;  5: +5 
	data.32 68432  ;  6: +6 
	data.32 68926  ;  7: +7 
	data.32 61858  ;  8: -8 (0.943874^8 * 65536)
	data.32 62306  ;  9: -7
	data.32 62757  ; 10: -6
	data.32 63212  ; 11: -5
	data.32 63670  ; 12: -4
	data.32 64131  ; 13: -3
	data.32 64596  ; 14: -2
	data.32 65064  ; 15: -1
mod_e_table_1:
	data.32 mt_e_unused ; E0x
	data.32 mt_e_fine_porta_up ; E1x
	data.32 mt_e_fine_porta_dn ; E2x
	data.32 mt_e_unused ; E3x
	data.32 mt_e_unused ; E4x
	data.32 mt_e_unused ; E5x
	data.32 mt_e_pattern_loop ; E6x
	data.32 mt_e_unused ; E7x
	data.32 mt_e_unused ; E8x
	data.32 mt_e_retrig_note ; E9x
	data.32 mt_e_fine_vol_up ; EAx
	data.32 mt_e_fine_vol_dn ; EBx
	data.32 mt_e_unused ; ECx
	data.32 mt_e_unused ; EDx
	data.32 mt_e_pattern_delay ; EEx
	data.32 mt_e_unused ; EFx