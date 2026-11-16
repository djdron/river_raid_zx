; A generated line as Layer 2 shows it: the 2-bit colour indices of the playfield (0 the
; background, 1 the bank, 2 the bank edge, 3 the water), two dots per colour clock, colour
; clocks WINDOW_FIRST..WINDOW_FIRST + 159 of the 192. The colours are the palette's,
; which the Copper changes per line as the DLI does (sprites.asm).

WINDOW_FIRST	equ 20		; the first colour clock shown (the water never comes nearer)

render_line:
	ld hl,line_buf + WINDOW_FIRST / 4
	ld de,row_buf
	ld b,160 / 4
.byte	ld c,(hl)
	inc l
	rept 4
	ld a,c
	rlca
	rlca
	ld c,a
	and 3
	ld (de),a
	inc de
	ld (de),a
	inc de
	endr
	djnz .byte
	ret
