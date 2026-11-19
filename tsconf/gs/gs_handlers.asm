; The sound on the General Sound (gs_pulses.asm): what a pulse does in pk_other

pk_handlers:				; by AUDC's bits 7-5 (100, 101, 111: the loops above)
	dw ph_g17, ph_gtone, ph_g4, ph_gtone, 0, 0, ph_4, 0

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
	ld a,h
	or a
	jr nz,1F
	ld h,high POLY17
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
