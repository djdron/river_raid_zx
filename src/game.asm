; The game frame by frame, part 1: river_raid/port/src/game.cpp (Game::startAttract,
; prepare, the objects' movement, vbi). The rest of the main loop is in play.asm.
; Addresses in comments refer to the original cartridge code.

; ------------------------------------------------------------------------------------------
; POKEY's RANDOM ($D20A): a 17-bit polynomial counter stepping every machine cycle
; (river_raid/port/src/pokey_random.h). The game logic reads it at A205, always at the same
; point of the frame (scanline 192, cycle 13); rnd_state is the counter there in this frame.
random_read:				; A = the value read: bits 16-9
	ld a,(rnd_state + 1)
	ld b,a
	ld a,(rnd_state + 2)
	rra
	ld a,b
	rra
	ret

; The counter one frame (262 x 114 cycles) on: a linear map, random.inc has its columns.
random_step:
	ld hl,(rnd_state)
	ld ix,random_columns
	ld de,0
	ld c,d
	ld b,16
.bit	srl h
	rr l
	jr nc,.next
	ld a,e
	xor (ix+0)
	ld e,a
	ld a,d
	xor (ix+1)
	ld d,a
	ld a,c
	xor (ix+2)
	ld c,a
.next	inc ix
	inc ix
	inc ix
	djnz .bit
	ld a,(rnd_state + 2)
	rra
	jr nc,.done
	ld a,e
	xor (ix+0)
	ld e,a
	ld a,d
	xor (ix+1)
	ld d,a
	ld a,c
	xor (ix+2)
	ld c,a
.done	ld (rnd_state),de
	ld a,c
	ld (rnd_state + 2),a
	ret

; ------------------------------------------------------------------------------------------
; Bank colour of the frame (sub $AFD0): the shade switches while a bridge is still being
; drawn in near the top.
bank_colour:
	ld a,(BLOCK_FLAGS)
	and $04
	xor $D6
	ld c,a
	ld a,(ENTERING_SLOT)
	cp NO_SLOT
	ld a,c
	ret nc
	push hl
	push de
	ld a,(ENTERING_SLOT)
	ld e,a
	ld d,0
	ld hl,SLOT_FLAGS
	add hl,de
	bit 7,(hl)
	jr z,.done
	ld hl,SLOT_Y
	add hl,de
	ld a,(hl)
	cp $5C
	jr nc,.done
	ld a,c
	xor $04
	ld c,a
.done	ld a,c
	pop de
	pop hl
	ret

; ------------------------------------------------------------------------------------------
; The state of the attract mode at the frame its river starts (Game::startAttract): game 1,
; no plane, the first river line.
start_attract:
	ld hl,0				; the Atari's RAM cleared
	ld de,1
	ld bc,$3FFF
	ld (hl),l
	ldir
	call start_game			; the river: game 1 reset
	ld a,$0F			; GameState()
	ld (JOYSTICK),a
	ld hl,$2000
	ld (SCREEN_TOP),hl
	ld a,$20
	ld (colour_edge),a
	ld a,$84
	ld (colour_water),a
	call draw_logo_and_needle
	ld hl,ROM_PANEL_TEXT		; A0F0: the panel
	ld de,PANEL
	ld bc,60
	ldir
	ld a,$80
	ld (ATTRACT_FLAGS),a
	call set_up_game
	ld a,1
	ld (BULLET_Y),a
	ld (RESPAWNED),a
	ld (POWER_ON_DONE),a
	ld (SCREEN_ON),a
	ld a,4
	ld (LIVES),a
	ld (OTHER_LIVES),a
	ld a,$81
	ld (ATTRACT_FLAGS),a
	ld a,$FF
	ld (ATTRACT_TIMER),a
	ld (PLANE_STATE),a
	ld (FUEL),a
	ld (FUEL_FRAC),a
	ld a,$80
	ld (SPEED),a
	ld a,$7C
	ld (PLANE_X),a
	call bank_colour
	ld (colour_bank),a
	jp push_line

; sub $B0F1 leaves the rainbow under the logo and the fuel gauge's needle in player-missile
; memory.
draw_logo_and_needle:
	ld hl,PM_PLANE + $DB
	ld de,PM_P3 + $DB
	ld b,7
.logo	ld (hl),$FF
	ld a,$FC
	ld (de),a
	inc l
	inc e
	djnz .logo
	ld hl,PM_MISSILES + $CC
	ld b,10
.needle	ld (hl),$0C
	inc l
	djnz .needle
	ret

; ------------------------------------------------------------------------------------------
; A new river line at the top of the screen (Game::pushLine): the generator, screen memory
; (the address of the top line moves up by one line), and the line on Layer 2.
push_line:
	call next_line
line_done:				; the checks look at the generator here
	ld hl,(SCREEN_TOP)
	ld a,l
	sub 48
	ld l,a
	jr nc,.hi
	dec h
.hi	ld a,h
	cp $20
	jr nc,.h1
	ld h,$3E
.h1	cp $2F
	jr nz,.h2
	ld h,$2E
.h2	ld (SCREEN_TOP),hl
	ex de,hl
	ld hl,line_buf
	ld bc,48
	ldir
	call render_line
	ld a,(scroll)
	dec a
	ld (scroll),a
	add a,RIVER_TOP
	jp write_row

; ------------------------------------------------------------------------------------------
; AE99-AF38, at the top of the frame: the shapes of the tank, the helicopter missile, the
; tank shell and the plane into player-missile memory.
prepare:
	ld a,(TANK_Y)			; the tank: gone once below the screen
	ld c,a
	cp $BC
	jr c,.tank
	xor a
	ld (TANK_KIND),a
	ld (TANK_Y),a
.tank	ld a,(TANK_KIND)
	ld hl,ROM_TANK_SHAPE
	call .shape
	ld h,high PM_TANK
	ld l,c
	ld b,11
	call .copy
	ld a,(FRAME_COUNT)		; the shell's colour
	rrca
	rrca
	rrca
	and 7
	add a,low ROM_SHELL_COLOUR
	ld l,a
	ld h,high ROM_SHELL_COLOUR
	ld a,(hl)
	ld (shell_colour),a
	ld a,(MISSILE_Y)		; the helicopter's missile: one row, the two above cleared
	cp $1C
	jr c,.shell
	ld l,a
	ld h,high PM_MISSILES
	dec l
	dec l
	ld a,(hl)
	and $FC
	ld (hl),a
	inc l
	ld a,(hl)
	and $FC
	ld (hl),a
	inc l
	ld a,(hl)
	and $FC
	ld b,a
	ld a,(MISSILE_X)
	or a
	jr z,.m
	ld a,3
.m	or b
	ld (hl),a
.shell	ld a,(SHELL_Y)			; the shell: gone below the screen
	ld c,a
	cp $BC
	jr c,.s1
	ld a,$FF
	ld (SHELL_TIMER),a
	xor a
	ld (SHELL_FRAME),a
	ld (SHELL_Y),a
.s1	ld a,(SHELL_FRAME)
	ld hl,ROM_SHELL_SHAPE
	call .shape
	ld h,high PM_SHELL
	ld l,c
	ld b,16
	call .copy
	ld a,(PLANE_FRAME)
	ld hl,ROM_PLANE_SHAPE
	call .shape
	ld hl,PM_PLANE + $AA
	ld b,14
	call .copy
	ld a,(ATTRACT_TIMER)		; AF3A-AF58: lives, bridges and score into the panel
	or a
	call z,show_lives
	call show_bridges
	ld a,(PLAYER)
	or a
	jp z,show_score
	jp show_other_score
.shape					; DE = the pointer at HL + (2 * A & $FF)
	add a,a
	add a,l
	ld l,a
	jr nc,.s
	inc h
.s	ld e,(hl)
	inc hl
	ld d,(hl)
	ret
.copy					; sub $B00F: B rows from DE to HL, the last row first
	ld a,b
	dec a
	add a,l
	ld l,a
	jr nc,.c1
	inc h
.c1	ld a,b
	dec a
	add a,e
	ld e,a
	jr nc,.c
	inc d
.c	ld a,(de)
	ld (hl),a
	dec de
	dec hl
	djnz .c
	ret

; ------------------------------------------------------------------------------------------
; A21B-A26A: the tank on the road drives; at the river edge it fires.
drive_tank:
	ld a,(TANK_KIND)
	cp 4
	ld b,$0F
	jr c,.every
	cp 8
	jr nc,.every
	ld b,$03
.every	ld a,(FRAME_COUNT)
	and b
	ret nz
	ld a,(SHELL_TIMER)		; no shell in flight
	and $80
	jr z,.kind
	ld a,(ATTRACT_FLAGS)		; and the attract mode or a plane flying
	rla
	jr c,.fires
	ld a,(PLANE_STATE)
	or a
	jr nz,.kind
.fires
	ld a,(TANK_FIRES)
	and $80
	jr z,.bridge
	ld a,(TANK_Y)
	cp $1A
	jr c,.kind
	ld a,(HIT_TANK_AT_EDGE)
	and $80
	jr nz,.drive			; not at the river edge yet
	ld hl,SHELL_TIMER		; at the edge: fire
	inc (hl)
	jr .kind
.bridge	ld a,(BRIDGE_HIT)		; a tank on a bridge drives across
	or a
	jr nz,.kind
.drive	ld a,(TANK_KIND)
	and $7F
	cp 6
	ld hl,TANK_X
	jr nc,.left
	inc (hl)
	jr .kind
.left	dec (hl)
.kind	ld a,(TANK_KIND)
	bit 7,a
	ld a,3
	jr nz,.k
	ld a,(TANK_KIND)
	add a,low ROM_NEXT_TANK_KIND
	ld l,a
	ld a,high ROM_NEXT_TANK_KIND
	adc a,0
	ld h,a
	ld a,(hl)
.k	ld (TANK_KIND),a
	ret

; A26C-A2ED: animation and movement of the objects in the slots.
move_objects:
	ld a,(FIRST_SLOT)
	ld c,a
.slot	ld a,c
	cp SLOTS
	ret nc
	ld e,c
	ld d,0
	ld hl,SLOT_KIND
	add hl,de
	ld a,(hl)
	cp $0E				; bridges and depots stay put
	jp nc,.next
	cp $0C
	jr nc,.move
	ld b,$07			; animation every 8 frames, or 2 for kinds 7+
	cp 7
	jr c,.anim
	ld b,$01
.anim	ld a,(FRAME_COUNT)
	and b
	jr nz,.move
	ld a,(hl)
	push hl
	add a,low ROM_NEXT_KIND
	ld l,a
	ld a,high ROM_NEXT_KIND
	adc a,0
	ld h,a
	ld a,(hl)
	pop hl
	ld (hl),a
.move	ld a,(ATTRACT_FLAGS)		; nothing moves until the plane flies
	rla
	jr c,.level
	ld a,(PLANE_STATE)
	or a
	jr nz,.next
.level	ld a,(LEVEL)			; nothing moves before bridge 2
	srl a
	jr z,.next
	ld a,(hl)
	cp 7
	jr z,.step			; jets always fly
	jr c,.next			; not explosions
	cp $0C
	jr nz,.parity
	ld a,(FRAME_COUNT)		; balloons at half speed
	and 2
	jr nz,.next
.parity	ld a,(FRAME_COUNT)		; odd and even slots in turn
	xor c
	ld hl,SLOT_PARITY
	xor (hl)
	and 1
	jr nz,.next
	ld hl,SLOT_FLAGS
	add hl,de
	ld a,(hl)
	bit 6,a
	jr z,.next
	bit 0,a
	jr z,.free
	bit 4,a				; turn round once, at the first contact with the bank edge
	jr nz,.step
	xor $18
	ld (hl),a
	jr .step
.free	and $EF
	ld (hl),a
.step	ld hl,SLOT_FLAGS		; A2CA: one step, wrapping round the screen
	add hl,de
	bit 3,(hl)
	ld hl,SLOT_X
	add hl,de
	ld a,(hl)
	jr z,.right
	dec a
	cp $2C
	jr nc,.x
	ld a,$D4
	jr .x
.right	inc a
	cp $D5
	jr c,.x
	ld a,$2C
.x	ld (hl),a
.next	inc c
	jp .slot

; A5B7-A605: the shooting helicopter fires a missile the way it faces.
move_missile:
	ld b,0				; the new x
	ld a,(SHOOTER_SLOT)
	cp SLOTS
	jr nc,.set
	ld e,a
	ld d,0
	ld hl,SLOT_KIND
	add hl,de
	ld a,(hl)
	and $FE
	cp $0A
	jr nz,.set
	ld a,(MISSILE_X)
	or a
	jr z,.fire
	ld c,a				; flying until it hits the bank
	ld a,(HIT_MISSILE_BANK)
	and $80
	jr z,.set
	ld a,(MISSILE_STEP)
	add a,c
	ld b,a
	jr .set
.fire	ld a,(ATTRACT_FLAGS)		; not until the plane flies
	rla
	jr c,.f1
	ld a,(PLANE_STATE)
	or a
	jr nz,.set
.f1	ld hl,SLOT_Y
	add hl,de
	ld a,(hl)
	sub $3C
	cp $1C
	ret c				; too high on the screen: wait
	ld (MISSILE_Y),a
	ld a,9
	ld (SOUND_MISSILE),a
	ld hl,SLOT_X
	add hl,de
	ld a,(hl)
	sub 3
	ld b,a
	ld hl,SLOT_FLAGS
	add hl,de
	bit 3,(hl)
	ld a,$FE
	jr nz,.step
	ld a,b
	add a,10
	ld b,a
	ld a,2
.step	ld (MISSILE_STEP),a
.set	ld a,b
	ld (MISSILE_X),a
	ret

; A607-A671: the tank's shell flies across the river, then explodes.
move_shell:
	ld c,0				; the frame
	ld a,(SHELL_TIMER)
	bit 7,a
	jp nz,.done
	ld b,1				; count
	ld a,(TANK_KIND)
	cp 6
	sbc a,a
	ld (ms_right),a			; $FF: facing right
	ld a,(SHELL_TIMER)
	or a
	jr nz,.flight
	ld a,(TANK_Y)			; A60F: launch from the tank
	cp $19
	jr nc,.launch
	ld b,0				; the tank is too high: wait
	jr .count
.launch	sub 6
	ld (SHELL_Y),a
	xor a
	ld (SHELL_X_FRAC),a
	ld a,(ms_right)
	or a
	ld a,(TANK_X)
	jr z,.l_left
	add a,9				; ADC #9, SBC #4 with the carry of the sum
	ccf
	sbc a,4
	jr .l_set
.l_left	sub 4
.l_set	ld (SHELL_X),a
	ld c,1
	jr .count
.flight	cp $11
	jr nc,.explode
	ld e,a				; A62A: in flight
	ld d,0
	ld hl,ROM_SHELL_RISE
	add hl,de
	ld a,(SHELL_Y)
	add a,(hl)
	ld (SHELL_Y),a
	ld a,(ms_right)
	or a
	jr z,.f_left
	ld a,(SHELL_SPEED_FRAC)
	ld hl,SHELL_X_FRAC
	add a,(hl)
	ld (hl),a
	ld a,(SHELL_SPEED)
	ld hl,SHELL_X
	adc a,(hl)
	ld (hl),a
	jr .f_done
.f_left	ld a,(SHELL_SPEED_FRAC)
	ld e,a
	ld hl,SHELL_X_FRAC
	ld a,(hl)
	sub e
	ld (hl),a
	ld a,(SHELL_SPEED)
	ld e,a
	ld hl,SHELL_X
	ld a,(hl)
	sbc a,e
	ld (hl),a
.f_done	ld c,1
	jr .count
.explode				; A657: explosion frames
	sub $11
	rrca
	rrca
	rrca
	and $1F
	add a,2
	ld c,a
.count	ld a,b
	or a
	jr z,.done
	ld a,(SHELL_TIMER)		; A65E
	inc a
	cp $39
	jr c,.timer
	ld a,(PLANE_STATE)		; over: the tank fires again (no shell after a crash)
	or a
	ld a,0
	jr z,.again
	ld a,$FF
.again	ld c,0
.timer	ld (SHELL_TIMER),a
.done	ld a,c
	ld (SHELL_FRAME),a
	ret

; ------------------------------------------------------------------------------------------
; B2A5-B43E: the vertical blank: the sound driver's counters (the sound itself comes later),
; the frame counter, the colours of the next frame; POKEY's counter one frame on.
vbi:
	call sound_counters
	ld hl,FRAME_COUNT
	inc (hl)
	jr nz,.colours
	ld a,(ATTRACT_FLAGS)
	inc a
	and $C7
	ld (ATTRACT_FLAGS),a
	and 7
	jr nz,.colours
	ld hl,IDLE_TIME
	inc (hl)
	jr nz,.colours
	ld (hl),$80
.colours				; B3F2: the water flashes red while a hit bridge flashes
	ld c,$84
	ld a,(PAUSE_STATE)
	cp PAUSED
	jr nc,.water
	ld hl,BRIDGE_FLASH
	ld a,(hl)
	or a
	jr z,.water
	dec (hl)
	rra
	jr nc,.water
	ld c,$42
.water	ld a,c
	ld (colour_water),a
	ld a,$20
	ld (colour_edge),a
	call bank_colour		; sub $AFD0
	ld (colour_bank),a
	ld a,(SCREEN_ON)		; off while the screen is being cleared
	or a
	jp nz,random_step
	ld (colour_bank),a
	ld (colour_edge),a
	ld (colour_water),a
	jp random_step

; B2A5-B3D8: what the sound driver changes in the game's state.
sound_counters:
	ld hl,START_BEEP		; B2A6
	ld a,(hl)
	or a
	jr z,.pause
	dec (hl)
	ret
.pause	ld a,(PAUSE_STATE)		; B2BA
	cp PAUSED
	ret nc
	ld a,(EVENT_SOUND)		; B2D2: an event sound
	or a
	jr z,.engine
	ld hl,EVENT_SOUND_TIME
	dec (hl)
	jr nz,.ch2
	xor a
	ld (EVENT_SOUND),a
	jr .ch2
.engine	ld a,(PLANE_STATE)		; B2F9: only with the plane flying
	or a
	jr nz,.ch2
	ld a,(FUEL)			; B2FD: low fuel: a beep every 63 frames
	cp $40
	jr nc,.motor
	ld hl,EVENT_SOUND_TIME
	ld a,(hl)
	or a
	jr nz,.t
	ld a,$3F
.t	dec a
	ld (hl),a
	ld c,a
	ld a,(FUEL)
	cp 4
	jr nc,.first
	add a,a				; almost empty: a tone falling with the fuel
	add a,a
	ld b,a
	ld a,(FUEL_FRAC)
	rlca
	rlca
	and 3
	or b
	cpl
	add a,$20
	add a,a
	jr nz,.ch2			; the beep, not the engine
.first	ld a,c
	cp $1C
	jr nc,.ch2
.motor	ld hl,CRASH_PITCH		; B32C: the engine's pitch falls after a crash
	ld a,(hl)
	cp $1B
	jr c,.ch2
	dec (hl)
.ch2	ld hl,SOUND_EXPLOSION		; B352
	call .count
	ld hl,SOUND_MISSILE		; B367
	call .count
	ld hl,SOUND_FIRE		; B386
	call .count
	ld hl,SOUND_BONUS		; B399
.count	ld a,(hl)
	or a
	ret z
	dec (hl)
	ret
