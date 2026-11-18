# River Raid for the ZX Spectrum Next

English | [Русский](README.ru.md)

A port of River Raid (Activision, Atari 8-bit, 1983, by Carol Shaw) to the ZX Spectrum Next,
built on the C++ port in [djdron/river_raid](https://github.com/djdron/river_raid), which
works out how the original does everything and is checked against it frame by frame.

An unofficial fan project for educational purposes, not affiliated with Activision or
Microsoft. No part of the game is included: the program reads your own cartridge image at
run time.

How it works on the Next, for everyone: [docs/HOW_IT_WORKS.md](docs/HOW_IT_WORKS.md). For picking the work up: [HANDOFF.md](HANDOFF.md); how it is done, with numbers: [docs/NOTES.md](docs/NOTES.md); the assembly source routine by routine: [docs/CODE.md](docs/CODE.md).

## State

The game, with its sound. The attract mode runs at start; START begins a game: the plane
flies, steers, speeds up and slows down, fires, burns fuel and refuels over the depots;
enemies, bridges and depots explode and score; tanks fire at the plane, helicopters fire
missiles; crashes, new planes from the last bridge, extra planes every 10 000 points, game
over and the high score; SELECT changes the game (1-8: four starting bridges, one or two
players taking turns), any key pauses. Below the river the panel (score, game number, fuel
gauge, lives, high score or the other player's score, bridge) and the scrolling line with
the rainbow logo, which scrolls the credits while no game is played. Every frame does what
the original does (the game's logic, the river generator, and what the display list
interrupt shows and the collisions it reads, worked out without playing it), and is checked
against the C++ port frame by frame.

The sound: the original's sound driver sets POKEY's four channels every frame (checked
against the C++ port); POKEY itself is emulated in software, its output made into a ring of
samples that the zxnDMA sends to the DAC on its own (15 909 a second). Not yet heard on a
real Next: on Xpeccy+'s core it plays, and the checks write it to a WAV (`-wav`). In
Xpeccy+ set the DAC and PSG volumes to 100 (they are 80 by default): the DAC plays the
noises, the PSG (AY) the pure tones.

PAL or NTSC: the program starts as a PAL Atari (the Next at 50 Hz), CAPS + 1 switches to an
NTSC one (60 Hz) and back, as if the machine were switched on again. They differ as the
originals do: the NTSC game runs 17% faster (60 frames a second instead of 50), the panel and
the scrolling line are higher, the memory clearing after a crash takes 13 frames instead of
8, fuel depots are a little rarer on PAL from level $2F on, and so on (the C++ port's PAL
and NTSC variants).

Speed: at 28 MHz a frame's work takes about 21% of a 50 Hz frame on average at the start of
a game, about 41% at most in the heaviest scenes (all enemy slots taken, full speed, firing
all the time, from bridge 80); no frame is late on PAL or NTSC. So it runs at 14 MHz too:
even the heaviest frames take about 83% of a 50 Hz frame and 98% of a 60 Hz one. The sound is
about 25 000 ticks of it (4% of a frame), up to ~40 000 with explosions and the helicopter's
missile; in a busy frame it makes fewer samples and leaves the rest to the next frames.

## Running it

Put `build/river_raid.nex` and your `River_Raid.rom` (the cartridge image: 8192 bytes, no
header, as the C++ port uses) in the same folder of the Next's SD card and open the .nex in
the Browser. Without the ROM (or with a file that is not the cartridge) the border turns red
and the program stops. The ROM is looked for by its long name, then by its short name
`RIVER_~1.ROM`.

| | Keyboard | Joystick |
|---|---|---|
| fly | Q A O P | Kempston 1 (the second player in a two-player game: Kempston 2, or the same) |
| fire | Space or M | fire |
| START | Enter | START on a Mega Drive pad |
| SELECT (the game, 1-8) | G | A on a Mega Drive pad |
| pause | H (press and release; again to go on) | |
| PAL / NTSC | CAPS + 1 (starts again) | |
| sound off / on | CAPS + 2 | |
| the frame's work on the border, a colour per part: orange apply, grey prepare (and clear_layer2_page during a reset), red display, yellow build_sprites, blue main_loop, magenta push_line (a new river line, inside main_loop), white vbi, cyan pokey_frame, black the time left | T (on / off) | |

Games 1-8 as on the Atari: starting at bridge 1, 5, 20 or 50, odd numbers one player, even
two (they take turns; the keyboard flies for both).

POKEY's counter, which decides which enemy wakes when, starts from a different value at
each run, as on the real machine.

## Building

```
make deps    # sjasmplus, the C++ port and Xpeccy+ into deps/ (git, a C/C++ compiler, make, cmake, zlib)
make         # build/river_raid.nex
```

`make` alone needs only sjasmplus (`make SJASMPLUS=...` for one installed elsewhere).
`src/palette.inc` (the C++ port's palette model), `src/random.inc`, `src/font.inc`, `src/poly.inc`
and `src/poly17.bin` (POKEY's noise) are made by `make palette`.

## Checks

```
make check     # FRAMES=... frames (3000 by default); your ROM at rom/River_Raid.rom
make profile   # where the time of one frame goes (the frame after FRAMES)
```

`make check-original` compares the program with the original cartridge itself, as the C++ port
was compared: `rr_oracle` (from the C++ port's repository, built by the target: the original
on libatari800, which needs git, a C compiler, make, autoconf, automake) records runs of the
original (its RAM after every frame, what its game logic read from RANDOM, the input), and
`nxcheck -oracle DIR` runs the program on the same input and the same RANDOM values and
compares its RAM with the original's after every frame (`Game::diffWithRam`: the river
generator, the objects, the game's state, the collisions, player-missile memory, the river's
lines), going on from the original's state after a difference. Eight runs, 37 000 frames: the
attract mode, a bot game to game over and a new start, a two-player game, flying, refuelling,
NTSC and PAL. The same, but the frame of a game over in two NTSC runs: there the original sets
the frame counter just before or just after its VBI, depending on how long that frame's work
takes (the C++ port, and so the program, takes the more usual one).

`make check` runs it on PAL and on NTSC (`-pal`, `-ntsc`; `-switch N`: CAPS + 1 before frame
N). `tools/nxcheck` runs the program on the ZX Spectrum Next core of
[Xpeccy+](https://github.com/dotkoval/xpeccy-plus) with no window and runs the C++ port
beside it (`rr::Game::frame`, with the same POKEY counter and the same controls). The
controls come from a made-up player: it waits in the attract mode, sometimes selects another
game, presses START, flies towards the middle of the water, dodges enemies ahead, flies over
depots when low on fuel, fires, pauses now and then (`-bot N` for other choices, `-stress`
at full speed always firing, `-seed N` for another POKEY counter, `-attract` for no player). After every frame it compares the
river generator's state (`RiverGen::diffWithRam`), the game's state (the scrolling line's
too), the high scores and the panel's characters, screen memory, the
bank colour per line (`Game::scan`) and the objects as drawn (`Game::drawn`), the Copper's
memory and list; at the end the
picture of the last frame, pixel by pixel, the river, the panel and the scrolling line
(`Game::drawRiver` and `drawStatusBar` in the Next's colours). It also reports what was played and
how long the frames take. 4 x 40 000 frames with different players (games 1-8, about 70 games
and 300 crashes) are the same. A change that breaks it shows the first frame that differs
and the fields.

## How it works

| Z80 | 8K page | What |
|---|---|---|
| $0000-$3FFF | 30, 31 | the Atari's RAM: the game's state at the original's addresses, player-missile memory, screen memory; a dump compares byte for byte with the original and the C++ port |
| $4000-$5FFF | 18-27 | a window onto Layer 2 |
| $6000-$7FFF | 12 | the bank colour per line, the objects' rows (`ds_objs`), tables, the sprites' attributes, the Copper's list |
| $8000-$9FFF | 4 | the program: the frame, the river generator, the game's main loop |
| $A000-$BFFF | 5 | the cartridge image, at its own addresses: the tables are read where the original reads them |
| $C000-$DFFF | 6 | the program: the game, the display, the sprites, the panel |
| ($6000-$7FFF) | 7 | at the start only: the character sets, the tiles, the needle's and the logo's sprites |
| $E000-$FFFF | 1 | buffers, tables and the stack |

Each frame (`src/river_raid.asm`):

1. `src/game.asm`, `prepare`: the tank and its shell gone below the screen, the shell's
   colour, the lives, bridges and score into the panel's characters (`Game::prepare`). The
   Next writes no player-missile memory: the sprites' pictures and the collisions' rows
   come from the ROM's shapes.
2. `src/display_simple.asm`, `src/display_hits.asm`: the DLI's work, without the DLI
   (`Game::displayGeometry` on the C++ port's `dli_removed` branch). Each object stands at
   its slot's height, cut to the river; its rows go to `ds_objs`. The collisions the game reads
   are plain geometry: boxes first (against each line's water gaps, against each other),
   then the dots, wherever they touch. The original reads them in windows, object by object:
   0.01–0.25% of frames decide otherwise, a touch a frame earlier.
3. `src/sprites.asm`: what the Atari shows becomes Next hardware. Each object (player 3,
   whose colour changes every line) is a ready-made sprite with its rows in their colours,
   placed at the object's position. The other players and missiles are a sprite each too,
   at the position the game gave them. All their pictures are 4-bit patterns made once at
   the start from the ROM's shapes (`src/obj_pics.asm`), so a frame only picks a pattern and
   writes the sprite's attributes (an Atari pixel is two sprite pixels; double and quadruple
   width are the sprite's scale). The bank's colour changes next to a
   bridge: the Copper sets it per line in Layer 2's palette.
4. `src/play.asm`, `main_loop`: the main loop (`Game::mainLoop`): the controls (the keyboard
   and joysticks, read as the Atari's), pause, an enemy woken every 16 frames by POKEY's
   RANDOM, the tank, the objects, the plane (fuel, steering, speed, the bullet, what it hit),
   the missile, the shell, START and SELECT, new games, crashes and new planes, and the river
   lines for the speed (`src/river_gen.asm`, `river_gen.cpp` line for line) written to
   Layer 2. While the original clears memory after a crash or START (13 frames) only the
   display and the VBI run, and Layer 2 is cleared a page per frame.
5. `src/game.asm`, `vbi`: the sound driver (`src/sound.asm`: POKEY's registers), the frame counter, the colours
   of the next frame (the water flashes red when a bridge is hit), POKEY's counter one frame
   on (a matrix, `src/random.inc`). Then `pokey_frame` (`src/sound.asm`) makes the frame's
   samples of POKEY's output for the DMA.
6. Below the scrolling line (raster line 208) the new picture goes live: Layer 2's scroll and
   colours, the sprites' attributes,
   the panel and the scrolling line, the Copper's list.

The panel and the scrolling line are the tilemap (40 x 32, 8x8 tiles at 4 bits per pixel):
each Atari character (8x8, a colour clock a pixel) is two tiles, made at the start from the
character sets the game builds at power-on (the OS font's letters and digits, the
cartridge's own symbols). The Copper moves the tilemap to each row of characters, and moves
the scrolling line sideways by its fine scroll; the tile that is seen at both edges of the
screen is made each frame. The panel's grey is the fallback colour, so the fuel needle (a
sprite) is over it and under the characters, as on the Atari. The logo is five sprites.

Layer 2 (320x256, 256 colours) holds the playfield's 2-bit colour indices; 160 of the
line's 192 colour clocks are shown (from the 20th; the water never comes nearer to the
edges), two dots each, so the proportions are the Atari's within 2%. The colours are the
C++ port's PAL colours (Altirra's model) as the Next's 8-bit palette entries.

## Licence

The project's own code and documentation are under the MIT licence, see [LICENSE](LICENSE).
`src/palette.inc` is made from the palette model of the C++ port (MIT). `src/font.inc` is the
font of AltirraOS (Copyright (C) 2008-2018 Avery Lee; free to copy and distribute with its
notice, which the file keeps), as the C++ port has it: the Atari OS ROM is not part of the
cartridge. The checks use
[Xpeccy+](https://github.com/dotkoval/xpeccy-plus) (MIT) and the assembler
[sjasmplus](https://github.com/z00m128/sjasmplus) (BSD-3); neither is included, `make deps`
fetches them. River Raid itself (the ROM, its code, graphics and sound) belongs to its right
holders and is not covered by this licence.
