; The players and missiles of the river on the Next: river_raid/port/src/display.cpp
; (Game::drawRiver). On the Atari each player is one byte per scanline at one position; the
; Next's sprites are 16x16. So each player is cut into runs of up to 16 lines at one
; position, one sprite each, with a 4-bit pattern made from the lines' bytes (an Atari pixel
; is 2 sprite pixels, so a byte is 16; double and quadruple width are the sprite's scale).
; Player 3 changes colour every line (the DLI sets it per row of an object), and the bank
; colour changes next to a bridge: the Copper sets both, per line, in the palettes.
;
; Palette entries (4-bit patterns: offset * 16 + 1): player 3 1, the shell and the
; helicopter missile 17, the tank 33, the plane and its bullet 49; Layer 2: 0 black, 1 the
; bank, 2 the bank edge, 3 the water.

PATTERNS_HALF	equ 64			; 4-bit patterns per frame: two sets in turn
SPRITES_MAX	equ 60			; (4-bit patterns 124-127: the needle and the logo)
COPPER_WAIT_H	equ 40			; where in the line before a river line the Copper changes colours
P3_OFFSET	equ 0
SHELL_OFFSET	equ 1
TANK_OFFSET	equ 2
PLANE_OFFSET	equ 3

build_sprites:
	xor a
	ld (sb_count),a
	ld a,(sb_half)			; the set of patterns not shown now
	xor PATTERNS_HALF
	ld (sb_half),a
	nextreg $52,INIT_PAGE		; its patterns not used yet (emit_sprite)
	ld l,a
	ld h,high PC_USED
	ld b,SPRITES_MAX
	xor a
.unused	ld (hl),a
	inc l
	djnz .unused
	; in the order drawRiver draws them, the last on top
	ld a,high scan_p3		; player 3, from the DLI's record
	ld (sb_bits),a
	ld a,RIVER_FIRST
	ld (sb_off),a
	ld a,P3_OFFSET
	ld (sb_offset),a
	call p3_channel
	ld a,(PLANE_X)			; the plane
	ld hl,high PM_PLANE << 8 | $FF	; (page, mask)
	ld bc,PLANE_OFFSET		; (no conversion)
	call pm_channel
	ld a,(PLANE_X)			; its bullet: missile 2, 1 clock a bit
	add a,4
	ld hl,high PM_MISSILES << 8 | $30
	ld bc,high mc_bullet << 8 | PLANE_OFFSET
	call pm_channel
	ld a,(TANK_X)			; the tank
	ld hl,high PM_TANK << 8 | $FF
	ld bc,TANK_OFFSET
	call pm_channel
	ld a,(MISSILE_X)		; the helicopter's missile: missile 0, 2 clocks a bit
	ld hl,high PM_MISSILES << 8 | $03
	ld bc,high mc_missile << 8 | SHELL_OFFSET
	call pm_channel
	ld a,(SHELL_X)			; the shell
	ld hl,high PM_SHELL << 8 | $FF
	ld bc,SHELL_OFFSET
	call pm_channel
	jp build_copper

; A player's or a missile's lines from player-missile memory into sprites at one position
; A, normal width: page H, the bits L of each byte (a missile's), palette offset C; B: a
; table turning a missile's bits into a player's byte (0: none).
pm_channel:
	ld (sb_const_x),a
	ld a,h
	ld (sb_bits),a
	ld a,l
	ld (sb_mask),a
	ld a,c
	ld (sb_offset),a
	ld a,b
	ld (sb_conv),a
	ld a,RIVER_FIRST
	ld (sb_off),a
	jp channel

; Player 3's lines into sprites: runs of up to 16 lines at one position and size (lines
; with nothing to draw fit any run), from the DLI's record.
p3_channel:
	ld l,RIVER_FIRST		; scanline
.find	ld h,high scan_p3
.scan	ld a,(hl)
	or a
	jr nz,.run
	inc l
	ld a,l
	cp RIVER_FIRST + RIVER_LINES
	jr c,.scan
	ret
.run	ld a,l
	sub RIVER_FIRST
	ld (sb_start),a
	inc h
	ld d,(hl)			; its position
	inc h
	ld e,(hl)			; and size
	ld a,d
	ld (sb_run_x),a
	ld a,e
	ld (sb_run_size),a
	ld b,1				; lines in the run (the first fits)
	inc l
.line	ld a,b
	cp 16
	jr nc,.emit
	ld a,l
	cp RIVER_FIRST + RIVER_LINES
	jr nc,.emit
	ld h,high scan_p3
	ld a,(hl)
	or a
	jr z,.fits
	inc h
	ld a,(hl)
	cp d
	jr nz,.emit
	inc h
	ld a,(hl)
	cp e
	jr nz,.emit
.fits	inc l
	inc b
	jr .line
.emit	ld a,b
	ld (sb_lines),a
	push hl
	call emit_sprite
	pop hl
	ld a,l
	cp RIVER_FIRST + RIVER_LINES
	jr c,.find
	ret

; Another player's or missile's lines (at sb_bits, sb_off + line, the bits sb_mask) into
; sprites, at one position (sb_const_x), normal width. Lines are looked at 8 at a time; a
; missile's run is turned into a player's bytes in ch_bits (sb_conv) for emit_sprite.
channel:
	ld a,(sb_const_x)
	ld (sb_run_x),a
	xor a
	ld (sb_run_size),a
	ld a,(sb_off)
	ld l,a
	add a,RIVER_LINES
	ld (ch_end),a
	ld a,(sb_bits)
	ld h,a
	ld a,(sb_mask)
	ld c,a
.block	ld a,(ch_end)			; (may read up to 7 lines past the end: never used)
	dec a
	cp l
	ret c
	xor a
	rept 8
	or (hl)
	inc l
	endr
	and c
	jr z,.block
	ld a,l
	sub 8
	ld l,a
.find	ld a,(ch_end)
	dec a
	cp l
	ret c
	ld a,(hl)
	and c
	jr nz,.run
	inc l
	jr .find
.run	ld a,(sb_off)
	ld b,a
	ld a,l
	sub b
	ld (sb_start),a
	ld a,(ch_end)			; the run: 16 lines, or to the end
	sub l
	cp 16
	jr c,.n
	ld a,16
.n	ld (sb_lines),a
	ld b,a
	push hl
	ld a,(sb_conv)			; a missile: its bits as a player's byte
	or a
	jr z,.emit
	ld d,high ch_bits
	ld e,l
.conv	push bc
	ld a,(sb_conv)
	ld b,a
	ld a,(hl)
	and c
	ld c,a
	ld a,(bc)
	ld (de),a
	pop bc
	inc l
	inc e
	djnz .conv
	ld a,(sb_bits)
	push af
	ld a,high ch_bits
	ld (sb_bits),a
	call emit_sprite
	pop af
	ld (sb_bits),a
	jr .next
.emit	call emit_sprite
.next	pop hl
	ld a,(sb_mask)
	ld c,a
	ld a,(sb_lines)
	add a,l
	ld l,a
	ld a,(sb_bits)
	ld h,a
	jr .find

; A sprite for the run: its pattern now (into the set not shown), its attributes for apply.
emit_sprite:
	ld a,(sb_count)
	cp SPRITES_MAX
	ret nc
	ld a,(sb_bits)			; the pattern's 16 rows (then empty)
	ld h,a
	ld a,(sb_off)
	ld l,a
	ld a,(sb_start)
	add a,l
	ld l,a
	ld de,es_key
	ld a,(sb_lines)
	ld b,a
.key	ld a,(hl)
	ld (de),a
	inc l
	inc e
	djnz .key
	ld a,16
	ld hl,sb_lines
	sub (hl)
	jr z,.cache
	ld b,a
	xor a
.k0	ld (de),a
	inc e
	djnz .k0
.cache	ld hl,es_key			; a pattern of this set with these rows already: no need
	xor a				; to write one (page 7 at $4000: the patterns' rows, a hash
	ld b,16				; table, which are used this frame)
.h	rlca
	xor (hl)
	inc l
	djnz .h
	ld (es_hash),a
	ld l,a
	ld a,(sb_half)
	rlca
	rlca
	add a,high PC_BUCKETS
	ld h,a
	ld a,(hl)
	or a
	jr z,.alloc
	dec a
	ld (sb_pattern),a
	call .rows_of
	ld de,es_key
	ld b,16
.cmp	ld a,(de)
	cp (hl)
	jr nz,.alloc
	inc l
	inc e
	djnz .cmp
	ld a,(sb_pattern)		; used again
	ld l,a
	ld h,high PC_USED
	ld (hl),1
	jp .attributes
.alloc	ld a,(sb_half)			; a pattern not used this frame, in turn
	or a
	ld hl,pc_next
	jr z,.an
	inc hl
.an	ld a,(hl)
	ld c,a
	inc a
	cp SPRITES_MAX
	jr c,.an1
	xor a
.an1	ld (hl),a
	ld a,(sb_half)
	add a,c
	ld e,a
	ld d,high PC_USED
	ld a,(de)
	or a
	jr nz,.an
	ld a,1
	ld (de),a
	ld a,e
	ld (sb_pattern),a
	ld l,e				; its old rows out of the hash table
	ld h,high PC_HASH
	ld c,(hl)
	ld a,(es_hash)
	ld (hl),a
	ld a,(sb_half)
	rlca
	rlca
	add a,high PC_BUCKETS
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

; The Copper's list for the frame: per river line, the bank colour and player 3's colour
; where they change, set in the line before.
build_copper:
	ld de,copper_list
	ld hl,copper_start
	ld bc,copper_start_end - copper_start
	ldir
	ld a,$A0
	ld (bc_select),a
	ld ix,$FFFF			; IXH the bank colour, IXL player 3's set (none yet: no Atari
	ld l,RIVER_FIRST		; colour is odd); L the scanline
.line	ld h,high scan_bank
	ld a,(hl)
	cp ixh
	jr nz,.change
	ld h,high scan_p3
	ld a,(hl)
	or a
	jr z,.next
	ld h,high scan_col
	ld a,(hl)
	cp ixl
	jr nz,.change
.next	inc l
	ld a,l
	cp RIVER_FIRST + RIVER_LINES
	jr c,.line
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
.change	ld a,COPPER_WAIT_H * 2 | $80	; WAIT for the line before (ULA line 8 + k - 1)
	ld (de),a
	inc de
	ld a,l
	add a,RIVER_TOP - 32 - 1 - RIVER_FIRST
	ld (de),a
	inc de
	ld h,high scan_bank
	ld a,(hl)
	cp ixh
	jr z,.colour
	ld ixh,a			; the bank: Layer 2's palette
	ld b,$90
	call .select
	ld a,ixh
	call .move41
.colour	ld h,high scan_p3
	ld a,(hl)
	or a
	jr z,.next
	ld h,high scan_col
	ld a,(hl)
	cp ixl
	jr z,.next
	ld ixl,a			; player 3: the sprites' palette
	ld b,$A0
	call .select
	ld a,ixl
	call .move41
	jr .next
.select					; MOVE $43,B unless it is already
	ld a,(bc_select)
	cp b
	ret z
	ld a,b
	ld (bc_select),a
	ex de,hl
	ld (hl),$43
	inc hl
	ld (hl),a
	inc hl
	ex de,hl
	ret
.move41					; MOVE $41, the Next colour of Atari colour A
	push hl
	ld l,a
	ld h,high palette
	ld a,(hl)
	pop hl
	ex de,hl
	ld (hl),$41
	inc hl
	ld (hl),a
	inc hl
	ex de,hl
	ret

; The tilemap's rows (NTSC): the panel's at 202, 211 and 219 (map rows 20, 22, 23; buffer rows
; 182, 191, 199 of the C++ port, 20 lines higher), the scrolling line's at 231 (map row 26):
; the Copper sets the tilemap's Y scroll for each, and its X scroll for the scrolling line.
; The panel's grey is the fallback colour (nothing else is there: the needle goes over it,
; the characters over the needle, as PRIOR 4 has it), lines 201-229.
copper_panel:				; (one of the two below: tv_setup)
	ds copper_panel_ntsc_end - copper_panel_ntsc
copper_panel_end:
copper_panel_ntsc:
	db $80 | COPPER_WAIT_H * 2, 201 - 32 - 1
	db $4A, 0			; (grey: tv_setup)
	db $80 | COPPER_WAIT_H * 2, 211 - 32 - 1
	db $31, 176 - 211
	db $80 | COPPER_WAIT_H * 2, 230 - 32 - 1
	db $4A, 0
	db $80 | COPPER_WAIT_H * 2, 231 - 32 - 1
	db $31, 208 - 231
	db $30, 0			; (set by panel_frame)
copper_panel_ntsc_end:
; PAL (status_bar.cpp's layout): the panel's rows at 206, 218, 226, its grey to 239, the
; scrolling line at 243
copper_panel_pal:
	db $80 | COPPER_WAIT_H * 2, 201 - 32 - 1
	db $4A, 0
	db $80 | COPPER_WAIT_H * 2, 218 - 32 - 1
	db $31, 176 - 218
	db $80 | COPPER_WAIT_H * 2, 240 - 32 - 1
	db $4A, 0
	db $80 | COPPER_WAIT_H * 2, 243 - 32 - 1
	db $31, 208 - 243
	db $30, 0

copper_start:				; the sprites' palette, index 1
	db $43,$A0,$40,1
	db $4A,0			; the tilemap at the panel's first row, no X scroll
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
	nextreg $43,%10010000		; Layer 2: the edge and the water (red while a bridge flashes;
	nextreg $40,2			; black while the screen is cleared)
	ld a,(show_edge)
	call .colour
	nextreg $41,a
	nextreg $40,3
	ld a,(show_water)
	call .colour
	nextreg $41,a
	call panel_frame
	nextreg $62,0			; the Copper: stopped, the new list, started for each frame
	nextreg $61,0
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
	nextreg $61,0
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
	ld de,copper_list - 3
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
