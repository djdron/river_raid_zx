; A generated line as Layer 2 shows it: the 2-bit colour indices of the playfield (0 the
; background, 1 the bank, 2 the bank edge, 3 the water), two dots per colour clock, colour
; clocks WINDOW_FIRST..WINDOW_FIRST + 159 of the 192. The colours are the palette's,
; which the Copper changes per line as the DLI does (sprites.asm).

WINDOW_FIRST	equ 20		; the first colour clock shown (the water never comes nearer)

render_line:				; into Layer 2's row A (stored by columns: byte x * 256 + y,
	ld (wr_row),a			; 32 columns per 8K page)
	ld de,line_buf + WINDOW_FIRST / 4
	ld a,L2_FIRST_PAGE
.page	ld (rl_page),a
	nextreg $52,a
	ld a,(wr_row)
	ld l,a
	ld h,$40
	rept 4				; 4 bytes of the line: 16 colour clocks, 32 columns
	ld a,(de)
	ld c,a
	inc e
	ld b,high pix_tab
	ld a,(bc)
	ld (hl),a
	inc h
	ld (hl),a
	inc h
	inc b
	ld a,(bc)
	ld (hl),a
	inc h
	ld (hl),a
	inc h
	inc b
	ld a,(bc)
	ld (hl),a
	inc h
	ld (hl),a
	inc h
	inc b
	ld a,(bc)
	ld (hl),a
	inc h
	ld (hl),a
	inc h
	endr
	ld a,(rl_page)
	inc a
	cp L2_FIRST_PAGE + L2_PAGES
	jp nz,.page
	ret
