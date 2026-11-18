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
	nextreg $52,SPAN_PAGE		; the lines' runs of bank and edge (pf_under)
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
	call ds_fields
	ld a,(ds_y)			; the start
	cp $5D
	jr nc,1F
	ld a,$5D
1:	ld (ds_start),a
	ld b,a
	ld a,(ds_type)			; the first row
	ld l,a
	ld h,0
	ld de,ROM_OBJECT_HEIGHT
	add hl,de
	ld a,(ds_y)
	add a,(hl)
	sub b
	ld (ds_row),a
	cp $80
	jr nc,.next			; (gone above)
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
	ld hl,(ds_shapes)		; DE: the first row's byte, IY: its colour (ds_obj)
	call ds_row_hl
	ex de,hl
	ld hl,(ds_colours)
	call ds_row_hl
	push hl
	pop iy
	ld (ds_rowp),de
	call ds_obj			; (for the sprites: ds_objs)
	ld a,(ds_flags)			; a bridge: the road's colours by row, the bank's back after
	and $80
	call nz,.road
	ld a,(ds_edge_kind)		; P3PF: the edge, only for the kinds that turn at it
	or a
	call nz,ds_edge_test
	call ds_set_flags
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
	jp ds_bank_fill

.road					; a bridge's rows: the road's colour from the scanline after
	ld a,(ds_row)			; each row's, then the section's bank colour after the last
	ld (ds_l1),a			; (unless X wrapped)
	ld a,(ds_counter)
	sub 69 - 1
	ld c,a
	ld a,(ds_rows)
	ld b,a
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
	ld a,c
	call ds_bank
	pop bc
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

; The object's rows against the edge (P3PF): A = $02 if any of its dots is on an edge pixel,
; else 0. Its rows from ds_rowp (going down in memory), the first on the scanline of X =
; ds_counter, ds_rows of them; none past clock 255.
ds_edge_test:
	ld a,(ds_x)
	ld (.pv_x + 1),a
	ld (.ex1 + 1),a
	ld (.ex2 + 1),a
	ld a,(ds_size)
	and 3				; the edge test's variant for its size (pf_size)
	cp 3
	ld de,pf_v4
	ld hl,pf_v4_bits + 1
	ld c,32
	jr z,1F
	dec a
	ld de,pf_v2
	ld hl,pf_v2_bits + 1
	ld c,16
	jr z,1F
	ld de,pf_v1
	ld hl,pf_v1_bits + 1
	ld c,8
1:	ld (.pv + 1),de
	ld (.pv_bits + 1),hl
	ld a,(ds_x)
	add a,c
	ld (.pv_end + 1),a
	jp c,.none
	jp z,.none
	ld a,(ds_size)			; their dots' clocks: 1, 2 or 4 a dot (sizes 0 and 2, 1, 3)
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
	ld de,(ds_rowp)			; DE: the row, L: its scanline
	ld a,(ds_counter)
	sub $44
	ld l,a
	ld a,(ds_rows)
	ld ixl,a
.row	ld a,(de)			; the row's first and last dots (edge_lo, edge_hi), the
	or a				; clocks from X
	jr z,.row_on
	push de
	push hl
	ld b,l
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
	ld h,b
	ld b,a				; (B: past the last dot)
	ld a,h				; (a river scanline)
	sub RIVER_FIRST
	cp RIVER_LINES
	jr nc,.row_off
	ld hl,span_top			; the scanline's runs of edge pixels (pf_line, pf_edge)
	add a,(hl)
	span_rec
	add a,(hl)
	ld l,a
.run	ld a,(hl)			; a run past the row's last dot: none touched (the runs go
	cp b				; left to right, $FF at the end)
	jr nc,.row_off
	inc l
	ld a,c				; one that ends before its first dot: the next
	cp (hl)
	inc l
	jr nc,.run
	dec l				; one between: the dots themselves (the rows have gaps)
	dec l
	ld a,(de)			; the row's bits into the size's variant (pf_v*)
.pv_bits
	ld (0),a
.pv_end	ld b,0				; the object's end and first clocks (pf_size)
.pv_x	ld c,0
	ld d,high span_masks
.pv	call 0
	jr z,.row_off
	pop hl
	pop de
	ld a,$02
	ret
.row_off
	pop hl
	pop de
.row_on	inc l
	dec de
	dec ixl
	jp nz,.row
.none	xor a
	ret

; The slot's fields (beyond the last one: zeros), its shapes' and colours' addresses
ds_fields:
	ld a,(ds_slot)
	cp SLOTS
	jr nc,.none
	ld e,a
	ld d,0
	ld hl,SLOT_Y
	add hl,de
	ld a,(hl)
	ld (ds_y),a
	ld hl,SLOT_X
	add hl,de
	ld a,(hl)
	ld (ds_x),a
	ld hl,SLOT_FLAGS
	add hl,de
	ld a,(hl)
	ld (ds_flags),a
	ld hl,SLOT_KIND
	add hl,de
	ld a,(hl)
	ld (ds_kind),a
	ld hl,SLOT_TYPE
	add hl,de
	ld a,(hl)
	ld (ds_type),a
	ld hl,SLOT_SIZE
	add hl,de
	ld a,(hl)
	ld (ds_size),a
	jr .addr
.none	xor a
	ld (ds_y),a
	ld (ds_x),a
	ld (ds_flags),a
	ld (ds_kind),a
	ld (ds_type),a
	ld (ds_size),a
.addr	ld a,(ds_kind)			; tested against the edge: kinds 8-$0D ($FF, or 0)
	sub 8
	cp 6
	sbc a,a
	ld (ds_edge_kind),a
	ld a,(ds_flags)			; the shape's address (mirrored frames + 16)
	and $08
	add a,a
	ld hl,ds_kind
	add a,(hl)
	ld l,a
	ld h,0
	ld de,ROM_SHAPE_OFFSET
	add hl,de
	ld a,(hl)
	ld hl,ROM_SHAPES
	add a,l
	ld l,a
	adc a,h
	sub l
	ld h,a
	ld (ds_shapes),hl
	ld a,(ds_type)			; the colours' address
	ld l,a
	ld h,0
	ld de,ROM_COLOURS_OFFSET
	add hl,de
	ld a,(hl)
	ld hl,ROM_COLOURS
	add a,l
	ld l,a
	adc a,h
	sub l
	ld h,a
	ld (ds_colours),hl
	ret

; P3PF (A) as the object's: only the kinds that turn at the edge are tested (moveObjects
; reads the bit for helicopters, balloons and ships only)
ds_edge_only:
	push hl
	ld hl,ds_edge_kind
	and (hl)
	pop hl
	ret

; HL += ds_row
ds_row_hl:
	ld a,(ds_row)
	add a,l
	ld l,a
	ret nc
	inc h
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

; The bank colour E from scanline A on (a bridge's road, and back)
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
