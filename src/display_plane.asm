; (page 4, before the palette's alignment: display_simple.asm's page is full)

; NZ: the plane's rows (14 from $AA) touch the current object's (the last in ds_objs, if they
; are its), bit by bit (collide's pair test). P2PL's bit for player 3, read after the
; object's rows or at the river's end, sees only them since the HITCLR before them.
pl_touch:
	ld a,(ds_obj_slot)
	ld hl,ds_current
	cp (hl)
	jr nz,.no
	ld ix,(ds_obj_last)
	ld c,(ix + 0)			; the lines both are on: from max(first, $AA)
	ld a,c
	add a,(ix + 1)
	cp $AA + 14			; to min(first + rows, $AA + 14)
	jr c,1F
	ld a,$AA + 14
1:	ld e,a
	ld a,c
	cp $AA
	jr nc,1F
	ld a,$AA
1:	cp e
	jr nc,.no
	ld d,a
	sub c				; the object's row there: (the first) - (line - first)
	ld c,a
	ld b,0
	ld l,(ix + 2)
	ld h,(ix + 3)
	or a
	sbc hl,bc
.line	ld a,(hl)			; the object's bits
	or a
	jr z,.next
	push de
	push hl
	ld e,(ix + 6)
	ld d,a
	ld a,(ix + 7)
	ld b,3
	call collide.add
	pop hl
	pop de
	push de
	push hl
	ld h,high PM_PLANE		; the plane's
	ld l,d
	ld a,(hl)
	or a
	jr z,1F
	ld d,a
	ld a,(PLANE_X)
	ld e,a
	xor a
	ld b,2
	call collide.add
	ld hl,ds_obj_t
	ld (hl),0
	ld bc,2 << 8 | 3
	ld e,1
	call collide.pair
	ld a,(ds_obj_t)
	or a
1:	pop hl
	pop de
	ret nz
.next	dec hl
	inc d
	ld a,d
	cp e
	jr c,.line
.no	xor a
	ret

