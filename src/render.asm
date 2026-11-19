; A generated line as Layer 2 shows it: the 2-bit colour indices of the playfield (0 the
; background, 1 the bank, 2 the bank edge, 3 the water), two dots per colour clock, colour
; clocks WINDOW_FIRST..WINDOW_FIRST + 159 of the 192. The colours are the palette's,
; which the Copper changes per line as the DLI does (sprites.asm).

WINDOW_FIRST	equ 20		; the first colour clock shown (the water never comes nearer)

WINDOW_END	equ WINDOW_FIRST / 4 + 40	; the byte after the last shown

; By draw_line's pieces (dl_seg), not from the line's bytes: bytes of one value are one
; colour, 8 columns each, written without the table; an edge's bytes (from its piece in the
; table at $B800) and a decoration's row (from its bitmap) through pix_tab.
render_line:				; into Layer 2's row A (stored by columns: byte x * 256 + y,
	ld (wr_row),a			; 32 columns per 8K page)
	ld l,a
	ld h,$40
	ld a,L2_FIRST_PAGE
	ld (rl_page),a
	nextreg $52,a
	ld iy,dl_seg
	jr .seg
.next	ld bc,4
	add iy,bc
.seg	ld a,(iy+0)			; B: its first byte, C: past its last, in the window
	cp WINDOW_END
	ret nc				; (the end: byte 48)
	ld b,a
	ld a,(iy+4)
	cp WINDOW_END
	jr c,1F
	ld a,WINDOW_END
1:	ld c,a
	ld e,(iy+2)			; DE: its data
	ld d,(iy+3)
	ld a,b
	sub WINDOW_FIRST / 4
	jr nc,2F
	neg				; (bytes before the window: past them in its data)
	ld b,WINDOW_FIRST / 4
	bit 0,(iy+1)
	jr nz,2F
	add a,e
	ld e,a
	jr nc,2F
	inc d
2:	ld a,c
	sub b
	jr c,.next
	jr z,.next
	ld c,a				; C: its bytes in the window
	ld a,(iy+1)
	dec a
	jr nz,.table			; (kind 1: one value, E)
	ld d,high pix_tab
	ld a,(de)
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
	jp .next
.part	ld b,a				; to the page's end, the rest in the next
	ld a,c
	sub b
	ld c,a
	ld a,e
	call rl_fill
	call rl_next
	jr .chunk
.table	ld a,(iy+1)			; an edge's bytes: in the table's page
	or a
	jr nz,.t
	ld d,high ROM_EDGE_PIECES
.t	ld ixl,c
.byte	ld a,(de)
	ld c,a
	inc de
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
	jp .next

