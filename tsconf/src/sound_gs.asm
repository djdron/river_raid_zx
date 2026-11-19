; The sound on the General Sound, when there is one: all of POKEY's channels played by the
; card (gs/gs_pokey.asm, its program: the Next's DAC sound, in mono). gs_load (the start's,
; gs_load.asm) puts the program in; then apply sends POKEY's registers once a frame
; (gs_send): a command, then AUDF1-4 and AUDC1-4 as data, each once the card has read the one
; before. With no card (or one that does not answer) the AY plays the pure tones
; (sound_ay.asm).

GS_CMD		equ $BB			; the card's ports: commands and its state (bit 0 a
GS_DATA		equ $B3			; command not taken yet, bit 7 data), data
GS_FRAME	equ $A5			; a frame's registers follow
GS_STATE	equ $F0			; the firmware's state (the program: GS_READY)
GS_READY	equ $5A			; the program says it runs
GS_ORG		equ $8400		; where it goes in the card (page 2 at $8000)

; the frame's sound: the AY's tones worked out, unless the card plays it all
snd_frame:
	ld a,(gs_on)
	or a
	ret nz
	jp ay_frame

; and put out (apply)
snd_out:
	ld a,(gs_on)
	or a
	jp z,ay_out
gs_send:
	ld a,GS_FRAME
	out (GS_CMD),a
	call gs_wait_c
	jr c,.off
	ld hl,pokey_audf
	ld b,8
.d	ld a,(hl)
	out (GS_DATA),a
	call gs_wait_d
	jr c,.off
	inc hl
	djnz .d
	ret
.off	xor a				; the card no longer answers: the AY from now on
	ld (gs_on),a
	ret

; Waits until the card has taken the command (bit 0 clear) or read the data (bit 7 clear):
; carry if it has not after about 0.2 s (14 MHz; DE spent)
gs_wait_c:
	ld de,0
.w	in a,(GS_CMD)
	rrca
	ret nc
	dec de
	ld a,d
	or e
	jr nz,.w
	scf
	ret
gs_wait_d:
	ld de,0
.w	in a,(GS_CMD)
	rlca
	ret nc
	dec de
	ld a,d
	or e
	jr nz,.w
	scf
	ret
