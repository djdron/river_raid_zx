; The pure tones on the AY, every frame (sound_ay.asm says how). In page 6, not page 7 with
; the rest: calling them there would map page 7 at $6000-$7FFF, where the DAC's ring is
; (page 12), and the DMA, which reads through the same mapping, would send page 7's bytes
; meanwhile: a sample or two a frame at 0, heard as crackle.

ay_vol:	db 0, 8, 10, 12, 13, 13, 14, 14, 15, 15, 15, 15, 15, 15, 15, 15

; This frame's registers (ay_mask: the POKEY channels they take), then the AY those of 2
; frames ago: the pure tones (AUDC bits 7-5 101, 111, not only the volume), N = (AUDF + 1) x
; 3.454 (PAL) / 3.42 (NTSC); the rest is the DAC's (pokey_frame). Each POKEY channel has an
; AY channel of its own: 1 the second AY's A, 2 the third's A, 3 the first's B, 4 the
; first's C.
ay_slot:	db AYR / 3, 0, 2 * AYR / 3, 0, 0, 1, 0, 2	; per POKEY channel: the chip's
					; registers, the channel (0-2)
ay_frame:
	ld a,(ay_qi)			; this frame's: all quiet
	call ay_rec
	ld (ay_now),hl
	ld d,h
	ld e,l
	inc de
	ld (hl),0
	ld bc,AYR - 1
	ldir
	ld hl,(ay_now)
	ld de,7
	add hl,de
	ld (hl),$3F
	ld e,11
	add hl,de
	ld (hl),$3F
	add hl,de
	ld (hl),$3F
	xor a
	ld (ay_mask),a
	ld c,a
.ch	push bc
	call .one
	pop bc
	inc c
	ld a,c
	cp 4
	jr c,.ch
	ld a,(ay_qi)			; out: 2 frames ago, written over next frame
	inc a
	cp 3
	jr c,.qi
	xor a
.qi	ld (ay_qi),a
	call ay_rec
	jp ay_out
.one	ld a,c
	ld (ay_ch),a
	ld hl,pokey_audc
	add a,l
	ld l,a
	ld b,(hl)			; B: AUDC
	ld a,b				; (only the pure tones)
	and $F0
	cp $A0
	jr z,.mine
	cp $E0
	ret nz
.mine	ld a,1				; off the DAC
	inc c
.bit	dec c
	jr z,.set
	rlca
	jr .bit
.set	ld hl,ay_mask
	or (hl)
	ld (hl),a
	ld a,b
	and $0F
	ret z				; quiet
	ld hl,ay_vol
	add a,l
	ld l,a
	adc a,h
	sub l
	ld h,a
	ld a,(hl)
	ld (.vol + 1),a
	ld a,(ay_ch)			; IX: the chip's registers, C: the channel
	add a,a
	ld hl,ay_slot
	add a,l
	ld l,a
	adc a,h
	sub l
	ld h,a
	ld e,(hl)
	inc hl
	ld c,(hl)
	ld d,0
	ld ix,(ay_now)
	add ix,de
	ld a,c				; its volume
	add a,8
	ld e,a
	push ix
	pop hl
	add hl,de
.vol	ld (hl),0
	call .period			; HL: N
.tone	ld a,c				; registers 2C, 2C + 1, the mixer's tone bit
	add a,a
	ld e,a
	ld d,0
	ex de,hl
	push ix
	pop bc
	add hl,bc
	ld (hl),e
	inc hl
	ld (hl),d
	ld a,(ay_ch)
	add a,a
	ld hl,ay_slot + 1
	add a,l
	ld l,a
	adc a,h
	sub l
	ld h,a
	ld b,(hl)			; the channel again
	ld a,$FE
	inc b
.tb	dec b
	jr z,.mix
	rlca
	jr .tb
.mix	and (ix+7)
	ld (ix+7),a
	ret
; HL: a tone's N for this channel's AUDF (A kept: the kind)
.period	push af
	push bc
	call .audf
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
	pop bc
	pop af
	ret
.max	ld a,(tv_pal)			; 256 ticks
	or a
	ld hl,876
	jr z,.m
	ld hl,884
.m	pop bc
	pop af
	ret
.audf	ld a,(ay_ch)
	ld hl,pokey_audf
	add a,l
	ld l,a
	ld a,(hl)
	ret

; HL = ay_q's frame A
ay_rec:	ld e,a
	ld d,AYR
	mul d,e
	ld hl,ay_q
	add hl,de
	ret

; the three AY's registers 0-10 from HL (the first left selected)
ay_out:	ld bc,$FFFD
	ld a,$FF
	call .chip
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
	ld d,0
.r	ld b,$FF
	out (c),d
	ld b,$BF
	ld a,(hl)
	out (c),a
	inc hl
	inc d
	ld a,d
	cp 11
	jr c,.r
	ret

; quiet now (the sound off)
ay_quiet:
	ld hl,ay_q
	ld b,3 * 3
.q	push bc
	ld b,7
.z	ld (hl),0
	inc hl
	djnz .z
	ld (hl),$3F			; (the mixer: neither tone nor noise)
	inc hl
	ld (hl),0
	inc hl
	ld (hl),0
	inc hl
	ld (hl),0
	inc hl
	pop bc
	djnz .q
	ld hl,ay_q
	jp ay_out
