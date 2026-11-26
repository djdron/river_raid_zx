; The playfield's runs, for the collisions with it (pf_find, display.asm). Each river line
; has a record of 32 bytes in SPAN_PAGE (at $4000), in a ring of 256: river line k (from the
; top) at span_top + k, a new line at span_top - 1. A record: the offset of its edge's runs,
; then the runs of bank pixels (colour 1), ended by $FF, then those of edge pixels (colour 2),
; ended by $FF. A run is the colour clock it starts at and the one after it ends (32-224:
; pixel p is clock 32 + p), in order. Water and the background (colours 3, 0) are never
; looked at. (The river has at most 13 runs of the two on a line: 28 bytes.)

; The new line: its record, from draw_line's pieces (dl_seg), not from the line's bytes:
; bytes of one value are one colour, a decoration's row is the bank's (as the C++ port's
; bankRuns has it, the line without decoration); an edge's runs come ready from its piece
; (edge_runs, made at the start): no pixel is looked at. Slot 2 is left with SPAN_PAGE.
span_line:
				; (TS-Conf: window 1 holds SPANS)
	ld hl,span_top
	dec (hl)
	ld a,(hl)
	span_rec
	push hl
	inc hl
	ex de,hl
	ld hl,span_tmp
	exx				; DE': where the bank's runs go, HL': the edge's (span_tmp)
	ld iy,dl_seg
	ld d,high span_class
	ld c,0				; C: the colour of the run going on (0 none)
	jr .seg
.next	ld de,4
	add iy,de
	ld d,high span_class
.seg	ld a,(iy+0)
	cp 48
	jp nc,.end
	ld a,(iy+1)
	or a
	jr z,.edge
	dec a
	ld e,(iy+2)			; bytes of one value
	jr z,.one
	ld a,(dl_bank_fill)		; a row of decoration: the bank
	ld e,a
.one	ld a,(de)
	cp c
	jr z,.next
	ld e,a
	ld a,(iy+0)			; a run starts at its first clock
	add a,a
	add a,a
	add a,32
	ld b,a
	ld a,e
	call .change
	jr .next
.edge	ld a,(iy+4)			; an edge's runs, made at the start from its piece in the
	cp 48				; table at $B800 (edge_runs), up to the next piece
	jr c,.e48
	ld a,48
.e48	sub (iy+0)
	add a,a
	add a,a
	ld (.lim + 1),a
	ld a,(iy+0)			; E: its first clock
	add a,a
	add a,a
	add a,32
	ld e,a
	ld a,(iy+2)
	add a,a
	add a,a
	add a,a
	ld l,a
	ld h,high edge_runs
.tr	ld a,(hl)			; the clock in the piece (past it, $FF: the end)
.lim	cp 0
	jp nc,.next
	add a,e
	ld b,a
	inc l
	ld a,(hl)			; and its colour
	inc l
	cp c
	call nz,.change
	ld a,l				; (8 pairs: the piece's end)
	and 15
	jr nz,.tr
	jp .next
.end	ld b,224			; the last run ends at 224
	xor a
	call .change
	exx
	ld a,$FF
	ld (hl),a
	ld a,l				; B: the edge's bytes with their $FF
	sub low span_tmp - 1
	ld b,a
	pop hl				; the edge's runs after the bank's
	ld a,$FF
	ld (de),a
	inc de
	ld a,e
	and $1F
	ld (hl),a
	jr z,.cut			; (the bank's filled it)
	sub 32				; C: the room left in the record (never more than it holds:
	neg				; cut, an $FF last)
	ld c,a
	cp b
	ld a,b
	jr c,.full
	ld c,a
	ld b,0
	ld hl,span_tmp
	ldir
	jr .done
.full	ld b,0
	ld hl,span_tmp
	ldir
.cut	dec de
	ld a,$FF
	ld (de),a
.done	call .gaps
	jp .bgaps
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
.change	ex af,af'			; (A': the new one; the INT keeps AF')
	ld a,b
	dec c
	jr z,.cb
	dec c
	jr nz,.open
	exx				; the edge's ends
	ld (hl),a
	inc hl
	exx
	jr .open
.cb	exx				; the bank's
	ld (de),a
	inc de
	exx
.open	ex af,af'
	ld c,a
	dec a
	jr z,.ob
	dec a
	ret nz
	ld a,b				; an edge's starts
	exx
	ld (hl),a
	inc hl
	exx
	ret
.ob	ld a,b				; a bank's
	exx
	ld (de),a
	inc de
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
				; (TS-Conf: window 1 holds SPANS)
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



; At the start: each edge piece's runs (edge_runs, for span_line): pixels 0-7 of the
; piece's two bytes in the table at $B800 (offsets 0-30), a pair (the pixel, its colour, 3
; the water as 0: span_class) at the first and at each change of colour, $FF after
edge_runs_init:
	ld ix,edge_runs
	ld hl,ROM_EDGE_PIECES		; piece's two bytes, a pair at the first and at each change of
.ep	ld b,(hl)			; colour (3, the water, as 0: span_class)
	inc l
	ld c,(hl)
	inc l
	push hl
	push ix
	ld de,$FF			; E: the colour before, D: the pixel
.px	ld a,b
	rlca
	rlca
	and 3
	cp 3
	jr nz,1F
	xor a
1:	cp e
	jr z,2F
	ld e,a
	ld (ix + 0),d
	ld (ix + 1),a
	inc ix
	inc ix
2:	sla c
	rl b
	sla c
	rl b
	inc d
	ld a,d
	cp 8
	jr c,.px
	ld a,ixl			; (8 pairs: no room for the end, nor need)
	and 15
	jr z,3F
	ld (ix + 0),$FF
3:	pop ix
	ld de,16
	add ix,de
	pop hl
	ld a,l
	cp 32
	jr c,.ep
	ret
