; The sound. sound_driver is the original's sound driver (B2A5-B3D8, in the VBI): from the
; game's state it sets POKEY's four channels once a frame (pokey_audf, pokey_audc), as the
; C++ port's Game::soundDriver. pokey_frame then plays them: it makes the samples of POKEY's
; output for the frame into a ring of 1024 bytes, which the zxnDMA sends to the DAC on its
; own, a byte every 55 of its 875 kHz clock's ticks (15 909 a second).
;
; POKEY (AUDCTL 0, as River Raid leaves it): each channel counts a 64 kHz clock (a tick every
; 28 of the Atari's cycles) down from AUDF; when the count runs out (every AUDF + 1 ticks: a
; pulse) AUDC says what its output does: AUDC bit 7 = 0 lets a pulse through only when the
; 5-bit polynomial counter's bit is 1; bit 5 = 1 toggles the output (a tone), otherwise the
; output takes the 4-bit (bit 6 = 1) or the 17-bit counter's bit (noise); bit 4 = 1 is volume
; only (the output is on, whatever the count does); bits 3-0 the volume. The counters move on
; every cycle, so a pulse on tick k sees their bit 28k (tools/mkpoly: poly4, poly5 and the
; 17-bit one in pages 14-15, mapped at $0000 while the samples are made).
;
; A sample is 4 ticks (the DMA's rate is 0.5% above POKEY's 15 834 PAL or 15 980 NTSC). The
; frame makes as many as the DMA has sent since the last one, SND_LEAD ahead of where it is,
; so the two never drift apart. The level is the sum of the channels' volumes that are on,
; times 8 (the game's add up to 30 at most here: 0-240; past 31 the levels would wrap). Instead of counting each tick, each channel goes from pulse to pulse: the
; samples in between have its output as the pulse left it.

SND_RING	equ $7C00		; page 12, 1024 bytes (1K-aligned)
SND_PRESCALER	equ 55
SND_LEAD	equ 760			; samples ahead of the DMA: 2.4 frames (48 ms), as many
SND_MIN_LEAD	equ 200			; as the time left allows, but 0.6 frames at least
SND_CAP		equ 700			; samples a frame at most
SND_HOLD	equ 400			; past them, the last level held, when they are less than
SND_HOLD_PAST	equ 600			; this far ahead
DAC_PORT	equ $DF			; DAC A and D (SpecDrum)
POLY_PAGE	equ 14			; poly17.bin: pages 14 and 15

CH_D		equ 0			; a channel's state: samples to its next pulse,
CH_F		equ 1			; the ticks past them (x 64),
CH_OUT		equ 2			; its output (0, 1),
CH_P31		equ 3			; where the 5-bit counter is, the 4-bit one,
CH_P15		equ 4
CH_Q		equ 5			; and the 17-bit one: its byte (2) and bit (a mask)
CH_QM		equ 7
CH_SIZE		equ 8

; ------------------------------------------------------------------------------------------
; B2A5-B3D8: the sound driver. Channel 1: the start beep, an event sound (crash, out of fuel,
; tank full, refuelling), the low-fuel beep or the engine; 2: an explosion or the
; helicopter's missile; 3: firing or a bonus life; 4: the tank's shell.
sound_driver:
	ld hl,START_BEEP		; B2A6
	ld a,(hl)
	or a
	jr z,.pause
	dec (hl)
	ld a,$40
	ld (pokey_audf),a
	ld a,$AF
	ld (pokey_audc),a
	jr .quiet
.pause	ld a,(PAUSE_STATE)		; B2BA
	cp PAUSED
	jr c,.ch1
	xor a
	ld (pokey_audc),a
.quiet	xor a
	ld (pokey_audc + 1),a
	ld (pokey_audc + 2),a
	ld (pokey_audc + 3),a
	ret
.ch1	ld de,$3900			; D pitch, E control, C the last value (channel 2's
	ld c,e				; pitch at volume 0), B: the pitch is set
	ld b,1
	ld a,(EVENT_SOUND)		; B2D2: an event sound, EVENT_SOUND_TIME frames long
	or a
	jr z,.no_event
	ld l,a
	ld a,(EVENT_SOUND_TIME)
	ld h,a
	ld a,l
	cp OUT_OF_FUEL_SOUND + 1
	jr nc,.ev_tone
	cp OUT_OF_FUEL_SOUND
	jr nz,.ev_noise
	ld d,$11
.ev_noise
	ld a,h
	srl a
	or $80
	jr .ev_set
.ev_tone
	ld d,$3F
	cp TANK_FULL_SOUND
	jr nz,.ev_t
	ld d,$1F
.ev_t	ld a,h
	add a,$A0
.ev_set	ld e,a
	ld c,a
	ld hl,EVENT_SOUND_TIME
	dec (hl)
	jr nz,.ch1_set
	xor a
	ld (EVENT_SOUND),a
	ld c,a
	jr .ch1_set
.no_event
	ld a,(PLANE_STATE)		; B2F9: no plane flying: channel 1 off
	or a
	jr z,.flying
	ld c,a
	ld b,0
	jr .ch1_set
.flying	ld a,(FUEL)			; B2FD: low fuel: a beep every 63 frames
	cp $40
	jr nc,.engine
	ld hl,EVENT_SOUND_TIME
	ld a,(hl)
	or a
	jr nz,.t
	ld a,$3F
.t	dec a
	ld (hl),a
	ld l,a				; L the time, H the beep
	ld h,0
	ld a,(FUEL)
	cp 4
	jr nc,.first
	add a,a				; almost empty: a tone falling with the fuel
	add a,a
	ld h,a
	ld a,(FUEL_FRAC)
	rlca
	rlca
	and 3
	or h
	cpl
	add a,$20
	add a,a
	ld h,a
.first	ld a,h
	or a
	jr nz,.beep
	ld a,l				; the first frames of each 63
	cp $1C
	jr c,.engine
	ld h,a
.beep	ld a,h				; B326
	add a,a
	ld d,a
	ld c,a
	ld e,$AF
	jr .ch1_set
.engine	ld a,(SPEED)			; B32C: the engine, its pitch from the speed
	rrca
	rrca
	rrca
	rrca
	and $0F
	ld l,a
	ld a,$1F
	sub l
	ld d,a
	ld hl,CRASH_PITCH		; falling after a crash
	ld a,(hl)
	cp $1B
	jr c,.tone
	ld d,a
	dec (hl)
.tone	ld a,(JOYSTICK)			; the tone from up and down ($B4AC)
	and 3
	add a,low ROM_ENGINE_TONE
	ld l,a
	ld h,high ROM_ENGINE_TONE
	ld a,(hl)
	ld e,a
	ld c,a
.ch1_set
	ld a,b
	or a
	jr z,.ch1_c
	ld a,d
	ld (pokey_audf),a
.ch1_c	ld a,e
	ld (pokey_audc),a
	ld d,c				; channel 2: B352, an explosion's noise, fading
	ld hl,SOUND_EXPLOSION
	ld a,(hl)
	ld e,a
	or a
	jr z,.missile
	dec (hl)
	srl a
	add a,4
	and $0F
	add a,$80
	ld e,a
	call sound_random
	or $18
	ld d,a
.missile
	ld hl,SOUND_MISSILE		; B367: the helicopter's missile
	ld a,(hl)
	or a
	jr z,.ch2_set
	dec (hl)
	ld b,a
	ld a,(ATTRACT_FLAGS)
	rla
	jr c,.ch2_set
	ld a,b
	add a,$46
	ld e,a
	xor $0E
	add a,4
	and $0F
	add a,a
	add a,a
	ld d,a
.ch2_set
	ld a,d
	ld (pokey_audf + 1),a
	ld a,e
	ld (pokey_audc + 1),a
	ld de,0				; channel 3: B386, firing, rising
	ld hl,SOUND_FIRE
	ld a,(hl)
	or a
	jr z,.bonus
	dec (hl)
	ld b,a
	ld a,$1C
	sub b
	add a,a
	ld b,a				; twice
	add a,a				; 6 times, with the carry of the shift
	adc a,b
	ld d,a
	ld e,$A8
.bonus	ld hl,SOUND_BONUS		; B399: a bonus life
	ld a,(hl)
	or a
	jr z,.ch3_set
	dec a
	ld (hl),a
	ld b,a
	and $0F
	add a,$A0
	ld e,a
	ld a,b
	rrca
	rrca
	rrca
	rrca
	and $0F
	add a,low ROM_SCORE_PITCH
	ld l,a
	ld h,high ROM_SCORE_PITCH
	ld d,(hl)
.ch3_set
	ld a,d
	ld (pokey_audf + 2),a
	ld a,e
	ld (pokey_audc + 2),a
	ld e,0				; channel 4: B3B6, the tank's shell
	ld a,(ATTRACT_FLAGS)
	rla
	jr c,.ch4_set
	ld a,(SHELL_TIMER)
	or a
	jr z,.ch4_set
	jp m,.ch4_set
	cp $11
	jr nc,.boom
	add a,low ROM_SHELL_PITCH	; whistling down
	ld l,a
	ld h,high ROM_SHELL_PITCH
	ld a,(hl)
	ld (pokey_audf + 3),a
	ld e,$AC
	jr .ch4_set
.boom	call sound_random		; exploding: noise
	or $20
	ld (pokey_audf + 3),a
	ld e,$8C
.ch4_set
	ld a,e
	ld (pokey_audc + 3),a
	ret

; RANDOM for the sound: the counter as the game logic's read sees it (only a noise's pitch;
; not random_read, which the checks count)
sound_random:
	ld a,(rnd_state + 2)
	rra
	ld a,(rnd_state + 1)
	rra
	ret

; ------------------------------------------------------------------------------------------
; The DACs on, the channels and the ring quiet, the zxnDMA sending the ring round and round
sound_init:
	ld bc,$243B
	ld a,$08
	out (c),a
	inc b
	in a,(c)
	and $7F
	or $08				; the DACs
	out (c),a
	ld hl,SND_RING
	ld de,SND_RING + 1
	ld bc,1023
	ld (hl),0
	ldir
	ld hl,pokey_audf
	ld de,pokey_audf + 1
	ld bc,8 + 4 * CH_SIZE - 1
	ld (hl),0
	ldir
	xor a
	ld (snd_off),a
	ld (snd_keys),a
	nextreg $53,INIT_PAGE		; the AY, the tables, the DMA (sound_ay.asm)
	call sound_init7
	nextreg $53,12
	ld a,$87			; the DMA going, now that it reads the ring
	out ($6B),a
	ld hl,SND_RING + SND_LEAD
	ld (snd_w),hl
	ret

; ------------------------------------------------------------------------------------------
; This frame's samples: from snd_w up to SND_LEAD past where the DMA is, SND_CAP at most (a
; frame that came late does not make the next one longer: the samples skipped keep the last
; level).
; The ring gets each channel's changes first (+ or - its volume at the sample where its
; output turns on or off), then a running sum from the frame's first level makes them the
; levels.
pokey_frame:
	ld a,(snd_off)			; the sound off (CAPS + 2): the ring and the AY quiet once
	or a
	jr z,.on
	ld a,(snd_clear)
	or a
	ret z
	call ay_quiet			; (page 6: $6000-$7FFF stays the ring's, see sound_ay_run.asm)
	xor a
	ld (snd_clear),a
	ld hl,SND_RING
	ld de,SND_RING + 1
	ld bc,1023
	ld (hl),a
	ldir
	ret
.on	call ay_frame			; the pure tones on the AY, or all of it
	ld a,(ay_mask)
	cp $0F
	jr nz,.dac
	ld a,(snd_idle)			; all on the AY: the ring quiet once
	or a
	ret nz
	inc a
	ld (snd_idle),a
	ld hl,SND_RING
	ld de,SND_RING + 1
	ld bc,1023
	ld (hl),0
	ldir
	ret
.dac	xor a
	ld (snd_idle),a
	ld bc,$243B			; the lines left before wait_line (past it: the work, which
					; starts at wait_line, has ended before the frame's last
					; line: the rest of the frame and the next one's lines up
					; to wait_line, as many as allowed; it is never a frame long)
	ld a,$1E
	out (c),a
	inc b
	in a,(c)
	and 1
	ld h,a
	dec b
	ld a,$1F
	out (c),a
	inc b
	in l,(c)
	ld a,(wait_line)
	sub l
	ld c,a
	ld a,0
	sbc a,h
	jr z,.left
	ld c,255
.left	ld a,c
	ld (pk_left),a
	ld bc,$6B
	ld a,$A7			; A's address: the next byte the DMA sends
	out (c),a
	in e,(c)
	in a,(c)			; (in the ring: at a round's end it reads $8000)
	and 3
	or high SND_RING
	ld d,a
	ld (pk_dma),de
	ld hl,(snd_w)			; how far ahead the samples are
	or a
	sbc hl,de
	ld a,h
	and 3
	ld h,a
	push hl				; more than the lead ever is: the DMA has passed them
	ld bc,SND_LEAD + 1
	sbc hl,bc
	pop hl
	jr c,.ahead
	ifdef TEST
	push hl
	ld hl,(snd_passed)		; (test builds: how often, for nxcheck)
	inc hl
	ld (snd_passed),hl
	pop hl
	endif
	ld (snd_w),de			; from where the DMA is, as many as the time left allows
	ld hl,0				; (too much work: the sound gives way)
	ld (pk_must),hl
	ld d,h
	ld e,l
	jr .want
.ahead	ex de,hl			; DE: ahead
	ld hl,SND_MIN_LEAD		; the samples it must have (or the DMA passes them before
	or a				; the next frame's)
	sbc hl,de
	jr nc,.must
	ld hl,0
.must	ld (pk_must),hl
.want
	ld hl,SND_LEAD			; the samples it wants
	or a
	sbc hl,de
	ret z
	push hl
	ld a,(pk_left)			; and what the time left allows: 8 a line, past 16 lines
	sub 16
	jr nc,.b
	xor a
.b	ld l,a
	ld h,0
	add hl,hl
	add hl,hl
	add hl,hl
	pop de				; the fewer of these two,
	push hl
	or a
	sbc hl,de
	pop hl
	jr c,.f
	ex de,hl
.f	ld de,(pk_must)			; but what it must
	push hl
	or a
	sbc hl,de
	pop hl
	jr nc,.g
	ex de,hl
.g	ld a,h
	or l
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
	nextreg $50,POLY_PAGE		; the 17-bit counter's bits at $0000
	nextreg $51,POLY_PAGE + 1
	xor a				; no changes yet (and one more sample: where the part of a
	ld (snd_level),a		; turn past the end goes; the next frame starts from the
	ld hl,(snd_w)			; channels' outputs, the turn whole)
	ld de,(snd_n)
	inc de
	call snd_fill
	ld a,(ay_mask)			; (those on the AY: not here)
	ld (ay_skip),a
	ld ix,snd_ch			; the channels
	ld iy,pokey_audf
	ld b,4
.ch	push bc
	ld a,(ay_skip)
	rrca
	ld (ay_skip),a
	jr c,.next
	ld a,(iy+4)			; AUDC
	and $0F
	jr z,.next			; volume 0: nothing to hear
	add a,a
	add a,a
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
	nextreg $50,ATARI_RAM_PAGE
	nextreg $51,ATARI_RAM_PAGE + 1
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
	ld de,(pk_dma)			; DMA gets there before the next frame's samples it plays
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

; DE bytes (1-1023) of A from HL on in the ring: two stretches at most, each pushed from its
; end down (the stack pointer kept)
snd_fill:
	ld c,a
	ld b,a
	push hl				; the start
	push de
	ld de,SND_RING + 1024
	ex de,hl
	or a
	sbc hl,de
	ex de,hl			; DE: up to the ring's end
	pop hl				; HL: the count
	or a
	sbc hl,de
	jr c,.one
	jr z,.one
	ex (sp),hl			; the rest kept, HL the start
	call .seg			; up to the end
	pop de
	ld hl,SND_RING			; the rest from the ring's start
	jr .seg
.one	add hl,de
	ex de,hl
	pop hl
; DE bytes of BC from HL, not past the ring's end
.seg	ld a,d
	or e
	ret z
	bit 0,e
	jr z,.even
	ld (hl),c
	inc hl
	dec de
	ld a,d
	or e
	ret z
.even	add hl,de			; the end
	ld (.sp + 1),sp
	srl d				; words: 16 pushes a round, the first round the rest
	rr e
	ld a,e
	and 15
	neg
	and 15
	add a,low .push
	ld (.jp + 1),a
	ld a,high .push
	adc a,0
	ld (.jp + 2),a
	ex de,hl
	ld a,l
	add a,15
	ld l,a
	jr nc,.r
	inc h
.r	srl h				; (words + 15) / 16
	rra
	srl h
	rra
	srl h
	rra
	srl h
	rra
	ex de,hl
	ld d,a
	ld sp,hl
.jp	jp .push
.push	rept 16
	push bc
	endr
	dec d
	jp nz,.push
.sp	ld sp,0
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

