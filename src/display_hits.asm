; The collisions the DLI reads, without the scanlines' registers (river_raid/port/src/display.cpp,
; Game::displaySimple; docs/DLI_REMOVAL.md in the C++ port). Each sprite's rows are where the
; game put them (dh_desc): the scanlines where its collisions happen are worked out once a
; frame (dh_lists); an object's at its reads, against its rows in ds_objs (dh_obj). A read
; counts a collision if its scanline is between the last HITCLR's (ds_cleared) and its own.

; The sprites (10 bytes each): their rows' base (low byte; a row of line L at base + L: the
; ROM's shape, as prepare puts it into player-missile memory, from the first line), mask,
; rotations to bit 7, X, size, sprite (collide's), first line, rows, clocks wide, the base's
; high byte
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
	db 0, $03, 6, 0, 1, 4, 0, 1, 4, 0	; the missile (M0, double) its row,
	db 0, $20, 2, 0, 0, 6, 0, 8, 2, 0	; the bullet (M2's bit 5) 8 below bulletY
dh_template_end:
dh_ones:	db $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF	; the missiles' rows: all set

; At the frame's start: the other sprites' descriptors (their rows, boxes, positions)
dh_lists:
	ld hl,dh_template
	ld de,dh_desc
	ld bc,dh_template_end - dh_template
	ldir
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
1:	ret

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
	ld de,pf_edge
	ld hl,HIT_TANK_AT_EDGE
	ld a,1				; (the edge's gaps)
	call .pf
	ld ix,dh_desc + DH_PLANE
	ld de,pf_bank
	ld hl,HIT_PLANE_BANK
	ld a,2				; (the bank's)
	call .pf
	ld ix,dh_desc + DH_MISSILE
	ld de,pf_under
	ld hl,HIT_MISSILE_BANK
	ld a,3				; (both)
	call .pf
	ld ix,dh_desc + DH_BULLET
	ld de,pf_under
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
	ld a,(ix + 6)			; from the later first line
	cp (iy + 6)
	jr nc,1F
	ld a,(iy + 6)
1:	ld d,a
	call dh_end			; to the earlier end
	ld e,a
	push ix
	push iy
	pop ix
	call dh_end
	pop ix
	cp e
	jr nc,.l
	ld e,a
.l	ld a,d
	cp e
	jr nc,.no
	push de
	call dh_bits			; the first's bits
	jr z,.n
	push ix
	push iy
	pop ix				; (IX: the second)
	push af
	ld a,d
	call dh_bits
	jr z,.n2
	call dh_add
	ld c,(ix + 5)
	pop af
	pop ix				; (the first)
	push bc
	call dh_add
	pop bc
	ld b,(ix + 5)
	call dh_meet
	jr z,.n
	pop de
	or 1
	ret
.n2	pop af
	pop ix
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
	ret z
	ld b,(ix + 2)
	inc b
	jr 2F
1:	rlca
2:	djnz 1B
	or a
	ret

; Sprite IX with bits A into collide's list (for dh_meet)
dh_add:
	ld d,a
	ld e,(ix + 3)
	ld b,(ix + 5)
	ld a,(ix + 4)
	jp collide.add

; Do sprites B and C (in collide's list) touch? NZ: yes
dh_meet:
	ld hl,ds_obj_t
	ld (hl),0
	ld e,1
	call collide.pair
	ld a,(ds_obj_t)
	or a
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
	call dh_bits			; (no dots on the line: nothing)
	jr z,.n0
	ld (.bits + 1),a
	ld a,(bm_line)
	sub RIVER_FIRST			; the line's span record (its gaps' index)
	ld hl,span_top
	add a,(hl)
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
.bits	ld a,0
	ld d,a
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
; scanline of X = ds_counter, ds_rows of them going down in memory, at ds_x, ds_size), bit
; by bit on the scanlines both have, after their clocks
dh_obj:
	ld a,(ix + 7)			; (no rows)
	or a
	ret z
	ld a,(ds_size)			; first their clocks: the object's 8, 16 or 32 from its X,
	and 3				; the sprite's from its
	ld b,8
	rra
	jr nc,1F
	ld b,16
	or a
	jr z,1F
	ld b,32
1:	ld a,(ds_x)
	ld c,a
	ld a,(ix + 3)
	sub c
	jr c,1F
	cp b				; the sprite from the object's X on: before its end?
	jp nc,.no
	jr 2F
1:	neg				; before it: its end past the object's X?
	cp (ix + 8)
	jp nc,.no
2:	call dh_end			; the lines: to min(the sprite's end, the object's end)
	ld e,a
	ld a,(ds_counter)
	sub $44
	ld (ds_l1),a			; (the object's first)
	ld hl,ds_rows
	add a,(hl)
	jr c,1F
	cp e
	jr nc,1F
	ld e,a
1:	ld a,(ds_l1)			; from max(the object's first, the sprite's)
	ld d,(ix + 6)
	cp d
	jr c,1F
	ld d,a
1:	call ov_setup			; (the fast way when both are on the playfield's clocks)
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
	ld (ov_r),a
	ld a,(ov_mode)
	or a
	jr z,.slow
	pop de
	push de
	ld a,d
	call dh_bits
	jr z,.n
	call ov_fast
	jr nz,.yes
	jr .n
.slow	ld a,(ov_r)
	ld d,a
	ld a,(ds_x)
	ld e,a
	ld a,(ds_size)
	ld b,3
	call collide.add
	pop de
	push de
	ld a,d
	call dh_bits
	jr z,.n
	call dh_add
	ld b,(ix + 5)
	ld c,3
	call dh_meet
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

; dh_obj's fast way for sprite IX and the current object: when both are on the playfield's
; clocks (32-223), their dots compared a byte at a time: the object's row widened to a
; clock a bit (ov_exp2, ov_exp4: 1, 2 or 4 bytes), the sprite's byte (a clock a bit) shifted
; to it. ov_mode: the object's bytes (0: the slow way, collide); ov_k, ov_s: the sprite from
; the object's byte k, bit s on; ov_k $FF: it starts ov_s clocks before the object. D, E kept.
ov_setup:
	xor a
	ld (ov_mode),a
	ld a,(ds_size)			; the object's width and bytes
	and 3
	ld bc,8 << 8 | 1
	rra
	jr nc,1F
	ld bc,16 << 8 | 2
	or a
	jr z,1F
	ld bc,32 << 8 | 4
1:	ld a,(ds_x)
	cp 32
	ret c
	add a,b
	ret c
	cp 224 + 1
	ret nc
	ld a,(ix + 3)			; the sprite's (8 clocks)
	cp 32
	ret c
	cp 224 - 8 + 1
	ret nc
	ld hl,ds_x
	sub (hl)
	jr c,.before
	ld b,a
	rrca
	rrca
	rrca
	and $1F
	ld (ov_k),a
	ld a,b
	and 7
	ld (ov_s),a
	ld a,c
	ld (ov_mode),a
	ret
.before	neg
	ld (ov_s),a
	ld a,$FF
	ld (ov_k),a
	ld a,c
	ld (ov_mode),a
	ret

; NZ: the sprite's byte A (from dh_bits) meets the object's row ov_r (ov_setup)
ov_fast:
	ld b,a
	ld a,(ov_r)			; the row, a clock a bit, into ov_o (a zero after it)
	ld l,a
	ld a,(ov_mode)
	ld de,ov_o
	cp 2
	jr c,.w1
	ld h,high ov_exp2
	jr z,.w2
	ld h,high ov_exp4
	ld c,4
.w4	ld a,(hl)
	ld (de),a
	inc e
	inc h
	dec c
	jr nz,.w4
	jr .w0
.w2	ld a,(hl)
	ld (de),a
	inc e
	inc h
	ld a,(hl)
	ld (de),a
	inc e
	jr .w0
.w1	ld a,l
	ld (de),a
	inc e
.w0	xor a
	ld (de),a
	ld a,(ov_s)
	ld c,a
	ld a,(ov_k)
	cp $FF
	jr z,.before
	ld e,a				; the sprite from byte k, bit s: its byte over k and k + 1
	ld d,0
	ld hl,ov_o
	add hl,de
	ld a,b
	ld e,0
	inc c
	jr .sh
.shl	srl a
	rr e
.sh	dec c
	jr nz,.shl
	and (hl)
	ret nz
	inc hl
	ld a,e
	and (hl)
	ret
.before	ld a,b				; s clocks before the object: its byte moved left by s
.bl	add a,a
	dec c
	jr nz,.bl
	ld hl,ov_o
	and (hl)
	ret
