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
	ret
.full	dec de
	ld a,$FF
	ld (de),a
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

; Screen memory cleared: no runs on any line. Slot 2 is left with SPAN_PAGE.
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

