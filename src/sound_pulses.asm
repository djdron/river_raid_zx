; The sound (sound.asm): a channel's pulses into the ring (page 6)

; One channel (IX its state, IY its AUDF, AUDC at IY + 4, C its volume x 4, its AUDF 5 or
; more): its changes from snd_w on. Its next pulse is CH_D samples and CH_F / 64 ticks
; ahead; every AUDF + 1 ticks after that another (K of them in this frame's samples). In the
; loops: HL the pulse's sample, E the ticks past it (x 64), B the pulses left, C the volume,
; D what the channel adds now (0 or C; for a tone, what it adds at its next pulse: + or - C);
; the other registers: HL and C the 17-bit counter's byte and bit (mask), B the 5-bit
; counter, D its step, E the 4-bit counter.
pk_channel:
	sla c				; the volume x 4
	ld a,(iy+0)			; the period: AUDF + 1 ticks, as samples and ticks x 64
	inc a
	ld l,a
	ld h,0
	jr nz,.p
	inc h
.p	ld a,l
	and 3
	rrca
	rrca
	ld (pk_tone.pf + 1),a
	ld (pk_noise.pf + 1),a
	ld (pk_other.pf + 1),a
	srl h
	rr l
	srl l
	ld a,l
	ld (pk_tone.pq + 1),a
	ld (pk_noise.pq + 1),a
	ld (pk_other.pq + 1),a
	push bc
	ld a,(iy+0)			; the polynomial counters' steps a pulse
	ld b,15
	call pk_mod
	ld (snd_s15),a
	ld a,(iy+0)
	ld b,31
	call pk_mod
	ld (snd_s31),a
	pop bc
	ld a,(ix+CH_OUT)		; what it adds at the frame's start
	or a
	jr z,.l0
	ld a,c
.l0	ld (pk_d),a
	ld hl,snd_level
	add a,(hl)
	ld (hl),a
	ld l,(ix+CH_D)			; the first pulse's tick: 4 x CH_D + CH_F / 64
	ld h,0
	add hl,hl
	add hl,hl
	ld a,(ix+CH_F)
	rlca
	rlca
	and 3
	or l
	ld l,a
	ex de,hl
	ld hl,(snd_ticks)
	or a
	sbc hl,de
	jr z,.none
	jr nc,.some
.none	ld a,(snd_n)			; past this frame's samples
	ld e,a
	ld a,(ix+CH_D)
	sub e
	ld (ix+CH_D),a
	ret
.some	dec hl				; K = (ticks - 1 - first) / period + 1
	ld a,(iy+0)
	inc a
	jr nz,.div
	ld l,h				; (256)
	jr .k
.div	push bc
	ld c,a
	xor a
	ld b,16
.d	add hl,hl
	rla
	jr c,.s
	cp c
	jr c,.d1
.s	sub c
	inc l
.d1	djnz .d
	pop bc
.k	inc l
	ld b,l
	push bc
	ld c,(ix+CH_D)			; the first pulse's sample in the ring
	ld b,0
	ld hl,(snd_w)
	add hl,bc
	ld a,h
	and 3
	or high SND_RING
	ld h,a
	pop bc
	ld e,(ix+CH_F)
	ld a,(pk_d)
	ld d,a
	exx
	ld l,(ix+CH_Q)
	ld h,(ix+CH_Q + 1)
	ld c,(ix+CH_QM)
	ld a,c
	or a
	jr nz,.m
	inc c
.m	ld b,(ix+CH_P31)
	ld e,(ix+CH_P15)
	ld a,(snd_s31)
	ld d,a
	exx
	ld a,(iy+4)			; what a pulse does: AUDC's bits 7-5
	rlca
	rlca
	rlca
	and 7
	cp 4
	jp z,pk_noise
	cp 5
	jp z,pk_tone
	cp 7
	jp z,pk_tone
	push hl
	add a,a
	ld hl,pk_handlers
	add a,l
	ld l,a
	adc a,h
	sub l
	ld h,a
	ld a,(hl)
	inc hl
	ld h,(hl)
	ld l,a
	ld (pk_other.call + 1),hl
	pop hl
	jp pk_other

; the rest of the frame's ticks in CH_D, CH_F; the other registers back
pk_done:
	ld a,e
	ld (ix+CH_F),a
	ld de,(snd_w)			; the next pulse past the frame's end
	or a
	sbc hl,de
	ld a,h
	and 3
	ld h,a
	ld de,(snd_n)
	or a
	sbc hl,de
	ld a,l
	ld (ix+CH_D),a
	exx
	ld (ix+CH_Q),l
	ld (ix+CH_Q + 1),h
	ld (ix+CH_QM),c
	ld (ix+CH_P31),b
	ld (ix+CH_P15),e
	exx
	ret

; A tone: the output turns at every pulse
pk_tone:
	ld a,d				; at the next pulse: + or - the volume
	or a
	ld a,c
	jr z,.l
	neg
.l	ld d,a
.loop	ld a,(hl)
	add a,d
	ld (hl),a
	ld a,d
	neg
	ld d,a
	ld a,e
.pf	add a,0
	ld e,a
	ld a,l
.pq	adc a,0
	ld l,a
	jr c,.page
.cont	djnz .loop
	ld a,d				; on if it turns off next
	rlca
	and 1
	ld (ix+CH_OUT),a
	jp pk_done
.page	inc h
	ld a,h
	and 3
	or high SND_RING
	ld h,a
	jr .cont

; Noise: the 17-bit counter's bit at every pulse (its bits in turn: the bit 28 x the
; period on is as random as the next one)
pk_noise:
.loop	exx
	rlc c
	jr nc,.q
	inc hl
	bit 6,h
	jr z,.q
	ld h,0
.q	ld a,(hl)
	and c
	exx
	jr z,.off
	ld a,d
	or a
	jr nz,.pos
	ld d,c
	ld a,(hl)
	add a,c
	ld (hl),a
	jr .pos
.off	ld a,d
	or a
	jr z,.pos
	ld d,0
	ld a,(hl)
	sub c
	ld (hl),a
.pos	ld a,e
.pf	add a,0
	ld e,a
	ld a,l
.pq	adc a,0
	ld l,a
	jr c,.page
.cont	djnz .loop
	jr pk_end
.page	inc h
	ld a,h
	and 3
	or high SND_RING
	ld h,a
	jr .cont
pk_end:	ld a,d
	or a
	jr z,.o
	ld a,1
.o	ld (ix+CH_OUT),a
	jp pk_done

; The rest (the 5-bit counter letting a pulse through, the 4-bit counter): what a pulse does
; from pk_handlers: A the output (0, 1), 2 a turn, $FF nothing
pk_other:
.loop	exx
.call	call 0
	exx
	cp 2
	jr z,.turn
	jr nc,.pos
	or a
	jr z,.off
.on	ld a,d
	or a
	jr nz,.pos
	ld d,c
	ld a,(hl)
	add a,c
	ld (hl),a
	jr .pos
.turn	ld a,d
	or a
	jr z,.on
.off	ld a,d
	or a
	jr z,.pos
	ld d,0
	ld a,(hl)
	sub c
	ld (hl),a
.pos	ld a,e
.pf	add a,0
	ld e,a
	ld a,l
.pq	adc a,0
	ld l,a
	jr c,.page
.cont	djnz .loop
	jr pk_end
.page	inc h
	ld a,h
	and 3
	or high SND_RING
	ld h,a
	jr .cont

pk_handlers:				; by AUDC's bits 7-5 (100, 101, 111: the loops above)
	dw ph_g17, ph_gtone, ph_g4, ph_gtone, 0, 0, ph_4, 0

; A mod B (A + 1, as AUDF + 1)
pk_mod:	ld l,a
	ld h,0
	inc hl
.m	ld a,l
	sub b
	ld l,a
	jr nc,.m
	dec h
	jp p,.m
	add a,b
	ret

adv31:	macro			; the 5-bit counter a pulse on
	ld a,b
	add a,d
	cp 31
	jr c,1F
	sub 31
1:	ld b,a
	endm
adv15:	macro
	ld a,(snd_s15)
	add a,e
	cp 15
	jr c,1F
	sub 15
1:	ld e,a
	endm
gate:	macro			; its bit 0: no pulse
	ld a,b
	ld (.g5 + 1),a
.g5	ld a,(snd_tables)
	or a
	ld a,$FF
	ret z
	endm
step17:	macro			; the 17-bit counter's next bit in A (0, 1)
	rlc c
	jr nc,1F
	inc hl
	bit 6,h
	jr z,1F
	ld h,0
1:	ld a,(hl)
	and c
	jr z,2F
	ld a,1
2:
	endm
read4:	macro
	ld a,e
	add a,$40
	ld (.g4 + 1),a
.g4	ld a,(snd_tables + $40)
	endm

ph_gtone:
	adv31
	gate
	ld a,2
	ret
ph_4:	adv15
	read4
	ret
ph_g4:	adv15
	adv31
	gate
	read4
	ret
ph_g17:	step17
	ex af,af'
	adv31
	gate
	ex af,af'
	ret
