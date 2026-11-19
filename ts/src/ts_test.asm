; TS-Conf smoke test: 320x240 at 256 colours, a gradient (the check's first step)
	org $8000
VCONFIG		equ $00AF
VPAGE		equ $01AF
PAGE3		equ $13AF
FMADDR		equ $15AF
SYSCONFIG	equ $20AF
VID_PAGE	equ 32			; the picture: 16 pages from here (512 lines of 512 bytes)

start:	di
	ld sp,$BFF0
	ld bc,SYSCONFIG			; 14 MHz (the cache off)
	ld a,$06
	out (c),a
	ld bc,VPAGE
	ld a,VID_PAGE
	out (c),a
	ld bc,VCONFIG			; 256 colours, 320x240
	ld a,$82
	out (c),a
	ld e,VID_PAGE			; the picture: lines 0-239, pixel x/2 on the first 320
	ld d,0				; (D: the line)
.page	ld bc,PAGE3
	ld a,e
	out (c),a
	ld hl,$C000
.line	ld b,0				; 320 dots: x / 2 + the line / 8
	ld c,0
.dot	ld a,c
	srl a
	push af
	ld a,d
	rrca
	rrca
	rrca
	and $1F
	ld b,a
	pop af
	add a,b
	ld (hl),a
	inc hl
	inc c
	jr nz,.dot2
	ld a,1
	ld (.hi + 1),a
.dot2
.hi	ld a,0
	or a
	jr z,.dot
	ld a,c
	cp 320 - 256
	jr c,.dot
	xor a
	ld (.hi + 1),a
	ld bc,512 - 320			; to the next line
	add hl,bc
	inc d
	ld a,d
	cp 240
	jr z,.pal
	ld a,h
	or a
	jr nz,.line
	inc e				; the next page
	jr .page
.pal	ld bc,FMADDR			; the palette: CRAM through the FM window at $C000
	ld a,$10 | $04
	out (c),a
	ld hl,$4000
	ld e,0
.col	ld a,e				; a grey-blue ramp: R = G = e / 8, B = e / 4
	rrca
	rrca
	rrca
	and $1F
	ld d,a
	ld a,e
	rrca
	rrca
	and $1F
	ld c,a				; B
	ld a,d				; RGB555: 0RRRRRGG GGGBBBBB
	rlca
	rlca
	ld b,a				; R << 2
	ld a,d
	rrca
	rrca
	rrca
	and 3
	or b
	ld b,a				; the high byte: R, G's top 2
	ld a,d
	rrca
	rrca
	rrca
	and $E0
	or c
	ld (hl),a
	inc hl
	ld (hl),b
	inc hl
	inc e
	jr nz,.col
.end	ld bc,FMADDR
	xor a
	out (c),a
	ld bc,VCONFIG			; 256 colours, 320x240
	ld a,$82
	out (c),a
	jr $

