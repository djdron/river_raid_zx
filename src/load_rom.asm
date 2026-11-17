; (page 7, at $6000 only while it runs: the start)
	ifndef TEST
; River_Raid.rom (the cartridge image, 8192 bytes) from the program's folder into $A000,
; through esxDOS (page 7 at $6000 meanwhile: start); where long names are not seen, by its short name. Without it: a red
; border, and the program stops.
F_OPEN		equ $9A
F_CLOSE		equ $9B
F_READ		equ $9D
FA_READ		equ $01

load_rom:
	ld ix,rom_name
	call .open
	jr nc,.opened
	ld ix,rom_short_name
	call .open
	jr c,.fail
.opened
	ld (rom_handle),a
	ld ix,$A000
	ld bc,$2000
	rst $08
	db F_READ
	push af
	push bc
	ld a,(rom_handle)
	rst $08
	db F_CLOSE
	pop bc
	pop af
	jr c,.fail
	ld a,b				; all 8192 bytes
	cp $20
	jr nz,.fail
	ld a,c
	or a
	jr nz,.fail
	ld hl,($BFFA)			; the cartridge starts at $A000
	ld de,$A000
	or a
	sbc hl,de
	ret z
.fail	di
	ld a,2
	out ($FE),a
	halt
.open	ld a,'*'
	ld b,FA_READ
	rst $08
	db F_OPEN
	ret

rom_name:	db "River_Raid.rom",0
rom_short_name:	db "RIVER_~1.ROM",0
	endif
