; The panel below the river and the scrolling line on TS-Conf: river_raid/port/src/
; status_bar.cpp (drawStatusBar, PAL's layout: the board's frame is 50 Hz). Screen rows
; 184-239 (the C++ port's 180-235, 4 rows lower as the river is) come from a picture of their
; own (VPANEL: its line 0 is row 184), which the frame INT puts in at row 184 with the bitmap
; over the tiles and sprites (GFXOVR, its holes, dots of 0, showing them):
; - the characters (the panel's 3 rows, the scrolling line) are its dots: colours 4-7 the
;   panel's PF0-PF3, 8 the scrolling line's; the rest holes;
; - under them tile layer 0: the panel's grey (CRAM $3F) on rows 185-223, black ($3E) on the
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
GLYPHS		equ 64			; the characters drawn once (pc_put copies them by the DMA):
					; the picture's lines 64-79 the scrolling line's (colour 8),
					; 80-143 the panel's in colours 4-7; 32 a line of 8 lines

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
	ld hl,.colours			; the colours: the characters' (group 0, 4-8; PAL_BLACK's too,
	ld b,4				; the panel shown while the river is black), the needle's,
.pc	ld e,(hl)			; the logo's rows (from $B48D, the bottom one first), the
	inc hl				; tiles' black and grey
	xor a
	call cram_set
	ld a,PAL_BLACK
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
	ld a,3				; (palette 3's colours 14 and 15: the river's palettes use
	ld b,14				; 0-3)
	ld e,$00
	call cram_set
	ld a,3
	ld b,15
	ld e,$06
	call cram_set
	ld bc,PAGE1
	ld a,WORK_PAGE
	out (c),a
	ld c,0				; the characters, drawn once: the scrolling line's,
.gl	push bc
	ld a,c
	ld d,$06
	ld b,8
	call pc_bank
	call pc_draw
	pop bc
	push bc
	ld a,4				; the panel's in its 4 colours
.gp	push af
	ld b,a
	ld a,c
	ld d,$08
	call pc_bank
	call pc_draw
	pop af
	pop bc
	push bc
	inc a
	cp 8
	jr c,.gp
	pop bc
	inc c
	ld a,c
	cp 64
	jr c,.gl
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
	jr pc_put
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
	jr pc_put

; Where character A (bits 5-0) of the set at D x 256, colour B, was drawn once: line E, dot
; HL (A, B, D kept)
pc_bank:
	push af
	and $3F
	ld e,a				; x: 16 x (A mod 32)
	and $1F
	ld l,a
	ld h,0
	add hl,hl
	add hl,hl
	add hl,hl
	add hl,hl
	ld a,e				; the line: 64 (the scrolling line's) or 80 + 16 x (B - 4)
	and $20				; (the panel's), + 8 for 32-63
	rrca
	rrca
	ld e,a
	ld a,d
	cp $06
	ld a,64
	jr z,1F
	ld a,b
	sub 4
	add a,a
	add a,a
	add a,a
	add a,a
	add a,80
1:	add a,e
	ld e,a
	pop af
	ret

; Character A of the set at D x 256 in colour B into the panel's picture at line E, dot HL
; (from -8: the dots left of 0 not put), copied by the DMA from where it was drawn once
; (pc_bank); by pc_draw while the DMA is busy (a reset's clearing)
pc_put:
	push bc
	ld bc,DMACTRL
	in c,(c)
	bit 7,c
	pop bc
	jr nz,pc_draw
	push hl
	push de
	call pc_bank			; the source: line E, dot HL
	ld a,e
	call pc_adr
	ld bc,DMASADDRX
	call pc_reg
	pop de
	pop hl
	ld bc,7				; 8 words a line (16 dots); from -8: 4, from dot 8 of it
	bit 7,h
	jr z,1F
	ld bc,DMASADDRL			; (the source's address: 8 bytes on)
	ld a,(pc_src)
	add a,8
	out (c),a
	ld hl,0
	ld bc,3
1:	push bc
	ld a,e
	call pc_adr
	ld bc,DMADADDRX
	call pc_reg
	pop bc
	ld a,c
	ld bc,DMALEN
	out (c),a
	ld bc,DMANUM			; 8 lines
	ld a,7
	out (c),a
	ld bc,DMACTRL			; RAM to RAM, both by lines of 512 bytes
	ld a,$39
	out (c),a
	ret
; the panel's picture's line A, dot HL: its page (A) and address in it (HL)
pc_adr:	push af
	and 31
	add a,a
	add a,h
	ld h,a
	pop af
	rlca
	rlca
	rlca
	and 7
	add a,VPANEL
	ret
; a DMA address: page A, address HL to the registers from BC (X) down (L kept in pc_src)
pc_reg:	out (c),a
	dec b
	ld a,h
	out (c),a
	dec b
	ld a,l
	ld (pc_src),a
	out (c),a
	ret

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
