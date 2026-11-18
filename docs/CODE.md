# The assembly source, file by file

For Z80 programmers who want to read the code or make it faster. For each file: what is in
it, each routine's job, who calls it and when, how it works, and what it costs. The why
behind the design is in [NOTES.md](NOTES.md) and [HANDOFF.md](../HANDOFF.md); the plain-words
picture in [HOW_IT_WORKS.md](HOW_IT_WORKS.md).

## The numbers

Times are the Next core's ticks at 28 MHz, per frame, averaged, from nxcheck's histogram
(`NXHISTALL=file`, then `python3 tools/prof.py build/test.sym file 60`). Two runs:

- **A**: PAL, bot 1, 3 000 frames from the start (the usual early game): ~117 000 a frame on average, ~181 000 at most;
- **B**: `-stress` from bridge 80, PAL, 6 000 frames (`NXBRIDGE=80 NXGHOST=1 NXGAME=1`: all slots taken, full speed, always firing): ~185 000 on average, ~234 000 at most (NTSC ~235 000).

A frame has ~567 000 ticks on PAL and ~481 000 on NTSC (half that at 14 MHz). `apply` (and
so `panel_frame`) runs after the measured work (below the scrolling line) and is not in these
numbers: ~7 400 a frame. A routine's time is its own instructions only: the routines it calls
are counted under their own names.

By part (A / B):

| part | A | B |
|---|---|---|
| the display: objects' placement and collisions (`display_simple`, `display_objs`, `display_hits`, `pf_*` and `collide` in `display.asm`) | 50 500 | 66 400 |
| sound (`pokey_frame`, `snd_*`, `pk_*`, `ay_*`, `sound_driver`) | 25 400 | 43 000 |
| new river lines (`river_gen`, `render_line`, `span_line`, `push_line`) | 19 900 | 45 700 |
| sprites and the Copper's list (`build_sprites`, `ob_*`, `pl_*`, `build_copper`) | 11 600 | 16 400 |
| the game logic and the rest (`prepare`, `main_loop`, `move_objects`, `random_step`, the panel's printing, …) | 11 000 | 13 900 |

The most expensive routines (A / B):

| routine | A | B | file |
|---|---|---|---|
| `render_line` | 7 700 | 16 900 | render |
| `span_line` | 6 300 | 14 900 | spans |
| `pk_noise` | 4 400 | 12 500 | sound_pulses |
| `ds_edge_test` | 3 400 | 11 000 | display_simple |
| `display` (own code) | 8 400 | 9 500 | display_simple |
| `dh_pf` | 8 100 | 9 400 | display_hits |
| `snd_sum` | 8 600 | 8 600 | sound |
| `dh_obj` | 5 100 | 6 500 | display_hits |
| `ds_fields` | 5 700 | 6 500 | display_simple |
| `ds_obj` | 5 400 | 6 300 | display_objs |
| `ob_list` | 4 100 | 5 600 | sprites |
| `draw_line` | 2 300 | 5 200 | river_gen |
| `ob_attr` | 2 900 | 5 200 | sprites |
| `dh_bits` | 4 400 | 4 700 | display_hits |
| `move_objects` | 2 000 | 3 900 | game |
| `pk_channel` | 1 500 | 3 300 | sound_pulses |
| `dl_fill` | 1 300 | 3 000 | river_gen |
| `line_done` | 1 300 | 2 900 | game |
| `pk_off`, `pk_on` | 1 800 | 5 400 | sound_pulses |
| `snd_fill` | 2 800 | 2 800 | sound |
| `pokey_frame` (own code) | 2 400 | 2 500 | sound |
| `dh_lists` | 2 000 | 2 000 | display_hits |
| `pk_g4` | 0 | 1 700 (18 000 in a frame when the missile sounds) | sound_pulses |
| `ds_bank_fill` | 1 800 | 1 600 | display_simple |
| `build_copper` | 1 600 | 1 500 | sprites |

The heaviest frame of B (~234 000): the river's two new lines ~31 000, the sound up to
~40 000 (`pk_g4` ~18 000 of it), the placement (`display`, `ds_fields`, `ds_obj`) ~27 000,
`dh_pf` and `dh_bits` ~26 000, the bank colours and the Copper's list at a bridge
(`ds_bank_fill`, `build_copper`) ~16 500, the edge tests ~10 000.

(`prof.py` takes a routine's name from the nearest global label below the address, so a
data label right in front of code can take its time; the symbols of page 12 at $6000-$7FFF
stand for `panel_init` in page 7 at the same addresses, which runs once at the start.)

## Memory while the code runs

8K slots ($0000, $2000, … $E000) and the pages in them:

| slot | address | normally | remapped by |
|---|---|---|---|
| 0–1 | $0000–$3FFF | 30–31: the Atari's RAM at the original's addresses | `pokey_frame`: 14–15, POKEY's 17-bit counter (`poly17.bin`), while it makes samples |
| 2 | $4000–$5FFF | varies: there is no fixed page | `render_line`: 18–27 (Layer 2, one page per 32 columns); `display`, `span_line`, `spans_clear`: 28 (`SPAN_PAGE`, the lines' runs); `panel_frame`: 11 (the tilemap's map); `panel_init`: 10, 11 |
| 3 | $6000–$7FFF | 12: buffers (`copper_list`, `ds_objs`, `sprite_list`, `ov_exp2`/`ov_exp4` (a byte's dots widened, `dh_obj`), the edge's gaps `eg_*` (`ds_edge_test`), the DAC's ring at $7C00) | only at the start: 7 (`panel_init`, `sound_init7`, `load_rom`). **Never while the sound plays**: the DMA reads the ring through this slot |
| 4 | $8000–$9FFF | 4: code | — |
| 5 | $A000–$BFFF | 5: the cartridge, read from River_Raid.rom | — |
| 6 | $C000–$DFFF | 6: code | — |
| 7 | $E000–$FFFF | 1: variables, tables (the bank's gaps `bg_*` among them), the stack (from $0000 down to above $FF00) | — |

Page 4 ends at ~$9E2C (of $A000), page 6 at ~$DD53 (of $E000), page 7 at ~$6913 (the build
prints these): the DLI's schedule gone left some room. Moving code between pages is how room was
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

With T on (`tm_show`), each of these parts sets the border's colour first (`TM_COLOUR`): orange `apply`, grey `prepare` (and `clear_layer2_page` during a reset), red `display`, yellow `build_sprites`, blue `main_loop`, magenta `push_line` (a new river line, inside `main_loop`), white `vbi`, cyan `pokey_frame`, black the time left. `push_line` sets magenta and back to blue.

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
| `init_tables` | `start` | Once: the tables: `pix_tab` (`render_line`), `ring_lo`/`ring_hi` (screen memory's 160 lines in order), `span_class` (a byte's colour if its 4 pixels are one), `span_init` (the masks), an empty Copper list. |
| `tv_setup` | `restart` | The standard's settings: NR $05 50/60 Hz, `init_line_tables`, `wait_line`, the random map, the Copper's panel part (`copper_panel_ntsc`/`_pal` copied, the grey patched into it, `COPPER_GREY`), the tilemap's first Y scroll, clip windows (Layer 2 down to the panel's last grey line, sprites, tilemap). |
| `init_video` | `start` | Black border, no ULA, global transparency $E3, Layer 2 320×256×8 at bank 9, layer order (tilemap over sprites over Layer 2), the palettes: Layer 2's 4 entries, the sprites' 128–255 = the Atari's colours, NR $15 with the sprites' clip in over-border mode. |
| `test_ghost` | test builds, after `display` when `test_ghost_on` | nxcheck's NXGHOST: the plane's collisions and the fuel set so that it cannot crash. |

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
| `draw_bullet`, `move_bullet` | `fly_plane`, `crash` | The bullet's 8 rows into missile 2's memory (`-DBEAM` only; otherwise `draw_bullet` returns at once). | 380 / 520 |
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
| `draw_logo_and_needle` | `reset`, `start_attract` | The rainbow and the fuel needle into player-missile memory, as sub $B0F1 leaves them (`-DBEAM` only; the Next's are sprites). | |
| `push_line` | `scroll_river`, `start_attract` | A new river line: `next_line` (river_gen) into `line_buf`, then at `line_done` the line into screen memory (48 bytes, the top line's address one line up), `render_line` (Layer 2), `plain_line` and `span_line` (the collisions' runs). | |
| `prepare` | `main_frame` | AE99–AF38 at the frame's top: the tank and the shell gone below the screen, the shell's colour, the panel's lives, bridges and score. The shapes into player-missile memory ($0B00–$0FFF) only in the cycle model's build (`-DBEAM`): the Next's sprites and collisions take them from the ROM. | ~2 000 (3 000 with the copies) |
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
The collisions test sprite rows against these runs instead of pixels. With the same ring
index, its gaps: `eg_e1`–`eg_s2` and `eg_e3`–`eg_s4` (page 12) the water between the edge's
runs (with 2 runs the one between them, with 4 the 1st–2nd and the 3rd–4th, with none all of
the line, else none: $FF); `bg_e1`–`bg_s2`, `bg_e3`–`bg_s4` (page 1) the two widest gaps
between the bank's runs (from clock 32 before the first, to 224 after the last). A box inside
a gap touches nothing on the line.

| routine | called | what and how | A / B |
|---|---|---|---|
| `span_line` | `line_done` | The new line's record from `line_buf` (after `plain_line`): bytes all of the current run's colour (`span_class`) are skipped, the others looked at pixel by pixel (4 unrolled), and each colour change closes a run (`.change`). Then its gaps (`.gaps` from the edge's runs, `.bgaps` from the bank's: the two widest kept, `.gap`). | 6 300 / 14 900 |
| `plain_line` | `line_done` | `line_buf` without decoration (houses, roads): the bank's bytes where it was drawn, so a line is bank, edge, water, edge, bank (twice with an island). | |
| `spans_clear` | `start_attract` | No runs on any line (screen memory cleared). The gaps are left: with no runs nothing can be touched whatever they say, and each new line makes them anew. | |
| `span_init` | `init_tables` | The masks: bits i..j of a byte (`span_masks`). | |

## display_simple.asm: the objects placed, their collisions

As the C++ port's `displayGeometry` (branch `dli_removed`): no DLI. Each object stands at
its slot's y, cut to the river, and its collisions are plain geometry. What it leaves:
`ds_objs` (each object's rows for the sprites: 8 bytes, first line, row count, shape and
colour pointers, x, size), `scan_bank` (the bank colour by river line, via `ds_bank_ev` →
`build_copper`), the collision results in HIT and the slots' edge flags.

`display` (~8 400 / 9 500 of its own):

1. Maps SPAN_PAGE, `dh_lists` (the other sprites' descriptors), the registers cleared and set as B527–B55C, `bm_hitclr`, `dh_sprites` (HIT = $FF, then the other sprites with the bank and each other).
2. `.slot`, per slot from FIRST_SLOT: `ds_fields`; the start = max(y, $5D); the first row = y + height[type] − start (≥ $80: gone above, the next); X = start + 3 (past 255: the end); rows = min(row + 1, 256 − X); `ds_rowp` the first row's byte; `ds_obj` (the rows into `ds_objs`); a bridge: `.road` (the road's colour from the scanline after each row's, X − 69 + 1; the section's bank colour after the last unless X wrapped, via `ds_bank`).
3. The edge (P3PF) for kinds 8–$0D (`ds_edge_kind`: helicopters, balloons, ships turn at it): `ds_edge_test`, then `ds_set_flags`.
4. Against the bullet, the shell (not a bridge) and the plane: `dh_obj`; a touch stores the slot (HIT_BULLET_OBJECT, HIT_SHELL_OBJECT, HIT_PLANE_OBJECT), so the last one down the screen stays.
5. `.end`: `test_ghost` (test builds), `ds_bank_fill`.

| routine | called | what and how | A / B |
|---|---|---|---|
| `ds_fields` | `display`, per slot | The slot's fields (kind, x, size, flags, y) and the addresses of its shapes and colours from the ROM tables; past the last slot zeros. | 5 700 / 6 500 |
| `ds_edge_test` | `display`, per object of kinds 8–$0D | A = $02 if a dot of the object's rows is on an edge pixel. The object's box (X to X + 8, 16 or 32 clocks; none past clock 255) per row against the line's water gaps (`eg_*`, the line's ring index stepping by one); inside one, the next row. Else the row's first and last dots (`edge_lo`/`edge_hi` scaled by the size: `.s1`/`.s2`, plus X: `.ex1`/`.ex2`) against the line's edge runs (its record), and only a row over a run to the dots (`pf_v*`). | 3 400 / 11 000 |
| `ds_set_flags` | `display` | The object's edge bit into its slot's flags (bit 0). | 1 100 / 1 300 |
| `ds_bank` | `display` | A bank colour change from scanline A (a bridge's road and back): into `ds_bank_ev`. | |
| `ds_bank_fill` | end of `display` | `scan_bank` for every river line from `ds_bank_ev` (also what nxcheck compares). | 1 800 / 1 600 |
| `ds_row_hl`, `ds_edge_only` | `display` | HL += `ds_row`; the edge bit only for the kinds that read it. | |

## display_objs.asm

| routine | called | what and how | A / B |
|---|---|---|---|
| `ds_obj` | `display`, per object with rows | The object's rows for the sprites: first scanline, row count, the first row's shape and colour addresses (DE, IY), x, size: 8 bytes into `ds_objs` (`DS_OBJS` = 16 at most). An object whose first line is at or above line 28 (above the river's top) is extended to its whole shape (k = start − y more rows), so the sprite is drawn whole and the sprites' clip window cuts it. At the end of page 4. | 5 400 / 6 300 |

## display_hits.asm: the collisions as geometry

No collision registers and no reads: a collision counts if it happens anywhere on the
sprites' rows. Five other sprites are described by 10-byte descriptors in `dh_desc` (copied
from `dh_template` each frame and filled in): the rows' base (low), mask, rotations, x, size,
sprite number, first line, rows, clock width, the base (high) (`DH_SIZE` = 10; `DH_SHELL`,
`DH_TANK`, `DH_PLANE`, `DH_MISSILE`, `DH_BULLET`). A row of line L is the byte at base + L:
the ROM's shape for the frame (base = its address − the first line, `dh_shape`, `dh_base`);
the missile's and the bullet's rows are `dh_ones` (all set) under their masks ($03; the
bullet $20). After a reset (`pm_empty`, until the next `prepare`) no rows.

| routine | called | what and how | A / B |
|---|---|---|---|
| `dh_lists` | start of `display` | The descriptors. | 2 000 / 2 000 |
| `dh_sprites` | `display` | HIT = $FF, then HIT 0 where: the tank meets the edge (P1PF), the plane the bank (P2PF), the missile and the bullet the bank or the edge (M0PF, M2PF): `dh_pf`; the plane and the shell (P2PL bit 0), the missile and the plane (M0PL): `dh_pair`. | |
| `dh_pf` | `dh_sprites` | NZ: sprite IX's rows meet the playfield (DE: `pf_edge`, `pf_bank`, `pf_under`). Per river line with dots (`dh_bits`): its box (X to X + its clocks) in the line's gaps first (A: bit 0 the edge's `eg_*`, bit 1 the bank's `bg_*`); inside them nothing; else the dots against the runs (the `pf_*` function). Stops at the first touch. | 8 100 / 9 400 |
| `dh_pair` | `dh_sprites` | NZ: two sprites' rows overlap on a line both have, bit by bit (via `collide`'s list: `dh_add`, `dh_meet`). | |
| `dh_bits`, `dh_end` | `dh_pf`, `dh_pair`, `dh_obj` | Sprite IX's bits on line A, at bit 7 (Z: none); the line after its last row. | 4 400 / 4 700 |
| `dh_add`, `dh_meet` | | A sprite with its bits into `collide`'s list; do sprites B and C touch? | |
| `dh_obj` | `display`, per object (bullet, shell, plane) | NZ: sprite IX touches the current object's rows (`ds_rowp`, from the line of X = `ds_counter`, `ds_rows` of them, at `ds_x`, `ds_size`). Rejects first by rows, then X (the two clock spans), then the lines both have; per line the object's row byte and the sprite's bits; with both on the playfield's clocks (32–223) `ov_fast`, else `collide`. | 5 100 / 6 500 |
| `ov_setup`, `ov_fast` | `dh_obj` | A byte at a time: the object's row widened to a clock a bit (`ov_exp2`, `ov_exp4`: tables made by `init_tables`, 1, 2 or 4 bytes into `ov_o`), the sprite's byte (a clock a bit) shifted onto byte k, bit s of it (`ov_k`, `ov_s`; or s clocks before it), one AND with each of the two bytes it covers. | |

## display.asm: the playfield tests and `collide` (and the old beam model)

Most of this file is the full cycle-exact model of the DLI (`op`, `bm_events`, `bm_draw`,
`rec_set`, `p3_scan`, `bm_wsync`, the beam's `collide` body…), kept for reference and
assembled only with `-DBEAM`. Assembled always:

| routine | called | what and how | A / B |
|---|---|---|---|
| `pf_under`, `pf_bank`, `pf_edge`, `pf_none` | `dh_pf` | Is the sprite's row (bits D from bit 7, position E, size A: 1, 2 or 4 clocks a bit) on line `bm_line` over the bank, the edge, or either? Finds the line's record (`pf_line`), then walks its runs (`pf_size`). | 1 500 / 2 300 |
| `pf_line` | `pf_bank`, `pf_edge` | HL = the record of line `bm_line` (carry: a river line). | 2 600 / 4 200 |
| `pf_size`, `pf_v1`, `pf_v2`, `pf_v4` | `pf_*`, `ds_edge_test` | The runs under the sprite: a run that overlaps the sprite's clocks is tested against its bits with `span_masks` (D: the masks' page); one variant per size (N shifts turn a clock offset into a bit index). | 4 100 / 7 200 |
| `collide` (`.add`, `.pair`, `.overlap`, `.entry`) | `dh_obj` (off the playfield's clocks), `dh_add`, `dh_meet` | A list of the sprites on a line (bits, position, size) and the bit-exact overlap test between two of them. | 1 500 / 1 200 |
| `bm_hitclr` | `display` | HITCLR: the collision bits cleared. | 1 500 / 1 700 |
| `init_line_tables` | `tv_setup` | Per scanline: ANTIC's cycles at its start (`line_start`) and those left after its draw (`line_after_draw`); only the `-DBEAM` model reads them now. | |

## sprites.asm: sprites, the Copper, `apply`, the panel

| routine | called | what and how | A / B |
|---|---|---|---|
| `build_sprites` | `main_frame` | `ob_list` (the objects); the plane, its bullet, the tank, the helicopter's missile, the shell (in the order `drawRiver` draws them, the last on top): each its frame's pattern made at the start (`pl_plane`, `pl_tank`, `pl_shell`, `pl_bullet`, `pl_missile`) at its position, `pl_sprite`; `pl_keep` saves their attributes, which a reset's frames (`busy`) show again (`pl_again`); `build_copper`. | 1 000 / 1 100 |
| `pl_sprite` | `build_sprites` | Pattern A ($FF: none) at line D (none below the river), position E, palette offset C: its 5 attribute bytes into `sprite_list` (X = 2·(x − 52), 9 bits; Y; the offset; the pattern; 4-bit, the half pattern). | ~100 a sprite |
| `ob_list` | `build_sprites` | Per `ds_objs` entry, its rows from `ds_objf` (all of them): its picture made at the start found by the top row's shape and colour addresses (`obj_lookup`; not found: `ob_miss`, not drawn), a sprite per 16 rows (`ob_attr`: X = 2·(x − 52), Y, the bank, 4 bits, the half pattern, the scale for double or quadruple width), none for a piece whose first line is below the river. | 5 700 / 6 400 |
| `build_copper` | `build_sprites` | Only when the bank colours change (`cp_colour`; always while there are bank events, `ds_bank_n` ≠ 0): `copper_start`, then a WAIT + MOVE $41 for each colour change by river line, from `ds_bank_ev`, set on the line before; then the panel's part (`copper_panel`), the end WAIT. `cp_full` = 1. | 1 400 / 1 600 |
| `apply` | after `wait_frame` | Layer 2's scroll (NR $17), the sprites' attributes (port $57, OTIR 5 a sprite; the previous frame's extra ones hidden), the colours of the shell, the tank and the plane (sprite palette), Layer 2's colours 0, 2, 3, `panel_frame`, the Copper: stopped, the whole list sent if `cp_full`, else only the scrolling line's X-scroll byte, restarted (mode %11). The screen off after a long idle (IDLE_TIME). Not in the numbers above. | — |
| `panel_frame` | `apply` | The panel: only the positions `panel_put` listed (`pf_dirty`; all after `start_attract`'s copy and `tv_setup`), each from `.cells` (its left half's cell; the row's first character its right half only), 2 cells of tile 2·code + half and the colour bits as the palette offset. The scrolling line (half h at 8h − X0, X0 = 16·TEXT_LO + 38 − 2·FINE_SCROLL): a ring in map row 26 (half h in column h mod 40; only the halves new since the last frame written, `.ring_write`; all 40 after a jump), the X scroll X0 mod 320 (9 bits: `CP_XSCROLL_HI_BACK`, `CP_XSCROLL_BACK`); the tilemap's clip window S = X0 & 7 dots short on the right (the column that wraps); sprite 70 (pattern 20, palette offset 6) at X 320 − S with half h0 + 40 (its 64 bytes written when it changes: `.spr_pattern`). The needle's and the logo's sprites. | ~1 700 the scrolling line, ~200 the panel, ~1 400 needle and logo |

Data: `copper_start` (Layer 2's palette index 1, a NOP where NR $4A was (T's colour), the tilemap's Y and X scroll 0: its lines the screen's, nothing in the rows outside the panel),
`copper_panel_ntsc`/`_pal` (the same layout, so the offsets from the list's end hold for both:
line 200: the tilemap's Y scroll for the panel's first row (`CP_PANEL_Y`, patched by `tv_setup`), Layer 2's colours 0–3 black and the sprites' window from line 215 down (`OBJ_LAST` + 1,
below any object's rows; the needle and the logo lower); 201: grey (`COPPER_GREY`, patched by
`tv_setup`); the tilemap's Y scroll per panel row; line 230 (240 PAL):
colours 0–3 back, the edge's and water's written by `apply` (`CP_EDGE_BACK`); the scrolling
line's Y and X scroll (`CP_XSCROLL_HI_BACK`, `CP_XSCROLL_BACK`); at `wait_line`: the sprites' window the river's
again). `apply` sends the edge-to-X-scroll bytes (`.cp_send`) when the list is not sent whole.

## panel.asm (page 6): the panel's characters

| routine | called | what and how |
|---|---|---|
| `panel_put`, `panel_put_de` | the panel's writers | A character into the panel at HL (DE): nothing if it is there already; else written and its position listed in `pf_dirty` (60 or more: all). |
| `print_bcd` | `show_score`, `show_other_score`, `show_high_score`, `show_bridges`, the game over | B BCD bytes at HL as digits at DE, '0' = C, leading zeros blank; nothing in the attract mode. Per place (score, high or other score, bridges, other bridges) it keeps the digits' base and the bytes it printed (`pb_cache`) and returns at once when they are the same. |
| `show_lives` | `prepare` and others | The lives' symbols; nothing when their number is the one printed last (`sl_last`). |
| `pb_forget` | `start_attract` | The numbers printed last forgotten (all printed again). |

The places that overlap forget each other's: the lives and the other player's bridges, the
game-over text in the lives' place.

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
| `panel_init` | `start` (page 7 at $6000) | The Atari's character sets built where the game builds them (OS font from `font.inc`, the cartridge's symbols), each character as two tiles (tiles 0–127 the panel's, 128–255 the scrolling line's) in pages 10–11, the tilemap's palette and registers (NR $6B/$6C/$6E/$6F, clip), the needle's and the logo's sprite patterns, `edge_lo`/`edge_hi` (the first and last set dot of each byte, for the edge test). |
| `pl_pics` | `panel_init`, before `obj_pics` (page 7) | The plane's 10 frames (14 rows), the tank's 8 (11 rows) and the shell's 7 (16 rows) from their ROM pointer tables, as `prepare` copies them into player-missile memory: a 4-bit pattern each (a dot: 2 pixels of value 1), shared by frames with one address, none for an all-empty one ($FF); the bullet (8 rows of one dot) and the helicopter's missile (one row of 4 dots). Patterns from 0 (20 of them). |
| `obj_pics` | `panel_init` (page 7) | The objects' pictures: for types 7–15 the kinds they can have (their own, `ROM_NEXT_KIND`'s below $0C, the explosion's from 2 and 3), each mirrored too, height + 1 rows; 58 pictures as 4-bit patterns from 24, a dot's value its row colour's place in palette bank 14 (types 12, 15) or 15 (the others); `obj_head`/`obj_e` for `obj_lookup`. |

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

- **Self-modifying code** is common in hot loops: patched immediates and jump targets (`ds_edge_test`'s `.bx1/.be1/.bx2/.be2/.ex1/.ex2/.s1/.s2/.pv/.pv_bits/.pv_end/.pv_x`; `dh_pf`'s `.mode/.x0a…/.x1d/.bits/.fn`; `snd_sum`'s `.jp`; `pk_*`'s `.pf/.pq`). A variant must be checked byte by byte (a leftover `add a,a` once doubled the sound).
- **Unrolled entry points**: `snd_sum` jumps into the middle of a `rept` block for the remainder.
- **Slot 2** is a scratch window: a routine that needs a page there maps it and does not restore it; the next user maps its own. **Slot 3** must stay page 12 while the sound plays.
- **Tables are page-aligned** so that `ld h,high table / ld l,index` is the lookup: `pix_tab`, `span_masks`, `span_class`, `edge_lo/edge_hi`, `obj_head`, `ov_exp2`/`ov_exp4`, `eg_*`, `bg_*`, the palette.
- **The checks**: after any change, `nxcheck` compares state and screen memory, the bank colour per line, the objects as drawn, the Copper's list and memory every frame, and the picture at the end, against the C++ port. The full set takes ~25 minutes on 2 cores (HANDOFF.md, *Method*). A failed assembly leaves the old pages: check the build output first.
- **Measuring**: `NXHISTALL=file` (all frames) or `NXHIST=file` (one frame) and `tools/prof.py`; `NXSLOW=T` lists the frames over T ticks. `NXHISTAPPLY=file` does the same for `apply` (from the end of `wait_frame`) and prints its average and maximum; `tools/prof_local.py build/test.sym file frames [routine…]` splits the time by local labels too (`ds_edge_test.row`, `panel_frame.mod`, …). The heaviest frames: `-stress` with `NXBRIDGE=80 NXGHOST=1 NXGAME=1`.
- **apply** (~7 400 a frame, not in the tables above): the scrolling line ~1 700 (the X scroll mod 320 by subtraction ~650 of it), the needle and logo ~1 400, the panel ~200 (only what changed), the sprites' attributes ~1 800, the Copper's list ~1 200.
- **A rewrite** is quickest made sure of by a test build that runs the new way beside the old one every frame and counts where they differ (done for the collision rows, the placement, the cursors), then dropping the old.
