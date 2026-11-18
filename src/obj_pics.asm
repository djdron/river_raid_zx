; The objects' patterns, made once at the start (page 7, called by panel_init): every
; picture an object can have, whole, as 4-bit patterns from OBP_FIRST on, its colours in
; one of two sprite palette banks (OBJ_BANK_A: types 12 and 15, OBJ_BANK_B: the others;
; 15 and 14 colours, see NOTES.md). obj_lookup finds a picture by the addresses of its top
; row's shape byte and colour ($B9xx, $B7xx: what ds_objs keeps).
;
; The pictures: for each type 7-15 (the objects placed: river_gen's .kind) the kinds it can
; have: its own, those ROM_NEXT_KIND animates it into (kinds below $0C), and an explosion's
; (kinds 2 and 3 and on, with the type's colours), each also mirrored (shape offset + 16);
; height[type] + 1 rows from the shape's address + height[type] down, as the DLI draws them
; (ds_row); a pattern per 16 rows. 58 pictures, the same addresses once.

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
	ld a,OBP_FIRST
	ld (op_p),a
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
	ld a,(op_t)			; its bank
	cp 12
	jr z,.ba
	cp 15
	jr z,.ba
	ld a,1
	jr .bs
.ba	xor a
.bs	ld (op_bank),a
	ld a,(obj_count)		; a new entry: its colour byte, pattern (+ bank in bit 7),
	cp OBJ_ENTRIES			; the next with the same shape byte
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
	ld a,(op_s)			; its patterns, a row's dots each 2 pixels
	ld l,a
	ld h,high ROM_SHAPES
	ld (op_sp),hl
	ld a,(op_c)
	ld l,a
	ld h,high ROM_COLOURS
	ld (op_cp),hl
.chunk	ld a,(op_p)			; pattern / 2, the half (bit 7)
	ld c,a
	srl a
	bit 0,c
	jr z,1F
	or $80
1:	ld bc,$303B
	out (c),a
	ld a,16
	ld (op_rows),a
.row	ld a,(op_left)
	or a
	jr z,.blank
	dec a
	ld (op_left),a
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
	jr z,.blank
	ld d,a
	call .index			; A: the colour's place in the bank
	ld c,a
	rlca
	rlca
	rlca
	rlca
	or c
	ld c,a
	ld b,8
.dot	xor a
	rl d
	jr nc,2F
	ld a,c
2:	out ($5B),a
	djnz .dot
	jr .rowe
.blank	xor a
	ld b,8
3:	out ($5B),a
	djnz 3B
.rowe	ld hl,op_rows
	dec (hl)
	jr nz,.row
	ld hl,op_p
	inc (hl)
	ld a,(op_left)
	or a
	jr nz,.chunk
	ret

; colour E in bank op_bank: its place (1-15), the palette entry set when new
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
	ld h,a				; HL: the bank's colours (from place 1)
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
.add	ld a,c				; (more than 15: the last; NOTES.md, never)
	cp 16
	jr c,4F
	pop hl
	ld a,15
	ret
4:	ld (hl),e
	pop hl
	inc (hl)
	ld a,(op_bank)
	add a,OBJ_BANK_A
	add a,a
	add a,a
	add a,a
	add a,a
	add a,c
	nextreg $43,%00100000		; the sprites' palette
	nextreg $40,a
	ld l,e
	ld h,high palette
	ld a,(hl)
	nextreg $41,a
	ld a,c
	ret
.found	pop hl
	ld a,c
	ret
