; River Raid river viewer for the ZX Spectrum Next.
;
; The river of game 1 from the start, one line per frame, as the C++ port's river map draws
; it: the generator (river_gen.asm) and the drawing of a line (render.asm) on the Z80, the
; picture on Layer 2 (320x256, 256 colours), scrolled by the hardware.
;
; Memory (8K pages):
;   $0000-$3FFF  the Atari's RAM, where the generator keeps its state (pages 30, 31)
;   $8000-$9FFF  this program (page 4)
;   $A000-$BFFF  the cartridge image, read from River_Raid.rom at start (page 5)
;   $C000-$DFFF  a window onto Layer 2 (pages 18-27)
;   $E000-$FFFF  buffers and the stack (page 1)
;
; Build: sjasmplus src/viewer.asm (river_view.nex), with -DTEST the image for the checks
; (tools/check): no file loading, the cartridge is put in page 5 by the check.

	device zxspectrumnext
	opt --zxnext

	include "vars.inc"

ATARI_RAM_PAGE	equ 30
L2_BANK		equ 9			; 16K bank of Layer 2: 8K pages 18..27
L2_FIRST_PAGE	equ L2_BANK * 2
L2_PAGES	equ 10			; 320x256 bytes
RIVER_LINES	equ 160
RIVER_TOP	equ 40			; Layer 2 row (of 256) of the river's top line
WAIT_LINE	equ 200			; raster line (ULA numbering) where a frame's work starts

	mmu 4,4
	org $8000
entry:	jp start
	dw line_done			; for the checks: the address where a line is ready

start:
	ifndef TEST
	call load_rom
	endif
	di
	ld sp,0
	nextreg $07,3			; 28 MHz
	nextreg $50,ATARI_RAM_PAGE	; the Atari's RAM at $0000-$3FFF
	nextreg $51,ATARI_RAM_PAGE + 1
	call init_video
	call start_game
	xor a
	ld (scroll),a
	ld b,RIVER_LINES		; fill the screen
.fill	push bc
	call new_line
	pop bc
	djnz .fill
	ld a,(scroll)
	nextreg $17,a
	ld bc,$123B			; Layer 2 on
	ld a,$02
	out (c),a
.frame	call wait_frame
	ld a,(scroll)			; show the line drawn in the frame before
	nextreg $17,a
	call new_line
	jr .frame

; a new line at the top, above what is shown until the scroll register moves
new_line:
	call next_line
	call render_line
line_done:				; the checks look at line_buf, row_buf and the state here
	ld a,(scroll)
	dec a
	ld (scroll),a
	add a,RIVER_TOP
	jp write_row

; wait for raster line WAIT_LINE, below the river
wait_frame:
	ld bc,$243B
	ld a,$1F			; active video line, low byte
	out (c),a
	inc b
.wait	in a,(c)
	cp WAIT_LINE
	jr nz,.wait
	ret

; row_buf (320 bytes) into Layer 2 row A. Layer 2 at 320x256 is stored by columns: byte
; x * 256 + y, 32 columns per 8K page.
write_row:
	ld (wr_row),a
	ld de,row_buf
	ld c,L2_FIRST_PAGE
	ld b,L2_PAGES
.page	ld a,c
	nextreg $56,a			; page into $C000
	ld a,(wr_row)
	ld l,a
	ld h,$C0
	rept 32
	ld a,(de)
	ld (hl),a
	inc de
	inc h
	endr
	inc c
	dec b
	jp nz,.page
	ret

init_video:
	xor a				; black border, no ULA
	out ($FE),a
	nextreg $68,$80
	nextreg $4A,0			; transparent: black
	nextreg $14,$E3			; global transparency (the palette never makes it)
	nextreg $12,L2_BANK
	nextreg $70,%00010000		; Layer 2 320x256, 8 bits per pixel
	nextreg $16,0			; no scroll yet
	nextreg $71,0
	nextreg $17,0
	nextreg $1C,%00000001		; Layer 2 clip window: the river's rows
	nextreg $18,0
	nextreg $18,159
	nextreg $18,RIVER_TOP
	nextreg $18,RIVER_TOP + RIVER_LINES - 1
	nextreg $43,%00010000		; Layer 2's first palette: the Atari's colours
	nextreg $40,0
	ld hl,palette
	ld b,0
.pal	ld a,(hl)
	inc hl
	nextreg $44,a
	ld a,(hl)
	inc hl
	nextreg $44,a
	djnz .pal
	ld c,L2_FIRST_PAGE		; clear Layer 2
	ld b,L2_PAGES
.clear	ld a,c
	nextreg $56,a
	ld hl,$C000
	ld de,$C001
	ld (hl),0
	push bc
	ld bc,$1FFF
	ldir
	pop bc
	inc c
	djnz .clear
	ret

	ifndef TEST
; River_Raid.rom (the cartridge image, 8192 bytes) from the program's folder into $A000,
; through esxDOS; where long names are not seen, by its short name. Without it: a red
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

	include "river_gen.asm"
	include "render.asm"

palette:
	include "palette.inc"

	assert $ <= $A000		; the program fits page 4

; ------------------------------------------------------------------------------------------
; Buffers and variables (page 1)
	mmu 7,1
	org $E000
line_buf:	ds 256			; the generated line (48 bytes; the drawing wraps at 256)
row_buf:	ds 320			; the line as Layer 2 shows it
	align 256
rl_colours:	ds 4			; colour codes of the 2-bit indices 0..3
rl_have:	ds 1
rl_type:	ds 1
rl_row:		ds 1
rl_flags:	ds 1
rl_shape:	ds 1
rl_colour:	ds 1
rl_x:		ds 1
rl_width:	ds 1
bh_obj_x:	ds 1
bh_obj_size:	ds 1
bh_island:	ds 1
bh_gap:		ds 1
dl_bank_fill:	ds 1
dl_island:	ds 1
dl_deco_left:	ds 1
dl_x:		ds 1
dl_count:	ds 1
dl_water:	ds 1
dl_small:	ds 1
dl_before:	ds 1
po_slot:	ds 1
po_type:	ds 1
po_x:		ds 1
po_facing:	ds 1
po_place:	ds 1
pt_width:	ds 1
scroll:		ds 1
wr_row:		ds 1
rom_handle:	ds 1

; ------------------------------------------------------------------------------------------
	ifdef TEST
	savebin "build/test_page4.bin",$8000,$2000
	else
	savenex open "build/river_view.nex",entry,0
	savenex core 3,0,0
	savenex cfg 0
	savenex bank 2
	savenex close
	endif
