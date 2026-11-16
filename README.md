# River Raid for the ZX Spectrum Next

English | [Русский](README.ru.md)

A port of River Raid (Activision, Atari 8-bit, 1983, by Carol Shaw) to the ZX Spectrum Next,
built on the C++ port in [djdron/river_raid](https://github.com/djdron/river_raid), which
works out how the original does everything and is checked against it frame by frame.

An unofficial fan project for educational purposes, not affiliated with Activision or
Microsoft. No part of the game is included: the program reads your own cartridge image at
run time.

## State

A river viewer: the attract mode, as the C++ port's river viewer shows it. The river of
game 1 from the start, one line per frame; the enemies wake up and move (from bridge 2 on,
as in the original), turn at the bank edge, tanks drive to the river and fire, helicopters
fire missiles. Every frame does what the original does (the game's logic, the river
generator, and the display list interrupt that shows the objects and reads the collisions,
with its cycle counts), and is checked against the C++ port frame by frame.

Speed: not enough yet. At 28 MHz a frame's work takes about a 50 Hz frame on average (95%
over the first bridges, 105% over the first 40), up to 1.5 frames when the most is on
screen (tanks and their shells beside the enemies); such frames are shown twice. At 60 Hz
it is too slow. Making it fit is the next step; then the panel and the scrolling line,
then the game.

## Running it

Put `build/river_view.nex` and your `River_Raid.rom` (the cartridge image: 8192 bytes, no
header, as the C++ port uses) in the same folder of the Next's SD card and open the .nex in
the Browser. Without the ROM (or with a file that is not the cartridge) the border turns red
and the program stops. The ROM is looked for by its long name, then by its short name
`RIVER_~1.ROM`.

POKEY's counter, which decides which enemy wakes when, starts from a different value at
each run, as on the real machine.

## Building

```
make deps    # sjasmplus, the C++ port and Xpeccy+ into deps/ (git, a C/C++ compiler, make, cmake, zlib)
make         # build/river_view.nex
```

`make` alone needs only sjasmplus (`make SJASMPLUS=...` for one installed elsewhere).
`src/palette.inc` (the C++ port's palette model) and `src/random.inc` are made by
`make palette`.

## Checks

```
make check     # FRAMES=... frames (3000 by default); your ROM at rom/River_Raid.rom
make profile   # where the time of one frame goes (the frame after FRAMES)
```

`tools/nxcheck` runs the viewer on the ZX Spectrum Next core of
[Xpeccy+](https://github.com/dotkoval/xpeccy-plus) with no window and runs the C++ port's
attract mode beside it (`rr::Game`, with the same POKEY counter), comparing after every
frame: the river generator's state (`RiverGen::diffWithRam`), the game's state the attract
mode changes, player-missile memory, screen memory, and what the DLI left per line (player
3 and the bank colour, `Game::scan`); at the end the picture of the last frame, pixel by
pixel (`Game::drawRiver` in the Next's colours). It also reports how long the frames take.
40 000 frames (past bridge 35) are the same. A change that breaks it shows the first frame
that differs and the fields.

## How it works

| Z80 | 8K page | What |
|---|---|---|
| $0000-$3FFF | 30, 31 | the Atari's RAM: the game's state at the original's addresses, player-missile memory, screen memory; a dump compares byte for byte with the original and the C++ port |
| $4000-$5FFF | 18-27 | a window onto Layer 2 |
| $6000-$7FFF | 12 | the DLI's record per line, tables, the sprites' attributes, the Copper's list |
| $8000-$9FFF | 4 | the program: the river generator, the main loop |
| $A000-$BFFF | 5 | the cartridge image, at its own addresses: the tables are read where the original reads them |
| $C000-$DFFF | 6 | the program: the game, the display, the sprites |
| $E000-$FFFF | 1 | buffers, tables and the stack |

Each frame (`src/viewer.asm`):

1. `src/game.asm`, `prepare`: the tank's, its shell's and the missile's shapes into
   player-missile memory (`Game::prepare`).
2. `src/display.asm`: the DLI (`Game::display`). It shows every object with player 3, row by
   row, and reads the collision registers after each object; whether a collision on the
   line being read counts depends on the cycle, so the DLI's instructions run with their
   cycle counts and the scanlines are drawn in between, as the C++ port models the reference
   emulator. Instructions with nothing the beam sees between them go as one.
3. `src/sprites.asm`: what the Atari shows becomes Next hardware. The players and missiles
   are cut into runs of up to 16 lines at one position, a sprite each with a 4-bit pattern
   made from the lines' bytes (an Atari pixel is two sprite pixels; double and quadruple width
   are the sprite's scale). Player 3's colour changes every line and the bank's next to a
   bridge: the Copper sets them per line in the palettes.
4. `src/game.asm`, `logic`, `vbi`: the attract mode's main loop (`Game::logic`): an enemy
   woken every 16 frames by POKEY's RANDOM (its counter moved 16 frames on by a matrix,
   `src/random.inc`), the tank, the objects, the missile, the shell, one river line
   (`src/river_gen.asm`, `river_gen.cpp` line for line) written to Layer 2.
5. At raster line 200 the new picture goes live: Layer 2's scroll, the sprites'
   attributes (their patterns were written into the set not shown), the Copper's list.

Layer 2 (320x256, 256 colours) holds the playfield's 2-bit colour indices; 160 of the
line's 192 colour clocks are shown (from the 20th; the water never comes nearer to the
edges), two dots each, so the proportions are the Atari's within 2%. The colours are the
C++ port's PAL colours (Altirra's model) as the Next's 8-bit palette entries.

## Licence

The project's own code and documentation are under the MIT licence, see [LICENSE](LICENSE).
`src/palette.inc` is made from the palette model of the C++ port (MIT). The checks use
[Xpeccy+](https://github.com/dotkoval/xpeccy-plus) (MIT) and the assembler
[sjasmplus](https://github.com/z00m128/sjasmplus) (BSD-3); neither is included, `make deps`
fetches them. River Raid itself (the ROM, its code, graphics and sound) belongs to its right
holders and is not covered by this licence.
