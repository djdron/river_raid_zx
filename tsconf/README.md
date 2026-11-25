# River Raid for TS-Conf

English | [Русский](README.ru.md) | [Українська](README.uk.md) | [Deutsch](README.de.md) | [Polski](README.pl.md) | [Italiano](README.it.md) | [Español](README.es.md) | [中文](README.zh.md) | [日本語](README.ja.md)

The port to TS-Conf (ZX Evolution / Pentevo): its own project with its own build, apart from
the ZX Spectrum Next's ([NEXT.md](../NEXT.md); both: [the main page](../README.md)). It shares
only `../deps` (sjasmplus, the C++ port, Xpeccy+: `make deps` at the top).

The game as the Next's runs it (the same game logic, display and river generator, copied into
`src/`), shown the TS-Conf's way. 50 Hz (PAL) only: the board's frame.

How it works on both machines, for everyone: [../docs/HOW_IT_WORKS.md](../docs/HOW_IT_WORKS.md).

How it is done on this board and what was found, with numbers: [NOTES.md](NOTES.md).

The source routine by routine, what changed in the Next's shared code, and a table of how the two machines differ: [CODE.md](CODE.md).

- The river: the 16-colour mode, 320x240, a picture line of 256 bytes (160 at its start), 512
  lines a ring scrolled by the hardware (GYOFFS); a new river line is written straight into
  its row (`render.asm`), no copies.
- The bank's colour by line: one palette (PALSEL 0) holds the bank's colours, the two greens
  and the bridge road's (entries 1 and 9-15, set once at the start), with 2 and 3 the edge and
  the water; each new line's bank dots are drawn in its own colour's entry (`line_bank`, worked
  out only by a bridge; nothing switched per line), so the colour goes with the line: no INT per change, nothing to
  set while the picture is shown.
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
- The controls: Q A O P, Space or M to fire, Enter START, G SELECT, H pause, T the frame's work on the border (a colour per part, as on the Next), CAPS + 3 the CPU's speed: 14, 7, 3.5 MHz in turn; Kempston.
- The sound: all of it on a General Sound (the original card or a NeoGS), when there is one:
  the card's own Z80 plays POKEY as the Next's DAC does (`gs/`, the Next's `pokey_frame` and
  its pulses, the 17-bit counter's bits made by the card from their recurrence), in mono (the same samples to all four channels: 1 and 2 left, 3 and 4 right), at 15 820 samples a second (its INT, 37 500
  a second, takes 108 of 256). The start puts the program into the card through its firmware
  (`gs_load.asm`; run again, it finds the program still there); then the apply sends POKEY's
  registers once a frame (`sound_gs.asm`). Without a card (or one that does not answer): the
  pure tones only (the engine, the beeps, firing, the bonus, the shell's whistle) on
  TurboSound's two AYs, as the Next plays them (`sound_ay.asm`): POKEY's channels 1 and 2 the
  second chip's A and B, 3 and 4 the first's B and C. On Xpeccy: turn the General Sound on
  (and TurboSound NedoPC for the AYs).

At 14 MHz a frame's work takes ~65 000 ticks on average in the attract mode, ~108 000 at full
speed always firing from bridge 80 (-stress), ~178 000 at most, of ~287 000; at 7 MHz it
still fits, just (~125 000 at most with -stress, of ~143 400; no frame late); at 3.5 MHz it
does not keep up.

Memory (16K windows): $0000 the Atari's RAM (page 1; the start's work, page 3, while it runs), $4000 the lines' runs and buffers, the OS
font at $7D00 (page 5; `render_line` puts a page of the picture there while it draws), $8000
the program and the cartridge at $A000 (page 2), $C000 the program, buffers and the stack
(page 6); the river's picture from page 32, the panel's from 64, the tile map in page 7, the
tiles' dots in page 8, the sprites' from 24.

    make          build/river_raid.spg: the program for Wild Commander (SPG 1.0); it finds
                  River_Raid.rom on the SD card itself (below)
    make sna      build/river_raid.sna: a 128K snapshot with your ROM in (../rom/River_Raid.rom)
    make check    runs the test build on Xpeccy+'s TSConf core and compares it with the C++
                  port frame by frame: the state, and the picture of every frame (FRAMES=...
                  how many, 3000 by default), and with a General Sound (Xpeccy+'s, its
                  firmware gs105b.rom) the registers the card gets
    make palette  writes src/palette_ts.inc again (the C++ port's colours at the board's levels)

`build/tools/tscheck` also plays: `-bot N` (nxcheck's made-up player), `-stress`, `-start N`;
TSBRIDGE, TSGHOST, NXGAME as nxcheck's; TSSPEED=1 at 7 MHz; TSBORDER=1 T on (TSFULL=1 with TSSHOT=k: the frames with the border); TSGS=neo a NeoGS, TSGS=0 no card
(the AY's tones checked); TSWAV=file, TSWAVCPP=file the card's samples and the C++ port's
POKEY at that rate (WAVs to listen to).

The .spg is also built on GitHub (the `tsconf` workflow: its artifact). Put River_Raid.rom (the
cartridge image, 8192 bytes) anywhere on the SD card: the program searches the card at the
start (`load_rom.asm`: its first partition or the whole card, FAT16 or FAT32, the root first,
then its folders, 8 deep; the long name in any case, or the short RIVER_~1.ROM). Without it: a
red border. While the start works the screen is black (`screen_black`: all of CRAM black at
once, whatever mode Wild Commander left: its ZX screen in page 5 is where the start's buffers
go).

`build/tools/tscheck -spg build/river_raid.spg 600 out.ppm -sd folder` runs the .spg with a
host folder as the SD card (`-img file`: a card's image); `-sna build/river_raid.sna 600
out.ppm` the snapshot.
