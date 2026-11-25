; The river part of the display without the DLI's cycles: river_raid/port/src/display.cpp
; (Game::displaySimple, docs/DLI_REMOVAL.md in the C++ port). The DLI's loop (B565-B664) is
; followed by scanlines: X (ds_counter) goes up by one at every STA WSYNC, so the scanline
; drawn while X = c is c - 69 (one more for each scanline the DLI fell behind: ds_slip).
; Which rows each object shows, where each collision read and HITCLR comes, follow from that
; (a schedule, no scanlines gone over): the objects are drawn from their rows (ds_objs,
; build_sprites), the collisions come from the sprites' rows (display_hits.asm).
; What it leaves: the objects' rows (ds_objs), the bank colour by river line (scan_bank), the
; collisions (HIT, the slots' edge flags).

DS_OBJS		equ 16			; the objects' rows kept for the sprites (ds_objs)

display:
				; (TS-Conf: window 1 holds SPANS)		; the lines' runs of bank and edge (pf_under)
	call dh_lists			; the other sprites' rows, and their collisions
	ld hl,hpos_p			; registers cleared, then as B527-B55C set them
	ld b,regs_end - hpos_p
	xor a
.regs	ld (hl),a
	inc hl
	djnz .regs
	inc a
	ld (size_m),a			; missile 0 double width (A116)
	ld a,(FUEL)
	srl a
	srl a
	srl a
	add a,$5C
	ld (hpos_m + 1),a
	ld a,(PLANE_X)
	ld (hpos_p + 2),a
	add a,4
	ld (hpos_m + 2),a
	ld a,(TANK_X)
	ld (hpos_p + 1),a
	ld a,(MISSILE_X)
	ld (hpos_m),a
	ld a,(SHELL_X)
	ld (hpos_p),a
	call bm_hitclr
	xor a
	ld (ds_slip),a
	ld (ds_bank_n),a
	ld (ds_obj_n),a
	ld (ds_obj_over),a
	dec a
	ld (ds_obj_slot),a
	call dh_sprites			; HIT: the other sprites' collisions (bank, each other)
	ld a,(FIRST_SLOT)
	ld (ds_slot),a

	; Each object at its own slot's y: its rows from X = max(y, $5D) + 3 (the scanline
	; X - 69), row height[type] - (start - y) first (the shapes are kept bottom up), as many
	; as come before X wraps (the river's end). Checked against the DLI's loop it replaces:
	; that never fell behind an object (the C++ port's displayGeometry).
.slot	ld a,(ds_slot)
	cp SLOTS
	jp nc,.end
	ld (ds_current),a
	ld e,a				; IY: the slot's fields where the game keeps them: kind, type
	ld d,0				; (+11), X (+22), size (+33) (no copies)
	ld iy,SLOT_KIND
	add iy,de
	ld hl,SLOT_Y			; (Y and the flags, read several times: kept)
	add hl,de
	ld a,(hl)
	ld (ds_y),a
	ld hl,SLOT_FLAGS
	add hl,de
	ld a,(hl)
	ld (ds_flags),a
	ld a,(iy + 0)			; tested against the edge: kinds 8-$0D ($FF, or 0)
	sub 8
	cp 6
	sbc a,a
	ld (ds_edge_kind),a
	ld a,(ds_y)			; the start
	cp $5D
	jr nc,1F
	ld a,$5D
1:	ld (ds_start),a
	ld b,a
	ld a,(iy + 11)			; the first row (by its type)
	add a,low ROM_OBJECT_HEIGHT
	ld l,a
	adc a,high ROM_OBJECT_HEIGHT
	sub l
	ld h,a
	ld a,(ds_y)
	add a,(hl)
	sub b
	ld (ds_row),a
	cp $80
	jp nc,.next			; (gone above)
	ld a,b				; its X: past 255, none from here on
	add a,3
	jp c,.end
	ld (ds_counter),a
	neg				; the rows: before X wraps
	ld b,a
	ld a,(ds_row)
	inc a
	cp b
	jr c,1F
	ld a,b
1:	ld (ds_rows),a
	ld ixl,a
	ld a,(ds_flags)			; DE: the first row's byte (the shape: mirrored frames + 16)
	and $08
	add a,a
	add a,(iy + 0)
	add a,low ROM_SHAPE_OFFSET	; (the ROM's tables by 8-bit sums: ROM_SHAPES and
	ld l,a				; ROM_COLOURS start pages)
	adc a,high ROM_SHAPE_OFFSET
	sub l
	ld h,a
	ld a,(ds_row)
	ld c,a
	add a,(hl)
	ld l,a
	ld a,high ROM_SHAPES
	adc a,0
	ld h,a
	ld (ds_rowp),hl
	ld a,(iy + 11)			; BC: its colour's (ds_obj)
	add a,low ROM_COLOURS_OFFSET
	ld l,a
	adc a,high ROM_COLOURS_OFFSET
	sub l
	ld h,a
	ld a,c
	add a,(hl)
	ld c,a
	ld a,high ROM_COLOURS
	adc a,0
	ld b,a
	ld de,(ds_rowp)
	assert low ROM_SHAPES == 0 && low ROM_COLOURS == 0
	call ds_obj			; (for the sprites: ds_objs)
	ifdef BEAM			; a bridge: the road's colours by row, the bank's back after
	ld a,(ds_flags)			; (the cycle model's scan_bank only: the bank's colour
	and $80				; goes by line, line_bank)
	call nz,.road
	endif
	ld a,(ds_edge_kind)		; P3PF: the edge, only for the kinds that turn at it
	or a
	call nz,ds_edge_test
	call ds_set_flags
	ld a,(ds_counter)		; the object's lines, for the three (dh_obj): its first,
	sub $44
	ld (ds_l1),a
	ld hl,ds_rows			; past its last (255: past the end)
	add a,(hl)
	jr nc,1F
	ld a,255
1:	ld (ds_l2),a
	ld ix,dh_desc + DH_BULLET	; the bullet, the shell (not a bridge) and the plane against
	call dh_obj			; its rows
	jr z,1F
	ld a,(ds_current)
	ld (HIT_BULLET_OBJECT),a
1:	ld a,(ds_flags)
	and $80
	jr nz,1F
	ld ix,dh_desc + DH_SHELL
	call dh_obj
	jr z,1F
	ld a,(ds_current)
	ld (HIT_SHELL_OBJECT),a
1:	ld ix,dh_desc + DH_PLANE
	call dh_obj
	jr z,.next
	ld a,(ds_current)
	ld (HIT_PLANE_OBJECT),a
.next	ld a,(ds_current)
	inc a
	ld (ds_slot),a
	jp .slot
.end
	ifdef TEST
	call test_ghost
	endif
	ifdef BEAM			; (scan_bank: only the beam's display reads it; the Copper's
	jp ds_bank_fill			; list is made from ds_bank_ev, build_copper)
	else
	ret
	endif

	ifdef BEAM
.road					; a bridge's rows: the road's colour from the scanline after
	ld a,(ds_row)			; each row's, then the section's bank colour after the last
	ld (ds_l1),a			; (unless X wrapped)
	ld a,(ds_counter)
	sub 69 - 1
	ld c,a
	ld a,(ds_rows)
	ld b,a
	ld d,$FF			; (D: the colour set last: a row's the same, no change)
.rd	push bc
	ld hl,ds_l1
	ld a,(hl)
	dec (hl)
	add a,low ROM_ROAD_COLOURS
	ld l,a
	ld a,high ROM_ROAD_COLOURS
	adc a,0
	ld h,a
	ld e,(hl)
	ld a,e
	cp d
	jr z,1F
	ld d,a
	ld a,c
	call ds_bank
1:	pop bc
	inc c
	djnz .rd
	ld a,(ds_counter)
	ld hl,ds_rows
	add a,(hl)
	ret c
	sub 69 - 1
	ld c,a
	ld a,(SECTION_BANK_COLOUR)
	ld e,a
	ld a,c
	jp ds_bank
	endif

; The object's rows against the edge (P3PF): A = $02 if a row's span (its first dot to its
; last) meets a run of edge pixels on its line, else 0 (the C++ port's edgeTouches). Its rows from ds_rowp (going down in memory), the first on the scanline of X =
; ds_counter, ds_rows of them; none past clock 255.
ds_edge_test:
	ld a,(iy + 22)
	ld (.ex1 + 1),a
	ld (.ex2 + 1),a
	ld (.bx1 + 1),a
	ld (.bx2 + 1),a
	ld b,a
	ld a,(iy + 33)			; its width: 8, 16 or 32 clocks (sizes 0 and 2, 1, 3)
	and 3
	ld c,32
	cp 3
	jr z,1F
	ld c,16
	dec a
	jr z,1F
	ld c,8
1:	ld a,b
	add a,c
	ld (.be1 + 1),a
	ld (.be2 + 1),a
	jp c,.none
	jp z,.none
	ld a,(iy + 33)			; their dots' clocks: 1, 2 or 4 a dot (sizes 0 and 2, 1, 3)
	and 3
	ld hl,0				; (NOP NOP)
	rra				; (bit 0: at least double)
	jr nc,2F
	ld l,$87			; (ADD A,A)
	or a				; (and bit 1: quadruple)
	jr z,2F
	ld h,$87
2:	ld (.s1),hl
	ld (.s2),hl
	ld de,(ds_rowp)			; DE: the row, C: its line's span record (the objects' rows
	ld a,(ds_counter)		; are all on the river's lines, the next line's the next)
	sub $44 + RIVER_FIRST
	ld hl,span_top
	add a,(hl)
	ld c,a
	ld a,(ds_rows)
	ld ixl,a
.row	ld l,c				; first the object's box (X to X + its width) against the
	ld h,high eg_e1			; line's water gaps (eg_*): inside one, no edge pixel near
.bx1	ld a,0
	cp (hl)
	jr c,.g2
	inc h
	ld a,(hl)
.be1	cp 0
	jr nc,.row_on
.g2	ld h,high eg_e3
.bx2	ld a,0
	cp (hl)
	jr c,.look
	inc h
	ld a,(hl)
.be2	cp 0
	jr nc,.row_on
.look	ld a,(de)			; else the row's dots against the line's runs
	or a
	jr z,.row_on
	push bc
	ld a,c
	span_rec
	ld a,l
	add a,(hl)
	ld l,a
	ld a,(de)			; the row's first and last dots (edge_lo, edge_hi), the
	push hl				; clocks from X
	ld l,a
	ld h,high edge_lo
	ld a,(hl)
.s1	nop
	nop
.ex1	add a,0
	ld c,a
	inc h
	ld a,(hl)
.s2	nop
	nop
.ex2	add a,0
	ld b,a				; (B: past the last dot)
	pop hl
.run2	ld a,(hl)			; a run past the row's last dot: none touched
	cp b
	jr nc,.off
	inc l
	ld a,c				; one that ends before its first dot: the next
	cp (hl)
	inc l
	jr nc,.run2
	pop bc				; one between: touched (the row's first and last dots decide,
	ld a,$02			; as the C++ port's edgeTouches: no dot by dot)
	ret
.off	pop bc
.row_on	dec de
	inc c
	dec ixl
	jp nz,.row
.none	xor a
	ret

; P3PF (A) as the object's: only the kinds that turn at the edge are tested (moveObjects
; reads the bit for helicopters, balloons and ships only)
ds_edge_only:
	push hl
	ld hl,ds_edge_kind
	and (hl)
	pop hl
	ret

; The current object's edge bit (A: $02 set) into its slot's flags (bit 0)
ds_set_flags:
	ld b,a
	ld a,(ds_current)
	cp SLOTS
	ret nc
	ld e,a
	ld d,0
	ld hl,SLOT_FLAGS
	add hl,de
	ld a,b
	or a
	ld a,(hl)
	res 0,a
	jr z,1F
	set 0,a
1:	ld (hl),a
	ret

	ifdef BEAM
; The bank colour E from scanline A on (a bridge's road, and back; the cycle model's scan_bank)
ds_bank:
	push hl
	ld l,a
	ld a,(ds_bank_n)
	cp DS_BANKS
	jr nc,.full
	inc a
	ld (ds_bank_n),a
	dec a
	add a,a
	push de
	ld e,a
	ld d,0
	ld a,l
	ld hl,ds_bank_ev
	add hl,de
	pop de
	ld (hl),a
	inc hl
	ld (hl),e
.full	pop hl
	ret

; The bank colour of every scanline of the river into scan_bank: the VBI's, then as the DLI
; changed it
ds_bank_fill:
	ld hl,ds_bank_ev
	ld a,(ds_bank_n)
	ld b,a
	ld a,(colour_bank)
	ld c,a
	ld a,b				; one colour all the way, as last frame: nothing to do
	or a
	jr nz,1F
	ld a,(ds_bank_last)
	cp c
	ret z
1:	ld a,b
	or a
	ld a,c
	jr z,2F
	ld a,$FF			; (none odd: next frame fills again)
2:	ld (ds_bank_last),a
	ld de,scan_bank + RIVER_FIRST
.seg	ld a,b				; the next change (none: the river's end)
	or a
	ld a,RIVER_FIRST + RIVER_LINES
	jr z,1F
	ld a,(hl)
	cp RIVER_FIRST + RIVER_LINES
	jr c,1F
	ld a,RIVER_FIRST + RIVER_LINES
1:	sub e
	jr c,.set
	jr z,.set
	push bc
	ld b,a
	ld a,c
.fill	ld (de),a
	inc e
	djnz .fill
	pop bc
.set	ld a,b
	or a
	ret z
	inc hl
	ld c,(hl)
	inc hl
	dec b
	jr .seg
	endif
