# River Raid (Atari 8-bit) → ZX Spectrum Next: project state

English | [Русский](HANDOFF.ru.md)

This file is for picking the work up on any computer or in a new chat. Start a new session with "read HANDOFF.md and docs/NOTES.md".

## Goal
River Raid (Activision, Atari 800, 1983, by Carol Shaw) on the ZX Spectrum Next, built on the C++ port in [djdron/river_raid](https://github.com/djdron/river_raid):
- the game logic as the original's, frame by frame: the same RAM at the same addresses, checked against the C++ port and against the original itself;
- the picture on the Next's hardware (Layer 2, sprites, tilemap, Copper), the same as the C++ port's drawing pixel for pixel;
- in time: a frame's work within a 50 Hz frame at 28 MHz;
- no original assets are distributed: the program reads the user's ROM at run time.

## State
The game is complete, with its sound: attract mode, games 1–8, one and two players, the plane, fuel, enemies, tanks, missiles, bridges, score, lives, high scores, pause, the panel and the scrolling line with the rainbow logo. PAL (50 Hz) by default, NTSC (60 Hz) with CAPS + 1. Checked frame by frame against the C++ port (bot games, hundreds of thousands of frames, PAL and NTSC, bridges 1–200) and against the original on libatari800. Not yet run on a real Next: only on Xpeccy+'s Next core.

There is no DLI any more, neither its cycles nor its loop: each object stands at its own slot's y, cut to the river, and the collisions are plain geometry (boxes, then the dots), each where the sprites' and the objects' rows touch at all. This changes the game slightly: the original reads the collision registers in windows (from a HITCLR to a read, object by object), and misses some touches or sees them a frame later; measured over long bot runs 0.01–0.25% of frames decide otherwise, always a touch the original sees a frame later or not at all (the bullet on an object's last row, the plane's or the tank's rows below the last read). Done first in the C++ port's `displayGeometry` (branch `dli_removed`, the default there; the original's reads stay as `RR_DISPLAY=simple`), then here, and checked frame by frame against it. Before, the objects were placed by the DLI's counter: it never fell behind an object in 120 000 frames, so the placement is the same; the old schedule is in git history and on the C++ port's `dli_removal` branch.

Speed (28 MHz, in the core's ticks a frame's work; a 50 Hz frame is ~567 000, 60 Hz ~481 000): the start of a game (PAL, 3 000 frames) ~117 000 on average, ~181 000 at most; the heaviest load, `-stress` from bridge 80 (all slots taken, full speed, firing all the time), ~185 000 on average and ~234 000 at most on PAL, ~235 000 at most on NTSC. So at 14 MHz (half: ~283 000 PAL, ~240 000 NTSC) even the heaviest frames fit, NTSC with ~5 000 to spare. The heaviest frame: the river's new lines ~31 000 (`render_line`, `span_line`), the sound up to ~40 000 (`pk_g4`, the helicopter's missile, ~18 000 of it), the objects' placement ~27 000, the edge tests ~10 000, the sprites ~13 000. `apply` (below the scrolling line) ~7 400.

Controls, building, checks: [README.md](README.md).

## What you need
- The whole project folder; `make deps` fetches sjasmplus, the C++ port and Xpeccy+ into `deps/`.
- Your own ROM `River_Raid.rom` (8192 bytes, no header) at `rom/River_Raid.rom` for the checks; on the Next, next to the .nex.

## Layout
| Path | What |
|---|---|
| `src/river_raid.asm` | the program: memory map, start and restart (PAL/NTSC), the frame loop, tables, the data pages; builds the .nex or the test pages |
| `src/river_gen.asm` | the river generator (`river_gen.cpp` line for line) |
| `src/game.asm` | attract mode start, `prepare`, the objects' movement, the VBI (colours, scrolling line, POKEY's counter) |
| `src/sound.asm`, `src/sound_pulses.asm`, `src/sound_ay.asm`, `src/sound_ay_run.asm` | the sound driver (POKEY's registers), pure tones on the AY, POKEY emulated into the DMA's ring, the DMA and DAC set up (the channels' pulses and the AY's per-frame code in page 6: the DMA reads the ring at $7C00 through the MMU, so nothing may map another page at $6000-$7FFF while the sound plays) |
| `src/play.asm` | the main loop: controls, pause, the plane, explosions, crashes, resets, new games |
| `src/panel.asm` | the panel's characters (page 6): `panel_put` writes one only if it changed and lists it for `panel_frame`; `print_bcd`, `show_lives` print nothing that is already there (`pb_cache`, `sl_last`) |
| `src/display_simple.asm` | the display: each object at its slot's y (its rows into `ds_objs`), a bridge's road colours, the object's collisions (`dh_obj`), its edge (`ds_edge_test`), the bank colours |
| `src/display_hits.asm` | the collisions as geometry: the other sprites' rows from the ROM's shapes (`dh_lists`), with the bank and each other once a frame (`dh_sprites`: `dh_pf`, `dh_pair`), an object against the bullet, shell, plane (`dh_obj`; a byte at a time: `ov_setup`, `ov_fast`) |
| `src/display_objs.asm` | `ds_obj` (page 4, in the palette's alignment gap) |
| `src/display.asm` | the helpers (`pf_*`, collide's `.add`/`.pair`); with `-DBEAM` the old cycle model of the DLI (no longer builds) |
| `src/sprites.asm` | the objects, the other players and missiles as 4-bit sprites (their pictures made at the start: `obj_pics.asm`), the Copper's list (bank colours), `apply`, `panel_frame` (the panel's changed characters, the scrolling line's ring and sprite, the needle and logo) |
| `src/spans.asm` | each river line's runs of bank and edge pixels, from the line without its decoration, and its gaps (the water between the edge's runs, `eg_*`; the two widest between the bank's, `bg_*`) |
| `src/load_rom.asm` | reading `River_Raid.rom` at the start (page 7) |
| `src/render.asm` | a river line into Layer 2 |
| `src/panel_init.asm` | 8K page 7, at the start only: character sets, tiles, fixed sprite patterns, palettes |
| `src/obj_pics.asm` | page 7, at the start only: the objects' (`obj_pics`) and the other players' and missiles' (`pl_pics`) pictures as 4-bit sprite patterns, the objects' lookup table |
| `src/vars.inc` | the original's RAM addresses and ROM tables |
| `src/palette.inc`, `src/random.inc`, `src/font.inc`, `src/poly.inc`, `src/poly17.bin` | made by `make palette` (tools/mkpalette, mkrandom, mkfont, mkpoly) |
| `tools/nxcheck.cpp` | the checks: the program on Xpeccy+'s Next core beside the C++ port, or against rr_oracle's runs (`-oracle`) |
| `tools/check_original.sh` | `make check-original`: the eight runs of the original |
| `tools/prof.py` | per-routine time from nxcheck's histograms |
| [docs/NOTES.md](docs/NOTES.md) | how it is done and what was found, with numbers |
| [docs/HOW_IT_WORKS.md](docs/HOW_IT_WORKS.md) | how the Atari's picture and collisions are made on the Next, for everyone |
| [docs/CODE.md](docs/CODE.md) | the assembly files routine by routine: what, when, how, and the ticks each costs |

## Established facts (all checked)
1. **Same RAM.** The Atari's 16 KB of RAM is 8K pages 30–31 at $0000–$3FFF: every variable at the original's address. A RAM dump compares byte for byte with the original's and the C++ port's (`Game::diffWithRam`).
2. **Cartridge at its own address.** The ROM is page 5 at $A000–$BFFF: tables are read where the original reads them; nothing from it is in the program.
3. **No DLI.** Each object's rows from X = max(y, $5D) + 3 (scanline X − 69) as many as come before X wraps (the river's end): the same as the DLI's loop put them, which never fell behind an object (checked over 120 000 frames in the C++ port). No cycles, no reads, no HITCLR.
4. **Collisions as geometry.** What the game reads: P1PF (tank, edge), P2PF (plane, bank), M0PF and M2PF (missile, bullet: bank or edge), P3PF (object, edge, only for helicopters, balloons, ships), P2PL (plane with shell and object), P3PL (shell, object; not a bridge), M2PL (bullet, object), M0PL (missile, plane). The other sprites' rows are only where the game put them (shell 16 rows from shellY, tank 11 from tankY, plane 14 from $AA, missile its row, bullet 8 below bulletY), their bits the ROM's shapes (player-missile memory is not written any more outside `-DBEAM`); a collision counts if it happens anywhere on their rows; an object hit is the last one down the screen. Boxes first: a sprite's or an object's box against each line's gaps (`eg_*`, `bg_*`) before its dots; a sprite against an object by their clocks, then the lines both have, then the dots a byte at a time.
8. **Player-missile memory is not written.** Nothing in the game reads it back: the sprites' pictures and the collisions' rows come from the ROM's shapes (only the `-DBEAM` build writes it).
5. **POKEY's RANDOM** is a 17-bit counter; the program keeps it at the game logic's read point (A205) and moves it one frame on per VBI (a matrix, NTSC or PAL).
6. **PAL/NTSC** as in the C++ port: display list end (panel line 190/194), panel and logo layout, reset frames 13/8, depot limit $2E/$2F, RANDOM read point, the scrolling line's start, the VBI before sub $B21A at a game over on PAL.
7. **Game over race.** At a game over the original's frame counter lands before or after its VBI by the frame's length; the C++ port, and so the program, takes the usual case. The two differences in `make check-original` are this.

## Environment limits
- sjasmplus 1.24.1 (commit 5c44bea), Xpeccy+ commit 0ec06e33, river_raid commit 69d00e8 (branch `dli_removed`): `tools/get_deps.sh`. Every change of the C++ port that the program follows needs this commit moved too. Xpeccy+ 2026.10.1 (the user's) draws lines below the visible ones that the headless core does not (`NXFULL=1` writes the whole frame buffer).
- Xpeccy+'s Next core is used headless through libxpeccy: no firmware (palettes start at 0), not `comp_power_on`; at 60 Hz its picture starts at Layer 2 row 0, at 50 Hz at 24.
- The checks need the ROM; CI only builds the .nex (artifact without a zip).
- Code is indented with tabs; documentation in English (`X.md`) and Russian (`X.ru.md`), every change in both.
- Commits: author `djdron <djdron@gmail.com>`, message ending with `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`, no session link.

## Method
Anything that changes what the game does is done first in the C++ port (now branch `dli_removed`), checked there, committed with its docs; then ported here and checked with nxcheck, which links the C++ port from `deps/river_raid` (`tools/get_deps.sh` pins the commit). On `dli_removed` the default is `displayGeometry`; `RR_DISPLAY=simple` is the original's reads (as `dli_removal`, checked against the original with `game_check` and `rr_oracle`), `RR_GEOMCHECK=1` counts the frames where geometry decides otherwise (`=2` prints each: what, where). What only concerns the Next's hardware (sprites, Copper, tables) is done here only.

nxcheck checks after every frame: the game's state, screen memory, the bank colour by river line, the objects as drawn (`ds_objs` against the C++ port's `drawn`), the Copper's memory and list; at the end the picture pixel by pixel. The full set (about 25 minutes on 2 cores): `-pal` and `-ntsc` 3 000 frames, `-bot 2` and `-bot 3` 20 000, `-bot 8` and `-bot 9` 30 000, `-attract` 20 000, `NXGAME=7` PAL and NTSC and `NXGAME=5` 10 000. The later bridges: `NXBRIDGE=n NXGHOST=1 NXGAME=1` (every game from bridge n, the plane unable to crash on both sides). The heaviest frames: `-stress` with `NXBRIDGE=80 NXGHOST=1 NXGAME=1` (the bot at full speed, always firing, no pauses; all slots taken). Speed: `NXHISTALL` (all frames) or `NXHIST` (one frame) and `tools/prof.py`, `tools/prof_local.py` (by local labels); `NXSLOW=T` lists the frames over T ticks. A test build that compares a new way with the old one every frame and counts the differences (as was done for the collision rows, the cursors and the placement) is the quickest way to be sure of a rewrite.

## Decisions
- The C++ port is the spec, not the 6502 listing: same speed on the Z80, readable, already checked.
- Layer 2 at 320x256 holds the playfield's 2-bit colour indices, 160 of the 192 colour clocks, two dots each; the bank, edge and water colours are palette entries, the bank's per line by the Copper (its list sent again only when the bank's colours change).
- Each object is a ready-made sprite with its rows in their colours (a 4-bit pattern made at the start, `obj_pics`: a dot is its row colour's place in sprite palette bank 14 or 15; found by its top row's shape and colour addresses); an object above the river's top is drawn whole and clipped by the sprites' clip window. The other players and missiles are a sprite each at the game's position, each frame of theirs a 4-bit pattern made at the start too (`pl_pics`); nothing is written into pattern memory while playing.
- The display follows the C++ port's displayGeometry: no DLI, the collisions as geometry (0.01–0.25% of frames decide otherwise than the original, a frame earlier). Chosen for the speed at 14 MHz: the DLI's schedule and reads were ~145 000 ticks in the heaviest frame, now ~45 000.
- The worst frame is the measure, not the average: shortcuts that only skip work when nothing changed (the panel's numbers) help the average; what lowers the worst frame is work not done at all (pictures made at the start, the scrolling line's ring) or done cheaper every time (gaps instead of runs, a byte at a time instead of a dot).
- The scrolling line is a ring in the tilemap's row 26 (half character h in column h mod 40, the X scroll X0 mod 320; only new halves written); the column that wraps round to the right edge is cut off there by the tilemap's clip window (S = X0 & 7 dots, set every frame), and one sprite (pattern 20, palette offset 6) shows the next half there, its 64 bytes written only when it changes. The panel's characters are written into the tilemap only when they change (`panel_put`, `pf_dirty`). The Copper leaves the tilemap's Y scroll 0 until line 200 (so whenever it starts a frame, nothing of the panel shows below the scrolling line; Xpeccy+ 2026.10.1 showed the scrolling line again there before, confirmed gone).
- The panel and scrolling line are the tilemap; the panel's grey is Layer 2's (its 4 colours made grey by the Copper on the panel's lines, its clip window down to the panel's last grey line), so it is 320 dots wide like the river; the fallback colour stays black, the border too.
- The picture is the Next's 320 dots, colour clocks 20–179: the C++ port shows 12–179 (and the scrolling line's 192); the 8 on the left stay out (the border can only be a flat colour, and the sprites would vanish over it). In the attract mode the scrolling line lacks 2 characters on the left, about 1 on the right.
- The pixels' shape is left to the screen: Xpeccy+ square; the C++ port 0.86 (NTSC) / 1.03 (PAL); a real Next on HDMI at 60 Hz about 0.89.
- The sound: the DAC's gain fixed at 8 a volume unit (levels to 240), keeping the C++ port's balance with the AY's tones (at the YM table's top); mono, as the original. In Xpeccy+ it is about half the C++ port's loudness (one DAC a side in the Next's mix; DAC and PSG volumes 80 by default).
- The frame goes live below the scrolling line (raster line 208 NTSC, 220 PAL).
- PAL by default; CAPS + 1 switches and starts again as if the machine were switched on (P is "right" in Q A O P).
- Controls: Q A O P, Space/M fire, Enter START, G SELECT, H pause; Kempston 1 and 2, Mega Drive START and A. CAPS + 1 PAL/NTSC, CAPS + 2 the sound off/on, CAPS + 3 28/14 MHz (NR $07: `cpu_14`; the program starts at 28), CAPS + 4 the noise on the AY or the DAC (`ay_noise`, on at the start; sound_ay.asm: channel 1's noise on the second AY, 2's on the third, 4's on the first's C, N = (AUDF + 1) x 1.727 at most 31, so noise below AUDF 17 plays higher; the checks' build starts with the DAC, nxcheck NXAYNOISE=1 the AY's). Screen memory exists only in the -DTEST and -DBEAM builds (SCREEN_MEMORY; -DNOSCREEN with NXNOSCREEN=1 to measure the check's build without it); draw_line records its pieces in `dl_seg` for render_line and span_line. T toggles the frame's work on the border: the fallback colour (the border's, and where no layer draws) a colour per part from `apply` on (orange `apply`, grey `prepare` (and `clear_layer2_page` during a reset), red `display`, yellow `build_sprites`, blue `main_loop`, magenta `push_line` (a new river line, inside `main_loop`), white `vbi`, cyan `pokey_frame`, black the time left; `TM_*` in river_raid.asm, `TM_COLOUR`), so the coloured lines from `wait_line` on are the time each part takes.

## Open questions
- Not tried on a real Next; the keyboard and joystick reading is untested (the checks give the controls directly). Speed is measured on Xpeccy+'s Next core; the real machine's memory wait states at 28 MHz are not checked.
- The sound has been heard only on Xpeccy+ (the crackle there was the DMA reading another page mapped over the ring: fixed; nothing may map over $6000-$7FFF while it plays). Not on a real Next: the zxnDMA (burst mode, prescaler 55, auto restart, read back of its address) and the DAC on port $DF are as Xpeccy+'s core models the VHDL.
- The ROM is now read by `load_rom` in page 7 (moved for room); test builds do not have it, so it is checked only on a real Next.
- The collisions as geometry (above): whether the frame-earlier touches are noticed by a player is not tried; the original's reads can come back as an option (the C++ port keeps them, `RR_DISPLAY=simple`; here they are in git history).
- Power-on before the attract mode (the first 38/25 frames) is not shown; the program starts at the attract mode.

## Next steps
- The river's new lines (`render_line` ~17 000, `span_line` ~15 000 at full speed, two lines a frame): the biggest cost left in every heavy frame.
- The sound's peaks: the helicopter's missile (`pk_g4`, ~18 000), the noise (`pk_noise`, ~13 000).
- `display`'s own placement (~11 000) and `ds_fields`, `ds_obj` (~7 000 each); the X scroll mod 320 of the scrolling line by subtraction (~650).
- The docs of the C++ port's `dli_removed` branch (docs/DLI_REMOVAL.md: displayGeometry).
- If wanted: the AY's tones in stereo (NR $09).
- Run it on a real Next (the keyboard, the joysticks, the DMA sound, the ROM loading, the speed with memory wait states).
