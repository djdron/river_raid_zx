; River Raid river viewer for the ZX Spectrum Next: the attract mode, as the C++ port's
; river viewer shows it. The river of game 1 from the start, one line per frame; the enemies
; wake up and move (from bridge 2 on, as in the original), tanks drive to the river and
; fire, helicopters fire missiles.
;
; Every frame does what the original does (game.asm, display.asm, river_gen.asm), then the
; result is shown the Next's way: the river on Layer 2 (320x256), scrolled by the hardware;
; the players and missiles as sprites (sprites.asm); the colours the DLI changes per line by
; the Copper.
;
; Memory (8K pages):
;   $0000-$3FFF  the Atari's RAM: the game's state, player-missile and screen memory (30, 31)
;   $4000-$5FFF  a window onto Layer 2 (pages 18-27)
;   $6000-$7FFF  buffers (page 12)
;   $8000-$9FFF  the program (page 4)
;   $A000-$BFFF  the cartridge image, read from River_Raid.rom at start (page 5)
;   $C000-$DFFF  the program (page 6)
;   $E000-$FFFF  buffers and the stack (page 1)
;
; Build: sjasmplus src/viewer.asm (river_view.nex), with -DTEST the image for the checks
; (tools/check): no file loading, the cartridge put in page 5 by the check.

	device zxspectrumnext
	opt --zxnext

	include "vars.inc"

ATARI_RAM_PAGE	equ 30
DATA_PAGE	equ 12
CODE2_PAGE	equ 6
L2_BANK		equ 9			; 16K bank of Layer 2: 8K pages 18..27
L2_FIRST_PAGE	equ L2_BANK * 2
L2_PAGES	equ 10			; 320x256 bytes
RIVER_LINES	equ 160
RIVER_TOP	equ 40			; Layer 2 row (of 256) of the river's top line
WAIT_LINE	equ 200			; raster line (ULA numbering) where a frame's work starts

	mmu 4,4
	org $8000
entry:	jp start
	dw line_done			; for the checks: where a river line is ready,
	dw frame_done			; where a frame has been worked out,
	dw apply_done			; and where it has gone live
rnd_init:
	db $01,$00,$00			; POKEY's counter at the first read (the checks set it)

start:
	ifndef TEST
	call load_rom
	ld a,r				; a different moment of power-on every time
	ld hl,rnd_init
	xor (hl)
	jr nz,.r
	inc a
.r	ld (hl),a
	endif
	di
	ld sp,0
	nextreg $07,3			; 28 MHz
	nextreg $50,ATARI_RAM_PAGE	; the Atari's RAM at $0000-$3FFF
	nextreg $51,ATARI_RAM_PAGE + 1
	nextreg $53,DATA_PAGE
	nextreg $56,CODE2_PAGE
	call init_tables
	call init_line_tables
	call init_video
	ld hl,(rnd_init)
	ld (rnd_state),hl
	ld a,(rnd_init + 2)
	ld (rnd_state + 2),a
	xor a
	ld (scroll),a
	call start_attract		; frame 0: the attract mode starts, its first line
main_frame:
	ld a,(scroll)			; the screen as this frame's display sees it
	ld (show_scroll),a
	call prepare
	call display
	call build_sprites
	call logic
	call vbi
frame_done:
	call wait_frame
	call apply
apply_done:
	jr main_frame

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
	nextreg $52,a			; page into $4000
	ld a,(wr_row)
	ld l,a
	ld h,$40
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

init_tables:
	ld hl,0				; double_hi/lo: each bit of a byte doubled
.dbl	ld a,l
	rrca
	rrca
	rrca
	rrca
	call .nibble
	ld h,high double_hi
	ld (hl),a
	ld a,l
	call .nibble
	ld h,high double_lo
	ld (hl),a
	inc l
	jr nz,.dbl
	ld hl,exp4			; exp4: a nibble as 4 bytes of 4-bit pixels, $11 a bit
	ld c,0
.exp	ld b,4
	ld a,c
	rlca
	rlca
	rlca
	rlca
	ld d,a
.e	sla d
	sbc a,a
	and $11
	ld (hl),a
	inc l
	djnz .e
	inc c
	ld a,c
	cp 16
	jr c,.exp
	ld hl,exp8			; exp8: a byte as 8 bytes of 4-bit pixels
	ld c,0
.e8	ld b,8
	ld d,c
.e8b	sla d
	sbc a,a
	and $11
	ld (hl),a
	inc hl
	djnz .e8b
	inc c
	jr nz,.e8
	ld hl,shr_tables		; shift tables: right by 2s bits, then left by 8 - 2s
	ld c,1
.shr	ld l,0
.sr	ld a,l
	ld b,c
.sr1	srl a
	srl a
	djnz .sr1
	ld (hl),a
	inc l
	jr nz,.sr
	inc h
	inc c
	ld a,c
	cp 4
	jr c,.shr
	ld c,3				; left by 6, 4, 2 (for shifts 1, 2, 3)
.shl	ld l,0
.sl	ld a,l
	ld b,c
.sl1	add a,a
	add a,a
	djnz .sl1
	ld (hl),a
	inc l
	jr nz,.sl
	inc h
	dec c
	jr nz,.shl
	ld l,0				; dsh_tables: for shift s, byte k of (bits doubled, 24 bits) >> 2s
.dsh	ld h,high double_hi
	ld d,(hl)
	inc h
	ld e,(hl)
	xor a				; D E A: the 24 bits
	ld c,0				; shift
.ds	ld b,a
	ld a,c
	add a,a
	add a,c
	add a,high dsh_tables
	ld h,a
	ld (hl),d
	inc h
	ld (hl),e
	inc h
	ld (hl),b
	ld a,b
	srl d				; 2 bits further right
	rr e
	rra
	srl d
	rr e
	rra
	inc c
	ld b,a
	ld a,c
	cp 4
	ld a,b
	jr c,.ds
	inc l
	jr nz,.dsh
	ld hl,pf_class			; pf_class: 1, 2, 4 for pixels 1, 2, 3 of a byte
.pfc	ld a,l
	ld c,0
	ld b,4
.px	ld e,a
	and 3
	jr z,.p0
	cp 3
	jr nz,.p12
	set 2,c
	jr .p0
.p12	or c
	ld c,a
.p0	ld a,e
	rrca
	rrca
	djnz .px
	ld (hl),c
	inc l
	jr nz,.pfc
	xor a
	ld (sb_count),a
	ld (sb_half),a
	ld (ap_shown),a
	ld hl,copper_list		; no Copper list yet: the end only
	ld (hl),$FF
	inc hl
	ld (hl),$FF
	ld hl,2
	ld (copper_bytes),hl
	ret
.nibble					; A's low 4 bits, each doubled: 8 bits
	and $0F
	rlca
	rlca
	rlca
	rlca
	ld e,a
	xor a
	ld b,4
.n	add a,a
	add a,a
	sla e
	jr nc,.n0
	or 3
.n0	djnz .n
	ret

init_video:
	xor a				; black border, no ULA
	out ($FE),a
	nextreg $68,$80
	nextreg $4A,0			; transparent: black
	nextreg $14,$E3			; global transparency (the palette never makes it)
	nextreg $4B,0			; sprites: pixel 0 transparent
	nextreg $12,L2_BANK
	nextreg $70,%00010000		; Layer 2 320x256, 8 bits per pixel
	nextreg $16,0			; no scroll yet
	nextreg $71,0
	nextreg $17,0
	nextreg $1C,%00000011		; clip windows: Layer 2 and the sprites, the river's rows
	nextreg $18,0
	nextreg $18,159
	nextreg $18,RIVER_TOP
	nextreg $18,RIVER_TOP + RIVER_LINES - 1
	nextreg $19,0
	nextreg $19,159
	nextreg $19,RIVER_TOP
	nextreg $19,RIVER_TOP + RIVER_LINES - 1
	nextreg $15,%00000011		; sprites over Layer 2, visible, also over the border
	nextreg $43,%10010000		; Layer 2's palette: black, (the bank), the edge, the water
	nextreg $40,0
	nextreg $41,0
	nextreg $40,2
	ld a,(palette + COLOUR_BANK_EDGE)
	nextreg $41,a
	nextreg $40,3
	ld a,(palette + COLOUR_WATER)
	nextreg $41,a
	ld c,L2_FIRST_PAGE		; clear Layer 2
	ld b,L2_PAGES
.clear	ld a,c
	nextreg $52,a
	ld hl,$4000
	ld de,$4001
	ld (hl),0
	push bc
	ld bc,$1FFF
	ldir
	pop bc
	inc c
	djnz .clear
	ld bc,$123B			; Layer 2 on
	ld a,$02
	out (c),a
	ret

COLOUR_BANK_EDGE	equ $20
COLOUR_WATER		equ $84

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

	align 256
palette:				; Atari colour code -> the Next's colour (nextreg $41)
	include "palette.inc"
random_matrix:
	include "random.inc"

	assert $ <= $A000		; page 4 is full

	mmu 6,6
	org $C000
	include "game.asm"
	include "display.asm"
	include "sprites.asm"

	assert $ <= $E000		; page 6 is full

; ------------------------------------------------------------------------------------------
; Buffers (page 12)
	mmu 3,12
	org $6000
scan_p3:	ds 256			; per river line, as the DLI left it: player 3's byte,
scan_x:		ds 256			; its position,
scan_size:	ds 256			; its size,
scan_col:	ds 256			; its colour,
scan_bank:	ds 256			; and the bank colour
sp_mask:	ds 128			; collisions: the 8 sprites' masks, 16 bytes each
sp_u:		ds 8
sp_len:		ds 8
		ds 256 - 128 - 16
double_hi:	ds 256			; a byte's bits doubled
double_lo:	ds 256
ch_bits:	ds 256			; one player's bytes for the sprites
exp4:		ds 64			; a nibble as 4-bit pixels
		ds 256 - 64
sprite_list:	ds 5 * SPRITES_MAX	; the sprites' attributes for apply
	align 256
copper_list:	ds 2048
exp8:		ds 8 * 256		; a byte as 8 bytes of 4-bit pixels, $11 a bit
	assert $ <= $8000

; Buffers and variables (page 1)
	mmu 7,1
	org $E000
line_buf:	ds 256			; the generated line (48 bytes; the drawing wraps at 256)
row_buf:	ds 320			; the line as Layer 2 shows it
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
show_scroll:	ds 1
wr_row:		ds 1
rom_handle:	ds 1
rnd_state:	ds 3
colour_bank:	ds 1
shell_colour:	ds 1
ms_right:	ds 1
; the beam (display.asm)
bm_line:	ds 1
bm_drawn:	ds 1
bm_p:		ds 4			; the players' and missiles' data latched for the line
bm_m:		ds 1
bm_any:		ds 1
lms_k1:		ds 2
hpos_p:		ds 4			; registers
hpos_m:		ds 4
size_p:		ds 4
size_m:		ds 1
colour_p3:	ds 1
regs_end:
beam_bank:	ds 1
coll_mpf:	ds 4			; collision registers (cleared together: 16 bytes)
coll_ppf:	ds 4
coll_mpl:	ds 4
coll_ppl:	ds 4
sp_active:	ds 1
cl_size_m:	ds 1
cl_line:	ds 2
sm_hpos:	ds 1
sm_base:	ds 1
sm_bytes:	ds 1
sm_shr:		ds 1
sm_shl:		ds 1
sp_pf:		ds 1
so_end_b:	ds 1
so_end_c:	ds 1
so_u:		ds 1
so_byte:	ds 1
dl_counter:	ds 1
dl_slot:	ds 1
dl_current:	ds 1
dl_start:	ds 1
dl_flags:	ds 1
dl_row:		ds 1
dl_shapes:	ds 2
dl_colours:	ds 2
dl_sl_y:	ds 1
dl_sl_x:	ds 1
dl_sl_kind:	ds 1
dl_sl_type:	ds 1
dl_sl_size:	ds 1
dl_touched:	ds 1
dl_ended_b664:	ds 1
dl_sp:		ds 2
cl_q:		ds 4
cl_tables:	ds 1
cl_byte:	ds 1
dl_shapes_hi:	ds 1
dl_colours_hi:	ds 1
; the sprites (sprites.asm)
sb_count:	ds 1
sb_half:	ds 1
sb_pattern:	ds 1
sb_bits:	ds 1
sb_off:		ds 1
sb_const:	ds 1
sb_const_x:	ds 1
sb_missiles:	ds 1
sb_offset:	ds 1
sb_start:	ds 1
sb_lines:	ds 1
sb_run_x:	ds 1
sb_run_size:	ds 1
cm_count:	ds 1
cm_shift:	ds 1
bc_select:	ds 1
bc_bank:	ds 1
bc_p3:		ds 1
copper_bytes:	ds 2
ap_shown:	ds 1
	align 256
shr_tables:	ds 6 * 256		; a byte shifted right by 2, 4, 6 bits; and left by 6, 4, 2
pf_class:	ds 256			; the playfield colours of a byte's pixels: 1 bank, 2 edge, 4 water
sm_src:		ds 16			; a sprite's bits doubled, before the shift
	align 256
line_start:	ds 256			; per scanline: ANTIC's cycles at its start
line_after_draw: ds 256			; and the cycles left after it is drawn
dsh_tables:	ds 12 * 256		; a byte's bits doubled and shifted right by 2s bits: 3 bytes
	assert $ < $FF00		; (the stack above)

; ------------------------------------------------------------------------------------------
	ifdef TEST
	mmu 4,4
	savebin "build/test_page4.bin",$8000,$2000
	mmu 6,6
	savebin "build/test_page6.bin",$C000,$2000
	else
	savenex open "build/river_view.nex",entry,0
	savenex core 3,0,0
	savenex cfg 0
	savenex bank 2,3
	savenex close
	endif
