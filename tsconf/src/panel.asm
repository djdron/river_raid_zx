; The panel's characters: the game's writes into them, only what changed (panel_put lists
; it for panel_frame). Page 6.

; The numbers printed last forgotten: printed again next time
pb_forget:
	ld a,$FF
	ld (sl_last),a
	ld (pb_cache),a
	ld (pb_cache + 4),a
	ld (pb_cache + 8),a
	ld (pb_cache + 12),a
	ret

; A character into the panel (at DE: panel_put_de; at HL: panel_put), only if it changed:
; then its position is listed for panel_frame (pf_dirty; past 59 of them: all). AF only.
panel_put_de:
	ex de,hl
	call panel_put
	ex de,hl
	ret
panel_put:
	cp (hl)
	ret z
	ld (hl),a
	push hl
	push de
	ld e,l				; (PANEL at $1000: L is the position)
	ld hl,pf_dirty_n
	ld a,(hl)
	cp 60
	jr nc,.done
	inc (hl)
	ld hl,pf_dirty
	add a,l
	ld l,a
	jr nc,1F
	inc h
1:	ld (hl),e
.done	pop de
	pop hl
	ret

; The panel's characters ($1000, 40 per row)

; sub $AF5B: the lives as plane symbols (the newest blinks while the bonus sounds).
show_lives:
	ld a,(LIVES)
	ld c,a
	or a
	jr z,.s
	ld a,(SOUND_BONUS)
	and 8
	jr z,.s
	dec c
.s	ld a,c				; the same number as printed last: nothing to do
	ld hl,sl_last
	cp (hl)
	ret z
	ld (hl),a
	ld a,$FF			; (its row's other bridges, if printed, are gone)
	ld (pb_cache + 12),a
	ld hl,PANEL + PANEL_LIVES
	ld b,9
	ld e,0
.l	ld a,e
	cp c
	ld a,LIFE_SYMBOL
	jr c,.w
	xor a
.w	call panel_put
	inc hl
	inc e
	djnz .l
	ret

show_bridges:
	ld hl,BRIDGES
	ld b,2
	ld de,PANEL + PANEL_BRIDGES
	ld c,DIGITS_BRIDGES
	jr print_bcd
show_score:
	ld hl,SCORE
	ld b,3
	ld de,PANEL + PANEL_SCORE
	ld c,DIGITS_SCORE
	jr print_bcd
show_other_score:
	ld hl,SCORE
	ld b,3
	ld de,PANEL + PANEL_HIGH_SCORE
	ld c,DIGITS_OTHER
	jr print_bcd
show_high_score:
	ld a,(GAME_NUMBER)
	and $0E
	add a,a
	add a,HIGH_SCORE
	ld l,a
	ld h,0
	ld b,3
	ld de,PANEL + PANEL_HIGH_SCORE
	ld c,DIGITS_HIGH_SCORE

; B086-B0C6: B BCD bytes at HL as digits at DE, '0' = C, leading zeros blank; nothing in the
; attract mode.
print_bcd:
	ld a,(ATTRACT_FLAGS)
	rla
	ret c
	ld a,e				; the same digits as printed there last: nothing to do
	ld ix,pb_cache			; (pb_cache: per place, the digits' base and the BCD bytes)
	cp low (PANEL + PANEL_SCORE)
	jr z,.slot
	ld ix,pb_cache + 4
	cp low (PANEL + PANEL_HIGH_SCORE)
	jr z,.slot
	ld ix,pb_cache + 8
	cp low (PANEL + PANEL_BRIDGES)
	jr z,.slot
	ld ix,pb_cache + 12		; the other bridges: over the lives (show_lives prints them
	ld a,$FF			; again)
	ld (sl_last),a
.slot	ld a,c
	cp (ix + 0)
	jr nz,.new
	push ix
	push hl
	push bc
.cmp	ld a,(hl)
	cp (ix + 1)
	jr nz,.diff
	inc hl
	inc ix
	djnz .cmp
	pop bc
	pop hl
	pop ix
	ret
.diff	pop bc
	pop hl
	pop ix
.new	ld (ix + 0),c
	push hl
	push bc
.keep	ld a,(hl)
	ld (ix + 1),a
	inc hl
	inc ix
	djnz .keep
	pop bc
	pop hl
	ld a,1
	ld (pb_leading),a
.byte	ld a,(hl)
	rrca
	rrca
	rrca
	rrca
	and $0F
	call .digit
	ld a,(hl)
	and $0F
	call .digit
	inc hl
	djnz .byte
	ret
.digit	jr nz,.show
	ld a,(pb_leading)
	or a
	jr z,.show
	xor a
	call panel_put_de
	inc de
	ret
.show	add a,c
	call panel_put_de
	inc de
	xor a
	ld (pb_leading),a
	ret

