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
PANEL_FIRST	equ 190		; the panel's first (NTSC)

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
; In: A = IXH - 1; out: the same for the new IXH.
bm_events:
	push hl
	push bc
	inc a
.loop	ld ixh,a
	ld a,(bm_drawn)
	or a
	jr nz,.next_line
	inc a				; drawn at 28 - IXH: collisions, the record
	ld (bm_drawn),a
	ld a,(bm_any)
	or a
	jr z,.record
	push de
	call collide
	pop de
.record	ld a,(bm_line)			; the line's record (scan_*: by scanline)
	ld l,a
	ld h,high scan_p3
	ld a,(bm_p + 3)
	ld (hl),a
	inc h
	ld a,(hpos_p + 3)
	ld (hl),a
	inc h
	ld a,(size_p + 3)
	ld (hl),a
	inc h
	ld a,(colour_p3)
	ld (hl),a
	inc h
	ld a,(beam_bank)
	ld (hl),a
.after	ld a,(bm_line)			; then refresh and screen data
	ld l,a
	ld h,high line_after_draw
	ld a,ixh
	add a,(hl)
	jr .check
.next_line				; at 114 - IXH: the next line from its start cycles
	xor a
	ld (bm_drawn),a
	ld hl,bm_line
	inc (hl)
	ld l,(hl)
	ld h,high PM_MISSILES		; latch the players' and missiles' data
	ld a,(hl)
	ld (bm_m),a
	ld c,a
	inc h
	ld a,(hl)
	ld (bm_p),a
	or c
	ld c,a
	inc h
	ld a,(hl)
	ld (bm_p + 1),a
	or c
	ld c,a
	inc h
	ld a,(hl)
	ld (bm_p + 2),a
	or c
	ld c,a
	inc h
	ld a,(hl)
	ld (bm_p + 3),a
	or c
	ld (bm_any),a
	ld a,l				; the line's screen memory (0 outside the river)
	sub RIVER_FIRST
	jr z,.top
	cp RIVER_LINES
	jr nc,.off
	ld bc,(cl_line)			; 48 bytes on, round the two blocks
	ld a,c
	add a,48
	ld c,a
	jr nc,.b
	inc b
.b	ld a,b
	cp $2F
	jr nz,.b1
	ld b,$30
.b1	cp $3F
	jr nz,.b2
	ld b,$20
.b2	ld (cl_line),bc
	jr .start
.top	ld bc,(SCREEN_TOP)
	ld (cl_line),bc
	jr .start
.off	ld bc,0
	ld (cl_line),bc
.start	ld h,high line_start
	ld a,ixh
	add a,DRAW_CYCLE
	sub (hl)
.check	dec a				; due again?
	jp m,.again
	pop bc
	pop hl
	ret
.again	inc a
	jp .loop

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
	ld l,PANEL_FIRST		; the panel: mode 6 with an address
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

collide:					; (cl_line: the playfield of the line, 0 outside the river)
	ld a,(bm_p)			; only player 3 (the usual): its mask and the playfield
	ld hl,bm_p + 1
	or (hl)
	inc hl
	or (hl)
	ld hl,bm_m
	or (hl)
	jp nz,.all
	ld hl,(cl_line)			; only player 3 (the usual): with the playfield, if any
	ld a,h
	or a
	ret z
	ld a,(size_p + 3)		; normal width: its 3 mask bytes, straight
	and 3
	cp 1
	jp z,.wide
	cp 3
	jp z,.wide
	ld a,(hpos_p + 3)
	ld c,a
	and 3
	ld e,a
	add a,a
	add a,e
	add a,high dsh_tables
	ld d,a
	ld a,(bm_p + 3)
	ld e,a
	ld a,c
	srl a
	srl a
	sub 8				; the first screen byte
	ld c,a
	ld b,e
	ld e,a				; HL: the line's byte (if on the line)
	add a,a
	sbc a,a
	push de
	ld d,a
	ld hl,(cl_line)
	add hl,de
	pop de
	ld e,b
	ld b,0				; the colours under it
	ld a,c				; all 3 bytes on the line: no checks
	cp 48 - 2
	jr nc,.edge3
	rept 3
	ld a,(de)
	and (hl)
	jr z,1F
	push hl
	ld l,a
	ld h,high pf_class
	ld a,(hl)
	or b
	ld b,a
	pop hl
1:	inc hl
	inc d
	endr
	ld a,b
	ld hl,coll_ppf + 3
	or (hl)
	ld (hl),a
	ret
.edge3	rept 3
	ld a,c
	cp 48
	jr nc,1F
	ld a,(de)
	and (hl)
	jr z,1F
	push hl
	ld l,a
	ld h,high pf_class
	ld a,(hl)
	or b
	ld b,a
	pop hl
1:	inc hl
	inc d
	inc c
	endr
	ld a,b
	ld hl,coll_ppf + 3
	or (hl)
	ld (hl),a
	ret
.wide	ld a,(bm_p + 3)			; q: the bits doubled once or twice for wider sizes
	ld hl,cl_q
	ld (hl),a
	ld b,1
	ld a,(size_p + 3)
	and 3
	cp 1
	jr z,.q2
	cp 3
	jr nz,.qs
	ld l,(hl)			; quadruple: 4 bytes
	ld h,high double_hi
	ld e,(hl)
	inc h
	ld d,(hl)
	ld l,e
	ld a,(hl)
	dec h
	ld c,(hl)
	ld (cl_q),bc			; (C, then A below)
	ld (cl_q + 1),a
	ld l,d
	ld a,(hl)
	ld (cl_q + 2),a
	inc h
	ld a,(hl)
	ld (cl_q + 3),a
	ld b,4
	jr .qs
.q2	ld l,(hl)			; double: 2 bytes
	ld h,high double_hi
	ld a,(hl)
	inc h
	ld c,(hl)
	ld (cl_q),a
	ld a,c
	ld (cl_q + 1),a
	ld b,2
.qs	ld a,(hpos_p + 3)		; the tables of the shift; the first screen byte
	ld c,a
	and 3
	ld e,a
	add a,a
	add a,e
	add a,high dsh_tables
	ld (cl_tables),a
	ld a,c
	srl a
	srl a
	sub 8
	ld c,a				; C: the screen byte
	ld e,a				; HL: the line's byte C (C may be off the line: then not read)
	add a,a
	sbc a,a
	ld d,a
	ld hl,(cl_line)
	add hl,de
	ld ixl,0			; the colours under it
	ld de,cl_q
.qb	push bc				; each q: its 3 mask bytes from byte 2i
	push de
	push hl
	ld a,(de)
	ld e,a
	ld a,(cl_tables)
	ld d,a
	ld b,3
.fb	ld a,c
	cp 48
	jr nc,.fn
	ld a,(de)			; mask AND screen: the covered pixels
	and (hl)
	jr z,.fn
	push hl
	ld l,a
	ld h,high pf_class
	ld a,(hl)
	or ixl
	ld ixl,a
	pop hl
.fn	inc hl
	inc d
	inc c
	djnz .fb
	pop hl				; the next q: 2 bytes on
	inc hl
	inc hl
	pop de
	inc de
	pop bc
	inc c
	inc c
	djnz .qb
	ld a,ixl
	ld hl,coll_ppf + 3
	or (hl)
	ld (hl),a
	ret
.all	xor a				; which sprites are on this line
	ld (sp_active),a
	ld b,0				; players
.player	push bc
	ld hl,bm_p
	call .index
	ld a,(hl)
	or a
	jr z,.p_next
	ld d,a
	ld hl,hpos_p
	call .index
	ld e,(hl)
	ld hl,size_p
	call .index
	ld a,(hl)
	call sprite_mask
	call sprite_playfield
	ld e,a
	pop bc
	push bc
	ld hl,coll_ppf
	call .index
	ld a,e
	or (hl)
	ld (hl),a
	call .set_active
.p_next	pop bc
	inc b
	ld a,b
	cp 4
	jr c,.player
	ld a,(bm_m)			; missiles: 2 bits each
	ld c,a
	ld a,(size_m)
	ld (cl_size_m),a
.missile
	push bc
	ld a,c
	and 3
	jr z,.m_next
	rrca				; the 2 bits at the top, like a player's first two
	rrca
	ld d,a
	ld a,b
	sub 4
	ld hl,hpos_m
	add a,l
	ld l,a
	adc a,h
	sub l
	ld h,a
	ld e,(hl)
	ld a,(cl_size_m)
	call sprite_mask
	call sprite_playfield
	ld e,a
	pop bc
	push bc
	ld hl,coll_mpf - 4
	call .index
	ld a,e
	or (hl)
	ld (hl),a
	call .set_active
.m_next	ld hl,cl_size_m
	srl (hl)
	srl (hl)
	pop bc
	srl c
	srl c
	inc b
	ld a,b
	cp SPRITES
	jr c,.missile
	ld a,(sp_active)		; with each other, if more than one
	ld b,a
	dec a
	and b
	ret z
	ld b,0				; sprite n
.pn	ld a,(sp_active)
	call .bit_b
	jr z,.pn_next
	ld c,0				; player k
.pk	ld a,b
	cp c
	jr z,.pk_next
	ld a,(sp_active)
	push bc
	ld b,c
	call .bit_b
	pop bc
	jr z,.pk_next
	push bc
	call sprites_overlap
	pop bc
	jr nc,.pk_next
	ld hl,coll_ppl			; P?PL / M?PL |= 1 << k
	ld a,b
	cp 4
	jr c,.pl_p
	ld hl,coll_mpl - 4
.pl_p	call .index
	push bc
	ld a,1
	inc c
.shift	dec c
	jr z,.or
	add a,a
	jr .shift
.or	pop bc
	or (hl)
	ld (hl),a
.pk_next
	inc c
	ld a,c
	cp 4
	jr c,.pk
.pn_next
	inc b
	ld a,b
	cp SPRITES
	jr c,.pn
	ret
.index					; HL += B
	ld a,b
	add a,l
	ld l,a
	adc a,h
	sub l
	ld h,a
	ret
.bit_b					; Z: bit B of A clear
	push bc
	inc b
.bb	dec b
	jr z,.bt
	rrca
	jr .bb
.bt	pop bc
	and 1
	ret
.set_active				; sp_active |= 1 << B
	ld a,1
	inc b
.sa	dec b
	jr z,.sa_set
	add a,a
	jr .sa
.sa_set	ld hl,sp_active
	or (hl)
	ld (hl),a
	ret

; Sprite B's mask: graphics bits D (first at bit 7), position E, size A (SIZEP/SIZEM bits).
; Each bit covers 1, 2 or 4 colour clocks: the bits doubled (2 mask bits a clock) give 1, 2
; or 4 bytes q (the bits; then each doubled again, once or twice), and each q doubled and
; shifted right by the clock within the first byte is 3 bytes from dsh_tables, ORed in at
; byte 2i: a mask of 3, 5 or 9 bytes.
sprite_mask:
	ld c,a
	ld a,e
	ld (sm_hpos),a
	ld a,b
	add a,a
	add a,a
	add a,a
	add a,a
	ld (sm_base),a
	ld hl,sm_src			; q
	ld a,c
	and 3
	cp 3
	jr z,.w4
	cp 1
	jr z,.w2
	ld (hl),d			; 1 clock a bit: q = the bits
	ld b,1
	jr .mask
.w2	ld l,d				; 2 clocks: q = the bits doubled
	ld h,high double_hi
	ld a,(hl)
	inc h
	ld e,(hl)
	ld hl,sm_src
	ld (hl),a
	inc l
	ld (hl),e
	ld b,2
	jr .mask
.w4	ld l,d				; 4 clocks: doubled twice
	ld h,high double_hi
	ld c,(hl)
	inc h
	ld e,(hl)
	ld l,c
	ld a,(hl)			; (double_lo of the first)
	dec h
	ld c,(hl)
	ld hl,sm_src
	ld (hl),c
	inc l
	ld (hl),a
	ld l,e
	ld h,high double_hi
	ld c,(hl)
	inc h
	ld a,(hl)
	ld hl,sm_src + 2
	ld (hl),c
	inc l
	ld (hl),a
	ld b,4
.mask	ld a,b				; length: 2 * q + 1
	add a,a
	inc a
	ld (sm_bytes),a
	ld a,(sm_base)			; cleared
	ld l,a
	ld h,high sp_mask
	ld a,(sm_bytes)
	ld c,a
	xor a
.clr	ld (hl),a
	inc l
	dec c
	jr nz,.clr
	ld a,(sm_hpos)			; the tables of this shift
	and 3
	ld c,a
	add a,a
	add a,c
	add a,high dsh_tables
	ld (sm_shr),a
	ld de,sm_src
	ld a,(sm_base)
	ld (sm_shl),a			; (where q's 3 bytes go)
.q	ld a,(de)
	inc e
	push de
	ld e,a
	ld a,(sm_shr)
	ld d,a
	ld a,(sm_shl)
	ld l,a
	ld h,high sp_mask
	ld a,(de)
	or (hl)
	ld (hl),a
	inc l
	inc d
	ld a,(de)
	ld (hl),a
	inc l
	inc d
	ld a,(de)
	ld (hl),a
	ld a,(sm_shl)
	add a,2
	ld (sm_shl),a
	pop de
	djnz .q
	ld a,(sm_base)			; its length and first byte
	rrca
	rrca
	rrca
	rrca
	ld e,a
	ld d,0
	ld hl,sp_len
	add hl,de
	ld a,(sm_bytes)
	ld (hl),a
	ld hl,sp_u
	add hl,de
	ld a,(sm_hpos)
	srl a
	srl a
	ld (hl),a
	ret

; Playfield colours under the sprite whose mask was just built: A bits 1 bank, 2 edge,
; 4 water (pf_class gives them for a byte of covered pixels).
sprite_playfield:
	ld hl,(cl_line)
	ld a,h
	or a
	ret z				; no playfield on this line (A = 0)
	ld a,(sm_hpos)
	srl a
	srl a
	sub 8				; the first screen byte (may be outside the line)
	ld c,a
	ld a,(sm_bytes)
	ld b,a
	ld a,(sm_base)
	ld e,a
	ld d,high sp_mask
	xor a
	ld (sp_pf),a
.byte	ld a,c
	cp 48
	jr nc,.next			; outside the line (left of it as well: negative)
	ld hl,(cl_line)
	add a,l
	ld l,a
	adc a,h
	sub l
	ld h,a
	ld a,(de)
	and (hl)			; the covered pixels
	jr z,.next
	ld l,a
	ld h,high pf_class
	ld a,(sp_pf)
	or (hl)
	ld (sp_pf),a
.next	inc e
	inc c
	djnz .byte
	ld a,(sp_pf)
	ret

; Do sprites B and C overlap on the line? Carry: yes.
sprites_overlap:
	ld hl,sp_u
	ld a,b
	call .at
	ld d,a				; u of B
	ld a,c
	call .at
	ld e,a				; u of C
	ld hl,sp_len
	ld a,b
	call .at
	add a,d
	ld (so_end_b),a
	ld a,c
	call .at
	add a,e
	ld (so_end_c),a
	ld a,d				; from the larger start, but not left of the line
	cp e
	jr nc,.s1
	ld a,e
.s1	cp 8
	jr nc,.s2
	ld a,8
.s2	ld (so_u),a
.loop	ld a,(so_u)
	cp 8 + 48			; not right of the line
	jr nc,.no
	ld hl,so_end_b
	cp (hl)
	jr nc,.no
	ld hl,so_end_c
	cp (hl)
	jr nc,.no
	push de
	sub d				; B's byte
	ld l,a
	ld a,b
	add a,a
	add a,a
	add a,a
	add a,a
	add a,l
	ld l,a
	ld h,high sp_mask
	ld a,(hl)
	ld (so_byte),a
	ld a,(so_u)
	sub e				; C's byte
	ld l,a
	ld a,c
	add a,a
	add a,a
	add a,a
	add a,a
	add a,l
	ld l,a
	ld a,(so_byte)
	and (hl)
	pop de
	jr nz,.yes
	ld hl,so_u
	inc (hl)
	jr .loop
.yes	scf
	ret
.no	or a
	ret
.at	push hl
	add a,l
	ld l,a
	adc a,h
	sub l
	ld h,a
	ld a,(hl)
	pop hl
	ret

; ------------------------------------------------------------------------------------------
; The DLI, frame by frame (B500-B6BC, B6C5-B727)

display:
	ld (dl_sp),sp			; scan = {}: zeros pushed
	ld hl,0
	ld a,high scan_p3
	ld c,5
.clear	ld d,a
	ld e,RIVER_FIRST + RIVER_LINES
	ex de,hl
	ld sp,hl
	ex de,hl
	ld b,RIVER_LINES / 8
.cl	push hl
	push hl
	push hl
	push hl
	djnz .cl
	inc a
	dec c
	jr nz,.clear
	ld sp,(dl_sp)
	ld hl,0				; the line before the river: no playfield
	ld (cl_line),hl
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
	ld a,23				; (its players latched: rows 23 of player-missile memory)
	ld (bm_line),a
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
	inc h
	ld a,(hl)
	ld (bm_p + 3),a
	ld hl,bm_p			; anything on the line
	or (hl)
	inc hl
	or (hl)
	inc hl
	or (hl)
	ld hl,bm_m
	or (hl)
	ld (bm_any),a
	ld a,1				; drawn, at cycle 76
	ld (bm_drawn),a
	ld ixh,LINE_CYCLES - 76
	ld a,(colour_bank)		; set by the VBI
	ld (beam_bank),a
	ld a,(SLOT_SIZE + SLOTS - 1)
	ld (size_p + 3),a
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
	call .slot_y			; TXA, CMP $0C,Y
	ld b,a
	ld a,(dl_counter)
	cp b
	jr c,.wait_on
	ld (dl_start),a
	ld a,6 + 3 + 5			; there (BCS): B575 STX $04, INX
	opa
	call .count
	jp z,.exit
	jr .slot_fields
.wait_on
	call .count			; INX
	ld a,6 + 2 + 2 + 3 + 4		; not yet: BNE B567, STA WSYNC
	jr nz,.wait
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
.got	ld a,2 + 4			; B57A-B57D
	opa
	op 4
	ld a,(dl_sl_x)
	ld (hpos_p + 3),a
	op 2				; blank rows above the object
	op 5
	call .p3_row
	ld (hl),0
	op 5
	call .p3_row
	inc hl
	ld (hl),0
	op 7				; $07
	op 4				; B58D
	wsync
	op 2
	ld a,(dl_flags)
	and $08
	jr nz,.left
	taken
	jr .shapes
.left	not_taken
	op 2
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
	op 17				; CLC ... INX
	call .count
	jp z,.exit
	not_taken
	op 7				; B5A3-B5A8
	op 4
	ld a,(dl_sl_size)
	ld (size_p + 3),a
	op 7
	op 4				; B5B0
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
	op 29				; B5B3-B5C5
	call .count
	jp z,.exit
	not_taken
	op 2				; TAY
	ld a,(dl_row)
	cp $80
	jr c,.rows_start
	taken				; B5C9: the object has gone: the next slot
	op 5
	ld a,(dl_current)
	inc a
	ld (dl_slot),a
	jp .slot_loop
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
	ld b,2				; (the branch not taken)
.row	ld a,(dl_shapes_hi)		; B5CB: one shape row per scanline, the bottom row first
	cp d				; (LDA 6 cycles when the index crosses a page)
	ld a,b
	adc a,5
	opa
	op 5
	ld a,(de)
	ld (iy+0),a
	op 4
	wsync
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
	jp .row
.rows_end
	ld a,b				; B5E8: the collisions of this object
	add a,3
	opa
	op 4
	ld a,(coll_mpl + 2)		; M2PL: the bullet touched player 3
	and $08
	ld b,a
	op 2
	ld a,b
	or a
	jr nz,.bullet
	taken
	jr .b5f3
.bullet	not_taken
	op 3
	ld a,(dl_current)
	ld (HIT_BULLET_OBJECT),a
.b5f3	op 4				; B5F3
	wsync
	op 3
	ld a,(dl_flags)
	and $80
	jr nz,.bridge_end
	taken_far
	op 4
	ld a,(coll_ppl + 3)		; P3PL: player 3 touched the shell
	and $01
	ld b,a
	op 2
	ld a,b
	or a
	jr nz,.shell
	taken
	jr .b60a
.shell	not_taken
	op 3
	ld a,(dl_current)
	ld (HIT_SHELL_OBJECT),a
	jr .b60a
.bridge_end
	not_taken			; a bridge: the bank colour back
	op 3
	op 4
	ld a,(SECTION_BANK_COLOUR)
	ld (beam_bank),a
	op 3
.b60a	op 2				; B60A INX
	call .count
	jp z,.taken_end
	not_taken
	op 4
	ld a,(coll_ppl + 2)		; P2PL: the plane touched players
	ld (dl_touched),a
	op 2
	ld a,(dl_touched)
	and $01
	jr nz,.plane_shell
	taken
	jr .p_obj
.plane_shell
	not_taken
	op 3
	ld a,(dl_current)
	ld (HIT_PLANE_SHELL),a
.p_obj	op 2
	ld a,(dl_touched)
	and $08
	jr nz,.plane_obj
	taken
	jr .edge
.plane_obj
	not_taken
	op 3
	ld a,(dl_current)
	ld (HIT_PLANE_OBJECT),a
.edge	op 4
	ld a,(coll_ppf + 3)		; P3PF: the object touched the bank edge
	and $02
	ld (dl_touched),a
	op 2
	op 4				; B61F
	wsync
	op 10
	op 5
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
.e1	op 2
	call .count
	jp z,.taken_end
	not_taken
	op 4
	ld a,(coll_mpl)			; M0PL: the missile touched the plane
	and $04
	ld b,a
	op 2
	ld a,b
	or a
	jr nz,.m_plane
	taken
	jr .m_bank
.m_plane
	not_taken
	op 3
	ld a,(dl_current)
	ld (HIT_MISSILE_PLANE),a
.m_bank	op 4
	ld a,(coll_mpf)			; M0PF: bank or edge
	and $03
	ld b,a
	op 2
	ld a,b
	or a
	jr nz,.m_bank_hit
	taken
	jr .tank
.m_bank_hit
	not_taken
	op 3
	ld a,(dl_current)
	ld (HIT_MISSILE_BANK),a
.tank	op 4
	ld a,(coll_ppf + 1)		; P1PF: the tank reached the edge
	and $02
	ld (dl_touched),a
	op 4				; B645
	wsync
	op 2
	ld a,(dl_touched)
	or a
	jr nz,.tank_hit
	taken
	jr .plane_bank
.tank_hit
	not_taken
	op 3
	ld a,(dl_current)
	ld (HIT_TANK_AT_EDGE),a
.plane_bank
	op 4
	ld a,(coll_ppf + 2)		; P2PF: the plane touched the bank
	and $01
	ld b,a
	op 2
	ld a,b
	or a
	jr nz,.plane_bank_hit
	taken
	jr .bullet_bank
.plane_bank_hit
	not_taken
	op 3
	ld a,(dl_current)
	ld (HIT_PLANE_BANK),a
.bullet_bank
	op 4
	ld a,(coll_mpf + 2)		; M2PF: bank or edge
	and $03
	ld b,a
	op 2
	ld a,b
	or a
	jr nz,.bullet_bank_hit
	taken
	jr .hitclr
.bullet_bank_hit
	not_taken
	op 3
	ld a,(dl_current)
	ld (HIT_BULLET_BANK),a
.hitclr	op 4				; B65F HITCLR
	call bm_hitclr
	op 4
	ld a,(dl_current)
	inc a
	ld (dl_slot),a
	call .count
	jr nz,.loop_on
	taken
	op 3
	ld a,1
	ld (dl_ended_b664),a
	jr .end
.loop_on
	not_taken
	op 3				; JMP B565
	jp .slot_loop
.exit	taken				; the loop left through B5E3
	exit_b5e3
	jr .end
.taken_end
	taken
.end	; B66B: the end of the river; the panel's part reads the collisions of the object still
	; in progress, unless the loop ended right after a HITCLR
	op 4
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
