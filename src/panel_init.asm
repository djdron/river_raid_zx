; The panel below the river and the scrolling line, set up once at the start (8K page 7,
; mapped at $6000 only while it runs): river_raid/port/src/status_bar.cpp.
;
; The two character sets go into the Atari's RAM where the game builds them at power-on
; (A0FB-A143): the scrolling line's at $0600, the panel's at $0800. Each 8x8 character is
; two tiles of the Next's tilemap (an Atari pixel, a colour clock, is two dots): tiles 0-127
; the panel's, 128-255 the scrolling line's, all in 8K page 10 (bank 5); tile 256 is made
; each frame for the scrolling line's first column (sprites.asm, panel_frame), and the map
; (40 x 32, with attributes) follows it in page 11.
;
; Also the fuel gauge's needle and the rainbow logo: sprites with fixed 4-bit patterns
; (124-127) and their colours.

	include "font.inc"

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

	nextreg $52,10			; the tiles
	ld de,$4000
	ld hl,$0800
	call .set
	ld hl,$0600
	call .set
	nextreg $52,11			; tile 256 and the map: empty
	ld hl,$4000
	ld de,$4001
	ld bc,TILE_MAP - TILE_256 + 40 * 32 * 2 - 1
	ld (hl),0
	ldir

	nextreg $43,%00110000		; the tilemap's palette: pixel 1 in offsets 0-3 the panel's
	ld hl,.tile_colours		; colours, 4 the scrolling line's
	ld b,5
	ld c,1
.tc	ld a,c
	nextreg $40,a
	ld a,(hl)
	call .colour
	nextreg $41,a
	inc hl
	ld a,c
	add a,16
	ld c,a
	djnz .tc

	nextreg $43,%00100000		; the sprites' palette: the needle (offset 4) and the logo's
	nextreg $40,NEEDLE_OFFSET * 16 + 1	; rows (offset 5, from $B48D)
	ld a,$1E
	call .colour
	nextreg $41,a
	nextreg $40,LOGO_OFFSET * 16 + 1
	ld b,7
	ld hl,ROM_LOGO_COLOURS + 6
.lc	ld a,(hl)
	call .colour
	nextreg $41,a
	dec hl
	djnz .lc

	ld bc,$303B			; the patterns: all empty, as the cache has them
	xor a
	out (c),a
	ld c,$5B
	ld d,64
.pc	ld b,0
.pc1	out (c),a
	djnz .pc1
	dec d
	jr nz,.pc
	ld hl,PATTERN_CACHE + $2000	; (page 7 at $6000 now)
	ld de,PATTERN_CACHE + $2001
	ld bc,PC_USED + $100 - PATTERN_CACHE - 1
	ld (hl),0
	ldir
	ld l,0				; each byte's first and last dots (edge_lo, edge_hi; display)
.eb	ld b,l
	ld c,0				; C the dot (bit 7 first), D the first ($FF none yet), E the
	ld de,$FF00			; last + 1
.ebb	sla b
	jr nc,.ebn
	ld e,c
	inc e
	inc d
	jr z,.ebf
	dec d
	jr .ebn
.ebf	ld d,c
.ebn	inc c
	bit 3,c
	jr z,.ebb
	ld h,high edge_lo
	ld (hl),d
	inc h
	ld (hl),e
	inc l
	jr nz,.eb
	ld bc,$303B			; 124: the needle (2 dots x 10 lines)
	ld a,62
	out (c),a
	ld c,$5B
	ld d,10
.needle	ld a,$11
	out (c),a
	out (c),a
	ld b,6
	xor a
.n0	out (c),a
	djnz .n0
	dec d
	jr nz,.needle
	ld b,6 * 8
	xor a
.n1	out (c),a
	djnz .n1
	ld e,1				; 125: the logo's quadruple-width part, a colour per row
.solid	ld a,e
	rlca
	rlca
	rlca
	rlca
	or e
	ld b,8
.s	out (c),a
	djnz .s
	inc e
	ld a,e
	cp 8
	jr nz,.solid
	ld b,9 * 8
	xor a
.s0	out (c),a
	djnz .s0
	ld e,0				; 126, 127: player 2's part, one colour clock further left on
.slant	ld b,0				; each row: dots 12 - 2k to 27 - 2k of the two
.dot	ld a,b
	call .logo_dot
	ld d,a
	inc b
	ld a,b
	call .logo_dot
	rlca
	rlca
	rlca
	rlca
	or d
	rrca				; (left dot in the high nibble)
	rrca
	rrca
	rrca
	out (c),a
	inc b
	ld a,b
	cp 16
	jr nz,.dot
	inc e
	ld a,e
	cp 16
	jr nz,.slant
	ld e,0
.slant2	ld b,16
.dot2	ld a,b
	call .logo_dot
	ld d,a
	inc b
	ld a,b
	call .logo_dot
	rlca
	rlca
	rlca
	rlca
	or d
	rrca
	rrca
	rrca
	rrca
	out (c),a
	inc b
	ld a,b
	cp 32
	jr nz,.dot2
	inc e
	ld a,e
	cp 16
	jr nz,.slant2

	nextreg $6E,$21			; the tilemap: map at bank 5 + $2100, tiles at + 0; 40 x 32,
	nextreg $6F,$00			; attributes, 512 tiles; over the sprites (USL, apply)
	nextreg $6C,0
	nextreg $4C,0			; pixel 0 transparent
	nextreg $2F,0
	nextreg $30,0
	nextreg $31,0
	nextreg $1C,%00001000		; its clip window: the panel and the scrolling line
	nextreg $1B,0
	nextreg $1B,159
	nextreg $1B,PANEL_FIRST_LINE
	nextreg $1B,PANEL_LAST_NTSC
	nextreg $6B,%10000010
	xor a
	ld (pc_next),a
	ld (pc_next + 1),a
	jp obj_pics			; the objects' patterns

; the dot B of row E of the logo's player 2 part: its colour (E + 1) or 0
.logo_dot
	cp 32
	jr nc,.none
	push bc
	ld c,a
	ld a,e
	cp 7
	jr nc,.nd
	add a,a				; 12 - 2E <= B <= 27 - 2E
	neg
	add a,12
	ld b,a
	ld a,c
	sub b
	jr c,.nd
	cp 16
	jr nc,.nd
	ld a,e
	inc a
	pop bc
	ret
.nd	pop bc
.none	xor a
	ret

; 64 characters at HL as 128 tiles at DE: the left half (bits 7-4) then the right one
.set	ld c,64
.char	push hl
	ld b,8
.left	ld a,(hl)
	rrca
	rrca
	rrca
	rrca
	call .nibble
	inc hl
	djnz .left
	pop hl
	push hl
	ld b,8
.right	ld a,(hl)
	call .nibble
	inc hl
	djnz .right
	pop hl
	ld a,l
	add a,8
	ld l,a
	jr nc,$+3
	inc h
	dec c
	jr nz,.char
	ret

; bits 3-0 of A as 4 bytes at DE, two dots of pixel 1 for each set bit
.nibble	push bc
	ld c,a
	ld b,4
.nb	xor a
	bit 3,c
	jr z,$+4
	ld a,$11
	ld (de),a
	inc de
	sla c
	djnz .nb
	pop bc
	ret

.colour	push hl
	ld l,a
	ld h,high palette
	ld a,(hl)
	pop hl
	ret

.tile_colours
	db $1E,$8E,$1E,$00		; the panel: PF0-PF3 (B66B)
	db $0C				; the scrolling line
