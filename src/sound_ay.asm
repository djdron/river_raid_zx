; The sound's pure tones on the AY (page 7, after panel_init: pokey_frame maps it at $6000
; while it calls these; the variables in page 1). POKEY's channels 1, 3
; and 4 when they play a pure tone (AUDC bits 7-5 101 or 111, not volume only) go to the
; first AY's channels A, B and C instead of the DAC: the same square wave, no samples to
; make. (Channel 2 never plays one.) A tone of AUDF + 1 ticks a half period (POKEY's
; 64 kHz clock: the Atari's / 28) is an AY period of 1.75 MHz / 16 = 109 375 Hz:
; N = (AUDF + 1) x 3.454 (PAL) or 3.422 (NTSC). The volume: POKEY's is linear, the AY's
; logarithmic (the Next's YM table): ay_vol takes the AY's nearest to it, at the DAC's
; scale (a channel's volume v is 16 v in the mix, an AY volume V is the table's 2V + 1).
; The AY plays what the registers were 2 frames ago: the DAC's samples are about that far
; ahead.

ay_vol:	db 0, 6, 8, 10, 11, 11, 12, 12, 13, 13, 13, 14, 14, 14, 15, 15

; the AY's ports: TurboSound on (NR $08 bit 1), the first chip mono (NR $09 bit 5), only
; its tones on, quiet
ay_init:
	ld bc,$243B
	ld a,$08
	out (c),a
	inc b
	in a,(c)
	or $02
	out (c),a
	dec b
	ld a,$09
	out (c),a
	inc b
	in a,(c)
	or $20
	out (c),a
	ld hl,ay_q
	ld de,ay_q + 1
	ld bc,3 * 9 - 1
	ld (hl),0
	ldir
	xor a
	ld (ay_mask),a
	ld a,$FF			; the first AY, both sides
	ld bc,$FFFD
	out (c),a
	ld a,7				; tones on, noise off
	out (c),a
	ld b,$BF
	ld a,$38
	out (c),a
	jp ay_out

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


; sound_init's part in this page (nothing at $6000-$7FFF touched): the AY, POKEY's tables
; into page 1, the steps' tables, the DMA set going
sound_init7:
	call ay_init
	ld hl,snd_tables_init
	ld de,snd_tables
	ld bc,$88
	ldir
	ld hl,snd_mod15			; (AUDF + 1) mod 15 and mod 31 by AUDF
	ld bc,15 << 8 | 31
	ld de,1 << 8 | 1
.mod	ld (hl),d
	inc h
	ld (hl),e
	dec h
	inc d
	ld a,d
	cp b
	jr c,.m15
	ld d,0
.m15	inc e
	ld a,e
	cp c
	jr c,.m31
	ld e,0
.m31	inc l
	jr nz,.mod
	ld hl,dma_program
	ld bc,(dma_program_end - dma_program) << 8 | $6B
	otir
	ret

snd_tables_init:
	include "poly.inc"
	db 1,2,4,8,16,32,64,128

dma_program:
	db $83, $C3			; disable, reset
	db $7D				; WR0: A -> B; A's address and the length follow
	dw SND_RING, 1024
	db $54, $02			; WR1: A memory, incrementing, 2 cycles
	db $68, $22, SND_PRESCALER	; WR2: B i/o, fixed, 2 cycles, the prescaler
	db $CD				; WR4: burst; B's address follows
	dw DAC_PORT
	db $A2				; WR5: again from the start at the end
	db $CF				; load
	db $BB, $18			; read mask: A's address
	db $87				; enable
dma_program_end:
