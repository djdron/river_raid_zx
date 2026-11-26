; dh_pf, the Next's: not in page 6 (no room there) but in page 12 at P12_CODE, where the start
; copies it from page 7 (river_raid.asm, p12_code); the same as the TS-Conf's (display_hits.asm).

; (dh_pf) To `fail` unless the box (D to E) is inside one of line L's two gaps (g1: its
; end, then the next's start, a page on; g2 the same)
	macro DH_GAP g1, g2, fail
	ld h,high g1
	ld a,d
	cp (hl)
	jr c,1F
	inc h
	ld a,(hl)
	cp e
	jr nc,2F
1:	ld h,high g2
	ld a,d
	cp (hl)
	jp c,fail
	inc h
	ld a,(hl)
	cp e
	jp c,fail
2:
	endm

; NZ: sprite IX's rows meet the playfield on a river line (DE: pf_edge, pf_bank, pf_under;
; A: which gaps a line's box is looked up in first, bit 0 the edge's (eg_*), bit 1 the bank's
; (bg_*): inside the gaps, nothing to look at on the line)
dh_pf:
	ld (.fn + 1),de
	ld (.mode + 1),a
	ld a,(ix + 7)
	or a
	ret z
	ld c,a
	ld a,(ix + 3)			; the box: X to X + its clocks
	ld (.x0a + 1),a
	ld (.x0b + 1),a
	ld (.x0c + 1),a
	ld (.x0d + 1),a
	add a,(ix + 8)
	jr nc,1F
	xor a				; (past clock 255: none, the dots looked at)
	ld (.mode + 1),a
1:	ld (.x1a + 1),a
	ld (.x1b + 1),a
	ld (.x1c + 1),a
	ld (.x1d + 1),a
	ld b,(ix + 6)			; B: the line, DE: its row's byte (as dh_bits), C: the rows
	ld a,b				; left, cut to the river's lines
	add a,(ix + 0)
	ld e,a
	ld a,(ix + 9)
	adc a,0
	ld d,a
	ld a,(ix + 1)
	ld (.mask + 1),a
	ld a,b
	sub RIVER_FIRST
	jr nc,.in
	neg				; (k lines above the river: skipped)
	cp c
	jp nc,.no
	ld l,a
	ld a,c
	sub l
	ld c,a
	ld a,b
	add a,l
	ld b,a
	ld a,e
	add a,l
	ld e,a
	jr nc,1F
	inc d
1:	xor a
.in	cp RIVER_LINES
	jp nc,.no
	sub RIVER_LINES
	neg
	cp c
	jr nc,.q
	ld c,a
.q	ld a,(.mode + 1)		; first the box against the gaps on all its lines at once:
	or a				; inside on every one, nothing to look at on any (the dots
	jp z,.l				; need not be looked for); else line by line, as before
	push bc
	push de
	ld a,b
	sub RIVER_FIRST
	ld hl,span_top
	add a,(hl)
	ld l,a				; L: the first line's gaps
	ld b,c				; B: the lines
	ld a,(.mode + 1)
	ld c,a
	ld a,(.x0a + 1)			; D, E: the box
	ld d,a
	ld a,(.x1a + 1)
	ld e,a
	dec c
	jr z,.qe
	dec c
	jr z,.qb
.qeb	DH_GAP eg_e1, eg_e3, .qf
	DH_GAP bg_e1, bg_e3, .qf
	inc l
	djnz .qeb
	jr .qn
.qe	DH_GAP eg_e1, eg_e3, .qf
	inc l
	djnz .qe
	jr .qn
.qb	DH_GAP bg_e1, bg_e3, .qf
	inc l
	djnz .qb
.qn	pop de
	pop bc
	xor a
	ret
.qf	pop de
	pop bc
.l	ld a,(de)
.mask	and 0				; (no dots: nothing)
	jr nz,.dots
.n	inc de
	inc b
	dec c
	jp nz,.l
.no	xor a
	ret
.dots	push bc
	push de
	ld (.raw + 1),a
	ld a,b
	ld (bm_line),a
	sub RIVER_FIRST			; the line's span record (its gaps' index); the box against
	ld hl,span_top			; the gaps first, the dots looked at only if it is not inside
	add a,(hl)			; one (most lines: the plane over the water)
	ld l,a
.mode	ld c,0
	bit 0,c
	jr z,.bank
	ld h,high eg_e1
.x0a	ld a,0
	cp (hl)
	jr c,.e2
	inc h
	ld a,(hl)
.x1a	cp 0
	jr nc,.bank
.e2	ld h,high eg_e3
.x0b	ld a,0
	cp (hl)
	jr c,.look
	inc h
	ld a,(hl)
.x1b	cp 0
	jr c,.look
.bank	bit 1,c
	jr z,.gap
	ld h,high bg_e1
.x0c	ld a,0
	cp (hl)
	jr c,.b2
	inc h
	ld a,(hl)
.x1c	cp 0
	jr nc,.gap
.b2	ld h,high bg_e3
.x0d	ld a,0
	cp (hl)
	jr c,.look
	inc h
	ld a,(hl)
.x1d	cp 0
	jr c,.look
.gap	ld a,c				; (mode 0: no gaps, the dots looked at)
	or a
	jr nz,.n0
.look
.raw	ld d,0				; the dots (as dh_bits)
	ld e,(ix + 3)
	ld a,(ix + 4)
.fn	call 0
	or a
	jr z,.n0
	pop de
	pop bc
	or 1
	ret
.n0	pop de
	pop bc
	jp .n
