; River Raid for the ZX Spectrum Next. The attract mode, then the game with START, as the
; C++ port runs them: the plane, its bullet and fuel, the enemies, tanks and missiles,
; crashes, new planes, two players. (No panel or sound yet: the panel's characters are
; kept in memory as the original keeps them.)
;
; Every frame does what the original does (game.asm, play.asm, display.asm, river_gen.asm), then the
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
; Build: sjasmplus src/river_raid.asm (river_raid.nex), with -DTEST the image for the checks
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
WAIT_LINE_NTSC	equ 208			; raster line (ULA numbering) where a frame's work starts:
WAIT_LINE_PAL	equ 220			; below the scrolling line
INIT_PAGE	equ 7			; panel_init.asm, at $6000 while it runs
PANEL_FIRST_LINE equ 200		; the tilemap's lines: the panel and the scrolling line
PANEL_LAST_NTSC	equ 239
PANEL_LAST_PAL	equ 255
TILE_256	equ $4000		; page 11 at $4000: the scrolling line's tile 256
TILE_MAP	equ $4100		; and the map, 40 x 32 entries of 2 bytes
NEEDLE_OFFSET	equ 4			; sprite palette offsets
LOGO_OFFSET	equ 5
PATTERN_CACHE	equ $4800		; page 7 at $4000: the rows of each sprite pattern (128 x 16),
PC_BUCKETS	equ $5000		; a hash of the rows -> pattern + 1, for each set (2 x 256),
PC_HASH		equ $5200		; each pattern's hash,
PC_USED		equ $5300		; which are used this frame;
OB_BUCKETS	equ $5400		; the objects' patterns (8-bit): a hash of the key -> pattern + 1,
OB_SHL		equ $5500		; each pattern's key (by pattern, 64 each): its first row's
OB_SHH		equ $5540		; address,
OB_CLL		equ $5580		; its colour's,
OB_CLH		equ $55C0
OB_N		equ $5600		; its rows ($FF: none to match),
OB_HASH		equ $5640		; the hash,
OB_FRAME	equ $5680		; the frame it was last used in
SPAN_PAGE	equ 28			; at $4000 (display, push_line): the river lines' runs of bank
SPANS		equ $4000		; and edge pixels, 32 bytes a line, a ring of 256 (spans.asm)

; HL = the record of slot A
span_rec	macro
	rrca
	rrca
	rrca
	ld l,a
	and $1F
	add a,high SPANS
	ld h,a
	ld a,l
	and $E0
	ld l,a
	endm

	mmu 4,4
	org $8000
entry:	jp start
	dw line_done			; for the checks: where a river line is ready,
	dw frame_done			; where a frame has been worked out,
	dw apply_done			; and where it has gone live
rnd_init:
	db $01,$00,$00			; POKEY's counter at the first read (the checks set it)
in_stick:	db $0F,$0F		; the controls of the frame (play.asm; the checks set them)
in_trig:	db 0
in_console:	db 0
in_key:		db 0
tv_init:	db 1			; 1 PAL (50 Hz), 0 NTSC (60 Hz); CAPS + 1 changes it
rnd_feed_on:	db 0			; test builds: RANDOM as the checks give it (random_read)
rnd_feed:	db 0
rnd_feed_reads:	db 0
	ifdef TEST
start_bridges_hi: db 0			; the starting bridge's hundreds and thousands, BCD (nxcheck
					; NXBRIDGE patches the ROM's starts and this)
snd_passed:	dw 0			; the frames whose samples the DMA had passed (sound.asm)
test_ghost_on:	db 0			; nxcheck NXGHOST: after the display, the plane cannot crash
test_ghost:				; and never runs out of fuel (as the C++ port's display_bench)
	ld a,(test_ghost_on)
	or a
	ret z
	ld a,$FF
	ld (HIT_PLANE_BANK),a
	ld (HIT_PLANE_OBJECT),a
	ld (HIT_PLANE_SHELL),a
	ld (HIT_MISSILE_PLANE),a
	ld (FUEL),a
	ret
	endif

start:
	ifndef TEST
	nextreg $53,INIT_PAGE		; (load_rom is there)
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
	call init_video
	nextreg $53,INIT_PAGE		; the panel's characters, tiles and sprites
	call panel_init
	nextreg $53,DATA_PAGE
	ld hl,(rnd_init)
	ld (rnd_state),hl
	ld a,(rnd_init + 2)
	ld (rnd_state + 2),a
	ld a,(tv_init)
	ld (tv_pal),a
; The machine switched on with tv_pal's standard: everything from the start
restart:
	ld sp,0
	call tv_setup
	ld a,L2_PAGES			; Layer 2 empty
	ld (l2_clear),a
.cl2	call clear_layer2_page
	ld a,(l2_clear)
	or a
	jr nz,.cl2
	xor a
	ld (scroll),a
	ld (busy),a
	ld (resume),a
	ld (game_over_text),a
	ld (vbi_before),a
	call sound_init
	call start_attract		; frame 0: the attract mode starts, its first line
main_frame:
	ld a,(scroll)			; the screen as this frame's display sees it
	ld (show_scroll),a
	ld a,(colour_edge)
	ld (show_edge),a
	ld a,(colour_water)
	ld (show_water),a
	ld a,(PLAYER)
	ld (show_player),a
	ifndef TEST
	call read_input
	endif
	ld a,(tv_toggle)		; CAPS + 1: the other standard, from the start (the checks
	or a				; set it too)
	jr z,.go
	xor a
	ld (tv_toggle),a
	ld a,(tv_pal)
	xor 1
	ld (tv_pal),a
	jp restart
.go
	ld a,(busy)
	or a
	jr nz,.busy
	call prepare
	call display
	call build_sprites
	call main_loop
	call vbi
	jr .sound
.busy	dec a				; sub $B0F1 is clearing memory: the main loop is stuck,
	ld (busy),a			; only the interrupts run
	cp 1
	jr nz,.b
	ld (SCREEN_ON),a		; colours back on
.b	call display
	call build_sprites
	call clear_layer2_page
	ld a,(busy)
	or a
	call z,finish_reset
	call vbi
.sound	call pokey_frame
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
	ld a,(wait_line)
	ld e,a
.wait	in a,(c)
	cp e
	jr nz,.wait
	ret

init_tables:
	ld hl,mc_bullet			; the missiles' bits as a player's byte
.mc	ld a,l
	ld c,0
	bit 5,a
	jr z,$+4
	set 7,c
	bit 4,a
	jr z,$+4
	set 6,c
	ld (hl),c
	inc h
	ld c,0
	bit 1,a
	jr z,$+4
	ld c,$C0
	bit 0,a
	jr z,.mc1
	ld a,c
	or $30
	ld c,a
.mc1	ld (hl),c
	dec h
	inc l
	jr nz,.mc
	ld hl,pix_tab			; render_line's tables
.pix	ld a,l
	ld c,h
	ld b,4
.pk	rlca
	rlca
	ld e,a
	and 3
	ld (hl),a
	ld a,e
	inc h
	djnz .pk
	ld h,c
	inc l
	jr nz,.pix
	ld hl,$2000			; ring_lo/hi: screen memory's lines, 80 in each block
	ld de,ring_lo
.ring	ld a,l
	ld (de),a
	inc d
	ld a,h
	ld (de),a
	dec d
	inc e
	ld bc,48
	add hl,bc
	ld a,e
	cp 80
	jr nz,.r1
	ld hl,$3000
.r1	cp 160
	jr nz,.ring
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
	ld hl,span_class		; span_class: a byte's colour if its 4 pixels are one
.sc	ld a,l				; (water and background: 0), $FF if not
	rlca
	rlca
	cp l
	ld a,$FF
	jr nz,.sc1
	ld a,l
	and 3
	cp 3
	jr nz,.sc1
	xor a
.sc1	ld (hl),a
	inc l
	jr nz,.sc
	call span_init
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
	ld a,1				; (all of it to the Copper)
	ld (cp_full),a
	ret

; The standard's settings (tv_pal): 50 or 60 Hz, ANTIC's cycles at the panel's first line,
; when a frame starts, POKEY's counter per frame, where the panel and the scrolling line are.
tv_setup:
	ld bc,$243B			; nextreg $05 bit 2: 60 Hz for NTSC
	ld a,$05
	out (c),a
	inc b
	in a,(c)
	and %11111011
	ld e,a
	ld a,(tv_pal)
	or a
	ld a,e
	jr nz,.hz
	or %00000100
.hz	nextreg $05,a
	call init_line_tables
	ld a,(tv_pal)
	or a
	ld a,WAIT_LINE_NTSC
	ld hl,random_columns_ntsc
	ld de,copper_panel_ntsc
	ld bc,PANEL_LAST_NTSC << 8 | 160 - 202
	jr z,.set
	ld a,WAIT_LINE_PAL
	ld hl,random_columns_pal
	ld de,copper_panel_pal
	ld bc,PANEL_LAST_PAL << 8 | 160 - 206
.set	ld (wait_line),a
	ld (rnd_cols),hl
	ld a,c				; the tilemap at the panel's first row (copper_start)
	ld (copper_start + 7),a
	ex de,hl			; the Copper's part for the panel and the scrolling line
	ld de,copper_panel
	push bc
	ld bc,copper_panel_end - copper_panel
	ldir
	pop bc
	ld a,(palette + $06)		; the panel's background (COLBK $06)
	ld hl,copper_panel + COPPER_GREY
	ld (hl),a
	inc hl
	inc hl
	ld (hl),a
	inc hl
	inc hl
	ld (hl),a
	inc hl
	inc hl
	ld (hl),a
	ld a,(tv_pal)			; Layer 2's clip window: the river and the panel's grey
	or a
	ld a,229
	jr z,.l2
	ld a,239
.l2	nextreg $1C,%00000001
	nextreg $18,0
	nextreg $18,159
	nextreg $18,RIVER_TOP
	nextreg $18,a
	ld a,$FF			; the Copper's list made again (no Atari colour is odd)
	ld (cp_colour),a
	nextreg $1C,%00001010		; clip windows: the sprites and the tilemap to the last line
	nextreg $19,0
	nextreg $19,159
	nextreg $19,RIVER_TOP
	ld a,b
	nextreg $19,a
	nextreg $1B,0
	nextreg $1B,159
	nextreg $1B,PANEL_FIRST_LINE
	nextreg $1B,a
	jp rnd_tables			; random_step's tables for the standard

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
	nextreg $1C,%00000001		; clip window: Layer 2, the river's rows (the sprites' and
	nextreg $18,0			; the tilemap's: tv_setup)
	nextreg $18,159
	nextreg $18,RIVER_TOP
	nextreg $18,RIVER_TOP + RIVER_LINES - 1
	nextreg $15,%00110011		; the tilemap over the sprites over Layer 2 (USL), sprites
					; visible, also over the border, in their clip window (from
					; the river's top: an object's rows above it are not shown)
	nextreg $43,%10010000		; Layer 2's palette: black, (the bank), the edge, the water
	nextreg $40,0
	nextreg $41,0
	nextreg $40,2
	ld a,(palette + COLOUR_BANK_EDGE)
	nextreg $41,a
	nextreg $40,3
	ld a,(palette + COLOUR_WATER)
	nextreg $41,a
	nextreg $43,%00100000		; the sprites' palette 128-255: the Atari's colours, 128 +
	nextreg $40,128			; colour / 2 (the objects' patterns: sprites.asm)
	ld hl,palette
	ld b,128
.sp	ld a,(hl)
	nextreg $41,a
	inc l
	inc l
	djnz .sp
	ld bc,$123B			; Layer 2 on
	ld a,$02
	out (c),a
	ret

COLOUR_BANK_EDGE	equ $20
COLOUR_WATER		equ $84


	include "river_gen.asm"
	include "render.asm"
	include "display_objs.asm"	; (before the palette's alignment: room there)
	assert $ <= $9000

	align 256
palette:				; Atari colour code -> the Next's colour (nextreg $41)
	include "palette.inc"
random_columns:
	include "random.inc"
	include "play.asm"
	include "sound.asm"
	include "sound_handlers.asm"
	ifdef OBJCHECK
; (test) the other players' and missiles' rows on the river's lines outside their boxes
; (dh_desc: shell, tank, plane, helicopter missile, bullet): pc_bad
pc_check:
	ld ix,dh_desc
	ld b,5
.ch	push bc
	ld l,RIVER_FIRST
.ln	ld h,(ix + 0)
	ld a,(hl)
	and (ix + 1)
	jr z,.ok
	ld a,(ix + 7)			; rows: in the box?
	or a
	jr z,.bad
	ld a,l
	sub (ix + 6)
	jr c,.bad
	cp (ix + 7)
	jr c,.ok
.bad	push hl
	ld hl,(pc_bad)
	inc hl
	ld (pc_bad),hl
	pop hl
.ok	inc l
	ld a,l
	cp RIVER_FIRST + RIVER_LINES
	jr c,.ln
	ld de,DH_SIZE
	add ix,de
	pop bc
	djnz .ch
	ret

	endif

	display "page 4 end: ",$
	assert $ <= $A000		; page 4 is full

	mmu 6,6
	org $C000
	include "game.asm"
	include "display.asm"
	include "sprites.asm"
	include "sound_pulses.asm"
	include "sound_ay_run.asm"
	include "spans.asm"
	include "display_hits.asm"

	display "page 6 end: ",$
	assert $ <= $E000		; page 6 is full

	mmu 3,INIT_PAGE
	org $6000
	include "panel_init.asm"
	include "sound_ay.asm"
	include "load_rom.asm"
	display "page 7 end: ",$
	assert $ <= $6800		; (the pattern cache from $6800: PATTERN_CACHE in slot 2)

; ------------------------------------------------------------------------------------------
; Buffers (page 12)
	mmu 3,12
	org $6000
scan_p3:	ds 256			; per river line, as the DLI left it: player 3's byte,
scan_x:		ds 256			; its position,
scan_size:	ds 256			; its size,
scan_col:	ds 256			; its colour,
scan_bank:	ds 256			; and the bank colour
ds_cover:	ds 256			; display: the other sprites' boxes by scanline
ch_bits:	ds 256			; one player's bytes for the sprites
ring_lo:	ds 256			; screen memory's 160 lines, in the order they follow
ring_hi:	ds 256
sprite_list:	ds 5 * SPRITES_MAX	; the sprites' attributes for apply
ds_objs:	ds 8 * DS_OBJS		; display: the objects' rows (display_simple.asm)
	align 256
copper_list:	ds 2048
exp8:		ds 8 * 256		; a byte as 8 bytes of 4-bit pixels, $11 a bit
	assert $ <= $8000

; Buffers and variables (page 1)
	mmu 7,1
	org $E000
line_buf:	ds 256			; the generated line (48 bytes; the drawing wraps at 256)
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
colour_bank:	ds 1			; the playfield's colours for the next frame (the VBI)
colour_edge:	ds 1
colour_water:	ds 1
show_edge:	ds 1			; and as this frame shows them
show_water:	ds 1
show_player:	ds 1
pf_s:		ds 1			; panel_frame
pf_h0:		ds 1
pf_text:	ds 2
pf_right:	ds 2
pf_right_half:	ds 1
pf_left_half:	ds 1
pf_left_nibble:	ds 1
pf_mask:	ds 1
logo_shown:	ds 1			; the logo's position this frame (before the VBI moves it)
game_over_text:	ds 1			; A3B4: "Game over" scrolls past
busy:		ds 1			; frames of sub $B0F1 still to come
resume:		ds 1			; what the main loop does after them
l2_clear:	ds 1			; pages of Layer 2 still to clear
rs_full:	ds 1
tv_pal:		ds 1			; 1 PAL, 0 NTSC
tv_toggle:	ds 1			; read_input: CAPS + 1 pressed
tv_keys:	ds 1			; (it was down last frame)
wait_line:	ds 1
rnd_cols:	ds 2			; random_step's map for the standard
vbi_before:	ds 1			; PAL: the VBI sees the state before sub $B21A (vbi)
vbi_saved:	ds 3
logo_y:		ds 1
rl_page:	ds 1
cs_sp:		ds 2
pb_leading:	ds 1
fp_exploding:	ds 1
shell_colour:	ds 1
ms_right:	ds 1
; the beam (display.asm)
bm_line:	ds 1
bm_drawn:	ds 1
bm_p:		ds 4			; the players' and missiles' data latched for the line
bm_m:		ds 1
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
span_top:	ds 1			; the river's top line in the ring of runs (spans.asm)
rec_bank:	ds 3
cs_present:	ds 1			; collide: the sprites on the line (bit n)
cs_list:	ds 5 * 8		; collide: per sprite on the line: bits, position, size,
					; end, mask made
pu_pf:		ds 1			; pf_under
f_ls:		ds 1			; display: ANTIC's cycles at the line's start
ov_bits:	ds 1			; collide.overlap: the other sprite
ov_hpos:	ds 1
ov_wlog:	ds 1
	align 16
es_key:		ds 16			; emit_sprite: a pattern's rows
es_hash:	ds 1
es_src:		ds 2			; the run's rows
pc_next:	ds 2			; the next pattern to take, in each set			; the bank colour's record (rec_set): value, from which line, scan page
sp_pf:		ds 1
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
dl_shapes_hi:	ds 1
dl_colours_hi:	ds 1
; the display without the DLI's cycles (display_simple.asm)
DS_EVENTS	equ 32
ds_counter:	ds 1
ds_slot:	ds 1
ds_current:	ds 1
ds_start:	ds 1
ds_ended:	ds 1
ds_slip:	ds 1
ds_adv:		ds 1
ds_to:		ds 1
ds_cleared:	ds 1
ds_end_line:	ds 1
ds_cur_x:	ds 1
ds_cur_size:	ds 1
ds_cur_col:	ds 1
ds_latch:	ds 1
ds_rows:	ds 1
ds_bank_last:	ds 1
ds_cmask:	ds 2			; ds_cover_do
ds_slow:	ds 1			; display: the DLI fell behind this frame
dl_deco_n:	ds 1			; draw_line: the decoration's rows on the line
dl_deco:	ds 2 * 4		; (where, bytes)
ds_ev_next:	ds 1
DS_BANKS	equ 48
ds_bank_n:	ds 1
ds_bank_ev:	ds 2 * DS_BANKS		; bank colour changes: scanline, colour
ds_ev_n:	ds 1
ds_ev_rd:	ds 1
ds_ev:		ds 3 * DS_EVENTS		; HPOSP3 / SIZEP3 writes: scanline, which, value
ds_y:		ds 1
ds_x:		ds 1
ds_flags:	ds 1
ds_kind:	ds 1
ds_type:	ds 1
ds_size:	ds 1
ds_shapes:	ds 2
ds_colours:	ds 2
ds_row:		ds 1
ds_l1:		ds 1
ds_le:		ds 1
ds_bridge:	ds 1
ds_bullet:	ds 1
ds_hits:	ds 1
ds_edge:	ds 1
ds_obj_n:	ds 1			; the objects drawn (ds_objs)
ds_obj_over:	ds 1			; more than DS_OBJS of them
ds_obj_t:	ds 1
ds_obj_slot:	ds 1			; the slot of the last object in ds_objs ($FF: none),
ds_obj_last:	ds 2			; its entry
ds_edge_kind:	ds 1			; the object is tested against the edge ($FF) or not (0)
ds_edge_skip:	ds 1			; display's rows: no edge test (none, or P3PF set already)
; the sprites (sprites.asm)
sb_count:	ds 1
sb_half:	ds 1
sb_pattern:	ds 1
sb_bits:	ds 1
sb_off:		ds 1
sb_offset:	ds 1
sb_start:	ds 1
sb_lines:	ds 1
sb_run_x:	ds 1
sb_run_size:	ds 1
cm_count:	ds 1
cm_shift:	ds 1
sb_bpage:	ds 1			; the hash table's page of the set (PC_BUCKETS)
ob_frame:	ds 1			; frames, for the objects' patterns (OB_FRAME)
ob_next:	ds 1			; the next object pattern to take
ob_line:	ds 1			; ob_emit: the sprite's first line,
ob_n:		ds 1			; its rows,
ob_sh:		ds 2			; the address of its first row,
ob_col:		ds 2			; and of its first row's colour
ob_x:		ds 1
ob_size:	ds 1
ob_left:	ds 1
ob_hash:	ds 1
ob_nokey:	ds 1			; rows from the scanlines: never the same again
	ifdef OBJCHECK
oc_bad:		ds 2			; (test) the scanlines the objects' sprites do not show as they are
oc_frames:	ds 2
pc_bad:		ds 2
	endif
bc_bank:	ds 1
bc_p3:		ds 1
copper_bytes:	ds 2
cp_full:	ds 1			; the list changed: all of it to the Copper (apply)
cp_colour:	ds 1			; the bank's colour of the list, when it has no changes ($FF:
					; it has, or none made yet)
ap_shown:	ds 1
	align 256
pix_tab:	ds 4 * 256		; render_line: pixel k (bits 7-6 first) of a line byte
mc_bullet:	ds 256			; missile 2's bits ($30) as a player's byte (1 clock a bit)
mc_missile:	ds 256			; missile 0's bits ($03) as a player's byte (2 clocks a bit)
sm_src:		ds 16			; a sprite's bits doubled, before the shift
	align 256
line_start:	ds 256			; per scanline: ANTIC's cycles at its start
line_after_draw: ds 256			; and the cycles left after it is drawn
span_class:	ds 256			; span_line: a byte's colour if its pixels are one, $FF if not
span_masks:	ds 64			; pf_find: bits i..j of a sprite's byte at 8i + j
span_tmp:	ds 32			; span_line: the edge's runs
	align 256
snd_tables:	ds 256			; the sound (sound.asm): POKEY's 5-bit counter at the ticks,
					; its 4-bit one at +$40, a bit's mask at +$80 (sound_init),
					; the volume x 0-3 at +$90 (pk_channel)
snd_mod15:	ds 256			; (AUDF + 1) mod 15, mod 31
snd_mod31:	ds 256
pk_kh:		ds 1
pk_dma:		ds 2			; where the DMA was
snd_off:	ds 1			; CAPS + 2: the sound off,
snd_clear:	ds 1			; the ring to be made quiet,
snd_keys:	ds 1			; the keys last frame
pk_left:	ds 1
pk_must:	ds 2
pokey_audf:	ds 4			; what the sound driver wrote: AUDF1-4,
pokey_audc:	ds 4			; AUDC1-4
snd_ch:		ds 4 * CH_SIZE		; the channels' state (pokey_frame)
snd_w:		ds 2			; the ring: where this frame's samples go,
snd_n:		ds 2			; how many
snd_s31:	ds 1			; a pulse's steps of the 5-bit and 4-bit counters
snd_s15:	ds 1
snd_ticks:	ds 2			; the frame's ticks (4 a sample)
snd_level:	ds 1			; the level at its start
pk_d:		ds 1
pk_k:		ds 1
ay_q:		ds 3 * 9		; the tones 2 frames ago, 1, now: period, volume x 3
ay_mask:	ds 1			; the POKEY channels on the AY (bits 0-3)
ay_skip:	ds 1			; (pokey_frame's copy)
ay_ch:		ds 1			; the POKEY channel in .one
	align 256
edge_lo:	ds 256			; a player's byte: its first dot (bit 7 dot 0; panel_init),
edge_hi:	ds 256			; its last dot + 1
dh_tank_edge:	ds 17			; display_hits.asm: the scanlines of each collision (a count,
dh_plane_bank:	ds 17			; the scanlines; one page),
dh_missile_bank: ds 17
dh_bullet_bank:	ds 17
dh_plane_shell:	ds 17
dh_missile_plane: ds 17
dh_desc:	ds 5 * DH_SIZE		; the sprites
dh_list:	ds 2
	align 256
rnd_tab:	ds 256			; random_step: the columns' XORs, 4 bits at a time
rnd_col16:	ds 3			; and bit 16's column
	assert $ < $FF00		; (the stack above)

; ------------------------------------------------------------------------------------------
	mmu 0 1,POLY_PAGE		; POKEY's 17-bit counter (sound.asm)
	org $0000
	incbin "poly17.bin"
	ifdef TEST
	savebin "build/test_poly.bin",$0000,$4000
	mmu 4,4
	savebin "build/test_page4.bin",$8000,$2000
	mmu 6,6
	savebin "build/test_page6.bin",$C000,$2000
	mmu 3,INIT_PAGE
	savebin "build/test_page7.bin",$6000,$2000
	else
	savenex open "build/river_raid.nex",entry,0
	savenex core 3,0,0
	savenex cfg 0
	savenex bank 2,3,7
	savenex close
	endif
