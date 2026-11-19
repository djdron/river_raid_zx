; The river part of the display, scanline by scanline, as the original's display list
; interrupt drives it: river_raid/port/src/display.cpp (Game::display and its Beam) line for
; line. The DLI shows every object with player 3, re-used down the screen, and reads the
; collision registers after each object; whether a collision on the line being read counts
; depends on the cycle, so the DLI's instructions are run with their cycle counts and the
; scanlines happen in between (the reference emulator's timing, as the C++ port models it):
;   - a scanline is 114 machine cycles; at its start ANTIC takes 5 cycles for the players
;     and missiles and 1 for the display list (3 with a screen address);
;   - at cycle 28 the line is drawn, collisions included; ANTIC then takes 9 refresh cycles
;     and 48 for a river line's screen data;
;   - STA WSYNC waits for cycle 106.
; What it leaves: per river line the state of player 3 and the bank colour (scan_*), the
; rows of the objects in player 3's memory, the collisions (HIT, the slots' edge flags).

LINE_CYCLES	equ 114
DRAW_CYCLE	equ 28
WSYNC_CYCLE	equ 106
REFRESH_CYCLES	equ 9
RIVER_FIRST	equ 28		; the river's first scanline
PANEL_FIRST	equ 190		; the panel's first (NTSC; 194 PAL)

; An instruction of n cycles. Instructions in a row with nothing the beam sees between
; them (a register written, a collision read, WSYNC) can go as one: the events between them
; happen before the next such instruction all the same.
;
; An instruction of n cycles. IXH (during the display) is the cycles left until the beam's
; next event (the line drawn at cycle 28, the next line at 114), signed; events due before
; the instruction happen first.
op:	macro n
	ld a,ixh
	dec a
	call m,bm_events
	sub n - 1
	ld ixh,a
	endm
opa:	macro			; an instruction (or several together) of A cycles
	ld c,a
	ld a,ixh
	dec a
	call m,bm_events
	inc a
	sub c
	ld ixh,a
	endm
opk:	macro k, n		; k cycles nothing on screen sees, then an instruction of n:
	ld a,ixh		; the events of those cycles happen before it all the same
	sub k + 1
	call m,bm_events
	sub n - 1
	ld ixh,a
	endm
opc:	macro n, k		; the same, C + k cycles first
	ld a,ixh
	sub c
	sub k + 1
	call m,bm_events
	sub n - 1
	ld ixh,a
	endm
	ifdef BEAM			; (the cycle model only: display.asm's display)
taken:	macro			; a branch taken (3 cycles)
	op 3
	endm
not_taken: macro		; a branch not taken (2 cycles)
	op 2
	endm
taken_far: macro		; taken to another page (4)
	op 4
	endm
wsync:	macro
	call bm_wsync
	endm
exit_b5e3: macro		; leaving through B5E3 (BEQ to another page) and B60B
	op 4
	op 3
	endm

; ------------------------------------------------------------------------------------------
; The beam

bm_op:					; an instruction of A cycles (A > 0)
	ld c,a
	ld a,ixh
	dec a
	call m,bm_events
	inc a
	sub c
	ld ixh,a
	ret

; The events due (IXH <= 0): the line drawn, the next line, until the next event is ahead.
; In: A = IXH - 1; out: the same for the new IXH. Drawing a line only matters when a player
; or missile is on it: the collisions, and player 3's position, size and colour (scan_*,
; only where player 3 is on the line). Player 3's data is kept as the lines latch it
; (p3_scan), the bank colour when it changes (rec_set).
bm_events:
	push hl
	inc a
.loop	ld ixh,a
	ld hl,bm_drawn
	ld a,(hl)
	or a
	jr nz,.next_line
	inc (hl)			; drawn at 28 - IXH
	call bm_draw
	ld a,(bm_line)
	ld l,a
.after	ld h,high line_after_draw	; then refresh and screen data
	ld a,ixh
	add a,(hl)
	dec a				; due again?
	jp m,.again
	pop hl
	ret
.next_line				; at 114 - IXH: the next line from its start cycles
	ld (hl),0
	ld hl,bm_line
	inc (hl)
	ld l,(hl)
	ld h,high line_start
	ld a,ixh
	add a,DRAW_CYCLE
	sub (hl)
	dec a				; due again?
	jp m,.again
	pop hl
	ret
.again	inc a
	jp .loop

; The line bm_line drawn: player 3's position, size and colour where it is on the line, the
; collisions where anything is. Keeps IX, IY.
bm_draw:
	ld a,(bm_line)
	ld l,a
	ld h,high scan_p3		; player 3 on the line: its position, size and colour
	ld a,(hl)
	or a
	jr z,.no_p3
	inc h
	ld a,(hpos_p + 3)
	ld (hl),a
	inc h
	ld a,(size_p + 3)
	ld (hl),a
	inc h
	ld a,(colour_p3)
	ld (hl),a
	ld h,high PM_MISSILES		; only player 3 (the usual): with the playfield, if any
	ld a,(hl)
	inc h
	or (hl)
	inc h
	or (hl)
	inc h
	or (hl)
	jr nz,.collide
	ld a,(coll_ppf + 3)		; P3PF: only the edge is read, once set it stays
	and $02
	ret nz
	push bc
	push de
	ld h,high scan_p3
	ld d,(hl)
	ld a,(hpos_p + 3)
	ld e,a
	ld a,(size_p + 3)
	call pf_edge
	ld hl,coll_ppf + 3
	or (hl)
	ld (hl),a
	pop de
	pop bc
	ret
.no_p3	ld h,high PM_MISSILES		; anything else: the collisions
	ld a,(hl)
	inc h
	or (hl)
	inc h
	or (hl)
	inc h
	or (hl)
	ret z
.collide
	push bc
	push de
	call collide_line
	pop de
	pop bc
	ret

; The line's players, missiles and playfield for collide
collide_line:
	ld a,(bm_line)
	ld l,a
	ld h,high PM_MISSILES
	ld a,(hl)
	ld (bm_m),a
	inc h
	ld a,(hl)
	ld (bm_p),a
	inc h
	ld a,(hl)
	ld (bm_p + 1),a
	inc h
	ld a,(hl)
	ld (bm_p + 2),a
	ld h,high scan_p3
	ld a,(hl)
	ld (bm_p + 3),a
	jp collide

; A register shown per line changes to A (HL: its record: value, from which line, the
; scan_* page): the lines since the last change get the old value. A is kept.
rec_set:
	push af
	push bc
	push de
	ld b,a
	ld a,(bm_drawn)			; the first line it shows on: this one if not yet drawn
	ld c,a
	ld a,(bm_line)
	add a,c
	ld c,a
	ld a,(hl)
	ld (hl),b
	ld b,a				; B: the old value
	inc hl
	ld a,c
	sub (hl)
	jr c,.done
	jr z,.done
	ld e,(hl)
	ld (hl),c
	inc hl
	ld d,(hl)
	ex de,hl
.fill	ld (hl),b
	inc l
	dec a
	jr nz,.fill
.done	pop de
	pop bc
	pop af
	ret

; the last value of a record to the river's end
rec_end:
	ld b,(hl)
	inc hl
	ld e,(hl)
	inc hl
	ld d,(hl)
	ld a,RIVER_FIRST + RIVER_LINES
	sub e
	ret c
	ret z
	ex de,hl
.fill	ld (hl),b
	inc l
	dec a
	jr nz,.fill
	ret

; Player 3's data written at HL (A): if its line has not started yet, that is what the line
; latches. A is kept.
p3_scan:
	push af
	ld a,(bm_line)
	cp l
	jr nc,.late
	ld a,h
	cp high PM_P3
	jr nz,.late
	pop af
	push hl
	ld h,high scan_p3
	ld (hl),a
	pop hl
	ret
.late	pop af
	ret

bm_wsync:				; STA WSYNC (after its 4 cycles): on to cycle 106
	ld a,(bm_drawn)
	or a
	jr z,.draw
	ld a,ixh			; drawn, at or before 106: there
	bit 7,a
	jr nz,.next
	cp LINE_CYCLES - WSYNC_CYCLE
	jr c,.next
	ld ixh,LINE_CYCLES - WSYNC_CYCLE
	ret
.next	ld a,-1				; past it: the next line (at 114)
	call bm_events
.draw	ld a,-1				; halted until the line is drawn (at 28)
	call bm_events
	ld ixh,LINE_CYCLES - WSYNC_CYCLE
	ret

	endif
; Per scanline: the cycles ANTIC takes at its start (line_start), and the cycles left in it
; after it is drawn (line_after_draw). The river rows whose display list instruction has a
; screen address change from frame to frame (display).
init_line_tables:
	ld hl,line_start
.l	ld (hl),5
	inc h
	ld (hl),LINE_CYCLES - DRAW_CYCLE - REFRESH_CYCLES
	dec h
	inc l
	jr nz,.l
	ld l,RIVER_FIRST
	ld b,RIVER_LINES
.r	ld (hl),5 + 1
	inc h
	ld (hl),LINE_CYCLES - DRAW_CYCLE - REFRESH_CYCLES - 48
	dec h
	inc l
	djnz .r
	ld l,24				; blank-line instructions
	ld (hl),5 + 1
	ld l,RIVER_FIRST + RIVER_LINES
	ld (hl),5 + 1
	ld a,(tv_pal)			; the panel: mode 6 with an address (2 blank lines before
	add a,a				; it, 6 on PAL)
	add a,a
	add a,PANEL_FIRST
	ld l,a
	ld (hl),5 + 3
	inc h
	ld (hl),LINE_CYCLES - DRAW_CYCLE - REFRESH_CYCLES - 20
	ld hl,lms_k1
	ld (hl),0
	inc hl
	ld (hl),80
	ret

bm_hitclr:
	ld hl,0
	ld (coll_mpf),hl
	ld (coll_mpf + 2),hl
	ld (coll_ppf),hl
	ld (coll_ppf + 2),hl
	ld (coll_mpl),hl
	ld (coll_mpl + 2),hl
	ld (coll_ppl),hl
	ld (coll_ppl + 2),hl
	ret

; ------------------------------------------------------------------------------------------
; GTIA's collision detection for the line being drawn. A sprite's cover is kept as mask
; bytes in the playfield's layout (2 bits per colour clock, 4 clocks per byte): byte j of
; sprite n covers screen byte sp_u[n] + j - 8.

SPRITES	equ 8				; players 0-3, missiles 0-3

collide:					; (line bm_line)
	ifdef BEAM			; (the body: the cycle model; display_hits.asm takes .add, .pair)
.all	; more than player 3. Only what the DLI reads (B5E8-B664, B6BC on): with the
	; playfield P1PF, P2PF, P3PF, M0PF, M2PF; with each other M0PL (the plane), M2PL (player
	; 3), P2PL (the shell; player 3: pl_touch), P3PL (the shell). The others are never read.
	xor a				; none yet, no masks made
	ld (cs_present),a
	ld (cs_list + 0 * 5),a
	ld (cs_list + 0 * 5 + 4),a
	ld (cs_list + 2 * 5),a
	ld (cs_list + 2 * 5 + 4),a
	ld (cs_list + 3 * 5),a
	ld (cs_list + 3 * 5 + 4),a
	ld (cs_list + 4 * 5),a
	ld (cs_list + 4 * 5 + 4),a
	ld (cs_list + 6 * 5),a
	ld (cs_list + 6 * 5 + 4),a
	ld a,(bm_p)			; P0: only touched
	or a
	jr z,.p1
	ld d,a
	ld a,(hpos_p)
	ld e,a
	ld a,(size_p)
	ld b,0
	call .add
.p1	ld a,(bm_p + 1)			; P1: the playfield
	or a
	jr z,.p2
	ld d,a
	ld a,(hpos_p + 1)
	ld e,a
	ld a,(size_p + 1)
	ld hl,coll_ppf + 1
	call .pf
.p2	ld a,(bm_p + 2)
	or a
	jr z,.p3
	ld d,a
	ld a,(hpos_p + 2)
	ld e,a
	ld a,(size_p + 2)
	ld b,2
	call .add
	ld hl,coll_ppf + 2
	call .pf_bank
.p3	ld a,(bm_p + 3)
	or a
	jr z,.m0
	ld d,a
	ld a,(hpos_p + 3)
	ld e,a
	ld a,(size_p + 3)
	ld b,3
	call .add
	ld hl,coll_ppf + 3
	call .pf
.m0	ld a,(bm_m)			; missiles: 2 bits each, at the top like a player's first two
	and $03
	jr z,.m2
	rrca
	rrca
	ld d,a
	ld a,(hpos_m)
	ld e,a
	ld a,(size_m)
	ld b,4
	call .add
	ld hl,coll_mpf
	call .pf_entry
.m2	ld a,(bm_m)
	and $30
	jr z,.pairs
	rlca
	rlca
	ld d,a
	ld a,(hpos_m + 2)
	ld e,a
	ld a,(size_m)
	rrca
	rrca
	rrca
	rrca
	ld b,6
	call .add
	ld hl,coll_mpf + 2
	call .pf_entry
.pairs	ld a,(cs_present)
	ld d,a
	and $48				; M2PL: player 3
	cp $48
	jr nz,.pr2
	ld bc,6 << 8 | 3
	ld hl,coll_mpl + 2
	ld e,$08
	call .pair
.pr2	ld a,d
	and $09				; P3PL: the shell
	cp $09
	jr nz,.pr3
	ld bc,3 << 8 | 0
	ld hl,coll_ppl + 3
	ld e,$01
	call .pair
.pr3	ld a,d
	and $05				; P2PL: the shell
	cp $05
	jr nz,.pr4
	ld bc,2 << 8 | 0
	ld hl,coll_ppl + 2
	ld e,$01
	call .pair
.pr4	ld a,d				; (P2PL's bit for player 3: pl_touch)
	and $14				; M0PL: the plane
	cp $14
	ret nz
	ld bc,4 << 8 | 2
	ld hl,coll_mpl
	ld e,$04
	; (on to .pair)

	endif
; sprites B and C: if both are on the line and touch, (HL) |= E
.pair	push hl
	push de
	ld a,b
	call .entry
	ld a,(hl)			; bits: there?
	or a
	jr z,.no
	inc hl
	ld e,(hl)			; hpos B
	inc hl
	inc hl
	ld d,(hl)			; end B
	ld a,c
	call .entry
	ld a,(hl)
	or a
	jr z,.no
	inc hl
	ld a,(hl)			; hpos C < end B
	cp d
	jr nc,.no
	inc hl
	inc hl
	ld a,e				; hpos B < end C
	cp (hl)
	jr nc,.no
	call .overlap			; the spans meet: pixel by pixel
	jr nc,.no
	pop de
	pop hl
	ld a,e
	or (hl)
	ld (hl),a
	ret
.no	pop de
	pop hl
	ret

; sprite B (bits D, position E, size A) on the line: its entry (bits, hpos, size, end, mask
; made)
.add	and 3
	ld c,a
	push bc
	ld a,1
	inc b
.ab	dec b
	jr z,.ab1
	add a,a
	jr .ab
.ab1	ld hl,cs_present
	or (hl)
	ld (hl),a
	pop bc
	ld a,b
	call .entry
	ld (hl),d
	inc hl
	ld (hl),e
	inc hl
	ld (hl),c
	inc hl
	ld a,b				; width: 8 or 2 clocks a sprite, x1, 2, 4
	cp 4
	ld a,8
	jr c,.w
	ld a,2
.w	bit 0,c
	jr z,.wn
	add a,a
	bit 1,c
	jr z,.wn
	add a,a
.wn	add a,e
	jr nc,.we
	ld a,$FF
.we	ld (hl),a
	ld a,c
	ret

; its playfield colours into (HL) (A = size)
; (only the bits the DLI reads: P1PF, P3PF the edge, P2PF the bank, M0PF, M2PF both)
	ifdef BEAM
.pf_entry
	push hl
	call pf_under
	pop hl
	or (hl)
	ld (hl),a
	ret
.pf_bank
	push hl
	call pf_bank
	pop hl
	or (hl)
	ld (hl),a
	ret
.pf	push hl
	call pf_edge
	pop hl
	or (hl)
	ld (hl),a
	ret

; HL = entry A of the list
	endif
.entry	ld l,a
	add a,a
	add a,a
	add a,l
	add a,low cs_list
	ld l,a
	ld a,high cs_list
	adc a,0
	ld h,a
	ret

; Do sprite B's pixels touch sprite C's? Carry: yes. Each colour clock B covers (its bits,
; 1, 2 or 4 clocks each) is looked up in C's bits; only clocks over the playfield count
; (32-223, as GTIA's masks are kept).
.overlap
	push bc
	ld a,c
	call .entry
	ld a,(hl)
	ld (ov_bits),a
	inc hl
	ld a,(hl)
	ld (ov_hpos),a
	inc hl
	ld a,(hl)
	call .wlog
	ld (ov_wlog),a
	pop bc
	ld a,b
	call .entry
	ld d,(hl)			; D: B's bits, E: the clock
	inc hl
	ld e,(hl)
	inc hl
	ld a,(hl)
	call .wlog
	ld c,1				; C: clocks a bit
	or a
	jr z,.ob
	ld c,2
	dec a
	jr z,.ob
	ld c,4
.ob	ld a,d
	or a
	ret z				; (carry clear)
	sla d
	ld b,c
	jr c,.ock
	ld a,e
	add a,c
	ld e,a
	jr .ob
.ock	ld a,e
	cp 32
	jr c,.on
	cp 224
	jr nc,.on
	ld hl,ov_hpos
	sub (hl)
	jr c,.on
	ld h,a				; the clock in C: its bit
	ld a,(ov_wlog)
	or a
	ld a,h
	jr z,.s
	srl a
	ld h,a
	ld a,(ov_wlog)
	dec a
	ld a,h
	jr z,.s
	srl a
.s	cp 8
	jr nc,.on
	add a,low .bitmask
	ld l,a
	ld a,high .bitmask
	adc a,0
	ld h,a
	ld a,(ov_bits)
	and (hl)
	jr z,.on
	scf
	ret
.on	inc e
	djnz .ock
	jr .ob
.bitmask
	db $80,$40,$20,$10,$08,$04,$02,$01

; size bits A: 1, 2, 4 clocks a bit as 0, 1, 2
.wlog	and 3
	cp 3
	jr z,.wl2
	and 1
	ret
.wl2	ld a,2
	ret
; The playfield under a sprite: bits D (the first at bit 7), position E, size A (each bit 1,
; 2 or 4 colour clocks), on line bm_line. pf_under: 1 if a bit covers the bank, 2 the
; edge (both); pf_bank, pf_edge: only that one. The line's runs of bank and of edge pixels are
; kept from when it was generated (span_line, spans.asm), as the clocks they start and end at; a run that
; meets the sprite's clocks is looked at bit by bit: the sprite's bits over it (SPAN_MASKS:
; bits i_lo..i_hi) ANDed with its bits.
pf_under:
	push af
	push de
	call pf_bank
	ld (pu_pf),a
	pop de
	pop af
	call pf_edge
	ld hl,pu_pf
	or (hl)
	ret

pf_bank:
	call pf_line
	jr nc,pf_none
	inc l
	call pf_size
	ret z
	ld a,1
	ret

pf_edge:
	call pf_line
	jr nc,pf_none
	add a,(hl)
	ld l,a
	call pf_size
	ret z
	ld a,2
	ret

pf_none:
	xor a
	ret

; HL, A = L: the record of line bm_line (carry; no carry: not a river line), C = A
pf_line:
	ld c,a
	ld a,(bm_line)			; river line k is at span_top + k
	sub RIVER_FIRST
	cp RIVER_LINES
	ret nc
	ld hl,span_top
	add a,(hl)
	span_rec
	scf
	ret

; The runs at HL under the sprite (bits D, position E, size C): NZ if a bit is over one.
; The variant for the size gets B: the sprite's end clock, C: its first, D: the masks' page,
; and its bits. (A sprite past clock 255 is past the runs too: its end wraps to below its
; first, and none is looked at.)
pf_size:
	ld a,c
	and 3
	cp 3
	jr z,.w4
	dec a
	jr z,.w2
	ld a,d
	ld (pf_v1_bits + 1),a
	ld a,e
	add a,8
	ld b,a
	ld c,e
	ld d,high span_masks
	jp pf_v1
.w2	ld a,d
	ld (pf_v2_bits + 1),a
	ld a,e
	add a,16
	ld b,a
	ld c,e
	ld d,high span_masks
	jp pf_v2
.w4	ld a,d
	ld (pf_v4_bits + 1),a
	ld a,e
	add a,32
	ld b,a
	ld c,e
	ld d,high span_masks
	jp pf_v4

; One variant per size: N shifts make a clock offset a bit's index.
pf_v	macro N, BITS
.l	ld a,(hl)			; the run's first clock: past the sprite, the end
	cp b
	jr nc,.end
	ex af,af'
	inc hl
	ld e,(hl)			; its end: the sprite starts after it, the next
	inc hl
	ld a,c
	cp e
	jr nc,.l
	ld a,e				; the last bit over it
	cp b
	jr c,.h
	ld a,b
.h	dec a
	sub c
	rept N
	srl a
	endr
	ld e,a
	ex af,af'			; the first bit over it
	sub c
	jr nc,.p
	xor a
.p
	rept N
	srl a
	endr
	add a,a
	add a,a
	add a,a
	or e
	ld e,a
	ld a,(de)
BITS	and 0
	jr z,.l
	ret
.end	xor a
	ret
	endm

pf_v1:	pf_v 0, pf_v1_bits
pf_v2:	pf_v 1, pf_v2_bits
pf_v4:	pf_v 2, pf_v4_bits

; ------------------------------------------------------------------------------------------
; The DLI, frame by frame (B500-B6BC, B6C5-B727)

	ifdef BEAM			; (the DLI's cycles, as before: -DBEAM)
display:
				; (TS-Conf: window 1 holds SPANS)		; the lines' runs of bank and edge (pf_under)
	call .beam
	ld hl,rec_bank			; the bank colour's last value to the river's end
	jp rec_end
.beam	ld hl,PM_P3			; player 3's data as the lines will latch it (p3_scan: as
	ld de,scan_p3			; the DLI changes it)
	ld b,16
.p3	rept 16
	ldi
	endr
	djnz .p3
	; rows whose display list instruction has a screen address: the top row and where screen
	; memory goes on in the other block
	ld hl,(SCREEN_TOP)
	ld a,h
	cp $30
	ld de,$2F00
	jr c,.block
	ld de,$3F00
.block	ex de,hl
	or a
	sbc hl,de			; bytes to the block's end
	ld c,0
.div	ld a,h
	or a
	jr nz,.d1
	ld a,l
	cp 48
	jr c,.d2
.d1	ld de,-48
	add hl,de
	inc c
	jr .div
.d2	ld hl,line_start + RIVER_FIRST	; last frame's rows back to 1 cycle, this frame's 3
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
	; the beam: the DLI starts on scanline 23, B500-B51D take it to about cycle 76
	ld hl,hpos_p			; registers (the Beam's) cleared
	ld b,regs_end - hpos_p
	xor a
.regs	ld (hl),a
	inc hl
	djnz .regs
	ld a,1
	ld (size_m),a			; missile 0 double width (A116)
	call bm_hitclr
	ld a,23
	ld (bm_line),a
	ld a,1				; drawn, at cycle 76
	ld (bm_drawn),a
	ld ixh,LINE_CYCLES - 76
	ld a,(colour_bank)		; set by the VBI
	ld (beam_bank),a
	ld a,(SLOT_SIZE + SLOTS - 1)
	ld (size_p + 3),a
	ld hl,rec_bank			; the bank colour the lines show from the river's top
	ld de,beam_bank
	ld bc,high scan_bank << 8 | RIVER_FIRST
	call .rec_init
	ld hl,HIT			; B510
	ld b,9
	ld a,$FF
.hit	ld (hl),a
	inc hl
	djnz .hit
	op 4				; B51E
	wsync
	op 9				; B521-B525
	op 13				; B527-B52F
	op 4
	ld a,(FUEL)
	srl a
	srl a
	srl a
	add a,$5C
	ld (hpos_m + 1),a
	op 3				; B532
	op 4
	ld a,(PLANE_X)
	ld (hpos_p + 2),a
	op 4				; B537
	op 4
	ld a,(PLANE_X)
	add a,4
	ld (hpos_m + 2),a
	op 2				; COLPM1
	op 4
	op 5				; COLPM2
	ld a,(PLAYER)
	or a
	jr z,.p1
	taken
	jr .p2
.p1	not_taken
	op 2
.p2	op 4
	op 3				; B54D
	op 4
	ld a,(TANK_X)
	ld (hpos_p + 1),a
	op 3				; B552
	op 4
	ld a,(MISSILE_X)
	ld (hpos_m),a
	op 3				; B557
	op 4
	ld a,(SHELL_X)
	ld (hpos_p),a
	op 5				; B55C-B560
	taken
	; X counts scanlines ($5D on the first river line), the river ends when it wraps to 0;
	; Y walks the slots
	ld a,$5D
	ld (dl_counter),a
	ld a,(FIRST_SLOT)
	ld (dl_slot),a
	ld (dl_current),a
	xor a
	ld (dl_ended_b664),a
.slot_loop
	ld a,(dl_slot)
	ld (dl_current),a
	ld a,3 + 4			; B565 STY $06; B567: STA WSYNC
.wait	opa				; wait for the scanline where the slot's object starts
	wsync
.wait_check
	call .slot_y			; TXA, CMP $0C,Y (the slot's y in IXL while it waits)
	ld ixl,a
.wait_y	ld a,(dl_counter)
	cp ixl
	jr c,.wait_on
	ld (dl_start),a
	ld c,6 + 3 + 5			; there (BCS): B575 STX $04, INX
	call .count
	jp z,.exit_c
	jr .slot_fields
.wait_on
	inc a				; INX
	ld (dl_counter),a
	ld a,6 + 2 + 2 + 3 + 4		; not yet: BNE B567, STA WSYNC
	jr z,.wait_end
	ld a,(bm_line)			; STA WSYNC goes past the line's end: the next line starts
	inc a				; and is drawn (WSYNC holds the CPU until then), the
	cp RIVER_FIRST + RIVER_LINES	; count at 106 again (as STA WSYNC left it): straight
	jr nc,.wait_past		; in the river
	ld (bm_line),a
	call bm_draw
	jr .wait_y
.wait_past
	ld a,6 + 2 + 2 + 3 + 4
	jr .wait
.wait_end
	ld a,6 + 2 + 2 + 2 + 3 + 4 + 3	; the river's end: out through B5E3
	opa
	jp .end
.slot_fields
	; the slot (beyond the last one: zeros)
	ld a,(dl_slot)
	cp SLOTS
	jr nc,.sl
	ld e,a
	ld d,0
	ld hl,SLOT_Y
	add hl,de
	ld a,(hl)
	ld (dl_sl_y),a
	ld hl,SLOT_X
	add hl,de
	ld a,(hl)
	ld (dl_sl_x),a
	ld hl,SLOT_FLAGS
	add hl,de
	ld a,(hl)
	ld (dl_flags),a
	ld hl,SLOT_KIND
	add hl,de
	ld a,(hl)
	ld (dl_sl_kind),a
	ld hl,SLOT_TYPE
	add hl,de
	ld a,(hl)
	ld (dl_sl_type),a
	ld hl,SLOT_SIZE
	add hl,de
	ld a,(hl)
	ld (dl_sl_size),a
	jr .got
.sl	xor a
	ld (dl_sl_y),a
	ld (dl_sl_x),a
	ld (dl_flags),a
	ld (dl_sl_kind),a
	ld (dl_sl_type),a
	ld (dl_sl_size),a
.got	opc 4, 2 + 4			; B57A-B57D, STA HPOSP3
	ld a,(dl_sl_x)
	ld (hpos_p + 3),a
	opk 2, 5			; blank rows above the object
	call .p3_row
	ld (hl),0
	xor a
	call p3_scan
	op 5
	call .p3_row
	inc hl
	ld (hl),0
	xor a
	call p3_scan
	opk 7, 4			; $07; B58D
	wsync
	ld c,2 + 3
	ld a,(dl_flags)
	and $08
	jr z,.shapes
	ld c,2 + 2 + 2
.shapes	ld a,(dl_flags)			; the shape's address (mirrored frames +16)
	and $08
	add a,a
	ld hl,dl_sl_kind
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
	ld (dl_shapes),hl
	call .count			; CLC ... INX
	jr nz,1F
	ld a,c
	add a,17
	ld c,a
	jp .exit_c
1:	opc 4, 17 + 2 + 7		; B5A3-B5A8, STA SIZEP3
	ld a,(dl_sl_size)
	ld (size_p + 3),a
	opk 7, 4			; B5B0
	wsync
	ld a,(dl_sl_type)		; the colours' address
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
	ld (dl_colours),hl
	ld a,(dl_sl_type)		; the shape row on this scanline
	ld l,a
	ld h,0
	ld de,ROM_OBJECT_HEIGHT
	add hl,de
	ld a,(dl_sl_y)
	add a,(hl)
	ld hl,dl_start
	sub (hl)
	ld (dl_row),a
	ld c,29				; B5B3-B5C5
	call .count
	jp z,.exit_c
	ld a,(dl_row)			; not taken, TAY
	cp $80
	jr c,.rows_start
	ld a,(dl_current)		; B5C9: the object has gone: the next slot (JMP B565)
	inc a
	ld (dl_slot),a
	ld (dl_current),a
	ld a,29 + 2 + 2 + 3 + 5 + 3 + 4
	jp .wait
.rows_start
	; the row loop keeps its pointers in registers (the beam's events keep them): DE the
	; shape's row, HL its colour, IY player 3's memory at the scanline counter, B the
	; cycles of the instructions not yet counted
	ld hl,(dl_shapes)
	ld a,h
	ld (dl_shapes_hi),a
	call .row_hl
	ex de,hl
	ld hl,(dl_colours)
	ld a,h
	ld (dl_colours_hi),a
	call .row_hl
	ld a,(dl_counter)
	ld iyl,a
	ld iyh,0
	ld bc,PM_P3_ROWS
	add iy,bc
	ld b,29 + 2 + 2 + 2		; (from B5B3, the branch not taken)
.row	ld a,(dl_shapes_hi)		; B5CB: one shape row per scanline, the bottom row first
	cp d				; (LDA 6 cycles when the index crosses a page)
	ld a,b
	adc a,5
	opa
	op 5
	ld a,(de)
	ld (iy+0),a
	ld c,a				; (p3_scan)
	ld a,(bm_line)
	cp iyl
	jr nc,1F
	ld a,c
	ld c,iyl
	ld b,high scan_p3
	ld (bc),a
1:
	op 4
	wsync
	; From here on (just past STA WSYNC, cycle 106) each row goes the same way while the
	; lines are the river's: the colour part starts the next line (ANTIC's cycles there),
	; writes the bank (a bridge's road) and player 3's colour before the line is drawn,
	; then the next row's shape part draws it, and STA WSYNC ends at 106 again. So the rows
	; after the first go straight (.fast), with the beam's count only worked out where the
	; loop is left.
	; The rows that go all the way straight (not a bridge, inside the river, the counter not
	; wrapping, a row left) are .tight: as many as all three allow, counted in IXL, the
	; pointers in registers, only what bm_draw reads written, the beam's count left as the
	; line drawn leaves it (106). The first row that may leave goes the long way (.fast_gen),
	; which works out the count.
.fast	ld a,(dl_flags)
	and $80
	jp nz,.fast_gen
	ld a,(bm_line)			; lines before the river's last
	ld c,a
	ld a,RIVER_FIRST + RIVER_LINES - 1
	sub c
	jp c,.fast_gen
	jp z,.fast_gen
	ld c,a
	ld a,low PM_P3_ROWS - 1		; INX before the counter wraps
	sub iyl
	jp z,.fast_gen
	cp c
	jr nc,1F
	ld c,a
1:	ld a,(dl_row)			; rows left
	cp c
	jr nc,1F
	or a
	jp z,.fast_gen
	ld c,a
1:	ld a,(dl_row)
	sub c
	ld (dl_row),a
	ld ixl,c
.tight	ld a,(bm_line)
	inc a
	ld (bm_line),a
	ld b,a
	ld a,(hl)			; player 3's colour
	ld (colour_p3),a
	inc iy				; INX, the row above
	dec de
	dec hl
	ld a,(de)			; its shape, latched if the line has not started
	ld (iy+0),a
	ld a,b
	cp iyl
	jr nc,1F
	ld b,high scan_p3
	ld c,iyl
	ld a,(de)
	ld (bc),a
1:	push de
	push hl
	call bm_draw
	pop hl
	pop de
	dec ixl
	jp nz,.tight
	ld a,iyl
	sub low PM_P3_ROWS
	ld (dl_counter),a
	ld ixh,LINE_CYCLES - WSYNC_CYCLE
.fast_gen
	ld a,(bm_line)
	inc a
	cp RIVER_FIRST + RIVER_LINES
	jr nc,.slow_colour
	ld (bm_line),a			; the next line starts, not drawn
	ld c,a
	xor a
	ld (bm_drawn),a
	ld b,high line_start
	ld a,(bc)
	ld (f_ls),a
	ld a,(dl_flags)
	and $80
	jr nz,.f_road
	ld a,(dl_colours_hi)		; BIT, BPL, LDA colour (11 or 12 cycles)
	cp h
	ld a,3 + 3
	adc a,5
	jr .f_colour
.f_road	push hl				; BIT, BPL, LDA road; STA COLBK; LDA colour
	ld hl,ROM_ROAD_COLOURS
	call .row_hl
	ld a,high ROM_ROAD_COLOURS
	cp h
	ld a,3 + 2
	adc a,4
	ld c,a
	ld a,(hl)
	ld (beam_bank),a
	push hl
	ld hl,rec_bank
	call rec_set
	pop hl
	pop hl
	ld a,(dl_colours_hi)
	cp h
	ld a,c
	adc a,4 + 5
.f_colour				; A: the cycles up to STA COLPM3
	ld c,a
	ld a,(hl)
	ld (colour_p3),a
	ld a,LINE_CYCLES - WSYNC_CYCLE + DRAW_CYCLE - 4	; the count after STA COLPM3
	sub c
	ld c,a
	ld a,(f_ls)
	ld b,a
	ld a,c
	sub b
	ld ixh,a
	jr .row_tail
.slow_colour
	ld a,(dl_flags)			; BIT $07
	and $80
	jr nz,.road
	ld a,(dl_colours_hi)		; BIT, BPL, LDA colour
	cp h
	ld a,3 + 3
	adc a,5
	opa
	jr .row_colour
.road	push hl				; a bridge: the road across the bank (BIT, BPL, LDA road)
	ld hl,ROM_ROAD_COLOURS
	call .row_hl
	ld a,high ROM_ROAD_COLOURS
	cp h
	ld a,3 + 2
	adc a,4
	opa
	op 4
	ld a,(hl)
	ld (beam_bank),a
	push hl
	ld hl,rec_bank
	call rec_set
	pop hl
	pop hl
	ld a,(dl_colours_hi)		; LDA colour
	cp h
	ld a,0
	adc a,5
	opa
.row_colour
	op 4
	ld a,(hl)
	ld (colour_p3),a
.row_tail
	inc iy				; INX
	ld a,(dl_counter)
	inc a
	ld (dl_counter),a
	jr nz,.row_on
	ld a,2 + 3 + 4 + 3		; wrapped: out through B5E3
	opa
	jp .end
.row_on	dec de				; the row above
	dec hl
	ld a,(dl_row)			; DEY, BPL
	dec a
	ld (dl_row),a
	ld b,2 + 2 + 2 + 2
	jp m,.rows_end
	ld b,2 + 2 + 2 + 3
	ld a,(bm_line)			; the next row's shape part, straight: the line drawn
	cp RIVER_FIRST + RIVER_LINES	; (before or after player 3's row is written: it is
	jp nc,.row			; latched already), STA WSYNC to cycle 106
	ld a,(bm_drawn)
	or a
	jp nz,.row
	ld a,(de)
	ld (iy+0),a
	ld c,a				; (p3_scan)
	ld a,(bm_line)
	cp iyl
	jr nc,1F
	ld a,c
	ld c,iyl
	ld b,high scan_p3
	ld (bc),a
1:	inc a
	ld (bm_drawn),a
	push de
	push hl
	call bm_draw
	pop hl
	pop de
	ld ixh,LINE_CYCLES - WSYNC_CYCLE
	jp .fast
.rows_end
	; The collisions of this object (B5E8 on). The cycles of instructions nothing on screen
	; sees (branches, INX, the game's own memory) go with the next one that something sees
	; (opk, opc: C cycles more).
	ld a,b				; DEY, BPL
	add a,3
	ld c,a
	opc 4, 0			; LDA M2PL: the bullet touched player 3
	ld a,(coll_mpl + 2)
	and $08
	ld c,2 + 3
	jr z,.b5f3
	ld a,(dl_current)
	ld (HIT_BULLET_OBJECT),a
	ld c,2 + 2 + 3
.b5f3	opc 4, 0			; B5F3 STA WSYNC
	wsync
	ld a,(dl_flags)
	and $80
	jr nz,.bridge_end
	opk 3 + 4, 4			; LDA P3PL: player 3 touched the shell
	ld a,(coll_ppl + 3)
	and $01
	ld c,2 + 3
	jr z,.b60a
	ld a,(dl_current)
	ld (HIT_SHELL_OBJECT),a
	ld c,2 + 2 + 3
	jr .b60a
.bridge_end
	opk 3 + 2 + 3, 4		; a bridge: the bank colour back
	ld a,(SECTION_BANK_COLOUR)
	ld (beam_bank),a
	push hl
	ld hl,rec_bank
	call rec_set
	pop hl
	ld c,3
.b60a	call .count			; B60A INX
	jr nz,1F
	ld a,c
	add a,2 + 3
	ld c,a
	jp .end_c
1:	opc 4, 2 + 2			; LDA P2PL: the plane touched players
	ld a,(coll_ppl + 2)
	ld (dl_touched),a
	and $01
	ld c,2 + 3
	jr z,.p_obj
	ld a,(dl_current)
	ld (HIT_PLANE_SHELL),a
	ld c,2 + 2 + 3
.p_obj	ld a,(dl_touched)
	and $08
	jr nz,.plane_obj
	opc 4, 2 + 3			; LDA P3PF: the object touched the bank edge
	jr .edge
.plane_obj
	ld a,(dl_current)
	ld (HIT_PLANE_OBJECT),a
	opc 4, 2 + 2 + 3
.edge	ld a,(coll_ppf + 3)
	and $02
	ld (dl_touched),a
	opk 2, 4			; B61F STA WSYNC
	wsync
	ld a,(dl_current)
	cp SLOTS
	jr nc,.e1
	ld e,a
	ld d,0
	ld hl,SLOT_FLAGS
	add hl,de
	ld a,(hl)
	and $FE
	ld b,a
	ld a,(dl_touched)
	or a
	ld a,b
	jr z,.e0
	or 1
.e0	ld (hl),a
.e1	call .count			; INX
	jr nz,1F
	ld c,10 + 5 + 2 + 3
	jp .end_c
1:	opk 10 + 5 + 2 + 2, 4		; LDA M0PL: the missile touched the plane
	ld a,(coll_mpl)
	and $04
	jr nz,.m_plane
	opk 2 + 3, 4			; LDA M0PF: bank or edge
	jr .m_bank
.m_plane
	ld a,(dl_current)
	ld (HIT_MISSILE_PLANE),a
	opk 2 + 2 + 3, 4
.m_bank	ld a,(coll_mpf)
	and $03
	jr nz,.m_bank_hit
	opk 2 + 3, 4			; LDA P1PF: the tank reached the edge
	jr .tank
.m_bank_hit
	ld a,(dl_current)
	ld (HIT_MISSILE_BANK),a
	opk 2 + 2 + 3, 4
.tank	ld a,(coll_ppf + 1)
	and $02
	ld (dl_touched),a
	op 4				; B645 STA WSYNC
	wsync
	ld a,(dl_touched)
	or a
	jr nz,.tank_hit
	opk 2 + 3, 4			; LDA P2PF: the plane touched the bank
	jr .plane_bank
.tank_hit
	ld a,(dl_current)
	ld (HIT_TANK_AT_EDGE),a
	opk 2 + 2 + 3, 4
.plane_bank
	ld a,(coll_ppf + 2)
	and $01
	jr nz,.plane_bank_hit
	opk 2 + 3, 4			; LDA M2PF: bank or edge
	jr .bullet_bank
.plane_bank_hit
	ld a,(dl_current)
	ld (HIT_PLANE_BANK),a
	opk 2 + 2 + 3, 4
.bullet_bank
	ld a,(coll_mpf + 2)
	and $03
	jr nz,.bullet_bank_hit
	opk 2 + 3, 4			; B65F HITCLR
	jr .hitclr
.bullet_bank_hit
	ld a,(dl_current)
	ld (HIT_BULLET_BANK),a
	opk 2 + 2 + 3, 4
.hitclr	call bm_hitclr
	ld a,(dl_current)
	inc a
	ld (dl_slot),a
	call .count			; INX, BNE
	jr nz,.loop_on
	ld a,1
	ld (dl_ended_b664),a
	ld c,4 + 3 + 3
	jp .end_c
.loop_on				; JMP B565
	ld a,(dl_slot)
	ld (dl_current),a
	ld a,4 + 2 + 3 + 3 + 4
	jp .wait
.exit_c	ld a,c				; the loop left through B5E3 (C cycles before)
	add a,3 + 4 + 3
	ld c,a
	jp .end_c
.end	; B66B: the end of the river; the panel's part reads the collisions of the object still
	; in progress, unless the loop ended right after a HITCLR
	ld c,0
.end_c	opc 4, 0
	wsync
	op 4
	xor a
	ld (hpos_p + 1),a
	op 4
	ld (hpos_p),a
	op 4
	ld (hpos_m),a
	op 31
	ld a,(RESPAWNED)
	or a
	jr z,.r_taken
	not_taken
	op 3
	ld a,(PLAYER)
	or a
	jr z,.r_p
	not_taken
	op 2
	jr .r_done
.r_p	taken
	jr .r_done
.r_taken
	taken
.r_done	op 7
	ld a,(PLANE_STATE)
	or a
	jr z,.ps_taken
	not_taken
	op 3
	ld a,(PLANE_STATE)
	ld hl,ATTRACT_FLAGS
	or (hl)
	and $80
	jr nz,.ps_t2
	not_taken
	op 5
	ld a,(FRAME_COUNT)
	and $30
	jr nz,.ps_t3
	not_taken
	op 7
	jr .ps_done
.ps_t3	taken
	jr .ps_done
.ps_t2	taken
	jr .ps_done
.ps_taken
	taken
.ps_done
	op 8
	op 4				; B6B4
	wsync
	op 15
	ld a,(dl_current)
	cp SLOTS
	jr c,.last
	taken
	ret
.last	not_taken
	op 8
	ld a,(dl_ended_b664)
	or a
	jr z,.last2
	taken
	ret
.last2	not_taken
	op 4
	ld a,(dl_current)
	ld e,a
	ld d,0
	ld hl,SLOT_FLAGS
	add hl,de
	ld a,(coll_ppf + 3)
	rrca
	and 1
	ld b,a
	ld a,(hl)
	and $FE
	or b
	ld (hl),a
	op 17
	op 4
	ld a,(coll_mpl)
	and $04
	ld de,HIT_MISSILE_PLANE
	call nz,.hit_current
	op 7
	op 4
	ld a,(coll_mpf)
	and $03
	ld de,HIT_MISSILE_BANK
	call nz,.hit_current
	op 7
	op 4
	ld a,(coll_mpf + 2)
	and $03
	ld de,HIT_BULLET_BANK
	call nz,.hit_current
	op 7
	op 4
	ld a,(coll_ppf + 2)
	and $01
	ld de,HIT_PLANE_BANK
	call nz,.hit_current
	op 7
	op 4
	ld a,(coll_ppl + 2)
	and $01
	ld de,HIT_PLANE_SHELL
	call nz,.hit_current
	ld a,(coll_ppl + 2)
	and $08
	ld de,HIT_PLANE_OBJECT
	call nz,.hit_current
	op 14
	op 4
	ld a,(coll_ppl + 3)
	and $01
	ld de,HIT_SHELL_OBJECT
	call nz,.hit_current
	op 7
	op 4
	ld a,(coll_ppf + 1)
	and $02
	ld de,HIT_TANK_AT_EDGE
	call nz,.hit_current
	op 7
	op 4
	ld a,(coll_mpl + 2)
	and $08
	ld de,HIT_BULLET_OBJECT
	call nz,.hit_current
	ld a,ixh			; finish: the events up to the next instruction
	dec a
	call m,bm_events
	ret
.hit_current
	ld a,(dl_current)
	ld (de),a
	ret
.rec_init				; record HL of register DE (scan page B, from line C)
	ld a,(de)
	ld (hl),a
	inc hl
	ld (hl),c
	inc hl
	ld (hl),b
	ret
.p3_row					; HL = player 3's row at the scanline counter
	ld a,(dl_counter)
	ld l,a
	ld h,0
	ld de,PM_P3_ROWS
	add hl,de
	ret
.p3_row_keep_a
	push af
	call .p3_row
	pop af
	ret
.count					; INX; Z when it wraps to 0
	ld hl,dl_counter
	inc (hl)
	ret
.slot_y					; A = the slot's y ($FF after the last)
	ld a,(dl_slot)
	cp SLOTS
	ld a,$FF
	ret nc
	ld a,(dl_slot)
	ld e,a
	ld d,0
	ld hl,SLOT_Y
	add hl,de
	ld a,(hl)
	ret
.row_hl					; HL += dl_row
	ld a,(dl_row)
	add a,l
	ld l,a
	adc a,h
	sub l
	ld h,a
	ret
.crosses				; op(6) if HL's page is crossed by + dl_row, else op(5)
	ld a,(dl_row)
	add a,l
	ld a,5
	adc a,0
	jp bm_op
.crosses_minus1				; op(5) if crossed, else op(4)
	ld a,(dl_row)
	add a,l
	ld a,4
	adc a,0
	jp bm_op

	else
	include "display_simple.asm"
	endif
