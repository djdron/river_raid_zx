; POKEY's counter one frame on (NTSC, then PAL): the XOR of column j for each set bit j
; of the counter, 3 bytes each from the low one. Made by tools/mkrandom.
random_columns_ntsc:
	db $77,$2D,$01	; bit 0
	db $EE,$5A,$00	; bit 1
	db $DC,$B5,$00	; bit 2
	db $B9,$6B,$01	; bit 3
	db $72,$D7,$00	; bit 4
	db $92,$83,$00	; bit 5
	db $25,$07,$01	; bit 6
	db $4B,$0E,$00	; bit 7
	db $96,$1C,$00	; bit 8
	db $2D,$39,$00	; bit 9
	db $5A,$72,$00	; bit 10
	db $B5,$E4,$00	; bit 11
	db $6B,$C9,$01	; bit 12
	db $D7,$92,$01	; bit 13
	db $AE,$25,$01	; bit 14
	db $5D,$4B,$00	; bit 15
	db $BB,$96,$00	; bit 16
random_columns_pal:
	db $D7,$2F,$00	; bit 0
	db $AF,$5F,$00	; bit 1
	db $5E,$BF,$00	; bit 2
	db $BD,$7E,$01	; bit 3
	db $7A,$FD,$00	; bit 4
	db $22,$D5,$01	; bit 5
	db $45,$AA,$01	; bit 6
	db $8B,$54,$01	; bit 7
	db $17,$A9,$00	; bit 8
	db $2F,$52,$01	; bit 9
	db $5F,$A4,$00	; bit 10
	db $BF,$48,$01	; bit 11
	db $7E,$91,$00	; bit 12
	db $FD,$22,$01	; bit 13
	db $FA,$45,$00	; bit 14
	db $F5,$8B,$00	; bit 15
	db $EB,$17,$01	; bit 16
