; (page 4: display_simple.asm's page is full)

; The object's rows for the sprites (build_sprites): the scanline of its first row, how many,
; the address of the first row's byte (DE) and colour (IY), its position and size. 8 bytes
; in ds_objs. DE, BC (the colour's address), IY (the slot's fields) kept.
ds_obj:
	ld a,(ds_obj_n)
	cp DS_OBJS
	jr c,1F
	ld (ds_obj_over),a		; (too many: the sprites from the scanlines)
	ret
1:	inc a
	ld (ds_obj_n),a
	ld a,(ds_current)
	ld (ds_obj_slot),a
	ld a,(ds_obj_n)
	dec a
	push de
	add a,a
	add a,a
	add a,a
	add a,low ds_objs
	ld l,a
	adc a,high ds_objs
	sub l
	ld h,a
	ld (ds_obj_last),hl
	push bc				; (BC: the colour's address)
	ld a,(ds_counter)
	sub $44
	cp RIVER_FIRST + 1		; its first row on the river's first line or above: the rows
	jr nc,2F			; the DLI did not get to (start - y) on the lines above, as
	push hl				; the sprite's rows too, from the object's top row (the clip
	ld hl,ds_start			; window hides them): the same pattern while it comes in
	ld a,(ds_y)
	sub (hl)
	neg				; (k = start - y)
	ld l,a
	ld h,0
	add hl,de
	ex de,hl
	ld l,a
	ld h,0
	add hl,bc
	ld b,h
	ld c,l
	ld l,a
	ld a,(ds_rows)
	add a,l
	ld (ds_obj_t),a
	ld a,(ds_counter)
	sub $44
	sub l
	pop hl
	ld (hl),a
	inc hl
	ld a,(ds_obj_t)
	jr 3F
2:	ld (hl),a
	inc hl
	ld a,(ds_rows)
3:	ld (hl),a
	push hl				; the rows for the sprites (ds_objf): all of them, also
	push af				; those past the river's end, which the DLI did not get to
	ld a,(ds_obj_n)			; (the sprites' window hides them: copper_panel), so an
	add a,low (ds_objf - 1)		; object's pattern stays the same while it goes out
	ld l,a
	adc a,high (ds_objf - 1)
	sub l
	ld h,a
	ld a,(ds_row)
	inc a
	push hl
	ld hl,ds_rows
	sub (hl)
	pop hl
	ld (hl),a
	pop af
	add a,(hl)
	ld (hl),a
	pop hl
	inc hl
	ld (hl),e
	inc hl
	ld (hl),d
	inc hl
	ld (hl),c
	inc hl
	ld (hl),b
	inc hl
	pop bc
	ld a,(iy + 22)			; (IY: the slot's fields, display)
	ld (hl),a
	inc hl
	ld a,(iy + 33)
	ld (hl),a
	pop de
	ret
