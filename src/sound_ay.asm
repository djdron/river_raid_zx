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

; The noise (AUDC bits 7-5 100, the 17-bit counter), while ay_noise is on: channel 1's on the
; second AY, 2's on the third (their channel A), 4's on the first AY's C (its tone and its
; noise never sound together), each with its chip's noise generator: a new random bit every
; 2N AY periods as POKEY's every pulse, N = (AUDF + 1) x 1.727 (PAL) or 1.711 (NTSC), but 31
; at most (AUDF 17: the lower noise is played higher).

; the AY's ports: TurboSound on (NR $08 bit 1), the chips mono (NR $09 bits 7-5), the first's
; tones on, the others' noise on A, quiet
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
	or $E0				; (all three)
	out (c),a
	xor a
	ld (ay_mask),a
	ld a,$FE			; the second and third AY: only channel A's noise
	call .mix
	ld a,$FD
	call .mix
	jp ay_quiet
.mix	ld bc,$FFFD
	out (c),a
	ld a,7
	out (c),a
	ld b,$BF
	ld a,$37
	out (c),a
	ret

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
	ld hl,g4_tab			; pk_g4's table: B the 5-bit counter, C the 4-bit
	ld bc,0
.g4	ld a,b
	ld (.p5 + 1),a
.p5	ld a,(snd_tables)
	or a
	ld a,$FF
	jr z,.g4s
	ld a,c
	add a,$40
	ld (.p4 + 1),a
.p4	ld a,(snd_tables + $40)
	or a
	jr z,.g4s
	ld a,1
.g4s	ld (hl),a
	push hl
	ld de,465
	add hl,de
	ld (hl),a
	pop hl
	inc hl
	inc b
	ld a,b
	cp 31
	jr c,.g45
	ld b,0
.g45	inc c
	ld a,c
	cp 15
	jr c,.g44
	ld c,0
.g44	ld de,-(g4_tab + 465)
	push hl
	add hl,de
	pop hl
	jr nc,.g4
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
