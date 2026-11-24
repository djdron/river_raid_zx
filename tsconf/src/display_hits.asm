; The collisions the DLI reads, without the scanlines' registers (river_raid/port/src/display.cpp,
; Game::displaySimple; docs/DLI_REMOVAL.md in the C++ port). Each sprite's rows are where the
; game put them (dh_desc): the scanlines where its collisions happen are worked out once a
; frame (dh_lists); an object's at its reads, against its rows in ds_objs (dh_obj). A read
; counts a collision if its scanline is between the last HITCLR's (ds_cleared) and its own.

; The sprites (10 bytes each): their rows' base (low byte; a row of line L at base + L: the
; ROM's shape, as prepare puts it into player-missile memory, from the first line), mask
; (turned to the dots' places at the top already: the missiles' rows are all set), the
; end of its rows (dh_lists: the line after the last, past 255 255), X, size, sprite (collide's), first line, rows, clocks wide, the base's high byte
DH_SIZE		equ 10
DH_SHELL	equ 0
DH_TANK		equ DH_SIZE
DH_PLANE	equ 2 * DH_SIZE
DH_MISSILE	equ 3 * DH_SIZE
DH_BULLET	equ 4 * DH_SIZE
dh_template:
	db 0, $FF, 0, 0, 0, 0, 0, 16, 8, 0	; the shell 16 rows from shellY,
	db 0, $FF, 0, 0, 0, 1, 0, 11, 8, 0	; the tank 11 from tankY,
	db 0, $FF, 0, 0, 0, 2, $AA, 14, 8, 0	; the plane 14 from $AA,
	db 0, $C0, 0, 0, 1, 4, 0, 1, 4, 0	; the missile (M0, double: $03 turned 6) its row,
	db 0, $80, 0, 0, 0, 6, 0, 8, 2, 0	; the bullet (M2's bit 5 turned 2) 8 below bulletY
dh_template_end:
dh_ones:	db $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF	; the missiles' rows: all set

; At the frame's start: the other sprites' descriptors (their rows, boxes, positions)
dh_lists:
	ld a,16				; (the rows: as the template, then cleared below if none)
	ld (dh_desc + DH_SHELL + 7),a
	ld a,11
	ld (dh_desc + DH_TANK + 7),a
	ld a,14
	ld (dh_desc + DH_PLANE + 7),a
	ld a,1
	ld (dh_desc + DH_MISSILE + 7),a
	ld a,8
	ld (dh_desc + DH_BULLET + 7),a
	ld a,(SHELL_X)
	ld (dh_desc + DH_SHELL + 3),a
	ld a,(SHELL_Y)
	ld (dh_desc + DH_SHELL + 6),a
	ld a,(TANK_X)
	ld (dh_desc + DH_TANK + 3),a
	ld a,(TANK_Y)
	ld (dh_desc + DH_TANK + 6),a
	ld a,(PLANE_X)
	ld (dh_desc + DH_PLANE + 3),a
	add a,4
	ld (dh_desc + DH_BULLET + 3),a
	ld a,(MISSILE_X)
	ld (dh_desc + DH_MISSILE + 3),a
	ld a,(MISSILE_Y)
	ld (dh_desc + DH_MISSILE + 6),a
	cp $1C
	jr nc,1F
	xor a
	ld (dh_desc + DH_MISSILE + 7),a
1:	ld a,(MISSILE_X)		; (no position: its bits clear)
	or a
	jr nz,1F
	ld (dh_desc + DH_MISSILE + 7),a
1:	ld a,(BULLET_Y)
	cp 2
	jr nc,2F
	xor a
	ld (dh_desc + DH_BULLET + 7),a
	jr 3F
2:	dec a
	cp $1B
	jr nc,1F
	ld a,$1B
1:	inc a
	ld (dh_desc + DH_BULLET + 6),a
3:	ld ix,dh_desc + DH_SHELL	; the rows: the shapes of the frames prepare drew
	ld a,(SHELL_FRAME)
	ld hl,ROM_SHELL_SHAPE
	call dh_shape
	ld ix,dh_desc + DH_TANK
	ld a,(TANK_KIND)
	ld hl,ROM_TANK_SHAPE
	call dh_shape
	ld ix,dh_desc + DH_PLANE
	ld a,(PLANE_FRAME)
	ld hl,ROM_PLANE_SHAPE
	call dh_shape
	ld ix,dh_desc + DH_MISSILE
	ld de,dh_ones
	call dh_base
	ld ix,dh_desc + DH_BULLET
	ld de,dh_ones
	call dh_base
	ld a,(pm_empty)			; a reset cleared them, no prepare since: none
	or a
	jr z,1F
	xor a
	ld (dh_desc + DH_SHELL + 7),a
	ld (dh_desc + DH_TANK + 7),a
	ld (dh_desc + DH_PLANE + 7),a
	ld (dh_desc + DH_MISSILE + 7),a
	ld (dh_desc + DH_BULLET + 7),a
1:	ld ix,dh_desc			; each one's end (dh_end)
	ld b,5
	ld de,DH_SIZE
2:	call dh_end
	ld (ix + 2),a
	add ix,de
	djnz 2B
	ret

; At the start: the sprites' fields that stay (dh_lists sets the others every frame)
dh_init:
	ld hl,dh_template
	ld de,dh_desc
	ld bc,dh_template_end - dh_template
	ldir
	ret

; At the frame's start the other sprites' collisions with the bank and each other, as plain
; geometry (anywhere on their rows): HIT 0 where they touch. P1PF the tank and the edge, P2PF
; the plane and the bank, M0PF and M2PF the missile and the bullet and either, P2PL the plane
; and the shell, M0PL the missile and the plane.
dh_sprites:
	ld hl,HIT			; B510: none
	ld b,9
	ld a,$FF
1:	ld (hl),a
	inc hl
	djnz 1B
	ld ix,dh_desc + DH_TANK
	ld de,sp_edge
	ld hl,HIT_TANK_AT_EDGE
	ld a,1				; (the edge's gaps)
	call .pf
	ld ix,dh_desc + DH_PLANE
	ld de,sp_bank
	ld hl,HIT_PLANE_BANK
	ld a,2				; (the bank's)
	call .pf
	ld ix,dh_desc + DH_MISSILE
	ld de,sp_under
	ld hl,HIT_MISSILE_BANK
	ld a,3				; (both)
	call .pf
	ld ix,dh_desc + DH_BULLET
	ld de,sp_under
	ld hl,HIT_BULLET_BANK
	ld a,3
	call .pf
	ld ix,dh_desc + DH_PLANE
	ld iy,dh_desc + DH_SHELL
	call dh_pair
	jr z,1F
	xor a
	ld (HIT_PLANE_SHELL),a
1:	ld ix,dh_desc + DH_MISSILE
	ld iy,dh_desc + DH_PLANE
	call dh_pair
	ret z
	xor a
	ld (HIT_MISSILE_PLANE),a
	ret
.pf	push hl
	call dh_pf
	pop hl
	ret z
	ld (hl),0
	ret

; NZ: sprites IX and IY touch on a scanline both have
dh_pair:
	ld b,(ix + 3)			; their boxes' clocks
	ld c,(ix + 8)
	ld d,(iy + 3)
	ld e,(iy + 8)
	call hit_setup
	ret z
	ld a,(ix + 6)			; their lines: from the later first
	cp (iy + 6)
	jr nc,1F
	ld a,(iy + 6)
1:	ld d,a
	ld a,(ix + 2)			; to the earlier end
	ld e,(iy + 2)
	cp e
	jr nc,.l
	ld e,a
.l	ld a,d
	cp e
	jr nc,.no
	push de
	call dh_bits			; the first's dots
	jr z,.n
	ld c,(ix + 4)
	ld de,hit_a
	call hit_wide
	pop de
	push de
	push ix
	push iy
	pop ix				; (IX: the second)
	ld a,d
	call dh_bits
	jr z,.n2
	ld c,(ix + 4)
	ld de,hit_b
	call hit_wide
	pop ix
	call hit_line
	jr z,.n
	pop de
	or 1
	ret
.n2	pop ix
.n	pop de
	inc d
	jr .l
.no	xor a
	ret

; Sprite IX's rows: frame A's shape from pointer table HL (as prepare: 2 * A & $FF)
dh_shape:
	add a,a
	add a,l
	ld l,a
	jr nc,1F
	inc h
1:	ld e,(hl)
	inc hl
	ld d,(hl)
; Sprite IX's rows from DE on its first line: base = DE - the first line
dh_base:
	ld l,(ix + 6)
	ld h,0
	ex de,hl
	or a
	sbc hl,de
	ld (ix + 0),l
	ld (ix + 9),h
	ret

; The end of sprite IX's rows (the line after the last; past 255: 255)
dh_end:
	ld a,(ix + 6)
	add a,(ix + 7)
	ret nc
	ld a,255
	ret

; Sprite IX's bits on line A, at the top (Z: none). D kept.
dh_bits:
	add a,(ix + 0)
	ld l,a
	ld a,(ix + 9)
	adc a,0
	ld h,a
	ld a,(hl)
	and (ix + 1)
	ret

; NZ: sprite IX's rows meet the playfield on a river line (DE: pf_edge, pf_bank, pf_under;
; A: which gaps a line's box is looked up in first, bit 0 the edge's (eg_*), bit 1 the bank's
; (bg_*): inside the gaps, nothing to look at on the line)
dh_pf:
	ld (.fn + 1),de
	ld (.mode + 1),a
	ld a,(ix + 7)
	or a
	ret z
	ld c,a
	ld a,(ix + 3)			; the box: X to X + its clocks
	ld (.x0a + 1),a
	ld (.x0b + 1),a
	ld (.x0c + 1),a
	ld (.x0d + 1),a
	add a,(ix + 8)
	jr nc,1F
	xor a				; (past clock 255: none, the dots looked at)
	ld (.mode + 1),a
1:	ld (.x1a + 1),a
	ld (.x1b + 1),a
	ld (.x1c + 1),a
	ld (.x1d + 1),a
	ld b,(ix + 6)
.l	ld a,b
	cp RIVER_FIRST + RIVER_LINES
	jp nc,.no
	cp RIVER_FIRST
	jp c,.n
	push bc
	ld (bm_line),a
	add a,(ix + 0)			; the row's byte (as dh_bits: no dots, nothing)
	ld l,a
	ld a,(ix + 9)
	adc a,0
	ld h,a
	ld a,(hl)
	and (ix + 1)
	jr z,.n0
	ld (.raw + 1),a
	ld a,(bm_line)
	sub RIVER_FIRST			; the line's span record (its gaps' index); the box against
	ld hl,span_top			; the gaps first, the dots looked at only if it is not inside
	add a,(hl)			; one (most lines: the plane over the water)
	ld l,a
.mode	ld c,0
	bit 0,c
	jr z,.bank
	ld h,high eg_e1
.x0a	ld a,0
	cp (hl)
	jr c,.e2
	inc h
	ld a,(hl)
.x1a	cp 0
	jr nc,.bank
.e2	ld h,high eg_e3
.x0b	ld a,0
	cp (hl)
	jr c,.look
	inc h
	ld a,(hl)
.x1b	cp 0
	jr c,.look
.bank	bit 1,c
	jr z,.gap
	ld h,high bg_e1
.x0c	ld a,0
	cp (hl)
	jr c,.b2
	inc h
	ld a,(hl)
.x1c	cp 0
	jr nc,.gap
.b2	ld h,high bg_e3
.x0d	ld a,0
	cp (hl)
	jr c,.look
	inc h
	ld a,(hl)
.x1d	cp 0
	jr c,.look
.gap	ld a,c				; (mode 0: no gaps, the dots looked at)
	or a
	jr nz,.n0
.look
.raw	ld d,0				; the dots (as dh_bits)
	ld e,(ix + 3)
	ld a,(ix + 4)
.fn	call 0
	or a
	jr z,.n0
	pop bc
	or 1
	ret
.n0	pop bc
.n	inc b
	dec c
	jp nz,.l
.no	xor a
	ret

; NZ: sprite IX touches the current object's rows (display: ds_rowp, the first on the
; scanline of X = ds_counter, ds_rows of them going down in memory, at the slot's X and size: IY + 22, + 33), bit
; by bit on the scanlines both have, after their clocks
dh_obj:
	ld a,(ix + 7)			; (no rows)
	or a
	ret z
	ld e,(ix + 2)			; the lines first (most objects are on none of the sprite's):
	ld a,e				; to min(the sprite's end, the object's: ds_l2, display)
	ld a,(ds_l2)
	cp e
	jr nc,1F
	ld e,a
1:	ld a,(ds_l1)			; from max(the object's first, the sprite's)
	ld d,(ix + 6)
	cp d
	jr c,1F
	ld d,a
1:	ld a,d
	cp e
	jr nc,.no
	push de
	ld a,(iy + 33)			; then their boxes' clocks (IY: the slot's fields, display): the object's 8, 16 or 32 from its X,
	and 3				; the sprite's from its
	ld c,8
	rra
	jr nc,1F
	ld c,16
	or a
	jr z,1F
	ld c,32
1:	ld b,(iy + 22)
	ld d,(ix + 3)
	ld e,(ix + 8)
	call hit_setup
	pop de
	ret z
	ld a,d
.l	cp e
	jr nc,.no
	push de
	ld hl,ds_l1			; the object's row there: (the first) - (line - first)
	sub (hl)
	ld c,a
	ld b,0
	ld hl,(ds_rowp)
	or a
	sbc hl,bc
	ld a,(hl)
	or a
	jr z,.n
	ld c,(iy + 33)
	ld de,hit_a
	call hit_wide
	pop de
	push de
	ld a,d				; the sprite's
	call dh_bits
	jr z,.n
	ld c,(ix + 4)
	ld de,hit_b
	call hit_wide
	call hit_line
	jr nz,.yes
.n	pop de
	inc d
	ld a,d
	jr .l
.yes	pop de
	or 1
	ret
.no	xor a
	ret

; ------------------------------------------------------------------------------------------
; The collisions' test, for any two (an object and a sprite, two sprites): their boxes'
; clocks first (hit_setup, once: the window where both are, on the playfield's clocks 32-223,
; as GTIA's masks were kept; never wider than a sprite, 8), then on each line both have, their
; dots (a clock a bit: an object's or a sprite's byte widened by its size from ov_exp2,
; ov_exp4) shifted by the barrel shifter to the window's first clock and ANDed (hit_line).

; Z: A's clocks (from B, C wide) and B's (from D, E wide) don't meet on the playfield; else
; the window: where it starts in A's dots and in B's (byte, bit), its clocks' bits
hit_setup:
	ld a,d				; the boxes first: B's start before A's end, A's before B's
	sub b
	jr c,1F
	cp c
	jr nc,.none
	jr 2F
1:	neg
	cp e
	jr nc,.none
2:	ld a,b				; H: the window's end (the earliest)
	add a,c
	jr nc,1F
	ld a,255
1:	ld h,a
	ld a,d
	add a,e
	jr nc,1F
	ld a,255
1:	cp h
	jr c,1F
	ld a,h
1:	cp 224
	jr c,1F
	ld a,224
1:	ld h,a
	ld a,b				; L: its start (the latest)
	cp d
	jr nc,1F
	ld a,d
1:	cp 32
	jr nc,1F
	ld a,32
1:	ld l,a
	ld a,h
	sub l
	jr c,.none
	jr z,.none
	cp 8
	jr c,1F
	ld a,8
1:	ld c,a				; its bits: the top C
	ld a,8
	sub c
	ld c,a
	ld a,$FF
	inc c
	jr 2F
1:	add a,a
2:	dec c
	jr nz,1B
	ld (hit_w),a
	ld a,l				; in A's dots
	sub b
	ld c,a
	rrca
	rrca
	rrca
	and $1F
	ld (hit_ka),a
	ld a,c
	and 7
	ld (hit_sa),a
	ld a,l				; in B's
	sub d
	ld c,a
	rrca
	rrca
	rrca
	and $1F
	ld (hit_kb),a
	ld a,c
	and 7
	ld (hit_sb),a
	or 1
	ret
.none	xor a
	ret

; NZ: the dots in hit_a and hit_b meet in the window
; (TS-Conf: the Next's BSLA DE,B as a loop: B 0-7 steps)
shl_de_b	macro
	inc b
	jr 2F
1:	sla e
	rl d
2:	djnz 1B
	endm

hit_line:
	ld a,(hit_ka)
	add a,low hit_a
	ld l,a
	ld h,high hit_a
	ld d,(hl)
	inc l
	ld e,(hl)
	ld a,(hit_sa)
	ld b,a
	shl_de_b
	ld c,d
	ld a,(hit_kb)
	add a,low hit_b
	ld l,a
	ld d,(hl)
	inc l
	ld e,(hl)
	ld a,(hit_sb)
	ld b,a
	shl_de_b
	ld a,(hit_w)
	and c
	and d
	ret

; byte A's dots (size C: 1, 2 or 4 clocks a bit as GTIA's 0 or 2, 1, 3) a clock a bit into DE
; on, a zero after
hit_wide:
	bit 0,c
	jr nz,1F
	ld (de),a
	inc e
	xor a
	ld (de),a
	ret
1:	ld l,a
	bit 1,c
	jr nz,2F
	ld h,high ov_exp2
	ld a,(hl)
	ld (de),a
	inc e
	inc h
	ld a,(hl)
	ld (de),a
	inc e
	xor a
	ld (de),a
	ret
2:	ld h,high ov_exp4
	ld b,4
3:	ld a,(hl)
	ld (de),a
	inc e
	inc h
	djnz 3B
	xor a
	ld (de),a
	ret

; ------------------------------------------------------------------------------------------
; A sprite's row against the playfield of line bm_line, as the C++ port's spanTouches: the
; row's first and last dots (bits D, position E, size A) against the line's runs of edge
; pixels (sp_edge: brown), bank pixels (sp_bank: green) or either (sp_under); a run between
; them is a touch, no dot by dot. A = 1 (NZ): touched, else 0.
sp_edge:
	call sp_ends
	ret z
	call sp_rec
	ld a,l				; (the edge's runs: at the record's first byte's offset)
	add a,(hl)
	ld l,a
	jr sp_runs
sp_bank:
	call sp_ends
	ret z
	call sp_rec
	inc l				; (the bank's: from its second byte)
	jr sp_runs
sp_under:
	call sp_ends
	ret z
	call sp_rec
	push hl
	inc l
	call sp_runs
	pop hl
	ret nz
	ld a,l
	add a,(hl)
	ld l,a
; NZ (A = 1): a run (first clock, end; in order) from HL meets clocks C to B
sp_runs:
	ld a,(hl)			; one from past the row's last dot on: none touched
	cp b
	jr nc,.no
	inc l
	ld a,c				; one that ends before its first dot: the next
	cp (hl)
	inc l
	jr nc,sp_runs
	ld a,1				; one between: touched
	or a
	ret
.no	xor a
	ret

; C: the row's first dot's clock, B: past its last (bits D, position E, size A: a dot 1, 2
; or 4 clocks for GTIA's 0 or 2, 1, 3; edge_lo, edge_hi); Z (A = 0): no dots, or past clock 255
sp_ends:
	ld b,a
	ld a,d
	or a
	ret z
	ld l,a
	ld h,high edge_lo
	ld c,(hl)
	inc h
	ld a,(hl)
	bit 0,b
	jr z,1F
	add a,a
	sla c
	bit 1,b
	jr z,1F
	add a,a
	sla c
1:	add a,e				; (its end past 255: 255)
	jr nc,2F
	ld a,255
2:	ld b,a
	ld a,c
	add a,e
	jr c,3F
	ld c,a
	or 1
	ret
3:	xor a
	ret

; HL: the span record of line bm_line (a river line)
sp_rec:
	ld a,(bm_line)
	sub RIVER_FIRST
	ld hl,span_top
	add a,(hl)
	span_rec
	ret
