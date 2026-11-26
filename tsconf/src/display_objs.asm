; (page 4: display_simple.asm's page is full)

; The object's rows for the sprites (ob_list): the line of its first row, the low bytes of
; the first row's shape and colour addresses (E, C), its position and size, into ds_objs
; (8 bytes an object, at ds_obj_p: bytes 1, 3 and 5, the Next's rows and high bytes, not
; used here; nor the Next's ds_objf). An object whose first line is at or above line 28 (the
; river's top) is moved up by k = start - y rows, its addresses on by k, so that its sprite
; is its whole shape and the clip window cuts it. DE, BC, IY kept.
ds_obj:
	ld a,(ds_obj_n)
	cp DS_OBJS
	ret nc				; (too many: not drawn)
	inc a
	ld (ds_obj_n),a
	ld hl,(ds_obj_p)
	ld a,(ds_counter)
	sub $44
	cp RIVER_FIRST + 1
	jr nc,.in
	push bc				; at the top: k rows more
	ld b,a
	ld a,(ds_y)
	ld c,a
	ld a,(ds_start)
	sub c
	ld c,a				; C: k
	ld a,b
	sub c
	ld (hl),a
	inc hl
	inc hl
	ld a,e
	add a,c
	ld (hl),a
	ld a,c
	pop bc
	add a,c
	jr .col
.in	ld (hl),a
	inc hl
	inc hl
	ld (hl),e
	ld a,c
.col	inc hl
	inc hl
	ld (hl),a
	inc hl
	inc hl
	ld a,(iy + 22)			; (IY: the slot's fields, display)
	ld (hl),a
	inc hl
	ld a,(iy + 33)
	ld (hl),a
	inc hl
	ld (ds_obj_p),hl
	ret
