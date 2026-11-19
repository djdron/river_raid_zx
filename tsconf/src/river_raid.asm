; River Raid for TS-Conf: the viewer. The attract mode as the Next's game runs it (game.asm,
; play.asm, display.asm, river_gen.asm: the same code), shown the TS-Conf's way: the river in
; the 256-colour mode (320x240), a line of 512 bytes a row, scrolled by the hardware (GYOFFS);
; the bank's colour changed per line by the frame interrupt moved down the frame (as the
; Next's Copper does it); a tile layer black above and below the river. No sprites, panel or
; sound yet.
;
; Memory (16K windows, the board's pages):
;   $0000-$3FFF  the Atari's RAM (ATARI_PAGE)
;   $4000-$7FFF  the runs of the river's lines at $4000 (SPANS) and buffers at $6000
;                (WORK_PAGE); render_line puts a page of the picture here while it draws
;   $8000-$BFFF  the program at $8000, the cartridge at $A000 (CODE_PAGE)
;   $C000-$FFFF  the program at $C000, buffers and the stack at $E000 (HIGH_PAGE)
; The picture: pages VID_PAGE.. (512 lines of 512 bytes, 320 of each shown); the tile map
; (TMAP_PAGE) and the tile's dots (TGFX_PAGE).
;
; Build: make (tsconf/Makefile): build/river_raid.sna, a 128K snapshot with the cartridge in
; (your ROM, ../rom/River_Raid.rom: -DROM_FILE); with -DTEST the pages for tscheck
; (build/ts_page2.bin, ts_page6.bin), which puts the cartridge at $A000 and starts the program
; at $8000.

	device zxspectrum128

	include "vars.inc"

	ifdef TEST			; the Atari's screen memory: the check compares it
	define SCREEN_MEMORY		; (-DNOSCREEN: the check's build without it, to measure)
	endif
	ifdef NOSCREEN
	undefine SCREEN_MEMORY
	endif

; T: the work's parts (the Next shows them on the border; none here yet)
TM_APPLY	equ $F0
TM_PREPARE	equ $92
TM_DISPLAY	equ $E0
TM_SPRITES	equ $FC
TM_LOGIC	equ $03
TM_RIVER	equ $E7
TM_VBI		equ $FF
TM_SOUND	equ $1F
TM_IDLE		equ $00
	macro TM_COLOUR c
	ld a,c
	call tm_colour			; (game.asm; A, B and the flags spent)
	endm

; The board's ports
VCONFIG		equ $00AF
VPAGE		equ $01AF
GYOFFSL		equ $04AF
GYOFFSH		equ $05AF
TSCONFIG	equ $06AF
PALSEL		equ $07AF
PAGE0		equ $10AF
PAGE1		equ $11AF
PAGE2		equ $12AF
PAGE3		equ $13AF
FMADDR		equ $15AF
TMPAGE		equ $16AF
T0GPAGE		equ $17AF
DMASADDRL	equ $1AAF
DMASADDRH	equ $1BAF
DMASADDRX	equ $1CAF
DMADADDRL	equ $1DAF
DMADADDRH	equ $1EAF
DMADADDRX	equ $1FAF
SYSCONFIG	equ $20AF
MEMCONFIG	equ $21AF
HSINT		equ $22AF
VSINTL		equ $23AF
VSINTH		equ $24AF
DMALEN		equ $26AF
DMACTRL		equ $27AF
DMANUM		equ $28AF
INTMASK		equ $2AAF
T0XOFFSL	equ $40AF
T0XOFFSH	equ $41AF
T0YOFFSL	equ $42AF
T0YOFFSH	equ $43AF

ATARI_PAGE	equ 1			; (the program's pages: those a 128K snapshot maps at
WORK_PAGE	equ 5			; the start, WORK_PAGE, CODE_PAGE and HIGH_PAGE)
CODE_PAGE	equ 2
HIGH_PAGE	equ 6
TMAP_PAGE	equ 7
TGFX_PAGE_	equ 8
TGFX_PAGE	equ TGFX_PAGE_		; (T0GPAGE: a multiple of 8)
VID_PAGE	equ 32			; (VPAGE: a multiple of 16) 16 pages, 512 lines
L2_PAGES	equ 2			; the picture cleared in two halves (DMA, clear_layer2_page)
RIVER_LINES	equ 160
RIVER_TOP	equ 24			; the screen's row of the river's top line (of 240)
MASK_TOP	equ RIVER_TOP / 8	; the tile rows above the river,
MASK_BOTTOM	equ (RIVER_TOP + RIVER_LINES) / 8	; the first below it
	assert RIVER_TOP % 8 == 0 && (RIVER_TOP + RIVER_LINES) % 8 == 0
MASK_TILE	equ $3001		; tile 1, its colour (dots 1) $31: black
; The frame INT's lines (VSINT): line 0 is the one after the last of the 288 the border
; frame has; the 240 rows start 56 lines on (32 to the border's top, 24 more to the rows).
; Each INT comes at the right border of the line before the one it is for (HSINT), so its
; colour is there before that line's dots.
INT_X		equ 208			; HSINT: 416 dots from the line's blanking (x 384 + 32)
ROW_LINE	equ 56 - 1		; VSINT for screen row r: ROW_LINE + r
FRAME_LINE	equ ROW_LINE + RIVER_TOP + RIVER_LINES + 2	; the frame's work starts: below
					; the river
CRAM_SHADOW	equ $E000		; the FM window's 512 bytes of CRAM (the writes go on to
					; the memory under it too: a page of its own)
SPANS		equ $4000		; (WORK_PAGE) the river lines' runs of bank and edge
					; pixels, 32 bytes a line, a ring of 256 (spans.asm)

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

	mmu 2,CODE_PAGE
	org $8000
entry:	jp start
	dw line_done			; for the checks: where a river line is ready,
	dw frame_done			; where a frame has been worked out,
	dw apply_done			; and where it has gone live
rnd_init:
	db $01,$00,$00			; POKEY's counter at the first read (the checks set it)
in_stick:	db $0F,$0F		; the controls of the frame (the checks set them)
in_trig:	db 0
in_console:	db 0
in_key:		db 0
tv_init:	db 1			; 1 PAL (50 Hz): TS-Conf's frame
rnd_feed_on:	db 0			; test builds: RANDOM as the checks give it (random_read)
rnd_feed:	db 0
rnd_feed_reads:	db 0
	ifdef TEST
start_bridges_hi: db 0			; the starting bridge's hundreds and thousands, BCD
test_ghost_on:	db 0
ob_miss:	dw 0
test_ghost:
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
	di
	ld sp,STACK_TOP
	ld bc,SYSCONFIG			; 14 MHz, the cache on
	ld a,$06
	out (c),a
	ld bc,MEMCONFIG			; window 0: RAM, the page PAGE0 names, written
	ld a,$0E
	out (c),a
	ld bc,PAGE0
	ld a,ATARI_PAGE
	out (c),a
	inc b
	ld a,WORK_PAGE
	out (c),a
	inc b
	ld a,CODE_PAGE
	out (c),a
	inc b
	ld a,HIGH_PAGE
	out (c),a
	call init_tables
	call init_video
	ld hl,(rnd_init)
	ld (rnd_state),hl
	ld a,(rnd_init + 2)
	ld (rnd_state + 2),a
	ld a,(tv_init)
	ld (tv_pal),a
	xor a
	ld (tm_show),a
	ld a,high int_vectors		; IM 2: the frame INT's vector at int_vectors + $FF
	ld i,a
	im 2
; The machine switched on: everything from the start
restart:
	ld sp,STACK_TOP
	di
	call tv_setup
	ld a,L2_PAGES			; the picture black
	ld (l2_clear),a
.cl2	call clear_layer2_page
	ld a,(l2_clear)
	or a
	jr nz,.cl2
	call dma_wait
	ld hl,0
	ld (scroll),hl
	xor a
	ld (busy),a
	ld (resume),a
	ld (game_over_text),a
	ld (vbi_before),a
	ld (frame_flag),a
	ld hl,ev_none
	ld (ev_ptr),hl
	ld (ev_show),hl
	ld bc,VSINTL
	ld a,FRAME_LINE
	out (c),a
	ei
	call start_attract		; frame 0: the attract mode starts, its first line
main_frame:
	ld hl,(scroll)			; the screen as this frame's display sees it
	ld (show_scroll),hl
	ld a,(colour_edge)
	ld (show_edge),a
	ld a,(colour_water)
	ld (show_water),a
	ld a,(PLAYER)
	ld (show_player),a
	ld a,(busy)
	or a
	jr nz,.busy
	call prepare
	call display
	call build_events
	call main_loop
	call vbi
	jr .done
.busy	dec a				; sub $B0F1 is clearing memory: the main loop is stuck,
	ld (busy),a			; only the interrupts run
	cp 1
	jr nz,.b
	ld (SCREEN_ON),a		; colours back on
.b	call display
	call build_events
	call clear_layer2_page
	ld a,(busy)
	or a
	call z,finish_reset
	call vbi
.done
frame_done:
	call wait_frame
	call apply
apply_done:
	jp main_frame

; The frame INT below the river (frame_flag, irq)
wait_frame:
	ld a,(frame_flag)
	or a
	jr nz,.go
	halt
	jr wait_frame
.go	xor a
	ld (frame_flag),a
	ret

; The frame INT and the bank's colour changes: each event (ev_ptr) its VSINT line, then the
; CRAM word of colour 1; a line of 0 ends them (the frame INT, at FRAME_LINE).
irq:
	push af
	push bc
	push hl
	ld hl,(ev_ptr)
	ld a,(hl)
	or a
	jr z,.frame
	inc hl
	ld bc,FMADDR			; CRAM through the FM window
	ld a,$10 | high CRAM_SHADOW >> 4
	out (c),a
	ld a,(hl)
	ld (CRAM_SHADOW + 2),a
	inc hl
	ld a,(hl)
	ld (CRAM_SHADOW + 3),a
	xor a
	out (c),a
	inc hl
	ld (ev_ptr),hl
	ld a,(hl)			; the next event's line, or the frame's
	or a
	jr nz,1F
	ld a,FRAME_LINE
1:	ld bc,VSINTL
	out (c),a
	pop hl
	pop bc
	pop af
	ei
	ret
.frame	ld a,1
	ld (frame_flag),a
	pop hl
	pop bc
	pop af
	ei
	ret

; At the frame's start (below the river): the scroll, the playfield's colours, the bank's
; changes for the frame to come
apply:
	ld hl,(show_scroll)
	ld bc,GYOFFSL
	out (c),l
	inc b
	out (c),h
	ld bc,FMADDR
	ld a,$10 | high CRAM_SHADOW >> 4
	out (c),a
	ld h,high palette_lo
	ld a,(show_edge)
	ld l,a
	ld a,(hl)
	ld (CRAM_SHADOW + 4),a
	inc h
	ld a,(hl)
	ld (CRAM_SHADOW + 5),a
	ld a,(show_water)
	ld l,a
	dec h
	ld a,(hl)
	ld (CRAM_SHADOW + 6),a
	inc h
	ld a,(hl)
	ld (CRAM_SHADOW + 7),a
	ld hl,(ev_built)		; the bank's colour at the top, then its changes
	ld a,(hl)
	ld (CRAM_SHADOW + 2),a
	inc hl
	ld a,(hl)
	ld (CRAM_SHADOW + 3),a
	xor a
	out (c),a
	inc hl
	di
	ld (ev_ptr),hl
	ld a,(hl)
	or a
	jr nz,1F
	ld a,FRAME_LINE
1:	ld bc,VSINTL
	out (c),a
	ei
	ld hl,(ev_built)		; the other buffer for the next list
	ld (ev_show),hl
	ret

; The bank's colour by line (as the Next's build_copper: from ds_bank_ev): at ev_built the
; colour at the river's top (a CRAM word), then the changes (VSINT line, CRAM word), 0 after
build_events:
	ld hl,ev_a			; the buffer the INTs are not reading
	ld de,(ev_show)
	or a
	sbc hl,de
	ld hl,ev_a
	jr nz,1F
	ld hl,ev_b
1:	ld (ev_built),hl
	push hl
	pop ix
	ld a,(colour_bank)
	ld c,a				; C the colour from line E, B the one set
	call .word
	ld b,c
	ld e,RIVER_FIRST
	ld a,(ds_bank_n)
	ld d,a
	ld hl,ds_bank_ev
.seg	ld a,d				; the next change's line (none: the river's end)
	or a
	ld a,RIVER_FIRST + RIVER_LINES
	jr z,1F
	ld a,(hl)
	cp RIVER_FIRST + RIVER_LINES
	jr c,1F
	ld a,RIVER_FIRST + RIVER_LINES
1:	cp e
	jr c,.set
	jr z,.set
	push af
	ld a,c				; the colour on lines E to there
	cp b
	jr z,.same
	ld b,a
	ld a,e
	add a,ROW_LINE + RIVER_TOP - RIVER_FIRST
	ld (ix + 0),a
	inc ix
	call .word
.same	pop af
	ld e,a
.set	ld a,d
	or a
	jr z,.end
	inc hl
	ld c,(hl)
	inc hl
	dec d
	jr .seg
.end	ld (ix + 0),0
	ret
.word	push hl				; the CRAM word of colour C at IX, IX on
	ld h,high palette_lo
	ld l,c
	ld a,(hl)
	ld (ix + 0),a
	inc h
	ld a,(hl)
	ld (ix + 1),a
	inc ix
	inc ix
	pop hl
	ret

; The DMA's work done
dma_wait:
	ld bc,DMACTRL
.w	in a,(c)
	rla
	jr c,.w
	ret

; Half of the picture cleared (256 lines), while there are any left and the DMA is free
; (frames of the reset)
clear_layer2_page:
	ld a,(l2_clear)
	or a
	ret z
	ld bc,DMACTRL
	in a,(c)
	rla
	ret c
	ld a,(l2_clear)
	dec a
	ld (l2_clear),a
	add a,a				; 8 pages a half
	add a,a
	add a,a
	add a,VID_PAGE
	ld bc,DMADADDRX
	out (c),a
	xor a
	dec b				; DMADADDRH
	out (c),a
	dec b				; DMADADDRL
	out (c),a
	ld bc,DMASADDRX			; the word filled with: dma_zero
	ld a,HIGH_PAGE
	out (c),a
	dec b
	ld a,high (dma_zero - $C000)
	out (c),a
	dec b
	ld a,low dma_zero
	out (c),a
	ld bc,DMALEN			; 160 words a line,
	ld a,159
	out (c),a
	ld bc,DMANUM			; 256 lines,
	ld a,255
	out (c),a
	ld bc,DMACTRL			; each from a 512-byte line's start: fill
	ld a,$1C
	out (c),a
	ret

init_tables:
	call edge_runs_init		; (spans.asm)
	ld hl,ov_exp2			; dh_obj's: a byte's dots twice and 4 times as wide
.ov	ld a,l
	rrca
	rrca
	rrca
	rrca
	call .g16
	ld (hl),a			; (bits 7-4)
	inc h
	ld a,l
	call .g16
	ld (hl),a			; (bits 3-0)
	inc h
	ld b,4				; 4 times: a pair of bits a byte, from bits 7-6
	ld c,l
.ov4	ld a,c
	rlca
	rlca
	ld c,a
	and 3
	push hl
	ld e,a
	ld d,0
	ld hl,.f4
	add hl,de
	ld a,(hl)
	pop hl
	ld (hl),a
	inc h
	djnz .ov4
	ld h,high ov_exp2
	inc l
	jr nz,.ov
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
	ld l,0				; each byte's first and last dots (edge_lo, edge_hi; display)
.eb	ld b,l
	ld c,0				; C the dot (bit 7 first), D the first ($FF none yet), E the
	ld de,$FF00			; last + 1
.ebb	sla b
	jr nc,.ebn
	ld e,c
	inc e
	inc d
	jr z,.ebf
	dec d
	jr .ebn
.ebf	ld d,c
.ebn	inc c
	bit 3,c
	jr z,.ebb
	ld h,high edge_lo
	ld (hl),d
	inc h
	ld (hl),e
	inc l
	jr nz,.eb
	jp span_init
; A's bits 3-0 each twice (bit 3 first)
.g16	and $0F
	push hl
	ld e,a
	ld d,0
	ld hl,.t16
	add hl,de
	ld a,(hl)
	pop hl
	ret
.t16	db $00,$03,$0C,$0F,$30,$33,$3C,$3F,$C0,$C3,$CC,$CF,$F0,$F3,$FC,$FF
.f4	db $00,$0F,$F0,$FF

; The standard's settings: PAL only (TS-Conf's frame is 50 Hz)
tv_setup:
	call init_line_tables
	ld hl,random_columns_pal
	ld (rnd_cols),hl
	jp rnd_tables			; random_step's tables for the standard

; The picture: 256 colours, 320x240, from VID_PAGE; tile layer 0 the black above and below
; the river (tile 1 in the map's rows outside it); the frame INT; the colours
init_video:
	ld bc,VPAGE
	ld a,VID_PAGE
	out (c),a
	ld bc,VCONFIG			; 256 colours, 320x240
	ld a,$82
	out (c),a
	ld bc,PALSEL
	xor a
	out (c),a
	ld bc,PAGE1			; the tile map (window 1 for now)
	ld a,TMAP_PAGE
	out (c),a
	ld hl,$4000
	ld de,$4001
	ld bc,$3FFF
	ld (hl),0
	ldir
	ld hl,$4000			; the map's rows (256 bytes: layer 0's 64 entries first)
	ld b,30
	ld c,0
.row	ld a,c
	cp MASK_TOP
	jr c,.mask
	cp MASK_BOTTOM
	jr c,.next
.mask	push bc
	push hl
	ld b,40
.tile	ld (hl),low MASK_TILE
	inc l
	ld (hl),high MASK_TILE
	inc l
	djnz .tile
	pop hl
	pop bc
.next	inc h
	inc c
	djnz .row
	ld bc,PAGE1			; tile 1's dots: colour 1 (4 bytes a line, 256 bytes a line
	ld a,TGFX_PAGE			; of the page)
	out (c),a
	ld hl,$4000 + 4
	ld b,8
.gfx	ld (hl),$11
	inc l
	ld (hl),$11
	inc l
	ld (hl),$11
	inc l
	ld (hl),$11
	dec l
	dec l
	dec l
	inc h
	djnz .gfx
	ld bc,PAGE1
	ld a,WORK_PAGE
	out (c),a
	ld bc,TMPAGE
	ld a,TMAP_PAGE
	out (c),a
	ld bc,T0GPAGE
	ld a,TGFX_PAGE
	out (c),a
	xor a
	ld bc,T0XOFFSL
	out (c),a
	inc b
	out (c),a
	inc b
	out (c),a
	inc b
	out (c),a
	ld bc,TSCONFIG			; tile layer 0 on
	ld a,$20
	out (c),a
	ld bc,FMADDR			; CRAM black (and $31, the tile's)
	ld a,$10 | high CRAM_SHADOW >> 4
	out (c),a
	ld hl,CRAM_SHADOW
	ld de,CRAM_SHADOW + 1
	ld bc,$1FF
	ld (hl),0
	ldir
	ld bc,FMADDR
	xor a
	out (c),a
	ld bc,HSINT
	ld a,INT_X
	out (c),a
	ld bc,VSINTH
	xor a
	out (c),a
	ld bc,INTMASK			; the frame INT only
	ld a,1
	out (c),a
	ret

	include "river_gen.asm"
	include "render.asm"
	include "play.asm"
	include "sound.asm"
	include "display_objs.asm"

	display "page $8000 end: ",$
	assert $ <= $A000		; the cartridge from there

	mmu 3,HIGH_PAGE
	org $C000
	include "game.asm"
	include "display.asm"
	include "spans.asm"
	include "display_hits.asm"
	include "panel.asm"
random_columns:
	include "random.inc"

	display "page $C000 end: ",$
	assert $ <= $E000

; ------------------------------------------------------------------------------------------
; Buffers and variables ($E000)
	org CRAM_SHADOW
	ds 512
	align 256
palette_lo:				; Atari colour -> CRAM word: low bytes, then high
	include "palette_ts.inc"
	ifdef SCREEN_MEMORY		; the generated line's bytes (48; the drawing wraps at 256),
line_buf:	ds 256			; for screen memory only
	endif
pix_tab:	ds 4 * 256		; render_line: pixel k (bits 7-6 first) of a line byte
line_start:	ds 256			; per scanline: ANTIC's cycles at its start
line_after_draw: ds 256			; and the cycles left after it is drawn
span_class:	ds 256			; span_line: a byte's colour if its pixels are one, $FF if not
edge_lo:	ds 256			; a player's byte: its first dot (bit 7 dot 0),
edge_hi:	ds 256			; its last dot + 1
rnd_tab:	ds 256			; random_step: the columns' XORs, 4 bits at a time
bg_e1:		ds 256			; per span record (line), its two widest gaps between runs
bg_s2:		ds 256			; of bank pixels (dh_pf; spans.asm)
bg_e3:		ds 256
bg_s4:		ds 256
span_masks:	ds 64			; pf_find: bits i..j of a sprite's byte at 8i + j
span_tmp:	ds 32			; span_line: the edge's runs
	assert high span_tmp == high (span_tmp + 31)
dl_seg:		ds 4 * 19		; draw_line: the line's pieces in order (byte, kind, data 2)
	assert high dl_seg == high (dl_seg + 4 * 19 - 1)
rnd_col16:	ds 3			; random_step's bit 16's column
ev_a:		ds 2 + 3 * 48 + 1	; the bank's colour by line (build_events): two buffers
ev_b:		ds 2 + 3 * 48 + 1
ev_none:	db 0, 0, 0
ev_ptr:		ds 2			; the INT's next event
ev_show:	ds 2			; the list the frame shown reads
ev_built:	ds 2			; the one made this frame
frame_flag:	ds 1			; the frame INT came
rl_count:	ds 1			; render_line: an edge's bytes left
dma_zero:	dw 0			; clear_layer2_page's fill
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
scroll:		ds 2			; the picture's line at the screen's top (9 bits)
show_scroll:	ds 2
rnd_state:	ds 3
colour_bank:	ds 1			; the playfield's colours for the next frame (the VBI)
colour_edge:	ds 1
colour_water:	ds 1
show_edge:	ds 1			; and as this frame shows them
show_water:	ds 1
show_player:	ds 1
pf_dirty_n:	ds 1			; the panel's positions changed (panel_put; 60: all)
pf_dirty:	ds 60			; which
logo_shown:	ds 1			; the logo's position this frame (before the VBI moves it)
game_over_text:	ds 1			; A3B4: "Game over" scrolls past
busy:		ds 1			; frames of sub $B0F1 still to come
resume:		ds 1			; what the main loop does after them
l2_clear:	ds 1			; halves of the picture still to clear
rs_full:	ds 1
tv_pal:		ds 1			; 1 PAL
rnd_cols:	ds 2			; random_step's map for the standard
vbi_before:	ds 1			; PAL: the VBI sees the state before sub $B21A (vbi)
vbi_saved:	ds 3
logo_y:		ds 1
cs_sp:		ds 2
pb_leading:	ds 1
pb_cache:	ds 16			; print_bcd: per place, the digits' base and BCD bytes printed
sl_last:	ds 1			; show_lives: the symbols printed
fp_exploding:	ds 1
shell_colour:	ds 1
ms_right:	ds 1
tm_show:	ds 1
; the beam (display.asm)
bm_line:	ds 1
bm_drawn:	ds 1
bm_p:		ds 4
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
cs_present:	ds 1
cs_list:	ds 5 * 8
pu_pf:		ds 1
f_ls:		ds 1
ov_bits:	ds 1
ov_hpos:	ds 1
ov_wlog:	ds 1
	align 16
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
ds_cmask:	ds 2
ds_slow:	ds 1
dl_seg_p:	ds 2			; draw_line: the next of dl_seg
ds_ev_next:	ds 1
DS_BANKS	equ 48
ds_bank_n:	ds 1
ds_bank_ev:	ds 2 * DS_BANKS		; bank colour changes: scanline, colour
ds_ev_n:	ds 1
ds_ev_rd:	ds 1
ds_ev:		ds 3 * DS_EVENTS
ds_y:		ds 1
ds_flags:	ds 1
ds_row:		ds 1
ds_l1:		ds 1
ds_rowp:	ds 2
hit_ka:		ds 1
hit_sa:		ds 1
hit_kb:		ds 1
hit_sb:		ds 1
hit_w:		ds 1
hit_a:		ds 5
hit_b:		ds 5
	assert high hit_a == high (hit_b + 4)
ds_le:		ds 1
ds_bridge:	ds 1
ds_bullet:	ds 1
ds_hits:	ds 1
ds_edge:	ds 1
ds_obj_n:	ds 1
ds_obj_over:	ds 1
ds_obj_t:	ds 1
ds_objf:	ds DS_OBJS
ob_fptr:	ds 2
ds_obj_slot:	ds 1
ds_obj_last:	ds 2
ds_edge_kind:	ds 1
ds_edge_skip:	ds 1
sb_count:	ds 1
pm_empty:	ds 1			; a reset cleared player-missile memory, no prepare since
dh_desc:	ds 5 * DH_SIZE		; the sprites
pokey_audf:	ds 4			; what the sound driver wrote: AUDF1-4,
pokey_audc:	ds 4			; AUDC1-4
	display "buffers end: ",$
	assert $ <= int_vectors - 64	; (the stack below the vectors)
STACK_TOP	equ int_vectors - 2
	org $FE00
int_vectors:	ds $FF
		dw irq			; the frame INT's ($FF)

; ------------------------------------------------------------------------------------------
; The work page ($6000): buffers
	mmu 1,WORK_PAGE
	org $6000
scan_p3:	ds 256			; per river line, as the DLI left it: player 3's byte,
scan_x:		ds 256			; its position,
scan_size:	ds 256			; its size,
scan_col:	ds 256			; its colour,
scan_bank:	ds 256			; and the bank colour
edge_runs:	ds 256			; span_line: each edge piece's runs
ring_lo:	ds 256			; screen memory's 160 lines, in the order they follow
ring_hi:	ds 256
ds_objs:	ds 8 * DS_OBJS		; display: the objects' rows (display_simple.asm)
	align 256
ov_exp2:	ds 2 * 256		; dh_obj: a byte's dots doubled (2 bytes: pages), and
ov_exp4:	ds 4 * 256		; quadrupled (4)
eg_e1:		ds 256			; per span record (line), the water's gaps between its
eg_s2:		ds 256			; runs of edge pixels
eg_e3:		ds 256
eg_s4:		ds 256
	assert $ <= $8000

	mmu 2,CODE_PAGE
	ifdef TEST
	savebin "build/ts_page2.bin",$8000,$4000
	mmu 3,HIGH_PAGE
	savebin "build/ts_page6.bin",$C000,$4000
	else
	org $A000			; the cartridge
	incbin ROM_FILE,0,$2000
	mmu 1,WORK_PAGE
	mmu 3,HIGH_PAGE			; (the snapshot's $C000: 7FFD)
	savesna "build/river_raid.sna",start
	endif
