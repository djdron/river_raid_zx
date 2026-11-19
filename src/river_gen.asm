; River Raid river generator on the Z80: river_raid/port/src/river_gen.cpp line for line.
; Addresses in comments refer to the original cartridge code ($A000-$BFFF).
;
; The state lives at the original's RAM addresses (vars.inc) and the cartridge's tables are
; read where the cartridge has them ($A000-$BFFF). Arithmetic is 8-bit with wrap-around, as
; in the original. Where the original carries the 6502's carry from one sum into the next,
; the Z80's carry does the same; for subtraction the 6502's carry is "no borrow", the Z80's
; is "borrow", so the chains below start with the opposite carry.

; ------------------------------------------------------------------------------------------
; sub $B183: the 24-bit LFSR. Feedback = bit 7 of ((B << 5) ^ B), shifted in through A, then
; A's top bit into C and C's into B.
step_lfsr:
	ld a,(RND_B)
	ld b,a
	add a,a
	add a,a
	add a,a
	add a,a
	add a,a
	xor b
	rla				; carry = feedback
	ld hl,RND_A
	rl (hl)
	ld hl,RND_C
	rl (hl)
	ld hl,RND_B
	rl (hl)
	ret

; ------------------------------------------------------------------------------------------
; sub $B194: remember where the river is (restart point), go up a level (stops at $50).
section_checkpoint:
	ld hl,CHECKPOINT
	ld de,PREV_CHECKPOINT
	ld bc,4
	ldir
	ld a,(RND_A)
	ld (CHECKPOINT),a
	ld a,(RND_B)
	ld (CHECKPOINT+1),a
	ld a,(RND_C)
	ld (CHECKPOINT+2),a
	ld a,(BANK)
	ld (CHECKPOINT+3),a
	ld a,(LEVEL)
	cp $50
	jr c,.l
	ld a,$4E
.l	inc a
	ld (LEVEL),a
	ret

; ------------------------------------------------------------------------------------------
; $A711-$A7FA: count the line; at the start of each block and section, set up what comes.
count_lines:
	ld a,(LEVEL)
	cp 9
	ld a,6
	jr c,.margin
	xor a
.margin	ld (BANK_MARGIN),a
	ld hl,LINE_IN_BLOCK
	inc (hl)
	ld a,(hl)
	cp 32
	jr nc,.new_block
	ld a,(BLOCK_FLAGS)
	and $80				; the run-up to a bridge is straight
	ret nz
	jp step_lfsr
.new_block				; $A72B
	ld (hl),0
	xor a
	ld (DECO_FLAGS),a
	ld (CORRIDOR),a
	ld a,(BLOCK_FLAGS)
	and $04
	or $10
	ld (BLOCK_FLAGS),a
	ld a,(SECTION_WIDTH)
	ld (PREV_SECTION_WIDTH),a
	ld hl,BLOCKS_LEFT
	dec (hl)
	jr z,.new_section
	ld a,(SECTIONS_LEFT)		; the second block of a section
	cp 1
	jp nz,step_lfsr
	xor a				; $A749: the last one: run-up to the bridge
	ld (BRIDGE_HIT),a
	ld a,(LEVEL)
	and 1
	ld a,$80
	jr nz,.odd
	ld a,$84
.odd	ld (BLOCK_FLAGS),a
	jp step_lfsr
.new_section				; $A75C
	ld hl,SECTIONS_LEFT
	dec (hl)
	jr nz,.no_checkpoint
	call section_checkpoint
	ld a,16
	ld (SECTIONS_LEFT),a
.no_checkpoint
	call step_lfsr
	ld a,(SECTIONS_LEFT)
	cp 1
	jr nz,.width
	xor a				; $A76F: the section ending in the bridge
	ld (ISLAND_FLAGS),a
	ld a,$0D
	ld (SECTION_WIDTH),a
	ld a,(LEVEL)
	and 1
	jr z,.even
	ld hl,CORRIDOR
	dec (hl)
.even	ld a,$36
	jr .target
.width	ld a,(LEVEL)
	and 1
	ld a,7				; odd levels: always 7
	jr nz,.set_width
	call choose_section_width
.set_width
	ld (SECTION_WIDTH),a		; $A7DC
	add a,a
	add a,a
.target					; $A7E0: the island changes towards its new width
	ld b,a
	ld a,2
	ld (BLOCKS_LEFT),a
	ld a,b
	ld (ISLAND_TARGET),a
	ld hl,ISLAND_WIDTH
	sub (hl)
	ret z
	ld c,a				; change
	ld a,b
	cp (hl)
	jr nc,.grow
	ld a,c				; shrinking: 1 per line, 2 when the change is 32 or more
	cp $E0
	ld a,$FF
	jr nc,.step
	ld a,$FE
	jr .step
.grow	ld a,c
	cp $20
	ld a,2
	jr nc,.step
	ld a,1
.step	ld (ISLAND_STEP),a
	ret

; ------------------------------------------------------------------------------------------
; $A781-$A7DB, even levels: the width code of a new section (returned in A); islands open
; and close here.
choose_section_width:
	ld a,(SECTIONS_LEFT)
	cp 2
	jr nz,.not_second_to_last
	ld a,(ISLAND_FLAGS)		; $A78D: the second-to-last section
	cp $C0
	jr z,.open_or_close		; close the island
	xor a				; $A7B2: no island before the bridge
	ld (ISLAND_FLAGS),a
	jr .random
.not_second_to_last
	ld a,(ISLAND_FLAGS)
	ld b,a
	add a,a
	xor b
	and $80
	jr z,.maybe
	ld a,b				; $A7AC: after an opening the island is there; after a closing gone
	and $40
	jr z,.gone
	ld a,$C0
.gone	ld (ISLAND_FLAGS),a
	jr .random
.maybe	ld a,(RND_A)
	and $30				; one time in four
	jr nz,.random
.open_or_close				; $A79E: a section of width 0
	ld a,(ISLAND_FLAGS)
	and $80
	jr nz,.closing
	ld a,$40
.closing
	ld (ISLAND_FLAGS),a
	xor a
	ret
.random					; $A7B6: 2..15, narrower with an island, below levels 20 and 9
	ld c,$0F
	ld a,(ISLAND_FLAGS)
	and $80
	jr z,.r1
	dec c
.r1	ld a,(LEVEL)
	cp $14
	jr nc,.r2
	dec c
.r2	ld a,(BANK_MARGIN)
	or a
	jr z,.r3
	ld c,8
.r3	ld a,(RND_A)
	and $0F
	cp 2
	jr nc,.r4
	add a,2
.r4	cp c
	ret c
	ld a,c
	ret

; ------------------------------------------------------------------------------------------
; $A7FB-$A825: the island moves toward its target width; the water narrows by twice as much.
change_island:
	ld a,(ISLAND_STEP)
	or a
	ret z
	ld c,a
	ld a,(ISLAND_WIDTH)
	ld b,a
	ld a,(ISLAND_TARGET)
	bit 7,c
	jr z,.growing
	cp b				; shrinking: reached when target >= width
	jr nc,.reached
	jr .step
.growing
	ld d,a				; growing: reached when width >= target
	ld a,b
	cp d
	jr nc,.reached
.step	ld a,b
	add a,c
	ld (ISLAND_WIDTH),a
	ld a,c
	add a,a
	ld c,a
	ld a,(WATER_WIDTH)
	sub c
	ld (WATER_WIDTH),a
	ret
.reached
	xor a
	ld (ISLAND_STEP),a
	ret

; ------------------------------------------------------------------------------------------
; $A8D2-$A95E: would one more bank step run into the object still being drawn in?
; Out: carry set = yes.
bank_hit_setup:				; Z set: no object to keep clear of
	ld a,(ENTERING_SLOT)
	cp NO_SLOT
	jr nc,.none
	ld e,a
	ld d,0
	ld hl,SLOT_TYPE
	add hl,de
	ld a,(hl)
	cp 8
	jr c,.none
	ld hl,SLOT_X
	add hl,de
	ld a,(hl)
	ld (bh_obj_x),a
	ld hl,SLOT_SIZE
	add hl,de
	ld a,(hl)
	ld (bh_obj_size),a
	ld a,(ISLAND_WIDTH)		; the island's width while it changes: the larger
	ld b,a
	ld a,(ISLAND_TARGET)
	cp b
	jr nc,.max
	ld a,b
.max	ld (bh_island),a
	ld b,a
	ld a,$40
	sub b
	add a,a
	ld (bh_gap),a
	or 1				; NZ
	ret
.none	xor a				; Z
	ret

bank_hits_left:				; the object must stay left of the edge
	call bank_hit_setup
	ret z				; (carry clear)
	ld a,(ISLAND_FLAGS)
	and $80
	jr nz,.island
	ld a,(BANK)
	ld hl,bh_gap
	add a,(hl)
	ld hl,bh_island
	add a,(hl)
	jr .edge
.island	ld a,(ISLAND_OBJ_SIDE)
	and $80
	jr z,.gap
	ld a,(BANK)			; right of the island
	add a,$80
	jr nz,.edge
.gap	ld a,(bh_gap)
	srl a
	ld hl,BANK
	add a,(hl)
	jr nz,.edge
	ld hl,bh_gap
	add a,(hl)
	ld hl,bh_island
	add a,(hl)
.edge	ld c,a
	ld a,(bh_obj_x)
	sub $17
	ld hl,BANK_MARGIN
	add a,(hl)
	ld b,a
	ld a,(bh_obj_size)
	or a
	ld a,b
	jr z,.cmp
	add a,8
.cmp	cp c
	ccf				; carry: left >= edge
	ret

bank_hits_right:			; the object must stay right of the edge
	call bank_hit_setup
	ret z
	ld a,(ISLAND_FLAGS)
	and $80
	jr nz,.island
	ld a,(BANK)
	ld hl,bh_island
	add a,(hl)
	jr .edge
.island	ld a,(ISLAND_OBJ_SIDE)
	and $80
	ld a,(BANK)
	jr z,.edge
	scf				; bank + $40 ...
	adc a,$3F
	ld hl,bh_island
	adc a,(hl)			; ... + island, with the carry of the first sum
	jr nz,.edge
	add a,(hl)
.edge	add a,2
	ld c,a
	ld a,(bh_obj_x)
	sub $20
	ld hl,BANK_MARGIN
	sub (hl)
	cp c				; carry: below the edge
	ret

; ------------------------------------------------------------------------------------------
; $A826-$A96B: the bank position for this line.
move_bank:
	ld a,(BLOCK_FLAGS)
	and $80
	jr z,.free
	xor a				; run-up to a bridge: a fixed shape
	ld (BANK_DIR),a
	ld a,(LINE_IN_BLOCK)
	ld l,a
	ld h,0
	ld de,ROM_BRIDGE_BANK_STEP
	add hl,de
	ld a,(hl)
	ld hl,BANK
	add a,(hl)
	ld (hl),a
	ret
.free	ld a,(CORRIDOR)
	or a
	jr z,.limits
	ld a,(BANK)			; pull the bank into $18..$28
	cp $18
	jr nc,.c1
	inc a
	ld (BANK),a
	ret
.c1	cp $29
	jr c,.limits
	dec a
	ld (BANK),a
	ret
.limits					; $A84F: walk limits by level
	ld d,1
	ld e,$40
	ld a,(LEVEL)
	cp 3
	jr nc,.l1
	ld d,$1C
	ld e,$24
	jr .set
.l1	ld b,a
	and 1
	jr z,.l19
	ld a,(CORRIDOR)
	or a
	jr nz,.l19
	ld a,b
	cp $0A
	jr c,.l19
	cp $14
	jr nc,.l2
	ld d,$0D
	ld e,$34
.l2	ld a,(DECO_FLAGS)		; leave room for the decoration
	or a
	jr z,.set
	and $80
	jr z,.l3
	ld d,$19
	jr .set
.l3	ld e,$28
	jr .set
.l19	ld d,$19
	ld e,$28
.set	ld a,d
	ld (BANK_MIN),a
	ld a,e
	ld (BANK_MAX),a
	ld a,(RND_C)			; $A889: random walk by the low 4 bits of C
	and $0F
	ld c,a
	ld a,(BANK_DIR)
	or a
	jr nz,.moving
	ld a,c
	cp 8
	ld a,1
	jr nc,.start
	ld a,$FF
.start	ld (BANK_DIR),a
	jr .step
.moving	ld a,c
	cp 8
	ret c				; stay
	cp $0D
	jr nz,.m1
	ld a,(BANK_DIR)			; turn round
	xor $FE
	ld (BANK_DIR),a
	jr .step
.m1	cp $0F
	jr nz,.step
	ld a,(ISLAND_FLAGS)		; stay where the river is narrow
	and $80
	ld a,$0E
	jr z,.m2
	ld a,$0D
.m2	ld hl,SECTION_WIDTH
	cp (hl)
	ret c
	ld hl,PREV_SECTION_WIDTH
	cp (hl)
	ret c
.step					; $A8C4: one step, or turn round at a limit or the new object
	ld a,(BANK_DIR)
	and $80
	jr z,.right
	ld a,(BANK)
	ld hl,BANK_MIN
	cp (hl)
	jr c,.turn
	call bank_hits_left
	jr c,.turn
	ld hl,BANK
	dec (hl)
	ret
.right	ld a,(BANK)
	ld hl,BANK_MAX
	cp (hl)
	jr nc,.turn
	call bank_hits_right
	jr c,.turn
	ld hl,BANK
	inc (hl)
	ret
.turn	ld a,(BANK_DIR)			; $A95F
	xor $FE
	ld (BANK_DIR),a
	ret

; ------------------------------------------------------------------------------------------
; $A96C-$A9D6: at the start of some blocks, a house or mountain for the bank.
start_decoration:
	ld a,(BLOCK_FLAGS)
	and $80
	ret nz
	ld a,(LINE_IN_BLOCK)
	or a
	ret nz
	ld a,(RND_C)
	and $20
	ret z
	ld a,(LEVEL)
	and 1
	jr z,.by_width
	ld a,(RND_A)
	and 7
	ld b,a
	ld l,a
	ld h,0
	ld de,ROM_DECO_OFFSET_ODD
	add hl,de
	ld c,(hl)
	bit 7,c
	jr z,.found
.by_width
	ld a,(SECTION_WIDTH)
	ld b,a
	ld a,(PREV_SECTION_WIDTH)
	cp b
	jr c,.min
	ld a,b
.min	ld b,a
	cp 2
	ret c
	ld a,(ISLAND_FLAGS)
	and $80
	jr z,.offset
	ld a,b
	cp 5
	ret c
	add a,$0B
	ld b,a
.offset	ld l,b
	ld h,0
	ld de,ROM_DECO_OFFSET_WIDTH
	add hl,de
	ld c,(hl)
.found	ld a,c
	ld (DECO_OFFSET),a
	ld l,b
	ld h,0
	ld de,ROM_DECO_WIDTH
	add hl,de
	ld a,(hl)
	ld (DECO_WIDTH),a
	ld l,a
	ld h,0
	ld de,ROM_DECO_ROWS
	add hl,de
	ld a,(hl)
	ld (DECO_ROWS),a
	ld a,(RND_C)			; $A9B1: the side, swapped when the bank there is too narrow
	and $80
	ld b,a
	jr z,.right
	ld a,(BANK)
	cp $18
	ld a,b
	jr nc,.side
	xor $80
	jr .side
.right	ld a,(BANK)
	cp $29
	ld a,b
	jr c,.side
	xor $80
.side	inc a
	ld (DECO_FLAGS),a
	ld a,(DECO_WIDTH)
	add a,a
	ld l,a
	ld h,0
	ld de,ROM_DECO_BITMAP
	add hl,de
	ld e,(hl)
	inc hl
	ld d,(hl)
	ld (DECO_BITMAP),de
	ret

; ------------------------------------------------------------------------------------------
; $AA8C-$AB75: draw the line into line_buf[0..47]. Runs of whole bytes (bank, water,
; island) with 2-byte edge pieces where they meet, plus a row of the decoration bitmap.
; Positions x are in pixels, 4 per byte; the buffer index wraps at 256 as the original's.

BANK_BYTES	equ $55
FLASH_BYTES	equ $AA
WATER_BYTES	equ $FF
ISLAND_BYTES	equ $AA

; B bytes of C from DRAW_POS on; nothing when B is 0 or above $80
dl_fill:
	ld a,b
	or a
	ret z
	cp $81
	ret nc
	ld a,(DRAW_POS)
	ld hl,(dl_seg_p)		; a piece of kind 1 from here
	ld (hl),a
	inc l
	ld (hl),1
	inc l
	ld (dl_seg_p),hl
	ld l,a
	ld h,high line_buf
.loop	ld (hl),c
	inc l
	djnz .loop
	ld a,l
	ld (DRAW_POS),a
	ret

; B bytes of the bank
dl_fill_bank:
	ld a,(dl_bank_fill)
	ld c,a
	jr dl_fill

; sub $B03B: the edge piece A (2 bytes from the table at $B800)
dl_edge:
	ld e,a
	ld d,high ROM_EDGE_PIECES
	ld a,(DRAW_POS)
	ld hl,(dl_seg_p)		; a piece of kind 0 from here
	ld (hl),a
	inc l
	ld (hl),0
	inc l
	ld (dl_seg_p),hl
	ld l,a
	ld h,high line_buf
	ld a,(de)
	ld (hl),a
	inc l
	inc e
	ld a,(de)
	ld (hl),a
	inc l
	ld a,l
	ld (DRAW_POS),a
	ret

; sub $B034: a bank edge piece; the flashing set is $10 further
dl_bank_edge:
	ld b,a
	ld a,(FLASH_LINES)
	or a
	ld a,b
	jr z,dl_edge
	add a,$10
	jr dl_edge

; sub $B01A: a row of the decoration bitmap
dl_deco_row:
	ld a,(DECO_WIDTH)
	or a
	ret z
	ld b,a
	ld a,(DRAW_POS)
	ld hl,(dl_seg_p)		; a piece of kind 2 from here
	ld (hl),a
	inc l
	ld (hl),2
	inc l
	ld (dl_seg_p),hl
	ld de,(DECO_BITMAP)
	ld a,(DRAW_POS)
	ld l,a
	ld h,high line_buf
.loop	ld a,(de)
	ld (hl),a
	inc de
	inc l
	djnz .loop
	ld (DECO_BITMAP),de
	ld a,l
	ld (DRAW_POS),a
	ret

; the pixel within the byte of x (A), as an edge piece index
edge_index:	macro
	and 3
	add a,a
	add a,a
	endm

draw_line:
	ld hl,dl_seg			; no pieces yet
	ld (dl_seg_p),hl
	call .line
	ld hl,(dl_seg_p)		; the end
	ld (hl),48
	ret
.line	xor a
	ld (DRAW_POS),a			; (no clearing: the runs are drawn one after another from
					; byte 0, and the right bank goes to byte 48)
	ld a,(FLASH_LINES)
	or a
	ld a,BANK_BYTES
	jr z,.fill
	ld a,FLASH_BYTES
.fill	ld (dl_bank_fill),a
	ld a,(ISLAND_FLAGS)
	and $80
	ld (dl_island),a
	ld a,(DECO_ROWS)		; rows of the decoration left
	ld b,a
	ld a,(LINE_IN_BLOCK)
	cp b
	sbc a,a				; $FF when lineInBlock < decoRows
	ld (dl_deco_left),a

	; the left bank up to the water; without an island the extra width is bank too
	ld a,(BANK)
	ld b,a
	ld a,(dl_island)
	or a
	ld a,b
	jr nz,.x
	ld hl,ISLAND_WIDTH
	add a,(hl)
.x	ld (dl_x),a
	srl a
	srl a
	dec a
	ld (dl_count),a
	ld a,(dl_island)
	or a
	jr nz,.left_bank
	ld a,(DECO_FLAGS)
	and $80
	jr z,.left_bank
	ld a,(dl_deco_left)
	or a
	jr z,.left_bank
	ld a,(DECO_OFFSET)		; a decoration on the left bank
	ld b,a
	call dl_fill_bank
	call dl_deco_row
	ld a,(DECO_WIDTH)
	ld b,a
	ld a,(DECO_OFFSET)
	ld c,a
	ld a,(dl_count)
	sub b
	sbc a,c
	ld (dl_count),a
.left_bank
	ld a,(dl_count)			; $AAB9
	ld b,a
	call dl_fill_bank
	ld a,(dl_x)
	edge_index
	call dl_bank_edge
	ld a,(WATER_WIDTH)		; water up to the right bank
	ld (dl_water),a
	ld a,(dl_island)
	or a
	jp z,.right_water
	ld a,(ISLAND_WIDTH)
	cp 6
	jr nc,.island
	ld b,a				; too narrow to draw: the island's width is water
	ld a,(dl_water)
	add a,b
	adc a,b
	ld (dl_water),a
	jp .right_water
.island					; $AAD2: water, the island, water
	ld a,(dl_water)
	srl a
	ld hl,dl_x
	add a,(hl)
	ld (hl),a
	srl a
	srl a
	ld hl,DRAW_POS
	sub (hl)
	ld b,a
	ld c,WATER_BYTES
	call dl_fill
	ld a,(ISLAND_WIDTH)
	cp 8
	sbc a,a				; $FF when small (< 8)
	ld (dl_small),a
	and $10
	ld b,a
	ld a,(dl_x)
	edge_index
	add a,2
	add a,b
	call dl_edge
	ld a,(dl_x)			; $AAEF: x += 2 * island width, with its carry
	ld b,a
	ld a,(ISLAND_WIDTH)
	add a,a
	adc a,b
	ld (dl_x),a
	srl a
	srl a
	ld hl,DRAW_POS
	sub (hl)
	dec a
	ld (dl_count),a
	ld a,(dl_small)
	or a
	jr z,.big
	ld a,(dl_count)
	ld b,a
	ld c,ISLAND_BYTES
	call dl_fill
	ld a,(dl_x)
	edge_index
	add a,$10
	jr .island_end
.big	ld a,(DECO_FLAGS)
	or a
	jr z,.island_bank
	ld a,(dl_deco_left)
	or a
	jr z,.island_bank
	ld a,(DRAW_POS)			; a decoration on the island
	ld b,a
	ld a,(DECO_OFFSET)
	sub b
	ld (dl_before),a
	ld b,a
	ld a,(DECO_WIDTH)
	ld c,a
	ld a,(dl_count)
	sub b
	sbc a,c
	ld (dl_count),a
	ld a,(dl_before)
	ld b,a
	call dl_fill_bank
	call dl_deco_row
.island_bank
	ld a,(dl_count)
	ld b,a
	call dl_fill_bank
	ld a,(dl_x)
	edge_index
.island_end
	call dl_edge			; $AB31
	ld a,(WATER_WIDTH)
	srl a
	ld (dl_water),a
.right_water				; $AB37: water up to the right bank
	ld a,(dl_water)
	ld hl,dl_x
	add a,(hl)
	ld (hl),a
	srl a
	srl a
	ld hl,DRAW_POS
	sub (hl)
	ld b,a
	ld c,WATER_BYTES
	call dl_fill
	ld a,(dl_x)
	edge_index
	add a,2
	call dl_bank_edge
	ld a,(DRAW_POS)			; $AB4B: the right bank to the end of the line
	ld b,a
	ld a,48
	sub b
	ld (dl_count),a
	ld a,(dl_island)
	or a
	jr nz,.right_bank
	ld a,(DECO_FLAGS)
	or a
	jr z,.right_bank
	and $80
	jr nz,.right_bank
	ld a,(dl_deco_left)
	or a
	jr z,.right_bank
	ld a,(DECO_OFFSET)		; a decoration on the right bank
	ld b,a
	ld a,(DECO_WIDTH)
	ld c,a
	ld a,(dl_count)
	sub b
	sbc a,c
	inc a
	ld b,a
	call dl_fill_bank
	call dl_deco_row
	ld a,(DECO_OFFSET)
	dec a
	ld (dl_count),a
.right_bank
	ld a,(dl_count)
	ld b,a
	jp dl_fill_bank

; ------------------------------------------------------------------------------------------
; $AB76-$ABF2: everything moves down one line; when the lowest slot leaves the screen the
; slots shift down by one.
scroll_objects:
	ld hl,FLASH_LINES
	ld a,(hl)
	or a
	jr z,.moved
	dec (hl)
.moved	ld hl,TANK_Y
	inc (hl)
	ld hl,SHELL_Y
	inc (hl)
	ld hl,MISSILE_Y
	inc (hl)
	ld hl,SLOT_Y
	ld b,SLOTS
.y	inc (hl)
	inc hl
	djnz .y
	ld a,(SLOT_Y + SLOTS - 1)
	or a
	ret nz
	ld a,(FIRST_SLOT)
	cp NO_SLOT
	ret nc
	cp SLOTS - 1
	jr nc,.shifted			; nothing below to move
	ld c,a
	ld a,SLOTS - 1
	sub c
	ld c,a				; slots firstSlot..9 move to firstSlot+1..10
	ld hl,SLOT_Y + SLOTS - 2
	call .shift
	ld hl,SLOT_X + SLOTS - 2
	call .shift
	ld hl,SLOT_FLAGS + SLOTS - 2
	call .shift
	ld hl,SLOT_KIND + SLOTS - 2
	call .shift
	ld hl,SLOT_TYPE + SLOTS - 2
	call .shift
	ld hl,SLOT_SIZE + SLOTS - 2
	call .shift
.shifted
	ld hl,SLOT_PARITY
	ld a,(hl)
	xor 1
	ld (hl),a
	ld hl,FIRST_SLOT
	inc (hl)
	ld hl,SHOOTER_SLOT
	ld a,(hl)
	cp NO_SLOT
	jr nc,.s1
	inc (hl)
.s1	ld hl,ENTERING_SLOT
	ld a,(hl)
	cp NO_SLOT
	ret nc
	inc (hl)
	ret
.shift	ld d,h
	ld e,l
	inc de
	ld b,0
	push bc
	lddr
	pop bc
	ret

; ------------------------------------------------------------------------------------------
; $AC62-$AC8B: an enemy type (in A), from the LFSR.
choose_enemy:
	ld a,(RND_B)
	and 7
	ld l,a
	ld h,0
	ld de,ROM_ENEMY_CHOICE
	add hl,de
	ld a,(hl)
	cp 7
	jr nz,.not_jet
	ld a,(LEVEL)			; jets from level 5 on
	cp 5
	ld a,7
	jr nc,.done
	ld a,$0D
	jr .done
.not_jet
	cp $0C
	jr nz,.done
	ld a,(LINE_IN_BLOCK)		; balloons at block starts, from level 3
	or a
	jr nz,.helicopter
	ld a,(LEVEL)
	cp 3
	ld a,$0C
	jr nc,.done
.helicopter
	ld a,8
.done	cp $0D
	ret nz
	ld a,5
	ld (WIDE_OBJECT),a
	ld a,$0D
	ret

; ------------------------------------------------------------------------------------------
; $AC8C-$AD28: where across the river the new object goes: po_x (relative to the bank,
; less $20), po_facing; may change po_type.
position_object:
	ld a,(SECTION_WIDTH)
	ld b,a
	ld a,(PREV_SECTION_WIDTH)
	cp b
	jr nz,.changing
	ld a,b
	ld (PLACE_WIDTH),a
	ld a,(LEVEL)
	and 1
	jr z,.even
	ld a,(WIDE_OBJECT)		; odd levels: anywhere across, at random
	or a
	ld a,$3F
	jr z,.o1
	ld a,$37
.o1	ld hl,BANK_MARGIN
	sub (hl)
	ld c,a
	ld a,(RND_A)
	and $3F
	add a,(hl)
	cp c
	jr c,.o2
	ld a,c
.o2	ld hl,ISLAND_WIDTH
	add a,(hl)
	ld (po_x),a
	ld a,(RND_A)
	and $80
	ld (po_facing),a
	ret
.even	ld a,(LEVEL)
	srl a
	ld (po_x),a
	jr .narrow_check
.changing
	cp b				; A = previous width
	jr nc,.max
	ld a,b
.max	ld (PLACE_WIDTH),a
	ld (po_x),a
.narrow_check
	ld a,(ISLAND_FLAGS)
	and $80
	ld a,$0E
	jr z,.n1
	ld a,$0D
.n1	ld hl,PLACE_WIDTH
	cp (hl)
	jr nc,.room
	ld a,(po_type)
	cp 7
	jr z,.room			; a jet flies anyway
	ld a,1				; no room: nothing
	ld (po_type),a
	ret
.room					; $ACD5: a narrow river has helicopters, not ships
	ld a,(SECTIONS_LEFT)
	cp 1
	jr nz,.n2
	ld hl,BANK_MARGIN
	inc (hl)
	inc (hl)
	jr .narrow
.n2	ld a,(ISLAND_FLAGS)
	and $80
	ld a,$0D
	jr z,.n3
	ld a,$0A
.n3	ld hl,PLACE_WIDTH
	cp (hl)
	jr nc,.sides
.narrow	ld a,(po_type)
	cp $0D
	jr nz,.sides
	xor a
	ld (WIDE_OBJECT),a
	ld a,8
	ld (po_type),a
.sides					; $ACF6: which side; D = the 6502's carry
	ld a,(PLACE_WIDTH)
	add a,a
	add a,a				; carry: bit 6 of the width
	ld c,a				; x
	ld d,0
	rl d
	ld e,0				; side: 0 random, 1 left, 2 right, 3 right of the island
	or a
	jr z,.random
	ld a,(ISLAND_FLAGS)
	and $80
	jr z,.random
	ld a,d
	rra
	ld a,c
	cpl
	adc a,$41
	ld c,a
	ld d,0
	rl d
	ld a,(RND_A)
	ld (ISLAND_OBJ_SIDE),a
	and $80
	jr nz,.left_of_island
	ld e,3
	jr .random
.left_of_island
	ld a,d
	rra
	ld a,c
	cpl
	adc a,$80
	ld c,a
	ld d,0
	rl d
	ld a,c
	or a
	jr z,.random
	ld e,1
.random	ld a,e
	or a
	jr nz,.side
	ld e,1
	ld a,(RND_A)
	and $80
	jr z,.side
	ld e,2
.side	ld a,e
	cp 1
	jr nz,.not_left
	ld a,(BANK_MARGIN)		; $AD14: from the left, facing right
	scf
	adc a,c
	ld c,a
	ld d,0
	rl d
	ld a,c
	or a
	jr z,.left_full
	ld (po_x),a
	ret
.left_full
	ld e,2
.not_left
	ld a,e
	cp 2
	jr nz,.from_right
	ld a,d				; $AD19
	rra
	ld a,c
	cpl
	adc a,$81
	ld c,a
.from_right				; $AD1D: measured from the right, facing left
	ld a,(WIDE_OBJECT)
	ld b,a
	ld a,(po_type)
	cp $0F				; borrow unless a depot
	ld a,c
	sbc a,8
	ld hl,BANK_MARGIN
	sbc a,(hl)
	inc b
	dec b
	jr z,.narrow_object
	sbc a,8
.narrow_object
	ld (po_x),a
	ld a,$80
	ld (po_facing),a
	ret

; ------------------------------------------------------------------------------------------
; $ABF3-$AD8D: every 16 lines a new object goes into the next free slot at the top.
place_object:
	ld hl,FIRST_SLOT
	dec (hl)
	ld a,(hl)
	ld (ENTERING_SLOT),a
	ld (po_slot),a
	xor a
	ld (WIDE_OBJECT),a
	ld (po_facing),a
	ld (po_x),a
	ld (po_place),a
	ld a,1				; nothing
	ld (po_type),a
	call .slot_hl
	ld de,SLOT_FLAGS
	add hl,de
	ld a,(BLOCK_FLAGS)
	ld (hl),a
	and $80
	jr z,.not_bridge
	ld a,(BLOCK_FLAGS)		; the bridge itself
	and $04
	or $D2
	ld (SECTION_BANK_COLOUR),a
	ld a,7
	ld (WIDE_OBJECT),a
	ld a,$0E
	ld (po_type),a
	ld a,(ISLAND_WIDTH)
	sub 6
	ld (po_x),a
	jr .decided
.not_bridge
	ld a,(LINE_IN_BLOCK)
	or a
	jr z,.block_start
	ld a,(LEVEL)			; mid-block: maybe an enemy, more likely higher up
	sub 8
	ld (po_x),a
	bit 7,a
	jr nz,.decided
	cp $20
	jr nc,.enemy
	add a,a
	add a,a
	add a,a
	ld (po_x),a
	ld hl,RND_B
	cp (hl)
	jr nc,.enemy
	jr .decided
.block_start				; $AC3E: an enemy or a fuel depot
	xor a
	ld (po_type),a
	ld a,(SECTIONS_LEFT)
	ld hl,BLOCKS_LEFT
	add a,(hl)
	ld (po_x),a
	cp $12
	jr nc,.decided
	ld a,(DEPOT_LEVEL_LIMIT)	; depots get rarer with the level, up to the limit
	ld b,a
	ld a,(LEVEL)
	cp b
	jr c,.l
	ld a,b
.l	ld b,a
	ld a,$3F
	sub b
	add a,a
	ld (po_x),a
	ld hl,RND_B
	cp (hl)
	jr c,.enemy
	ld a,(RND_A)
	and $40
	jr nz,.decided
	ld a,$0F
	ld (po_type),a
	jr .place
.enemy	call choose_enemy
	ld (po_type),a
.place	call position_object
.decided
	ld a,(po_facing)
	or a
	jr z,.store
	ld a,(po_type)
	cp $0F
	jr z,.store
	call .slot_hl
	ld de,SLOT_FLAGS
	add hl,de
	set 3,(hl)
.store					; $AD37
	ld a,(BANK)
	ld b,a
	ld a,(CORRIDOR)
	and $80
	jr z,.x
	ld a,b
	cp $18
	jr nc,.x1
	ld b,$18
.x1	ld a,b
	cp $29
	jr c,.x
	ld b,$28
.x	ld a,(po_x)
	add a,$20
	add a,b
	ld b,a
	call .slot_hl
	ld de,SLOT_X
	add hl,de
	ld (hl),b
	ld a,(po_type)
	ld c,a
	cp 8				; one helicopter at a time fires missiles
	jr nz,.kind
	ld a,(SHOOTER_SLOT)
	cp NO_SLOT
	jr c,.kind
	ld a,(SECTIONS_LEFT)
	cp $0E
	jr nc,.kind
	ld a,(RND_C)
	and $70
	jr nz,.kind
	ld a,(LEVEL)
	cp $0D
	jr c,.kind
	ld c,$0A
	xor a
	ld (MISSILE_X),a
	ld a,(po_slot)
	ld (SHOOTER_SLOT),a
.kind	call .slot_hl
	ld de,SLOT_KIND
	add hl,de
	ld (hl),c
	call .slot_hl
	ld de,SLOT_TYPE
	add hl,de
	ld (hl),c
	ld a,(po_type)			; height and size of the type as chosen (8 for a shooter too)
	ld c,a
	ld l,a
	ld h,0
	ld de,ROM_OBJECT_HEIGHT
	add hl,de
	ld a,(hl)
	add a,4
	ld (ENTERING_LINES),a
	ld b,a
	ld l,c
	ld h,0
	ld de,ROM_OBJECT_SIZE
	add hl,de
	ld c,(hl)
	call .slot_hl
	ld de,SLOT_SIZE
	add hl,de
	ld (hl),c
	ld a,$61
	sub b
	ld b,a
	call .slot_hl
	ld de,SLOT_Y
	add hl,de
	ld (hl),b
	ld a,(LINE_IN_BLOCK)
	ld hl,TANK_KIND
	or (hl)
	ret nz
	jp place_tank
.slot_hl
	ld a,(po_slot)
	ld l,a
	ld h,0
	ret

; ------------------------------------------------------------------------------------------
; $AD8E-$AE93: at a block start, maybe a tank on a road.
place_tank:
	ld a,(BLOCK_FLAGS)
	and $80
	jr z,.bank_road
	ld a,(RND_A)			; $ADA6: on the bridge, driving across
	and $7F
	ld b,a
	ld a,$0B
	ld (TANK_Y),a
	xor a
	ld (TANK_FIRES),a
	ld (SHELL_SPEED_FRAC),a
	ld a,2
	ld (SHELL_SPEED),a
	ld a,b
	cp $40
	ld a,6
	jr nc,.k
	ld a,5
.k	ld (TANK_KIND),a
	ld a,b
	add a,$40
	ld (TANK_X),a
	ret
.bank_road				; $ADCD
	ld a,(SECTION_WIDTH)
	ld b,a
	ld a,(PREV_SECTION_WIDTH)
	cp b
	jr c,.w
	ld a,b
.w	ld (pt_width),a
	ld a,(ENTERING_SLOT)
	ld l,a
	ld h,0
	ld de,SLOT_KIND
	add hl,de
	ld a,(hl)
	cp 8
	ret c
	ld a,(LEVEL)
	cp 7
	ret c
	ld a,(SECTIONS_LEFT)
	cp 5
	ret c
	cp $0E
	ret nc
	ld a,(RND_C)
	and $C0
	ret nz
	ld a,(pt_width)
	cp 2
	ret c
	cp $0E
	ret nc
	ld a,(RND_C)			; the shell's speed
	rrca
	rrca
	rrca
	and $1F
	ld b,a
	ld a,(LEVEL)
	cp $0A
	ld a,b
	jr nz,.s1
	xor 7
.s1	and 6
	jr nz,.s2
	ld b,a
	ld a,(ISLAND_FLAGS)
	and $80
	ld a,b
	jr nz,.s2
	ld a,(pt_width)
	cp 8
	ld a,b
	jr nc,.s2
	ld a,8
.s2	ld l,a
	ld h,0
	ld de,ROM_SHELL_SPEED
	add hl,de
	ld a,(hl)
	ld (SHELL_SPEED),a
	inc hl
	ld a,(hl)
	ld (SHELL_SPEED_FRAC),a
	ld c,5				; kind: 5 right, 6 left
	ld a,(ISLAND_FLAGS)
	and $80
	jr z,.banks
	ld a,(DECO_FLAGS)		; on the island
	or a
	ret nz
	ld a,(pt_width)
	cp $0B
	ret nc
	cp 4
	ret c
	ld a,(RND_C)
	and 1
	jr z,.i1
	inc c
.i1	ld b,$7C
	jr .set
.banks	ld a,(LEVEL)			; on the left or the right bank
	and 1
	jr z,.even
	ld a,(RND_C)
	and $1F
	cp $10
	jr c,.left
	add a,$58
	jr .right
.even	ld a,(pt_width)
	ld l,a
	ld h,0
	ld de,ROM_TANK_START_X
	add hl,de
	ld a,(hl)
	cp $50
	jr c,.left
.right	ld b,a				; mirrored when a decoration is on the right
	ld a,(DECO_FLAGS)
	or a
	jr z,.no_deco_right
	and $80
	jr nz,.no_deco_right
	ld e,1				; mirror
	jr .place
.no_deco_right
	inc c
	ld e,0
	jr .place
.left	ld b,a				; mirrored when a decoration is on the left
	ld e,0
	ld a,(DECO_FLAGS)
	and $80
	jr z,.place
	inc c
	ld e,1
.place	ld a,(LEVEL)
	and 1
	jr z,.place_even
	ld a,e
	or a
	ld a,b
	jr z,.po
	ld b,a
	ld a,$78
	sub b
.po	ld hl,BANK
	add a,(hl)
	add a,$20
	ld b,a
	jr .set
.place_even
	ld a,e
	or a
	ld a,b
	jr z,.pe
	ld b,a
	ld a,$98
	sub b
.pe	add a,$30
	ld b,a
.set	ld a,b
	ld (TANK_X),a
	ld a,c
	ld (TANK_KIND),a
	ld a,$0C
	ld (TANK_Y),a
	ld a,$FF
	ld (SHELL_TIMER),a
	ld (TANK_FIRES),a
	ret

; ------------------------------------------------------------------------------------------
; Respawn and game start: sub $B0F1 resets the river and puts a bridge at the bottom, then
; $A3C8 continues from the checkpoint.
restore_checkpoint:
	ld hl,ROM_RESET_VALUES		; $4D-$54 and $5A, $5D, $5F from the reset table
	ld de,FIRST_SLOT
	ld bc,8
	ldir
	ld a,(ROM_RESET_VALUES + BLOCKS_LEFT - FIRST_SLOT)
	ld (BLOCKS_LEFT),a
	ld a,(ROM_RESET_VALUES + SECTIONS_LEFT - FIRST_SLOT)
	ld (SECTIONS_LEFT),a
	ld a,(ROM_RESET_VALUES + SECTION_WIDTH - FIRST_SLOT)
	ld (SECTION_WIDTH),a
	xor a
	ld hl,PREV_SECTION_WIDTH	; $2C-$2F
	ld b,4
	call .clear
	ld hl,ENTERING_LINES		; $32-$3A
	ld b,9
	call .clear
	ld hl,SHELL_SPEED		; $3E-$41
	ld b,4
	call .clear
	ld hl,SLOT_KIND			; kinds, types, x, sizes
	ld b,4 * SLOTS
	call .clear
	ld hl,SLOT_FLAGS
	ld b,SLOTS
	call .clear
	ld (CORRIDOR),a
	ld a,$0E			; $B15E: the bridge we restart from, in the lowest slot
	ld (SLOT_TYPE + SLOTS - 1),a
	ld a,$17
	ld (ENTERING_LINES),a
	ld a,$4A
	ld (SLOT_Y + SLOTS - 1),a
	ld a,(LEVEL)
	and 1
	ld a,$D2
	jr z,.c
	ld a,$D6
.c	ld (SECTION_BANK_COLOUR),a
	and $84
	ld (BLOCK_FLAGS),a
	ld (SLOT_FLAGS + SLOTS - 1),a
	ld a,SLOTS - 1
	ld (FIRST_SLOT),a
	ld (ENTERING_SLOT),a
	ld hl,CHECKPOINT		; $A3C8
	ld de,RND_A
	ld bc,3
	ldir
	ld a,(hl)
	ld (BANK),a
	ret
.clear	ld (hl),a
	inc hl
	djnz .clear
	ret

; Game 1 as after START: the cartridge's first starting point (bridge 1).
start_game:
	ld hl,0				; RiverState{}: everything 0 ...
	ld de,1
	ld bc,$05FF
	ld (hl),l
	ldir
	ld a,(tv_pal)			; ... but the depot limit ($2E NTSC, $2F PAL)
	add a,$2E
	ld (DEPOT_LEVEL_LIMIT),a
	ld hl,ROM_START_CHECKPOINT
	ld de,CHECKPOINT
	ld b,4
.cp	ld a,(hl)
	ld (de),a
	inc hl
	inc hl
	inc hl
	inc hl
	inc de
	djnz .cp
	ld a,(ROM_START_LEVEL)
	ld (LEVEL),a
	jp restore_checkpoint

; ------------------------------------------------------------------------------------------
; One line: line_buf[0..47] gets its bitmap.
next_line:
	call count_lines
	call change_island
	call move_bank
	call start_decoration
	call draw_line
	call scroll_objects
	ld a,(ENTERING_SLOT)		; $ABE1: the newest object still takes up the top lines
	cp NO_SLOT
	jr nc,.free
	ld a,(ENTERING_LINES)
	or a
	jr z,.entered
	cp $81
	jr nc,.entered
	dec a
	ld (ENTERING_LINES),a
	ret
.entered
	ld a,NO_SLOT
	ld (ENTERING_SLOT),a
.free	ld a,(LINE_IN_BLOCK)
	and $0F
	ret nz
	ld a,(FIRST_SLOT)
	or a
	ret z
	call place_object
	ld hl,ENTERING_LINES		; $AE94
	dec (hl)
	ret
