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
