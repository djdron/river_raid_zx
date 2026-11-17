; (page 4: sprites.asm's page is full)
; Player 3's lines into sprites when the DLI fell behind: runs of up to 16 lines at one
; position and size (lines with nothing to draw fit any run), from the DLI's record, each
; with its lines' colours (ob_emit).
p3_channel:
	ld l,RIVER_FIRST		; scanline
.find	ld h,high scan_p3
.scan	ld a,(hl)
	or a
	jr nz,.run
	inc l
	ld a,l
	cp RIVER_FIRST + RIVER_LINES
	jr c,.scan
	ret
.run	ld a,l
	ld (ob_line),a
	inc h
	ld d,(hl)			; its position
	inc h
	ld e,(hl)			; and size
	ld b,1				; lines in the run (the first fits)
	inc l
.line	ld a,b
	cp 16
	jr nc,.emit
	ld a,l
	cp RIVER_FIRST + RIVER_LINES
	jr nc,.emit
	ld h,high scan_p3
	ld a,(hl)
	or a
	jr z,.fits
	inc h
	ld a,(hl)
	cp d
	jr nz,.emit
	inc h
	ld a,(hl)
	cp e
	jr nz,.emit
.fits	inc l
	inc b
	jr .line
.emit	push hl
	ld a,b
	ld (ob_n),a
	ld a,(ob_line)
	ld l,a
	ld h,high scan_p3
	ld (ob_sh),hl
	ld h,high scan_col
	ld (ob_col),hl
	ld a,d
	ld (ob_x),a
	ld a,e
	ld (ob_size),a
	ld a,1
	ld (ob_nokey),a
	ld a,$23			; (INC HL, INC DE: the lines go down)
	ld (ob_write.step_sh),a
	ld a,$13
	ld (ob_write.step_col),a
	call ob_emit
	pop hl
	ld a,l
	cp RIVER_FIRST + RIVER_LINES
	jr c,.find
	ret

