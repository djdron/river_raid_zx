; The bank's colour by line on the Next (page 6): each line's bank drawn in its colour's
; entry of Layer 2's palette (render.asm), as the C++ port's Game::lineBank; the Copper's
; list, which no longer changes it by line.

; The bank's colour of the line just generated (the C++ port's lineBankColour): the bridge's
; road colour by the row the line shows (road_row: set when the bridge is placed or put back,
; a line on with each line, scroll_objects), else the frame's (bank_colour); rl_set its set
; of tables (pix_sets). It changes only by a bridge: past one, the same set as the line before
line_bank:
	ld a,(road_row)
	cp $7F
	ret z
	cp $7E				; the first line past the road: the new green, then no more
	jr z,.past
	or a
	jp m,.green
	add a,low ROM_ROAD_COLOURS
	ld l,a
	ld a,high ROM_ROAD_COLOURS
	adc a,0
	ld h,a
	ld a,(hl)
	jr .entry
.green	call bank_colour
	jr .entry
.past	ld a,$7F
	ld (road_row),a
	call bank_colour
.entry	ld hl,rl_colour			; the same colour as the line before: the same set
	cp (hl)
	ret z
	ld (hl),a
	ld hl,bank_cols			; its place in bank_cols: its set (none: the first; bank_init
	ld bc,(bank_n - 1)		; has them all)
	ld c,0
.find	cp (hl)
	jr z,.found
	inc hl
	inc c
	djnz .find
	ld c,0
.found	ld a,c
	add a,a
	add a,a
	ld (rl_set),a
	ret

; Layer 2's bank entries: their colours (E = 1), or black (E = 0)
bank_set:
	nextreg $43,%00010000		; (Layer 2's first palette, the index going up)
	nextreg $40,1
	ld hl,bank_cols
	ld a,(hl)
	call .col
	nextreg $41,a
	nextreg $40,4
	ld a,(bank_n)
	dec a
	ret z
	ld b,a
1:	inc hl
	ld a,(hl)
	call .col
	nextreg $41,a
	djnz 1B
	ret
.col	push hl
	ld l,a
	ld h,high palette
	ld a,(hl)
	pop hl
	inc e
	dec e
	ret nz
	xor a
	ret

; The Copper's list: copper_start, then copper_panel, made again when the standard changed
; (tv_setup) or the colours went off or on (the bank's entries black while they are off, B101:
; the restored ones after the panel's grey too)
build_copper:
	ld a,(colour_bank)		; (0: the colours off)
	or a
	jr z,1F
	ld a,1
1:	ld hl,cp_bank_on
	cp (hl)
	jr nz,2F
	ld a,(cp_built)
	or a
	ret nz
	ld a,(hl)
2:	ld (hl),a
	ld e,a
	ld a,1
	ld (cp_built),a
	ld (cp_full),a
	ld ix,copper_panel + CP_RESTORE	; the bank's entries restored after the grey
	ld hl,bank_cols
	ld a,(hl)
	call bank_set.col
	ld (ix + 5),a			; (entry 1; 0, 2 and 3 apply's)
	ld a,(bank_n)
	dec a
	jr z,4F
	ld b,a
3:	inc hl
	ld a,(hl)
	call bank_set.col
	ld (ix + 11),a			; (4..)
	inc ix
	inc ix
	djnz 3B
4:	ld de,copper_list
	ld hl,copper_start
	ld bc,copper_start_end - copper_start
	ldir
	ld hl,copper_panel		; the panel and the scrolling line
	ld bc,copper_panel_end - copper_panel
	ldir
	ex de,hl
	ld (hl),$FF			; the end: a WAIT that never comes
	inc hl
	ld (hl),$FF
	inc hl
	ld de,copper_list
	or a
	sbc hl,de
	ld (copper_bytes),hl
	ret
