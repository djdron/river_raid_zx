; The sound's pure tones on the AY (TurboSound: two chips), as the Next's sound_ay_run.asm
; plays them: POKEY's channels when they play a pure tone (AUDC bits 7-5 101 or 111, not
; volume only) go to an AY channel each: 1 the second chip's A, 2 its B, 3 the first chip's
; B, 4 its C. The same square wave: a tone of AUDF + 1 ticks a half period (POKEY's 64 kHz
; clock: the Atari's / 28) is an AY period of 1.75 MHz / 16 = 109 375 Hz: N = (AUDF + 1) x
; 3.454 (PAL). The volume: POKEY's is linear, the AY's logarithmic: ay_vol takes the AY's
; nearest to it. The rest (the noises, the explosions, the helicopter's missile: the Next's
; DAC) only on a General Sound, which then plays it all (sound_gs.asm).
; ay_frame works the registers out (after the VBI's sound driver), apply puts them out
; (ay_out): at the frame's start, as the Next's AY plays them (with no DAC to wait for, not 2
; frames late).

AYR		equ 22			; a frame's AY registers: the two chips' 0-10

ay_vol:	db 0, 8, 10, 12, 13, 13, 14, 14, 15, 15, 15, 15, 15, 15, 15, 15
ay_slot:	db AYR / 2, 0, AYR / 2, 1, 0, 1, 0, 2	; per POKEY channel: the chip's
					; registers, the channel (0-2)

ay_frame:
	call ay_clear			; all quiet
	ld c,0
.ch	push bc
	call .one
	pop bc
	inc c
	ld a,c
	cp 4
	jr c,.ch
	ret
.one	ld a,c
	ld (ay_ch),a
	ld hl,pokey_audc
	add a,l
	ld l,a
	adc a,h
	sub l
	ld h,a
	ld b,(hl)			; B: AUDC
	ld a,b				; (only the pure tones)
	and $F0
	cp $A0
	jr z,.mine
	cp $E0
	ret nz
.mine	ld a,b
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
	ld ix,ay_regs
	add ix,de
	ld a,c				; its volume
	add a,8
	ld e,a
	push ix
	pop hl
	add hl,de
.vol	ld (hl),0
	call .period			; HL: N
	ld a,c				; registers 2C, 2C + 1, the mixer's tone bit
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
; HL: a tone's N for this channel's AUDF: 3 a + round(a x 116 / 256), a = AUDF + 1
; (884 for 256); BC kept
.period	push bc
	ld a,(ay_ch)
	ld hl,pokey_audf
	add a,l
	ld l,a
	adc a,h
	sub l
	ld h,a
	ld a,(hl)
	inc a
	jr z,.max
	ld c,a				; a x 116 = a x 128 - a x 12 (16 bits)
	ld l,a
	ld h,0
	add hl,hl
	add hl,hl			; x 4
	ld d,h
	ld e,l
	add hl,hl			; x 8
	add hl,de
	ex de,hl			; DE: x 12
	ld h,c				; HL: x 128
	ld l,0
	srl h
	rr l
	or a
	sbc hl,de
	ld a,l				; / 256, rounded
	rla
	ld a,h
	adc a,0
	ld e,a
	ld d,0
	ld a,(ay_ch)			; (C was AUDF + 1: again)
	ld hl,pokey_audf
	add a,l
	ld l,a
	adc a,h
	sub l
	ld h,a
	ld a,(hl)
	inc a
	ld l,a
	ld h,0
	ld c,l
	ld b,h
	add hl,hl
	add hl,bc			; 3 a
	add hl,de
	pop bc
	ret
.max	ld hl,884			; 256 ticks
	pop bc
	ret

; ay_regs to the two chips (registers 0-10 each; the first left selected)
ay_out:	ld bc,$FFFD
	ld a,$FE			; the second chip first
	ld hl,ay_regs + AYR / 2
	call .chip
	ld a,$FF
	ld hl,ay_regs
	call .chip
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

; quiet now
ay_quiet:
	call ay_clear
	jr ay_out
ay_clear:				; (the mixers: neither tone nor noise)
	ld hl,ay_regs
	ld de,ay_regs + 1
	ld (hl),0
	ld bc,AYR - 1
	ldir
	ld a,$3F
	ld (ay_regs + 7),a
	ld (ay_regs + AYR / 2 + 7),a
	ret
