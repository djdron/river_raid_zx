; The playfield's runs, for the collisions with it (pf_find, display.asm). Each river line
; has a record of 32 bytes in SPAN_PAGE (at $4000), in a ring of 256: river line k (from the
; top) at span_top + k, a new line at span_top - 1. A record: the offset of its edge's runs,
; then the runs of bank pixels (colour 1), ended by $FF, then those of edge pixels (colour 2),
; ended by $FF. A run is the colour clock it starts at and the one after it ends (32-224:
; pixel p is clock 32 + p), in order. Water and the background (colours 3, 0) are never
; looked at. (The river has at most 13 runs of the two on a line: 28 bytes.)

; The new line (line_buf): its record. Bytes of one colour, the run's, are passed over
; (span_class); in the others each pixel is looked at. Slot 2 is left with SPAN_PAGE.
span_line:
	nextreg $52,SPAN_PAGE
	ld hl,span_top
	dec (hl)
	ld a,(hl)
	span_rec
	push hl
	inc hl
	ex de,hl
	ld hl,span_tmp
	exx				; DE': where the bank's runs go, HL': the edge's (span_tmp)
	ld hl,line_buf
	ld d,high span_class
	ld c,0				; C: the colour of the run going on (0 none)
	ld b,48
.byte	ld e,(hl)
	ld a,(de)
	cp c
	jr nz,.mixed
	inc l
	djnz .byte
	jr .end
.mixed	push bc
	ld a,l				; B: the byte's first clock
	add a,a
	add a,a
	add a,32
	ld b,a
	ld a,e
	rept 4
	rlca				; the next pixel (bits 7-6)
	rlca
	ld e,a
	and 3
	cp 3
	jr nz,$+3
	xor a
	cp c
	call nz,.change
	inc b
	ld a,e
	endr
	ld a,c
	pop bc
	ld c,a
	inc l
	djnz .byte
.end	ld b,224			; the last run ends at 224
	xor a
	call .change
	exx
	ld a,$FF
	ld (hl),a
	pop hl				; the edge's runs after the bank's
	ld (de),a
	inc de
	ld a,e
	and $1F
	ld (hl),a
	ld hl,span_tmp
.copy	ld a,e				; (never more than the record holds)
	and $1F
	jr z,.full
	ld a,(hl)
	ld (de),a
	inc hl
	inc de
	inc a
	jr nz,.copy
	call .gaps
	jr .bgaps
.full	dec de
	ld a,$FF
	ld (de),a
	call .gaps
	jr .bgaps
; The line's water gaps (ds_edge_test): with 2 runs of edge pixels the one between them,
; with 4 the 1st-2nd and the 3rd-4th (the island between); with none all of it; else none
; ($FF: the runs looked at)
.gaps	ld a,(span_top)
	ld l,a
	ld de,span_tmp
	ld a,(de)
	cp $FF
	jr z,.g0
	ld h,high eg_e1
	inc e
	ld a,(de)			; the 1st's end
	ld (hl),a
	inc e
	ld a,(de)			; the 2nd's start
	cp $FF
	jr z,.gx
	inc h
	ld (hl),a
	inc e
	inc e
	ld a,(de)			; a 3rd?
	cp $FF
	jr z,.g2
	inc e
	ld a,(de)
	inc h
	ld (hl),a			; its end
	inc e
	ld a,(de)			; a 4th's start
	cp $FF
	jr z,.gx
	inc h
	ld (hl),a
	inc e
	inc e
	ld a,(de)			; no 5th
	cp $FF
	ret z
.gx	ld h,high eg_e1			; another number of runs: the runs looked at
	ld (hl),$FF
	ld h,high eg_e3
	ld (hl),$FF
	ret
.g2	ld h,high eg_e3
	ld (hl),$FF
	ret
.g0	ld h,high eg_e1			; none: all a gap
	ld (hl),0
	inc h
	ld (hl),$FF
	ld h,high eg_e3
	ld (hl),$FF
	ret

; the run of colour C ends at clock B, one of colour A starts there
.change	push af
	ld a,c
	dec a
	jr nz,.e2
	ld a,b
	exx
	ld (de),a
	inc de
	exx
	jr .open
.e2	dec a
	jr nz,.open
	ld a,b
	exx
	ld (hl),a
	inc hl
	exx
.open	pop af
	ld c,a
	dec a
	jr nz,.o2
	ld a,b
	exx
	ld (de),a
	inc de
	exx
	ret
.o2	dec a
	ret nz
	ld a,b
	exx
	ld (hl),a
	inc hl
	exx
	ret

; The line's two widest gaps between its runs of bank pixels (from the playfield's first clock,
; 32, before the first, to its end, 224, after the last), for dh_pf: bg_e1-bg_s2,
; bg_e3-bg_s4 ($FF: none)
.bgaps	ld a,(span_top)
	ld (.bi + 1),a
	span_rec
	inc l				; (the bank's runs)
	ld bc,$FF00			; B: the widest's start, C: its width;
	ld de,$FF00			; D, E: the next's
	ld a,32				; (the gap's start: the playfield's first clock)
.bg	ld (.bs + 1),a
	ld a,(hl)			; the next run's start: a gap to it
	cp $FF
	jr z,.blast
	call .gap
	inc l
	ld a,(hl)			; and on from its end
	inc l
	jr .bg
.blast	ld a,224			; (to the playfield's end)
	call .gap
	push hl
.bi	ld l,0
	ld h,high bg_e1
	ld (hl),b
	inc h
	ld a,b
	add a,c
	ld (hl),a
	inc h
	ld (hl),d
	inc h
	ld a,d
	add a,e
	ld (hl),a
	pop hl
	ret
.gap	push hl				; the gap from .bs to A (width A - start): one of the two
.bs	ld l,0				; widest?
	sub l
	jr c,.gx2
	cp c
	jr c,.g2nd
	ld d,b
	ld e,c
	ld b,l
	ld c,a
	pop hl
	ret
.g2nd	cp e
	jr c,.gx2
	ld d,l
	ld e,a
.gx2	pop hl
	ret

; Screen memory cleared: no runs on any line. Slot 2 is left with SPAN_PAGE. (The lines' gaps,
; eg_* and bg_*, are left as they are: they only let a line be passed over, and with no runs
; there is nothing on it to touch; span_line makes them anew with each line's runs.)
spans_clear:
	nextreg $52,SPAN_PAGE
	ld hl,SPANS
	ld de,32 - 2
	ld b,0
.rec	ld (hl),2
	inc hl
	ld (hl),$FF
	inc hl
	ld (hl),$FF
	add hl,de
	djnz .rec
	ret

; The masks (at the start): bits i..j of a byte, bit 7 the first: ($FF >> i) & ($FF << (7 - j))
span_init:
	ld hl,span_masks
	ld c,$FF
	ld b,8
.i	push bc
	ld a,$80
	ld b,8
.j	ld d,a
	and c
	ld (hl),a
	inc l
	ld a,d
	sra a
	djnz .j
	pop bc
	srl c
	djnz .i
	ret

; line_buf without its decoration (houses, roads): the bank's bytes where it was drawn. The
; collisions with the bank look at the line this way (the C++ port's bankRuns): without
; decoration a line is bank, edge, water, edge, bank (an island: twice).
plain_line:
	ld a,(dl_deco_n)
	or a
	ret z
	ld b,a
	ld de,dl_deco
.deco	ld a,(de)			; from
	ld l,a
	inc de
	ld a,(de)			; bytes
	inc de
	ld c,a
	ld h,high line_buf
	ld a,(dl_bank_fill)
.fill	ld (hl),a
	inc l
	dec c
	jr nz,.fill
	djnz .deco
	ret

