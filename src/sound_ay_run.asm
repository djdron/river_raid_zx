; The pure tones on the AY, every frame (sound_ay.asm says how). In page 6, not page 7 with
; the rest: calling them there would map page 7 at $6000-$7FFF, where the DAC's ring is
; (page 12), and the DMA, which reads through the same mapping, would send page 7's bytes
; meanwhile: a sample or two a frame at 0, heard as crackle.

ay_vol:	db 0, 8, 10, 12, 13, 13, 14, 14, 15, 15, 15, 15, 15, 15, 15, 15

; this frame's tones (ay_mask: the POKEY channels they take), then the AY what they were 2
; frames ago
ay_frame:
	xor a
	ld (ay_mask),a
	ld de,ay_q + 18			; this frame's: 3 x period (2), volume
	ld c,0
	call .one
	ld c,2
	call .one
	ld c,3
	call .one
	call ay_out
	ld hl,ay_q + 9			; a frame on
	ld de,ay_q
	ld bc,18
	ldir
	ret
.one	ld a,c
	ld (ay_ch),a
	ld hl,pokey_audc
	ld a,l
	add a,c
	ld l,a
	ld a,(hl)
	ld b,a
	and $F0
	cp $A0
	jr z,.tone
	cp $E0
	jr z,.tone
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
	ld hl,ay_vol
	add a,l
	ld l,a
	adc a,h
	sub l
	ld h,a
	ld b,(hl)			; B: the AY's volume
	ld a,1				; the channel off the DAC
	inc c
.bit	dec c
	jr z,.set
	rlca
	jr .bit
.set	ld hl,ay_mask
	or (hl)
	ld (hl),a
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

; the AY's registers from ay_q (2 frames ago): periods 0-5, volumes 8-10
ay_out:	ld hl,ay_q
	ld d,0
	ld e,8
.ch	ld bc,$FFFD
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
	ret

; quiet now (the sound off)
ay_quiet:
	ld hl,ay_q
	ld de,ay_q + 1
	ld bc,3 * 9 - 1
	ld (hl),0
	ldir
	jp ay_out
