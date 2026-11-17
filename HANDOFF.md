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
The game is complete, with its sound: attract mode, games 1–8, one and two players, the plane, fuel, enemies, tanks, missiles, bridges, score, lives, high scores, pause, the panel and the scrolling line with the rainbow logo. PAL (50 Hz) by default, NTSC (60 Hz) with CAPS + 1. Checked frame by frame against the C++ port (bot games, hundreds of thousands of frames, PAL and NTSC) and against the original on libatari800 (eight runs, 37 000 frames). Not yet run on a real Next: only on Xpeccy+'s Next core.

The display no longer counts the DLI's cycles (display_simple.asm, after the C++ port's displaySimple; -DBEAM builds the cycle model): same frames, a frame's work ~301 000 ticks on average (bot 1, PAL) against ~340 000; at bridge 50 none late on PAL, on NTSC 6.7% of frames instead of 43%.

Speed before that (28 MHz, PAL): a frame's work is about 60–61% of a 50 Hz frame on average, up to about 88%; no frame late in 60 000. The sound is about 25 000 ticks a frame on average (up to ~60 000; fewer samples in a busy frame). NTSC at 60 Hz: about 1 frame in 140 is late and shown twice. At bridge 50 and on the scenes are much busier (`NXSOLO=1 NXGAME=7`: ~441 000 ticks on average, 1 frame in 235 late on PAL, 45% on NTSC); on a real Next it slows down there, with and without the sound (CAPS + 2).

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
| `src/sound.asm`, `src/sound_pulses.asm`, `src/sound_ay.asm` | the sound driver (POKEY's registers), pure tones on the AY, POKEY emulated into the DMA's ring, the DMA and DAC set up (the channels' pulses in page 6) |
| `src/play.asm` | the main loop: controls, pause, the plane, explosions, crashes, resets, new games, the panel's characters |
| `src/display.asm` | the DLI as the C++ port's Beam models it: cycle counts, events, collisions |
| `src/sprites.asm` | players and missiles as sprites, the Copper's list, `apply`, the panel and scrolling line per frame |
| `src/render.asm` | a river line into Layer 2 |
| `src/panel_init.asm` | 8K page 7, at the start only: character sets, tiles, fixed sprite patterns, palettes |
| `src/vars.inc` | the original's RAM addresses and ROM tables |
| `src/palette.inc`, `src/random.inc`, `src/font.inc`, `src/poly.inc`, `src/poly17.bin` | made by `make palette` (tools/mkpalette, mkrandom, mkfont, mkpoly) |
| `tools/nxcheck.cpp` | the checks: the program on Xpeccy+'s Next core beside the C++ port, or against rr_oracle's runs (`-oracle`) |
| `tools/check_original.sh` | `make check-original`: the eight runs of the original |
| `tools/prof.py` | per-routine time from nxcheck's histograms |
| [docs/NOTES.md](docs/NOTES.md) | how it is done and what was found, with numbers |
| [docs/HOW_IT_WORKS.md](docs/HOW_IT_WORKS.md) | how the Atari's picture and collisions are made on the Next, for everyone |

## Established facts (all checked)
1. **Same RAM.** The Atari's 16 KB of RAM is 8K pages 30–31 at $0000–$3FFF: every variable at the original's address. A RAM dump compares byte for byte with the original's and the C++ port's (`Game::diffWithRam`).
2. **Cartridge at its own address.** The ROM is page 5 at $A000–$BFFF: tables are read where the original reads them; nothing from it is in the program.
3. **The DLI decides collisions by cycle.** `display.asm` runs the DLI's instructions with their cycle counts and the beam's events (line drawn at 28, next line at 114, WSYNC to 106) as the C++ port's Beam does. Inside an object's rows and while waiting for an object, every line goes the same way, so those loops run without counting (docs/NOTES.md, "Fast loops").
4. **Only the collisions the DLI reads** are computed: P1–P3, M0, M2 with the playfield; M0–P2, M2–P3, P2–P0, P2–P3, P3–P0 with each other. Water under a sprite is never looked at.
5. **POKEY's RANDOM** is a 17-bit counter; the program keeps it at the game logic's read point (A205) and moves it one frame on per VBI (a matrix, NTSC or PAL).
6. **PAL/NTSC** as in the C++ port: display list end (panel line 190/194), panel and logo layout, reset frames 13/8, depot limit $2E/$2F, RANDOM read point, the scrolling line's start, the VBI before sub $B21A at a game over on PAL.
7. **Game over race.** At a game over the original's frame counter lands before or after its VBI by the frame's length; the C++ port, and so the program, takes the usual case. The two differences in `make check-original` are this.

## Environment limits
- sjasmplus 1.24.1 (commit 5c44bea), Xpeccy+ commit 0ec06e33, river_raid commit 7fb27a8: `tools/get_deps.sh`.
- Xpeccy+'s Next core is used headless through libxpeccy: no firmware (palettes start at 0), not `comp_power_on`; at 60 Hz its picture starts at Layer 2 row 0, at 50 Hz at 24.
- The checks need the ROM; CI only builds the .nex (artifact without a zip).
- Code is indented with tabs; documentation in English (`X.md`) and Russian (`X.ru.md`), every change in both.
- Commits: author `djdron <djdron@gmail.com>`, message ending with `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`, no session link.

## Method
Each step is ported from the C++ port (which is the spec, line for line, with the original's addresses in comments) and checked with nxcheck: state after every frame, the DLI's record per line, the last picture pixel by pixel; then against the original (`make check-original`). Speed work is measured with `NXHISTALL` (all frames) or `NXHIST` (one frame) and `tools/prof.py`, and every change re-checked over long bot runs (30 000 frames, two bots).

## Decisions
- The C++ port is the spec, not the 6502 listing: same speed on the Z80, readable, already checked.
- Layer 2 at 320x256 holds the playfield's 2-bit colour indices, 160 of the 192 colour clocks, two dots each; the bank, edge and water colours are palette entries, the bank's per line by the Copper.
- Each object (player 3) is a ready-made sprite with its rows in their colours (8-bit pattern, made once and kept); the other players and missiles are 16-line runs as sprites with 4-bit patterns.
- The panel and scrolling line are the tilemap; the panel's grey is the fallback colour.
- The frame goes live below the scrolling line (raster line 208 NTSC, 220 PAL).
- PAL by default; CAPS + 1 switches and starts again as if the machine were switched on (P is "right" in Q A O P).
- Controls: Q A O P, Space/M fire, Enter START, G SELECT, H pause; Kempston 1 and 2, Mega Drive START and A.

## Open questions
- Not tried on a real Next; the keyboard and joystick reading is untested (the checks give the controls directly). Speed is measured on Xpeccy+'s Next core; the real machine's memory wait states at 28 MHz are not checked.
- The sound has not been heard on a real Next: the zxnDMA (burst mode, prescaler 55, auto restart, read back of its address) and the DAC on port $DF are as Xpeccy+'s core models the VHDL.
- NTSC at 60 Hz: the busiest frames take more than a 60 Hz frame (about 1 in 140 late).
- The busy scenes from bridge 50 on: slow on a real Next on PAL and more on NTSC; the work there needs to come down by 10-15% (collisions ~120 000 ticks, the DLI model ~125 000, sprites and the Copper's list ~110 000).
- Power-on before the attract mode (the first 38/25 frames) is not shown; the program starts at the attract mode.

## Next steps
- The sound cheaper: the running sum (`snd_sum`, ~8 600 ticks a frame) and the ring's clearing (~2 800) are nearly half of it.
- Optionally more speed. Now the work is about 42% the DLI model, 25% sprites and the Copper's list, 25% collisions (docs/NOTES.md, Speed); a per-object box test before the per-line collision work is the first idea to measure.
