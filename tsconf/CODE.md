# The TS-Conf port's assembly source, file by file

English | [Русский](CODE.ru.md) | [Українська](CODE.uk.md) | [Deutsch](CODE.de.md) | [Polski](CODE.pl.md) | [Italiano](CODE.it.md) | [Español](CODE.es.md) | [中文](CODE.zh.md) | [日本語](CODE.ja.md)

For Z80 programmers who want to read the TS-Conf port's code or make it faster. The game
itself (its logic, the river's generator, the objects' placement and collisions) is the
Next's code, copied into `src/`; [docs/CODE.md](../docs/CODE.md) describes those routines,
and this document only says how they were changed. What is the TS-Conf's own (the picture,
the bank colour by line, the sprites, the panel, the sound on a General Sound, the start from
an SD card) is described here routine by routine, with what it costs. The overview is in
[README.md](README.md).

## The two machines side by side

The same game, two ways of showing it. What differs, and where it shows in the code:

| | ZX Spectrum Next | TS-Conf (ZX Evolution) |
|---|---|---|
| CPU | Z80N at 28 MHz (3.5 / 7 / 14 / 28), interrupts off: the frame by polling the raster line | Z80 at 14 MHz (3.5 / 7 / 14), the cache on; the frame INT, IM 2, moved down the frame from event to event |
| Z80N instructions | `nextreg`, `mul`, `bsla de,b`, `outinb`… | none: a register is `ld bc,port / out (c),a`; `bsla de,b` a loop (`shl_de_b`, display_hits.asm); `mul` not needed (the AY's period by adds) |
| Memory | 8K slots (MMU, NR $50–$57) | 16K windows (PAGE0–PAGE3); window 0 RAM written (MEMCONFIG), so the Atari's RAM lives at $0000 |
| The river | Layer 2, 320×256, 8 bits, stored by columns: a line is 320 writes down the columns, 10 pages in turn | 16 colours, 320×240, a line of 256 bytes a row (2 dots a byte): a line is 160 bytes written along the row, one page |
| Scrolling | NR $17, a ring of 256 lines | GYOFFS, a ring of 512 lines (`scroll` 9 bits) |
| The bank's colour by line | the Copper: a list of WAIT/MOVE, sent when it changes | a palette per bank colour (PALSEL 0–7, CRAM); the frame INT sets PALSEL a line before a change (`build_events`, `irq`) |
| Sprites | 128 patterns of 16×16, 4 or 8 bits, scale ×2 ×4; an object is a sprite per 16 rows | one 512×512 4-bit picture memory (SGPAGE), any size to 64×64, no scale: each picture kept at 16, 32 and 64 dots across; an object is one sprite |
| Colours | NR $41 etc., 9 bits | CRAM through the FM window at $E000 (`CRAM_SHADOW`): the colours, and the sprites' list (SFILE) at $E200, are plain memory writes |
| The panel and the scrolling line | the tilemap over everything, its Y and X scroll by the Copper; the scrolling line a ring of tiles + one sprite at the wrap | a picture of its own (256 colours, pages 64–79) put in at row 184 by the frame INT (VPAGE, GYOFFS, VCONFIG with GFXOVR), its characters drawn once and copied by the DMA; the scrolling line a ring of 32 characters across 512 dots, GXOFFS set by the INT; tile layer 0 the grey under the characters and the black above and below the river |
| Sound | the noises POKEY makes into a ring, the zxnDMA to the DAC (`pokey_frame` on the main CPU, ~26 000–39 000 of its 28 MHz ticks a frame); pure tones on 3 AYs | a General Sound's own Z80 plays all of POKEY (`gs/`); the main CPU sends 8 bytes a frame (~3 400 with the driver). Without a card: the pure tones on TurboSound's 2 AYs |
| The cartridge | esxDOS: River_Raid.rom from the program's folder | the program's own SD and FAT16/FAT32 code: the card searched (Wild Commander gives no folder) |
| TV | 50 or 60 Hz (CAPS + 1) | 50 Hz only: the board's frame |
| Clearing the picture | PUSH, two Layer 2 pages a frame | the DMA's fill, half the picture a frame |
| Tools | `nxcheck` (Next core), `NXHISTALL` + `tools/prof.py` | `tscheck` (TSConf core), `TSHISTALL` + `../tools/prof.py` |

## The numbers

Times are the TSConf core's ticks at 14 MHz (the CPU's clock), a frame has ~286 800. From
tscheck's histogram (`TSHISTALL=file`, then `python3 ../tools/prof.py build/test.sym file
60`, divided by the frames), on the check's build (`-DTEST`: with the Atari's screen memory,
which the game does not have: `line_done` and `draw_line` are ~1 000–2 000 heavier than in
the game). With a General Sound, so the noises cost the main CPU nothing. Two runs:

- **A**: bot 1, 3 000 frames from the start: the work ~74 000 a frame on average, ~124 000 at most;
- **B**: `-stress` from bridge 80, 6 000 frames (`TSBRIDGE=80 TSGHOST=1 NXGAME=1 … -bot 1 -stress`: all slots taken, full speed, always firing): ~116 000 on average, ~153 000 at most.

The work is from `apply_done` to `frame_done` (the frame INT's waits not counted); the parts
below also count `apply` and the INTs (~7 000).

By part (A / B):

| part | A | B |
|---|---|---|
| the display: objects' placement and collisions (`display`, `ds_*`, `dh_*`, `sp_*`, `hit_*`) | 42 900 | 57 300 |
| new river lines (`river_gen`, `render_line`, `span_line`, `line_done`, `push_line`) | 14 400 | 33 800 |
| sprites and the bank's events (`build_sprites`, `ob_*`, `pl_*`, `obj_lookup`, `sfile_put`, `build_events`, `pal_get`) | 10 700 | 16 000 |
| `apply`, the panel and the INTs (`apply`, `panel_frame`, `panel_draw`, `pc_*`, `pal_edges`, `irq`, the panel's printing) | 7 300 | 7 000 |
| sound (`sound_driver`, `snd_*`, `gs_*`; without a card `ay_*`: ~5 800 in A) | 3 400 | 3 500 |
| the game logic and the rest (`move_objects`, `main_loop`, `random_step`, `vbi`, …) | 7 000 | 9 100 |

The most expensive routines (A / B):

| routine | A | B | file |
|---|---|---|---|
| `display` (own code) | 11 000 | 12 600 | display_simple |
| `render_line` | 4 400 | 10 200 | render |
| `span_line` | 3 900 | 9 400 | spans |
| `ds_edge_test` | 2 800 | 8 800 | display_simple |
| `dh_pf` | 7 100 | 8 300 | display_hits |
| `ds_obj` | 5 500 | 6 400 | display_objs |
| `dh_obj` | 4 500 | 5 900 | display_hits |
| `ob_attr` | 2 500 | 5 200 | sprites |
| `dh_bits` | 3 700 | 3 900 | display_hits |
| `move_objects` | 1 700 | 3 300 | game |
| `dl_fill` | 1 500 | 3 300 | river_gen |
| `hit_setup` | 2 100 | 3 300 | display_hits |
| `ob_list` | 2 400 | 3 100 | sprites |
| `line_done` (screen memory's copy, check build only) | 1 100 | 2 500 | river_raid |
| `sfile_put` | 1 600 | 2 400 | river_raid |
| `dh_lists` | 2 000 | 2 000 | display_hits |
| `pl_keep` | 800 | 1 600 | sprites |
| `panel_frame` | 1 600 | 1 600 | panel_ts |
| `irq` | 1 400 | 1 400 | river_raid |
| `gs_send` + `gs_wait_c` + `gs_wait_d` | 2 400 | 2 400 | sound_gs |
| `apply` (own code) | 1 200 | 1 200 | river_raid |
| `pal_edges` | 1 100 | 1 100 | river_raid |
| `build_events` | 1 000 | 1 000 | river_raid |

At 7 MHz (`TSSPEED=1`, ~143 400 ticks a frame) the work is the same instructions: `-stress`
~96 000 on average, ~143 000 at most, just fitting; at 3.5 MHz it does not keep up.
`gs_send` waits for the card to read each byte (~300 ticks a byte at 14 MHz).

(`prof.py` takes a routine's name from the nearest global label below the address. Addresses
below $4000 are the start's work in INIT_PAGE: leave them out.)

## Memory while the code runs

16K windows and the pages in them (the board's 16K pages):

| window | address | normally | remapped by |
|---|---|---|---|
| 0 | $0000–$3FFF | 1 (`ATARI_PAGE`): the Atari's RAM at the original's addresses | at the start: 3 (`INIT_PAGE`: `sprite_pics.asm`, `gs_load.asm`, `load_rom.asm` run there) |
| 1 | $4000–$7FFF | 5 (`WORK_PAGE`): the lines' runs at $4000 (`SPANS`, 32 bytes × 256 lines), buffers at $6000 (`scan_*`, `edge_runs`, `ring_*`, `ds_objs`, `ov_exp2/4`, `eg_*`, `bg_*`, `line_*`, `edge_lo/hi`, `rnd_tab`), the OS font at $7D00 | `render_line`: a page of the river's picture (32–47); `panel_draw`/`pc_*`: the panel's picture (64–79); at the start the tile map (7), the tiles (8), the sprites' pictures (24–31); always put back to 5 |
| 2 | $8000–$BFFF | 2 (`CODE_PAGE`): code to ~$9F71, the cartridge at $A000 | — |
| 3 | $C000–$FFFF | 6 (`HIGH_PAGE`): code to ~$D60E, then at $E000 the FM window (`CRAM_SHADOW`: CRAM $E000–$E1FF, the SFILE $E200–$E3FF; the writes also go to the RAM under it), tables and variables to ~$FD47, the stack, the IM 2 vectors at $FE00 | — |

The pictures: the river from page 32 (`VID_PAGE`, 16 pages: 512 lines of 512 bytes, 320 dots
of each shown), the panel from page 64 (`VPANEL`), the tile map in page 7, the tiles' dots in
page 8, the sprites' 512×512 dots in pages 24–31 (`SGPAGE`). The INIT_PAGE's code ends at
~$11E5, the work page's buffers at $7C00. The FM window is on for good: nothing else may use
$E000–$E3FF, and $E400–$E4FF are its registers (`palette_lo` is there, read only).

## The frame

`main_frame` (river_raid.asm), every frame:

1. Snapshots what this frame's picture shows (`scroll`, the edge and water colours, the player), `read_input`.
2. Normally: `prepare` → `display` → `build_sprites` → `build_events` → `main_loop` → `vbi` → `snd_frame`. During a reset (`busy`): `display` → `build_sprites` → `build_events` → `clear_layer2_page` → (`finish_reset` in the last) → `vbi` → `snd_frame`.
3. `wait_frame`: HALT until the frame INT has come (`frame_flag`), at `FRAME_LINE`, below the panel.
4. `apply`: everything built goes live (the scroll, the sound, the colours, the SFILE, the bank's palette at the top and the INT's events for the frame to come).
5. `panel_draw`: the panel's characters that changed and the scrolling line's new ones, into its picture (after `apply`: it may take a while, and the panel is shown only from row 184).

While the picture is drawn the INT comes at each event of the list `apply` armed: EV_PAL (the
river's palette from the next line), EV_PANEL (the panel's picture from row 184), EV_GX (the
scrolling line's X), then the frame's INT. Each comes at the right border of the line before
(HSINT = 208), and PALSEL, VPAGE, GYOFFS are taken at a line's end, so a change is exact at
any CPU speed and wherever the work is.

---

## The Next's files, as they are here

Copied from `../src`, the same code:

- `river_gen.asm`, `display_objs.asm`, `panel.asm`, `vars.inc`, `font.inc`, `random.inc`: unchanged.
- `display.asm`, `display_simple.asm`, `spans.asm`: the SPANS page is not mapped (`nextreg $52,SPAN_PAGE` gone: window 1 holds SPANS all the time); `spans.asm` without `rl_fill`/`rl_next` (the Next's `render_line` helpers).
- `display_hits.asm`: `bsla de,b` (Z80N) as `shl_de_b`, a loop of 0–7 `sla e / rl d` (in `hit_line`: up to ~100 ticks more a test, a few hundred a frame).
- `game.asm`: `tm_colour` does nothing (no T on the border yet); `push_line` moves `scroll` in a ring of 512 lines (9 bits) and draws into the picture's line `scroll + RIVER_TOP`.
- `play.asm`: `clear_layer2_page` is the TS-Conf's (river_raid.asm, the DMA); `read_input` without CAPS + 1 (no 60 Hz), CAPS + 2 (sound off), CAPS + 3 (speed), T, the second Kempston and the Mega Drive pad.
- `sound.asm`: only `sound_driver` and `sound_random`: `pokey_frame` runs on the General Sound (`gs/`).
- `render.asm`, `sprites.asm`, `sound_ay.asm`, `load_rom.asm`, `river_raid.asm`: the TS-Conf's own (below), with the Next's names where they do the same job.

The routines of the first three groups are described in [docs/CODE.md](../docs/CODE.md); their
costs here are in the table above.

## river_raid.asm: the frame, the start, the INT, the colours

The top file: the board's ports, memory, the pages, `include`s, the frame, the INT, `apply`,
the river's palettes, variables and buffers.

| routine | called | what and how | A / B |
|---|---|---|---|
| `start` | at load | 14 MHz and the cache (SYSCONFIG $06), window 0 RAM (MEMCONFIG $0E), the pages, `screen_black`, `load_rom` (SPG builds), `init_tables`, `init_video`, the sprites' pictures (`obj_pics`, `pl_pics`, `panel_pics`), `gs_load`, then the Atari's RAM in window 0, `panel_init`, `ay_quiet`, RANDOM's seed, IM 2 (vectors at $FE00), `restart`. | once |
| `restart` | `start` | `tv_setup`, the picture cleared (both halves by the DMA, waited for), the frame INT at `FRAME_LINE`, `start_attract`, the panel drawn whole, falls into `main_frame`. | once |
| `main_frame` | every frame | See *The frame*. | 340 / 340 |
| `wait_frame` | `main_frame` | HALT until `frame_flag`: idle time, not work. | — |
| `irq` | the INT | The event at `ev_ptr`: EV_PAL PALSEL; EV_PANEL VPAGE = `VPANEL`, GYOFFS = 0, VCONFIG $8A (256 colours, the bitmap over tiles and sprites); EV_GX GXOFFS; the frame's (EV_END) `frame_flag`. Events on the same line taken together; then VSINT set to the next one's line (`vsint_set`), or the frame's. | 1 400 / 1 400 |
| `vsint_set` | `irq`, `apply`, `restart` | VSINT = HL (9 bits), kept in `ev_line`. | 340 / 330 |
| `apply` | after `wait_frame` | GYOFFS = `show_scroll`, VPAGE the river's, VCONFIG $81 (16 colours), GXOFFS 0; `snd_out` (the AY's registers or the card's frame); `panel_frame`; the shell's and the plane's colours into CRAM; `sfile_put`; while the picture is being cleared after a reset (from its second frame): the river black (palette of colour 0, edge and water 0, only the panel's events); else PALSEL the palette at the top (`ev_built`), `pal_edges`, the panel's events copied after the bank's (`ev_tail`); the INT armed at the first event (DI around it); `ev_show` = the list just armed (`build_events` writes the other). | 1 200 / 1 200 |
| `pal_get` | `build_events`, `apply` | The river's palette (PALSEL 0–7) of Atari colour E: each bank colour has its own, made when first seen (`pal_of`, `pal_n`): its colour 1 that colour, in CRAM. Past 8, the last again (never seen). | 110 / 110 |
| `pal_edges` | `apply` | Colours 2 and 3 (edge, water) of every palette made so far. | 1 100 / 1 100 |
| `sfile_put` | `apply` | The SFILE (at $E200 through the FM window): the river's sprites (`spr_list`, S0), an end entry (LEAP), the panel's 3 (needle and logo, S1), an end; the entries past them up to last frame's end (`sf_end`) cleared. 6 bytes a sprite by LDIR. | 1 600 / 2 400 |
| `build_events` | `main_frame` | The bank's colour by line, as the Next's `build_copper` from `ds_bank_ev`: into the buffer the INTs do not read (`ev_a`/`ev_b`), the palette at the river's top, then an EV_PAL event for each change, 5 bytes (kind, palette, colour for the check, VSINT line a line before it); `ev_tail` where apply puts the panel's two. | 1 000 / 1 000 |
| `clear_layer2_page` | `main_frame` during `busy`, `restart` | Half of the river's picture (256 lines × 160 bytes, 4 pages) a frame by the DMA's fill (DMACTRL $14, 80 words × 256 lines from `dma_zero`); none in the reset's first frame (`l2_wait`); nothing while the DMA is busy. The CPU only programs it (~150 ticks). | |
| `dma_wait` | `restart`, `init_video` | Until the DMA is free (DMACTRL bit 7). | |
| `init_tables` | `start` | As the Next's (`edge_runs_init`, `ov_exp2/4`, `ring_*`, `span_class`, `edge_lo/hi`, `span_init`), `pix_tab` with both nibbles the index (the 16-colour mode's 2 dots a byte). | once |
| `init_video` | `start` | The river's mode (VPAGE 32, VCONFIG $81, PALSEL 0); the tile map (page 7: rows 0–23 tile 1 black, 184 tile 3 a black line over grey, 185–223 tile 2 grey, 224–239 black; the river's rows none) and the tiles' dots (page 8); the sprites' 128K cleared by the DMA; TSCONFIG $A0 (tile layer 0 and sprites on); the FM window on for good, CRAM and SFILE zeroed; the tank's colour; HSINT, the frame INT only (INTMASK 1). | once |
| `screen_black` | first in `start` | TSCONFIG 0, BORDER 0, all 1K of CRAM and SFILE zeroed through the FM window: black whatever mode Wild Commander left (its ZX screen in page 5 is where the start's buffers go). | once |
| `tv_setup` | `restart` | PAL only: `init_line_tables`, RANDOM's PAL columns, `rnd_tables`. | |
| `test_ghost` | test builds | tscheck's TSGHOST, as the Next's. | |

`span_rec` (HL = a line's record in SPANS) is the same macro as the Next's, at $4000.

## render.asm: a line into the picture

| routine | called | what and how | A / B |
|---|---|---|---|
| `render_line` | `line_done` | Colour clocks 20–179 of the line into the picture's line HL (0–511): page `VID_PAGE` + line / 64 into window 1, the line at $4000 + (line & 63) × 256; from `dl_seg`'s pieces as the Next's: a piece of one value is its `pix_tab` byte 4 times a byte (`.fill`: `ld (hl),a / inc l`), an edge's bytes (the ROM's table) and a decoration's row through `pix_tab`, 4 output bytes each. 160 writes a line along the row (the Next writes 320 down columns, 10 pages). WORK_PAGE back at the end. | 4 400 / 10 200 |

## sprites.asm: the river's sprites

The TS-Conf's sprites have no scale, so every picture is kept at 16, 32 and 64 dots across
(an Atari pixel is 2 dots; a player 8 pixels at size ×1, ×2, ×4). An object is a single
sprite up to 24 rows (the Next makes one per 16 rows). Palettes: objects 14 and 15
(`OBJ_PAL_A`, `OBJ_PAL_B`, the row colours at places 1–15), shell and missile 8, tank 9,
plane and bullet 10. The entries (6 bytes each, the SFILE's format: Y with YS and ACT, X with
XS and the flip bits, the tile and the palette) go to `spr_list`; `apply` copies them.

| routine | called | what and how | A / B |
|---|---|---|---|
| `build_sprites` | `main_frame` | `ob_list`; then the plane, its bullet, the tank, the helicopter's missile, the shell (the order `drawRiver` draws them) by `pl_pattern` + `pl_sprite`; `pl_keep`. During a reset `pl_again`. | 800 / 800 |
| `ob_list` | `build_sprites` | Per `ds_objs` entry with its rows (`ds_objf`): `obj_lookup` by the top row's shape and colour addresses; not found: no sprite; first row below the river: none; else `ob_attr`. | 2 400 / 3 100 |
| `obj_lookup` | `ob_list` | The picture of the shape byte at $B900 + E and colour byte at $B700 + D: `obj_head` (by the shape byte) then its chain in `obj_e`; A = picture + bit 7 for `OBJ_PAL_B`. | 1 000 / 1 300 |
| `ob_attr` | `ob_list` | The SFILE entry: Y = `RIVER_TOP` + its line's place in the river (9 bits) with YS from `pic_h` and ACT; X = 2 × (position − 52) (9 bits) with XS 1, 3 or 7 by its size; the tile of the right width (`pic_tn16/32/64_lo/hi`), the palette. | 2 500 / 5 200 |
| `pl_pattern`, `pl_sprite` | `build_sprites` | The frame's picture from its table ($FF: none); a 16-dot sprite at line D (none below the river), position E, palette C. | ~100 a sprite |
| `pl_keep`, `pl_again` | `build_sprites` | The players' entries kept; a reset's frames show them again (as the Next's). | 800 / 1 600 |
| `cram_set` | the start, `init_video` | CRAM entry A × 16 + B = Atari colour E (`palette_lo`). | |

## sprite_pics.asm (INIT_PAGE, at the start): the sprites' pictures

Into the 512×512-dot picture memory (SGPAGE, 4 bits a dot, a line of 256 bytes) through
window 1; a picture's tiles are 8×8, numbered (line / 8) × 64 + x / 8.

| routine | called | what and how |
|---|---|---|
| `gfx_alloc` | `pic_set`, `pl_pics`, `panel_pics` | A place for a picture BC dots across, A rows (a multiple of 8): along the lines while they hold it, then the next lines (`gfx_cx`, `gfx_cy`, `gfx_rh`). |
| `gfx_tile` | | The tile number of a dot. |
| `gfx_row` | | Row C of a picture: byte D's dots (bit 7 first) in colour E at the three widths (2, 4, 8 dots a bit), or only the first (B 1). |
| `obj_pics` | `start` | As the Next's `obj_pics`: for types 7–15 the kinds they can have (their own, `ROM_NEXT_KIND`'s below $0C, the explosion's), each mirrored too, height + 1 rows as the DLI draws them; each picture once (by its addresses) at the three widths; a dot's value its row colour's place in palette 14 or 15 (made when new: `cram_set`); `obj_head`/`obj_e` for `obj_lookup`. |
| `pic_set` | `obj_pics` | Picture `op_p`'s three tiles (at gfx_x, + 16, + 48) and its YS. |
| `pl_pics` | `start` | The plane's 10 frames, the tank's 8, the shell's 7 (from their ROM pointer tables, as `prepare` copies them), the bullet and the helicopter's missile: 16 dots across, colour 1; one picture per address, $FF for an empty frame. |
| `panel_pics` | `start` | The needle (missile 1: 2 colour clocks, 10 rows) and the logo: player 3 at 64 dots (data $FC), player 2 (data $FF) a clock further left each row (7 rows in 32 dots). |

## panel_ts.asm: the panel and the scrolling line

The panel is a picture of its own (pages 64–79, 256 colours, 512 bytes a line), shown from
screen row 184 (the frame INT's EV_PANEL) with the bitmap over the tiles and sprites
(GFXOVR): its dots of 0 are holes, which show tile layer 0 (the grey, black) and the panel's
sprites. Colours 4–7 the panel's PF0–PF3, 8 the scrolling line's. The scrolling line is a
ring of 32 characters across the picture's 512 dots, shown from GXOFFS (EV_GX at its first
row).

| routine | called | what and how | A / B |
|---|---|---|---|
| `panel_init` | `start` | The Atari's two character sets into its RAM where the game builds them (A0FB–A143: the scrolling line's at $0600, the panel's at $0800); the colours (CRAM: the characters' as palette 0's entries 4–8, the needle's, the logo's rows from $B48D, the tiles' black and grey as palette 3's entries 14 and 15: a river palette uses only entries 0–3); the characters drawn once (`GLYPHS`: the scrolling line's, the panel's in its 4 colours) for `pc_put` to copy; the panel's picture cleared; all of it marked to be written at the first frame. | once |
| `panel_frame` | `apply` | The scrolling line's X (`pf_gx` = 16 TEXT_LO + 38 − 2 FINE_SCROLL, 9 bits) for the INT's EV_GX; the needle (missile 1 at fuel / 8 + $5C) and the logo's two sprites into `spr_s1` (`.spr`). | 1 600 / 1 600 |
| `panel_draw` | after `apply` | The characters `panel_put` listed (`pf_dirty`, all 60 after a copy) by `panel_frame.char`; the scrolling line: when TEXT_LO moved on by one, its character 24 on; when it jumped, all 25 (`panel_frame.text`: character t at the ring's dot 16 t mod 512). | 160 / 160 (+ `pc_*`) |
| `pc_put` | `.char`, `.text` | A character copied by the DMA from where it was drawn once (`pc_bank`) to the panel's picture at line E, dot HL; while the DMA is busy (a reset's clearing) drawn by `pc_draw`. | |
| `pc_draw` | `pc_put`, `panel_init` | A character's 8 rows drawn: set dots colour B, the others 0 (holes); dots left of 0 not drawn. | 700 in A |
| `pc_bank`, `pc_adr`, `pc_reg` | | Where a glyph was drawn; a line's page and address; a DMA address into its registers. | |

## sound.asm, sound_gs.asm, gs_load.asm and gs/: the sound on a General Sound

The Next's `pokey_frame` (its samples, the pulses, the 17-bit counter) runs on the card's own
Z80 at 12 MHz; the main CPU sends POKEY's registers once a frame.

| routine | called | what and how | A / B |
|---|---|---|---|
| `sound_driver` | `vbi` | The original's driver (as the Next's). | 840 / 1 000 |
| `snd_frame` | `main_frame` | With a card nothing; else `ay_frame`. | |
| `snd_out` | `apply` | With a card `gs_send`; else `ay_out`. | |
| `gs_send` | `snd_out` | Command `GS_FRAME` ($A5) to port $BB, then AUDF1–4 and AUDC1–4 to $B3, each once the card has read the one before (`gs_wait_c`: bit 0 of $BB clear; `gs_wait_d`: bit 7). A timeout (~0.2 s): the card is dropped (`gs_on` 0), the AY from then on. Most of its time is waiting for the card. | 2 400 / 2 400 |
| `gs_load` | `start` (INIT_PAGE) | Command $F0 (the firmware's status): no answer, no card; `GS_READY` ($5A) the program is there from a run before, go on with it. Else through the firmware: #12 page 2 at $8000, #18 the address, #19/#1B the program's bytes (`gs_prog`: `build/gs_pokey.bin` incbin'd), #13 a jump to `GS_ORG` ($8400), then wait for `GS_READY` (the program makes its tables first). `gs_on` = 1. | once |

The card's program, `gs/gs_pokey.asm` (built separately into `build/gs_pokey.bin`):

| routine | what and how |
|---|---|
| `gs_start` | IM 2 (all vectors to `INT_AT` $4141, the handler copied there), the variables cleared, $6000–$63FF a byte's own value (a read at $6000 + 256 (n − 1) + v latches v into DAC n), all four volumes at 63; `poly_make`, `tables_make`, the ring quiet, `GS_READY` out. |
| `main` | Waits for a command: $F4 (`GS_RESET`) DI, IM 1, JP 0 (the firmware again); $F0 (`GS_STATE`) `GS_READY` back; any other the 8 data bytes into `pokey_audf`/`pokey_audc`, then `pokey_frame`. |
| `gs_int` | The card's INT, 37 500 a second: a DDA (`DDA_STEP` 108 of 256) takes a sample from the ring 15 820 times a second, latches it into all four DACs (`ld a,(hl)` from $6000, $6100, $6200, $6300 + level): 1 and 2 left, 3 and 4 right, each side the sum of its two. |
| `poly_make` | POKEY's 17-bit counter's bits into $C000–$FFFF (16K), from the recurrence q(k) = q(k−9) ^ q(k−11) ^ q(k−12) ^ q(k−17) and its seeds; the Next reads them from `poly17.bin` (no room for 16K in the card's program). |
| `tables_make` | `snd_tables`, `snd_mod15/31`, `g4_tab` (as the Next's `sound_init7`). |
| `pokey_frame`, `snd_fill`, `snd_sum` | The Next's, without the AY, the zxnDMA and the time limit, and at 4 a volume step, not 8: all four channels are here (the Next's AYs take the tones), up to 60 × 4 = 240; at 8 they wrapped past 255 when explosions met (a hiss), and the two DACs a side make it as loud. Also: the samples ahead of the INT's place (`rp`) up to `SND_LEAD`, at most `SND_CAP`, the last level held past them (`SND_HOLD`). |
| `gs_pulses.asm`, `gs_handlers.asm` | The Next's `sound_pulses.asm`, `sound_handlers.asm`: the 17-bit counter's pointer wraps to $C0 (its 16K at $C000), and no `mul`. |

Its memory: $4000 the vectors, $4141 the handler, $4200 on the variables, `snd_tables` at
$4300, `snd_mod15/31` at $4400/$4500, `g4_tab` ending at $4800, the stack below $6000; page 2
at $8000: the ring $8000–$83FF, the program from $8400; $C000 the 17-bit bits.

## sound_ay.asm: the pure tones without a card

| routine | called | what and how | A |
|---|---|---|---|
| `ay_frame` | `snd_frame` | As the Next's: POKEY's channels playing a pure tone to an AY channel each (1 the second chip's A, 2 its B, 3 the first's B, 4 its C), N = (AUDF + 1) × 3.454 by adds (`3a + round(a × 116 / 256)`, no `mul`), the volume by `ay_vol`; into `ay_regs`. Not 2 frames late: with no DAC to keep in step, `apply` puts this frame's out. | 1 100 |
| `ay_out` | `snd_out` | The two chips' registers 0–10 (port $FFFD selects the chip and register, $BFFD the value). | 2 100 (+ 600 `ay_clear`) |
| `ay_quiet` | `start` | All quiet. | |

## load_rom.asm (INIT_PAGE, SPG builds): the cartridge from the SD card

Wild Commander starts the .spg with no folder and no DOS, so the program reads the card
itself through the Z-controller (port $77 bit 1 its /CS, port $57 a byte each way). The
sector buffer is SPANS (made anew after the start).

| routine | what and how |
|---|---|
| `load_rom` | `sd_init`, the MBR's first partition (or the card itself without a partition table: `lr_bpb`), the FAT volume's numbers, `lr_search` from the root; the file's clusters read into $A000 (8192 bytes). Without it `lr_fail`: CRAM entry 1 red and BORDER 1, then a stop. |
| `sd_init`, `sd_cmd`, `sd_read` | SPI mode (CMD0, CMD8, CMD55 + ACMD41, CMD58: SDHC block addresses, else CMD16 512 and byte addresses, `lr_hc`), a sector of 512 bytes. |
| `lr_bpb` | A boot sector: FAT16 or FAT32, sectors a cluster, FAT, root and data addresses. |
| `lr_search`, `lr_get`, `lr_advance`, `lr_rewind` | A folder's entries in turn (FAT16's fixed root or a cluster chain); the files first, then the folders, depth first, 8 deep (`lr_save`/`lr_restore` put the walk aside). |
| `lr_lfn`, `lr_name`, `lr_upper` | The long name from its LFN entries (13 characters each), compared with RIVER_RAID.ROM in any case; else the short name RIVER_~1.ROM. |
| `lr_next`, `lr_clus_lba` | The cluster chain from the FAT (16 or 32 bits); a cluster's first sector. |

## Includes and tools

- `palette_ts.inc`: Atari colour → CRAM word (5 bits a component, levels 0–24), the C++ port's PAL colours (`make palette`: `tools/mkpalette_ts`).
- `vars.inc`, `font.inc`, `random.inc`: the Next's.
- `gs/poly.inc`: POKEY's 4- and 5-bit sequences (`tools/mkpoly`).
- `tools/mkspg.py`: the SPG 1.0 file from the pages (`spg_page2/6/5/3.bin`): $8000–$9FFF, $C000–$FFFF, the font, the INIT_PAGE's code.
- `tools/tscheck.cpp`: Xpeccy+'s TSConf core (and its General Sound) beside the C++ port, every frame.

## Conventions worth knowing before changing code

- **The shared code**: a change to the game (logic, generator, display, collisions) goes into the C++ port first, then the Next's `src/`, then the copy here (`diff ../src/X.asm src/X.asm` shows only the changes listed above). A change to how the TS-Conf shows it stays here.
- **Window 1** is WORK_PAGE except while `render_line`, `panel_draw` or the start map another page there; each puts WORK_PAGE back (SPANS and the buffers live there).
- **The FM window** at $E000 is on all the time: writes to $E000–$E3FF go to CRAM and the SFILE (and to the RAM under them, which is how `apply` reads them back); never put anything else there.
- **The INT's events** are double-buffered (`ev_a`, `ev_b`): `build_events` writes the one `ev_show` does not name; `apply` arms it under DI.
- **Registers taken at a line's end** (PALSEL, VPAGE, GYOFFS, GXOFFS): set them in the INT of the line before; the INT comes at HSINT 208 (the right border), so there is time at 3.5–14 MHz.
- **The DMA** is shared by the picture's clearing (`clear_layer2_page`) and the panel's characters (`pc_put`): `pc_put` draws by CPU while the DMA is busy.
- **The checks**: `make check` (3 000 frames; `FRAMES=`), and with a bot, `-stress`, TSBRIDGE, TSSPEED=1 (7 MHz), TSGS=neo or 0, as in [README.md](README.md). After any change: the state, the bank colour by line (`ev_built`), the General Sound's registers and the machine's picture of every frame pixel for pixel.
- **Measuring**: `TSHISTALL=file` (every instruction's time over the run, the start, the INTs and the wait included), then `python3 ../tools/prof.py build/test.sym file 60`; the work's average and maximum are in tscheck's last lines. `TSTIME=N` prints the work of frames N−2..N+2. `TSVOL=1`: the frames' sums of POKEY's volumes and the card's highest level (it must stay at most 255).
