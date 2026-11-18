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

SPRITES_MAX	equ 60
OBP_FIRST	equ 24			; the objects' patterns (4-bit, obj_pics); the players' below
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
	; in the order drawRiver draws them, the last on top
	call ob_list			; player 3: the objects, from their rows
	ld a,(sb_count)			; (where the players' attributes start)
	ld (pl_first),a
	ld a,(busy)			; a reset's frames: player-missile memory as the last
	or a				; prepare left it (none runs meanwhile): the same sprites
	jp nz,pl_again
	ld a,(PLANE_FRAME)		; the plane: its frame (pl_pics, 0-9) at $AA
	ld hl,pl_plane
	call pl_pattern
	ld b,a
	ld d,$AA
	ld a,(PLANE_X)
	ld e,a
	ld c,PLANE_OFFSET
	ld a,b
	call pl_sprite
	ld a,(BULLET_Y)			; its bullet: 8 rows from bulletY (none at 1; not above $1C)
	dec a
	jr z,1F
	cp $1B
	jr nc,2F
	ld a,$1B
2:	inc a
	ld d,a
	ld a,(PLANE_X)
	add a,4
	ld e,a
	ld c,PLANE_OFFSET
	ld a,(pl_bullet)
	call pl_sprite
1:	ld a,(TANK_KIND)		; the tank: its kind's frame (0-7; bit 7 destroyed) at tankY
	and $7F
	cp 8
	jr nc,1F
	ld hl,pl_tank
	call pl_pattern
	ld b,a
	ld a,(TANK_Y)
	ld d,a
	ld a,(TANK_X)
	ld e,a
	ld c,TANK_OFFSET
	ld a,b
	call pl_sprite
1:	ld a,(MISSILE_Y)		; the helicopter's missile: its row (from $1C), while it has
	cp $1C				; a position
	jr c,1F
	ld d,a
	ld a,(MISSILE_X)
	or a
	jr z,1F
	ld e,a
	ld c,SHELL_OFFSET
	ld a,(pl_missile)
	call pl_sprite
1:	ld a,(SHELL_FRAME)		; the shell: its frame (0-6) at shellY
	cp 7
	jr nc,1F
	ld hl,pl_shell
	call pl_pattern
	ld b,a
	ld a,(SHELL_Y)
	ld d,a
	ld a,(SHELL_X)
	ld e,a
	ld c,SHELL_OFFSET
	ld a,b
	call pl_sprite
1:	call pl_keep
	jp build_copper

; The players' attributes this frame kept (pl_keep), or put again (pl_again: a reset)
pl_keep:
	ld a,(sb_count)
	ld hl,pl_first
	sub (hl)
	ld (pl_kept),a
	ret z
	ld b,a				; 5 bytes each
	add a,a
	add a,a
	add a,b
	ld c,a
	ld b,0
	push bc
	ld a,(pl_first)
	call .addr
	pop bc
	ld de,pl_attrs
	ldir
	ret
.addr	ld l,a				; HL = sprite_list + 5 A
	ld h,0
	ld e,l
	ld d,h
	add hl,hl
	add hl,hl
	add hl,de
	ld de,sprite_list
	add hl,de
	ret
pl_again:
	ld a,(pl_kept)
	or a
	jp z,build_copper
	ld b,a
	ld a,(sb_count)
	add a,b
	cp SPRITES_MAX + 1
	jp nc,build_copper
	ld c,a
	ld a,(sb_count)
	ld e,c
	push de
	call pl_keep.addr
	ex de,hl
	ld a,b
	add a,a
	add a,a
	add a,b
	ld c,a
	ld b,0
	ld hl,pl_attrs
	ldir
	pop de
	ld a,e
	ld (sb_count),a
	jp build_copper

; A = the pattern of frame A in the table at HL
pl_pattern:
	add a,l
	ld l,a
	adc a,h
	sub l
	ld h,a
	ld a,(hl)
	ret

; A player's or a missile's sprite: pattern A (made at the start: pl_pics; $FF none), its
; first row on line D (not below the river), position E, palette offset C, normal width.
; Its attributes: X = 2 * (position - 32 - 20) (9 bits, round the screen), Y = RIVER_TOP +
; the line's place in the river
pl_sprite:
	cp $FF
	ret z
	ld b,a
	ld a,d
	cp RIVER_FIRST + RIVER_LINES
	ret nc
	ld a,(sb_count)
	cp SPRITES_MAX
	ret nc
	push bc
	ld l,a
	ld h,0
	ld c,l
	ld b,h
	add hl,hl
	add hl,hl
	add hl,bc			; 5 bytes a sprite
	ld bc,sprite_list
	add hl,bc
	pop bc
	ld a,e
	sub 32 + WINDOW_FIRST
	ld e,a
	sbc a,a				; (borrow: negative)
	sla e
	rla
	ld (hl),e			; X
	inc hl
	and 1
	ld e,a
	ld a,d
	sub RIVER_FIRST - RIVER_TOP
	ld (hl),a			; Y
	inc hl
	ld a,c
	add a,a
	add a,a
	add a,a
	add a,a
	or e
	ld (hl),a			; palette offset, X bit 8
	inc hl
	ld a,b
	srl a
	or $C0
	ld (hl),a			; visible, 5 bytes, pattern
	inc hl
	ld a,b
	and 1
	rrca
	rrca				; N6 at bit 6
	or $80				; 4-bit pattern
	ld (hl),a
	ld hl,sb_count
	inc (hl)
	ret

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
	db $31, 0			; the tilemap at the panel's first row (tv_setup: CP_PANEL_Y)
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
	db $2F, 0			; (set by panel_frame: CP_XSCROLL_HI_BACK,
	db $30, 0			; CP_XSCROLL_BACK)
	db $80 | COPPER_WAIT_H * 2, WAIT_LINE_NTSC + 32 - 32 - 1
	db $1C, 2			; the sprites' window the river's again, for the next frame
	db $19, 0, $19, 159		; (below the logo, where apply starts)
	db $19, RIVER_TOP, $19, RIVER_TOP + RIVER_LINES - 1
copper_panel_ntsc_end:
; PAL (status_bar.cpp's layout): the panel's rows at 206, 218, 226, its grey to 239 (Layer 2's
; clip window), the scrolling line at 243. The same layout: the offsets below hold for both.
COPPER_GREY	equ 31			; the grey's 4 bytes in either, 2 apart
CP_PANEL_Y	equ 3			; the tilemap's Y scroll for the panel's first row
CP_EDGE_BACK	equ 25			; the restored edge colour's byte (the water's 2 after it)
CP_XSCROLL_BACK	equ 15			; the scrolling line's X scroll (low, high 2 before)
CP_XSCROLL_HI_BACK equ 17
PF_PATTERN	equ 20			; the scrolling line's sprite: its pattern (4-bit),
PF_OFFSET	equ 6			; palette offset
OBJ_LAST	equ RIVER_TOP + RIVER_LINES - 1 + 15	; the lowest line an object's rows reach
					; (a 16-row piece from the river's last line at the lowest)
NEEDLE_Y_NTSC	equ $CC - RIVER_FIRST + RIVER_TOP	; the needle's first line (10 lines)
NEEDLE_Y_PAL	equ $D3 - RIVER_FIRST + RIVER_TOP
	assert NEEDLE_Y_NTSC > OBJ_LAST		; (no object's rows reach the needle)
copper_panel_pal:
	db $80 | COPPER_WAIT_H * 2, 200 - 32 - 1
	db $31, 0			; the tilemap at the panel's first row (tv_setup: CP_PANEL_Y)
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
	db $2F, 0			; (set by panel_frame: CP_XSCROLL_HI_BACK,
	db $30, 0			; CP_XSCROLL_BACK)
	db $80 | COPPER_WAIT_H * 2, WAIT_LINE_PAL + 32 - 32 - 1
	db $1C, 2			; the sprites' window the river's again, for the next frame
	db $19, 0, $19, 159		; (below the logo, where apply starts)
	db $19, RIVER_TOP, $19, RIVER_TOP + RIVER_LINES - 1

copper_start:				; Layer 2's palette, index 1
	db $43,$90,$40,1
	db 0,0				; (a NOP: the fallback colour is T's, see main_frame)
					; the tilemap: no scroll (its lines the screen's: above
	db $31,0			; the panel and below the scrolling line, rows nothing is in,
					; whenever the Copper starts the frame; copper_panel moves it
					; to the panel's first row from line 200)
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
	; the panel: 3 rows of 20 characters, each two tiles (2 x code + half, the colour bits as
	; the palette offset); a row starts 8 dots left of the screen (its first tile is the first
	; character's right half) and ends 8 dots short. Only the positions panel_put listed.
	ld a,(pf_dirty_n)
	or a
	jr z,.panel_done
	cp 60
	jr c,.list
	ld b,60				; all
	ld e,0
.all	ld a,e
	push de
	push bc
	call .char
	pop bc
	pop de
	inc e
	djnz .all
	jr .panel_end
.list	ld b,a
	ld de,pf_dirty
.l	ld a,(de)
	inc de
	push de
	push bc
	call .char
	pop bc
	pop de
	djnz .l
.panel_end
	xor a
	ld (pf_dirty_n),a
.panel_done

	; the scrolling line: half character h (the character at $B800 + h / 2, its right half if h
	; is odd) at 8 h - X0, X0 = 16 TEXT_LO + 38 - 2 FINE_SCROLL (the first character 38 - 2 x
	; fine dots left of the screen). The tilemap's row is a ring: half h in column h mod 40, X
	; scroll X0 mod 320; only the halves new since the last frame are written. Column h0 mod 40
	; (h0 = X0 / 8, the left edge's) wraps round to the right edge: its last S = X0 & 7 dots
	; there are cut off by the tilemap's clip window, and a sprite shows half h0 + 40 there.
	ld a,(TEXT_LO)
	ld l,a
	ld h,0
	add hl,hl
	add hl,hl
	add hl,hl
	add hl,hl
	ld a,(FINE_SCROLL)
	add a,a
	neg
	add a,38
	ld e,a
	ld d,0
	add hl,de			; X0
	ld a,l
	and 7
	ld (pf_s),a
	push hl
	ld de,320			; X0 mod 320: the X scroll into the Copper's list
.mod	or a
	sbc hl,de
	jr nc,.mod
	add hl,de
	ld b,h
	ld c,l
	ld hl,(copper_bytes)
	ld de,copper_list - CP_XSCROLL_BACK
	add hl,de
	ld (hl),c
	dec hl
	dec hl
	ld (hl),b
	pop hl
	srl h				; h0
	rr l
	srl h
	rr l
	srl h
	rr l
	ld (pf_h0),hl
	ld de,(pf_ring_lo)		; the ring has halves pf_ring_lo to + 39: those from there + 40
	or a				; to h0 + 39 written (all 40 if that is not 1-39 of them)
	sbc hl,de
	jr z,.ring_ok
	ld a,h
	or a
	jr nz,.full
	ld a,l
	cp 40
	jr nc,.full
	ld b,a
	ld hl,40
	add hl,de
	jr .write
.full	ld hl,(pf_h0)
	ld b,40
.write	call .ring_write
	ld hl,(pf_h0)
	ld (pf_ring_lo),hl
.ring_ok
	ld hl,(pf_h0)			; the sprite's half: h0 + 40, its pattern written when it changes
	ld de,40
	add hl,de
	ld de,(pf_spr_h)
	or a
	sbc hl,de
	add hl,de
	call nz,.spr_pattern
	ld a,(pf_s)			; the clip window: S dots off the right
	rrca
	neg
	add a,159
	nextreg $1C,%00001000
	nextreg $1B,0
	nextreg $1B,a
	nextreg $1B,PANEL_FIRST_LINE
	ld a,(pf_clip_y2)
	nextreg $1B,a

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
	call .logo
	ld a,(pf_s)			; the scrolling line's sprite at 320 - S (X bit 8 set)
	neg
	add a,64
	out (c),a
	ld a,(tv_pal)
	or a
	ld a,231
	jr z,.sy
	ld a,243
.sy	out (c),a
	ld a,PF_OFFSET << 4 | 1
	out (c),a
	ld a,$C0 | PF_PATTERN >> 1
	out (c),a
	ld a,$80
	out (c),a
	ret

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

; B halves of the scrolling line from half HL into their columns of the ring
.ring_write
	push bc
	push hl
	ld bc,40			; the first's column: HL mod 40
.rm	or a
	sbc hl,bc
	jr nc,.rm
	add hl,bc
	ld a,l
	add a,a
	ld e,a
	ld d,0
	ld ix,TILE_MAP + 26 * 80
	add ix,de
	pop hl
	pop bc
	ld c,a				; (its byte in the row, to wrap at 80)
.rw	push hl
	ld a,l
	and 1
	ld e,a
	srl h
	rr l
	ld a,h
	add a,high ROM_SCROLL_TEXT
	ld h,a
	ld a,(hl)			; tile: 128 + (2 x character + half) & $7F
	add a,a
	or e
	and $7F
	or 128
	ld (ix + 0),a
	ld (ix + 1),$40			; palette offset 4
	pop hl
	inc hl
	inc ix
	inc ix
	ld a,c
	add a,2
	cp 80
	jr c,1F
	ld ix,TILE_MAP + 26 * 80
	xor a
1:	ld c,a
	djnz .rw
	ret

; The sprite's pattern: half HL's 8 rows (a dot 2 pixels of value 1), the rows below empty
; (as panel_init left them)
.spr_pattern
	ld (pf_spr_h),hl
	ld a,l
	and 1
	ld b,a
	srl h
	rr l
	ld a,h
	add a,high ROM_SCROLL_TEXT
	ld h,a
	ld a,(hl)
	and $3F
	ld l,a
	ld h,0
	add hl,hl
	add hl,hl
	add hl,hl
	ld de,$0600			; the glyph's rows
	add hl,de
	ld e,b				; E: the half
	ld bc,$303B
	ld a,PF_PATTERN >> 1
	out (c),a
	ld c,$5B
	ld d,8
.sr	ld a,(hl)
	inc hl
	bit 0,e				; the half's 4 bits at the top
	jr z,1F
	rrca
	rrca
	rrca
	rrca
1:	ld b,4
.sd	add a,a
	push af
	ld a,0
	jr nc,2F
	ld a,$11
2:	out (c),a
	pop af
	djnz .sd
	xor a
	out (c),a
	out (c),a
	out (c),a
	out (c),a
	dec d
	jr nz,.sr
	ret

; the left half's cell of each panel position (the row's first: its right half's, bit 15)
.cells
	dw TILE_MAP + 20 * 80 | $8000, TILE_MAP + 20 * 80 + 2, TILE_MAP + 20 * 80 + 6, TILE_MAP + 20 * 80 + 10
	dw TILE_MAP + 20 * 80 + 14, TILE_MAP + 20 * 80 + 18, TILE_MAP + 20 * 80 + 22, TILE_MAP + 20 * 80 + 26
	dw TILE_MAP + 20 * 80 + 30, TILE_MAP + 20 * 80 + 34, TILE_MAP + 20 * 80 + 38, TILE_MAP + 20 * 80 + 42
	dw TILE_MAP + 20 * 80 + 46, TILE_MAP + 20 * 80 + 50, TILE_MAP + 20 * 80 + 54, TILE_MAP + 20 * 80 + 58
	dw TILE_MAP + 20 * 80 + 62, TILE_MAP + 20 * 80 + 66, TILE_MAP + 20 * 80 + 70, TILE_MAP + 20 * 80 + 74
	dw TILE_MAP + 22 * 80 | $8000, TILE_MAP + 22 * 80 + 2, TILE_MAP + 22 * 80 + 6, TILE_MAP + 22 * 80 + 10
	dw TILE_MAP + 22 * 80 + 14, TILE_MAP + 22 * 80 + 18, TILE_MAP + 22 * 80 + 22, TILE_MAP + 22 * 80 + 26
	dw TILE_MAP + 22 * 80 + 30, TILE_MAP + 22 * 80 + 34, TILE_MAP + 22 * 80 + 38, TILE_MAP + 22 * 80 + 42
	dw TILE_MAP + 22 * 80 + 46, TILE_MAP + 22 * 80 + 50, TILE_MAP + 22 * 80 + 54, TILE_MAP + 22 * 80 + 58
	dw TILE_MAP + 22 * 80 + 62, TILE_MAP + 22 * 80 + 66, TILE_MAP + 22 * 80 + 70, TILE_MAP + 22 * 80 + 74
	dw TILE_MAP + 23 * 80 | $8000, TILE_MAP + 23 * 80 + 2, TILE_MAP + 23 * 80 + 6, TILE_MAP + 23 * 80 + 10
	dw TILE_MAP + 23 * 80 + 14, TILE_MAP + 23 * 80 + 18, TILE_MAP + 23 * 80 + 22, TILE_MAP + 23 * 80 + 26
	dw TILE_MAP + 23 * 80 + 30, TILE_MAP + 23 * 80 + 34, TILE_MAP + 23 * 80 + 38, TILE_MAP + 23 * 80 + 42
	dw TILE_MAP + 23 * 80 + 46, TILE_MAP + 23 * 80 + 50, TILE_MAP + 23 * 80 + 54, TILE_MAP + 23 * 80 + 58
	dw TILE_MAP + 23 * 80 + 62, TILE_MAP + 23 * 80 + 66, TILE_MAP + 23 * 80 + 70, TILE_MAP + 23 * 80 + 74

; Panel position A into the tilemap: the left half's cell from pf_cells (bit 7 of its high
; byte: the row's first character, its right half only)
.char	ld l,a
	ld h,high PANEL
	ld c,(hl)			; the character
	add a,a
	ld l,a
	ld h,0
	ld de,.cells
	add hl,de
	ld e,(hl)
	inc hl
	ld d,(hl)
	ld a,c
	and $C0
	rrca
	rrca
	ld b,a				; B: the attribute
	ld a,c
	and $3F
	add a,a
	ld c,a				; C: the left half's tile
	bit 7,d
	jr nz,.first
	ld (de),a
	inc de
	ld a,b
	ld (de),a
	inc de
	inc c
.right	ld a,c
	ld (de),a
	inc de
	ld a,b
	ld (de),a
	ret
.first	res 7,d
	inc c
	jr .right
