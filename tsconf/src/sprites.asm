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
	xor a
	ld (sb_count),a
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

; The players' entries this frame kept (pl_keep), or put again (pl_again: a reset)
pl_keep:
	ld a,(sb_count)
	ld hl,pl_first
	sub (hl)
	ld (pl_kept),a
	ret z
	call .bytes
	push bc
	ld a,(pl_first)
	call .addr
	pop bc
	ld de,pl_attrs
	ldir
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
	dec a
	call pl_keep.addr
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
	ret

; ------------------------------------------------------------------------------------------
; The sprites' pictures, made at the start: the objects' (obj_pics) and the players' (pl_pics),
; into SGPAGE's dots through window 1 (WORK_PAGE back after)

; A place for a picture of BC dots across, A rows (a multiple of 8): its first dot's x
; (gfx_x) and line (gfx_y, 9 bits); the next on the same lines while they hold it
gfx_alloc:
	push af
	ld hl,(gfx_cx)			; past the line's end: on the next lines
	add hl,bc
	ld de,513
	or a
	sbc hl,de
	jr c,1F
	ld hl,(gfx_cy)
	ld a,(gfx_rh)
	ld e,a
	ld d,0
	add hl,de
	ld (gfx_cy),hl
	xor a
	ld (gfx_rh),a
	ld hl,0
	ld (gfx_cx),hl
1:	ld hl,(gfx_cx)
	ld (gfx_x),hl
	add hl,bc
	ld (gfx_cx),hl
	ld hl,(gfx_cy)
	ld (gfx_y),hl
	pop af
	ld hl,gfx_rh
	cp (hl)
	ret c
	ld (hl),a
	ret

; The tile number of dot gfx_x + HL, line gfx_y: (line / 8) x 64 + x / 8 into DE
gfx_tile:
	ld de,(gfx_x)
	add hl,de
	srl h				; x / 8: 0-63
	rr l
	srl l
	srl l
	push hl
	ld hl,(gfx_y)			; line / 8 x 64 = (line & $1F8) x 8
	ld a,l
	and $F8
	ld l,a
	add hl,hl
	add hl,hl
	add hl,hl
	pop de
	ld a,l
	or e
	ld e,a
	ld d,h
	ret

; Row C (from gfx_y) of a picture: byte D's dots (bit 7 first), colour E (0-15), at the three
; widths from gfx_x (16, then 32, then 64 dots: 2, 4, 8 dots a bit), or only the first (B 1)
gfx_row:
	ld a,b
	ld (gfx_once),a
	ld hl,(gfx_y)			; the line: page SGPAGE + line / 64, $4000 + (line & 63) x 256
	ld b,0
	add hl,bc
	ld a,l
	and 63
	add a,$40
	ld c,a
	add hl,hl
	add hl,hl
	ld a,h
	add a,SGPAGE
	push bc
	ld bc,PAGE1
	out (c),a
	pop bc
	ld h,c
	ld a,(gfx_x)			; + x / 2
	ld l,a
	ld a,(gfx_x + 1)
	rra
	rr l
	ld a,e				; the colour in both dots of a byte
	add a,a
	add a,a
	add a,a
	add a,a
	or e
	ld e,a
	ld c,1				; 1, 2, 4 bytes a bit
.width	push de
	ld b,8
.bit	xor a
	rl d
	jr nc,1F
	ld a,e
1:	push bc
	ld b,c
2:	ld (hl),a
	inc l
	djnz 2B
	pop bc
	djnz .bit
	pop de
	ld a,(gfx_once)			; (1: once)
	dec a
	ret z
	ld a,c
	add a,a
	ld c,a
	cp 8
	jr c,.width
	ret

; The objects' pictures: for each type 7-15 (the objects placed: river_gen's .kind) the kinds
; it can have: its own, those ROM_NEXT_KIND animates it into (kinds below $0C), and an
; explosion's (kinds 2 and 3 and on, with the type's colours), each also mirrored (shape
; offset + 16); height[type] + 1 rows from the shape's address + height[type] down, as the
; DLI draws them (ds_row). Each picture once (by its addresses), at the three widths.
obj_pics:
	ld hl,obj_head			; no picture yet
	ld de,obj_head + 1
	ld bc,255
	ld (hl),0
	ldir
	xor a
	ld (obj_count),a
	ld (op_bankn),a
	ld (op_bankn + 1),a
	ld (gfx_rh),a
	inc a				; (picture 0: none, obj_lookup)
	ld (op_p),a
	ld hl,0
	ld (gfx_cx),hl
	ld (gfx_cy),hl
	ld a,7
.type	ld (op_t),a
	ld hl,op_reach			; the kinds it can have
	ld b,16
.cr	ld (hl),0
	inc hl
	djnz .cr
	ld a,(op_t)
	call .mark
	ld a,2
	call .mark
	ld a,3
	call .mark
	ld c,16
.it	ld b,12				; (kinds $0C on are not animated)
	ld hl,op_reach
	ld de,ROM_NEXT_KIND
.ik	ld a,(hl)
	or a
	jr z,.in
	ld a,(de)
	push hl
	push de
	call .mark
	pop de
	pop hl
.in	inc hl
	inc de
	djnz .ik
	dec c
	jr nz,.it
	xor a
.kind	ld (op_k),a
	ld l,a
	ld h,0
	ld de,op_reach
	add hl,de
	ld a,(hl)
	or a
	jr z,.nk
	xor a				; as it is
	call .pic
	ld a,16				; mirrored
	call .pic
.nk	ld a,(op_k)
	inc a
	cp 16
	jr c,.kind
	ld a,(op_t)
	inc a
	cp 16
	jr c,.type
	ret

.mark	ld l,a				; kind A can be had
	ld h,0
	ld de,op_reach
	add hl,de
	ld (hl),1
	ret

; the picture of kind op_k + A (A: 0, or 16 mirrored), type op_t
.pic	ld hl,op_k
	add a,(hl)
	ld l,a
	ld h,0
	ld de,ROM_SHAPE_OFFSET
	add hl,de
	ld c,(hl)			; C: the shape's offset
	ld a,(op_t)
	ld l,a
	ld h,0
	ld de,ROM_OBJECT_HEIGHT
	add hl,de
	ld b,(hl)			; B: the height
	ld a,c
	add a,b
	ld (op_s),a			; the top row's shape byte: $B900 + offset + height
	ld e,a
	ld a,(op_t)
	ld l,a
	ld h,0
	ld de,ROM_COLOURS_OFFSET
	add hl,de
	ld a,(hl)
	add a,b
	ld (op_c),a			; and its colour: $B700 + offset + height
	ld d,a
	ld a,b
	inc a
	ld (op_left),a			; height + 1 rows
	ld a,(op_s)
	ld e,a
	call obj_lookup			; (made already)
	or a
	ret nz
	ld a,(op_t)			; its palette
	cp 12
	jr z,.ba
	cp 15
	jr z,.ba
	ld a,1
	jr .bs
.ba	xor a
.bs	ld (op_bank),a
	ld a,(obj_count)		; a new entry: its colour byte, picture (+ palette in bit
	cp OBJ_ENTRIES			; 7), the next with the same shape byte
	ret nc
	ld c,a
	inc a
	ld (obj_count),a
	ld h,high obj_e
	ld l,c
	ld a,(op_c)
	ld (hl),a
	ld a,l
	add a,OBJ_ENTRIES
	ld l,a
	ld a,(op_bank)
	rrca
	ld b,a
	ld a,(op_p)
	or b
	ld (hl),a
	ld a,l
	add a,OBJ_ENTRIES
	ld l,a
	ld a,(op_s)
	ld e,a
	ld d,high obj_head
	ld a,(de)
	ld (hl),a
	ld a,c
	inc a
	ld (de),a
	ld a,(op_left)			; its place: 112 dots across (16 + 32 + 64), its rows
	add a,7				; rounded up to 8
	and $F8
	push af
	ld bc,112
	call gfx_alloc
	pop af
	call pic_set			; (its tiles at the three widths)
	ld a,(op_s)			; its rows, the top first
	ld l,a
	ld h,high ROM_SHAPES
	ld (op_sp),hl
	ld a,(op_c)
	ld l,a
	ld h,high ROM_COLOURS
	ld (op_cp),hl
	ld c,0
.row	ld a,(op_left)
	or a
	ret z
	dec a
	ld (op_left),a
	push bc
	ld hl,(op_cp)
	ld a,(hl)
	dec hl
	ld (op_cp),hl
	and $FE				; (GTIA has no bit 0)
	ld e,a
	ld hl,(op_sp)
	ld a,(hl)
	dec hl
	ld (op_sp),hl
	or a
	jr z,.rowe
	ld d,a
	push de
	call .index			; A: the colour's place in the palette
	pop de
	ld e,a
	pop bc
	push bc
	ld b,0
	call gfx_row
.rowe	pop bc
	inc c
	jr .row

; colour E in palette op_bank: its place (1-15), the CRAM entry set when new
.index	ld a,(op_bank)
	ld c,a
	add a,a
	add a,a
	add a,a
	add a,a
	add a,low op_bankc
	ld l,a
	ld a,high op_bankc
	adc a,0
	ld h,a				; HL: the palette's colours (from place 1)
	push hl
	ld a,c
	add a,low op_bankn
	ld l,a
	ld a,high op_bankn
	adc a,0
	ld h,a
	ld b,(hl)			; B: how many
	ex (sp),hl
	ld c,1
	ld a,b
	or a
	jr z,.new
.find	inc hl
	ld a,(hl)
	cp e
	jr z,.found
	inc c
	djnz .find
	inc hl
	jr .add
.new	inc hl
.add	ld a,c				; (more than 15: the last; never)
	cp 16
	jr c,4F
	pop hl
	ld a,15
	ret
4:	ld (hl),e
	pop hl
	inc (hl)
	ld a,(op_bank)			; its CRAM word: group OBJ_PAL_A or B, entry C
	add a,OBJ_PAL_A
	ld b,c
	call cram_set
	ld a,b
	ret
.found	pop hl
	ld a,c
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
	add hl,bc
	ld bc,FMADDR
	ld a,$10 | high CRAM_SHADOW >> 4
	out (c),a
	ld b,high palette_lo
	ld c,e
	ld a,(bc)
	ld (hl),a
	inc hl
	inc b
	ld a,(bc)
	ld (hl),a
	ld bc,FMADDR
	xor a
	out (c),a
	pop hl
	pop bc
	ret

; Picture op_p: at gfx_x, gfx_y, A rows (a multiple of 8): its tiles at 16, 32 and 64 dots
; across (at gfx_x, + 16, + 48) and its YS; op_p on
pic_set:
	rrca				; YS: rows / 8 - 1 at bits 3-1
	rrca
	sub 2
	and $0E
	ld b,high pic_h
	ld hl,op_p
	ld c,(hl)
	inc (hl)
	ld (bc),a
	push bc
	ld hl,0
	call gfx_tile
	pop bc
	ld b,high pic_tn16_lo
	call .put
	push bc
	ld hl,16
	call gfx_tile
	pop bc
	ld b,high pic_tn32_lo
	call .put
	push bc
	ld hl,48
	call gfx_tile
	pop bc
	ld b,high pic_tn64_lo
.put	ld a,e
	ld (bc),a
	inc b
	ld a,d
	ld (bc),a
	ret

; The other players' and missiles' pictures, made at the start: the plane's, the tank's and
; the shell's frames (their shape pointers' tables, as prepare copies them into player-
; missile memory: row i of the frame at its line + i), the bullet (missile 2's 8 rows: a
; dot) and the helicopter's missile (missile 0's row: 4 dots); 16 dots across, a dot 2 of
; colour 1. pl_plane, pl_tank, pl_shell: each frame's picture, $FF for an empty one.
pl_pics:
	ld hl,ROM_PLANE_SHAPE
	ld de,pl_plane
	ld bc,10 << 8 | 14
	call .table
	ld hl,ROM_TANK_SHAPE
	ld de,pl_tank
	ld bc,8 << 8 | 11
	call .table
	ld hl,ROM_SHELL_SHAPE
	ld de,pl_shell
	ld bc,7 << 8 | 16
	call .table
	ld hl,op_buf			; the bullet: 8 rows of a dot (missile 2's bit 5)
	ld b,8
1:	ld (hl),$80
	inc hl
	djnz 1B
	ld a,(op_p)
	ld (pl_bullet),a
	ld hl,op_buf
	ld c,8
	call .write
	ld a,$F0			; the helicopter's missile: a row of 4 dots (missile 0's
	ld (op_buf),a			; 2 bits, 2 clocks each)
	ld a,(op_p)
	ld (pl_missile),a
	ld hl,op_buf
	ld c,1
	call .write
	ld bc,PAGE1
	ld a,WORK_PAGE
	out (c),a
	ret

; B frames, their shapes' pointers at HL, C rows each, the pictures into DE
.table	ld (op_tab),hl
	ld (op_out),de
	ld a,c
	ld (op_rows),a
	xor a
.frame	ld (op_k),a
	push bc
	ld l,a				; this frame's pointer
	ld h,0
	add hl,hl
	ld de,(op_tab)
	add hl,de
	ld e,(hl)
	inc hl
	ld d,(hl)
	ld b,a				; the same as an earlier frame's: its picture
	ld hl,(op_tab)
	or a
	jr z,.blank_q
.same	ld a,(hl)
	inc hl
	cp e
	jr nz,.diff
	ld a,(hl)
	cp d
	jr nz,.diff
	ld a,(op_k)			; (frame j = op_k - B)
	sub b
	ld l,a
	ld h,0
	push de
	ld de,(op_out)
	add hl,de
	pop de
	ld a,(hl)
	jr .put
.diff	inc hl
	djnz .same
.blank_q
	ld a,(op_rows)			; empty: none
	ld b,a
	push de
.bq	ld a,(de)
	inc de
	or a
	jr nz,.full
	djnz .bq
	pop de
	ld a,$FF
	jr .put
.full	pop hl				; (the rows)
	ld a,(op_rows)
	ld c,a
	ld a,(op_p)
	push af
	call .write
	pop af
.put	ld hl,(op_out)
	ld e,a
	ld a,(op_k)
	add a,l
	ld l,a
	adc a,h
	sub l
	ld h,a
	ld (hl),e
	pop bc
	ld a,(op_k)
	inc a
	djnz .frame
	ret

; picture op_p (and on): C rows from HL, 16 dots across, its rows rounded up to 8
.write	push bc
	push hl
	ld a,c
	add a,7
	and $F8
	push af
	ld bc,16
	call gfx_alloc
	pop af
	call pic_set
	pop hl
	pop bc
	ld b,c
	ld c,0
.wr	push bc
	push hl
	ld d,(hl)
	ld e,1
	ld b,1
	call gfx_row
	pop hl
	pop bc
	inc hl
	inc c
	djnz .wr
	ret
