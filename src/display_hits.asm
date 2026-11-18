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

; At the frame's start: the sprites, and the scanlines of P1PF (the tank, the edge), P2PF (the
; plane, the bank), M0PF and M2PF (the missile, the bullet: either), P2PL (the plane and the
; shell), M0PL (the missile and the plane)
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
1:
	ld ix,dh_desc + DH_TANK
	ld hl,dh_tank_edge
	ld de,pf_edge
	call dh_pf
	ld ix,dh_desc + DH_PLANE
	ld hl,dh_plane_bank
	ld de,pf_bank
	call dh_pf
	ld ix,dh_desc + DH_MISSILE
	ld hl,dh_missile_bank
	ld de,pf_under
	call dh_pf
	ld ix,dh_desc + DH_BULLET
	ld hl,dh_bullet_bank
	ld de,pf_under
	call dh_pf
	ld ix,dh_desc + DH_PLANE
	ld iy,dh_desc + DH_SHELL
	ld hl,dh_plane_shell
	call dh_pair
	ld ix,dh_desc + DH_MISSILE
	ld iy,dh_desc + DH_PLANE
	ld hl,dh_missile_plane
	; (on to dh_pair)

; The scanlines where sprites IX and IY touch, into list HL (a count, the scanlines)
dh_pair:
	ld (hl),0
	ld (dh_list),hl
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
	ret nc
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
	push de
	ld hl,(dh_list)
	inc (hl)
	ld a,(hl)
	add a,l
	ld l,a
	ld (hl),d
	jr .n
.n2	pop af
	pop ix
.n	pop de
	inc d
	jr .l

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

; The scanlines where sprite IX's rows meet the playfield (DE: pf_edge, pf_bank, pf_under),
; into list HL
dh_pf:
	ld (.fn + 1),de
	ld (hl),0
	ld (dh_list),hl
	ld a,(ix + 7)
	or a
	ret z
	ld c,a
	ld b,(ix + 6)
.l	ld a,b
	cp RIVER_FIRST + RIVER_LINES
	ret nc
	cp RIVER_FIRST
	jr c,.n
	push bc
	ld (bm_line),a
	call dh_bits
	jr z,.n0
	ld d,a
	ld e,(ix + 3)
	ld a,(ix + 4)
.fn	call 0
	or a
	jr z,.n0
	pop bc
	push bc
	ld hl,(dh_list)
	inc (hl)
	ld a,(hl)
	add a,l
	ld l,a
	ld (hl),b
.n0	pop bc
.n	inc b
	dec c
	jr nz,.l
	ret

; NZ: list HL has a scanline from the last HITCLR's to A
dh_seen:
	ld c,a
	ld a,(ds_cleared)
	ld d,a
	ld b,(hl)
	inc b
	jr .e
.l	inc hl
	ld a,(hl)
	cp d
	jr c,.e
	ld e,a
	ld a,c
	cp e
	jr nc,.yes
.e	djnz .l
	xor a
	ret
.yes	or 1
	ret

; NZ: sprite IX touches the current object's rows (the last in ds_objs, if they are its) on
; the scanlines from the last HITCLR's to C, bit by bit
dh_obj:
	ld a,(ix + 7)			; (no rows)
	or a
	ret z
	ld a,(ds_obj_slot)
	ld hl,ds_current
	cp (hl)
	jp nz,.no
	ld iy,(ds_obj_last)
	ld a,(iy + 7)			; first their clocks: the object's 8, 16 or 32 from its X,
	and 3				; the sprite's from its
	ld b,8
	rra
	jr nc,1F
	ld b,16
	or a
	jr z,1F
	ld b,32
1:	ld a,(ix + 3)
	sub (iy + 6)
	jr c,1F
	cp b				; the sprite from the object's X on: before its end?
	jp nc,.no
	jr 2F
1:	neg				; before it: its end past the object's X?
	cp (ix + 8)
	jp nc,.no
2:
	ld a,c				; the lines: to min(through + 1, the sprite's end, the
	inc a				; object's end)
	jr nz,1F
	dec a
1:	ld e,a
	call dh_end
	cp e
	jr nc,1F
	ld e,a
1:	ld a,(iy + 0)
	add a,(iy + 1)
	jr c,1F
	cp e
	jr nc,1F
	ld e,a
1:	ld a,(iy + 0)			; from max(the object's first, the sprite's, the HITCLR's)
	ld d,(ix + 6)
	cp d
	jr c,1F
	ld d,a
1:	ld a,(ds_cleared)
	cp d
	jr c,1F
	ld d,a
1:	ld a,d
.l	cp e
	jr nc,.no
	push de
	sub (iy + 0)			; the object's row there: (the first) - (line - first)
	ld c,a
	ld b,0
	ld l,(iy + 2)
	ld h,(iy + 3)
	or a
	sbc hl,bc
	ld a,(hl)
	or a
	jr z,.n
	ld d,a
	ld e,(iy + 6)
	ld a,(iy + 7)
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

; A late object's rows against the edge (P3PF; the rows' loop does it for the others)
dh_edge:
	ld a,(ds_edge_kind)
	or a
	ret z
	ld iy,(ds_obj_last)
	ld b,(iy + 1)
	ld c,(iy + 0)
	ld l,(iy + 2)
	ld h,(iy + 3)
.l	ld a,c
	sub RIVER_FIRST
	cp RIVER_LINES
	jr nc,.n
	ld a,(hl)
	or a
	jr z,.n
	push bc
	push hl
	ld d,a
	ld a,c
	ld (bm_line),a
	ld e,(iy + 6)
	ld a,(iy + 7)
	call pf_edge
	pop hl
	pop bc
	or a
	jr z,.n
	ld hl,coll_ppf + 3
	set 1,(hl)
	ret
.n	dec hl
	inc c
	djnz .l
	ret
