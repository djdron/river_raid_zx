; A generated line as Layer 2 shows it: the 2-bit colour indices of the playfield (0 the
; background, 1 the bank, 2 the bank edge, 3 the water), two dots per colour clock, colour
; clocks WINDOW_FIRST..WINDOW_FIRST + 159 of the 192. The colours are the palette's,
; which the Copper changes per line as the DLI does (sprites.asm).

WINDOW_FIRST	equ 20		; the first colour clock shown (the water never comes nearer)

WINDOW_END	equ WINDOW_FIRST / 4 + 40	; the byte after the last shown

; By draw_line's pieces (dl_seg): bytes of one value are one colour, 8 columns each, written
; without the table; an edge's bytes and a decoration's row through pix_tab.
render_line:				; into Layer 2's row A (stored by columns: byte x * 256 + y,
	ld (wr_row),a			; 32 columns per 8K page)
	ld l,a
	ld h,$40
	ld a,L2_FIRST_PAGE
	ld (rl_page),a
	nextreg $52,a
	ld iy,dl_seg
	ld d,high line_buf
.seg	ld a,(iy+0)
	cp WINDOW_END
	ret nc				; (the end: byte 48)
	ld e,a
	ld a,(iy+2)			; C: its end, B: its kind
	cp WINDOW_END
	jr c,.e
	ld a,WINDOW_END
.e	ld c,a
	ld b,(iy+1)
	inc iy
	inc iy
	ld a,e
	cp WINDOW_FIRST / 4
	jr nc,.s
	ld e,WINDOW_FIRST / 4
.s	ld a,c
	sub e
	jr c,.seg
	jr z,.seg
	ld c,a				; C: its bytes in the window
	djnz .table			; (kind 1: one value)
	ld a,(de)
	ld e,a
	ld d,high pix_tab
	ld a,(de)
	ld d,high line_buf
	ld e,a				; E: the colour
.chunk	ld a,$60			; bytes to the page's end (1-4)
	sub h
	rrca
	rrca
	rrca
	cp c
	jr c,.part
	ld b,c				; all of them in this page
	ld a,e
	call rl_fill
	bit 5,h
	call nz,rl_next
	jp .seg
.part	ld b,a				; to the page's end, the rest in the next
	ld a,c
	sub b
	ld c,a
	ld a,e
	call rl_fill
	call rl_next
	jr .chunk
.table	ld ixl,c
.byte	ld a,(de)
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
	bit 5,h
	call nz,rl_next
	dec ixl
	jr nz,.byte
	jp .seg

; B bytes' columns (8 each) of colour A
rl_fill:
	rept 8
	ld (hl),a
	inc h
	endr
	djnz rl_fill
	ret

; the next page's first column (A spent)
rl_next:
	ld h,$40
	ld a,(rl_page)
	inc a
	ld (rl_page),a
	nextreg $52,a
	ret
