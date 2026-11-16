; The river generator's state, at the addresses the original keeps it in the Atari's RAM.
; The Atari's RAM ($0000-$3FFF) is paged in at $0000 of the Z80, so a memory dump compares
; byte for byte with the original and with the C++ port (RiverGen::saveToRam).
; Names and meanings as in river_raid/port/src/river_gen.h.

SECTION_BANK_COLOUR	equ $0B		; bank colour of the section ($D2/$D6)
SLOT_Y			equ $0C		; 11 slots: vertical position, +1 per generated line
BLOCK_FLAGS		equ $23		; $80 run-up to a bridge, $10 new block, $04 bank shade
PREV_SECTION_WIDTH	equ $2C
ISLAND_FLAGS		equ $2D		; $80 island, $40 opening
BRIDGE_HIT		equ $2E
LINE_IN_BLOCK		equ $2F		; 0..31
ENTERING_LINES		equ $32		; lines until the newest object is fully drawn in
SLOT_PARITY		equ $33
ISLAND_TARGET		equ $34
ISLAND_STEP		equ $35
DECO_FLAGS		equ $36		; 0 none; bit 7: on the left bank
ISLAND_OBJ_SIDE		equ $37
TANK_KIND		equ $38
TANK_X			equ $39
TANK_Y			equ $3A
SHELL_SPEED		equ $3E
SHELL_SPEED_FRAC	equ $3F
SHELL_Y			equ $40
TANK_FIRES		equ $41
SLOT_FLAGS		equ $42		; 11 slots: $80 bridge, $40 awake, $08 facing left
FIRST_SLOT		equ $4D		; slots fill from 10 down
ENTERING_SLOT		equ $4E		; 11 = none
FLASH_LINES		equ $4F
SHELL_TIMER		equ $50
SHOOTER_SLOT		equ $51
BANK			equ $52		; left bank: where the water starts
WATER_WIDTH		equ $53
ISLAND_WIDTH		equ $54
BLOCKS_LEFT		equ $5A
SECTIONS_LEFT		equ $5D
SECTION_WIDTH		equ $5F
LEVEL			equ $60
CHECKPOINT		equ $66		; 4: LFSR A, B, C and bank at the last bridge
RND_A			equ $AA		; 24-bit LFSR
RND_B			equ $AB
RND_C			equ $AC
PREV_CHECKPOINT		equ $AD		; 4
PLACE_WIDTH		equ $B3
DRAW_POS		equ $B4		; bytes of the line drawn so far
BANK_MARGIN		equ $B5
WIDE_OBJECT		equ $B8
DECO_BITMAP		equ $BA		; 2: ROM address of the next bitmap row
DECO_WIDTH		equ $BC
DECO_OFFSET		equ $BD
DECO_ROWS		equ $BE
MISSILE_X		equ $C1
MISSILE_Y		equ $C2
BANK_DIR		equ $C3		; +1, $FF or 0
BANK_MIN		equ $C4
BANK_MAX		equ $C5
DEPOT_LEVEL_LIMIT	equ $CB		; $2E NTSC, $2F PAL
SLOT_KIND		equ $0500	; 11 slots: current kind
SLOT_TYPE		equ $050B	; 11 slots: type as placed
SLOT_X			equ $0516	; 11 slots: horizontal position
SLOT_SIZE		equ $0521	; 11 slots: sprite width (SIZEP3)
CORRIDOR		equ $052D

NO_SLOT			equ 11
SLOTS			equ 11

; Tables in the cartridge image, which is paged in at $A000 as on the Atari
ROM_START_CHECKPOINT	equ $B494	; 4 starts x 4 bytes, interleaved (start + 4 * i)
ROM_START_LEVEL		equ $B4A4
ROM_ROAD_COLOURS	equ $B4E5	; bank colour per row next to a bridge
ROM_COLOURS		equ $B700	; object colours, one per row
ROM_EDGE_PIECES		equ $B800	; 2-byte pieces where water meets the bank
ROM_SHAPES		equ $B900	; object shapes, one byte per row
ROM_BRIDGE_BANK_STEP	equ $BA8F
ROM_RESET_VALUES	equ $BAE1	; what sub $B0F1 loads into $4D..
ROM_ENEMY_CHOICE	equ $BB1C
ROM_COLOURS_OFFSET	equ $BB30
ROM_SHAPE_OFFSET	equ $BB40
ROM_OBJECT_HEIGHT	equ $BB60
ROM_OBJECT_SIZE		equ $BBA2
ROM_DECO_WIDTH		equ $BBB2
ROM_DECO_OFFSET_ODD	equ $BBCC
ROM_DECO_OFFSET_WIDTH	equ $BBD4
ROM_DECO_ROWS		equ $BBEB
ROM_DECO_BITMAP		equ $BBF0
ROM_SHELL_SPEED		equ $B7F4
ROM_TANK_START_X	equ $BFE4

; The game's state (river_raid/port/src/game.h, GameState), at the original's addresses
FRAME_COUNT		equ $18		; +1 per frame (VBI)
JOYSTICK		equ $19
HIT			equ $1A		; 9 collision results ($1A-$22), $FF = none
HIT_BULLET_BANK		equ $1A
HIT_PLANE_BANK		equ $1B
HIT_BULLET_OBJECT	equ $1C
HIT_PLANE_OBJECT	equ $1D
HIT_PLANE_SHELL		equ $1E
HIT_SHELL_OBJECT	equ $1F
HIT_TANK_AT_EDGE	equ $20
HIT_MISSILE_PLANE	equ $21
HIT_MISSILE_BANK	equ $22
PAUSE_STATE		equ $24
SELECT_DELAY		equ $25
POWER_ON_DONE		equ $28
ATTRACT_FLAGS		equ $29		; bit 7: attract mode
ATTRACT_TIMER		equ $2A
PLANE_ACCEL		equ $2B
SCROLL_FRAC		equ $30
BRIDGE_FLASH		equ $31
SHELL_FRAME		equ $3B
SHELL_X			equ $3C
SHELL_X_FRAC		equ $3D
BULLET_Y		equ $56
PLANE_X			equ $57
SPEED			equ $59
FUEL			equ $5B
FUEL_FRAC		equ $5C
PLANE_FRAME		equ $5E
LIVES			equ $6A
OTHER_LIVES		equ $75
PLANE_STATE		equ $76		; $FF: no plane
PLAYER			equ $77
IDLE_TIME		equ $78
RESPAWNED		equ $79
SOUND_EXPLOSION		equ $7C
SOUND_MISSILE		equ $7F
JOYSTICK_PREV		equ $B9
MISSILE_STEP		equ $C0
SCREEN_ON		equ $C7
CRASH_PITCH		equ $052C
GAME_NUMBER		equ $09

; Player-missile memory, one byte per scanline
PM_MISSILES		equ $0B00
PM_SHELL		equ $0C00	; player 0
PM_TANK			equ $0D00	; player 1
PM_PLANE		equ $0E00	; player 2 (the plane's rows from $AA)
PM_P3			equ $0F00	; player 3: every object, row by row (the DLI)
PM_P3_ROWS		equ $0EBC	; player 3 less $44: indexed by the DLI's scanline counter

; Screen memory: a ring of two 80-line blocks, the address of the top line at $3F04
SCREEN_TOP		equ $3F04

ROM_NEXT_KIND		equ $BB24
ROM_NEXT_TANK_KIND	equ $BAAF
ROM_SHELL_COLOUR	equ $BAC5
ROM_SHELL_RISE		equ $B4AF
ROM_TANK_SHAPE		equ $B4D1	; pointers
ROM_SHELL_SHAPE		equ $BAB7
ROM_PLANE_SHAPE		equ $BACD

; More of the game's state (the game proper)
PLANE_X_FRAC		equ $58
BRIDGES			equ $61		; 2, BCD
SCORE			equ $63		; 3, BCD, high byte first
OTHER			equ $6B		; the other player's $60-$6A
OTHER_BRIDGES		equ $6C
OTHER_SCORE		equ $6E
EVENT_SOUND		equ $7A
EVENT_SOUND_TIME	equ $7B
SOUND_FIRE		equ $7D
SOUND_BONUS		equ $7E
HIGH_SCORE		equ $80		; 16
HIGH_SCORE_CHECK	equ $90		; 16
START_BEEP		equ $C6
PANEL			equ $1000	; 60 characters

; PLANE_STATE
FLYING			equ 0
WAITING			equ $2F
LIFE_LOST		equ $30
CRASHED			equ $FE
NO_PLANE		equ $FF

; PAUSE_STATE
PLAYING			equ 0
RESUMING		equ 1
PAUSED			equ 2
PAUSING			equ 3

; EVENT_SOUND
CRASH_SOUND		equ 1
OUT_OF_FUEL_SOUND	equ 2
TANK_FULL_SOUND		equ 3
REFUEL_SOUND		equ 4

; panel positions and digit characters
PANEL_SCORE		equ $02
PANEL_PLAYER1_MARK	equ $0B
PANEL_HIGH_SCORE	equ $0C		; or the other player's score
PANEL_PLAYER2_MARK	equ $12
PANEL_BRIDGES		equ $23
PANEL_GAME_NUMBER	equ $2A
PANEL_LIVES		equ $33
PANEL_OTHER_BRIDGES	equ $37
LIFE_SYMBOL		equ $9C
DIGITS_SCORE		equ $10
DIGITS_OTHER		equ $50
DIGITS_BRIDGES		equ $90
DIGITS_HIGH_SCORE	equ $D0

ROM_START_BRIDGES	equ $B4A8	; BCD
ROM_POINTS		equ $BB0B
ROM_PANEL_TEXT		equ $BB70
ROM_PLAYER_TWO_TEXT	equ $BB8F

; The scrolling line (VBI B44B-B47F)
TEXT_LO			equ $3FB3	; its text: $B800 + this (the display list's LMS)
FINE_SCROLL		equ $26		; HSCROL, 7-0
LOGO_X			equ $27		; the rainbow logo's position, 0: none

ROM_SCROLL_TEXT		equ $B800
ROM_LOGO_COLOURS	equ $B48D	; 7 rows, the bottom one first
ROM_LOGO_LETTERING	equ $BEEE
ROM_PANEL_SYMBOLS	equ $BF2E
ROM_PLAYER_LABELS	equ $BF9E
ROM_YEAR_DIGITS		equ $BFB6
