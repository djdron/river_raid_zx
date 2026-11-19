; The sound (sound.asm): a channel's pulses into the ring (page 6)

; One channel (IX its state, IY its AUDF, AUDC at IY + 4, C its volume x 4, its AUDF 5 or
; more): its changes from snd_w on. Its next pulse is CH_D samples and CH_F / 64 ticks
; ahead; every AUDF + 1 ticks after that another (K of them in this frame's samples). In the
; loops: HL the pulse's sample, E the ticks past it (x 64), B the pulses left (and pk_kh
; rounds of 256), C the volume, D what the channel adds now (0 or C); the other registers:
; HL and C the 17-bit counter's byte and bit (a mask), B the 5-bit counter, D its step, E
; the 4-bit counter.
pk_channel:
	sla c				; the volume x 8
	ld a,c				; and x 0-3 (the part of a turn before it, pk_on, pk_off)
	rrca
	rrca
	and $3F
	ld (snd_tables + $91),a
	ld b,a
	add a,a
	ld (snd_tables + $92),a
	add a,b
	ld (snd_tables + $93),a
	xor a
	ld (snd_tables + $90),a
	ld a,(iy+0)			; the period: AUDF + 1 ticks, as samples and ticks x 64
	ld l,a
	ld h,high snd_mod15		; (and the polynomial counters' steps a pulse)
	ld a,(hl)
	ld (snd_s15),a
	inc h
	ld a,(hl)
	ld (snd_s31),a
	ld a,l
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
	ld (pk_g4.pf + 1),a
	srl h
	rr l
	srl l
	ld a,l
	ld (pk_tone.pq + 1),a
	ld (pk_noise.pq + 1),a
	ld (pk_other.pq + 1),a
	ld (pk_g4.pq + 1),a
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
	ld h,0
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
.k	inc hl
	ld b,l				; B, and rounds of 256 after it
	ld a,l
	or a
	ld a,h
	jr nz,.kh
	dec a
.kh	ld (pk_kh),a
	push bc
	ld c,(ix+CH_D)			; the first pulse's sample in the ring
	ld b,0
	ld hl,(snd_w)
	add hl,bc
	ld a,h
	and 3
	or high SND_RING
	ld h,a
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
	jr z,.noise
	cp 5
	jr z,.tone
	cp 7
	jr z,.tone
	cp 2
	jr z,.g4
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
	pop bc
	jp pk_other
.noise	pop bc
	jp pk_noise
.g4	pop bc
	jp pk_g4
.tone	pop bc
	jp pk_tone

; The output turns on (pk_on) or off (pk_off) at the pulse in HL's sample, E / 64 ticks into
; it: the sample gets the change less the part before the turn, the next one that part (an
; average over the sample, as POKEY's output would be: the turns do not jump to whole
; samples, which buzzes). D the new output.
pk_on:	ld d,c
	ld a,e
	rlca
	rlca
	or $90
	ld (.v + 1),a
.v	ld a,(snd_tables + $90)
	ld (pk_part + 1),a
	neg
	add a,c
	add a,(hl)
	ld (hl),a
	jr pk_part_next
pk_off:	ld d,0
	ld a,e
	rlca
	rlca
	or $90
	ld (.v + 1),a
.v	ld a,(snd_tables + $90)
	ld (.t + 1),a
	neg
	ld (pk_part + 1),a
.t	ld a,0
	sub c
	add a,(hl)
	ld (hl),a
pk_part_next:
	inc l
	jr z,pk_part_page
pk_part:
	ld a,0
	add a,(hl)
	ld (hl),a
	dec l
	ret
pk_part_page:
	push hl				; (the next page)
	ld a,h
	inc a
	and 3
	or high SND_RING
	ld h,a
	ld a,(pk_part + 1)
	add a,(hl)
	ld (hl),a
	pop hl
	dec l
	ret

; the rest of the frame's ticks in CH_D, CH_F, the output, the other registers back
pk_done:
	ld a,d
	or a
	jr z,.o
	ld a,1
.o	ld (ix+CH_OUT),a
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
.loop	ld a,d
	or a
	jr nz,.off
	call pk_on
	jr .pos
.off	call pk_off
.pos	ld a,e				; the next pulse's sample
.pf	add a,0
	ld e,a
	ld a,l
.pq	adc a,0
	ld l,a
	jr c,.page
.cont	djnz .loop
	ld a,(pk_kh)			; another round of 256, or the end
	or a
	jp z,pk_done
	dec a
	ld (pk_kh),a
	jp .loop
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
	jr z,.zero
	ld a,d
	or a
	call z,pk_on
	jr .pos
.zero	ld a,d
	or a
	call nz,pk_off
.pos	ld a,e				; the next pulse's sample
.pf	add a,0
	ld e,a
	ld a,l
.pq	adc a,0
	ld l,a
	jr c,.page
.cont	djnz .loop
	ld a,(pk_kh)			; another round of 256, or the end
	or a
	jp z,pk_done
	dec a
	ld (pk_kh),a
	jp .loop
.page	inc h
	ld a,h
	and 3
	or high SND_RING
	ld h,a
	jr .cont

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
	jr z,.zero
	ld a,d
	or a
	call z,pk_on
	jr .pos
.turn	ld a,d
	or a
	jr nz,.off
	call pk_on
	jr .pos
.zero	ld a,d
	or a
	jr z,.pos
.off	call pk_off
.pos	ld a,e				; the next pulse's sample
.pf	add a,0
	ld e,a
	ld a,l
.pq	adc a,0
	ld l,a
	jr c,.page
.cont	djnz .loop
	ld a,(pk_kh)			; another round of 256, or the end
	or a
	jp z,pk_done
	dec a
	ld (pk_kh),a
	jp .loop
.page	inc h
	ld a,h
	and 3
	or high SND_RING
	ld h,a
	jr .cont

; The 4-bit counter, a pulse let through by the 5-bit one (AUDC bits 7-5 010: the
; helicopter's missile), by g4_tab: the two counters as one, m (0-464: m mod 31 the 5-bit
; one, m mod 15 the 4-bit one), a pulse m + s. In the other registers HL g4_tab + m, DE s,
; BC 465 (the 17-bit counter's kept on the stack; the counters back at the end, pk_done).
pk_g4:
	ifdef G4CHECK			; (-DG4CHECK: the counters at the end checked by stepping)
	ld a,(pk_kh)
	ld (g4c_kh),a
	ld a,b
	ld (g4c_b),a
	exx
	ld a,b
	ld (g4c_p31),a
	ld a,e
	ld (g4c_p15),a
	exx
	endif
	exx
	push hl
	ld a,c
	push af
	push de				; (D: the 5-bit counter's step)
	ld c,e				; m
	call g4_crt
	ld bc,g4_tab
	add hl,bc
	ex (sp),hl
	ld b,h				; s
	ld a,(snd_s15)
	ld c,a
	call g4_crt
	ex de,hl
	pop hl
	ld bc,465
	exx
.loop	exx
	add hl,de
	ld a,h
	cp high (g4_tab + 465)
	jr c,.m
	sbc hl,bc
.m	ld a,(hl)
	exx
	inc a
	jr z,.pos			; not let through
	dec a
	jr z,.zero
	ld a,d
	or a
	call z,pk_on
	jr .pos
.zero	ld a,d
	or a
	call nz,pk_off
.pos	ld a,e				; the next pulse's sample
.pf	add a,0
	ld e,a
	ld a,l
.pq	adc a,0
	ld l,a
	jr c,.page
.cont	djnz .loop
	ld a,(pk_kh)			; another round of 256, or the end
	or a
	jr z,.end
	dec a
	ld (pk_kh),a
	jp .loop
.page	inc h
	ld a,h
	and 3
	or high SND_RING
	ld h,a
	jr .cont
.end	exx				; the counters from m: B m mod 31, E m mod 15
	ld bc,-g4_tab
	add hl,bc
	ld de,-31
	ld c,0				; (C: m / 31)
.d31	ld a,h
	or a
	jr nz,.s31
	ld a,l
	cp 31
	jr c,.r31
.s31	add hl,de
	inc c
	jr .d31
.r31	ld b,l
	add a,c				; m mod 15 = (m mod 31 + m / 31) mod 15
.d15	cp 15
	jr c,.r15
	sub 15
	jr .d15
.r15	ld e,a
	pop af
	ld c,a
	pop hl
	ifdef G4CHECK
	push hl
	push bc
	push de
	ld a,(g4c_b)			; K = B + 256 pk_kh pulses (B 0: 256)
	ld l,a
	ld a,(g4c_kh)
	ld h,a
	ld a,l
	or a
	jr nz,.ck
	inc h
.ck	ld a,(snd_s15)
	ld c,a
	ld a,(snd_s31)
	ld d,a
	ld a,(g4c_p31)
	ld b,a
	ld a,(g4c_p15)
	ld e,a
.cl	ld a,b
	add a,d
	cp 31
	jr c,.c1
	sub 31
.c1	ld b,a
	ld a,e
	add a,c
	cp 15
	jr c,.c2
	sub 15
.c2	ld e,a
	dec hl
	ld a,h
	or l
	jr nz,.cl
	ld a,b
	ld c,e
	pop de
	cp b
	jr nz,.bad
	ld a,c
	cp e
	jr z,.ok
.bad	ld hl,(g4c_bad)
	inc hl
	ld (g4c_bad),hl
.ok	ld hl,(g4c_n)
	inc hl
	ld (g4c_n),hl
	pop bc
	pop hl
	endif
	exx
	jp pk_done

; HL = the number m (0-464) with m mod 31 = B, m mod 15 = C: B + 31 ((C - B) mod 15) (DE spent)
g4_crt:	ld a,c
	sub b
	add a,30
.m	cp 15
	jr c,.t
	sub 15
	jr .m
.t	ld e,a
	ld d,31
	mul d,e
	ld l,b
	ld h,0
	add hl,de
	ret
