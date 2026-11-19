# River Raid for TS-Conf

The port to TS-Conf (ZX Evolution / Pentevo): its own project with its own build, apart from
the ZX Spectrum Next's (the repository's top). It shares only `../deps` (sjasmplus, the C++
port, Xpeccy+: `make deps` at the top).

So far: the viewer. The attract mode runs as the Next's game runs it (the same game logic,
display and river generator, copied into `src/`), shown the TS-Conf's way:

- the river in the 256-colour mode, 320x240, a picture line of 512 bytes a row (the dots of
  320 at its start), 512 lines a ring scrolled by the hardware (GYOFFS): a new river line is
  written straight into its row (`render.asm`), no copies;
- the bank's colour changed per line, as the Next's Copper does it: the frame INT moved down
  the frame from change to change (`build_events`, `irq`), each writing CRAM through the FM
  window a line before;
- above and below the river, tile layer 0 black;
- no sprites, panel or sound yet. 50 Hz (PAL) only: the board's frame.

At 14 MHz a frame's work takes ~63 000 ticks on average, ~91 000 at most, of ~287 000.

Memory (16K windows): $0000 the Atari's RAM (page 1), $4000 the lines' runs and buffers (page
5; `render_line` puts a page of the picture there while it draws), $8000 the program and the
cartridge at $A000 (page 2), $C000 the program, buffers and the stack (page 6); the picture
from page 32, the tile map in page 7, the tile's dots in page 8.

    make          build/river_raid.spg: the program for Wild Commander (SPG 1.0); it finds
                  River_Raid.rom on the SD card itself (below)
    make sna      build/river_raid.sna: a 128K snapshot with your ROM in (../rom/River_Raid.rom)
    make check    runs the test build on Xpeccy+'s TSConf core and compares it with the C++
                  port frame by frame (FRAMES=... how many, 3000 by default), then the last
                  frame's picture pixel by pixel
    make palette  writes src/palette_ts.inc again (the C++ port's colours at the board's levels)

The .spg is also built on GitHub (the `tsconf` workflow: its artifact). Put River_Raid.rom (the
cartridge image, 8192 bytes) anywhere on the SD card: the program searches the card at the
start (`load_rom.asm`: its first partition or the whole card, FAT16 or FAT32, the root first,
then its folders, 8 deep; the long name in any case, or the short RIVER_~1.ROM). Without it: a
red border.

`build/tools/tscheck -spg build/river_raid.spg 600 out.ppm -sd folder` runs the .spg with a
host folder as the SD card (`-img file`: a card's image); `-sna build/river_raid.sna 600
out.ppm` the snapshot.

Next: the objects and the plane as sprites, the panel on a tile layer.

Russian: [README.ru.md](README.ru.md).
