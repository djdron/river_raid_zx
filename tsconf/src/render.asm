; A generated line as the picture shows it, in the 16-colour mode: the 2-bit colour indices of
; the playfield (0 the background, 1 the bank, 2 the bank edge, 3 the water), two dots per
; colour clock (a byte: both nibbles the index), colour clocks WINDOW_FIRST..WINDOW_FIRST +
; 159 of the 192: 160 bytes at the start of the line's 256. The colours are those of the
; palette PALSEL picks for the line (0-7: entries 1-3 its bank, edge and water; apply, and
; the frame INT a line before a change of the bank's colour).

WINDOW_FIRST	equ 20		; the first colour clock shown (the water never comes nearer)

WINDOW_END	equ WINDOW_FIRST / 4 + 40	; the byte after the last shown
RL_DMA_MIN	equ 5		; a run of one value this long or longer: filled by the DMA

; By draw_line's pieces (dl_seg): bytes of one value are one colour, 8 dots each; an edge's
; bytes (from its piece in the table at $B800) and a decoration's row (from its bitmap)
; through pix_tab (its values both nibbles). Into the picture's line HL (0-511, more wraps),
; through window 1 (put back to WORK_PAGE at the end).
render_line:
	ld a,h				; the page: VID_PAGE + line / 64
	and 1
	ld h,a
	ld a,l
	add hl,hl
	add hl,hl
	ld e,h
	and 63				; the line's place in it: (line & 63) x 256
	add a,$40
	ld h,a
	ld l,0
	ld a,e
	add a,VID_PAGE
	ld (rl_page),a
	ld bc,PAGE1
	out (c),a
	ld iy,dl_seg
	jr .seg
.next	ld bc,4
	add iy,bc
.seg	ld a,(iy+0)			; B: its first byte, C: past its last, in the window
	cp WINDOW_END
	jp nc,.end			; (the end: byte 48)
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
	ld b,a
	ld a,c				; a long run by the DMA (a fill from rl_word), while it is
	cp RL_DMA_MIN			; free (the CPU's own: the one before it, a reset's clearing)
	jr c,.cpu
	push bc
	ld bc,DMACTRL
	in a,(c)
	rla
	pop bc
	jr nc,.dma
.cpu	ld a,b
.fill	rept 4
	ld (hl),a
	inc l
	endr
	dec c
	jr nz,.fill
	jp .next
.dma	ld a,b
	ld (rl_word),a
	ld (rl_word + 1),a
	ld a,c				; E: its words - 1, D: the low byte after it
	add a,a
	ld e,a
	dec e
	add a,a
	add a,l
	ld d,a
	ld bc,DMASADDRX
	ld a,HIGH_PAGE
	out (c),a
	dec b
	ld a,high (rl_word - $C000)
	out (c),a
	dec b
	ld a,low rl_word
	out (c),a
	ld bc,DMADADDRX			; the picture's page, the line in it, the byte
	ld a,(rl_page)
	out (c),a
	dec b
	ld a,h
	sub $40
	out (c),a
	dec b
	out (c),l
	ld bc,DMALEN
	out (c),e
	ld bc,DMANUM
	xor a
	out (c),a
	ld bc,DMACTRL			; fill
	ld a,$04
	out (c),a
	ld l,d
	jp .next
.table	ld a,(iy+1)			; an edge's bytes: in the table's page
	or a
	jr nz,.t
	ld d,high ROM_EDGE_PIECES
.t	ld a,c
	ld (rl_count),a
.byte	ld a,(de)
	ld c,a
	inc de
	ld b,high pix_tab
	rept 3
	ld a,(bc)
	ld (hl),a
	inc l
	inc b
	endr
	ld a,(bc)
	ld (hl),a
	inc l
	ld a,(rl_count)
	dec a
	ld (rl_count),a
	jr nz,.byte
	jp .next
.end	ld bc,PAGE1
	ld a,WORK_PAGE
	out (c),a
	ret
