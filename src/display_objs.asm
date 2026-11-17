; (page 4, before the palette's alignment: display_simple.asm's page is full)

; The object's rows for the sprites (build_sprites): the scanline of its first row, how many,
; the address of the first row's byte (DE) and colour (IY), its position and size. 8 bytes
; in ds_objs. DE, BC, IY kept.
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
	push bc
	push iy
	pop bc				; (BC: the colour's address)
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
	ld a,(ds_x)
	ld (hl),a
	inc hl
	ld a,(ds_size)
	ld (hl),a
	pop de
	ret
