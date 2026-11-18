# The assembly source, file by file

For Z80 programmers who want to read the code or make it faster. For each file: what is in
it, each routine's job, who calls it and when, how it works, and what it costs. The why
behind the design is in [NOTES.md](NOTES.md) and [HANDOFF.md](../HANDOFF.md); the plain-words
picture in [HOW_IT_WORKS.md](HOW_IT_WORKS.md).

## The numbers

Times are the Next core's ticks at 28 MHz, per frame, averaged over 3 000 frames, from
nxcheck's histogram (`NXHISTALL=file`, then `python3 tools/prof.py build/test.sym file 60`).
Two runs:

- **A**: PAL, bot 1, from the start (the usual early game);
- **B**: NTSC, from bridge 50, the plane unable to crash (`NXBRIDGE=50 NXGHOST=1 NXGAME=1`): the busy late river.

A frame has 560 000 ticks on PAL and 467 000 on NTSC. Run A averages ~172 600 ticks of work
a frame, run B ~227 800. `apply` (and so `panel_frame`) runs after the measured work
(below the scrolling line) and is not in these numbers. A routine's time is its own
instructions only: the routines it calls are counted under their own names.

By part (A / B):

| part | A | B |
|---|---|---|
| the display: objects' schedule and collisions (`display_simple`, `display_objs`, `display_hits`, `pf_*` and `collide` in `display.asm`) | 87 400 | 120 100 |
| sound (`pokey_frame`, `snd_*`, `pk_*`, `ay_*`, `sound_driver`) | 25 400 | 32 100 |
| sprites and the Copper's list (`build_sprites`, `ob_*`, `pm_channel`, `emit_sprite`, `build_copper`) | 25 000 | 30 100 |
| new river lines (`river_gen`, `render_line`, `span_line`, `push_line`) | 19 700 | 27 900 |
| the game logic and the rest (`prepare`, `main_loop`, `move_objects`, `random_step`, `print_bcd`, …) | 13 100 | 15 000 |

The 30 most expensive routines (A / B):

| routine | A | B | file |
|---|---|---|---|
| `display` (own code) | 32 700 | 50 400 | display_simple |
| `ob_emit` | 9 700 | 10 400 | sprites |
| `render_line` | 7 700 | 10 500 | render |
| `snd_sum` | 8 600 | 7 300 | sound |
| `dh_obj` | 7 100 | 8 600 | display_hits |
| `span_line` | 5 400 | 7 900 | spans |
| `dh_pf` | 5 600 | 6 900 | display_hits |
| `pk_noise` | 4 400 | 8 000 | sound_pulses |
| `ob_list` | 5 700 | 6 400 | sprites |
| `ds_fields` | 5 600 | 6 400 | display_simple |
| `dh_seen` | 4 000 | 6 500 | display_hits |
| `ds_obj` | 3 900 | 4 500 Also `ds_objf`: the rows for the sprites, all of them, those past the river's end too (byte 1, the DLI's count, stays for the collisions); the Copper's sprite window below the river hides them, so an object keeps one pattern while it goes out at the bottom. Now at the end of page 4. | display_objs |
| `emit_sprite` | 2 600 | 5 200 | sprites |
| `dh_bits` | 3 400 | 4 200 | display_hits |
| `pf_line` | 2 600 | 4 200 | display |
| `prepare` | 3 000 | 3 000 | game |
| `pm_channel` | 2 700 | 3 100 | sprites |
| `move_objects` | 2 000 | 3 700 | game |
| `draw_line` | 2 300 | 3 300 | river_gen |
| `snd_fill` | 2 800 | 2 400 | sound |
| `pf_size` + `pf_v1` (+ `pf_v1_bits`) | 4 100 | 7 200 | display |
| `pokey_frame` (own code) | 2 400 | 2 500 | sound |
| `pk_channel` | 1 500 | 2 800 | sound_pulses |
| `ob_write` | 1 800 | 2 500 | sprites |
| `ds_inx` | 1 800 | 2 000 | display_simple |
| `dh_lists` (shown as `dh_template_end`, the same address) | 1 900 | 1 900 | display_hits |
| `ds_bank_fill` | 1 800 | 1 900 | display_simple |
| `dl_fill` | 1 300 | 1 800 | river_gen |
| `bm_hitclr` | 1 500 | 1 700 | display |

(`prof.py` takes a routine's name from the nearest global label below the address, so a
data label right in front of code can take its time: `dh_template_end` is `dh_lists`, and
the symbols of page 12 at $6000-$7FFF (`scan_col`, `ds_cover`) stand for `panel_init` in
page 7 at the same addresses, which runs once at the start.)

## Memory while the code runs

8K slots ($0000, $2000, … $E000) and the pages in them:

| slot | address | normally | remapped by |
|---|---|---|---|
| 0–1 | $0000–$3FFF | 30–31: the Atari's RAM at the original's addresses | `pokey_frame`: 14–15, POKEY's 17-bit counter (`poly17.bin`), while it makes samples |
| 2 | $4000–$5FFF | varies: there is no fixed page | `render_line`: 18–27 (Layer 2, one page per 32 columns); `display`, `span_line`, `spans_clear`: 28 (`SPAN_PAGE`, the lines' runs); `build_sprites`/`emit_sprite`: 7 (`INIT_PAGE`: the 4-bit patterns' rows and hash tables, the 8-bit pattern cache `OB_*`); `panel_frame`: 11 (tile 256, the map); `panel_init`: 10, 11 |
| 3 | $6000–$7FFF | 12: buffers (`copper_list`, `ds_objs`, `sprite_list`, `exp8`, the DAC's ring at $7C00) | only at the start: 7 (`panel_init`, `sound_init7`, `load_rom`). **Never while the sound plays**: the DMA reads the ring through this slot |
| 4 | $8000–$9FFF | 4: code | — |
| 5 | $A000–$BFFF | 5: the cartridge, read from River_Raid.rom | — |
| 6 | $C000–$DFFF | 6: code | — |
| 7 | $E000–$FFFF | 1: variables, tables, the stack (from $0000 down to above $FF00) | — |

The code pages are nearly full: page 4 ends at ~$9F2F (of $A000), page 6 at ~$DE4E (of
$E000), page 7 at ~$66CD (the build prints these). Moving code between pages is how room was
found before (`display_objs.asm` sat in the gap before the palette's alignment in page 4, now at its end).

Interrupts are off all the time (`di` at start): the frame is paced by polling the raster
line (`wait_frame`), the sound by the DMA, the per-line colours by the Copper.

## The frame

`main_frame` (river_raid.asm), every frame:

1. Snapshots what this frame's picture shows (`scroll`, the edge and water colours, the player), `read_input`, CAPS + 1 (`restart` in the other standard).
2. Normally: `prepare` → `display` → `build_sprites` → `main_loop` → `vbi`. During a reset (`busy`, the frames in which the original clears memory: 13 NTSC, 8 PAL): `display` → `build_sprites` → `clear_layer2_page` → (`finish_reset` in the last) → `vbi`.
3. `pokey_frame`: the frame's samples into the DAC's ring and the AY's tones.
4. `wait_frame`: polls the active video line (NR $1E/$1F) until `wait_line` (208 NTSC, 220 PAL), below the scrolling line, where nothing on screen changes.
5. `apply`: everything built goes live at once (Layer 2's scroll and colours, the sprites' attributes, the panel's tiles, the Copper's list).

With T on (`tm_show`), each of these parts sets the border's colour first (`TM_COLOUR`): orange `apply`, grey `prepare` (and `clear_layer2_page` during a reset), red `display`, yellow `build_sprites`, blue `main_loop`, magenta `push_line` (a new river line, inside `main_loop`), white `vbi`, cyan `pokey_frame`, green the time left. `push_line` sets magenta and back to blue.

Order matters: `display` uses the state the previous frame's `main_loop` left (as the
Atari's DLI shows the previous frame's state), and `build_sprites` uses what `display` left.

---

## river_raid.asm: the frame, the start, memory

The top file: memory layout, `include`s, page assembly (`mmu`/`org`), variables of page 1
and buffers of page 12, test-build hooks.

| routine | called | what and how |
|---|---|---|
| `start` | at load | `load_rom` (not in test builds), seeds RANDOM from R, 28 MHz, maps pages, `init_tables`, `init_video`, `panel_init` (page 7 mapped), then `restart`. |
| `restart` | `start`; CAPS + 1 | The machine "switched on" in `tv_pal`'s standard: `tv_setup`, Layer 2 cleared (all 10 pages at once), `sound_init`, `start_attract`, falls into `main_frame`. |
| `main_frame` | every frame | See *The frame*. ~340 ticks of its own. |
| `wait_frame` | `main_frame` | Busy-waits on NR $1F against `wait_line`. Its time is idle time, not work. |
| `init_tables` | `start` | Once: the tables: `mc_bullet`/`mc_missile` (a missile's bits as a player's byte), `pix_tab` (`render_line`), `ring_lo`/`ring_hi` (screen memory's 160 lines in order), `exp8` (a byte as 8 nibbles, for the 4-bit patterns), `span_class` (a byte's colour if its 4 pixels are one), `span_init` (the masks), an empty Copper list. |
| `tv_setup` | `restart` | The standard's settings: NR $05 50/60 Hz, `init_line_tables`, `wait_line`, the random map, the Copper's panel part (`copper_panel_ntsc`/`_pal` copied, the grey patched into it, `COPPER_GREY`), the tilemap's first Y scroll, clip windows (Layer 2 down to the panel's last grey line, sprites, tilemap). |
| `init_video` | `start` | Black border, no ULA, global transparency $E3, Layer 2 320×256×8 at bank 9, layer order (tilemap over sprites over Layer 2), the palettes: Layer 2's 4 entries, the sprites' 128–255 = the Atari's colours, NR $15 with the sprites' clip in over-border mode. |
| `test_ghost` | test builds, after `display` when `test_ghost_on` | nxcheck's NXGHOST: the plane's collisions and the fuel set so that it cannot crash. |
| `pc_check` | `build_sprites`, `OBJCHECK` builds | Counts the other sprites' rows outside their boxes (`pc_bad`). |

Also: `span_rec` (macro: HL = the 32-byte record of river line A in SPAN_PAGE), the
`palette` (Atari colour → Next colour, 256 bytes) and `random_columns`, the `TEST`
variables (`start_bridges_hi`, `snd_passed`, `test_ghost_on`).

## play.asm: the main loop (A197–A6EA)

The game logic the original runs in its main loop, as the C++ port has it. State lives at
the original's RAM addresses.

| routine | called | what and how | A / B |
|---|---|---|---|
| `main_loop` | `main_frame` (not during a reset) | A197–A6EA: reads RANDOM (`random_read`), the plane (`fly_plane`) or the explosion/respawn (`respawn_or_game_over`), `drive_tank`, `move_objects`, then `main_loop_end`. Returns early when a reset starts. | 620 / 620 |
| `main_loop_end` | `main_loop`, `finish_reset` | A5B7–A6EA: the missile and the shell (`move_missile`, `move_shell`), `scroll_river`, START/SELECT. | 180 / 170 |
| `scroll_river` | `main_loop_end` | A6FD: the speed added twice a frame to a fraction; each carry is one `push_line` (a new river line: the expensive part, see river_gen). | 140 / 160 |
| `fly_plane` | `main_loop` | A3E9–A5B4: fuel, steering (`steer`), speed (`change_speed`), firing, the bullet (`move_bullet`), the collisions' results: `explode` (an object shot or rammed: points), `crash`. | 290 / 480 |
| `steer`, `change_speed` | `fly_plane` | The plane's X with a sub-pixel fraction; the speed $40–$FE. | |
| `explode` | `fly_plane` | A4E0–A589: the slot becomes an explosion, the points (BCD), a bridge's bonus. | |
| `crash` | `fly_plane`, `explode` | sub $B1C0: the plane crashes, with an event sound; `section_checkpoint`. | |
| `draw_bullet`, `move_bullet` | `fly_plane`, `crash` | The bullet's 8 rows into missile 2's memory. | 380 / 520 |
| `new_game`, `reset` | START, game over, respawn | sub $B0F1: the river and the objects reset (`restore_checkpoint`), `clear_screen_memory`, `busy` = 13 or 8 frames. | |
| `clear_layer2_page` | `main_frame` during `busy`, `restart` | One of Layer 2's 10 pages cleared a frame (`l2_clear` counts). ~1 100 a frame on average over A, but one page is 8 KB of writes in the frames it runs. | 1 100 / 570 |
| `finish_reset`, `finish_respawn`, `respawn_or_game_over` | | After the reset: the river continues from the checkpoint, the next player or game over. | |
| `swap_players`, `update_high_score`, `set_up_game`, `select_game` | | Two players, high score with its check bytes, the game number. | |
| `show_lives`, `show_score`, `show_bridges`, … | the loop, the VBI | The panel's characters in Atari RAM ($1000). | 620 / 720 |
| `print_bcd` | the `show_*` | B086: BCD bytes as digits, leading zeros blank. | 1 200 / 1 400 |
| `read_input` | `main_frame` (not in test builds) | The keyboard (Q A O P, Space/M, Enter, G, H, CAPS + 1/2), Kempston 1 and 2 and the Mega Drive pad, into the Atari's stick, trigger and console bytes. T (on press) toggles `tm_show`, off: the fallback colour black. | — |

## game.asm: per-frame game parts and the VBI

| routine | called | what and how | A / B |
|---|---|---|---|
| `random_read` | `main_loop` (A205) | POKEY's RANDOM: the 17-bit counter as it stands at the read point. The checks count these reads. | |
| `random_step` | `vbi` | The counter one frame on: a fixed linear map (17 columns in `random.inc`, NTSC or PAL), 4 bits at a time: for each of the 4 nibbles of bits 0–15 a 3-byte entry of `rnd_tab` (page 1, 256 bytes aligned: 64 k + 4 v) XORed in, bit 16's column (`rnd_col16`) if set. Was bit by bit, ~2 300. | 560 / 560 |
| `rnd_tables` | end of `tv_setup` | `rnd_tab` and `rnd_col16` from the standard's columns (`rnd_cols`): each entry the XOR of its value's columns. | |
| `bank_colour` | `vbi`, `start_attract` | sub $AFD0: the bank's shade (switches while a bridge is drawn in near the top). | 200 / 200 |
| `start_attract` | `restart` | The attract mode's state at its first line (game 1, no plane). | |
| `draw_logo_and_needle` | `reset`, `start_attract` | The rainbow and the fuel needle into player-missile memory, as sub $B0F1 leaves them. | |
| `push_line` | `scroll_river`, `start_attract` | A new river line: `next_line` (river_gen) into `line_buf`, then at `line_done` the line into screen memory (48 bytes, the top line's address one line up), `render_line` (Layer 2), `plain_line` and `span_line` (the collisions' runs). | |
| `prepare` | `main_frame` | AE99–AF38 at the frame's top: the shapes of the tank, the helicopter's missile, the tank's shell and the plane copied into player-missile memory ($0B00–$0FFF) from the ROM's tables. | 3 000 / 3 000 |
| `drive_tank` | `main_loop` | A21B: the tank on the road drives, fires at the river's edge. | |
| `move_objects` | `main_loop` | A26C–A2ED: the objects in the slots animate and move (ships and helicopters turn at the edge: the slot's edge flag from the display). | 2 000 / 3 700 |
| `move_missile`, `move_shell` | `main_loop_end` | The helicopter's missile, the tank's shell. | |
| `vbi` | `main_frame` | B2A5–B43E: `sound_driver`, the frame counter, the colours of the next frame (`bank_colour`), `scroller_step`, `random_step`. On PAL at a game over it sees some values from before sub $B21A (`vbi_before`). | 420 / 430 |
| `scroller_step` | `vbi`, `start_attract` | B44B: the scrolling line a colour clock a frame in the attract mode, still in play. | |

## river_gen.asm: the river's generator (A711–AE93)

One river line at a time, as the original generates it: the 24-bit LFSR, sections and
blocks, bank and island widths, decorations (houses, mountains), roads and bridges, the
objects placed every 16 lines. Its output is `line_buf` (48 bytes: 192 colour clocks, 2 bits
each) and the slots.

| routine | called | what and how | A / B |
|---|---|---|---|
| `next_line` | `push_line` | One line: `count_lines`, `move_bank`, `change_island`, `scroll_objects`, `place_object`, then `draw_line`. | 210 / 290 |
| `count_lines` | `next_line` | A711: counts lines; at block and section starts sets up what comes (`choose_section_width`, `start_decoration`, checkpoints). | 160 / 210 |
| `move_bank` (+ `bank_hit_setup`, `bank_hits_left/right`) | `next_line` | A826: the bank's position for this line, without running into the object still being drawn in. | 350 / 570 |
| `change_island`, `choose_section_width` | | The island toward its target width. | |
| `draw_line` | `next_line` | The line's bytes: bank fill (`dl_fill`, `dl_fill_bank`), edges (`dl_edge`, `dl_bank_edge`: 2-byte pieces from $B800), the decoration's row (`dl_deco_row`), water. | 2 300 / 3 300 |
| `dl_fill` | `draw_line` | B bytes of C from DRAW_POS: a plain fill loop. | 1 300 / 1 800 |
| `scroll_objects` | `next_line` | AB76: everything one line down; when the lowest slot leaves the screen, the slots shift. | 560 / 820 |
| `place_object`, `choose_enemy`, `position_object`, `place_tank` | `next_line` | Every 16 lines a new object in the next free slot; at a block's start maybe a tank on a road. | |
| `step_lfsr` | many | sub $B183: the 24-bit LFSR. | 140 / 200 |
| `section_checkpoint`, `restore_checkpoint`, `start_game` | | The restart point; a new game from bridge 1 (or `start_bridges_hi` in test builds). | |

The generator's cost is per new line: the speed is added twice a frame to a fraction and
each carry is a line, so 0–2 lines a frame, more the faster the plane flies.

## render.asm: a line into Layer 2

| routine | called | what and how | A / B |
|---|---|---|---|
| `render_line` | `line_done` | `line_buf` colour clocks 20–179 (`WINDOW_FIRST`) into Layer 2's row A. Layer 2 is stored by columns (byte x·256 + y, 32 columns an 8K page), so the row is written down the columns: for each line byte (4 colour clocks), `pix_tab` gives 2 dots per clock as bytes, each written twice (`inc h` = the next column). 10 pages mapped in turn into slot 2. 320 writes a line. | 7 700 / 10 500 |

## spans.asm: the lines' runs for the playfield collisions

Each river line has a 32-byte record in SPAN_PAGE (page 28 at $4000), in a ring of 256:
the colour clocks where its runs of bank (colour 1) and of edge (colour 2) start and end.
The collisions test sprite rows against these runs instead of pixels.

| routine | called | what and how | A / B |
|---|---|---|---|
| `span_line` | `line_done` | The new line's record from `line_buf` (after `plain_line`): bytes all of the current run's colour (`span_class`) are skipped, the others looked at pixel by pixel (4 unrolled), and each colour change closes a run (`.change`). | 5 400 / 7 900 |
| `plain_line` | `line_done` | `line_buf` without decoration (houses, roads): the bank's bytes where it was drawn, so a line is bank, edge, water, edge, bank (twice with an island). | |
| `spans_clear` | `start_attract` | No runs on any line (screen memory cleared). | |
| `span_init` | `init_tables` | The masks: bits i..j of a byte (`span_masks`). | |

## display_simple.asm: the DLI as a schedule

The biggest cost. It follows the C++ port's `displaySimple` (docs/DLI_REMOVAL.md there): the
Atari's DLI loop (B565–B664) walks the object slots down the screen; its counter X (here
`ds_counter`) goes up one per `STA WSYNC`, and the scanline drawn while X = c is c − 69
(+ `ds_slip`, a line for each time the DLI fell behind). The code does not go scanline by
scanline: it jumps X from event to event (an object's start, its rows, its collision reads,
HITCLR), so the work is per object, plus per row only where a row is tested against the
edge.

What it leaves: `ds_objs` (each object's rows for the sprites: 8 bytes, first line, row
count, shape and colour pointers, x, size), `scan_bank` (the bank colour by river line, via
`ds_bank_ev` → `build_copper`), the collision results in HIT and the slots' edge flags.

`display` itself (~32 700 / 50 400 of its own):

1. Maps SPAN_PAGE, `ds_lms` (which rows have a screen-address instruction: 3 cycles at their start), `dh_lists` (the per-frame collision scanline lists, display_hits), the registers cleared and set as B527–B55C, HIT = $FF.
2. `.slot_loop`, per slot from FIRST_SLOT: `ds_slot_y` (the object's y), X advanced to it (`.wait`; past 255: the end), then the instructions before the rows, each an `ds_inx` (X + 1, Z when it wraps): `ds_fields` (the slot's kind, x, size, flags, the shape's and colour's addresses from the ROM's tables), the first row (`ds_row`).
3. `.rows`: `ds_chunk` (the code from a WSYNC to the next: past 106 cycles with the line's start and draw taken out, the DLI falls a line behind: `ds_slip`), rows = min(row + 1, 256 − X), `ds_obj` (the rows into `ds_objs`), the bridge's road colour by row (`.road`, via `ds_bank`), then the edge test (P3PF) only for kinds 8–$0D (`ds_edge_kind`: helicopters, balloons, ships turn at the edge; the other kinds' bit is never read): a self-modified row loop. Per row: the row's first and last dots from `edge_lo`/`edge_hi` (page 1, built by `panel_init`) scaled by the size (`.s1`/`.s2`: `nop`, `add a,a`), plus x (`.ex1`/`.ex2`), compared with the line's edge runs (SPAN_PAGE); only a row whose span overlaps a run goes to the bit test (`pf_v*` for the size). Stops at the first hit.
4. `.rows_done`: X past the rows, then the object's collision reads, each at its own X: M2PL (bullet, `dh_obj` through the line before, a bridge's through its own), P3PL (shell), the bridge's colour back (`ds_bank`), P2PL (plane: `dh_seen` on `dh_plane_shell`, `dh_obj` for the object), the plane's playfield lists (`dh_seen`), HITCLR (`ds_cleared` = the line). `ds_set_flags` puts the edge bit into the slot.
5. `.end`: the reads after the last object (the panel's), then `ds_bank_fill`.

| routine | called | what and how | A / B |
|---|---|---|---|
| `ds_fields` | `display`, per slot | The slot's fields (kind, x, size, flags, y) and the addresses of its shapes and colours from the ROM tables; past the last slot zeros. | 5 600 / 6 400 |
| `ds_inx` | `display`, several per slot | X + 1, Z at the wrap. Called ~5 times per slot. | 1 800 / 2 000 |
| `ds_slot_y` | `display` | The slot's y ($FF past the last). | 960 / 1 100 |
| `ds_chunk`, `ds_chunk_at` | `display` | The one surviving cycle rule: a code stretch longer than its line puts the DLI a line behind (`ds_slip` + 1). `ds_chunk_at` uses `line_start`/`line_after_draw` (from `init_line_tables`). | 1 500 / 1 800 |
| `ds_after_draw` | `display` | Does an access C cycles after a WSYNC on line A come after A's draw? (M0PF and HITCLR fall either side.) | 790 / 910 |
| `ds_set_flags` | `display` | The object's edge bit into its slot's flags (bit 0). | 1 100 / 1 300 |
| `ds_bank` | `display` | A bank colour change from scanline A (a bridge's road and back): into `ds_bank_ev`. | 750 / 850 |
| `ds_bank_fill` | end of `display` | `scan_bank` for every river line from `ds_bank_ev` (also what nxcheck compares). | 1 800 / 1 900 |
| `ds_lms` | start of `display` | The rows whose display-list instruction has a screen address (the top row, and where screen memory continues in the other block). | 520 / 520 |
| `ds_row_hl`, `ds_edge_only` | `display` | HL += `ds_row`; the edge bit only for the kinds that read it. | |

## display_objs.asm

| routine | called | what and how | A / B |
|---|---|---|---|
| `ds_obj` | `display`, per object with rows | The object's rows for the sprites: first scanline, row count, the first row's shape and colour addresses (DE, IY), x, size: 8 bytes into `ds_objs` (`DS_OBJS` = 16 at most). An object whose first line is at or above line 28 (above the river's top) is extended to its whole shape (k = start − y more rows), so the sprite is drawn whole and the sprites' clip window cuts it. Keeps `ds_obj_last`, `ds_obj_slot` for `dh_obj`. In page 4 in the alignment gap before the palette. | 3 900 / 4 500 |

## display_hits.asm: collisions from the sprites' rows

No collision registers: each read is answered from rows. Five other sprites are described
by 9-byte descriptors in `dh_desc` (copied from `dh_template` each frame and filled in):
page, mask, rotations, x, size, sprite number, first line, rows, clock width (`DH_SIZE` = 9;
`DH_SHELL`, `DH_TANK`, `DH_PLANE`, `DH_MISSILE`, `DH_BULLET`).

| routine | called | what and how | A / B |
|---|---|---|---|
| `dh_lists` | start of `display` | The descriptors, then per-frame lists of the scanlines (17 bytes each: a count, the lines) where: the tank meets the edge (`dh_tank_edge`, P1PF), the plane the bank (`dh_plane_bank`, P2PF), the missile and the bullet the bank (`dh_missile_bank`, `dh_bullet_bank`), the plane and the shell (`dh_plane_shell`, P2PL bit 0), the missile and the plane (`dh_missile_plane`, M0PL). Built once a frame with `dh_pf` and `dh_pair`. | 1 900 / 1 900 |
| `dh_pf` | `dh_lists` | Sprite IX's rows on the river's lines: each row's bits (`dh_bits`) tested by `pf_edge`/`pf_bank`/`pf_under` (display.asm, the runs); hit lines appended to list HL. | 5 600 / 6 900 |
| `dh_pair` | `dh_lists` | The lines where two sprites' rows overlap bit by bit (via `collide`'s list: `dh_add`, `dh_meet`). | 750 / 830 |
| `dh_bits`, `dh_end` | `dh_pf`, `dh_pair`, `dh_obj` | Sprite IX's bits on line A (Z: none); the line after its last row. | 3 400 / 4 200 |
| `dh_add`, `dh_meet` | | A sprite with its bits into `collide`'s list; do sprites B and C touch? | |
| `dh_seen` | `display`, per read | Does list HL have a line in [`ds_cleared`, A] (since the last HITCLR, up to the read)? A linear scan of the list. | 4 000 / 6 500 |
| `dh_obj` | `display`, 3 reads per object (bullet, shell, plane) | Does sprite IX touch the current object's rows (the last `ds_objs` entry, if it is this slot's) on the lines from the last HITCLR to C? Rejects first by rows, slot, then X (the two clock spans), then the line window (max of firsts and `ds_cleared` to min of ends), then per line: the object's row byte, `collide.add` it, the sprite's bits (`dh_bits`, `dh_add`), `dh_meet`. | 7 100 / 8 600 |
| `dh_edge` | | A late object's rows against the edge (the rows' loop in `display` does it for the others). | |

## display.asm: the playfield tests and `collide` (and the old beam model)

Most of this file is the full cycle-exact model of the DLI (`op`, `bm_events`, `bm_draw`,
`rec_set`, `p3_scan`, `bm_wsync`, the beam's `collide` body…), kept for reference and
assembled only with `-DBEAM`. Assembled always:

| routine | called | what and how | A / B |
|---|---|---|---|
| `pf_under`, `pf_bank`, `pf_edge`, `pf_none` | `dh_pf`, `collide` | Is the sprite's row (bits D from bit 7, position E, size A: 1, 2 or 4 clocks a bit) on line `bm_line` over the bank, the edge, or either? Finds the line's record (`pf_line`), then walks its runs (`pf_size`). | 1 500 / 2 300 |
| `pf_line` | `pf_bank`, `pf_edge` | HL = the record of line `bm_line` (carry: a river line). | 2 600 / 4 200 |
| `pf_size`, `pf_v1`, `pf_v2`, `pf_v4` | `pf_*`, `display`'s edge loop | The runs under the sprite: a run that overlaps the sprite's clocks is tested against its bits with `span_masks` (D: the masks' page); one variant per size (N shifts turn a clock offset into a bit index). | 4 100 / 7 200 |
| `collide` (`.add`, `.pair`, `.overlap`, `.entry`) | `dh_obj`, `dh_add`, `dh_meet` | A list of the sprites on a line (bits, position, size) and the bit-exact overlap test between two of them. | 1 500 / 1 200 |
| `bm_hitclr` | `display` | HITCLR: the collision bits cleared. | 1 500 / 1 700 |
| `init_line_tables` | `tv_setup` | Per scanline: ANTIC's cycles at its start (`line_start`) and those left after its draw (`line_after_draw`). | |

## sprites.asm: sprites, the Copper, `apply`, the panel

| routine | called | what and how | A / B |
|---|---|---|---|
| `build_sprites` | `main_frame` | Flips the 4-bit pattern set (`sb_half`: two sets of 12, one shown while the other is written) and clears its "used" table; `ob_list` (the objects); the plane, its bullet, the tank, the helicopter's missile, the shell with `pm_channel` (in the order `drawRiver` draws them, the last on top); `build_copper`. | 1 000 / 1 100 |
| `ob_list` | `build_sprites` | Per `ds_objs` entry, its rows from `ds_objf` (all of them), a sprite per 16 rows (`ob_emit`), none for a piece whose first line is below the river, the row pointers stepping back 16 a chunk (the bottom row is first in memory: `ob_write` steps with self-modified `dec hl`/`dec de`). | 5 700 / 6 400 |
| `ob_emit` | `ob_list` | An 8-bit multicolour pattern for (shape address, colour address, rows): a hash of the key into `OB_BUCKETS`, the key compared (`OB_SHL/SHH/CLL/CLH/N`); found: reused. Not found: a pattern slot (12–61) not used this frame or the last (`OB_FRAME`, so the one on screen is not overwritten) taken in turn, its old key removed, the new one stored, `ob_write`. Then the 5 attribute bytes into `sprite_list` (X = 2·(x − 52), Y, the pattern, the scale for double or quadruple width). Mostly the key check and attribute work: a pattern write is rare once the cache is warm. | 9 700 / 10 400 |
| `ob_write` | `ob_emit` | Pattern A over port $5B: n rows of 8 dots, each dot 2 bytes of colour 128 + Atari colour / 2 (bit set) or 0, then empty rows to 16. | 1 800 / 2 500 |
| `pm_channel` | `build_sprites` | One player or missile from player-missile memory as one 4-bit sprite: only its known rows (E from line D: where the game put it), clipped to the river; nothing if they are empty (an OR over them); a missile's bits converted to a player's byte through a table into `ch_bits`. Then `emit_sprite`. | 2 700 / 3 100 |
| `emit_sprite` | `pm_channel` | A 4-bit pattern for the 16 rows: a hash (rotate-XOR, unrolled) into the set's hash table (page 7 at $4000), compared row by row (unrolled); found: reused; else a new pattern from `exp8` (a byte as 8 nibbles) into the set not shown. The attributes. | 2 600 / 5 200 |
| `build_copper` | `build_sprites` | Only when the bank colours change (`cp_colour`; always while there are bank events, `ds_bank_n` ≠ 0): `copper_start`, then a WAIT + MOVE $41 for each colour change by river line, from `ds_bank_ev`, set on the line before; then the panel's part (`copper_panel`), the end WAIT. `cp_full` = 1. | 1 400 / 1 600 |
| `apply` | after `wait_frame` | Layer 2's scroll (NR $17), the sprites' attributes (port $57, OTIR 5 a sprite; the previous frame's extra ones hidden), the colours of the shell, the tank and the plane (sprite palette), Layer 2's colours 0, 2, 3, `panel_frame`, the Copper: stopped, the whole list sent if `cp_full`, else only the scrolling line's X-scroll byte, restarted (mode %11). The screen off after a long idle (IDLE_TIME). Not in the numbers above. | — |
| `panel_frame` | `apply` | The panel's 3 rows of 20 characters into the tilemap (2 tiles a character), tile 256 for the scrolling line's split edge column (made fresh from the two halves), the scrolling line's tiles and X scroll, the needle's and the logo's sprites. | — |

Data: `copper_start` (Layer 2's palette index 1, a NOP where NR $4A was (T's colour), the tilemap at the panel's first row),
`copper_panel_ntsc`/`_pal` (the same layout, so the offsets from the list's end hold for both:
line 200: Layer 2's colours 0–3 black and the sprites' window from line 215 down (`OBJ_LAST` + 1,
below any object's rows; the needle and the logo lower); 201: grey (`COPPER_GREY`, patched by
`tv_setup`); the tilemap's Y scroll per panel row; line 230 (240 PAL):
colours 0–3 back, the edge's and water's written by `apply` (`CP_EDGE_BACK`); the scrolling
line's Y and X scroll (`CP_XSCROLL_BACK`); at `wait_line`: the sprites' window the river's
again). `apply` sends the edge-to-X-scroll bytes (`.cp_send`) when the list is not sent whole.

## sound.asm: the sound driver and POKEY's samples

| routine | called | what and how | A / B |
|---|---|---|---|
| `sound_driver` | `vbi` | B2A5–B3D8: the original's driver: channel 1 the start beep, event sounds, the low-fuel beep or the engine; 2 an explosion or the missile; 3 firing or a bonus life; 4 the shell. Writes POKEY's AUDF/AUDC (`pokey_audf`, `pokey_audc`). | 770 / 930 |
| `sound_init` | `restart` | The DACs on (NR $08), the ring and channels quiet, `sound_init7` (page 7: the AY, POKEY's tables, the DMA programmed), then the DMA enabled ($87) once page 12 is mapped back. | |
| `pokey_frame` | `main_frame` | `ay_frame` (the pure tones to the AY), then how many samples: the lines left before `wait_line` (NR $1E/$1F), where the DMA is (its address read back), up to `SND_LEAD` (760) ahead, at least `SND_MIN_LEAD` (200), at most `SND_CAP` (700). Then: `snd_fill` (the stretch to 0), each channel not on the AY: volume × 8 (`add a,a` twice) as a constant level (volume only, or AUDF ≤ 4: half) or `pk_channel` (its turns as + and − into the ring), then `snd_sum` (the running sum makes the levels). Pages 14–15 at $0000 meanwhile (the 17-bit counter). | 2 400 / 2 500 |
| `snd_fill` | `pokey_frame` | DE bytes of A from HL in the ring (two stretches at the wrap), each by PUSH from its end down (SP saved). | 2 800 / 2 400 |
| `snd_sum` | `pokey_frame` | The running sum over DE samples: `add a,(hl) / ld (hl),a / inc l`, 8 unrolled, entered at the right point for the remainder (self-modified `jp`), page by page in the ring. ~8 400 ticks for ~270 samples: about 31 a sample. | 8 600 / 7 300 |
| `sound_random` | `sound_driver` | RANDOM for a noise's pitch (not `random_read`, which the checks count). | |

The ring: 1024 bytes at $7C00 (page 12), 1K-aligned, sent to port $DF by the zxnDMA in
burst mode with prescaler 55 (15 909 Hz), restarting at its end. Levels 0–240.

## sound_pulses.asm, sound_handlers.asm: one channel's turns

| routine | called | what and how | A / B |
|---|---|---|---|
| `pk_channel` | `pokey_frame`, per channel with AUDF ≥ 5 | Sets up: the volume's partial values (× 0–3 of 4, for a turn inside a sample), the period's steps for the 4- and 5-bit counters (`snd_mod15/31`), the period as samples and ticks × 64 patched into the loops; the first pulse (`CH_D`, `CH_F`); K = pulses this frame (a division); then the loop for its kind. | 1 500 / 2 800 |
| `pk_tone` | `pk_channel` | A tone: the output turns at every pulse. | |
| `pk_noise` | `pk_channel` | Noise: the 17-bit counter's next bit at every pulse (bits in turn, mapped at $0000). | 4 400 / 8 000 |
| `pk_g4` | `pk_channel` | The 4-bit counter let through by the 5-bit (AUDC 010: the helicopter's missile), straight. | 0 / 480 |
| `pk_other` + `pk_handlers` (`adv31`, `adv15`) | `pk_channel` | The other kinds through handlers. | |
| `pk_on`, `pk_off`, `pk_part*` | the loops | A turn at a pulse: the sample gets the change less the part before the turn, the next sample that part (no buzz from whole samples). | 1 800 / 3 400 |
| `pk_done` | the loops | The rest of the frame's ticks into `CH_D`, `CH_F`, the output kept. | |

## sound_ay.asm (page 7), sound_ay_run.asm (page 6): the pure tones on the AY

| routine | called | what and how | A / B |
|---|---|---|---|
| `ay_init` | `sound_init7` | TurboSound on, the first AY mono, tones only, quiet. | |
| `sound_init7` | `sound_init` | `ay_init`, POKEY's tables into page 1, `snd_mod15/31`, the DMA programmed (not enabled). | |
| `ay_frame` | `pokey_frame` | For POKEY channels 1, 3, 4 with a pure tone (AUDC 101x or 111x, not volume only, volume ≠ 0): the AY period N = (AUDF + 1) × 3.454 (PAL) / 3.422 (NTSC) via `mul d,e`, the volume via `ay_vol`; `ay_mask` tells `pokey_frame` to skip them. The AY gets what was queued 2 frames ago (`ay_q`). | 1 300 / 1 500 |
| `ay_out` | `ay_frame`, `ay_init`, `ay_quiet` | The AY's registers 0–5 and 8–10 from `ay_q`. | 740 / 740 |
| `ay_quiet` | `pokey_frame` (sound off) | All quiet. | |

`sound_ay_run.asm` is in page 6, not 7, so that `pokey_frame` never maps page 7 over the
ring (see NOTES: the crackle).

## panel_init.asm (page 7, at the start)

| routine | called | what and how |
|---|---|---|
| `panel_init` | `start` (page 7 at $6000) | The Atari's character sets built where the game builds them (OS font from `font.inc`, the cartridge's symbols), each character as two tiles (tiles 0–127 the panel's, 128–255 the scrolling line's) in pages 10–11, the tilemap's palette and registers (NR $6B/$6C/$6E/$6F, clip), the needle's and the logo's sprite patterns, the 8-bit pattern cache's tables (`OB_*`), `edge_lo`/`edge_hi` (the first and last set dot of each byte, for the edge test). |

## load_rom.asm (page 7)

| routine | called | what and how |
|---|---|---|
| `load_rom` | `start` (not test builds) | Opens River_Raid.rom in the program's folder through esxDOS (F_OPEN, F_READ, F_CLOSE; by its short name where long names are not seen) and reads its 8192 bytes into $A000 (page 5). Without it: a red border and a stop. Tested only on a real Next. |

## Includes

- `vars.inc`: the Atari RAM addresses of the game's variables (the original's names).
- `palette.inc`: the Atari palette as Next colours (made by `tools/mkpalette`).
- `random.inc`: the RANDOM step's columns (`tools/mkrandom`).
- `font.inc`: the OS font (`tools/mkfont`, AltirraOS's, with its notice).
- `poly.inc`, `poly17.bin`: POKEY's 4-, 5- and 17-bit sequences (`tools/mkpoly`).

## Conventions worth knowing before changing code

- **Self-modifying code** is common in hot loops: patched immediates and jump targets (`display`'s `.ex1/.ex2/.s1/.s2/.pv/.pv_bits/.pv_end/.pv_x`; `ob_write.step_sh/.step_col`; `snd_sum`'s `.jp`; `emit_sprite`'s `.hj/.cj`; `pk_*`'s `.pf/.pq`). A variant must be checked byte by byte (a leftover `add a,a` once doubled the sound).
- **Unrolled entry points**: `snd_sum`, `emit_sprite` jump into the middle of a `rept` block for the remainder.
- **Slot 2** is a scratch window: a routine that needs a page there maps it and does not restore it; the next user maps its own. **Slot 3** must stay page 12 while the sound plays.
- **Tables are page-aligned** so that `ld h,high table / ld l,index` is the lookup: `pix_tab`, `span_masks`, `span_class`, `edge_lo/edge_hi`, `OB_*`, the palette, the hash tables.
- **The checks**: after any change, `nxcheck` compares state, screen and player-missile memory, the bank colour per line, the objects as drawn, the Copper's list and memory every frame, and the picture at the end, against the C++ port. The full set takes ~25 minutes on 2 cores (HANDOFF.md, *Method*). A failed assembly leaves the old pages: check the build output first.
- **Measuring**: `NXHISTALL=file` (all frames) or `NXHIST=file` (one frame) and `tools/prof.py`; `NXSLOW=T` lists the frames over T ticks. `NXHISTAPPLY=file` does the same for `apply` (from the end of `wait_frame`) and prints its average and maximum; `tools/prof_local.py build/test.sym file frames [routine…]` splits the time by local labels too (`display.rows`, `panel_frame.entry`, …).
- **apply** (~42 500 a frame on both runs, not in the tables above): `panel_frame` ~38 000 of it (the panel's 3 rows of 40 tiles rewritten every frame ~21 000, the scrolling line's 39 tiles ~10 000, tile 256 ~5 000), the sprites' attributes ~1 800, the Copper's list ~1 200.
- **display's own time** by part (A / B): the edge test's row loop (`.row` … `.row_on`) ~8 000 / ~25 000 (the line's record found per row, `.ex2` to `.run`, 2 700 / 8 700; the runs walked, `.run`, 1 600 / 5 800); the reads after an object (`.b60a` on) 8 400 / 9 400; the object's rows set up (`.rows`) 6 400 / 8 000; the slot's fields (`.there`) 2 400 / 2 800.
