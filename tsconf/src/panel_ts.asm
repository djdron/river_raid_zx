; The panel below the river and the scrolling line on TS-Conf: river_raid/port/src/
; status_bar.cpp (drawStatusBar, PAL's layout: the board's frame is 50 Hz). Screen rows
; 184-239 (the C++ port's 180-235, 4 rows lower as the river is) come from a picture of their
; own (VPANEL: its line 0 is row 184), which the frame INT puts in at row 184 with the bitmap
; over the tiles and sprites (GFXOVR, its holes, dots of 0, showing them):
; - the characters (the panel's 3 rows, the scrolling line) are its dots: colours 4-7 the
;   panel's PF0-PF3, 8 the scrolling line's; the rest holes;
; - under them tile layer 0: the panel's grey (CRAM $32) on rows 185-223, black ($31) on the
;   others; it hides the river's sprites (S0) there;
; - the fuel gauge's needle and the rainbow logo: sprites over the tiles (S1).
; The scrolling line is a ring of 32 characters across the picture's 512 dots, shown from
; GXOFFS (set by the frame INT at its first row): a character is written when it comes in.

VPANEL		equ 64			; the panel's picture: pages 64-79 (VPAGE, a multiple of 16)
PANEL_ROW	equ RIVER_TOP + RIVER_LINES	; its first row (184)
SCROLL_LINE	equ 227 - PANEL_ROW	; the scrolling line's (C++ 223)
NEEDLE_ROW	equ $CC + 7 - 8 + 4	; the needle's first row (C++ $CB)
LOGO_ROW	equ 227			; the logo's
NEEDLE_PAL	equ 11			; CRAM groups: the needle (1),
LOGO_PAL	equ 12			; the logo's rows (1-7)
GREY_ROW	equ PANEL_ROW + 1	; the grey: rows 185-223
GREY_END	equ 224

; At the start: the two character sets into the Atari's RAM where the game builds them at
; power-on (A0FB-A143): the scrolling line's at $0600, the panel's at $0800
panel_init:
	ld hl,$0600			; A0FB: RAM $0600-$09FF from the OS font and the cartridge
	ld de,$0601
	ld bc,$03FF
	ld (hl),0
	ldir
	ld hl,font_e000 + 8		; (the copy starts at byte 8: character 0 stays blank)
	ld de,$0808
	ld bc,248
	ldir
	ld hl,font_e100 + 8
	ld de,$0908
	ld bc,248
	ldir
	ld hl,font_e100 + 8
	ld de,$0608
	ld bc,248
	ldir
	ld hl,font_e300 + 8
	ld de,$0708
	ld bc,248
	ldir
	ld hl,ROM_LOGO_LETTERING
	ld de,$06C0
	ld bc,$40
	ldir
	ld hl,ROM_PANEL_SYMBOLS
	ld de,$0818
	ld bc,$70
	ldir
	ld hl,ROM_PLAYER_LABELS
	ld de,$08D0
	ld bc,$18
	ldir
	ld hl,ROM_YEAR_DIGITS
	ld de,$07D0
	ld bc,$30
	ldir
	ld hl,.colours			; the colours: the characters' (group 0, 4-8), the needle's,
	ld b,4				; the logo's rows (from $B48D, the bottom one first), the
.pc	ld e,(hl)			; tiles' black and grey
	inc hl
	xor a
	call cram_set
	inc b
	ld a,b
	cp 9
	jr c,.pc
	ld a,NEEDLE_PAL
	ld b,1
	ld e,$1E
	call cram_set
	ld hl,ROM_LOGO_COLOURS + 6
	ld b,1
.lc	ld e,(hl)
	dec hl
	ld a,LOGO_PAL
	call cram_set
	inc b
	ld a,b
	cp 8
	jr c,.lc
	ld a,3
	ld b,1
	ld e,$00
	call cram_set
	ld a,3
	ld b,2
	ld e,$06
	call cram_set
	; the sprites' pictures: the needle (missile 1: 2 colour clocks, 10 rows), the logo's
	; player 3 (quadruple width, data $FC: 48 dots) and player 2 (data $FF, a clock further
	; left each row: 7 rows of 16 dots in 28)
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
	ld a,$FF			; the scrolling line: all of it written at the first frame
	ld (pf_ring),a
	ld a,60				; and the panel
	ld (pf_dirty_n),a
	ld bc,PAGE1			; the panel's picture: lines 0-63 cleared
	ld a,VPANEL
	call .clear
	ld a,VPANEL + 1
	call .clear
	ld bc,PAGE1
	ld a,WORK_PAGE
	out (c),a
	ret
.clear	out (c),a
	ld hl,$4000
	ld de,$4001
	push bc
	ld bc,$3FFF
	ld (hl),0
	ldir
	pop bc
	ret
.colours	db $1E,$8E,$1E,$00,$0C

; ------------------------------------------------------------------------------------------
; The panel and the scrolling line of the frame (drawStatusBar), as the frame leaves them.
; panel_frame (apply, before the INT's events are set): the scrolling line's X (pf_gx, for
; the frame INT), the needle's and the logo's sprites (spr_s1); panel_draw (apply, after
; them: it may take a while): the characters panel_put listed, those of the scrolling line
; that came in.
panel_draw:
	ld a,(pf_dirty_n)		; the panel: 3 rows of 20 characters at lines 6, 18 and 26,
	or a				; from 8 dots left of the screen
	jr z,.scroll
	cp 60
	jr c,.list
	ld b,60				; all
	ld e,0
.all	push de
	push bc
	ld a,e
	call panel_frame.char
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
	call panel_frame.char
	pop bc
	pop de
	djnz .l
.panel_end
	xor a
	ld (pf_dirty_n),a
.scroll	; the scrolling line: character t (from $B800 + t) at the ring's dot 16 t mod 512; the 25
	; drawn from TEXT_LO on there (one more when TEXT_LO went on by one; all of them when it
	; jumped); X: 16 TEXT_LO + 38 - 2 FINE_SCROLL
	ld a,(TEXT_LO)
	ld hl,pf_ring
	ld c,a
	sub (hl)
	jr z,.x
	ld (hl),c
	dec a
	jr nz,.ring
	ld a,c				; one: TEXT_LO + 24
	add a,24
	ld l,a
	ld a,0
	adc a,0
	ld h,a
	call panel_frame.text
	jr .x
.ring	ld l,c				; all 25
	ld h,0
	ld b,25
.rr	push bc
	push hl
	call panel_frame.text
	pop hl
	pop bc
	inc hl
	djnz .rr
.x	ld bc,PAGE1
	ld a,WORK_PAGE
	out (c),a
	ret

panel_frame:
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
	add hl,de
	ld a,h
	and 1
	ld h,a
	ld (pf_gx),hl
	; the needle: missile 1 at fuel / 8 + $5C (B527)
	ld ix,spr_s1
	ld a,(FUEL)
	rrca
	rrca
	rrca
	and $1F
	add a,$5C
	ld e,a
	ld d,NEEDLE_ROW
	ld a,NEEDLE_PAL << 4
	ld (pf_pal),a
	ld a,(pp_needle)
	ld bc,high pic_tn16_lo << 8 | $02	; (16 dots)
	call .spr
	ld a,LOGO_PAL << 4
	ld (pf_pal),a
	; the logo: player 3 at quadruple width (data $FC) at LOGO_X, player 2 (data $FF) from
	; $15 clocks right of it, a clock further left each row (B72A)
	ld a,(logo_shown)
	ld e,a
	ld d,LOGO_ROW
	ld a,(pp_logo3)
	ld bc,high pic_tn64_lo << 8 | $0E	; (its 64-dot picture)
	call .spr
	ld a,(logo_shown)
	add a,$15 - 6
	ld e,a
	ld d,LOGO_ROW
	ld a,(pp_logo2)
	ld bc,high pic_tn16_lo << 8 | $06	; (32 dots from its first)
	call .spr
	ret

; S1's sprite at IX: picture A (its first tile from the tables at B x 256: pic_tn16_lo or
; pic_tn64_lo), screen row D, position E (X = 2 x (E - 52), 9 bits), XS C (bits 3-1: 16 dots
; 2, 32: 6, 64: 14), palette pf_pal
.spr	push af
	ld (ix + 0),d			; Y
	ld l,a				; ACT, its rows (YS)
	ld h,high pic_h
	ld a,(hl)
	or $20
	ld (ix + 1),a
	ld a,e
	sub 32 + WINDOW_FIRST
	ld l,a
	sbc a,a
	ld h,a
	add hl,hl
	ld (ix + 2),l
	ld a,h
	and 1
	or c
	ld (ix + 3),a
	pop af
	ld c,a
	ld a,(bc)
	ld (ix + 4),a
	inc b
	ld a,(bc)
	ld e,a
	ld a,(pf_pal)
	or e
	ld (ix + 5),a
	ld de,SPR_SIZE
	add ix,de
	ret

; panel position A: its character at line 6, 18 or 26 + its row, dot -8 + 16 x its column
.char	ld l,a
	ld h,high PANEL
	ld c,(hl)			; the character
	ld b,0				; B: the row
	cp 20
	jr c,1F
	inc b
	sub 20
	cp 20
	jr c,1F
	inc b
	sub 20
1:	ld l,a				; x = 16 x column - 8
	ld h,0
	add hl,hl
	add hl,hl
	add hl,hl
	add hl,hl
	ld de,-8
	add hl,de
	push hl
	ld hl,.rows
	ld e,b
	ld d,0
	add hl,de
	ld e,(hl)			; the line
	pop hl
	ld a,c				; its colour: 4 + bits 7-6
	rlca
	rlca
	and 3
	add a,4
	ld b,a
	ld a,c
	ld d,$08			; the panel's set
	jr pc_draw
.rows	db 6, 18, 26

; character t = HL of the scrolling line ($B800 + t) at the ring's dot 16 t mod 512
.text	ld de,ROM_SCROLL_TEXT
	add hl,de
	ld c,(hl)
	or a
	sbc hl,de
	add hl,hl			; 16 t mod 512
	add hl,hl
	add hl,hl
	add hl,hl
	ld a,h
	and 1
	ld h,a
	ld e,SCROLL_LINE
	ld b,8				; colour 8
	ld a,c
	ld d,$06			; the scrolling line's set
	; (on into pc_draw)

; Character A (bits 5-0) of the set at D x 256 into the panel's picture: line E, dot HL (from
; -8: the dots left of 0 not drawn), colour B for its set dots, 0 (a hole) for the others
pc_draw:
	push hl
	and $3F
	ld l,a
	ld h,0
	add hl,hl
	add hl,hl
	add hl,hl
	ld a,d
	add a,h
	ld h,a
	ld (pc_glyph),hl
	pop hl
	ld a,b
	ld (pc_colour),a
	ld (pc_x),hl
	ld a,e
	ld (pc_line),a
	ld b,8
.row	push bc
	ld hl,(pc_glyph)
	ld d,(hl)			; D: the row's dots
	inc hl
	ld (pc_glyph),hl
	ld a,(pc_line)			; its place: page VPANEL + line / 32, $4000 + (line & 31)
	ld e,a				; x 512 + x
	inc a
	ld (pc_line),a
	ld a,e
	rlca
	rlca
	rlca
	and 7
	add a,VPANEL
	ld bc,PAGE1
	out (c),a
	ld a,e
	and 31
	add a,a
	add a,$40
	ld h,a
	ld l,0
	ld bc,(pc_x)
	ld a,b				; (from -8: the first 8 dots left out)
	or a
	jp p,1F
	ld a,(pc_colour)
	ld e,a
	ld b,4				; past bits 7-4
2:	rl d
	djnz 2B
	ld b,4
	jr .dots
1:	add hl,bc
	ld a,(pc_colour)
	ld e,a
	ld b,8
.dots	xor a				; a dot: 2 of colour E, or holes
	rl d
	jr nc,3F
	ld a,e
3:	ld (hl),a
	inc hl
	ld (hl),a
	inc hl
	djnz .dots
	pop bc
	djnz .row
	ret
