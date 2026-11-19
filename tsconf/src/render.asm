; A generated line as the picture shows it: the 2-bit colour indices of the playfield (0 the
; background, 1 the bank, 2 the bank edge, 3 the water), a byte a dot, two dots per colour
; clock, colour clocks WINDOW_FIRST..WINDOW_FIRST + 159 of the 192: 320 bytes at the start of
; the line's 512. The colours are CRAM's 0-3 (apply; colour 1 by line: the frame INT).

WINDOW_FIRST	equ 20		; the first colour clock shown (the water never comes nearer)

WINDOW_END	equ WINDOW_FIRST / 4 + 40	; the byte after the last shown

; By draw_line's pieces (dl_seg): bytes of one value are one colour, 8 dots each; an edge's
; bytes (from its piece in the table at $B800) and a decoration's row (from its bitmap)
; through pix_tab. Into the picture's line HL (0-511, more wraps), through window 1 (put back
; to WORK_PAGE at the end).
render_line:
	ld a,h				; the page: VID_PAGE + line / 32
	and 1
	ld h,a
	ld a,l
	add hl,hl
	add hl,hl
	add hl,hl
	ld e,h
	and 31				; the line's place in it: (line & 31) x 512
	add a,a
	add a,$40
	ld h,a
	ld l,0
	ld a,e
	add a,VID_PAGE
	ld bc,PAGE1
	out (c),a
	ld iy,dl_seg
	jr .seg
.next	ld bc,4
	add iy,bc
.seg	ld a,(iy+0)			; B: its first byte, C: past its last, in the window
	cp WINDOW_END
	jr nc,.end			; (the end: byte 48)
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
.fill	rept 8
	ld (hl),a
	inc hl
	endr
	dec c
	jr nz,.fill
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
	inc hl
	ld (hl),a
	inc hl
	inc b
	endr
	ld a,(bc)
	ld (hl),a
	inc hl
	ld (hl),a
	inc hl
	ld a,(rl_count)
	dec a
	ld (rl_count),a
	jr nz,.byte
	jp .next
.end	ld bc,PAGE1
	ld a,WORK_PAGE
	out (c),a
	ret
