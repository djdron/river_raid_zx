# River Raid for TS-Conf

The port to TS-Conf (ZX Evolution / Pentevo): its own project with its own build, apart from
the ZX Spectrum Next's (the repository's top). It shares only `../deps` (sjasmplus, the C++
port, Xpeccy+: `make deps` at the top).

The game as the Next's runs it (the same game logic, display and river generator, copied into
`src/`), shown the TS-Conf's way. 50 Hz (PAL) only: the board's frame.

- The river: the 16-colour mode, 320x240, a picture line of 256 bytes (160 at its start), 512
  lines a ring scrolled by the hardware (GYOFFS); a new river line is written straight into
  its row (`render.asm`), no copies.
- The bank's colour by line: each colour the bank has had has a palette of its own (PALSEL
  0-7: its colour 1 that colour, set once; 2 and 3 the edge and the water, each frame). The
  frame INT, moved down the frame from change to change (`build_events`, `irq`), sets PALSEL
  a line before the change; the register is taken at the line's end, so the change is
  exact at any CPU speed.
- The objects, the plane, its bullet, the tank and the missiles: sprites (`sprites.asm`), their
  pictures made at the start from the cartridge's shapes, each object at 16, 32 and 64 dots
  across (the sprites have no scale).
- The panel and the scrolling line (`panel_ts.asm`): rows 184-239 come from a picture of their
  own, which the frame INT puts in at row 184 (VPAGE, GYOFFS) in the 256-colour mode with the
  bitmap over the tiles and sprites (GFXOVR); tile layer 0 the grey under the characters (it
  hides the river's sprites there); the needle and the logo sprites over it. The characters
  are drawn once at the start and copied by the DMA; the scrolling line is a ring of 32
  characters across the picture's 512 dots, shown from GXOFFS.
- Tile layer 0 also black above the river.
- The controls: Q A O P, Space or M to fire, Enter START, G SELECT, H pause; Kempston.
- The sound: so far the pure tones (the engine, the beeps, firing, the bonus, the shell's
  whistle) on TurboSound's two AYs, as the Next plays them (`sound_ay.asm`): POKEY's channels
  1 and 2 the second chip's A and B, 3 and 4 the first's B and C. The noises (explosions,
  the helicopter's missile) not yet.

At 14 MHz a frame's work takes ~70 000 ticks on average in the attract mode, ~120 000 at full
speed always firing (-stress), ~185 000 at most, of ~287 000; at 7 MHz it still fits (~133 000
at most with -stress, of ~143 000).

Memory (16K windows): $0000 the Atari's RAM (page 1), $4000 the lines' runs and buffers, the OS
font at $7D00 (page 5; `render_line` puts a page of the picture there while it draws), $8000
the program and the cartridge at $A000 (page 2), $C000 the program, buffers and the stack
(page 6); the river's picture from page 32, the panel's from 64, the tile map in page 7, the
tiles' dots in page 8, the sprites' from 24.

    make          build/river_raid.spg: the program for Wild Commander (SPG 1.0); it finds
                  River_Raid.rom on the SD card itself (below)
    make sna      build/river_raid.sna: a 128K snapshot with your ROM in (../rom/River_Raid.rom)
    make check    runs the test build on Xpeccy+'s TSConf core and compares it with the C++
                  port frame by frame: the state, and the picture of every frame (FRAMES=...
                  how many, 3000 by default)
    make palette  writes src/palette_ts.inc again (the C++ port's colours at the board's levels)

`build/tools/tscheck` also plays: `-bot N` (nxcheck's made-up player), `-stress`, `-start N`;
TSBRIDGE, TSGHOST, NXGAME as nxcheck's; TSSPEED=1 at 7 MHz.

The .spg is also built on GitHub (the `tsconf` workflow: its artifact). Put River_Raid.rom (the
cartridge image, 8192 bytes) anywhere on the SD card: the program searches the card at the
start (`load_rom.asm`: its first partition or the whole card, FAT16 or FAT32, the root first,
then its folders, 8 deep; the long name in any case, or the short RIVER_~1.ROM). Without it: a
red border.

`build/tools/tscheck -spg build/river_raid.spg 600 out.ppm -sd folder` runs the .spg with a
host folder as the SD card (`-img file`: a card's image); `-sna build/river_raid.sna 600
out.ppm` the snapshot.

Next: the noises.

Russian: [README.ru.md](README.ru.md).
