; A generated line as the picture shows it, in the 16-colour mode: the 2-bit colour indices of
; the playfield (0 the background, 1 the bank, 2 the bank edge, 3 the water), two dots per
; colour clock (a byte: both nibbles the index), colour clocks WINDOW_FIRST..WINDOW_FIRST +
; 159 of the 192: 160 bytes at the start of the line's 256. One palette (PAL_RIVER): 2 the
; edge, 3 the water (apply), the bank in its colour's entry (1 or 9.., bank_init): the dots
; from the line's set of tables (line_bank, pix_sets).

WINDOW_FIRST	equ 20		; the first colour clock shown (the water never comes nearer)

WINDOW_END	equ WINDOW_FIRST / 4 + 40	; the byte after the last shown
RL_DMA_MIN	equ 5		; a run of one value this long or longer: filled by the DMA

; By draw_line's pieces (dl_seg): bytes of one value are one colour, 8 dots each; an edge's
; bytes (from its piece in the table at $B800) and a decoration's row (from its bitmap)
; through the line's set of tables (its values both nibbles). Into the picture's line HL (0-511,
; more wraps), through window 1 (put back to WORK_PAGE at the end; the tables through window 0,
; ATARI_PAGE back).
render_line:
	push ix
	push hl
	call line_bank
	ld bc,PAGE0			; the dots' tables at $0000 meanwhile (pix_sets)
	ld a,PIX_PAGE
	out (c),a
	pop hl
	ld a,h				; the page: VID_PAGE + line / 64
	and 1
	ld h,a
	ld a,l
	add hl,hl
	add hl,hl
	ld e,h
	and 63				; the line's place in it: (line & 63) x 256
	add a,$40
	ld h,a
	ld l,0
	ld a,e
	add a,VID_PAGE
	ld (rl_page),a
	ld bc,PAGE1
	out (c),a
	ld iy,dl_seg
	jr .seg
.next	ld bc,4
	add iy,bc
.seg	ld a,(iy+0)			; B: its first byte, C: past its last, in the window
	cp WINDOW_END
	jp nc,.end			; (the end: byte 48)
	ld b,a
	ld a,(iy+4)
	cp WINDOW_END
	jr c,1F
	ld a,WINDOW_END
1:	ld c,a
	ld e,(iy+2)			; DE: its data
	ld d,(iy+3)
	ld a,b
	sub WINDOW_FIRST / 4
	jr nc,2F
	neg				; (bytes before the window: past them in its data)
	ld b,WINDOW_FIRST / 4
	bit 0,(iy+1)
	jr nz,2F
	add a,e
	ld e,a
	jr nc,2F
	inc d
2:	ld a,c
	sub b
	jr c,.next
	jr z,.next
	ld c,a				; C: its bytes in the window
	ld a,(iy+1)
	dec a
	jr nz,.table			; (kind 1: one value, E)
	ld a,(rl_set)			; (the bank in its colour's entry: the line's set)
	ld d,a
	ld a,(de)
	ld b,a
	ld a,c				; a long run by the DMA (a fill from rl_word), while it is
	cp RL_DMA_MIN			; free (the CPU's own: the one before it, a reset's clearing)
	jr c,.cpu
	push bc
	ld bc,DMACTRL
	in a,(c)
	rla
	pop bc
	jr nc,.dma
.cpu	ld a,b
.fill	rept 4
	ld (hl),a
	inc l
	endr
	dec c
	jr nz,.fill
	jp .next
.dma	ld a,b
	ld (rl_word),a
	ld (rl_word + 1),a
	ld a,c				; E: its words - 1, D: the low byte after it
	add a,a
	ld e,a
	dec e
	add a,a
	add a,l
	ld d,a
	ld bc,DMASADDRX
	ld a,HIGH_PAGE
	out (c),a
	dec b
	ld a,high (rl_word - $C000)
	out (c),a
	dec b
	ld a,low rl_word
	out (c),a
	ld bc,DMADADDRX			; the picture's page, the line in it, the byte
	ld a,(rl_page)
	out (c),a
	dec b
	ld a,h
	sub $40
	out (c),a
	dec b
	out (c),l
	ld bc,DMALEN
	out (c),e
	ld bc,DMANUM
	xor a
	out (c),a
	ld bc,DMACTRL			; fill
	ld a,$04
	out (c),a
	ld l,d
	jp .next
.table	ld a,(iy+1)			; an edge's bytes: in the table's page
	or a
	jr nz,.t
	ld d,high ROM_EDGE_PIECES
.t	ld a,c
	ld (rl_count),a
	ld a,(rl_set)
	ld ixh,a
.byte	ld a,(de)
	ld c,a
	inc de
	ld b,ixh
	rept 3
	ld a,(bc)
	ld (hl),a
	inc l
	inc b
	endr
	ld a,(bc)
	ld (hl),a
	inc l
	ld a,(rl_count)
	dec a
	ld (rl_count),a
	jr nz,.byte
	jp .next
.end	ld bc,PAGE1
	ld a,WORK_PAGE
	out (c),a
	ld b,high PAGE0			; (the Atari's RAM back)
	ld a,ATARI_PAGE
	out (c),a
	pop ix
	ret

; The bank's colour of the line just generated (the C++ port's lineBankColour, from the state
; after it): a bridge's road colour by the row the line shows (y + height - $5E), else the
; frame's (bank_colour); rl_set its set of tables (pix_sets)
line_bank:
	ld a,(FIRST_SLOT)		; the slots from the top while one may show a road row on the
	cp NO_SLOT			; new line (y <= $5E; y grows down the slots)
	jr nc,.green
	ld e,a
	ld d,0
	ld hl,SLOT_Y
	add hl,de
.slot	ld a,(hl)
	cp $5F
	jr nc,.green
	push hl
	ld bc,SLOT_FLAGS - SLOT_Y
	add hl,bc
	bit 7,(hl)			; a bridge
	jr z,.nx
	ld c,a				; C: its y
	ld hl,SLOT_TYPE
	add hl,de
	ld a,(hl)
	add a,low ROM_OBJECT_HEIGHT
	ld l,a
	ld a,high ROM_OBJECT_HEIGHT
	adc a,0
	ld h,a
	ld a,c
	add a,(hl)
	sub $5E				; the row: y + height - $5E (y <= $5E: at most the height)
	jr c,.nx			; (none yet)
	add a,low ROM_ROAD_COLOURS
	ld l,a
	ld a,high ROM_ROAD_COLOURS
	adc a,0
	ld h,a
	ld a,(hl)
	pop hl
	jr .entry
.nx	pop hl
	inc hl
	inc e
	ld a,e
	cp NO_SLOT
	jr c,.slot
.green	call bank_colour
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

; The bank's colours into the river's palette (CRAM group 0): the two greens ($D2, $D6), then
; the road's by the bridge (the cartridge's table at $B4E5, its 20 rows), each once: entries 1,
; then 9.. (2 and 3 are the edge's and the water's, 4-8 the panel's)
bank_init:
	ld a,$FF			; (line_bank: no colour yet)
	ld (rl_colour),a
	xor a
	ld (bank_n),a
	ld a,$D2
	call .add
	ld a,$D6
	call .add
	ld hl,ROM_ROAD_COLOURS
	ld b,20
1:	ld a,(hl)
	push hl
	push bc
	call .add
	pop bc
	pop hl
	inc hl
	djnz 1B
	jr pix_sets
.add	ld e,a				; already there: nothing
	ld hl,bank_cols
	ld a,(bank_n)
	or a
	jr z,.new
	ld b,a
	ld a,e
2:	cp (hl)
	ret z
	inc hl
	djnz 2B
.new	ld a,(bank_n)
	cp BANK_COLS
	ret nc
	ld (hl),e
	inc a
	ld (bank_n),a
	cp 2				; its entry: 1, then 9..
	jr c,3F
	add a,7
3:	ld b,a
	xor a				; (group 0)
	jp cram_set

; The dots' tables, a set per bank colour (bank_cols' order), in PIX_PAGE (at $0000 while they
; are made, then while render_line draws): set i at 4 i x 256, its page k byte b's dot k (bits
; 7-6 first) as the picture has it (both nibbles): 0, 2, 3 themselves, 1 colour i's entry
; (1, then 9..). At the start (from init_video: window 0 back to INIT_PAGE)
pix_sets:
	ld bc,PAGE0
	ld a,PIX_PAGE
	out (c),a
	ld hl,0
	ld a,(bank_n)
	ld ixh,a			; IXH: the sets left, IXL: the set
	ld ixl,0
.set	ld a,ixl			; E: its entry
	ld e,1
	or a
	jr z,1F
	add a,8
	ld e,a
1:	ld c,0				; C: the dot
.page	ld l,0
.byte	ld a,l
	ld b,c
	inc b
2:	rlca
	rlca
	djnz 2B
	and 3
	cp 1
	jr nz,3F
	ld a,e
3:	ld d,a
	add a,a
	add a,a
	add a,a
	add a,a
	or d
	ld (hl),a
	inc l
	jr nz,.byte
	inc h
	inc c
	ld a,c
	cp 4
	jr c,.page
	inc ixl
	dec ixh
	jr nz,.set
	ld bc,PAGE0
	ld a,INIT_PAGE
	out (c),a
	ret
