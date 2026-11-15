; Drawing a generated line the way the game shows it: river_raid/port/src/river_draw.cpp
; (drawScreenLine), the line as it looks when it enters the screen, with the object of the
; slot it crosses. The result is row_buf: Atari colour codes (hue << 4 | luminance), two
; bytes per colour clock, colour clocks WINDOW_FIRST..WINDOW_FIRST + 159 of the 192.

WINDOW_FIRST	equ 20		; the first colour clock shown (the water never comes nearer)
ENTRY_SCANLINE	equ $5D		; the DLI's scanline counter on the row where new lines enter
SPRITE_LEFT	equ 32		; sprite position of the left edge of the screen buffer

COLOUR_BACKGROUND	equ $00
COLOUR_BANK_EDGE	equ $20
COLOUR_WATER		equ $84

render_line:
	ld a,COLOUR_BACKGROUND		; the colours of the 2-bit indices 0, 2, 3
	ld (rl_colours),a
	ld a,COLOUR_BANK_EDGE
	ld (rl_colours + 2),a
	ld a,COLOUR_WATER
	ld (rl_colours + 3),a
	; bank colour (sub $AFD0): the shade switches while a bridge is still being drawn in
	ld a,(BLOCK_FLAGS)
	and $04
	xor $D6
	ld (rl_colours + 1),a
	ld a,(ENTERING_SLOT)
	cp NO_SLOT
	jr nc,.find
	ld e,a
	ld d,0
	ld hl,SLOT_FLAGS
	add hl,de
	bit 7,(hl)
	jr z,.find
	ld hl,SLOT_Y
	add hl,de
	ld a,(hl)
	cp $5C
	jr nc,.find
	ld a,(rl_colours + 1)
	xor $04
	ld (rl_colours + 1),a
.find	; the first slot (from firstSlot up) whose sprite covers this scanline
	xor a
	ld (rl_have),a
	ld a,(FIRST_SLOT)
	ld c,a
.slot	ld a,c
	cp SLOTS
	jp nc,.expand
	ld e,c
	ld d,0
	ld hl,SLOT_TYPE
	add hl,de
	ld a,(hl)
	ld (rl_type),a
	ld l,a
	ld h,0
	push de
	ld de,ROM_OBJECT_HEIGHT
	add hl,de
	pop de
	ld b,(hl)			; height
	ld hl,SLOT_Y
	add hl,de
	ld a,(hl)
	add a,b
	sub ENTRY_SCANLINE		; row: how far up from the object's bottom row
	cp $80
	jr nc,.next
	ld (rl_row),a
	ld l,a
	ld a,b
	cp l
	jr nc,.found
.next	inc c
	jr .slot
.found	ld hl,SLOT_FLAGS
	add hl,de
	ld a,(hl)
	ld (rl_flags),a
	bit 7,a
	jr z,.shape
	ld hl,ROM_ROAD_COLOURS		; a bridge: the road next to it
	ld a,(rl_row)
	add a,l
	ld l,a
	adc a,h
	sub l
	ld h,a
	ld a,(hl)
	ld (rl_colours + 1),a
.shape	ld hl,SLOT_KIND
	add hl,de
	ld a,(rl_flags)			; facing left: frame + 16
	and $08
	add a,a
	add a,(hl)
	ld l,a
	ld h,high ROM_SHAPE_OFFSET
	ld a,low ROM_SHAPE_OFFSET
	add a,l
	ld l,a
	adc a,h
	sub l
	ld h,a
	ld a,(hl)			; shape offset from $B900
	ld hl,ROM_SHAPES
	call .add_a_row
	ld a,(hl)
	ld (rl_shape),a
	ld a,(rl_type)
	ld l,a
	ld h,0
	push de
	ld de,ROM_COLOURS_OFFSET
	add hl,de
	pop de
	ld a,(hl)			; colours offset from $B700
	ld hl,ROM_COLOURS
	call .add_a_row
	ld a,(hl)
	ld (rl_colour),a
	ld hl,SLOT_X
	add hl,de
	ld a,(hl)
	ld (rl_x),a
	ld hl,SLOT_SIZE
	add hl,de
	ld a,(hl)
	and 3				; SIZEP3: 1 double, 3 quad
	ld b,1
	jr z,.w
	cp 1
	ld b,2
	jr z,.w
	cp 3
	ld b,1
	jr nz,.w
	ld b,4
.w	ld a,b
	ld (rl_width),a
	ld a,1
	ld (rl_have),a
.expand	; the playfield: 2-bit colour indices to colour codes
	ld ix,line_buf + WINDOW_FIRST / 4
	ld de,row_buf
	ld h,high rl_colours
	ld b,160 / 4
.byte	ld c,(ix+0)
	inc ix
	rept 4
	ld a,c
	rlca
	rlca
	ld c,a
	and 3
	ld l,low rl_colours
	add a,l
	ld l,a
	ld a,(hl)
	ld (de),a
	inc de
	ld (de),a
	inc de
	endr
	djnz .byte
	ld a,(rl_have)
	or a
	ret z
	; the object's row: 8 dots of 1, 2 or 4 colour clocks
	ld a,(rl_x)
	ld l,a
	ld h,0
	ld de,-(SPRITE_LEFT + WINDOW_FIRST)
	add hl,de			; HL: colour clock in the window (signed)
	ld a,(rl_shape)
	ld c,a
	ld b,8
.dot	sla c
	jr nc,.skip
	push hl
	push bc
	ld a,(rl_width)
	ld b,a
.clock	ld a,h
	or a
	jr nz,.out			; left of the window
	ld a,l
	cp 160
	jr nc,.out			; right of it
	push hl
	add hl,hl
	ld de,row_buf
	add hl,de
	ld a,(rl_colour)
	ld (hl),a
	inc hl
	ld (hl),a
	pop hl
.out	inc hl
	djnz .clock
	pop bc
	pop hl
.skip	ld a,(rl_width)
	ld e,a
	ld d,0
	add hl,de
	djnz .dot
	ret
.add_a_row				; HL += A + rl_row
	add a,l
	ld l,a
	adc a,h
	sub l
	ld h,a
	ld a,(rl_row)
	add a,l
	ld l,a
	adc a,h
	sub l
	ld h,a
	ret
