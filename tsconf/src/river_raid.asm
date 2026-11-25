; River Raid for TS-Conf. The attract mode, then the game with START, as the Next's game runs
; them (game.asm, play.asm, display.asm, river_gen.asm: the same code), shown the TS-Conf's
; way: the river in the 16-colour mode (320x240), a line of 256 bytes a row, scrolled by the
; hardware (GYOFFS); the bank's colour changed per line by the frame interrupt moved down the
; frame (PALSEL: a palette per colour; as the Next's Copper does it); the objects and players
; as sprites (sprites.asm); the panel a picture of its own below the river (panel_ts.asm);
; tile layer 0 black above the river and the panel's grey under it. The sound on a General
; Sound (sound_gs.asm, gs/), else its pure tones on the AYs (sound_ay.asm).
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
; Build: make (tsconf/Makefile): build/river_raid.spg (-DSPG), for Wild Commander: the program
; finds River_Raid.rom on the SD card itself (load_rom.asm); make sna: build/river_raid.sna, a
; 128K snapshot with the cartridge in (your ROM, ../rom/River_Raid.rom: -DROM_FILE); with
; -DTEST the pages for tscheck (build/ts_page2.bin, ts_page6.bin), which puts the cartridge
; at $A000 and starts the program at $8000.

	device zxspectrum128

	include "vars.inc"

	ifdef TEST			; the Atari's screen memory: the check compares it
	define SCREEN_MEMORY		; (-DNOSCREEN: the check's build without it, to measure)
	endif
	ifdef NOSCREEN
	undefine SCREEN_MEMORY
	endif

; T: the border's colour for the part of the frame that follows, while tm_show is on (A and the
; flags spent): a CRAM entry (BORDER), the needle's group's free ones from 2 (tm_cram; the
; Next's colours)
TM_IDLE		equ 0			; black: the work done, waiting for the next frame
TM_APPLY	equ 11 * 16 + 2		; orange: apply (the frame goes live)
TM_PREPARE	equ 11 * 16 + 3		; grey: prepare (and clear_layer2_page during a reset)
TM_DISPLAY	equ 11 * 16 + 4		; red: display (the objects' schedule, the collisions)
TM_SPRITES	equ 11 * 16 + 5		; yellow: build_sprites, build_events (the sprites, the
					; bank colour's events)
TM_LOGIC	equ 11 * 16 + 6		; blue: main_loop (the game logic)
TM_RIVER	equ 11 * 16 + 7		; magenta: push_line (a new river line, inside main_loop)
TM_VBI		equ 11 * 16 + 8		; white: vbi
TM_SOUND	equ 11 * 16 + 9		; cyan: snd_frame (the sound)
TM_PANEL	equ 11 * 16 + 10	; green: panel_draw (the panel's characters, after apply)
	macro TM_COLOUR c
	ld a,(tm_show)			; (off: no call, the frame's time as without it)
	or a
	jr z,.tm_off
	ld a,c
	call tm_colour			; (game.asm)
.tm_off
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
BORDER		equ $0FAF
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
GXOFFSL		equ $02AF
GXOFFSH		equ $03AF
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
INIT_PAGE	equ 3			; the start's work (sprite_pics.asm), at $0000 while it runs
TGFX_PAGE	equ TGFX_PAGE_		; (T0GPAGE: a multiple of 8)
VID_PAGE	equ 32			; (VPAGE: a multiple of 16) 16 pages, 512 lines
L2_PAGES	equ 2			; the picture cleared in two halves (DMA, clear_layer2_page)
RIVER_LINES	equ 160
RIVER_TOP	equ 24			; the screen's row of the river's top line (of 240)
	assert RIVER_TOP % 8 == 0 && (RIVER_TOP + RIVER_LINES) % 8 == 0
; The frame INT's lines (VSINT): line 0 is the one after the last of the 288 the border
; frame has; the 240 rows start 56 lines on (32 to the border's top, 24 more to the rows).
; Each INT comes at the right border of the line before the one it is for (HSINT), so its
; colour is there before that line's dots.
INT_X		equ 208			; HSINT: 416 dots from the line's blanking (x 384 + 32)
ROW_LINE	equ 56 - 1		; VSINT for screen row r: ROW_LINE + r
EV_GAP		equ 2			; irq.gap: at 3.5 MHz events this many lines apart taken together
FRAME_LINE	equ ROW_LINE + 241		; the frame's work starts: below the panel (9 bits)
EV_PAL		equ 0			; the INT's events: the river's palette (0-7: its bank
					; colour) from the next line,
EV_PANEL	equ 1			; the panel's picture from its row (VPAGE, GYOFFS, GFXOVR),
EV_GX		equ 2			; GXOFFS,
EV_END		equ $FF			; the frame's INT after them
					; the river
SGPAGE_REG	equ $19AF
CRAM_SHADOW	equ $E000		; the FM window's 512 bytes of CRAM, then the SFILE's 512
SFILE_SHADOW	equ CRAM_SHADOW + $200	; (the writes go on to
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
	ld bc,PAGE0			; the start's work at $0000 (the Atari's RAM after it)
	ld a,INIT_PAGE
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
	call screen_black		; nothing shown while the start works
	ifdef SPG
	call load_rom			; the cartridge from the SD card
	endif
	call init_tables
	call init_video
	call obj_pics			; the sprites' pictures
	call pl_pics
	call panel_pics
	call gs_load			; the General Sound's program, if there is one
	ld bc,PAGE0
	ld a,ATARI_PAGE
	out (c),a
	call panel_init			; the panel: its character sets, colours
	call ay_quiet
	ld hl,(rnd_init)
	ld (rnd_state),hl
	ld a,(rnd_init + 2)
	ld (rnd_state + 2),a
	ld a,(tv_init)
	ld (tv_pal),a
	xor a
	ld (tm_show),a
	ld (tm_keys),a
	call tm_cram
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
	xor a
	ld (l2_wait),a
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
	ld (ap_list),hl
	ld hl,FRAME_LINE
	call vsint_set
	ei
	call wait_frame			; the CPU's speed: a loop's turns in a frame (35 ticks each:
	xor a				; ~8 200 at 14 MHz, ~4 100 at 7, ~2 000 at 3.5); at 3.5 MHz
	ld (frame_flag),a		; the INT takes more than a line, so events up to EV_GAP lines
	ld hl,0				; apart are taken together (irq.gap)
1:	inc hl
	ld a,(frame_flag)
	or a
	jr z,1B
	ld de,-3000
	add hl,de
	jr c,2F
	ld a,$C3			; 3.5 MHz: JP .gap
	ld (irq.cmp),a
	ld hl,irq.gap
	ld (irq.cmp + 1),hl
2:
	call start_attract		; frame 0: the attract mode starts, its first line
	call panel_frame		; its panel, all of it drawn before the first frame
	call panel_draw
main_frame:
	ld hl,(scroll)			; the screen as this frame's display sees it
	ld (show_scroll),hl
	ld a,(colour_edge)
	ld (show_edge),a
	ld a,(colour_water)
	ld (show_water),a
	ld a,(PLAYER)
	ld (show_player),a
	ifndef TEST
	call read_input
	endif
	ld a,(busy)
	or a
	jr nz,.busy
	TM_COLOUR TM_PREPARE
	call prepare
	TM_COLOUR TM_DISPLAY
	call display
	TM_COLOUR TM_SPRITES
	call build_sprites
	call build_events
	TM_COLOUR TM_LOGIC
	call main_loop
	TM_COLOUR TM_VBI
	call vbi
	TM_COLOUR TM_SOUND
	call snd_frame			; the sound (sound_gs.asm, sound_ay.asm)
	jr .done
.busy	dec a				; sub $B0F1 is clearing memory: the main loop is stuck,
	ld (busy),a			; only the interrupts run
	cp 1
	jr nz,.b
	ld (SCREEN_ON),a		; colours back on
.b	TM_COLOUR TM_DISPLAY
	call display
	TM_COLOUR TM_SPRITES
	call build_sprites
	call build_events
	TM_COLOUR TM_PREPARE
	call clear_layer2_page
	TM_COLOUR TM_LOGIC
	ld a,(busy)
	or a
	call z,finish_reset
	TM_COLOUR TM_VBI
	call vbi
	TM_COLOUR TM_SOUND
	call snd_frame
.done	TM_COLOUR TM_IDLE		; T: the work done (the border shows the parts in their
frame_done:				; colours: TM_*)
	call wait_frame
	TM_COLOUR TM_APPLY
	call apply
apply_done:
	TM_COLOUR TM_PANEL
	call panel_draw			; the panel's characters (after the INT's events are set:
panel_done:				; it may take a while)
	jp main_frame

; The next frame INT below the river (frame_flag, irq): one that came during the work (a late
; frame) is too late for apply (the picture's top already shown), so the one after it, as the
; Next's wait for its line
wait_frame:
	xor a
	ld (frame_flag),a
1:	ld a,(frame_flag)		; (a loop, not HALT: an INT between the test and a HALT
	or a				; would be waited past, to the next one; nor DI around them:
	jr z,1B				; the INT is a pulse of 32 ticks, lost under DI)
	ret

; The frame INT and the events of the frame (ev_ptr): each its kind, its data (2 bytes), its
; VSINT line (2): EV_PAL the river's palette from the next row, EV_PANEL the panel's picture from it
; (VPANEL, its line 0, the bitmap over the tiles and sprites), EV_GX GXOFFS; EV_END: the
; frame's INT (FRAME_LINE). Events on the same line are taken together.
irq:
	push af
	push hl
	ld hl,(ev_ptr)
	ld a,(hl)
	inc hl
	or a
	jr nz,.other
	push bc				; EV_PAL: the river's palette from the next line (PALSEL,
	ld bc,PALSEL			; latched)
	ld a,(hl)
	out (c),a
	inc hl
	jr .next3
.other	push bc
	inc a
	jp z,.frame
	dec a
	dec a
	jr nz,.gx
	ld bc,VPAGE			; EV_PANEL
	ld a,VPANEL
	out (c),a
	ld bc,GYOFFSL
	xor a
	out (c),a
	inc b
	out (c),a
	ld bc,VCONFIG
	ld a,$8A
	out (c),a
	inc hl
	jr .next3
.gx	ld bc,GXOFFSL			; EV_GX
	ld a,(hl)
	out (c),a
	inc hl
	inc b
	ld a,(hl)
	out (c),a
.next3	inc hl				; (past its line)
	inc hl
	inc hl
	ld (ev_ptr),hl
	ld a,(hl)			; the next event's line, or the frame's
	cp EV_END
	jr z,.last
	inc hl
	inc hl
	inc hl
.cmp	ld a,(ev_line)			; (3.5 MHz: JP .gap here, from the start's test)
	cp (hl)
	jr nz,1F
	inc hl
	ld a,(ev_line + 1)
	cp (hl)
	jr nz,2F
.now	pop bc				; (the same line: now)
	pop hl
	pop af
	jp irq
2:	dec hl
1:	ld a,(hl)
	inc hl
	ld h,(hl)
	ld l,a
	jr 3F
.gap	ld a,(ev_line)			; 3.5 MHz: the INT takes more than a line, so the next
	ld c,a				; event up to EV_GAP lines on (or before: taken late) is
	ld a,(hl)			; taken now (its INT would come while this one runs, and be
	sub c				; lost: a pulse of 32 ticks), ev_line on by EV_GAP (the
	ld c,a				; time it takes)
	inc hl
	ld a,(ev_line + 1)
	ld b,a
	ld a,(hl)
	sbc a,b
	jr z,1F
	inc a
	jr z,4F
	jr 2F
1:	ld a,EV_GAP
	cp c
	jr c,2F
4:	ld hl,(ev_line)
	ld bc,EV_GAP
	add hl,bc
	ld (ev_line),hl
	jr .now
2:	ld b,(hl)
	dec hl
	ld l,(hl)
	ld h,b
	jr 3F
.last	ld hl,FRAME_LINE
3:	call vsint_set
	pop bc
	pop hl
	pop af
	ei
	ret
.frame	ld a,1				; EV_END: the frame (wait_frame); the picture's registers and
	ld (frame_flag),a		; the events as apply left them, again from the top: a frame
	push de				; late (its apply not yet done) shows the last one again, as
	ld hl,(ap_scroll)		; the Next's copper (else the panel's picture from the top,
	call river_regs			; the bank's colours not changed)
	ld bc,PALSEL
	ld a,(ap_pal)
	out (c),a
	ld hl,(ap_list)
	call ev_go
	pop de
	pop bc
	pop hl
	pop af
	ei
	ret

; The river's picture from the top (apply; again at a late frame's INT): GYOFFS HL, its pages,
; 16 colours, no X offset
river_regs:
	ld bc,GYOFFSL
	out (c),l
	inc b
	out (c),h
	ld bc,VPAGE
	ld a,VID_PAGE
	out (c),a
	ld bc,VCONFIG
	ld a,$81
	out (c),a
	ld bc,GXOFFSL
	xor a
	out (c),a
	inc b
	out (c),a
	ret

; The events from list HL: ev_ptr, the INT at the first one's line (or the frame's)
ev_go:
	ld (ev_ptr),hl
	ld a,(hl)
	cp EV_END
	inc hl
	inc hl
	inc hl
	ld e,(hl)
	inc hl
	ld d,(hl)
	ex de,hl
	jr nz,vsint_set
	ld hl,FRAME_LINE

; The frame INT at line HL (9 bits): VSINT, ev_line
vsint_set:
	ld (ev_line),hl
	ld bc,VSINTL
	out (c),l
	inc b
	ld a,h
	and 1
	out (c),a
	ret

; At the frame's start (below the river): the scroll, the playfield's colours, the bank's
; changes for the frame to come; all black while the picture is being cleared (from the
; reset's second frame)
apply:
	ld hl,(show_scroll)		; the river's picture again from the top, the panel's (its
	ld (ap_scroll),hl		; INT's) after it
	call river_regs
	call snd_out			; the frame's sound: the AY's tones or the General Sound's
	call panel_frame
	ld hl,(pf_gx)			; the panel's events: its picture, the scrolling line's X
	ld (ev_panel + 6),hl
	ld a,(shell_colour)		; the shell's colour (and the helicopter missile's); CRAM
					; and the SFILE: the FM window, always on
	ld l,a
	ld h,high palette_lo
	ld a,(hl)
	ld (CRAM_SHADOW + 2 * (SHELL_PAL * 16 + 1)),a
	inc h
	ld a,(hl)
	ld (CRAM_SHADOW + 2 * (SHELL_PAL * 16 + 1) + 1),a
	ld a,(show_player)		; the plane's: COLPM2 (B542)
	or a
	ld l,$1E
	jr z,1F
	ld l,$8E
1:	dec h
	ld a,(hl)
	ld (CRAM_SHADOW + 2 * (PLANE_PAL * 16 + 1)),a
	inc h
	ld a,(hl)
	ld (CRAM_SHADOW + 2 * (PLANE_PAL * 16 + 1) + 1),a
	call sfile_put			; the sprites
	ld a,(l2_wait)
	or a
	jr nz,.shown
	ld a,(l2_clear)
	or a
	jr z,.shown
	ld e,0				; black: the bank (palette of colour 0), the edge and the
	call pal_get			; water, no changes: the panel's events only
	ld bc,PALSEL
	out (c),a
	ld (ap_pal),a
	ld de,0
	call pal_edges
	ld hl,ev_panel
	jr .events
.shown	ld hl,(ev_built)		; the palette at the top
	ld a,(hl)
	ld bc,PALSEL
	out (c),a
	ld (ap_pal),a
	ld a,(show_water)		; the edge and the water this frame
	ld d,a
	ld a,(show_edge)
	ld e,a
	call pal_edges
	ld hl,ev_panel			; the panel's events after the bank's changes
	ld de,(ev_tail)
	ld bc,EV_PANEL_SIZE
	ldir
	ld hl,(ev_built)
	inc hl
	inc hl
.events	di
	ld (ap_list),hl
	call ev_go
	ei
	ld hl,(ev_built)		; the other buffer for the next list
	ld (ev_show),hl
	ret

; The river's palettes (16 colours, PALSEL 0-7): one for each colour the bank has had, its
; colour 1 that colour, set once (pal_get); 2 and 3 the edge and the water, set in all of them
; each frame (pal_edges). A the palette of Atari colour E (a new one: the next; past 8 of them,
; the last again: never so far)
pal_get:
	ld h,high pal_of
	ld l,e
	ld a,(hl)
	or a
	jr z,1F
	dec a
	ret
1:	ld a,(pal_n)
	cp 8
	jr c,2F
	ld a,7
	ret
2:	inc a
	ld (pal_n),a
	ld (hl),a
	dec a
	push af
	add a,a				; its colour 1: CRAM_SHADOW + 32 A + 2
	add a,a
	add a,a
	add a,a
	add a,a
	add a,2
	ld l,a
	ld h,high CRAM_SHADOW
	ld d,high palette_lo
	ld a,(de)
	ld (hl),a
	inc l
	inc d
	ld a,(de)
	ld (hl),a
	pop af
	ret

; Colours 2 and 3 of the palettes made so far: Atari colours E (the edge) and D (the water)
pal_edges:
	ld a,(pal_n)
	or a
	ret z
	ld b,a
	ld hl,CRAM_SHADOW + 4
	ld c,d
1:	ld d,high palette_lo
	ld a,(de)
	ld (hl),a
	inc l
	inc d
	ld a,(de)
	ld (hl),a
	inc l
	push de
	ld e,c
	dec d
	ld a,(de)
	ld (hl),a
	inc l
	inc d
	ld a,(de)
	ld (hl),a
	pop de
	ld a,l				; the next palette: 32 bytes on
	add a,32 - 3
	ld l,a
	djnz 1B
	ret

; The SFILE: the river's sprites (S0), the end of S0 and of S1 (an entry with LEAP each), the
; entries after them up to last frame's end cleared: made in spr_list, then copied by the DMA
; (by the CPU through the FM window while the DMA is busy: a reset's clearing)
sfile_put:
	ld a,(sb_count)			; DE: past the river's entries (6 each)
	ld l,a
	ld h,0
	add hl,hl
	ld e,l
	ld d,h
	add hl,hl
	add hl,de
	ld de,spr_list
	add hl,de
	ex de,hl
	ld hl,sf_tail			; S0's end, S1 (the panel's sprites), its end
	ld bc,sf_tail_end - sf_tail
	ldir
	ld hl,(sf_end)			; this frame's end; last frame's entries after it cleared
	ld (sf_end),de
	or a
	sbc hl,de
	jr c,.put
	jr z,.put
	ld b,h
	ld c,l
	ex de,hl
.clr	ld (hl),0
	inc hl
	dec bc
	ld a,b
	or c
	jr nz,.clr
	ex de,hl
.put	ex de,hl			; HL: the end of what is copied
	ld de,spr_list
	or a
	sbc hl,de
	push hl
	ld bc,DMACTRL
	in a,(c)
	rla
	jr c,.cpu
	ld bc,DMASADDRX			; from spr_list
	ld a,HIGH_PAGE
	out (c),a
	dec b
	ld a,high (spr_list - $C000)
	out (c),a
	dec b
	ld a,low spr_list
	out (c),a
	ld bc,DMADADDRX			; to the SFILE's start
	xor a
	out (c),a
	dec b
	out (c),a
	dec b
	out (c),a
	pop hl
	srl h				; the words (one burst: at most (SPRITES_MAX + 5) x 3)
	rr l
	dec l
	ld a,l
	ld bc,DMALEN
	out (c),a
	ld bc,DMANUM
	xor a
	out (c),a
	ld bc,DMACTRL			; RAM to the SFILE
	ld a,$85
	out (c),a
	ret
.cpu	pop bc
	ld hl,spr_list
	ld de,SFILE_SHADOW
	ldir
	ret
	assert (SPRITES_MAX + 5) * SPR_SIZE / 2 <= 256 && (spr_list & 1) == 0

; The bank's colour by line (as the Next's build_copper: from ds_bank_ev): at ev_built the
; palette at the river's top, then the changes (EV_PAL events: the palette of the colour, the
; colour; apply puts the panel's events after them, ev_tail). A change is made a line before
; it, the palette (PALSEL) latched for the next line.
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
	ld b,a
	push de
	push hl
	ld e,a
	call pal_get
	pop hl
	pop de
	ld (ix + 0),a			; (its palette, and the colour for the check)
	ld (ix + 1),b
	inc ix
	inc ix
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
	ld (ix + 0),EV_PAL
	ld (ix + 2),a			; (its colour, for the check)
	push de
	push hl
	ld e,a
	call pal_get
	pop hl
	pop de
	ld (ix + 1),a			; its palette
	ld a,e
	add a,ROW_LINE - 1 + RIVER_TOP - RIVER_FIRST
	ld (ix + 3),a
	ld (ix + 4),0
	ld a,c
	ld bc,5
	add ix,bc
	ld b,a
	ld c,a
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
.end	ld (ev_tail),ix			; (apply puts the panel's events there)
	ld (ix + 0),EV_END
	ret

; The DMA's work done
dma_wait:
	ld bc,DMACTRL
.w	in a,(c)
	rla
	jr c,.w
	ret

; Half of the picture cleared (256 lines of 160 bytes), while there are any left and the DMA is free
; (frames of the reset)
clear_layer2_page:
	ld hl,l2_wait			; (none in the reset's first frame: its picture is still
	ld a,(hl)			; being shown)
	or a
	jr z,1F
	ld (hl),0
	ret
1:	ld a,(l2_clear)
	or a
	ret z
	ld bc,DMACTRL
	in a,(c)
	rla
	ret c
	ld a,(l2_clear)
	dec a
	ld (l2_clear),a
	add a,a				; 4 pages a half
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
	ld bc,DMALEN			; 80 words a line,
	ld a,79
	out (c),a
	ld bc,DMANUM			; 256 lines,
	ld a,255
	out (c),a
	ld bc,DMACTRL			; each from a 256-byte line's start: fill
	ld a,$14
	out (c),a
	ret

init_tables:
	call edge_runs_init		; (spans.asm)
	call dh_init			; (display_hits.asm)
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
	and 3				; (both nibbles: the 16-colour mode's two dots)
	ld d,a
	rlca
	rlca
	rlca
	rlca
	or d
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

; The screen black at once, whatever mode it was left in (Wild Commander's, the ZX screen in
; page 5, which the start writes its buffers into): CRAM all black (every mode's colours,
; the border's too) through the FM window, no sprites or tiles
screen_black:
	ld bc,TSCONFIG
	xor a
	out (c),a
	ld bc,BORDER
	out (c),a
	ld bc,FMADDR
	ld a,$10 | high CRAM_SHADOW >> 4
	out (c),a
	ld hl,CRAM_SHADOW
	ld de,CRAM_SHADOW + 1
	ld bc,$3FF
	ld (hl),0
	ldir
	ret

; The picture: 256 colours, 320x240, from VID_PAGE; tile layer 0 the black above the river
; and the panel's grey and black below it (panel_ts.asm); the frame INT; the colours
init_video:
	ld bc,VPAGE
	ld a,VID_PAGE
	out (c),a
	ld bc,VCONFIG			; 16 colours, 320x240
	ld a,$81
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
	ld hl,$4000			; the map's rows (256 bytes: layer 0's 64 entries first):
	ld de,.map			; their tiles (tile 1 black, 2 the panel's grey, 3 a black
	ld b,30				; line then grey; colours $3E, $3F), 0 none
.row	ld a,(de)
	inc de
	or a
	jr z,.next
	push bc
	push hl
	ld b,40
.tile	ld (hl),a
	inc l
	ld (hl),$30
	inc l
	djnz .tile
	pop hl
	pop bc
.next	inc h
	djnz .row
	ld bc,PAGE1			; the tiles' dots (4 bytes a line, 256 bytes a line of the
	ld a,TGFX_PAGE			; page): tile N at 4 N
	out (c),a
	ld hl,$4000 + 4
	ld b,8
.gfx	ld a,$EE			; tile 1: colour 14
	call .four
	ld a,$FF			; tile 2: colour 15
	call .four
	ld a,b				; tile 3: line 0 colour 14, the others 15
	cp 8
	ld a,$EE
	jr z,1F
	ld a,$FF
1:	call .four
	ld l,4
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
	ld bc,SGPAGE_REG		; the sprites' pictures: SGPAGE's 128K cleared (DMA fill)
	ld a,SGPAGE
	out (c),a
	ld bc,DMADADDRX
	out (c),a
	xor a
	dec b
	out (c),a
	dec b
	out (c),a
	ld bc,DMASADDRX
	ld a,HIGH_PAGE
	out (c),a
	dec b
	ld a,high (dma_zero - $C000)
	out (c),a
	dec b
	ld a,low dma_zero
	out (c),a
	ld bc,DMALEN			; 256 words a burst, 256 of them
	ld a,255
	out (c),a
	ld bc,DMANUM
	out (c),a
	ld bc,DMACTRL
	ld a,$04
	out (c),a
	call dma_wait
	ld bc,TSCONFIG			; tile layer 0 and the sprites on
	ld a,$A0
	out (c),a
	ld bc,FMADDR			; the FM window at CRAM_SHADOW, on for good (nothing writes
	ld a,$10 | high CRAM_SHADOW >> 4	; to $E400-$E4FF, its registers: palette_lo there)
	out (c),a
	ld hl,CRAM_SHADOW		; CRAM black, and the SFILE: no sprite
	ld de,CRAM_SHADOW + 1
	ld bc,$3FF
	ld (hl),0
	ldir
	ld hl,pal_of			; no river palette yet
	ld de,pal_of + 1
	ld bc,255
	ld (hl),0
	ldir
	xor a
	ld (pal_n),a
	ld a,TANK_PAL			; the tank's colour: black
	ld b,1
	ld e,0
	call cram_set
	ld hl,spr_list
	ld (sf_end),hl
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
.four	ld (hl),a			; a tile's line: 4 bytes of A
	inc l
	ld (hl),a
	inc l
	ld (hl),a
	inc l
	ld (hl),a
	inc l
	ret
.map	db 1, 1, 1			; rows 0-23: black above the river
	ds 20				; the river
	db 3, 2, 2, 2, 2		; 184 black, 185-223 grey
	db 1, 1				; 224-239 black

	include "river_gen.asm"
	include "play.asm"
	include "sound.asm"
	include "sound_ay.asm"
	include "sound_gs.asm"
	include "panel.asm"
random_columns:
	include "random.inc"

	display "page $8000 end: ",$
	assert $ <= $A000		; the cartridge from there

	mmu 3,HIGH_PAGE
	org $C000
	include "game.asm"
	include "display.asm"
	include "spans.asm"
	include "display_hits.asm"
	include "sprites.asm"
	include "panel_ts.asm"
	include "render.asm"		; (render.asm, display_objs.asm: from page $8000, room there)
	include "display_objs.asm"

	display "page $C000 end: ",$
	assert $ <= $E000

; ------------------------------------------------------------------------------------------
; Buffers and variables ($E000)
	org CRAM_SHADOW
	ds 1024
	align 256
palette_lo:				; Atari colour -> CRAM word: low bytes, then high
	include "palette_ts.inc"
	ifdef SCREEN_MEMORY		; the generated line's bytes (48; the drawing wraps at 256),
line_buf:	ds 256			; for screen memory only
	endif
pix_tab:	ds 4 * 256		; render_line: pixel k (bits 7-6 first) of a line byte
span_class:	ds 256			; span_line: a byte's colour if its pixels are one, $FF if not
span_masks:	ds 64			; pf_find: bits i..j of a sprite's byte at 8i + j
span_tmp:	ds 32			; span_line: the edge's runs
	assert high span_tmp == high (span_tmp + 31)
dl_seg:		ds 4 * 19		; draw_line: the line's pieces in order (byte, kind, data 2)
	assert high dl_seg == high (dl_seg + 4 * 19 - 1)
rnd_col16:	ds 3			; random_step's bit 16's column
EV_PANEL_SIZE	equ 11
ev_a:		ds 2 + 5 * 48 + EV_PANEL_SIZE	; the bank's colour by line (build_events): two
ev_b:		ds 2 + 5 * 48 + EV_PANEL_SIZE	; buffers
ev_none:	db EV_END
ev_panel:	db EV_PANEL			; the panel's events (kind, data, VSINT line): its
		dw 0, ROW_LINE + PANEL_ROW - 1	; picture from its row (latched: a line before),
		db EV_GX			; the scrolling line's X
		dw 0, ROW_LINE + PANEL_ROW + SCROLL_LINE - 1
		db EV_END
ev_tail:	ds 2			; build_events: where its list ends
pal_n:		ds 1			; the river's palettes made (pal_get)
ev_line:	ds 2			; the INT's line now
pf_gx:		ds 2			; panel_frame: the scrolling line's X (GXOFFS)
pf_ring:	ds 1			; its text's first character in the ring
pf_pal:		ds 1			; .spr's palette (x 16)
pc_glyph:	ds 2			; pc_draw: the glyph's next row,
pc_colour:	ds 1			; its colour,
pc_x:		ds 2			; its dot,
pc_line:	ds 1			; its next line
pc_src:		ds 1			; pc_put: the source's address, its low byte
pp_needle:	ds 1			; the needle's picture, the logo's
pp_logo3:	ds 1
pp_logo2:	ds 1
sf_tail:	db 0, $40, 0, 0, 0, 0	; sfile_put: S0's end (LEAP),
spr_s1:		ds 3 * SPR_SIZE		; the needle and the logo (S1),
		db 0, $40, 0, 0, 0, 0	; its end
sf_tail_end:
ev_ptr:		ds 2			; the INT's next event
ap_list:	ds 2			; apply's: the events, the top's palette and scroll (the frame
ap_pal:		ds 1			; INT puts them again: a late frame)
ap_scroll:	ds 2
ev_show:	ds 2			; the list the frame shown reads
ev_built:	ds 2			; the one made this frame
frame_flag:	ds 1			; the frame INT came
rl_count:	ds 1			; render_line: an edge's bytes left
rl_page:	ds 1			; the picture's page of its line
	align 2
rl_word:	ds 2			; a run's value (twice) for the DMA's fill
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
l2_wait:	ds 1			; the reset's first frame: the clearing waits a frame
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
tm_show:	ds 1			; T: the frame's work shown on the border
tm_keys:	ds 1			; T last frame
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
ds_l2:		ds 1			; display: past the object's last line (dh_obj; 255 past the end)
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
	align 256
pal_of:		ds 256			; pal_get: the palette of each Atari colour + 1 (0 none yet)
; the sprites (sprites.asm)
	align 256
obj_head:	ds 256			; obj_lookup: by the shape byte's address, its first entry + 1
obj_e:		ds 3 * OBJ_ENTRIES	; the entries: colour byte's address, picture (+ palette),
					; the next with the same shape byte + 1
	align 256
pic_h:		ds PIC_MAX		; per picture: its YS (bits 3-1),
	align 256
pic_tn16_lo:	ds PIC_MAX		; its first tile at 16 dots across,
	align 256
pic_tn16_hi:	ds PIC_MAX
	align 256
pic_tn32_lo:	ds PIC_MAX		; 32,
	align 256
pic_tn32_hi:	ds PIC_MAX
	align 256
pic_tn64_lo:	ds PIC_MAX		; 64
	align 256
pic_tn64_hi:	ds PIC_MAX
spr_list:	ds SPR_SIZE * (SPRITES_MAX + 5)	; the SFILE as apply puts it: the river's entries,
					; then sf_tail
sf_end:		ds 2			; its end last frame
ob_line:	ds 1			; ob_attr: the sprite's first line,
ob_pat:		ds 1			; its picture,
ob_palv:	ds 1			; its palette,
ob_x:		ds 1
ob_size:	ds 1
op_t:		ds 1			; obj_pics (at the start): the type,
op_k:		ds 1			; the kind,
op_s:		ds 1			; the top row's shape byte (low; $B9xx),
op_c:		ds 1			; its colour (low; $B7xx),
op_left:	ds 1			; the rows left,
op_rows:	ds 1
op_sp:		ds 2			; the next row's shape byte,
op_cp:		ds 2			; and colour,
op_p:		ds 1			; the next picture,
op_bank:	ds 1			; the palette (0 A, 1 B),
op_reach:	ds 16			; the kinds the type can have,
op_bankn:	ds 2			; the colours in each palette,
op_bankc:	ds 32			; and which (place 1-15 in each 16)
obj_count:	ds 1			; obj_lookup's entries
op_tab:		ds 2			; pl_pics: the shapes' pointers,
op_out:		ds 2			; the pictures' table,
op_buf:		ds 8			; rows of a missile
gfx_cx:		ds 2			; gfx_alloc: where the next picture goes,
gfx_cy:		ds 2
gfx_rh:		ds 1			; the lines' height so far,
gfx_x:		ds 2			; the picture's place
gfx_y:		ds 2
gfx_once:	ds 1			; gfx_row: one width only
pl_plane:	ds 10			; the plane's frames' pictures ($FF none)
pl_tank:	ds 8			; the tank's
pl_shell:	ds 7			; the shell's
pl_bullet:	ds 1			; the bullet's
pl_missile:	ds 1			; the helicopter missile's
pl_first:	ds 1			; build_sprites: the players' first sprite,
pl_kept:	ds 1			; how many, last frame,
pl_attrs:	ds SPR_SIZE * 5		; and their entries
pokey_audf:	ds 4			; what the sound driver wrote: AUDF1-4,
pokey_audc:	ds 4			; AUDC1-4
ay_regs:	ds AYR			; ay_frame: the AY's registers for apply
ay_ch:		ds 1			; the POKEY channel in .one
gs_on:		ds 1			; the General Sound plays it all (gs_load)
	ifdef SPG			; load_rom: the card, the volume, the walk
lr_lfn_buf	equ pix_tab		; (a long name: filled at the start, after it)
lr_part:	ds 4			; the volume's first sector,
lr_fat:		ds 4			; its FAT's,
lr_data:	ds 4			; its clusters' (cluster 2),
lr_root:	ds 4			; the root's cluster (FAT16: 0),
lr_rootlba:	ds 4			; FAT16: the root's area, its sectors
lr_rootsec:	ds 2
lr_spc:		ds 1			; sectors a cluster
lr_fat32:	ds 1
lr_hc:		ds 1			; the card takes block addresses
lr_dst:		ds 2
lr_fclus:	ds 4			; the file found: its first cluster, its size
lr_fsize:	ds 4
lr_depth:	ds 1
lr_lfn_ok:	ds 1			; a long name in lr_lfn_buf for the next entry
lr_loaded:	ds 1			; the walk's sector in the buffer
lr_state:				; the walk: the folder's first cluster,
lr_first:	ds 4
lr_cur:		ds 4			; the cluster, the sector, the sectors left in it,
lr_sec:		ds 4
lr_left:	ds 2
lr_off:		ds 2			; the entry's place in the sector,
lr_mode:	ds 1			; the files (0) or the folders (1),
lr_end:		ds 1			; the folder's end
LR_STATE	equ $ - lr_state
lr_saved:	ds LR_STATE * LR_DEPTH	; the walks put aside, by depth
	endif
	display "buffers end: ",$
	assert $ <= int_vectors - 64	; (the stack below the vectors)
STACK_TOP	equ int_vectors - 2
	org $FE00
int_vectors:	ds $FF
		dw irq			; the frame INT's ($FF)

; ------------------------------------------------------------------------------------------
; The start's work (INIT_PAGE at $0000 while it runs)
	mmu 0,INIT_PAGE
	org $0000
	include "sprite_pics.asm"
	include "gs_load.asm"
	ifdef SPG
	include "load_rom.asm"
	endif
	display "init page end: ",$
	assert $ <= $4000
init_end:

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
bg_e1:		ds 256			; per span record (line), its two widest gaps between runs
bg_s2:		ds 256			; of bank pixels (dh_pf; spans.asm)
bg_e3:		ds 256
bg_s4:		ds 256
line_start:	ds 256			; per scanline: ANTIC's cycles at its start
line_after_draw: ds 256			; and the cycles left after it is drawn
edge_lo:	ds 256			; a player's byte: its first dot (bit 7 dot 0),
edge_hi:	ds 256			; its last dot + 1
rnd_tab:	ds 256			; random_step: the columns' XORs, 4 bits at a time
	display "work page end: ",$
	assert $ <= $7D00
	org $7D00			; the OS font, for panel_init (at the start)
	include "font.inc"
	assert $ <= $8000

	mmu 2,CODE_PAGE
	ifdef TEST
	savebin "build/ts_page2.bin",$8000,$4000
	mmu 3,HIGH_PAGE
	savebin "build/ts_page6.bin",$C000,$4000
	mmu 1,WORK_PAGE
	savebin "build/ts_page5.bin",$7C00,$400
	mmu 0,INIT_PAGE
	savebin "build/ts_page3.bin",$0000,$4000
	else
	ifdef SPG			; the pages for tools/mkspg.py: $8000-$9FFF, $C000-$FFFF,
					; $7C00-$7FFF (the font)
	savebin "build/spg_page2.bin",$8000,$2000
	mmu 3,HIGH_PAGE
	savebin "build/spg_page6.bin",$C000,$4000
	mmu 1,WORK_PAGE
	savebin "build/spg_page5.bin",$7C00,$400
	mmu 0,INIT_PAGE
	savebin "build/spg_page3.bin",$0000,(init_end + 511) & $FE00
	else
	org $A000			; the cartridge
	incbin ROM_FILE,0,$2000
	mmu 1,WORK_PAGE
	mmu 3,HIGH_PAGE			; (the snapshot's $C000: 7FFD)
	savesna "build/river_raid.sna",start
	endif
	endif
