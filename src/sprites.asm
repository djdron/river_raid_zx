; The players and missiles of the river on the Next: river_raid/port/src/display.cpp
; (Game::drawRiver). On the Atari each player is one byte per scanline at one position; the
; Next's sprites are 16x16 (an Atari pixel is 2 sprite pixels, so a byte is 16; double and
; quadruple width are the sprite's scale).
; - The objects (player 3): each is a sprite (two when it has more than 16 rows) with its
;   rows in their colours, an 8-bit pattern made once and kept while it is used: pixel
;   128 + colour / 2, the sprites' palette 128-255 the Atari's colours (init_video). The
;   display leaves the objects' rows (ds_objs); when the DLI fell behind, the rows on the
;   scanlines are not all the objects' any more, and the sprites come from the scanlines.
; - The others (one colour each) are cut into runs of up to 16 lines at one position, one
;   sprite each, with a 4-bit pattern made from the lines' bytes.
; The bank colour changes next to a bridge: the Copper sets it, per line, in Layer 2's palette.
;
; Palette entries (4-bit patterns: offset * 16 + 1): the shell and the helicopter missile 17,
; the tank 33, the plane and its bullet 49; Layer 2: 0 black, 1 the bank, 2 the bank edge,
; 3 the water.
; Patterns (8-bit, 256 bytes): 0-11 the 4-bit ones, 12 a frame in turn (24 of 128 bytes);
; 4-bit 24 on the objects' (made at the start: obj_pics); 62-63 the needle and the logo
; (4-bit 124-127).

PATTERNS_HALF	equ 12			; 4-bit patterns per frame: two sets in turn
SPRITES_MAX	equ 60
OBP_FIRST	equ 2 * PATTERNS_HALF	; the objects' patterns (4-bit, obj_pics)
OBJ_BANK_A	equ 14			; the objects' sprite palette banks (obj_pics)
OBJ_BANK_B	equ 15
OBJ_ENTRIES	equ 64			; obj_lookup's entries at most
COPPER_WAIT_H	equ 40			; where in the line before a river line the Copper changes colours
SHELL_OFFSET	equ 1
TANK_OFFSET	equ 2
PLANE_OFFSET	equ 3

build_sprites:
	xor a
	ld (sb_count),a
	ld a,(sb_half)			; the set of patterns not shown now
	xor PATTERNS_HALF
	ld (sb_half),a
	ld b,high PC_BUCKETS		; (its hash table)
	jr z,1F
	inc b
1:	ld c,a
	ld a,b
	ld (sb_bpage),a
	ld a,c
	nextreg $52,INIT_PAGE		; its patterns not used yet (emit_sprite)
	ld l,a
	ld h,high PC_USED
	ld b,PATTERNS_HALF
	xor a
.unused	ld (hl),a
	inc l
	djnz .unused
	; in the order drawRiver draws them, the last on top
	call ob_list			; player 3: the objects, from their rows
	ifdef OBJCHECK
	call pc_check
	endif
	ld a,(PLANE_X)			; the plane: 14 rows from $AA
	ld hl,high PM_PLANE << 8 | $FF	; (page, mask)
	ld bc,PLANE_OFFSET		; (no conversion)
	ld de,$AA << 8 | 14
	call pm_channel
	ld a,(BULLET_Y)			; its bullet: missile 2, 1 clock a bit; 8 rows below
	dec a				; bulletY (none at 1; not above $1C)
	jr z,1F
	cp $1B
	jr nc,2F
	ld a,$1B
2:	inc a
	ld d,a
	ld e,8
	ld a,(PLANE_X)
	add a,4
	ld hl,high PM_MISSILES << 8 | $30
	ld bc,high mc_bullet << 8 | PLANE_OFFSET
	call pm_channel
1:	ld a,(TANK_Y)			; the tank: 11 rows
	ld d,a
	ld e,11
	ld a,(TANK_X)
	ld hl,high PM_TANK << 8 | $FF
	ld bc,TANK_OFFSET
	call pm_channel
	ld a,(MISSILE_Y)		; the helicopter's missile: missile 0, 2 clocks a bit; its
	cp $1C				; row (from $1C)
	jr c,1F
	ld d,a
	ld e,1
	ld a,(MISSILE_X)
	ld hl,high PM_MISSILES << 8 | $03
	ld bc,high mc_missile << 8 | SHELL_OFFSET
	call pm_channel
1:	ld a,(SHELL_Y)			; the shell: 16 rows
	ld d,a
	ld e,16
	ld a,(SHELL_X)
	ld hl,high PM_SHELL << 8 | $FF
	ld bc,SHELL_OFFSET
	call pm_channel
	jp build_copper

; A player's or a missile's rows from player-missile memory as one sprite at position A,
; normal width: page H, the bits L of each byte (a missile's), palette offset C; B: a table
; turning a missile's bits into a player's byte (0: none). Its rows: E from line D (where the
; game put it: nothing of it is anywhere else, as ds_cover_set has it), the river's lines of
; them; none if they are empty.
pm_channel:
	ld (sb_run_x),a
	ld a,d				; the lines on the river (above its top: the clip window)
	cp RIVER_FIRST + RIVER_LINES
	ret nc
	ld a,RIVER_FIRST + RIVER_LINES
	sub d
	cp e
	jr nc,1F
	ld e,a
1:	ld a,h
	ld (sb_bits),a
	ld a,c
	ld (sb_offset),a
	push bc
	ld c,l
	ld l,d
	ld b,e
	xor a
.or	or (hl)
	inc l
	djnz .or
	and c
	pop hl				; (H the table)
	ret z
	ld a,d
	sub RIVER_FIRST
	ld (sb_start),a
	ld a,e
	ld (sb_lines),a
	ld a,RIVER_FIRST
	ld (sb_off),a
	xor a
	ld (sb_run_size),a
	ld a,h				; a missile: its bits as a player's bytes (ch_bits)
	or a
	jp z,emit_sprite
	ld ixh,a			; (the table)
	ld b,e
	ld e,d
	ld l,d
	ld d,high ch_bits
	ld a,(sb_bits)
	ld h,a
.conv	ld a,(hl)
	and c
	push hl
	ld l,a
	ld a,ixh
	ld h,a
	ld a,(hl)
	pop hl
	ld (de),a
	inc l
	inc e
	djnz .conv
	ld a,high ch_bits
	ld (sb_bits),a
	jp emit_sprite

; The objects' sprites, from what the display left (ds_objs; the rows from ds_objf): each
; object's picture made at the start (obj_pics), found by its top row's shape and colour
; addresses (obj_lookup); a sprite per 16 rows, none for a piece below the river (its rows
; past the river's end the sprites' window hides: copper_panel).
ob_list:
	ld a,(ds_obj_n)
	or a
	ret z
	ld b,a
	ld hl,ds_objf
	ld (ob_fptr),hl
	ld hl,ds_objs
.obj	push bc
	ld a,(hl)
	ld (ob_line),a
	inc hl
	inc hl				; (the DLI's rows: the collisions')
	ld e,(hl)			; E: the shape's address (low; $B9xx)
	inc hl
	inc hl
	ld d,(hl)			; D: the colour's ($B7xx)
	inc hl
	inc hl
	ld a,(hl)
	ld (ob_x),a
	inc hl
	ld a,(hl)
	ld (ob_size),a
	inc hl
	push hl
	ld hl,(ob_fptr)
	ld a,(hl)
	inc hl
	ld (ob_fptr),hl
	ld (ob_left),a
	call obj_lookup
	or a
	jr z,.miss
	ld (ob_pat),a
.chunk	ld a,(ob_left)
	or a
	jr z,.next
	ld a,(ob_line)			; none whose first row is below the river (no part of it
	sub RIVER_FIRST + RIVER_LINES	; shows on the Atari; lines past 220: an object coming in
	cp 32				; at the top, above 0)
	jr c,.next
	call ob_attr
	ld hl,ob_pat
	inc (hl)
	ld a,(ob_left)
	sub 16
	jr nc,1F
	xor a
1:	ld (ob_left),a
	ld a,(ob_line)
	add a,16
	ld (ob_line),a
	jr .chunk
.miss
	ifdef TEST
	ld hl,ob_miss			; (not the top row: a DLI slip cut it; not drawn)
	inc (hl)
	endif
.next	pop hl
	pop bc
	djnz .obj
	ret

; The picture whose top row's shape byte is at $B900 + E, its colour at $B700 + D: A the
; pattern (4-bit) + its bank in bit 7, 0 none
obj_lookup:
	ld h,high obj_head
	ld l,e
	ld a,(hl)
.l	or a
	ret z
	dec a
	ld l,a
	ld h,high obj_e
	ld a,(hl)
	cp d
	jr z,.f
	ld a,l
	add a,2 * OBJ_ENTRIES
	ld l,a
	ld a,(hl)
	jr .l
.f	ld a,l
	add a,OBJ_ENTRIES
	ld l,a
	ld a,(hl)
	ret

; The attributes of a sprite of pattern ob_pat at scanline ob_line, position ob_x, size
; ob_size: X = 2 x (position - 32 - 20) (9 bits), Y = RIVER_TOP + the line's place in the
; river, the bank, 4 bits, the scale (double 2x, quadruple 4x)
ob_attr:
	ld a,(sb_count)
	cp SPRITES_MAX
	ret nc
	ld l,a
	ld h,0
	ld e,l
	ld d,h
	add hl,hl
	add hl,hl
	add hl,de
	ld de,sprite_list
	add hl,de
	ld a,(ob_x)
	sub 32 + WINDOW_FIRST
	ld e,a
	sbc a,a
	ld d,a
	ex de,hl
	add hl,hl
	ex de,hl
	ld (hl),e			; X
	inc hl
	ld a,(ob_line)
	add a,RIVER_TOP - RIVER_FIRST
	ld (hl),a			; Y
	inc hl
	ld a,(ob_pat)
	rla
	ld a,OBJ_BANK_B << 4
	jr c,2F
	ld a,OBJ_BANK_A << 4
2:	ld c,a
	ld a,d
	and 1
	or c
	ld (hl),a			; the bank, X bit 8
	inc hl
	ld a,(ob_pat)
	and $7F
	ld c,a
	srl a
	or $C0
	ld (hl),a			; visible, 5 bytes, pattern / 2
	inc hl
	ld a,c
	rrca
	rrca
	and $40
	or $80
	ld c,a				; 4 bits, the half
	ld a,(ob_size)
	and 3
	cp 1
	ld b,%00001000
	jr z,3F
	cp 3
	ld b,%00010000
	jr z,3F
	ld b,0
3:	ld a,b
	or c
	ld (hl),a
	ld hl,sb_count
	inc (hl)
	ret

; A sprite for the run: its pattern now (into the set not shown), its attributes for apply.
emit_sprite:
	ld a,(sb_count)
	cp SPRITES_MAX
	ret nc
	ld a,(sb_bits)			; the pattern's rows: sb_lines of them, then empty to 16
	ld h,a
	ld a,(sb_off)
	ld l,a
	ld a,(sb_start)
	add a,l
	ld l,a
	ld (es_src),hl
	ld a,(sb_lines)			; the hash (16 rows: rotated, XORed in turn; the empty
	ld b,a				; rows only rotate), 3 bytes a row
	ld a,16
	sub b
	ld c,a				; C: the empty rows
	add a,a
	add a,c
	add a,low .hb
	ld (.hj + 1),a
	ld a,high .hb
	adc a,0
	ld (.hj + 2),a
	xor a
.hj	jp .hb
.hb	rept 16
	rlca
	xor (hl)
	inc l
	endr
	ld e,a
	ld a,c
	and 7
	ld b,a
	ld a,e
	jr z,.hd
.rot	rlca
	djnz .rot
.hd	ld (es_hash),a			; a pattern of this set with these rows already: no need
	ld l,a				; to write one (page 7 at $4000: the patterns' rows, a hash
	ld a,(sb_bpage)			; table, which are used this frame)
	ld h,a
	ld a,(hl)
	or a
	jp z,.alloc
	dec a
	ld (sb_pattern),a
	call .rows_of
	ld a,c				; its rows: the run's, 7 bytes a row
	add a,a
	add a,a
	add a,a
	sub c
	add a,low .cb
	ld (.cj + 1),a
	ld a,high .cb
	adc a,0
	ld (.cj + 2),a
	ld de,(es_src)
.cj	jp .cb
.cb	rept 16
	ld a,(de)
	cp (hl)
	jp nz,.alloc
	inc e
	inc l
	endr
	ld a,c				; then empty
	or a
	jr z,.hit
	ld b,a
.ce	ld a,(hl)
	or a
	jp nz,.alloc
	inc l
	djnz .ce
.hit	ld a,(sb_pattern)		; used again
	ld l,a
	ld h,high PC_USED
	ld (hl),1
	jp .attributes
.alloc	ld hl,(es_src)			; a new one: its rows (and the empty ones) in es_key
	ld de,es_key
	ld a,(sb_lines)
	ld c,a
	ld b,0
	ldir
	ld a,16
	ld hl,sb_lines
	sub (hl)
	jr z,.ak
	ld b,a
	xor a
.az	ld (de),a
	inc e
	djnz .az
.ak	ld a,(sb_half)			; a pattern not used this frame, in turn
	or a
	ld hl,pc_next
	jr z,1F
	inc hl
1:	ld b,PATTERNS_HALF
.an	ld a,(hl)
	ld c,a
	inc a
	cp PATTERNS_HALF
	jr c,.an1
	xor a
.an1	ld (hl),a
	ld a,(sb_half)
	add a,c
	ld e,a
	ld d,high PC_USED
	ld a,(de)
	or a
	jr z,.an2
	djnz .an
	ret				; (none: never so many)
.an2	ld a,1
	ld (de),a
	ld a,e
	ld (sb_pattern),a
	ld l,e				; its old rows out of the hash table
	ld h,high PC_HASH
	ld c,(hl)
	ld a,(es_hash)
	ld (hl),a
	ld a,(sb_bpage)
	ld h,a
	ld l,c
	ld a,(hl)
	dec a
	cp e
	jr nz,.ev
	ld (hl),0
.ev	ld a,(es_hash)			; the new ones in
	ld l,a
	ld a,e
	inc a
	ld (hl),a
	call .rows_of
	ex de,hl
	ld hl,es_key
	ld bc,16
	ldir
	ld a,(sb_pattern)		; the pattern: slot pattern / 2, half pattern & 1
	ld c,a
	srl a
	bit 0,c
	jr z,.slot
	or $80
.slot	ld bc,$303B
	out (c),a
	ld c,$5B
	ld hl,es_key
	ld d,16
.row	ld a,(hl)
	inc l
	or a
	jr z,.empty
	push hl				; the byte's 8 pixel pairs from exp8
	push de
	ld l,a
	ld h,0
	add hl,hl
	add hl,hl
	add hl,hl
	ld de,exp8
	add hl,de
	outi
	outi
	outi
	outi
	outi
	outi
	outi
	outi
	pop de
	pop hl
	dec d
	jr nz,.row
	jr .attributes
.empty	out (c),a
	out (c),a
	out (c),a
	out (c),a
	out (c),a
	out (c),a
	out (c),a
	out (c),a
	dec d
	jr nz,.row
.attributes
	; the attributes: X = 2 * (position - 32 - 20) (9 bits, round the screen),
	; Y = RIVER_TOP + the first line
	ld a,(sb_count)
	ld l,a
	ld h,0
	ld e,l
	ld d,h
	add hl,hl
	add hl,hl
	add hl,de			; 5 bytes a sprite
	ld de,sprite_list
	add hl,de
	ld a,(sb_run_x)
	sub 32 + WINDOW_FIRST
	ld e,a
	sbc a,a				; (borrow: negative)
	ld d,a
	ex de,hl
	add hl,hl			; HL = X (9 bits)
	ex de,hl
	ld (hl),e			; X
	inc hl
	ld a,(sb_start)
	add a,RIVER_TOP
	ld (hl),a			; Y
	inc hl
	ld a,(sb_offset)
	add a,a
	add a,a
	add a,a
	add a,a
	ld b,a
	ld a,d
	and 1
	or b
	ld (hl),a			; palette offset, X bit 8
	inc hl
	ld a,(sb_pattern)
	srl a
	or $C0
	ld (hl),a			; visible, 5 bytes, pattern
	inc hl
	ld a,(sb_pattern)
	and 1
	rrca
	rrca				; N6 at bit 6
	or $80				; 4-bit pattern
	ld b,a
	ld a,(sb_run_size)		; scale: double 2x, quadruple 4x
	and 3
	cp 1
	ld c,%00001000
	jr z,.scale
	cp 3
	ld c,%00010000
	jr z,.scale
	ld c,0
.scale	ld a,b
	or c
	ld (hl),a
	ld hl,sb_count
	inc (hl)
	ret

; HL = the rows kept for pattern sb_pattern
.rows_of
	ld a,(sb_pattern)
	ld l,a
	ld h,0
	add hl,hl
	add hl,hl
	add hl,hl
	add hl,hl
	ld de,PATTERN_CACHE
	add hl,de
	ret

; The Copper's list for the frame: per river line, the bank colour where it changes, set in
; the line before (Layer 2's palette, entry 1: copper_start). The changes are the display's
; (ds_bank_ev, as ds_bank_fill goes through them): the VBI's colour from the river's first
; line, then each from its line (one at or above the line reached: from there).
build_copper:
	ld hl,cp_colour			; one colour all the way, as the list has it: only the X scroll
	ld a,(ds_bank_n)		; changes (panel_frame, apply)
	or a
	ld a,$FF
	jr nz,1F
	ld a,(colour_bank)
	cp (hl)
	ret z
1:	ld (hl),a
	ld a,1
	ld (cp_full),a
	ld de,copper_list
	ld hl,copper_start
	ld bc,copper_start_end - copper_start
	ldir
	push de
	pop ix
	ld a,(colour_bank)
	ld c,a				; C the colour from line E, B the one set (none yet: no Atari
	ld b,$FF			; colour is odd); D the changes left, HL the next
	ld e,RIVER_FIRST
	ld a,(ds_bank_n)
	ld d,a
	ld hl,ds_bank_ev
.seg	ld a,d				; the next change's line (none: the river's end)
	or a
	ld a,RIVER_FIRST + RIVER_LINES
	jr z,1F
	ld a,(hl)
	cp RIVER_FIRST + RIVER_LINES
	jr c,1F
	ld a,RIVER_FIRST + RIVER_LINES
1:	cp e
	jr c,.set
	jr z,.set
	push af
	ld a,c				; the colour on lines E to there
	cp b
	jr z,.same
	ld b,a
	ld (ix + 0),COPPER_WAIT_H * 2 | $80	; WAIT for the line before (ULA line 8 + k - 1)
	ld a,e
	add a,RIVER_TOP - 32 - 1 - RIVER_FIRST
	ld (ix + 1),a
	ld (ix + 2),$41			; MOVE $41, the Next colour of Atari colour B
	push hl
	ld l,b
	ld h,high palette
	ld a,(hl)
	pop hl
	ld (ix + 3),a
	ld a,b
	ld bc,4
	add ix,bc
	ld b,a
.same	pop af
	ld e,a
.set	ld a,d
	or a
	jr z,.end
	inc hl
	ld c,(hl)
	inc hl
	dec d
	jr .seg
.end	push ix
	pop de
	ld hl,copper_panel		; the panel and the scrolling line
	ld bc,copper_panel_end - copper_panel
	ldir
	ex de,hl
	ld (hl),$FF			; the end: a WAIT that never comes
	inc hl
	ld (hl),$FF
	inc hl
	ld de,copper_list
	or a
	sbc hl,de
	ld (copper_bytes),hl
	ret

; The tilemap's rows (NTSC): the panel's at 202, 211 and 219 (map rows 20, 22, 23; buffer rows
; 182, 191, 199 of the C++ port, 20 lines higher), the scrolling line's at 231 (map row 26):
; the Copper sets the tilemap's Y scroll for each, and its X scroll for the scrolling line.
; The panel's grey is Layer 2's, lines 201-229: its clip window goes down to there, and the
; Copper makes its 4 colours black on line 200 and the grey on 201 (apply sets them again
; below the scrolling line). Under the sprites, so the needle goes over it and the characters
; over the needle, as PRIOR 4 has it; and only the 320 dots wide, as the Atari's (the
; fallback colour, which it used to be, filled the border too).
copper_panel:				; (one of the two below: tv_setup)
	ds copper_panel_ntsc_end - copper_panel_ntsc
copper_panel_end:
copper_panel_ntsc:
	db $80 | COPPER_WAIT_H * 2, 200 - 32 - 1
	db $43, $10			; Layer 2's colours 0-3 (the index going up)
	db $40, 0
	db $41, 0, $41, 0, $41, 0, $41, 0	; black
	db $1C, 2			; the sprites' window below the river: from the line after
	db $19, 0, $19, 159		; the lowest an object's rows reach (OBJ_LAST: ob_list shows
	db $19, OBJ_LAST + 1, $19, 255	; no 16-row piece below the river), the needle and the logo
	db $80 | COPPER_WAIT_H * 2, 201 - 32 - 1
	db $40, 0
	db $41, 0, $41, 0, $41, 0, $41, 0	; grey (tv_setup: COPPER_GREY)
	db $80 | COPPER_WAIT_H * 2, 211 - 32 - 1
	db $31, 176 - 211
	db $80 | COPPER_WAIT_H * 2, 229 + 1 - 32 - 1
	db $40, 0			; the river's colours back after the grey (so a late frame,
	db $41, 0, $41, 0, $41, 0, $41, 0	; whose apply comes after the next frame's top, still
					; shows them): 0 black, 1 (the list's top sets it), 2 the
					; edge, 3 the water (apply: CP_EDGE_BACK)
	db $80 | COPPER_WAIT_H * 2, 231 - 32 - 1
	db $31, 208 - 231
	db $30, 0			; (set by panel_frame: CP_XSCROLL_BACK)
	db $80 | COPPER_WAIT_H * 2, WAIT_LINE_NTSC + 32 - 32 - 1
	db $1C, 2			; the sprites' window the river's again, for the next frame
	db $19, 0, $19, 159		; (below the logo, where apply starts)
	db $19, RIVER_TOP, $19, RIVER_TOP + RIVER_LINES - 1
copper_panel_ntsc_end:
; PAL (status_bar.cpp's layout): the panel's rows at 206, 218, 226, its grey to 239 (Layer 2's
; clip window), the scrolling line at 243. The same layout: the offsets below hold for both.
COPPER_GREY	equ 29			; the grey's 4 bytes in either, 2 apart
CP_EDGE_BACK	equ 23			; the restored edge colour's byte (the water's 2 after it)
CP_XSCROLL_BACK	equ 15			; the scrolling line's X scroll
OBJ_LAST	equ RIVER_TOP + RIVER_LINES - 1 + 15	; the lowest line an object's rows reach
					; (a 16-row piece from the river's last line at the lowest)
NEEDLE_Y_NTSC	equ $CC - RIVER_FIRST + RIVER_TOP	; the needle's first line (10 lines)
NEEDLE_Y_PAL	equ $D3 - RIVER_FIRST + RIVER_TOP
	assert NEEDLE_Y_NTSC > OBJ_LAST		; (no object's rows reach the needle)
copper_panel_pal:
	db $80 | COPPER_WAIT_H * 2, 200 - 32 - 1
	db $43, $10			; Layer 2's colours 0-3 (the index going up)
	db $40, 0
	db $41, 0, $41, 0, $41, 0, $41, 0	; black
	db $1C, 2			; the sprites' window below the river: from the line after
	db $19, 0, $19, 159		; the lowest an object's rows reach (OBJ_LAST: ob_list shows
	db $19, OBJ_LAST + 1, $19, 255	; no 16-row piece below the river), the needle and the logo
	db $80 | COPPER_WAIT_H * 2, 201 - 32 - 1
	db $40, 0
	db $41, 0, $41, 0, $41, 0, $41, 0	; grey (tv_setup: COPPER_GREY)
	db $80 | COPPER_WAIT_H * 2, 218 - 32 - 1
	db $31, 176 - 218
	db $80 | COPPER_WAIT_H * 2, 239 + 1 - 32 - 1
	db $40, 0			; the river's colours back after the grey (so a late frame,
	db $41, 0, $41, 0, $41, 0, $41, 0	; whose apply comes after the next frame's top, still
					; shows them): 0 black, 1 (the list's top sets it), 2 the
					; edge, 3 the water (apply: CP_EDGE_BACK)
	db $80 | COPPER_WAIT_H * 2, 243 - 32 - 1
	db $31, 208 - 243
	db $30, 0			; (set by panel_frame: CP_XSCROLL_BACK)
	db $80 | COPPER_WAIT_H * 2, WAIT_LINE_PAL + 32 - 32 - 1
	db $1C, 2			; the sprites' window the river's again, for the next frame
	db $19, 0, $19, 159		; (below the logo, where apply starts)
	db $19, RIVER_TOP, $19, RIVER_TOP + RIVER_LINES - 1

copper_start:				; Layer 2's palette, index 1
	db $43,$90,$40,1
	db 0,0				; (a NOP: the fallback colour is T's, see main_frame)
					; the tilemap at the panel's first row, no X scroll
	db $31,160 - 202
	db $2F,0
	db $30,0
copper_start_end:

; At the frame's start (below the river): what build_sprites made goes live.
apply:
	ld a,(show_scroll)
	nextreg $17,a
	ld bc,$303B			; the sprites' attributes from sprite 0
	xor a
	out (c),a
	ld hl,sprite_list
	ld a,(sb_count)
	ld e,a
	or a
	jr z,.hide
	ld c,$57
.attr	ld b,5
	otir				; (B counts down; OTIR leaves C)
	dec e
	jr nz,.attr
.hide	ld a,(sb_count)			; the sprites of the frame before that are not used now
	ld e,a
	ld a,(ap_shown)
	sub e
	jr c,.hidden
	jr z,.hidden
	ld b,a
	ld c,$57
	xor a
.h	out (c),a
	out (c),a
	out (c),a
	out (c),a
	djnz .h
.hidden	ld a,(sb_count)
	ld (ap_shown),a
	nextreg $43,$A0			; the colours of the shell, the tank and the plane
	nextreg $40,SHELL_OFFSET * 16 + 1
	ld a,(shell_colour)
	call .colour
	nextreg $41,a
	nextreg $40,TANK_OFFSET * 16 + 1
	ld a,$00			; COLPM1
	call .colour
	nextreg $41,a
	nextreg $40,PLANE_OFFSET * 16 + 1
	ld a,(show_player)		; COLPM2 (B542)
	or a
	ld a,$1E
	jr z,.p
	ld a,$8E
.p	call .colour
	nextreg $41,a
	nextreg $43,%10010000		; Layer 2: black (the Copper made it the panel's grey), the
	nextreg $40,0			; edge and the water (red while a bridge flashes; black while
	nextreg $41,0			; the screen is cleared)
	nextreg $40,2
	ld a,(show_edge)
	call .colour
	nextreg $41,a
	ld hl,(copper_bytes)		; and into the Copper's list, where the panel's part
	ld de,copper_list - CP_EDGE_BACK	; restores them
	add hl,de
	ld (hl),a
	push hl
	nextreg $40,3
	ld a,(show_water)
	call .colour
	nextreg $41,a
	pop hl
	inc hl
	inc hl
	ld (hl),a
	call panel_frame
	nextreg $62,0			; the Copper: stopped, the list (when it changed, or only the
	nextreg $61,0			; X scroll: its last MOVE's value), started for each frame
	ld a,(cp_full)
	or a
	jr z,.xs
	xor a
	ld (cp_full),a
	ld bc,$243B
	ld a,$60
	out (c),a
	inc b
	ld hl,copper_list
	ld de,(copper_bytes)
.cop	ld a,(hl)
	out (c),a
	inc hl
	dec de
	ld a,d
	or e
	jr nz,.cop
	jr .cs
.xs	ld de,-CP_EDGE_BACK		; the restored edge and water colours to the X scroll
	ld b,CP_EDGE_BACK - CP_XSCROLL_BACK + 1
	call .cp_send
.cs	nextreg $61,0
	nextreg $62,%11000000
	ld a,(IDLE_TIME)		; A1F5: the screen off after a long time without input
	rla
	ret nc
	nextreg $62,0			; (no Copper: the fallback colour stays black)
	nextreg $4A,0
	nextreg $15,%00010000
	nextreg $6B,%00000010
	ld bc,$123B
	xor a
	out (c),a
	ret
; B bytes of the Copper's list from DE (negative) before its end into its memory
.cp_send
	ld hl,(copper_bytes)
	add hl,de
	ld a,l
	nextreg $61,a
	ld a,h
	and 7
	nextreg $62,a
	ld de,copper_list
	add hl,de
.cps	ld a,(hl)
	nextreg $60,a
	inc hl
	djnz .cps
	ret
.colour
	ld l,a
	ld h,high palette
	ld a,(hl)
	ret

; ------------------------------------------------------------------------------------------
; The panel and the scrolling line of the frame (status_bar.cpp, drawStatusBar), as the
; frame leaves them: the tilemap's rows, tile 256, the needle's and the logo's sprites.
; Called by apply (below the scrolling line).
panel_frame:
	nextreg $52,11
	ld hl,PANEL			; the panel: 3 rows of 20 characters, each two tiles; a row
	ld de,TILE_MAP + 20 * 80	; starts 8 dots left of the screen (the first tile is its
	call .panel_row			; first character's right half) and ends 8 dots short
	ld de,TILE_MAP + 22 * 80
	call .panel_row
	ld de,TILE_MAP + 23 * 80
	call .panel_row

	; the scrolling line: 25 characters from $B800 + TEXT_LO, the first 38 - 2 x FINE_SCROLL
	; dots left of the screen. Its tiles go S dots left (the X scroll, (38 - 2 x fine) & 7),
	; the first visible half character is H0 = (38 - 2 x fine) / 8.
	ld a,(FINE_SCROLL)
	add a,a
	neg
	add a,38
	ld b,a
	and 7
	ld (pf_s),a
	ld hl,(copper_bytes)		; the Copper's X scroll for it (the list's last MOVE)
	ld de,copper_list - CP_XSCROLL_BACK
	add hl,de
	ld (hl),a
	ld a,b
	rrca
	rrca
	rrca
	and $1F
	ld (pf_h0),a
	ld a,(TEXT_LO)
	ld l,a
	ld h,high ROM_SCROLL_TEXT
	ld (pf_text),hl
	ld de,TILE_MAP + 26 * 80	; column 0: tile 256
	xor a
	ld (de),a
	inc de
	ld a,$41			; palette offset 4, tile bit 8
	ld (de),a
	inc de
	ld a,(pf_h0)			; columns 1-39: half characters H0 + 1 ...
	inc a
	ld c,a
	ld b,39
.text	ld a,c
	call .half_char			; A: character, carry: right half
	rla
	and $7F
	or 128
	ld (de),a
	inc de
	ld a,$40
	ld (de),a
	inc de
	inc c
	djnz .text
	; tile 256: column 0 is seen twice, its first S dots at the right edge (half H0 + 40),
	; the rest at the left (half H0)
	ld a,(pf_h0)
	add a,40
	call .glyph
	ld (pf_right),hl
	ld (pf_right_half),a
	ld a,(pf_h0)
	call .glyph
	ld (pf_left_half),a
	ld a,(pf_s)			; the bits of the nibble from the right edge's half
	rrca
	ld e,a
	ld d,0
	push hl
	ld hl,.masks
	add hl,de
	ld a,(hl)
	ld (pf_mask),a
	pop hl				; HL: the left half's glyph
	ld de,(pf_right)
	exx
	ld hl,TILE_256
	exx
	ld b,8
.row	ld c,(hl)			; the left's nibble
	ld a,(pf_left_half)
	call .nibble
	ld (pf_left_nibble),a
	ld a,(de)			; the right edge's
	ld c,a
	ld a,(pf_right_half)
	call .nibble
	push hl
	ld hl,pf_mask
	and (hl)
	ld c,a
	ld a,(hl)
	cpl
	ld hl,pf_left_nibble
	and (hl)
	or c
	pop hl
	exx
	ld c,a				; the nibble as 4 bytes
	ld b,4
.dots	xor a
	bit 3,c
	jr z,$+4
	ld a,$11
	ld (hl),a
	inc hl
	sla c
	djnz .dots
	exx
	inc hl
	inc de
	djnz .row

	; the needle: missile 1 at fuel / 8 + $5C (B527), rows $CC-$D5
	ld bc,$303B
	ld a,64
	out (c),a
	ld c,$57
	ld a,(FUEL)
	rrca
	rrca
	and $3E
	add a,2 * ($5C - 32 - WINDOW_FIRST)
	out (c),a			; X
	ld a,(tv_pal)			; (rows $D3-$DC on PAL)
	or a
	ld a,$CC - RIVER_FIRST + RIVER_TOP
	jr z,.ny
	ld a,$D3 - RIVER_FIRST + RIVER_TOP
.ny	out (c),a			; Y
	ld a,NEEDLE_OFFSET << 4
	out (c),a
	ld a,$C0 | 62			; visible, pattern 124
	out (c),a
	ld a,$80
	out (c),a
	ld a,(tv_pal)			; the logo: rows $DB-$E1 ($E7-$ED on PAL)
	or a
	ld a,$DB - RIVER_FIRST + RIVER_TOP
	jr z,.ly
	ld a,$E7 - RIVER_FIRST + RIVER_TOP
.ly	ld (logo_y),a
	; the logo: player 3 at quadruple width (data $FC: 6 x 4 colour clocks) at LOGO_X, player
	; 2 (data $FF) from $15 clocks right of it, a clock further left each row (B72A)
	ld a,(logo_shown)
	ld l,a
	ld h,0
	add hl,hl
	ld de,-2 * (32 + WINDOW_FIRST)
	add hl,de			; X, 9 bits
	ld de,16
	ld a,$C0 | 62			; pattern 125
	ld b,$C0
	call .logo
	ld a,$C0 | 62
	call .logo
	ld a,$C0 | 62
	call .logo
	ld de,-18
	add hl,de			; X + 30
	ld de,16
	ld a,$C0 | 63			; patterns 126, 127
	ld b,$80
	call .logo
	ld a,$C0 | 63
	ld b,$C0
	ld de,0
	jr .logo

; a logo sprite at HL (then HL + DE), pattern A / B (4-bit, N6)
.logo	push af
	ld a,l
	out (c),a
	ld a,(logo_y)
	out (c),a
	ld a,h
	and 1
	or LOGO_OFFSET << 4
	out (c),a
	pop af
	out (c),a
	ld a,b
	out (c),a
	add hl,de
	ret

; the half character A of the scrolling line: A = its character, carry set for the right half
.half_char
	push hl
	srl a
	push af
	ld hl,(pf_text)
	add a,l
	ld l,a
	jr nc,$+3
	inc h
	pop af
	ld a,(hl)
	pop hl
	ret

; HL = the glyph (8 rows at $0600) of half character A; A = 0 left, 1 right
.glyph	call .half_char
	push af
	and $3F
	ld l,a
	ld h,0
	add hl,hl
	add hl,hl
	add hl,hl
	ld de,$0600
	add hl,de
	pop af
	ld a,0
	rla
	ret

; A = 0: bits 7-4 of C, else bits 3-0, as bits 3-0
.nibble	or a
	ld a,c
	jr nz,.lo
	rrca
	rrca
	rrca
	rrca
.lo	and $0F
	ret

.masks	db %0000, %1000, %1100, %1110

; HL: 20 characters as the 40 tiles of a row at DE
.panel_row
	ld a,(hl)
	inc hl
	ld c,1
	call .entry
	ld b,19
.pc	ld a,(hl)
	inc hl
	ld c,0
	call .entry
	ld c,1
	call .entry
	djnz .pc
	xor a
	ld (de),a
	inc de
	ld (de),a
	inc de
	ret
.entry	push af				; tile: 2 x code + half; attribute: colour (bits 7-6) as
	and $3F				; the palette offset
	add a,a
	or c
	ld (de),a
	inc de
	pop af
	push af
	and $C0
	rrca
	rrca
	ld (de),a
	inc de
	pop af
	ret
