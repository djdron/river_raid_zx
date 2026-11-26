; The players and missiles of the river on TS-Conf: river_raid/port/src/display.cpp
; (Game::drawRiver), as the Next's sprites.asm makes them, with the TS-Conf's sprites. An
; Atari pixel is 2 dots, so a player's byte is 16 dots, 32 at double width, 64 at quadruple:
; the TS-Conf's sprites have no scale, so each picture is kept at the three widths.
; - The objects (player 3): a sprite each, the whole picture (up to 24 rows) with its rows in
;   their colours: dots of 1-15, the place of the row's colour in one of two palettes (CRAM
;   groups OBJ_PAL_A, OBJ_PAL_B), made once at the start (obj_pics). The display leaves the
;   objects' rows (ds_objs).
; - The others (one colour each): a picture per frame of the plane, the tank and the shell,
;   the bullet and the helicopter's missile (pl_pics), 16 rows at most, one sprite each.
; The sprites' pictures: SGPAGE's 512 x 512 dots (4 bits a dot, a line of 256 bytes), placed
; one after another by gfx_alloc. The river's sprites are the first of the SFILE (S0, under
; tile layer 0: the black above the river and below it hides what is outside it).

SGPAGE		equ 24			; (a multiple of 8) 8 pages
SPRITES_MAX	equ 60
OBJ_ENTRIES	equ 64			; obj_lookup's entries at most
PIC_MAX		equ 96			; pictures (pic_*)
OBJ_PAL_A	equ 14			; CRAM groups: the objects' colours (types 12 and 15),
OBJ_PAL_B	equ 15			; (the others)
SHELL_PAL	equ 8			; the shell and the helicopter's missile (colour 1),
TANK_PAL	equ 9			; the tank,
PLANE_PAL	equ 10			; the plane and its bullet
SPR_SIZE	equ 6			; an SFILE entry

build_sprites:
	ld a,(busy)			; a reset's frame: last frame's players' entries kept first,
	or a				; before the objects' go over them (pl_keep)
	call nz,pl_save
	xor a
	ld (sb_count),a
	ld hl,spr_list
	ld (sb_ptr),hl
	; in the order drawRiver draws them, the last on top
	call ob_list			; player 3: the objects, from their rows
	ld a,(sb_count)			; (where the players' entries start)
	ld (pl_first),a
	ld a,(busy)			; a reset's frames: player-missile memory as the last
	or a				; prepare left it (none runs meanwhile): the same sprites
	jp nz,pl_again
	ld a,(PLANE_FRAME)		; the plane: its frame (0-9) at $AA
	ld hl,pl_plane
	call pl_pattern
	ld b,a
	ld d,$AA
	ld a,(PLANE_X)
	ld e,a
	ld c,PLANE_PAL
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
	ld c,PLANE_PAL
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
	ld c,TANK_PAL
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
	ld c,SHELL_PAL
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
	ld c,SHELL_PAL
	ld a,b
	call pl_sprite
1:	jp pl_keep

; The players' entries this frame: how many (pl_kept, from pl_first in spr_list, where they
; stay until the next frame's are made); copied to pl_attrs only when a reset's frame comes
; (pl_save, build_sprites), put again from there (pl_again)
pl_save:
	ld a,(pl_kept)
	or a
	ret z
	push af
	ld a,(pl_first)
	call pl_keep.addr
	pop af
	call pl_keep.bytes
	ld de,pl_attrs
	ldir
	ret
pl_keep:
	ld a,(sb_count)
	ld hl,pl_first
	sub (hl)
	ld (pl_kept),a
	ret
.bytes	ld b,a				; BC: A entries' bytes (6 each)
	add a,a
	add a,b
	add a,a
	ld c,a
	ld b,0
	ret
.addr	ld l,a				; HL = spr_list + 6 A
	ld h,0
	ld e,l
	ld d,h
	add hl,hl
	add hl,de
	add hl,hl
	ld de,spr_list
	add hl,de
	ret
pl_again:
	ld a,(pl_kept)
	or a
	ret z
	ld b,a
	ld a,(sb_count)
	add a,b
	cp SPRITES_MAX + 1
	ret nc
	ld c,a
	ld a,(sb_count)
	push bc
	call pl_keep.addr
	ex de,hl
	pop bc
	ld a,c
	ld (sb_count),a
	ld a,b
	call pl_keep.bytes
	ld hl,pl_attrs
	ldir
	ld (sb_ptr),de
	ret

; A = the picture of frame A in the table at HL
pl_pattern:
	add a,l
	ld l,a
	adc a,h
	sub l
	ld h,a
	ld a,(hl)
	ret

; A player's or a missile's sprite: picture A ($FF none), its first row on line D (not below
; the river), position E, palette C, 16 dots wide
pl_sprite:
	cp $FF
	ret z
	ld b,a
	ld a,d
	cp RIVER_FIRST + RIVER_LINES
	ret nc
	ld a,c
	ld (ob_palv),a
	ld a,d
	ld (ob_line),a
	ld a,e
	ld (ob_x),a
	ld a,b
	ld (ob_pat),a
	xor a
	ld (ob_size),a
	jr ob_attr

; The objects' sprites, from what the display left (ds_objs): each object's picture made at
; the start (obj_pics), found by its top row's shape and colour addresses (obj_lookup); none
; for an object whose first row is below the river.
ob_list:
	ld a,(ds_obj_n)
	or a
	ret z
	ld b,a
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
	call obj_lookup
	or a
	jr z,.miss
	ld b,a
	and $7F
	ld (ob_pat),a
	ld a,b
	rla
	ld a,OBJ_PAL_B
	jr c,1F
	ld a,OBJ_PAL_A
1:	ld (ob_palv),a
	ld a,(ob_line)			; none whose first row is below the river (no part of it
	sub RIVER_FIRST + RIVER_LINES	; shows on the Atari; lines past 220: an object coming in
	cp 32				; at the top, above 0)
	call nc,ob_attr
	jr .next
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
; picture + its palette in bit 7 (OBJ_PAL_B), 0 none
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

; The SFILE entry of a sprite of picture ob_pat at scanline ob_line, position ob_x, size
; ob_size (its width: 16, 32 or 64 dots), palette ob_palv: X = 2 x (position - 32 - 20)
; (9 bits), Y = RIVER_TOP + the line's place in the river (9 bits)
ob_attr:
	ld a,(sb_count)
	cp SPRITES_MAX
	ret nc
	inc a
	ld (sb_count),a
	ld hl,(sb_ptr)			; (spr_list + 6 sb_count)
	ld a,(ob_line)			; Y: lines 220-255 and 0-3 above the screen (9 bits round)
	sub RIVER_FIRST - RIVER_TOP
	ld e,a
	cp 216
	ld a,0
	adc a,0
	xor 1
	ld d,a
	ld (hl),e
	inc hl
	ld a,(ob_pat)			; the picture's height (YS) and its place
	ld c,a
	ld b,high pic_h
	ld a,(bc)
	or d
	or $20				; ACT
	ld (hl),a
	inc hl
	ld a,(ob_x)			; X
	sub 32 + WINDOW_FIRST
	ld e,a
	sbc a,a
	ld d,a
	ex de,hl
	add hl,hl
	ex de,hl
	ld (hl),e
	inc hl
	ld a,(ob_size)			; the width: XS, and which of the three pictures
	and 3
	ld b,high pic_tn16_lo
	ld e,$02			; (16 dots: XS 1)
	cp 1
	jr nz,1F
	ld b,high pic_tn32_lo
	ld e,$06			; (32: XS 3)
	jr 2F
1:	cp 3
	jr nz,2F
	ld b,high pic_tn64_lo
	ld e,$0E			; (64: XS 7)
2:	ld a,d
	and 1
	or e
	ld (hl),a
	inc hl
	ld a,(bc)			; the picture's first tile
	ld (hl),a
	inc hl
	inc b
	ld a,(bc)
	ld e,a
	ld a,(ob_palv)
	add a,a
	add a,a
	add a,a
	add a,a
	or e
	ld (hl),a
	inc hl
	ld (sb_ptr),hl
	ret

; CRAM entry A x 16 + B: Atari colour E (B, C, E kept)
cram_set:
	push bc
	push hl
	add a,a
	add a,a
	add a,a
	add a,a
	add a,b
	ld l,a
	ld h,0
	add hl,hl
	ld bc,CRAM_SHADOW
	add hl,bc			; (the FM window is always on)
	ld b,high palette_lo
	ld c,e
	ld a,(bc)
	ld (hl),a
	inc hl
	inc b
	ld a,(bc)
	ld (hl),a
	pop hl
	pop bc
	ret

