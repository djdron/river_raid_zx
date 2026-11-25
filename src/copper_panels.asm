; The Copper's part for the panel and the scrolling line, either standard's (sprites.asm:
; copper_panel): in page 7, which tv_setup puts at $4000 while it copies one.

copper_panel_ntsc:
	db $80 | COPPER_WAIT_H * 2, 200 - 32 - 1
	db $31, 0			; the tilemap at the panel's first row (tv_setup: CP_PANEL_Y)
	db $43, $10			; Layer 2's colours 0-10 (the index going up)
	db $40, 0
	rept CP_COLOURS			; black
	db $41, 0
	endr
	db $1C, 2			; the sprites' window below the river: from the line after
	db $19, 0, $19, 159		; the lowest an object's rows reach (OBJ_LAST: ob_list shows
	db $19, OBJ_LAST + 1, $19, 255	; no 16-row piece below the river), the needle and the logo
	db $80 | COPPER_WAIT_H * 2, 201 - 32 - 1
cpn_grey:
	db $40, 0
	rept CP_COLOURS			; grey (tv_setup: COPPER_GREY)
	db $41, 0
	endr
	db $80 | COPPER_WAIT_H * 2, 211 - 32 - 1
	db $31, 176 - 211
	db $80 | COPPER_WAIT_H * 2, 229 + 1 - 32 - 1
cpn_rest:
	db $40, 0			; the river's colours back after the grey (so a late frame,
	rept CP_COLOURS			; whose apply comes after the next frame's top, still
	db $41, 0			; shows them): 0 black, 1 and 4-10 the bank's (build_copper:
	endr				; CP_RESTORE), 2 the edge, 3 the water (apply: CP_EDGE_BACK)
	db $80 | COPPER_WAIT_H * 2, 231 - 32 - 1
	db $31, 208 - 231
	db $2F, 0			; (set by panel_frame: CP_XSCROLL_HI_BACK,
	db $30, 0			; CP_XSCROLL_BACK)
	db $80 | COPPER_WAIT_H * 2, WAIT_LINE_NTSC + 32 - 32 - 1
	db $1C, 2			; the sprites' window the river's again, for the next frame
	db $19, 0, $19, 159		; (below the logo, where apply starts)
	db $19, RIVER_TOP, $19, RIVER_TOP + RIVER_LINES - 1
copper_panel_ntsc_end:
	assert cpn_grey + 3 - copper_panel_ntsc == COPPER_GREY
	assert cpn_rest - copper_panel_ntsc == CP_RESTORE
	assert copper_panel_ntsc_end + 2 - (cpn_rest + 7) == CP_EDGE_BACK
; PAL (status_bar.cpp's layout): the panel's rows at 206, 218, 226, its grey to 239 (Layer 2's
; clip window), the scrolling line at 243. The same layout: the offsets below hold for both.
COPPER_GREY	equ 2 * CP_COLOURS + 23	; the grey's bytes in either, 2 apart
CP_PANEL_Y	equ 3			; the tilemap's Y scroll for the panel's first row
CP_RESTORE	equ 4 * CP_COLOURS + 28	; the restored colours' $40 (their bytes 2 apart after it)
CP_EDGE_BACK	equ 2 * CP_COLOURS + 17	; the restored edge colour's byte from the list's end (the
CP_XSCROLL_BACK	equ 15			; water's 2 after it); the scrolling line's X scroll (low,
CP_XSCROLL_HI_BACK equ 17		; high 2 before)
PF_PATTERN	equ 20			; the scrolling line's sprite: its pattern (4-bit),
PF_OFFSET	equ 6			; palette offset
OBJ_LAST	equ RIVER_TOP + RIVER_LINES - 1 + 15	; the lowest line an object's rows reach
					; (a 16-row piece from the river's last line at the lowest)
NEEDLE_Y_NTSC	equ $CC - RIVER_FIRST + RIVER_TOP	; the needle's first line (10 lines)
NEEDLE_Y_PAL	equ $D3 - RIVER_FIRST + RIVER_TOP
	assert NEEDLE_Y_NTSC > OBJ_LAST		; (no object's rows reach the needle)
copper_panel_pal:
	db $80 | COPPER_WAIT_H * 2, 200 - 32 - 1
	db $31, 0			; the tilemap at the panel's first row (tv_setup: CP_PANEL_Y)
	db $43, $10			; Layer 2's colours 0-10 (the index going up)
	db $40, 0
	rept CP_COLOURS			; black
	db $41, 0
	endr
	db $1C, 2			; the sprites' window below the river: from the line after
	db $19, 0, $19, 159		; the lowest an object's rows reach (OBJ_LAST: ob_list shows
	db $19, OBJ_LAST + 1, $19, 255	; no 16-row piece below the river), the needle and the logo
	db $80 | COPPER_WAIT_H * 2, 201 - 32 - 1
	db $40, 0
	rept CP_COLOURS			; grey (tv_setup: COPPER_GREY)
	db $41, 0
	endr
	db $80 | COPPER_WAIT_H * 2, 218 - 32 - 1
	db $31, 176 - 218
	db $80 | COPPER_WAIT_H * 2, 239 + 1 - 32 - 1
	db $40, 0			; the river's colours back after the grey (so a late frame,
	rept CP_COLOURS			; whose apply comes after the next frame's top, still
	db $41, 0			; shows them): 0 black, 1 and 4-10 the bank's (build_copper:
	endr				; CP_RESTORE), 2 the edge, 3 the water (apply: CP_EDGE_BACK)
	db $80 | COPPER_WAIT_H * 2, 243 - 32 - 1
	db $31, 208 - 243
	db $2F, 0			; (set by panel_frame: CP_XSCROLL_HI_BACK,
	db $30, 0			; CP_XSCROLL_BACK)
	db $80 | COPPER_WAIT_H * 2, WAIT_LINE_PAL + 32 - 32 - 1
	db $1C, 2			; the sprites' window the river's again, for the next frame
	db $19, 0, $19, 159		; (below the logo, where apply starts)
	db $19, RIVER_TOP, $19, RIVER_TOP + RIVER_LINES - 1
