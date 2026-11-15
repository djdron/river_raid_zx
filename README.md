# River Raid for the ZX Spectrum Next

English | [Русский](README.ru.md)

A port of River Raid (Activision, Atari 8-bit, 1983, by Carol Shaw) to the ZX Spectrum Next,
built on the C++ port in [djdron/river_raid](https://github.com/djdron/river_raid), which
works out how the original does everything and is checked against it frame by frame.

An unofficial fan project for educational purposes, not affiliated with Activision or
Microsoft. No part of the game is included: the program reads your own cartridge image at
run time.

## State

The first step: a river viewer. The river of game 1 from the start, one line per frame,
with the objects where the river generator places them (they do not move yet), as the C++
port's river map draws it. The generator and the drawing of a line run on the Z80; the
picture is on Layer 2, scrolled by the hardware.

Next: the attract mode as the C++ viewer shows it (moving enemies, tanks, the panel and the
scrolling line), then the game.

## Running it

Put `build/river_view.nex` and your `River_Raid.rom` (the cartridge image: 8192 bytes, no
header, as the C++ port uses) in the same folder of the Next's SD card and open the .nex in
the Browser. Without the ROM (or with a file that is not the cartridge) the border turns red
and the program stops. The ROM is looked for by its long name, then by its short name
`RIVER_~1.ROM`.

The screen shows 160 of the line's 192 colour clocks (from the 20th): the water never comes
nearer to the edges, and the C++ port shows 168 of them. A colour clock is two Layer 2
dots, so the proportions are the Atari's, within 2%. The colours are the C++ port's PAL
colours (Altirra's model) in the Next's 9 bits.

## Building

```
make deps    # sjasmplus, the C++ port and Xpeccy+ into deps/ (git, a C/C++ compiler, make, cmake, zlib)
make         # build/river_view.nex
```

`make` alone needs only sjasmplus (`make SJASMPLUS=...` for one installed elsewhere).
`src/palette.inc` is made from the C++ port's palette model by `make palette`.

## Checks

```
make check   # LINES=... lines (3000 by default); your ROM at rom/River_Raid.rom
```

`tools/nxcheck` runs the viewer on the ZX Spectrum Next core of
[Xpeccy+](https://github.com/dotkoval/xpeccy-plus) with no window and compares it with the
C++ port as it goes: after every line, the generator's state in the Atari's RAM
(`RiverGen::diffWithRam`), the 48 bytes of the line and the drawn row; at the end, the
picture of the last whole frame, pixel by pixel, in the colours the Next shows. The whole
river (121 000 lines, past bridge 100) is the same. A change that breaks it shows the
first line that differs and the fields.

## How it works

| Z80 | 8K page | What |
|---|---|---|
| $0000-$3FFF | 30, 31 | the Atari's RAM: the generator keeps its state at the original's addresses, so a dump compares byte for byte with the original and the C++ port |
| $8000-$9FFF | 4 | the program |
| $A000-$BFFF | 5 | the cartridge image, at its own addresses: the tables are read where the original reads them |
| $C000-$DFFF | 18-27 | a window onto Layer 2 |
| $E000-$FFFF | 1 | buffers and the stack |

- `src/river_gen.asm`: the river generator, `river_gen.cpp` of the C++ port line for line
  (the original's $A711-$AE96), with the 6502's carries where the original chains them.
- `src/render.asm`: a line as it enters the screen (`drawScreenLine`): the 2-bit pixels in
  the colours of the playfield registers, the bank in its section's shade or the road next to
  a bridge, and the row of the object the line crosses.
- `src/viewer.asm`: Layer 2 at 320x256 with 256 colours, the palette indexed by the Atari's
  colour code; the river's 160 rows in a clip window. Layer 2 is a ring of 256 rows: a new
  line is written above the shown rows, then the vertical scroll moves by one.

## Licence

The project's own code and documentation are under the MIT licence, see [LICENSE](LICENSE).
`src/palette.inc` is made from the palette model of the C++ port (MIT). The checks use
[Xpeccy+](https://github.com/dotkoval/xpeccy-plus) (MIT) and the assembler
[sjasmplus](https://github.com/z00m128/sjasmplus) (BSD-3); neither is included, `make deps`
fetches them. River Raid itself (the ROM, its code, graphics and sound) belongs to its right
holders and is not covered by this licence.
