; The sound's pure tones on the AY: the setting up here (page 7, after panel_init), what
; runs every frame in sound_ay_run.asm (page 6; the variables in page 1). POKEY's channels 1, 3
; and 4 when they play a pure tone (AUDC bits 7-5 101 or 111, not volume only) go to the
; first AY's channels A, B and C instead of the DAC: the same square wave, no samples to
; make. (Channel 2 never plays one.) A tone of AUDF + 1 ticks a half period (POKEY's
; 64 kHz clock: the Atari's / 28) is an AY period of 1.75 MHz / 16 = 109 375 Hz:
; N = (AUDF + 1) x 3.454 (PAL) or 3.422 (NTSC). The volume: POKEY's is linear, the AY's
; logarithmic (the Next's YM table): ay_vol takes the AY's nearest to it, at the DAC's
; scale (a channel's volume v is 32 v in the mix, an AY volume V is the table's 2V + 1; from
; v = 8, the game's usual, the AY's top, 255).
; The AY plays what the registers were 2 frames ago: the DAC's samples are about that far
; ahead.

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

; sound_init's part in this page (nothing at $6000-$7FFF touched): the AY, POKEY's tables
; into page 1, the steps' tables, the DMA set up (sound_init starts it)
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
dma_program_end:			; (enabled by sound_init, the ring mapped again)
