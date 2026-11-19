; The General Sound's program into the card (the start's work, sound_gs.asm): the card's state
; asked (GS_STATE; no answer: no card; GS_READY: the program is there already, from a run
; before), then through the firmware its page 2 at $8000 (#12), the program a byte at a time
; (#18 the address, #19 a byte, #1B the next), and a jump to it (#13); the program says
; GS_READY once its tables are made. gs_on: 1 if it did.
gs_load:
	xor a
	ld (gs_on),a
	in a,(GS_DATA)			; (data left from before: read)
	ld a,GS_STATE			; the firmware's state, or the program's GS_READY
	out (GS_CMD),a
	call gs_wait_c
	ret c				; no card (or one still starting: none either)
	ld de,0
.ans	in a,(GS_CMD)
	rlca
	jr c,.got
	dec de
	ld a,d
	or e
	jr nz,.ans
	scf
	ret
.got	in a,(GS_DATA)
	cp GS_READY			; the program already there (a run before this one): on
	jr z,.on
	ld a,2				; page 2 at $8000
	out (GS_DATA),a
	ld a,$12
	out (GS_CMD),a
	call gs_wait_c
	ret c
	ld hl,GS_ORG			; the program
	ld a,$18
	call .word
	ret c
	ld hl,gs_prog
	ld bc,GS_PROG_LEN
.put	ld a,(hl)
	out (GS_DATA),a
	ld a,$19
	out (GS_CMD),a
	call gs_wait_c
	ret c
	ld a,$1B
	out (GS_CMD),a
	call gs_wait_c
	ret c
	inc hl
	dec bc
	ld a,b
	or c
	jr nz,.put
	ld hl,GS_ORG			; started
	ld a,$13
	call .word
	ret c
	ld b,8				; its tables: up to about 1.6 s
.run	ld de,0
.r	in a,(GS_CMD)
	rlca
	jr c,.ready
	dec de
	ld a,d
	or e
	jr nz,.r
	djnz .run
	ret
.ready	in a,(GS_DATA)
	cp GS_READY
	ret nz
.on	ld a,1
	ld (gs_on),a
	ret

; command A with HL: L the data before it, H after it
.word	push af
	ld a,l
	out (GS_DATA),a
	pop af
	out (GS_CMD),a
	call gs_wait_c
	ret c
	ld a,h
	out (GS_DATA),a
	jp gs_wait_d

gs_prog:
	incbin "gs_pokey.bin"
GS_PROG_LEN	equ $ - gs_prog
