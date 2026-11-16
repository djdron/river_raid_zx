; POKEY's 4-bit and 5-bit polynomial counters at the 64 kHz ticks (tick k: bit 28k),
; a byte each, 64 bytes apart. Made by tools/mkpoly.
poly5:
	db 1,1,0,0,0,0,1,0,1,1,0,1,0,1,0,0,0,1,1,1,0,1,1,1,1,1,0,0,1,0,0
	ds 64 - 31
poly4:
	db 1,1,0,0,1,0,0,0,1,1,1,1,0,1,0
	ds 64 - 15
