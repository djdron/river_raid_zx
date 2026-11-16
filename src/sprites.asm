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
SPRITES_MAX	equ 64
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
	ld (sb_pattern),a
	; in the order drawRiver draws them, the last on top
	ld a,high scan_p3		; player 3, from the DLI's record
	ld (sb_bits),a
	ld a,RIVER_FIRST
	ld (sb_off),a
	ld a,P3_OFFSET
	ld (sb_offset),a
	call p3_channel
	ld a,1				; the others: one position, normal width
	ld (sb_const),a
	ld hl,PM_MISSILES + RIVER_FIRST	; which missiles are there at all
	call or160
	ld (sb_missiles),a
	ld hl,PM_PLANE + RIVER_FIRST	; the plane
	ld a,(PLANE_X)
	ld c,PLANE_OFFSET
	call pm_channel
	ld a,(sb_missiles)		; its bullet: missile 2, 1 clock a bit
	and $30
	jr z,.tank
	ld b,$80
	ld c,$40
	ld a,4
	call copy_missile
	ld a,(PLANE_X)
	add a,4
	ld c,PLANE_OFFSET
	call ch_channel
.tank	ld hl,PM_TANK + RIVER_FIRST	; the tank
	ld a,(TANK_X)
	ld c,TANK_OFFSET
	call pm_channel
	ld a,(sb_missiles)		; the helicopter's missile: missile 0, 2 clocks a bit
	and $03
	jr z,.shell
	ld b,$C0
	ld c,$30
	xor a
	call copy_missile
	ld a,(MISSILE_X)
	ld c,SHELL_OFFSET
	call ch_channel
.shell	ld hl,PM_SHELL + RIVER_FIRST	; the shell
	ld a,(SHELL_X)
	ld c,SHELL_OFFSET
	call pm_channel
	jp build_copper

or160:					; A = the OR of 160 bytes from HL (not crossing a page)
	xor a
	rept RIVER_LINES
	or (hl)
	inc l
	endr
	ret

pm_channel:				; a player's lines from player-missile memory at HL, if any:
	push hl				; position A, palette offset C
	push af
	call or160
	pop de
	pop hl
	ret z
	ld a,h
	ld (sb_bits),a
	ld a,l
	ld (sb_off),a
	ld a,d
	ld (sb_const_x),a
	ld a,c
	ld (sb_offset),a
	jp channel

ch_channel:				; the lines in ch_bits: position A, palette offset C
	ld (sb_const_x),a
	ld a,c
	ld (sb_offset),a
	ld a,high ch_bits
	ld (sb_bits),a
	xor a
	ld (sb_off),a
	jp channel

copy_missile:				; ch_bits = a missile's 2 bits as a player's (B: the first's,
	ld (cm_shift),a			; C: the second's), from the missiles' byte shifted right by A
	ld hl,PM_MISSILES + RIVER_FIRST
	ld de,ch_bits
	ld a,RIVER_LINES
	ld (cm_count),a
.line	ld a,(hl)
	push hl
	ld h,a
	ld a,(cm_shift)
	or a
	ld a,h
	jr z,.s
	rrca
	rrca
	rrca
	rrca
.s	ld l,0
	bit 1,a
	jr z,.b0
	ld l,b
.b0	bit 0,a
	jr z,.b1
	ld a,l
	or c
	ld l,a
.b1	ld a,l
	pop hl
	ld (de),a
	inc hl
	inc e
	ld a,(cm_count)
	dec a
	ld (cm_count),a
	jr nz,.line
	ret

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

; Another player's lines (at sb_bits, sb_off + line) into sprites, at one position
; (sb_const_x), normal width.
channel:
	ld a,(sb_const_x)
	ld (sb_run_x),a
	xor a
	ld (sb_run_size),a
	ld a,(sb_off)
	ld l,a
	add a,RIVER_LINES
	ld c,a				; the end
	ld a,(sb_bits)
	ld h,a
.scan	ld a,(hl)
	or a
	jr nz,.run
	inc l
	ld a,l
	cp c
	jr c,.scan
	ret
.run	ld a,(sb_off)
	ld b,a
	ld a,l
	sub b
	ld (sb_start),a
	ld b,16				; the run: 16 lines, or to the end
	ld a,c
	sub l
	cp b
	jr nc,.lines
	ld b,a
.lines	ld a,b
	ld (sb_lines),a
	push bc
	push hl
	call emit_sprite
	pop hl
	pop bc
	ld a,l
	add a,b
	ld l,a
	cp c
	jr c,.scan
	ret

; A sprite for the run: its pattern now (into the set not shown), its attributes for apply.
emit_sprite:
	ld a,(sb_count)
	cp SPRITES_MAX
	ret nc
	ld a,(sb_pattern)		; the pattern: slot pattern / 2, half pattern & 1
	ld c,a
	srl a
	bit 0,c
	jr z,.slot
	or $80
.slot	ld bc,$303B
	out (c),a
	ld c,$5B
	ld a,(sb_bits)
	ld h,a
	ld a,(sb_off)
	ld l,a
	ld a,(sb_start)
	add a,l
	ld l,a
	ld a,(sb_lines)
	ld e,a
	ld d,16
.row	ld a,e				; rows after the run: empty
	or a
	jr z,.empty
	dec e
	ld a,(hl)
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
.empty	xor a
	out (c),a
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
	ld hl,sb_pattern
	inc (hl)
	ret

; The Copper's list for the frame: per river line, the bank colour and player 3's colour
; where they change, set in the line before.
build_copper:
	ld de,copper_list
	ld hl,copper_start
	ld bc,4
	ldir
	ld a,$A0
	ld (bc_select),a
	ld ix,$FFFF			; IXH the bank colour, IXL player 3's set (none yet: no Atari
	ld c,0				; colour is odd); C the line
.line	ld a,c
	add a,RIVER_FIRST
	ld l,a
	ld h,high scan_bank
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
.next	inc c
	ld a,c
	cp RIVER_LINES
	jr c,.line
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
.change	ex de,hl			; WAIT for the line before (ULA line 8 + k - 1)
	ld (hl),COPPER_WAIT_H * 2 | $80
	inc hl
	ld a,c
	add a,RIVER_TOP - 32 - 1
	ld (hl),a
	inc hl
	ex de,hl
	ld a,c
	add a,RIVER_FIRST
	ld l,a
	ld h,high scan_bank
	ld a,(hl)
	cp ixh
	jr z,.colour
	ld ixh,a			; the bank: Layer 2's palette
	ld b,$90
	call .select
	ld a,ixh
	call .move41
.colour	ld a,c
	add a,RIVER_FIRST
	ld l,a
	ld h,high scan_p3
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
	ld l,a
	ld h,high palette
	ld a,(hl)
	ex de,hl
	ld (hl),$41
	inc hl
	ld (hl),a
	inc hl
	ex de,hl
	ret

copper_start:				; the sprites' palette, index 1
	db $43,$A0,$40,1

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
	ld a,(PLAYER)			; COLPM2 (B542)
	or a
	ld a,$1E
	jr z,.p
	ld a,$8E
.p	call .colour
	nextreg $41,a
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
	ret
.colour
	ld l,a
	ld h,high palette
	ld a,(hl)
	ret
