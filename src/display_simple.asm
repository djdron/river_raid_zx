; The river part of the display without the DLI's cycles: river_raid/port/src/display.cpp
; (Game::displaySimple, docs/DLI_REMOVAL.md in the C++ port). The DLI's loop (B565-B664) is
; followed by scanlines: X (ds_counter) goes up by one at every STA WSYNC, so the scanline
; drawn while X = c is c - 69 (one more for each scanline the DLI fell behind: ds_slip).
; Where each object's registers and rows land and which scanlines each collision read sees
; follow from that; the scanlines themselves are gone over in order as far as a read needs
; (ds_advance): the registers by scanline (scan_*), the collisions of the scanlines with
; anything on them (bm_draw, collide) into the collision registers.
; What it leaves is what the beam left: per river line the state of player 3 and the bank
; colour (scan_*), the rows of the objects in player 3's memory, the collisions (HIT, the
; slots' edge flags).

DS_OBJS		equ 16			; the objects' rows kept for the sprites (ds_objs)

; line(c) into A: c - 69 + slip (c in A)
ds_line	macro
	ld hl,ds_slip
	add a,(hl)
	sub 69
	endm

display:
	nextreg $52,SPAN_PAGE		; the lines' runs of bank and edge (pf_under)
	ld hl,PM_P3 + 24		; player 3's memory as the lines will fetch it (rows the DLI
	ld de,scan_p3 + 24		; writes in time change it)
	ld bc,192 - 24
	ldir
	call ds_lms			; the rows with a screen address: their start cycles
	call ds_cover_set
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
	ld hl,HIT			; B510
	ld b,9
	ld a,$FF
.hit	ld (hl),a
	inc hl
	djnz .hit
	xor a				; the scanlines' state from the top
	ld (ds_cur_x),a			; HPOSP3 (VBI, B411)
	ld (ds_cur_col),a
	ld (ds_slip),a
	ld (ds_ev_n),a
	ld (ds_ev_rd),a
	ld (ds_bank_n),a
	ld (ds_slow),a
	ld (ds_ended),a
	ld (ds_obj_n),a
	ld (ds_obj_over),a
	dec a
	ld (ds_obj_slot),a
	inc a
	ld a,(SLOT_SIZE + SLOTS - 1)
	ld (ds_cur_size),a
	ld a,23				; (the DLI starts on 23, past its draw)
	ld (ds_adv),a
	inc a
	ld (ds_cleared),a
	ld a,$FF
	ld (ds_end_line),a
	ld (ds_ev_next),a
	ld a,$5D
	ld (ds_counter),a
	ld a,(FIRST_SLOT)
	ld (ds_slot),a

.slot_loop
	ld a,(ds_slot)
	ld (ds_current),a
	call ds_slot_y			; B567: wait for the scanline where the slot's object starts
	ld b,a
	ld a,(ds_counter)
.wait	cp b
	jr nc,.there
	inc a
	jr nz,.wait
	ld (ds_counter),a
	jp .end
.there	ld (ds_counter),a
	ld (ds_start),a
	call ds_inx			; B575
	jp z,.end
	call ds_fields
	ld a,(ds_counter)		; HPOSP3 before this scanline's draw
	ds_line
	ld b,a
	ld a,(ds_x)
	call ds_event_x
	ld a,(ds_counter)		; blank rows above the object
	ld c,a
	ds_line
	ld b,a				; (both written on this scanline)
	ld a,c
	ld e,0
	call ds_write_p3
	ld a,c
	inc a
	call ds_write_p3
	call ds_inx			; B58D
	jp z,.end
	ld a,(ds_counter)		; SIZEP3 after this scanline's draw
	ds_line
	inc a
	ld b,a
	ld a,(ds_size)
	call ds_event_size
	ld a,(ds_type)			; the shape row on the next scanline
	ld l,a
	ld h,0
	ld de,ROM_OBJECT_HEIGHT
	add hl,de
	ld a,(ds_y)
	add a,(hl)
	ld hl,ds_start
	sub (hl)
	ld (ds_row),a
	call ds_inx			; B5B0
	jp z,.end
	ld a,(ds_row)
	cp $80
	jr c,.rows
	ld a,(ds_current)		; B5C9: the object has gone: the next slot
	inc a
	ld (ds_slot),a
	jp .slot_loop
.rows	ld hl,(ds_shapes)		; B5B0-B5D1: 49 cycles, 50 when the first row's byte is on
	ld a,(ds_row)			; the next page
	add a,l
	ld a,49
	adc a,0
	call ds_chunk
	; B5CB: a row a scanline, the bottom row first. DE: the shape's row, IY: its colour, HL:
	; player 3's memory (X - $44 = the scanline the row shows on, its low byte), C: the scanline
	; after the one it is written on (its colour from there), IXL: the rows to do before X
	; wraps
	ld hl,(ds_shapes)
	call ds_row_hl
	ex de,hl
	ld hl,(ds_colours)
	call ds_row_hl
	push hl
	pop iy
	ld a,(ds_counter)
	ld b,a
	ds_line
	inc a
	ld c,a
	ld a,b				; rows before X wraps: 256 - X
	neg
	ld b,a
	ld a,(ds_row)
	inc a
	cp b
	jr c,1F
	ld a,b
1:	ld ixl,a
	ld (ds_rows),a
	call ds_obj			; (for the sprites: build_sprites)
	ld a,(ds_counter)
	sub $44
	ld l,a
	ld h,high PM_P3
	ld b,high scan_col
	ld a,(ds_row)			; (a bridge: the road's colour of the row)
	ld (ds_l1),a
	ld a,(ds_slip)			; GTIA fetches the rows this frame if the DLI is not behind
	or a
	jp nz,.late_rows
	push bc
	ld a,(ds_x)			; (then HPOSP3 and SIZEP3 are this object's on its rows)
	ld (.row_x + 1),a
	ld (.pv_x + 1),a
	ld a,(ds_size)
	ld (.row_size + 1),a
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
	ld a,(ds_x)			; the row's first and last dots (edge_lo, edge_hi) + X
	ld (.ex1 + 1),a
	ld (.ex2 + 1),a
	ld a,(ds_x)			; (past clock 255: no edge there, none looked at)
	add a,c
	ld b,1
	jr c,2F
	jr z,2F
	ld a,(coll_ppf + 3)		; (once set it stays)
	and $02
	ld b,a
	ld a,(ds_edge_kind)		; only the kinds that turn at the edge are tested
	cpl
	or b
	ld b,a
2:	ld a,b
	ld (ds_edge_skip),a
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
	ld a,(ds_flags)			; a bridge: the road's colour on each row
	and $80
	ld hl,.road
	ld a,$CD			; (CALL .road)
	jr nz,2F
	xor a				; (NOP NOP NOP)
	ld h,a
	ld l,a
2:	ld (.road_call),a
	ld (.road_call + 1),hl
	ld hl,(ds_shapes)		; (DE, HL as the loop wants them again)
	call ds_row_hl
	ex de,hl
	ld a,(ds_counter)
	sub $44
	ld l,a
	ld h,high PM_P3
	pop bc
.row	ld a,(de)			; the row, and as the scanline fetches it, with player 3's
	ld (hl),a			; position and size there
	ld h,high scan_p3
	ld (hl),a
	inc h
.row_x
	ld (hl),0			; (the object's: set below)
	inc h
.row_size
	ld (hl),0
	ld h,high PM_P3
	ld a,(iy + 0)			; its colour (a bridge: the road's too)
	ld (bc),a
.road_call
	call .road			; (a bridge only)
	ld a,(ds_edge_skip)		; P3PF: only the edge is read, once set it stays
	or a
	jr nz,.row_on
	ld a,(de)			; the row's first and last dots (edge_lo, edge_hi), the
	or a				; clocks from X
	jr z,.row_on
	push bc
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
	ld hl,coll_ppf + 3
	set 1,(hl)
	ld a,1
	ld (ds_edge_skip),a
.row_off
	pop hl
	pop de
	pop bc
.row_on	inc l
	inc c
	dec de
	dec iy
	dec ixl
	jp nz,.row
	jr .rows_done
.late_rows
	ld a,(ds_flags)
	and $80
	call nz,.road
	ld a,(de)
	ld (hl),a
	ld h,high PM_P3
	inc l
	ld a,(iy + 0)
	ld (bc),a
	inc c
	dec de
	dec iy
	dec ixl
	jp nz,.late_rows
	jr .rows_done
.rows_done
	ld a,(iy + 1)			; (the last row's colour)
	ld (ds_cur_col),a
	ld a,(ds_rows)			; X after them: wrapped, or the object's collisions
	ld hl,ds_counter
	add a,(hl)
	ld (hl),a
	jp z,.end
	; B5E8: the object's collisions
	ld a,(ds_counter)
	ds_line
	ld (ds_le),a			; the scanline of X = E
	ld b,a
	ld a,(ds_flags)
	and $80
	ld (ds_bridge),a
	jr nz,1F
	dec b				; M2PL: up to the scanline before (a bridge: this one)
1:	ld a,b
	call ds_advance
	ld a,(coll_mpl + 2)
	and $08
	ld (ds_bullet),a
	jr z,1F
	ld a,(ds_current)
	ld (HIT_BULLET_OBJECT),a
1:	xor a
	ld (ds_hits),a
	ld a,(ds_bridge)
	or a
	jr z,.p3pl
	ld c,46				; a bridge: the last row to B5F3 is 46 cycles (row 0 reads
	ld a,(ds_bullet)		; no table across a page), 2 more for a bullet hit
	or a
	jr z,1F
	ld c,48
1:
	ld a,(ds_le)
	ld b,a
	ld a,c
	call ds_chunk_at
	ld a,(SECTION_BANK_COLOUR)	; B5F3: the bank colour back from the next scanline
	ld e,a
	ld a,(ds_le)
	inc a
	call ds_bank
	jr .b60a
.p3pl	ld a,(ds_le)			; P3PL: the shell
	call ds_advance
	ld a,(coll_ppl + 3)
	and $01
	jr z,.b60a
	ld a,(ds_current)
	ld (HIT_SHELL_OBJECT),a
	ld hl,ds_hits
	inc (hl)
.b60a	call ds_inx			; B60A
	jp z,.end
	ld a,(ds_counter)
	ds_line
	ld (ds_le),a
	dec a				; P2PL: the plane touched the shell, the object
	call ds_advance
	ld a,(coll_ppl + 2)
	and $01
	jr z,1F
	ld a,(ds_current)
	ld (HIT_PLANE_SHELL),a
	ld hl,ds_hits
	inc (hl)
1:	call pl_touch			; the plane touched the object: by its rows (P2PL's bit for
	jr z,1F				; player 3 sees only them)
	ld a,(ds_current)
	ld (HIT_PLANE_OBJECT),a
	ld hl,ds_hits
	inc (hl)
1:	ld a,(ds_le)			; P3PF: the object touched the bank edge
	call ds_advance
	ld a,(coll_ppf + 3)
	and $02
	call ds_edge_only
	ld (ds_edge),a
	ld a,(ds_hits)			; B5F3-B61F: 44 cycles (a bridge 43), 2 more a hit stored
	add a,a
	add a,44
	ld c,a
	ld a,(ds_bridge)
	or a
	jr z,1F
	dec c
1:	ld a,(ds_le)
	ld b,a
	ld a,c
	call ds_chunk_at
	ld a,(ds_edge)
	call ds_set_flags
	call ds_inx
	jp z,.end
	ld a,(ds_counter)
	ds_line
	ld (ds_le),a			; l
	dec a				; M0PL: the missile touched the plane (up to l - 1)
	call ds_advance
	ld a,(coll_mpl)
	and $04
	ld c,28				; M0PF 28 cycles after the WSYNC, 30 after a hit stored
	jr z,1F
	ld a,(ds_current)
	ld (HIT_MISSILE_PLANE),a
	ld c,30
1:	ld a,(ds_le)
	call ds_after_draw		; after l's draw: it sees l too
	ld a,(ds_le)
	jr c,1F
	dec a
1:	call ds_advance
	ld a,(coll_mpf)
	and $03
	jr z,1F
	ld a,(ds_current)
	ld (HIT_MISSILE_BANK),a
1:	ld a,(ds_le)			; P1PF, P2PF, M2PF: up to l
	call ds_advance
	ld c,23				; (HITCLR 23 cycles after the WSYNC, 2 more a hit stored)
	ld a,(coll_ppf + 1)
	and $02
	jr z,1F
	ld a,(ds_current)
	ld (HIT_TANK_AT_EDGE),a
	inc c
	inc c
1:	ld a,(coll_ppf + 2)
	and $01
	jr z,1F
	ld a,(ds_current)
	ld (HIT_PLANE_BANK),a
	inc c
	inc c
1:	ld a,(coll_mpf + 2)
	and $03
	jr z,1F
	ld a,(ds_current)
	ld (HIT_BULLET_BANK),a
	inc c
	inc c
1:	ld a,(ds_le)			; B65F HITCLR on l + 1, before or after its draw
	inc a
	call ds_after_draw
	ld a,(ds_le)
	inc a
	jr nc,1F
	inc a
1:	ld (ds_cleared),a
	call bm_hitclr
	ld a,(ds_current)
	inc a
	ld (ds_slot),a
	call ds_inx
	jp nz,.slot_loop
	ld a,1				; ended right after a HITCLR
	ld (ds_ended),a

.end	; B66B: the river's end (X wrapped to 0); the panel part reads the collisions of the
	; object still in progress, unless the loop ended right after a HITCLR
	xor a
	ds_line
	ld (ds_end_line),a
	ld a,(ds_current)
	cp SLOTS
	jp nc,.no_reads
	ld a,(ds_ended)
	or a
	jp nz,.no_reads
	ld a,(ds_end_line)
	inc a
	call ds_advance
	ld a,(coll_ppf + 3)
	and $02
	call ds_edge_only
	call ds_set_flags
	ld a,(ds_end_line)
	add a,2
	call ds_advance
	ld a,(coll_mpl)
	and $04
	ld de,HIT_MISSILE_PLANE
	call nz,.hit_current
	ld a,(coll_mpf)
	and $03
	ld de,HIT_MISSILE_BANK
	call nz,.hit_current
	ld a,(coll_mpf + 2)
	and $03
	ld de,HIT_BULLET_BANK
	call nz,.hit_current
	ld a,(coll_ppf + 2)
	and $01
	ld de,HIT_PLANE_BANK
	call nz,.hit_current
	ld a,(coll_ppl + 2)
	and $01
	ld de,HIT_PLANE_SHELL
	call nz,.hit_current
	call pl_touch
	ld de,HIT_PLANE_OBJECT
	call nz,.hit_current
	ld a,(coll_ppl + 3)
	and $01
	ld de,HIT_SHELL_OBJECT
	call nz,.hit_current
	ld a,(coll_ppf + 1)
	and $02
	ld de,HIT_TANK_AT_EDGE
	call nz,.hit_current
	ld a,(ds_end_line)
	add a,3
	call ds_advance
	ld a,(coll_mpl + 2)
	and $08
	ld de,HIT_BULLET_OBJECT
	call nz,.hit_current
	jr .fin
.no_reads
	ld a,(ds_end_line)		; what is drawn, to the panel
	inc a
	call ds_advance
.fin	call ds_cover_clear
	jp ds_bank_fill
.hit_current
	ld a,(ds_current)
	ld (de),a
	ret
.road					; a bridge's row: the bank the road's colour from scanline C
	push de
	push hl
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
	pop hl
	pop de
	ret

; INX: Z when X wraps to 0
ds_inx:
	ld hl,ds_counter
	inc (hl)
	ret

; A = the slot's y ($FF after the last)
ds_slot_y:
	ld a,(ds_slot)
	cp SLOTS
	ld a,$FF
	ret nc
	ld a,(ds_slot)
	ld e,a
	ld d,0
	ld hl,SLOT_Y
	add hl,de
	ld a,(hl)
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

; Player 3's row for X = A (its memory is indexed by X: scanline A - $44) to E, written on
; scanline B: GTIA fetches it on that scanline only if it starts after. BC kept.
ds_write_p3:
	push af
	ld l,a
	ld h,0
	or a				; (X = $100 for the second blank row after $FF)
	jr nz,1F
	ld a,(ds_counter)
	inc a
	jr nz,1F
	inc h
1:	push de
	ld de,PM_P3_ROWS
	add hl,de
	pop de
	ld (hl),e
	pop af
	sub $44
	cp b
	ret c
	ret z
	ld l,a
	ld h,high scan_p3
	ld (hl),e
	ret

; The code from a WSYNC to the next one, A cycles with that STA, on scanline B (ds_chunk:
; the scanline of X = ds_counter): past cycle 106 of it with its start and draw taken out,
; the DLI falls a scanline behind: A + start(B) - after_draw(B) > 28.
ds_chunk:
	ld c,a
	ld a,(ds_counter)
	ds_line
	ld b,a
	ld a,c
ds_chunk_at:
	ld l,b
	ld h,high line_start
	add a,(hl)
	inc h
	sub (hl)
	jr c,.no
	cp DRAW_CYCLE + 1
	ret c
	ld hl,ds_slip
	inc (hl)
	ld a,(ds_slow)			; from here on the scanlines' registers by events, the
	or a				; colours set on them ($FF: none; no Atari colour is odd)
	ret nz
	inc a
	ld (ds_slow),a
	ld a,b
	inc a
	ld l,a
	ld h,high scan_col
1:	ld (hl),$FF
	inc l
	ld a,l
	cp 192
	jr c,1B
	ret
.no	ret

; An access C cycles after a WSYNC, on scanline A: carry if it comes after A's draw
; (C - 8 + start(A) >= 28)
ds_after_draw:
	ld l,a
	ld h,high line_start
	ld a,c
	add a,(hl)
	cp LINE_CYCLES - WSYNC_CYCLE + DRAW_CYCLE
	ccf
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

; HPOSP3 (ds_event_x) or SIZEP3 (ds_event_size) = A from scanline B on
ds_event_x:
	ld c,0
	jr ds_event
ds_event_size:
	ld c,1
ds_event:
	push af
	ld a,(ds_ev_n)
	cp DS_EVENTS
	jr nc,.full
	ld l,a
	inc a
	ld (ds_ev_n),a
	ld a,l
	add a,a
	add a,l
	ld l,a
	ld h,0
	ld de,ds_ev
	add hl,de
	ld (hl),b			; scanline, which, value
	inc hl
	ld (hl),c
	inc hl
	pop af
	ld (hl),a
	ld a,(ds_ev_next)		; (the first one not yet reached)
	cp $FF
	ret nz
	ld a,b
	ld (ds_ev_next),a
	ret
.full	pop af
	ret

; The scanlines up to A, in order. A scanline with nothing on it is passed over (a colour
; set on it kept); one with a player or missile gets player 3's registers as written up to
; it (scan_*), and its collisions (from ds_cleared on) go into the collision registers
; (bm_draw).
ds_advance:
	ld b,a
	ld a,(ds_adv)
	cp b
	ret nc
	ld l,a
	ld a,(ds_slow)
	or a
	jr nz,.next
	; Player 3's rows are done (the rows' loop): only the other sprites' boxes from the last
	; HITCLR's scanline on
	ld h,high ds_cover
.fnext	inc l
	ld a,(hl)
	or a
	jr nz,.fbusy
.fskip	ld a,l
	cp b
	jr c,.fnext
	ld (ds_adv),a
	ret
.fbusy	ld a,(ds_cleared)
	dec a
	cp l
	jr nc,.fskip
	push bc
	push hl
	ld a,l
	ld (bm_line),a
	ld c,a
	ld h,high scan_x		; player 3's registers there: its row's (if any)
	ld a,(hl)
	ld (hpos_p + 3),a
	inc h
	ld a,(hl)
	ld (size_p + 3),a
	inc h
	ld a,(hl)
	ld (colour_p3),a
	call ds_panel
	call bm_draw
	pop hl
	pop bc
	ld h,high ds_cover
	jr .fskip
	; the DLI fell behind: every scanline
.next	inc l
	ld h,high scan_p3		; anything on the scanline? (player 3; the others' boxes)
	ld a,(hl)
	ld h,high ds_cover
	or (hl)
	jr nz,.busy
	ld h,high scan_col		; (a colour set on it: the one from here)
	ld a,(hl)
	cp $FF
	jr z,.skip
	ld (ds_cur_col),a
.skip	ld a,l
	cp b
	jr c,.next
	ld (ds_adv),a
	ret
.busy	push bc
	push hl
	ld a,l
	ld (bm_line),a
	ld c,a
	ld h,high ds_cover		; player 3 alone (the usual): straight to its part
	ld a,(hl)
	or a
	jp z,.p3_only
	ld a,(ds_ev_next)		; HPOSP3, SIZEP3 written up to this scanline
	cp c
	call z,ds_events
	call c,ds_events
	ld l,c				; player 3's colour: set on this scanline, or the last
	ld h,high scan_col
	ld a,(hl)
	cp $FF
	jr z,1F
	ld (ds_cur_col),a
	jr 2F
1:	ld a,(ds_cur_col)
	ld (hl),a
2:	ld (colour_p3),a
	ld a,(ds_cur_x)
	ld (hpos_p + 3),a
	ld a,(ds_cur_size)
	ld (size_p + 3),a
	call ds_panel
	ld a,(ds_cleared)		; the collisions from the last HITCLR's scanline on
	dec a
	cp c
	jr nc,1F
	push bc
	call bm_draw			; (collide: only what the DLI reads, spans first)
	pop bc
1:	ld l,c				; player 3's registers where it is
	ld h,high scan_p3
	ld a,(hl)
	or a
	jr z,.done
	inc h
	ld a,(hpos_p + 3)
	ld (hl),a
	inc h
	ld a,(size_p + 3)
	ld (hl),a
.done	pop hl
	pop bc
	jp .skip
.p3_only
	ld l,c				; a row written this frame with the DLI not behind: its
	ld h,high scan_col		; colour, position and size are there already
	ld a,(hl)
	cp $FF
	jr z,.p3_slow
	ld (ds_cur_col),a
	ld a,(ds_slow)
	or a
	jr nz,.p3_slow
	ld a,(ds_cleared)		; P3PF from the last HITCLR's scanline on: only the edge
	dec a				; is read, once set it stays
	cp c
	jr nc,.done
	ld a,(coll_ppf + 3)
	and $02
	jr nz,.done
	ld h,high scan_p3
	ld d,(hl)
	inc h
	ld e,(hl)
	inc h
	ld a,(hl)
	call pf_edge
	ld hl,coll_ppf + 3
	or (hl)
	ld (hl),a
	jp .done
.p3_slow
	ld a,(ds_ev_next)		; HPOSP3, SIZEP3 written up to this scanline
	cp c
	call z,ds_events
	call c,ds_events
	ld l,c
	ld h,high scan_col		; its colour: set on this scanline, or the last
	ld a,(hl)
	cp $FF
	jr z,1F
	ld (ds_cur_col),a
	jr 2F
1:	ld a,(ds_cur_col)
	ld (hl),a
2:	ld h,high scan_x		; its position and size
	ld a,(ds_cur_x)
	ld (hl),a
	ld e,a
	inc h
	ld a,(ds_cur_size)
	ld (hl),a
	ld b,a
	ld a,(ds_cleared)		; P3PF from the last HITCLR's scanline on: only the edge
	dec a				; is read, once set it stays; only on its box
	cp c
	jr nc,.done
	ld a,(coll_ppf + 3)
	and $02
	jr nz,.done
	ld h,high scan_p3
	ld d,(hl)
	ld a,b
	call pf_edge
	ld hl,coll_ppf + 3
	or (hl)
	ld (hl),a
	jr .done

; Scanline C in the panel: the shell, the tank, the missile at x 0
ds_panel:
	ld a,c
	cp RIVER_FIRST + RIVER_LINES
	ret c
	ld a,(ds_end_line)
	cp c
	ret nc
	xor a
	ld (hpos_p),a
	ld (hpos_p + 1),a
	ld (hpos_m),a
	ret

; The HPOSP3 and SIZEP3 writes up to scanline C; ds_ev_next: the next one's ($FF none)
ds_events:
	ld a,(ds_ev_rd)
	ld hl,ds_ev_n
	cp (hl)
	jr nc,.none
	ld l,a
	add a,a
	add a,l
	ld l,a
	ld h,0
	ld de,ds_ev
	add hl,de
	ld a,(hl)
	cp c
	jr z,.now
	jr nc,.later
.now	inc hl
	ld a,(hl)
	inc hl
	ld b,(hl)
	or a
	ld a,b
	jr nz,.size
	ld (ds_cur_x),a
	jr .on
.size	ld (ds_cur_size),a
.on	ld hl,ds_ev_rd
	inc (hl)
	jr ds_events
.later	ld (ds_ev_next),a
	ret
.none	ld a,$FF
	ld (ds_ev_next),a
	ret

; The other sprites' boxes by scanline (ds_cover, a bit a sprite: 0 the shell, 1 the tank,
; 2 the plane, 4 missile 0, 5 missile 2), where the game put them: the shell 16 rows from
; shellY, the tank 11 from tankY, the plane 14 from $AA, the missile the row missileY, the
; bullet 8 rows below bulletY. (Player 3: where its rows are.) Cleared again at the end.
ds_cover_set:
	ld de,$0102
	ld hl,$1020
	jr ds_cover_do
ds_cover_clear:
	ld de,0
	ld hl,0
ds_cover_do:
	ld (ds_cmask),hl		; (the bullet, missile 0)
	ld a,(SHELL_Y)
	ld b,16
	ld c,d
	call .mark
	ld a,(TANK_Y)
	ld b,11
	ld c,e
	call .mark
	ld a,$AA
	ld b,14
	ld c,e
	sla c
	call .mark
	ld a,(MISSILE_Y)
	cp $1C
	jr c,1F
	ld b,1
	ld hl,ds_cmask + 1
	ld c,(hl)
	call .mark
1:	ld a,(BULLET_Y)
	dec a
	ret z
	cp $1B
	jr nc,2F
	ld a,$1B
2:	inc a
	ld b,8
	ld hl,ds_cmask
	ld c,(hl)
.mark	ld l,a
	ld h,high ds_cover
	ld a,c
	or a
	jr z,.clr
.m	ld a,(hl)
	or c
	ld (hl),a
	inc l
	ret z
	djnz .m
	ret
.clr	ld (hl),a
	inc l
	ret z
	djnz .clr
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

; The rows of the river whose display list instruction has a screen address (the top row and
; where screen memory goes on in the other block): 3 cycles at their start, the others 1.
ds_lms:
	ld hl,(SCREEN_TOP)
	ld a,h
	cp $30
	ld de,$2F00
	jr c,.block
	ld de,$3F00
.block	ex de,hl
	or a
	sbc hl,de			; bytes to the block's end (48 k, k < 80): k = (bytes / 16) / 3
	add hl,hl
	add hl,hl
	add hl,hl
	add hl,hl
	ld d,h				; (H: bytes * 16 / 256 = bytes / 16; x 171 / 512 = / 3)
	ld e,171
	mul d,e
	ld a,d
	srl a
	ld c,a
	ld hl,line_start + RIVER_FIRST	; last frame's rows back to 1 cycle, this frame's 3
	ld a,(lms_k1)
	ld e,a
	ld d,0
	add hl,de
	ld (hl),5 + 1
	ld hl,line_start + RIVER_FIRST
	ld a,(lms_k1 + 1)
	cp RIVER_LINES
	jr nc,.d3
	ld e,a
	add hl,de
	ld (hl),5 + 1
.d3	ld a,c
	ld (lms_k1),a
	ld hl,line_start + RIVER_FIRST
	ld e,a
	add hl,de
	ld (hl),5 + 3
	add a,80
	ld (lms_k1 + 1),a
	cp RIVER_LINES
	jr nc,.d4
	ld hl,line_start + RIVER_FIRST
	ld e,a
	add hl,de
	ld (hl),5 + 3
.d4	ld a,5 + 3			; and the top row
	ld (line_start + RIVER_FIRST),a
	ret
