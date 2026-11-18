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

The Atari's DLI is no longer played: only its loop is kept, as a schedule (which rows each object shows, where each collision read and HITCLR comes, the few cycle rules that move them). The objects are ready-made multicolour sprites, the collisions come from the sprites' rows (boxes, then bits), the bank's edge from each row's first and last dots. All of it is done first in the C++ port's `displaySimple` (branch `dli_removal`, its docs/DLI_REMOVAL.md), checked there against the original, then here. The one known difference from the original: when its DLI falls a line behind (about 2 frames in 100 000, seen only from bridge 100 on), the original shows last frame's rows of an object where the late ones go; the port draws the new ones (collisions the same).

Speed (28 MHz, PAL, bot 1, 3 000 frames): a frame's work ~169 000 ticks on average, ~281 000 at most: about 30% of a 50 Hz frame, at most about 50%. Bridge 50 on NTSC (`NXGHOST=1 NXGAME=7`): ~221 000 on average, none late (it was 43% late before this work). Where it goes: the DLI's schedule ~48 000, collisions ~31 000, sprites ~25 000, sound ~19 000, river lines into Layer 2 ~18 000, the game itself ~15 000.

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
| `src/play.asm` | the main loop: controls, pause, the plane, explosions, crashes, resets, new games, the panel's characters |
| `src/display_simple.asm` | the display (default): the DLI's loop as a schedule, each object's rows into `ds_objs`, a bridge's road colours, the edge test, the collision reads, the bank colours |
| `src/display_hits.asm` | the collisions from the sprites' rows: the scanlines of each read's collision (`dh_lists`), an object's at its reads (`dh_obj`), the windows (`dh_seen`) |
| `src/display_objs.asm` | `ds_obj` (page 4, in the palette's alignment gap) |
| `src/display.asm` | the line-by-line helpers (`pf_*`, collide's `.add`/`.pair`, line tables); with `-DBEAM` the old cycle model of the DLI |
| `src/sprites.asm` | the objects as 8-bit multicolour sprites (pattern cache), the other players and missiles as 4-bit sprites, the Copper's list (bank colours), `apply`, the panel and scrolling line per frame |
| `src/spans.asm` | each river line's runs of bank and edge pixels, from the line without its decoration |
| `src/load_rom.asm` | reading `River_Raid.rom` at the start (page 7) |
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
3. **The DLI as a schedule.** Its loop's counter X goes up one per scanline (the line drawn while X = c is c − 69, plus a line each time it falls behind): an object starts at max(X, its Y), its rows run to the river's end, its reads follow on the next three values, then HITCLR. Only three cycle rules matter: a code stretch longer than the line puts the DLI a line behind; one read (M0PF) and HITCLR can fall either side of a line's drawing.
4. **Collisions without the chip's registers.** Only what the DLI reads: P1PF (tank, edge), P2PF (plane, bank), M0PF and M2PF (missile, bullet), P3PF (object, edge, only for helicopters, balloons, ships: the only kinds whose bit the game reads), P2PL (plane with shell and object), P3PL (shell, object), M2PL (bullet, object), M0PL (missile, plane). The other sprites' rows are only where the game put them (shell 16 rows from shellY, tank 11 from tankY, plane 14 from $AA, missile its row, bullet 8 below bulletY); a read counts a collision whose scanline is between the last HITCLR and the read. Water under a sprite is never looked at; the bank without its decoration is 2–8 numbers a line.
8. **Player 3's memory is the DLI's only.** Nothing in the game reads the object rows the DLI writes into player 3's memory; neither the port nor the C++ port writes them now (the checks skip them).
5. **POKEY's RANDOM** is a 17-bit counter; the program keeps it at the game logic's read point (A205) and moves it one frame on per VBI (a matrix, NTSC or PAL).
6. **PAL/NTSC** as in the C++ port: display list end (panel line 190/194), panel and logo layout, reset frames 13/8, depot limit $2E/$2F, RANDOM read point, the scrolling line's start, the VBI before sub $B21A at a game over on PAL.
7. **Game over race.** At a game over the original's frame counter lands before or after its VBI by the frame's length; the C++ port, and so the program, takes the usual case. The two differences in `make check-original` are this.

## Environment limits
- sjasmplus 1.24.1 (commit 5c44bea), Xpeccy+ commit 0ec06e33, river_raid commit 9bb2288 (branch `dli_removal`): `tools/get_deps.sh`. Every change of the C++ port that the program follows needs this commit moved too.
- Xpeccy+'s Next core is used headless through libxpeccy: no firmware (palettes start at 0), not `comp_power_on`; at 60 Hz its picture starts at Layer 2 row 0, at 50 Hz at 24.
- The checks need the ROM; CI only builds the .nex (artifact without a zip).
- Code is indented with tabs; documentation in English (`X.md`) and Russian (`X.ru.md`), every change in both.
- Commits: author `djdron <djdron@gmail.com>`, message ending with `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`, no session link.

## Method
Anything that changes what the game does is done first in the C++ port (branch `dli_removal`), checked there with `game_check` against runs of the original (`rr_oracle`, state and `-screens`) and with `RR_DISPLAY=check` against the old cycle model, committed with its docs/DLI_REMOVAL.md; then ported here and checked with nxcheck, which links the C++ port from `deps/river_raid` (`tools/get_deps.sh` pins the commit). What only concerns the Next's hardware (sprites, Copper, tables) is done here only.

nxcheck checks after every frame: the game's state, screen memory, player-missile memory, the bank colour by river line, the objects as drawn (`ds_objs` against the C++ port's `drawn`), the Copper's memory and list; at the end the picture pixel by pixel. The full set (about 25 minutes on 2 cores): `-pal` and `-ntsc` 3 000 frames, `-bot 2` and `-bot 3` 20 000, `-bot 8` and `-bot 9` 30 000, `-attract` 20 000, `NXGAME=7` PAL and NTSC and `NXGAME=5` 10 000. The later bridges: `NXBRIDGE=n NXGHOST=1 NXGAME=1` (every game from bridge n, the plane unable to crash on both sides). A test build with `-DOBJCHECK` (and `NXOBJCHECK=1`) also counts the other sprites' rows outside their boxes. Speed: `NXHISTALL` (all frames) or `NXHIST` (one frame) and `tools/prof.py`.

## Decisions
- The C++ port is the spec, not the 6502 listing: same speed on the Z80, readable, already checked.
- Layer 2 at 320x256 holds the playfield's 2-bit colour indices, 160 of the 192 colour clocks, two dots each; the bank, edge and water colours are palette entries, the bank's per line by the Copper (its list sent again only when the bank's colours change).
- Each object is a ready-made sprite with its rows in their colours (8-bit pattern: dot = 128 + Atari colour / 2, the sprites' palette 128–255 the Atari's colours; made once per shape, frame and clipping, kept in a cache); an object above the river's top is drawn whole and clipped by the sprites' clip window. The other players and missiles are a sprite each from where the game put them (4-bit patterns).
- The display follows the C++ port's displaySimple, not the 6502's timing: the original's DLI timing survives only where it decides which object a collision is counted for.
- The panel and scrolling line are the tilemap; the panel's grey is Layer 2's (its 4 colours made grey by the Copper on the panel's lines, its clip window down to the panel's last grey line), so it is 320 dots wide like the river; the fallback colour stays black, the border too.
- The frame goes live below the scrolling line (raster line 208 NTSC, 220 PAL).
- PAL by default; CAPS + 1 switches and starts again as if the machine were switched on (P is "right" in Q A O P).
- Controls: Q A O P, Space/M fire, Enter START, G SELECT, H pause; Kempston 1 and 2, Mega Drive START and A.

## Open questions
- Not tried on a real Next; the keyboard and joystick reading is untested (the checks give the controls directly). Speed is measured on Xpeccy+'s Next core; the real machine's memory wait states at 28 MHz are not checked.
- The sound has not been heard on a real Next: the zxnDMA (burst mode, prescaler 55, auto restart, read back of its address) and the DAC on port $DF are as Xpeccy+'s core models the VHDL.
- The ROM is now read by `load_rom` in page 7 (moved for room); test builds do not have it, so it is checked only on a real Next.
- The DLI falling behind (above): the original shows old rows of an object for a frame or two; whether to model it is open (it would need the old rows kept).
- Power-on before the attract mode (the first 38/25 frames) is not shown; the program starts at the attract mode.

## Next steps
- The schedule cheaper (`display` ~33 000 ticks, `ds_fields` ~5 600): the reads' windows and cycles, the slot's fields; or decide whether the cycle rules are still wanted (without them the schedule is a few additions an object, with rare differences from the original).
- `dh_obj` (~7 000): a test by Y before the one by X.
- The sound cheaper: the running sum (`snd_sum`, ~6 800 ticks a frame) and the noise (`pk_noise`, ~4 400).
- Run it on a real Next (the keyboard, the joysticks, the DMA sound, the ROM loading, the speed with memory wait states).
