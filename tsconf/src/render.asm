; A generated line as the picture shows it, in the 16-colour mode: the 2-bit colour indices of
; the playfield (0 the background, 1 the bank, 2 the bank edge, 3 the water), two dots per
; colour clock (a byte: both nibbles the index), colour clocks WINDOW_FIRST..WINDOW_FIRST +
; 159 of the 192: 160 bytes at the start of the line's 256. One palette (PAL_RIVER): 2 the
; edge, 3 the water (apply), the bank in its colour's entry (1 or 9.., bank_init), set by
; line_bank only when the line's colour changes (by a bridge): nothing switched per line.

WINDOW_FIRST	equ 20		; the first colour clock shown (the water never comes nearer)

WINDOW_END	equ WINDOW_FIRST / 4 + 40	; the byte after the last shown
RL_DMA_MIN	equ 5		; a run of one value this long or longer: filled by the DMA

; By draw_line's pieces (dl_seg): bytes of one value are one colour, 8 dots each; an edge's
; bytes (from its piece in the table at $B800) and a decoration's row (from its bitmap)
; through the line's set of tables (its values both nibbles). Into the picture's line HL (0-511,
; more wraps), through window 1 (put back to WORK_PAGE at the end).
render_line:
	push ix
	push hl
	call line_bank
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
.kind	jp nz,.table			; (kind 1: one value, E; .table or .table_k: line_bank)
	ld d,high rl_k1			; (its colour: the bank's the line's, line_bank)
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
.t	ld ixl,c			; (IXL: the bytes left)
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
	dec ixl
	jr nz,.byte
	jp .next
.table_k
	ld a,(iy+1)			; a road line: an edge's bytes through the first green's set,
	or a				; its bank dots in the road colour's entry (rl_sub)
	jr nz,1F
	ld d,high ROM_EDGE_PIECES
1:	ld ixl,c
	ld a,(rl_sub)
	ld ixh,a
.tkb	ld a,(de)
	ld c,a
	inc de
	ld b,high pix_set0
	rept 4
	ld a,(bc)
	cp $11
	jr nz,$ + 4
	ld a,ixh
	ld (hl),a
	inc l
	inc b
	endr
	dec ixl
	jr nz,.tkb
	jp .next
.end	ld bc,PAGE1
	ld a,WORK_PAGE
	out (c),a
	pop ix
	ret

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
.entry	ld hl,rl_colour			; the same colour as the line before: nothing to change
	cp (hl)
	ret z
	ld (hl),a
	ld hl,bank_cols			; its place in bank_cols (none: the first; bank_init has them
	ld bc,(bank_n - 1)		; all), its entry: 1, then 9..
	ld c,0
.find	cp (hl)
	jr z,.found
	inc hl
	inc c
	djnz .find
	ld c,0
.found	ld a,c
	or a
	ld b,1
	jr z,1F
	add a,8
	ld b,a
1:	ld a,b				; both nibbles
	add a,a
	add a,a
	add a,a
	add a,a
	or b
	ld (rl_k1 + $55),a		; the bank's runs in it
	ld (rl_sub),a
	ld a,c				; the edges' and decorations' bytes: the greens' own sets,
	ld hl,render_line.table		; a road colour's through the first green's (.table_k)
	ld b,high pix_set0
	or a
	jr z,3F
	ld b,high pix_set1
	dec a
	jr z,3F
	ld b,high pix_set0
	ld hl,render_line.table_k
3:	ld a,b
	ld (rl_set),a
	ld (render_line.kind + 1),hl
	ret

; The bank's colours into the river's palette (CRAM group 0): the two greens ($D2, $D6), then
; the road's by the bridge (the cartridge's table at $B4E5, its 20 rows), each once: entries 1,
; then 9.. (2 and 3 are the edge's and the water's, 4-8 the panel's)
bank_init:
	ld a,$FF			; (line_bank: no colour yet)
	ld (rl_colour),a
	ld a,$7E			; (no bridge yet: the green on the first line)
	ld (road_row),a
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

; The dots' tables of the two greens (bank_cols' first two), always there: pix_set0 and
; pix_set1, 4 pages each: page k's byte b is b's dot k as the picture has it (both nibbles): 0,
; 2, 3 themselves, 1 the green's entry (1, 9). rl_k1: a run's value (0, $55, $AA, $FF) as its
; colour, the bank's set by line_bank. At the start (bank_init)
pix_sets:
	ld e,1
	ld h,high pix_set0
	call .one
	ld e,9
	ld h,high pix_set1
	call .one
	ld hl,rl_k1
	ld (hl),0
	ld l,$AA
	ld (hl),$22
	ld l,$FF
	ld (hl),$33
	ret
.one	ld c,0				; C: the dot
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
	ret
