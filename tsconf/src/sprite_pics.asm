; The start's work that is needed only then, in a page of its own (INIT_PAGE) at $0000 while
; it runs (river_raid.asm: start): the sprites' pictures, the cartridge from the SD card
; (load_rom.asm, SPG builds), the General Sound's program.

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

; The panel's sprites' pictures: the needle (missile 1: 2 colour clocks, 10 rows), the logo's
; player 3 (quadruple width, data $FC: 48 dots) and player 2 (data $FF, a clock further left
; each row: 7 rows of 16 dots in 28)
panel_pics:
	ld a,16
	ld bc,16
	call gfx_alloc
	ld a,16
	call pic_set
	ld a,(op_p)
	dec a
	ld (pp_needle),a
	ld c,0
.nr	push bc
	ld de,$C001
	ld b,1
	call gfx_row
	pop bc
	inc c
	ld a,c
	cp 10
	jr c,.nr
	ld a,8				; player 3: its 64-dot picture
	ld bc,112
	call gfx_alloc
	ld a,8
	call pic_set
	ld a,(op_p)
	dec a
	ld (pp_logo3),a
	ld c,0
.l3	push bc
	ld a,c
	inc a
	ld e,a
	ld d,$FC
	ld b,0
	call gfx_row
	pop bc
	inc c
	ld a,c
	cp 7
	jr c,.l3
	ld a,8				; player 2: 32 dots, two 16-dot halves
	ld bc,32
	call gfx_alloc
	ld a,8
	call pic_set
	ld a,(op_p)
	dec a
	ld (pp_logo2),a
	ld c,0
.l2	push bc
	ld a,6				; row k: $FF00 >> (6 - k)
	sub c
	ld b,a
	ld hl,$FF00
	inc b
	jr 2F
1:	srl h
	rr l
2:	djnz 1B
	ld a,c
	inc a
	ld e,a
	push hl
	push de
	ld d,h
	ld b,1
	call gfx_row
	pop de
	pop hl
	pop bc
	push bc
	ld d,l
	ld hl,(gfx_x)
	push hl
	ld bc,16
	add hl,bc
	ld (gfx_x),hl
	pop hl
	pop bc
	push bc
	push hl
	ld b,1
	call gfx_row
	pop hl
	ld (gfx_x),hl
	pop bc
	inc c
	ld a,c
	cp 7
	jr c,.l2
	ld bc,PAGE1
	ld a,WORK_PAGE
	out (c),a
	ret
