# River Raid for modern ZX Spectrums

English | [Русский](README.ru.md) | [Українська](README.uk.md) | [Deutsch](README.de.md) | [Polski](README.pl.md) | [Italiano](README.it.md) | [Español](README.es.md) | [中文](README.zh.md) | [日本語](README.ja.md)

River Raid (Activision, Atari 8-bit, 1983, by Carol Shaw) on today's ZX Spectrum machines:
the **ZX Spectrum Next** and **TS-Conf** (ZX Evolution / Pentevo). Both are built on the C++
port in [djdron/river_raid](https://github.com/djdron/river_raid), which works out how the
original does everything and is checked against it frame by frame. The game's logic is the
original's, frame by frame, in the same RAM at the same addresses; each machine shows it with
its own hardware.

An unofficial fan project for educational purposes, not affiliated with Activision or
Microsoft. No part of the game is included: the program reads your own cartridge image at
run time.

## The ports

| | [ZX Spectrum Next](NEXT.md) | [TS-Conf](tsconf/README.md) (ZX Evolution / Pentevo) |
|---|---|---|
| File | `river_raid.nex` (opened in the Browser) | `river_raid.spg` (started from Wild Commander) |
| The ROM | `River_Raid.rom` in the same folder as the .nex | `River_Raid.rom` anywhere on the SD card (FAT16/32) |
| The river | Layer 2, each line's bank dots drawn in its colour's entry (one palette) | the 16-colour mode scrolled by the hardware, each line's bank dots drawn in its colour's entry (one palette) |
| Enemies, plane, missiles | sprites | sprites |
| The panel, scrolling line | the tilemap | a picture of its own switched in below the river, tiles, sprites |
| The sound | POKEY emulated by the program into the DAC (zxnDMA), the pure tones on the AY | all of it on a General Sound (POKEY emulated by the card's own Z80, mono); without one the pure tones on TurboSound's AYs |
| CPU | 28 MHz (fits in 14) | 14 MHz (fits in 7) |
| TV | PAL 50 Hz or NTSC 60 Hz (CAPS + 1) | PAL 50 Hz |
| Details | [NEXT.md](NEXT.md) | [tsconf/README.md](tsconf/README.md) |

The game is complete on both: the attract mode, games 1-8 (starting at bridge 1, 5, 20 or 50;
one player or two taking turns), the plane, fuel and depots, enemies, tanks, helicopters'
missiles, bridges, score, lives, high score, pause, the panel and the scrolling line with the
rainbow logo. Neither has been run on real hardware yet: both are checked on the emulator
[Xpeccy+](https://github.com/dotkoval/xpeccy-plus) (its Next and TSConf cores).

## Getting it

The programs are built on GitHub at every push: [Actions](https://github.com/djdron/river_raid_zx/actions),
the workflow `build` (the .nex) or `tsconf` (the .spg), its artifact. You need your own
`River_Raid.rom`: the cartridge image, 8192 bytes, no header (as the C++ port uses). Without
it the border turns red.

## Controls

| | Keyboard | Joystick |
|---|---|---|
| fly | Q A O P | Kempston |
| fire | Space or M | fire |
| START | Enter | (Next: START on a Mega Drive pad) |
| SELECT (the game, 1-8) | G | (Next: A on a Mega Drive pad) |
| pause | H | |

The Next has a few more keys (PAL/NTSC, the sound, the CPU's speed, the frame's time on the
border): [NEXT.md](NEXT.md).

## How it is checked

Anything that changes what the game does is done first in the C++ port, then on the Next,
then in the TS-Conf port's copy of the same code. Each port has a check that runs the
program on Xpeccy+'s core with no window, beside the C++ port with the same input and the same
POKEY counter, and compares them after every frame: the game's state, the river generator,
the panel, and the picture pixel by pixel (`make check`, `make -C tsconf check`; a made-up
player plays hundreds of thousands of frames). The Next's program is also compared with the
original cartridge itself, run on libatari800 (`make check-original`).

## Building

```
make deps          # sjasmplus, the C++ port and Xpeccy+ into deps/ (git, a C/C++ compiler, make, cmake, zlib)
make               # build/river_raid.nex
make -C tsconf     # tsconf/build/river_raid.spg
```

Building needs only sjasmplus; the checks need the rest and your ROM at `rom/River_Raid.rom`.

## The repository

| Path | What |
|---|---|
| `src/`, `tools/`, `Makefile` | the ZX Spectrum Next's program and its checks ([NEXT.md](NEXT.md)) |
| `tsconf/` | the TS-Conf port: its own project and build, the game's code copied from `src/` ([tsconf/README.md](tsconf/README.md)) |
| [docs/HOW_IT_WORKS.md](docs/HOW_IT_WORKS.md) | how the Atari's picture, collisions and sound are made on the Next and on TS-Conf, for everyone |
| [docs/NOTES.md](docs/NOTES.md) | how the Next's program is done and what was found, with numbers |
| [tsconf/NOTES.md](tsconf/NOTES.md) | the TS-Conf port's own: the board, the INT, the General Sound, the start, with numbers |
| [docs/CODE.md](docs/CODE.md) | the Next's assembly source routine by routine |
| [tsconf/CODE.md](tsconf/CODE.md) | the TS-Conf port's assembly source routine by routine, and how the two machines differ |
| [HANDOFF.md](HANDOFF.md) | the project's state, for picking the work up |

## Licence

The project's own code and documentation are under the MIT licence, see [LICENSE](LICENSE).
`src/palette.inc` and `tsconf/src/palette_ts.inc` are made from the palette model of the C++
port (MIT). `src/font.inc` and `tsconf/src/font.inc` are the font of AltirraOS (Copyright (C)
2008-2018 Avery Lee; free to copy and distribute with its notice, which the files keep), as
the C++ port has it: the Atari OS ROM is not part of the cartridge. The checks use
[Xpeccy+](https://github.com/dotkoval/xpeccy-plus) (MIT) and the assembler
[sjasmplus](https://github.com/z00m128/sjasmplus) (BSD-3); neither is included, `make deps`
fetches them. River Raid itself (the ROM, its code, graphics and sound) belongs to its right
holders and is not covered by this licence.
