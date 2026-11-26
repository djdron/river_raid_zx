; pokey_frame and what it calls (the samples, the AY's tones): in a page of their own
; (SOUND_PAGE, at $4000 while pokey_frame runs: river_raid.asm's main loop maps it there and
; SPAN_PAGE back after), as pages 4 and 6 have no room; sound.asm keeps the driver (the
; game's logic) and sound_init.

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
	call snd_gain_set
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
	ld d,a				; C: its level, the volume x the frame's gain
	ld a,(snd_gain)
	ld e,a
	mul d,e
	ld c,e
	bit 4,(iy+4)
	jr nz,.full			; volume only: the volume all the time
	ld a,(iy+0)
	cp 5
	jr nc,.pulses
	ld a,c				; 5 ticks or less: too high to sample, half the volume
	srl a
	jr .level
.full	ld a,c
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

; The frame's gain (snd_gain): a level is the volume x 8, unless the channels on the DAC add
; up to more than 31 (two explosions and the engine's noise: up to ~41 seen), where 8 would
; take the levels past 255 and the running sum would wrap (a hiss): then the most that keeps
; them at 255 or below (7, 6, 5 or 4: 60, all four at 15, x 4 = 240)
snd_gain_set:
	ld a,(ay_skip)
	ld c,a
	ld hl,pokey_audc
	ld de,$0400			; D the channels, E the sum
.v	rrc c
	jr c,.n
	ld a,(hl)
	and $0F
	add a,e
	ld e,a
.n	inc hl
	dec d
	jr nz,.v
	ld a,e
	ld b,8
	cp 32
	jr c,.g
	dec b
	cp 255 / 7 + 1
	jr c,.g
	dec b
	cp 255 / 6 + 1
	jr c,.g
	dec b
	cp 255 / 5 + 1
	jr c,.g
	dec b
.g	ld a,b
	ld (snd_gain),a
	ret
