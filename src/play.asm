; The game frame by frame, part 2: river_raid/port/src/game.cpp (the main loop: pause, the
; plane, the console keys, new games, crashes and respawns, the panel's contents).
; Addresses in comments refer to the original cartridge code.

RESUME_NEW_GAME		equ 1
RESUME_RESPAWN		equ 2

; ------------------------------------------------------------------------------------------
; A197-A6EA: the main loop. Returns early when a reset starts (new game, respawn): the rest
; runs when it ends (finish_reset).
main_loop:
	ld hl,in_stick			; A19E: any joystick, fire or console key: not idle, and
	ld a,(hl)			; no pause
	inc hl
	and (hl)
	cp $0F
	jr nz,.active
	ld a,(in_trig)
	ld b,a
	ld a,(in_console)
	or b
	jr z,.keys
.active	xor a
	ld (IDLE_TIME),a
	ld (PAUSE_STATE),a
.keys	ld a,(in_key)			; A1C5: pause with a key: press, release (paused), press,
	or a				; release (playing again)
	jr z,.k
	xor a
	ld (IDLE_TIME),a
	inc a
.k	ld c,a				; C: the key is down
	ld hl,PAUSE_STATE
	ld a,(hl)
	or a
	jr nz,.ps
	or c
	jr z,.go
	ld (hl),PAUSING
	ret
.ps	cp RESUMING
	jr nz,.ps2
	ld a,c
	or a
	jr nz,.go
	dec (hl)
	jr .go
.ps2	cp PAUSED
	jr nz,.ps3
	ld a,c
	or a
	ret z
	dec (hl)
	jr .go
.ps3	ld a,c
	or a
	ret nz
	dec (hl)
	ret
.go	ld a,(IDLE_TIME)		; A1F5: the screen is off after a long time without input
	rla
	ret c
	ld a,(FRAME_COUNT)		; A1FF: every 16 frames a random slot wakes up
	and $0F
	jr nz,.awake
	call random_read
	and $0F
	cp SLOTS
	jr c,.n
	sub 5
.n	ld c,a
	ld a,(ENTERING_SLOT)
	cp c
	jr z,.awake
	ld b,0
	ld hl,SLOT_FLAGS
	add hl,bc
	set 6,(hl)
.awake	call drive_tank
	call move_objects
	ld a,(ATTRACT_TIMER)		; A2F5: the attract timer, -1 every 8 frames; when it runs
	or a				; out after a game, the attract mode starts
	jr z,.stick
	ld a,(FRAME_COUNT)
	and 7
	jr nz,.stick
	ld a,(ATTRACT_TIMER)
	dec a
	jr nz,.t
	dec a
	ld hl,ATTRACT_FLAGS
	bit 7,(hl)
	jr nz,.t
	set 7,(hl)
	ld (ATTRACT_TIMER),a
	jp new_game
.t	ld (ATTRACT_TIMER),a
.stick	ld a,(PLAYER)			; A312: the joystick of the player whose turn it is
	and 1
	ld e,a
	ld d,0
	ld a,(JOYSTICK)
	add a,a
	add a,a
	add a,a
	add a,a
	ld (JOYSTICK_PREV),a
	ld hl,in_stick
	add hl,de
	ld a,(hl)
	and $0F
	ld (JOYSTICK),a
	ld a,(PLANE_STATE)		; A332: the waiting plane goes
	cp WAITING
	jr nz,.plane
	ld a,(JOYSTICK)
	cp $0F
	jr nz,.go_fly
	call player_trigger
	jr z,.plane
.go_fly	xor a
	ld (PLANE_STATE),a
	ld a,$40
	ld (SPEED),a
.plane	ld a,(PLANE_STATE)		; A33F: the plane
	or a
	jp m,.exploding
	jr z,.flying
	cp LIFE_LOST			; A348: the river refilling
	jr c,main_loop_end
	jr nz,.refill
	ld a,$80
	ld (CRASH_PITCH),a
	ld hl,LIVES
	dec (hl)
.refill	ld hl,PLANE_STATE
	dec (hl)
	jr main_loop_end
.flying	call fly_plane
	jr main_loop_end
.exploding				; A35C
	cp NO_PLANE
	jr z,main_loop_end
	inc a				; the explosion's frames
	and 7
	jr nz,.ex
	ld hl,PLANE_FRAME
	ld a,(hl)
	or a
	jr z,.ex
	dec (hl)
.ex	ld hl,PLANE_STATE
	dec (hl)
	bit 7,(hl)
	jr nz,main_loop_end
	call respawn_or_game_over
	ret c

; A5B7-A6EA: the rest of the main loop.
main_loop_end:
	call move_missile		; A5B7
	call move_shell			; A607
	ld a,(in_console)		; A673: console keys
	rra
	jr nc,.select
	ld a,2
	ld (START_BEEP),a
	xor a
	ld (ATTRACT_FLAGS),a
	ld (ATTRACT_TIMER),a
	jp new_game
.select	and 3
	jr z,.no
	ld hl,SELECT_DELAY		; A699: every 30 frames while held
	ld a,(hl)
	dec (hl)
	or a
	call z,select_game
	jr .scroll
.no	ld (SELECT_DELAY),a
.scroll	ld a,(PLANE_STATE)		; A6DE: scrolling
	or a
	jp p,.alive
	ld a,(ATTRACT_FLAGS)		; exploding: the river stops
	rla
	ret nc
	ld a,(GAME_NUMBER)		; A6F1: the attract mode
	cp 4
	ld a,$80
	jr c,.speed
	ld a,$FE
.speed	ld (SPEED),a
	jr scroll_river
.alive	cp WAITING			; the plane at the bridge: no scrolling
	jr nz,scroll_river
	ld a,9
	ld (PLANE_FRAME),a
	ret

; A6FD-A70F: the speed is added twice per frame to a fraction; each carry is a new line.
scroll_river:
	call .step
.step	ld a,(SPEED)
	cp $FE
	jp nc,push_line
	ld hl,SCROLL_FRAC
	add a,(hl)
	ld (hl),a
	ret nc
	jp push_line

; NZ when the fire button of the player whose turn it is is down
player_trigger:
	ld a,(PLAYER)
	rra
	ld a,(in_trig)
	jr nc,.t
	rra
.t	and 1
	ret

; ------------------------------------------------------------------------------------------
; A3E9-A5B4: the plane is flying.
fly_plane:
	ld a,(HIT_PLANE_OBJECT)		; A3E9: the plane touched an object
	bit 7,a
	jr nz,.shell
	ld c,a
	ld e,a
	ld d,0
	ld hl,SLOT_KIND
	add hl,de
	ld a,(hl)
	cp 7
	jr c,.shell
	cp $0F
	jr nc,.depot
	cp $0E				; an enemy or a bridge: both explode
	jr nz,.ram
	ld hl,BRIDGE_HIT
	inc (hl)
.ram	push bc
	ld b,CRASH_SOUND
	ld c,$1F
	call crash
	pop bc
	ld a,3
	jp explode
.depot	ld a,(FUEL)			; A40A: a fuel depot: +2 per frame
	add a,2
	ld b,REFUEL_SOUND
	jr nc,.f
	ld a,$FF
	ld (FUEL_FRAC),a
	ld b,TANK_FULL_SOUND
.f	ld (FUEL),a
	ld a,(EVENT_SOUND)
	cp b
	jr z,.shell
	ld a,b
	ld (EVENT_SOUND),a
	ld a,8
	ld (EVENT_SOUND_TIME),a
.shell	ld a,(SHELL_TIMER)		; A424: the tank shell exploding on the plane, the
	cp $11				; helicopter's missile, the bank
	ccf
	sbc a,a
	ld (fp_exploding),a
	ld d,a
	ld a,(HIT_PLANE_SHELL)
	and $80
	jr nz,.m
	or d
	jr nz,.crash
.m	ld a,(HIT_MISSILE_PLANE)
	and $80
	jr z,.crash
	ld a,(HIT_PLANE_BANK)
	and $80
	jr nz,.fuel
.crash	ld b,CRASH_SOUND
	ld c,$1F
	jp crash
.fuel	ld a,(FUEL_FRAC)		; A43F: fuel, $20 / 256 per frame
	sub $20
	jr nc,.ff
	ld b,a
	ld a,(FUEL)
	or a
	jr nz,.dec
	ld b,OUT_OF_FUEL_SOUND
	ld c,$23
	jp crash
.dec	dec a
	ld (FUEL),a
	ld a,b
.ff	ld (FUEL_FRAC),a
	call steer
	call change_speed
	ld a,(HIT_BULLET_OBJECT)	; A4B6: the bullet hit an object
	bit 7,a
	jr nz,.shelled
	ld c,a
	ld e,a
	ld d,0
	ld hl,SLOT_KIND
	add hl,de
	ld a,(hl)
	cp 7
	jr c,.shelled
	ld a,2
	jp explode
.shelled				; A4C1: the shell's explosion destroys an object
	ld a,(HIT_SHELL_OBJECT)
	bit 7,a
	jr nz,.bullet
	ld e,a
	ld d,0
	ld a,(fp_exploding)
	or a
	jr z,.bullet
	ld hl,SLOT_KIND
	add hl,de
	ld a,(hl)
	cp 8
	jr c,.bullet
	ld (hl),2
	ld a,$17
	ld (SOUND_EXPLOSION),a
.bullet	ld a,(HIT_BULLET_BANK)		; A58D: the bullet stops at the bank, flies up 6 lines
	and $80				; per frame, or is fired
	jr z,.stop
	ld a,(BULLET_Y)
	cp $1C
	jr c,.fire
	sub 6
	jp move_bullet
.fire	call player_trigger
	jr z,.stop
	ld a,$0F
	ld (SOUND_FIRE),a
	ld a,$A9
	jp move_bullet
.stop	ld a,1
	jp move_bullet

; A455-A496: steering. Left or right accelerates (+8 per frame up to $F8); the plane moves a
; pixel each time the fraction overflows. Plane frames 7/8/9: left / right / level.
steer:
	ld a,(JOYSTICK)
	ld c,a
	ld b,9
	and $0C
	cp $0C
	jr nz,.pressed
	xor a
	ld (PLANE_ACCEL),a
	ld (PLANE_X_FRAC),a
	jr .done
.pressed
	ld a,(PLANE_ACCEL)
	add a,8
	jr c,.full
	ld (PLANE_ACCEL),a
	ld e,a
	bit 3,c
	jr z,.right
	ld b,7				; left
	ld a,(PLANE_X_FRAC)
	sub e
	ld (PLANE_X_FRAC),a
	jr nc,.done
	ld hl,PLANE_X
	dec (hl)
	jr .done
.right	ld b,8
	ld a,(JOYSTICK_PREV)		; just pressed: move now
	bit 7,a
	ld a,$FF
	jr nz,.st
	ld a,(PLANE_X_FRAC)
.st	add a,e
	ld (PLANE_X_FRAC),a
	jr nc,.done
	ld hl,PLANE_X
	inc (hl)
	jr .done
.full	ld hl,PLANE_X			; at full speed: a pixel every frame
	bit 3,c
	jr z,.right_f
	ld b,7
	dec (hl)
	ld a,8
	ld (PLANE_X_FRAC),a
	jr .done
.right_f
	ld b,8
	inc (hl)
	xor a
	ld (PLANE_X_FRAC),a
.done	ld a,b
	ld (PLANE_FRAME),a
	ret

; A497-A4B5: speed: up +2 (up to $FE), down -2 (down to $40), neither: back towards $80.
change_speed:
	ld a,(JOYSTICK)
	ld c,a
	ld a,(SPEED)
	ld b,a
	bit 0,c
	jr z,.faster
	bit 1,c
	jr z,.slower
	cp $80
	ret z
	jr c,.faster
.slower	ld a,b
	cp $41
	ret c
	sub 2
	ld (SPEED),a
	ret
.faster	ld a,b
	cp $FE
	ret nc
	add a,2
	ld (SPEED),a
	ret

; A4E0-A589: the object in slot C explodes (kind A: 2 shot, 3 rammed); points.
explode:
	ld e,c
	ld d,0
	ld hl,SLOT_KIND
	add hl,de
	ld (hl),a
	ld hl,SLOT_TYPE
	add hl,de
	ld b,(hl)			; B: the type, for the points
	ld a,$17
	ld (SOUND_EXPLOSION),a
	ld a,b
	cp $0E
	jr nz,.points
	ld a,$17			; a bridge
	ld (BRIDGE_FLASH),a
	ld a,(BRIDGES + 1)		; the bridge counter +1
	add a,1
	daa
	ld (BRIDGES + 1),a
	ld a,(BRIDGES)
	adc a,0
	daa
	ld (BRIDGES),a
	ld hl,BRIDGE_HIT
	inc (hl)
	ld hl,SLOT_X
	add hl,de
	ld c,(hl)
	ld a,(TANK_X)			; A500: a tank on the bridge goes with it
	ld h,a
	ld a,c
	sub 8
	cp h
	jr nc,.no_tank
	ld a,c
	add a,$1F
	cp h
	jr c,.no_tank
	ld hl,TANK_KIND
	set 7,(hl)
	ld a,$37
	ld (SOUND_EXPLOSION),a
	ld b,$10
	jr .points
.no_tank				; A52B: from bridge 5 on, a tank close to the bridge fires
	ld a,(BRIDGES)
	or a
	jr nz,.fires
	ld a,(BRIDGES + 1)
	cp 5
	jr c,.points
.fires	ld a,(TANK_KIND)
	cp 6
	ld a,(TANK_X)
	jr nc,.tl
	ld l,a
	ld a,c
	sub l
	cp $29
	jr nc,.points
	jr .near
.tl	sub c
	cp $41
	jr nc,.points
.near	ld hl,SHELL_TIMER
	inc (hl)
.points	ld a,(SCORE + 1)		; A547: points (BCD); every 10 000 a new plane, up to 9
	and $F0
	ld c,a
	ld a,b
	add a,low ROM_POINTS
	ld l,a
	ld a,high ROM_POINTS
	adc a,0
	ld h,a
	ld a,(hl)
	ld hl,SCORE + 2
	add a,(hl)
	daa
	ld (hl),a
	dec hl
	ld a,(hl)
	adc a,0
	daa
	ld (hl),a
	dec hl
	ld a,(hl)
	adc a,0
	daa
	ld (hl),a
	jr nc,.bonus
	ld a,$99			; past 999 999: the game ends
	ld (hl),a
	inc hl
	ld (hl),a
	inc hl
	ld (hl),a
	xor a
	ld (LIVES),a
	ld b,CRASH_SOUND
	ld c,$1F
	jp crash
.bonus	ld a,(SCORE + 1)
	and $F0
	cp c
	jr z,.bullet
	ld a,(LIVES)
	cp 9
	jr z,.bullet
	inc a
	ld (LIVES),a
	ld a,$40
	ld (SOUND_BONUS),a
.bullet	ld a,1				; A589: the bullet is used up
	jp move_bullet

; sub $B1C0: the plane crashes, with event sound B of length C.
crash:
	ld a,c
	ld (EVENT_SOUND_TIME),a
	ld a,b
	ld (EVENT_SOUND),a
	ld a,(SLOT_FLAGS + SLOTS - 1)	; where the next plane starts: past a destroyed bridge,
	ld hl,BLOCK_FLAGS		; from the next section; on the run-up to a bridge not
	xor (hl)			; hit, one checkpoint back
	and 4
	jr z,.plane
	ld a,(BRIDGE_HIT)
	or a
	jr z,.not_hit
	bit 7,(hl)
	call nz,section_checkpoint
	jr .plane
.not_hit
	bit 7,(hl)
	jr nz,.plane
	ld a,(LEVEL)
	dec a
	cp $4E
	jr nz,.l
	ld a,$50
.l	ld (LEVEL),a
	ld hl,PREV_CHECKPOINT
	ld de,CHECKPOINT
	ld bc,4
	ldir
.plane	ld a,6				; B200
	ld (PLANE_FRAME),a
	ld a,CRASHED
	ld (PLANE_STATE),a
	xor a
	ld (ATTRACT_TIMER),a
	jp remove_plane_things

; sub $B21A: no plane (game over or attract mode). Leaves the carry clear.
game_over_screen:
	ld a,$FF
	ld (FRAME_COUNT),a
	ld (PLANE_STATE),a
	ld (ATTRACT_TIMER),a
	call remove_plane_things
	or a
	ret

; B204-B220: the bullet and the helicopter's missile go.
remove_plane_things:
	xor a
	call draw_bullet
	ld a,NO_SLOT
	ld (SHOOTER_SLOT),a
	ifdef BEAM
	ld a,(MISSILE_Y)
	ld l,a
	ld h,high PM_MISSILES
	ld a,(hl)
	and $FC
	ld (hl),a
	endif
	ld a,1
	ld (BULLET_Y),a
	ret

; sub $B221 / $B223: the bullet, A as bits, into the 8 rows of missile 2 from row BULLET_Y
; (at least $1C); none while BULLET_Y is 1. (The cycle model's build only: dh_lists.)
draw_bullet:
	ifndef BEAM
	ret
	else
	ld c,a
	ld a,(BULLET_Y)
	cp 1
	ret z
	cp $1C
	jr nc,.r
	ld a,$1C
.r	ld l,a
	ld h,high PM_MISSILES
	ld b,8
.d	ld (hl),c
	inc hl
	djnz .d
	ret
	endif

; A5AA-A5B4: the bullet to row A.
move_bullet:
	push af
	xor a
	call draw_bullet
	pop af
	ld (BULLET_Y),a
	ld a,$20
	jp draw_bullet

; ------------------------------------------------------------------------------------------
; A688-A17E: a new game (START), or the attract mode's river starting.
new_game:
	ld a,(GAME_NUMBER)
	and 1
	ld (PLAYER),a
	xor a				; A15D with X = $79: $79-$7F cleared
	ld hl,RESPAWNED
	ld b,7
.c	ld (hl),a
	inc hl
	djnz .c
	inc a
	call reset
	ld a,RESUME_NEW_GAME
	ld (resume),a
	ret

; sub $B0F1: reset of the river and the objects. A non-zero: a new game ($4D-$76 from the
; reset table); zero: a restart ($4D-$5F). Then 13 frames in which only the display and the
; VBI run (busy), while the original clears memory.
reset:
	ld (rs_full),a
	or a
	jr z,.river
	ld a,(ROM_RESET_VALUES + LEVEL - FIRST_SLOT)
	ld (LEVEL),a
.river	call restore_checkpoint
	ld hl,ROM_RESET_VALUES + BULLET_Y - FIRST_SLOT
	ld de,BULLET_Y			; bullet, plane x, its fraction, speed
	ld bc,4
	ldir
	ld hl,ROM_RESET_VALUES + FUEL - FIRST_SLOT
	ld de,FUEL
	ld bc,2
	ldir
	ld a,(ROM_RESET_VALUES + PLANE_FRAME - FIRST_SLOT)
	ld (PLANE_FRAME),a
	ld a,(rs_full)
	or a
	jr z,.common
	ld hl,ROM_RESET_VALUES + BRIDGES - FIRST_SLOT
	ld de,BRIDGES			; both players' data and the plane's state
	ld bc,PLANE_STATE - BRIDGES + 1
	ldir
.common	xor a
	ld (PLANE_ACCEL),a
	ld (SCROLL_FRAC),a
	ld (BRIDGE_FLASH),a
	ld (SHELL_FRAME),a
	ld (SHELL_X),a
	ld (SHELL_X_FRAC),a
	ld (CRASH_PITCH),a
	inc a				; (the collisions see none: dh_lists)
	ld (pm_empty),a
	xor a
	ifdef BEAM
	ld h,high PM_MISSILES		; player-missile memory rows 1-$BB cleared
.pm	ld l,1
	ld b,$BB
.row	ld (hl),a
	inc l
	djnz .row
	inc h
	bit 4,h				; up to page $0F
	jr z,.pm
	endif
	ld (SCREEN_ON),a		; B101: colours off while clearing
	call clear_screen_memory
	ld a,(tv_pal)			; 13 frames (8 on PAL: a longer frame, fewer of them)
	or a
	ld a,13
	jr z,.busy
	ld a,8
.busy	ld (busy),a
	ld a,L2_PAGES			; Layer 2 cleared in the frames to come
	ld (l2_clear),a
	jp draw_logo_and_needle

; Screen memory ($2000-$2EFF, $3000-$3EFF) cleared
clear_screen_memory:
	ld (cs_sp),sp
	ld hl,0
	ld sp,$2F00
	ld b,240
.a
	push hl
	push hl
	push hl
	push hl
	push hl
	push hl
	push hl
	push hl
	djnz .a
	ld sp,$3F00
	ld b,240
.b
	push hl
	push hl
	push hl
	push hl
	push hl
	push hl
	push hl
	push hl
	djnz .b
	ld sp,(cs_sp)
	jp spans_clear

; One page of Layer 2 cleared, while there are any left (frames of the reset)
clear_layer2_page:			; (two)
	call .page
.page	ld a,(l2_clear)
	or a
	ret z
	dec a
	ld (l2_clear),a
	add a,L2_FIRST_PAGE
	nextreg $52,a
	ld (cs_sp),sp
	ld hl,0
	ld sp,$6000
	ld b,0				; 2 x 256 x 16 bytes
.a
	push hl
	push hl
	push hl
	push hl
	push hl
	push hl
	push hl
	push hl
	djnz .a
.b
	push hl
	push hl
	push hl
	push hl
	push hl
	push hl
	push hl
	push hl
	djnz .b
	ld sp,(cs_sp)
	ret

; The main loop continues after sub $B0F1.
finish_reset:
	ld hl,resume
	ld a,(hl)
	ld (hl),0
	cp RESUME_RESPAWN
	jr nz,.new
	call finish_respawn
	jp main_loop_end
.new	cp RESUME_NEW_GAME
	ret nz
	call set_up_game		; AF80, A16C-A17E: the panel, then the main loop runs once
	ld a,(ATTRACT_FLAGS)		; more in this frame
	rla
	jr c,.loop
	call show_lives
	call show_bridges
	call show_score
.loop	jp main_loop

; A3C1-A3E3: the river continues from the restart point, the plane in the middle of it.
finish_respawn:
	ld hl,CHECKPOINT
	ld de,RND_A
	ld bc,3
	ldir
	ld a,(hl)
	ld (BANK),a
	add a,$26
	ld hl,ISLAND_WIDTH
	add a,(hl)
	ld (PLANE_X),a
	ld a,(ATTRACT_FLAGS)
	rla
	ret nc
	jp game_over_screen

; A36E-A3B6: the explosion is over: the next player, the next plane, or game over. Carry
; set when the river is reset for the next plane (the loop continues after it).
respawn_or_game_over:
	ld a,(OTHER_LIVES)
	or a
	call nz,swap_players
	ld a,1
	ld (RESPAWNED),a
	ld a,(LIVES)
	or a
	jr z,.over
	xor a				; A3BC
	call reset
	ld a,RESUME_RESPAWN
	ld (resume),a
	scf
	ret
.over	ld a,1				; A3B4: after this frame's VBI
	ld (game_over_text),a
	ld a,(tv_pal)			; PAL: the panel's DLI keeps the CPU longer, the VBI comes
	or a				; before sub $B21A and sees the state as it was
	jr z,.hs
	ld (vbi_before),a
	ld a,(FRAME_COUNT)
	ld (vbi_saved),a
	ld a,(PLANE_STATE)
	ld (vbi_saved + 1),a
	ld a,(ATTRACT_TIMER)
	ld (vbi_saved + 2),a
.hs
	ld hl,SCORE			; A37D: game over
	call update_high_score
	ld hl,OTHER_SCORE
	call update_high_score
	ld a,(GAME_NUMBER)
	and 1
	jr z,.one
	ld a,(PLAYER)
	or a
	call nz,swap_players
	ld hl,ROM_PLAYER_TWO_TEXT
	ld de,PANEL + PANEL_LIVES
	ld b,4
.text	ld a,(hl)
	xor $C0
	ld (de),a
	inc hl
	inc de
	djnz .text
	ld hl,OTHER_BRIDGES
	ld b,2
	ld de,PANEL + PANEL_OTHER_BRIDGES
	ld c,DIGITS_OTHER
	call print_bcd
	jp game_over_screen
.one	call show_high_score
	jp game_over_screen

; sub $B247: two-player game: the other player's turn ($60-$6A and $6B-$75 swapped).
swap_players:
	ld a,(GAME_NUMBER)
	and 1
	ret z
	ld a,(PLAYER)
	xor 1
	ld (PLAYER),a
	ld hl,LEVEL
	ld de,OTHER
	ld b,11
.s	ld a,(de)
	ld c,(hl)
	ld (hl),a
	ld a,c
	ld (de),a
	inc hl
	inc de
	djnz .s
	ret

; sub $B261: the score at HL becomes the high score of this pair of games if higher; then
; the check bytes are made again (sub $B298).
update_high_score:
	ld a,(GAME_NUMBER)
	and $0E
	add a,a
	add a,HIGH_SCORE
	ld e,a
	ld d,0
	push hl
	push de
	ld b,3
.cmp	ld a,(de)
	cp (hl)				; carry: the high score is lower
	jr c,.higher
	jr nz,.lower
	inc hl
	inc de
	djnz .cmp
.higher	pop de
	pop hl
	ld bc,3
	ldir
	ld c,15
.check	ld hl,HIGH_SCORE + 14
	ld b,15
	xor a
.i	adc a,(hl)
	ld d,a
	ld a,0
	rla
	ld e,a
	ld a,d
	xor c
	rr e
	dec hl
	djnz .i
	ld hl,HIGH_SCORE_CHECK
	ld e,c
	ld d,0
	add hl,de
	ld (hl),a
	dec c
	jp p,.check
	ret
.lower	pop de
	pop hl
	ret

; sub $AF80: one- or two-player markers in the panel and the starting point of the game.
set_up_game:
	ld a,(GAME_NUMBER)
	and 1
	jr z,.one
	call show_other_score
	ld a,$4F
	ld b,$50
	jr .marks
.one	call show_high_score
	ld a,$DB
	ld b,$D0
.marks	ld (PANEL + PANEL_PLAYER1_MARK),a
	ld a,b
	ld (PANEL + PANEL_PLAYER2_MARK),a
	ld a,(GAME_NUMBER)		; the start: 2 games each
	rra
	and 3
	ld e,a
	ld d,0
	ld hl,ROM_START_CHECKPOINT
	add hl,de
	ld ix,CHECKPOINT
	ld b,4
.cp	ld a,(hl)
	ld (ix+0),a
	ld (ix+OTHER - LEVEL),a
	inc ix
	inc hl
	inc hl
	inc hl
	inc hl
	djnz .cp
	ld hl,ROM_START_LEVEL
	add hl,de
	ld a,(hl)
	ld (LEVEL),a
	ld (OTHER),a
	ld hl,ROM_START_BRIDGES
	add hl,de
	ld a,(hl)
	ld (BRIDGES + 1),a
	ld (OTHER_BRIDGES + 1),a
	ifdef TEST
	ld a,(start_bridges_hi)		; (test builds: nxcheck's NXBRIDGE, the hundreds)
	else
	xor a
	endif
	ld (BRIDGES),a
	ld (OTHER_BRIDGES),a
	ret

; A699-A6DC: SELECT or OPTION: the next game number, everything back to the start.
select_game:
	ld a,(GAME_NUMBER)
	inc a
	and 7
	ld (GAME_NUMBER),a
	add a,$D1			; digit 1-8
	ld (PANEL + PANEL_GAME_NUMBER + 1),a
	xor a
	ld (PANEL + PANEL_GAME_NUMBER),a
	ld (IDLE_TIME),a
	ld (ATTRACT_FLAGS),a
	ld (LIVES),a
	ld (OTHER_LIVES),a
	ld (PLAYER),a
	ld (SOUND_MISSILE),a
	ld hl,SCORE
	ld (hl),a
	inc hl
	ld (hl),a
	inc hl
	ld (hl),a
	ld hl,OTHER_SCORE
	ld (hl),a
	inc hl
	ld (hl),a
	inc hl
	ld (hl),a
	ld a,2
	ld (START_BEEP),a
	ld a,$FF
	ld (SHELL_TIMER),a
	call set_up_game
	call show_lives
	call game_over_screen
	ld a,$25
	ld (ATTRACT_TIMER),a
	ld a,$1E
	ld (SELECT_DELAY),a
	ret

; ------------------------------------------------------------------------------------------
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
.s	ld hl,PANEL + PANEL_LIVES
	ld b,9
	ld e,0
.l	ld a,e
	cp c
	ld a,LIFE_SYMBOL
	jr c,.w
	xor a
.w	ld (hl),a
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
	ld (de),a
	inc de
	ret
.show	add a,c
	ld (de),a
	inc de
	xor a
	ld (pb_leading),a
	ret

; ------------------------------------------------------------------------------------------
; The controls, as the original reads them (Input of the C++ port): in_stick for the two
; joysticks (bits 0 up, 1 down, 2 left, 3 right; 0 = pressed), in_trig (bit 0 the first
; joystick's fire, bit 1 the second's), in_console (bit 0 START, 1 SELECT, 2 OPTION), in_key
; (a key of the keyboard: pause).
;
; Keyboard: Q A O P to fly, Space or M to fire (both players: they take turns); Enter START,
; G SELECT (the game number), H pause. Kempston joystick 1 (port $1F) and 2 ($37); on a
; Mega Drive pad also START, and A for SELECT.
	ifndef TEST
read_input:
	ld e,$0F			; E: the keyboard as a stick
	ld d,0				; D: bit 0 fire, 1 START, 2 SELECT, 3 the pause key
	ld c,$FE
	ld b,$FB			; Q: up
	in a,(c)
	bit 0,a
	jr nz,$+4
	res 0,e
	ld b,$FD			; A: down; G: SELECT
	in a,(c)
	bit 0,a
	jr nz,$+4
	res 1,e
	bit 4,a
	jr nz,$+4
	set 2,d
	ld b,$DF			; O: left; P: right
	in a,(c)
	bit 1,a
	jr nz,$+4
	res 2,e
	bit 0,a
	jr nz,$+4
	res 3,e
	ld b,$7F			; Space, M: fire
	in a,(c)
	cpl
	and %00000101
	jr z,$+4
	set 0,d
	ld b,$FE			; CAPS + 1: the other standard (when pressed)
	in a,(c)
	ld h,a
	ld b,$F7
	in a,(c)
	or h
	cpl
	and 1
	ld h,a
	ld a,(tv_keys)
	cpl
	and h
	ld (tv_toggle),a
	ld a,h
	ld (tv_keys),a
	ld b,$FE			; CAPS + 2: the sound off and on (when pressed)
	in a,(c)
	ld h,a
	ld b,$F7
	in a,(c)
	rrca
	or h
	cpl
	and 1
	ld h,a
	ld a,(snd_keys)
	cpl
	and h
	jr z,.snd
	ld a,(snd_off)
	xor 1
	ld (snd_off),a
	ld (snd_clear),a
.snd	ld a,h
	ld (snd_keys),a
	ld b,$FB			; T: the frame's work on the border, on and off (when
	in a,(c)			; pressed)
	cpl
	and $10
	ld h,a
	ld a,(tm_keys)
	cpl
	and h
	jr z,.tm
	ld a,(tm_show)
	xor 1
	ld (tm_show),a
	jr nz,.tm
	nextreg $4A,0			; off: black again
.tm	ld a,h
	ld (tm_keys),a
	ld b,$BF			; Enter: START; H: pause
	in a,(c)
	bit 0,a
	jr nz,$+4
	set 1,d
	bit 4,a
	jr nz,$+4
	set 3,d
	ld a,d				; the keyboard's fire for both players
	and 1
	ld b,a
	add a,a
	or b
	ld (in_trig),a
	ld a,d
	rra
	and 3
	ld (in_console),a
	ld a,d
	rra
	rra
	rra
	and 1
	ld (in_key),a
	in a,($1F)			; joystick 1
	ld hl,in_stick
	ld c,1				; (its fire: in_trig bit 0)
	call .joy
	in a,($37)			; joystick 2 (nothing there: $FF)
	cp $FF
	jr nz,$+3
	xor a
	inc hl
	ld c,2
.joy	ld b,a
	and $0F				; the directions
	push hl
	add a,low kempston_stick
	ld l,a
	ld h,high kempston_stick
	ld a,(hl)
	pop hl
	and e				; with the keyboard's
	ld (hl),a
	bit 4,b				; fire
	jr z,.start
	ld a,(in_trig)
	or c
	ld (in_trig),a
.start	bit 7,b				; Mega Drive pad: START, A
	jr z,.a
	ld a,(in_console)
	or 1
	ld (in_console),a
.a	bit 6,b
	ret z
	ld a,(in_console)
	or 2
	ld (in_console),a
	ret

	align 16
kempston_stick:				; Kempston bits 0 right, 1 left, 2 down, 3 up -> the stick
v = 0
	dup 16
	db $0F ^ ((v >> 3) & 1 | ((v >> 2) & 1) << 1 | ((v >> 1) & 1) << 2 | (v & 1) << 3)
v = v + 1
	edup
	endif
