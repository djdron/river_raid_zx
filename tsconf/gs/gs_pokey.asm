; The sound on the General Sound: POKEY played by the card's own Z80 (12 MHz), all four
; channels as the Next's DAC plays its noises (src/sound.asm, sound_pulses.asm,
; sound_handlers.asm: pokey_frame, here without the AY, the zxnDMA or the time limit). The
; TS-Conf side (sound_gs.asm) puts this program into the card through its firmware (at
; GS_ORG, started there) and sends POKEY's registers once a frame: a command (any but
; GS_RESET), then AUDF1-4 and AUDC1-4 as data. The program makes that frame's samples into
; a ring of 1024 bytes; the card's INT (37 500 a second) takes the next one at the POKEY's
; rate (DDA_STEP / 256 of them: 15 820 a second, POKEY's PAL 15 834) and latches it into all
; four DACs at full volume: mono, 1 and 2 left, 3 and 4 right (each side the sum of its two:
; the levels are 4 a volume's step, 0-240 for all four channels at 15, and the two DACs a
; side make it as loud as the Next's 8 a step on one).
;
; The card's memory: $4000-$40FF the INT's vectors (IM 2, the bus's byte whatever it is),
; INT_AT its handler, $4200 on the variables and tables, the stack below $6000; $6000-$63FF
; a byte's own value (a read at $6000 + 256 (n - 1) + v latches v into channel n); page 2
; (the firmware's page register, #12) at $8000: the ring at $8000, the program at GS_ORG, the
; 17-bit counter's bits at POLY17 (made at the start from its recurrence).
;
; GS_STATE ($F0, the firmware's "get status") answers GS_READY: the TS-Conf side, run again,
; finds the program still there and goes on with it. GS_RESET ($F4, the firmware's own reset
; command) starts the firmware again.

	device NOSLOT64K

GS_ORG		equ $8400
SND_RING	equ $8000		; 1024 bytes (1K-aligned)
POLY17		equ $C000		; tools/mkpoly's poly17.bin, 16K
SND_LEAD	equ 760			; samples ahead of the INT: 2.4 frames (as the Next)
SND_CAP		equ 700			; samples a frame at most
	assert 4 * SND_CAP < 4096	; (pk_channel's division: 12 bits)
SND_HOLD	equ 400			; past them, the last level held, when they are less than
SND_HOLD_PAST	equ 600			; this far ahead
DDA_STEP	equ 108
INT_TAB		equ $4000
INT_AT		equ $4141
GS_READY	equ $5A			; what the program says when it runs
GS_RESET	equ $F4
GS_STATE	equ $F0			; the firmware's "get status": this program says GS_READY

P_PAGE		equ $00			; the card's ports
P_CMD		equ $01
P_DATRD		equ $02
P_DATWR		equ $03
P_STAT		equ $04			; bit 7 data (from the ZX: there, to it: not yet read), bit 0
P_CLRC		equ $05			; a command
P_VOL1		equ $06

CH_D		equ 0			; a channel's state: samples to its next pulse,
CH_F		equ 1			; the ticks past them (x 64),
CH_OUT		equ 2			; its output (0, 1),
CH_P31		equ 3			; where the 5-bit counter is, the 4-bit one,
CH_P15		equ 4
CH_Q		equ 5			; and the 17-bit one: its byte (2) and bit (a mask)
CH_QM		equ 7
CH_SIZE		equ 8

; ------------------------------------------------------------------------------------------
	org $4200			; the variables (cleared at the start)
vars:
dda:		ds 1			; the INT's: its fraction of a sample,
rp:		ds 2			; the next sample in the ring
pokey_audf:	ds 4			; this frame's registers from the ZX: AUDF1-4,
pokey_audc:	ds 4			; AUDC1-4
snd_ch:		ds 4 * CH_SIZE		; the channels' state
snd_w:		ds 2			; the ring: where this frame's samples go,
snd_n:		ds 2			; how many
snd_s31:	ds 1			; a pulse's steps of the 5-bit and 4-bit counters
snd_s15:	ds 1
snd_ticks:	ds 2			; the frame's ticks (4 a sample)
snd_level:	ds 1			; the level at its start
pk_d:		ds 1
pk_k:		ds 1
pk_kh:		ds 1
pk_dma:		ds 2			; where the INT was
snd_frames:	ds 2			; the frames played,
snd_passed:	ds 2			; those the INT had passed the samples of
	ifdef G4CHECK
g4c_kh:		ds 1
g4c_b:		ds 1
g4c_p31:	ds 1
g4c_p15:	ds 1
g4c_bad:	ds 2
g4c_n:		ds 2
	endif
vars_end:
	assert vars_end <= $4300
	org $4300
snd_tables:	ds 256			; POKEY's 5-bit counter at the ticks, its 4-bit one at +$40,
					; a bit's mask at +$80, the volume x 0-3 at +$90 (pk_channel)
snd_mod15:	ds 256			; (AUDF + 1) mod 15, mod 31
snd_mod31:	ds 256
G4_TAB		equ $4800 - 465		; pk_g4: per state of the 5-bit and 4-bit counters (m: m mod
	org G4_TAB			; 31, m mod 15), $FF a pulse not let through, else the 4-bit
g4_tab:		ds 2 * 465		; counter's bit; twice (from $4800 on: 465 back)
	assert $ <= $5000		; (the stack above, up to $6000)

; ------------------------------------------------------------------------------------------
	org GS_ORG
gs_start:
	di
	ld sp,$6000
	ld hl,INT_TAB			; IM 2: every vector INT_AT
	ld de,INT_TAB + 1
	ld bc,256
	ld (hl),high INT_AT
	ldir
	ld hl,int_code
	ld de,INT_AT
	ld bc,INT_LEN
	ldir
	ld a,high INT_TAB
	ld i,a
	im 2
	ld hl,vars
	ld de,vars + 1
	ld bc,vars_end - vars - 1
	ld (hl),0
	ldir
	ld hl,$6000			; the DACs' tables: a byte's own value, 4 pages
.id	ld (hl),l
	inc l
	jr nz,.id
	inc h
	bit 2,h
	jr z,.id
	ld a,($6000)			; all four DACs 0, at full volume
	ld a,($6100)
	ld a,($6200)
	ld a,($6300)
	ld a,63
	out (P_VOL1),a
	out (P_VOL1 + 1),a
	out (P_VOL1 + 2),a
	out (P_VOL1 + 3),a
	call poly_make
	call tables_make
	ld hl,SND_RING			; the ring quiet
	ld de,SND_RING + 1
	ld bc,1023
	ld (hl),0
	ldir
	ld hl,SND_RING
	ld (rp),hl
	ld hl,SND_RING + SND_LEAD
	ld (snd_w),hl
	ld ix,snd_ch			; the 17-bit counters at its start
	ld b,4
	ld de,CH_SIZE
.ch	ld (ix+CH_Q + 1),high POLY17
	add ix,de
	djnz .ch
	ld a,GS_READY			; running
	out (P_DATWR),a
	ei

; The ZX's commands: GS_RESET the firmware again, GS_STATE GS_READY back; any other a frame's
; registers (8 bytes of data after it; another command first: that one)
main:	in a,(P_STAT)
	rrca
	jr nc,main
.cmd	in a,(P_CMD)
	out (P_CLRC),a
	cp GS_RESET
	jr z,.reset
	cp GS_STATE
	jr z,.state
	ld hl,pokey_audf
	ld b,8
.d	in a,(P_STAT)
	or a
	jp m,.data
	rrca
	jr nc,.d
	jr .cmd
.data	in a,(P_DATRD)
	ld (hl),a
	inc hl
	djnz .d
	call pokey_frame
	jr main
.state	ld a,GS_READY			; the state: running (the firmware says its error code)
	out (P_DATWR),a
	jr main
.reset	di
	im 1
	jp 0

; The INT: a sample (DDA_STEP / 256 of the INTs) into the DACs of channels 1 and 3
int_code:
	phase INT_AT
gs_int:	push af
	ld a,(dda)
	add a,DDA_STEP
	ld (dda),a
	jr c,.s
	pop af
	ei
	ret
.s	push hl
	ld hl,(rp)
	ld a,(hl)
	inc l
	jr nz,.n
	inc h
	res 2,h				; (the ring's end: its start)
.n	ld (rp),hl
	ld l,a
	ld h,$60			; channels 1 and 2 (left), 3 and 4 (right)
	ld a,(hl)
	inc h
	ld a,(hl)
	inc h
	ld a,(hl)
	inc h
	ld a,(hl)
	pop hl
	pop af
	ei
	ret
	dephase
INT_LEN		equ $ - int_code
	assert INT_AT + INT_LEN <= vars

; POKEY's 17-bit counter at the ticks (tools/mkpoly's poly17.bin), at POLY17: bit k is bit k
; mod 8 of byte k / 8; its recurrence q(k) = q(k - 9) ^ q(k - 11) ^ q(k - 12) ^ q(k - 17)
; makes 8 at a time from the 3 bytes before (B, C, D)
poly_make:
	ld bc,$CF << 8 | $37		; its first 24
	ld d,$33
	ld ix,POLY17
	ld (ix+0),b
	ld (ix+1),c
	ld (ix+2),d
	ld ix,POLY17 + 3
.byte	ld h,d				; q(k - 9), q(k - 11), q(k - 12): from C, D
	ld l,c
	add hl,hl
	ld a,h
	add hl,hl
	add hl,hl
	xor h
	add hl,hl
	xor h
	ld e,a
	ld a,b				; q(k - 17): from B, C
	rla
	ld a,c
	rla
	xor e
	ld (ix+0),a
	ld b,c
	ld c,d
	ld d,a
	inc ix
	ld a,ixh
	or a
	jr nz,.byte
	ret

; The tables (as the Next's sound_init7): POKEY's 4-bit and 5-bit counters, the masks, the
; steps of a pulse, pk_g4's
tables_make:
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
	ret

snd_tables_init:
	include "poly.inc"
	db 1,2,4,8,16,32,64,128

; ------------------------------------------------------------------------------------------
; This frame's samples: from snd_w up to SND_LEAD past where the INT is, SND_CAP at most (the
; Next's pokey_frame). The ring gets each channel's changes first (+ or - its volume at the
; sample where its output turns on or off), then a running sum from the frame's first level
; makes them the levels.
pokey_frame:
	ld hl,(snd_frames)
	inc hl
	ld (snd_frames),hl
	ld de,(rp)			; where the INT is
	ld (pk_dma),de
	ld hl,(snd_w)			; how far ahead the samples are
	or a
	sbc hl,de
	ld a,h
	and 3
	ld h,a
	push hl				; more than the lead ever is: the INT has passed them
	ld bc,SND_LEAD + 1
	sbc hl,bc
	pop hl
	jr c,.ahead
	ld hl,(snd_passed)
	inc hl
	ld (snd_passed),hl
	ld (snd_w),de			; from where the INT is
	ld hl,0
.ahead	ex de,hl			; DE: ahead
	ld hl,SND_LEAD			; the samples it wants
	or a
	sbc hl,de
	ret z
	ld de,SND_CAP + 1
	push hl
	sbc hl,de
	pop hl
	jr c,.n
	ld hl,SND_CAP
.n	ld (snd_n),hl
	add hl,hl			; and its ticks
	add hl,hl
	ld (snd_ticks),hl
	xor a				; no changes yet (and one more sample: where the part of a
	ld (snd_level),a		; turn past the end goes; the next frame starts from the
	ld hl,(snd_w)			; channels' outputs, the turn whole)
	ld de,(snd_n)
	inc de
	call snd_fill
	ld ix,snd_ch			; the channels
	ld iy,pokey_audf
	ld b,4
.ch	push bc
	ld a,(iy+4)			; AUDC
	and $0F
	jr z,.next			; volume 0: nothing to hear
	add a,a				; (x 2: half the level, pk_channel x 4)
	ld c,a
	bit 4,(iy+4)
	jr nz,.full			; volume only: the volume all the time
	ld a,(iy+0)
	cp 5
	jr nc,.pulses
	ld a,c				; 5 ticks or less: too high to sample, half the volume
	jr .level
.full	ld a,c
	add a,a
.level	ld hl,snd_level
	add a,(hl)
	ld (hl),a
	jr .next
.pulses	push iy
	call pk_channel
	pop iy
.next	ld de,CH_SIZE
	add ix,de
	inc iy
	pop bc
	djnz .ch
	ld a,(snd_level)		; the levels
	ld c,a
	ld hl,(snd_w)
	ld de,(snd_n)
	call snd_sum
	ld a,c				; the last level
	ld hl,(snd_w)
	ld de,(snd_n)
	add hl,de
	ld b,a
	ld a,h
	and 3
	or high SND_RING
	ld h,a
	ld (snd_w),hl
	push bc				; past them, up to SND_HOLD, the last level held: if the
	ld de,(pk_dma)			; INT gets there before the next frame's samples it plays
	or a				; that, not what the ring had a round ago
	sbc hl,de
	ld a,h
	and 3
	ld h,a
	ex de,hl
	ld hl,SND_HOLD_PAST		; far enough ahead: none (the next frame's come first)
	sbc hl,de
	pop bc
	ret c
	ld hl,1024 - 8
	or a
	sbc hl,de
	ret c
	ld de,SND_HOLD
	push hl
	sbc hl,de
	pop hl
	jr c,.hold
	ex de,hl
.hold	ld a,h
	or l
	ret z
	ex de,hl
	ld hl,(snd_w)
	ld a,b
	jp snd_fill

; DE bytes (1-1023) of A from HL on in the ring
snd_fill:
	ld c,a
.l	ld (hl),c
	inc l
	jr nz,.n
	inc h
	res 2,h
.n	dec de
	ld a,d
	or e
	jr nz,.l
	ret

; The running sum over DE samples (1-1023) from HL, from C: each page's stretch 8 a round,
; the first round the rest
snd_sum:
	ld a,l				; B: to the page's end, or the rest (0: 256)
	neg
	ld b,a
	ld a,d
	or a
	jr nz,.b
	ld a,b
	or a
	jr z,.rest
	ld a,e
	cp b
	jr nc,.b
.rest	ld b,e
.b	ld a,b				; DE -= B
	or a
	jr nz,.sub
	dec d
	jr .seg
.sub	ld a,e
	sub b
	ld e,a
	jr nc,.seg
	dec d
.seg	ld a,b				; into the 8 (3 bytes each)
	and 7
	neg
	and 7
	push bc
	ld b,a
	add a,a
	add a,b
	pop bc
	add a,low .add
	ld (.jp + 1),a
	ld a,high .add
	adc a,0
	ld (.jp + 2),a
	ld a,b				; (B + 7) / 8 rounds
	add a,7
	rra
	rrca
	rrca
	and $3F
	jr nz,.rounds
	ld a,32
.rounds	ld b,a
	ld a,c
.jp	jp .add
.add	rept 8
	add a,(hl)
	ld (hl),a
	inc l
	endr
	djnz .add
	ld c,a
	ld a,l				; past the page: the next one in the ring
	or a
	jr nz,.left
	inc h
	ld a,h
	and 3
	or high SND_RING
	ld h,a
.left	ld a,d
	or e
	jr nz,snd_sum
	ret

	include "gs_pulses.asm"
	include "gs_handlers.asm"

gs_end:
	display "GS program: ",GS_ORG,"-",gs_end
	assert gs_end <= POLY17
	savebin "build/gs_pokey.bin",GS_ORG,gs_end - GS_ORG
