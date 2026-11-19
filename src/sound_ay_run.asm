; The pure tones on the AY, every frame (sound_ay.asm says how). In page 6, not page 7 with
; the rest: calling them there would map page 7 at $6000-$7FFF, where the DAC's ring is
; (page 12), and the DMA, which reads through the same mapping, would send page 7's bytes
; meanwhile: a sample or two a frame at 0, heard as crackle.

ay_vol:	db 0, 8, 10, 12, 13, 13, 14, 14, 15, 15, 15, 15, 15, 15, 15, 15

; this frame's tones and noise (ay_mask: the POKEY channels they take), then the AY what they
; were 2 frames ago
AYQ_NOW		equ ay_q + 2 * AYF

ay_frame:
	xor a
	ld (ay_mask),a
	ld hl,AYQ_NOW + AYF_N1		; no noise yet
	ld (hl),a
	inc l
	ld (hl),$38			; (the first AY: its tones on, no noise)
	inc l
	ld (hl),a
	inc l
	ld (hl),a
	inc l
	ld (hl),a
	inc l
	ld (hl),a
	assert high (AYQ_NOW + AYF_N1) == high (AYQ_NOW + AYF_V3)
	ld de,AYQ_NOW			; this frame's: 3 x period (2), volume
	ld c,0
	call .one
	ld c,2
	call .one
	ld c,3
	call .one
	ld c,1				; (channel 2: only its noise)
	call .noise
	call ay_out
	ld hl,ay_q + AYF		; a frame on
	ld de,ay_q
	ld bc,2 * AYF
	ldir
	ret
.audc	ld a,c				; A, B: channel C's AUDC
	ld (ay_ch),a
	ld hl,pokey_audc
	add a,l
	ld l,a
	ld a,(hl)
	ld b,a
	ret
.one	call .audc
	and $F0
	cp $A0
	jr z,.tone
	cp $E0
	jr z,.tone
	cp $80
	call z,.noise_b
.quiet	xor a
	ld (de),a
	inc de
	ld (de),a
	inc de
	ld (de),a
	inc de
	ret
.tone	ld a,b
	and $0F
	jr z,.quiet
	call .vol_mask
	push de				; the period (C was spent: the channel from ay_ch)
	ld a,(ay_ch)
	ld hl,pokey_audf
	add a,l
	ld l,a
	ld a,(hl)
	inc a
	jr z,.max
	ld c,a				; N = 3 a + a x frac / 256
	ld d,a
	ld a,(tv_pal)
	or a
	ld e,108
	jr z,.f
	ld e,116
.f	mul d,e
	ld a,e				; (rounded)
	rla
	ld a,d
	adc a,0
	ld e,a
	ld d,0
	ld h,d
	ld l,c
	add hl,hl
	add hl,de
	ld e,c
	add hl,de
	jr .n
.max	ld a,(tv_pal)			; 256 ticks
	or a
	ld hl,876
	jr z,.n
	ld hl,884
.n	pop de
	ex de,hl
	ld (hl),e
	inc hl
	ld (hl),d
	inc hl
	ld (hl),b
	inc hl
	ex de,hl
	ret
; B (AUDC) the volume: B the AY's, the channel (ay_ch) off the DAC
.vol_mask
	ld a,b
	and $0F
	ld hl,ay_vol
	add a,l
	ld l,a
	adc a,h
	sub l
	ld h,a
	ld b,(hl)
	ld a,(ay_ch)			; its bit
	ld c,a
	inc c
	ld a,1
.bit	dec c
	jr z,.set
	rlca
	jr .bit
.set	ld hl,ay_mask
	or (hl)
	ld (hl),a
	ret
; channel C's noise, if it plays one and ay_noise is on (DE kept)
.noise	call .audc
	and $F0
	cp $80
	ret nz
.noise_b
	ld a,(ay_noise)
	or a
	ret z
	ld a,b
	and $0F
	ret z
	call .vol_mask			; B: the volume
	ld a,(ay_ch)			; N = a + a x frac / 256, 31 at most
	ld hl,pokey_audf
	add a,l
	ld l,a
	ld a,(hl)
	inc a
	ld c,31
	jr z,.nset
	cp 18 + 1
	jr nc,.nset
	ld c,a
	push de
	ld d,a
	ld a,(tv_pal)
	or a
	ld e,182
	jr z,.nf
	ld e,186
.nf	mul d,e
	ld a,e
	rla
	ld a,d
	adc a,c
	pop de
	cp 31
	jr c,.nn
	ld a,31
.nn	ld c,a
.nset	ld hl,AYQ_NOW + AYF_N2		; channel 1: the second AY,
	ld a,(ay_ch)
	or a
	jr z,.nput
	ld l,low (AYQ_NOW + AYF_N3)	; 2: the third
	dec a
	jr z,.nput
	ld l,low (AYQ_NOW + AYF_N1)	; 4: the first, its channel C
	ld (hl),c
	inc l
	ld (hl),$1C			; (A and B's tones, C's noise)
	pop hl				; (from .one: C's slot, as a tone's)
	xor a
	ld (de),a
	inc de
	ld (de),a
	inc de
	ld a,b
	ld (de),a
	inc de
	ret
.nput	ld (hl),c
	inc l
	ld (hl),b
	ret

; the AY's registers from ay_q (2 frames ago): the first's periods 0-5, volumes 8-10, noise
; 6, mixer 7; the second's and the third's noise 6, A's volume 8 (the first left selected)
ay_out:	ld hl,ay_q
	ld bc,$FFFD
	ld a,$FF
	out (c),a
	ld d,0
	ld e,8
.ch	ld b,$FF
	out (c),d
	ld b,$BF
	ld a,(hl)
	out (c),a
	inc hl
	inc d
	ld b,$FF
	out (c),d
	ld b,$BF
	ld a,(hl)
	out (c),a
	inc hl
	inc d
	ld b,$FF
	out (c),e
	ld b,$BF
	ld a,(hl)
	out (c),a
	inc hl
	inc e
	ld a,e
	cp 11
	jr c,.ch
	ld de,6 << 8 | 7		; (HL: ay_q + AYF_N1)
	call .reg2
	ld a,$FE
	call .chip
	ld a,$FD
	call .chip
	ld b,$FF
	ld a,b
	out (c),a
	ret
.chip	ld b,$FF
	out (c),a
	ld de,6 << 8 | 8
.reg2	ld b,$FF			; registers D and E from HL on
	out (c),d
	ld b,$BF
	ld a,(hl)
	out (c),a
	inc hl
	ld b,$FF
	out (c),e
	ld b,$BF
	ld a,(hl)
	out (c),a
	inc hl
	ret

; quiet now (the sound off)
ay_quiet:
	ld hl,ay_q
	ld de,ay_q + 1
	ld bc,3 * AYF - 1
	ld (hl),0
	ldir
	ld a,$38			; (the first AY's mixer as ever)
	ld (ay_q + AYF_N1 + 1),a
	jp ay_out
