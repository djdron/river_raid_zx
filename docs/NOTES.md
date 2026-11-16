# River Raid on the ZX Spectrum Next — notes

English | [Русский](NOTES.ru.md)

How the port is done and what was found on the way, with numbers. Addresses like A205 are the original's code; $xxxx in the Z80's address space unless said otherwise. The C++ port's files are in `deps/river_raid/port/src`.

## Memory
| Z80 | 8K page | What |
|---|---|---|
| $0000–$3FFF | 30, 31 | the Atari's RAM, at the original's addresses (state, $0500 slots, $0600–$09FF character sets, $0B00–$0FFF player-missile memory, $1000 panel, $2000–$2EFF and $3000–$3EFF screen memory, $3F04 the top line's address, $3FB3 the scrolling line's text) |
| $4000–$5FFF | 18–27 / 10, 11 / 7 | a window: Layer 2 (render_line, clearing), bank 5 (tilemap, panel_frame), page 7 (pattern cache, build_sprites) |
| $6000–$7FFF | 12 | scan_* per scanline, double_hi/lo, ch_bits, ring_lo/hi, sprite_list, copper_list (2K), exp8 (2K) |
| $8000–$9FFF | 4 | header and frame loop, river generator, render, palette, random maps, play.asm (~1.6K free) |
| $A000–$BFFF | 5 | the cartridge (loaded from the SD card; esxDOS F_OPEN/F_READ, long name then RIVER_~1.ROM; checked: 8192 bytes, $BFFA = $A000) |
| $C000–$DFFF | 6 | game.asm, display.asm, sprites.asm (~350 bytes free) |
| $E000–$FFFF | 1 | variables, pix_tab (4 pages), mc_bullet/mc_missile, pf_class, line_start, line_after_draw, dsh_tables (12 pages), stack |

Page 7 is mapped at $6000 only while `panel_init` runs at the start; its free part ($0800 on) keeps the pattern cache. The NEX holds 16K banks 2 and 3 (pages 4–7).

Header at $8000 (for the checks, `tools/nxcheck.cpp`): `jp start`, the addresses of `line_done`, `frame_done`, `apply_done`, POKEY's counter at the first read (3 bytes), the controls (in_stick ×2, in_trig, in_console, in_key at 12–16), `tv_init` (17), `rnd_feed_on`, `rnd_feed`, `rnd_feed_reads` (18–20).

## The frame
`main_frame` (river_raid.asm): snapshot what the display shows (scroll, edge and water colours, player), controls, CAPS + 1; then `prepare`, `display` (the DLI), `build_sprites` (sprites and the Copper's list), `main_loop`, `vbi`; or during a reset (sub $B0F1 clearing memory: 13 frames NTSC, 8 PAL) only display, sprites, two pages of Layer 2 cleared and the VBI, and `finish_reset` in the last. Then `wait_frame` (raster line 208 NTSC, 220 PAL: below the scrolling line, so nothing on screen changes while it is drawn) and `apply`: Layer 2's scroll and colours, the sprites' attributes, the panel and scrolling line, the Copper's list.

## Next hardware as used
- **Layer 2** 320x256, 8 bits, stored by columns (byte x·256 + y, 32 columns per 8K page): a river line is a column-wise write of 320 bytes (`render_line`, through `pix_tab`). Vertical scroll NR $17; the river's ring of 256 rows moves one row per new line. Clip window rows 40–199. Index 0 black, 1 bank (Copper per line), 2 edge, 3 water (apply: red while a bridge flashes, black while the screen is cleared).
- **Palette writes** with NR $41: 8 bits; the 9th (blue LSB) becomes (b1 | b0). The colours are the C++ port's PAL colours (Altirra's model) through `tools/next_palette.h` (8-bit, never $E3, the global transparency). The fallback colour NR $4A is extended the same way.
- **Sprites** with 4-bit patterns: 128 bytes each, 128 of them in 16K; pattern p = slot p/2 ($303B, bit 7 for the second half), attribute 3 bits 5–0 the slot, attribute 4 bit 6 (N6) the half, bit 7 = 4-bit. X is 9 bits and wraps round 512, which puts sprites partly off the left edge. Scale bits for double and quadruple width. Two sets of patterns in turn (0–59, 64–123); 124–127 fixed: the fuel needle and the logo.
- **Copper**: mode %11 (restart each frame). WAIT h = 40 (past the 320 dots) on the line before the one to change; line L of Layer 2 is v = L − 32. MOVE NR $43/$40/$41 for palette entries, $31/$30 for the tilemap's scroll, $4A for the fallback colour.
- **Tilemap** 40x32 with attributes, 512-tile mode (attribute bit 0 = tile bit 8), NR $6E = $21 (map at bank 5 + $2100), NR $6F = 0 (tiles at bank 5 + 0), pixel 0 transparent (NR $4C), clip rows 200–239 (NTSC) or 200–255 (PAL). Layer order USL (NR $15 = %00010011): tilemap over sprites over Layer 2.
- **50/60 Hz**: NR $05 bit 2, read-modify-write (the other bits are the joystick modes and the scandoubler).
- **Controls**: keyboard half-rows on port $FE; Kempston 1 at $1F, 2 at $37 ($FF there means nothing connected); Mega Drive pads: bit 7 START, bit 6 A.
- **Clock and interrupts**: 28 MHz (NR $07 = 3), set at start; only speed depends on it (the DLI model counts Atari cycles). Interrupts stay off (DI): per-line changes are the Copper's, and the frame goes live by polling the raster line (NR $1E/$1F). Line interrupts (NR $22/$23) and the sprite collision flag ($303B bit 0) are not used: the flag knows neither which sprites nor the playfield, and is set only as the beam draws, a frame too late.

## Sprites from the Atari's players and missiles
`build_sprites` in the order `Game::drawRiver` draws: player 3 from the DLI's record (`scan_p3/x/size/col` per scanline), then the plane (player 2), its bullet (missile 2), the tank (player 1), the helicopter's missile (missile 0), the shell (player 0) from player-missile memory at one position. A run is up to 16 lines at one position and size; each run is a sprite. An Atari pixel (colour clock) is two sprite pixels: a byte's 8 bits are 8 bytes of $11/$00 (`exp8`). Missiles' bits become a player's byte through `mc_bullet` (1 clock a bit) and `mc_missile` (2 clocks a bit). Lines are scanned 8 at a time (OR of 8 bytes). At most 60 sprites a frame; the most seen in the checks is 11.

**Pattern cache**: a sprite's 16 rows (its key) are hashed; a hash table per set (page 7: PC_BUCKETS) gives a pattern of that set with the same rows if there is one, else the next pattern not used this frame takes them (round robin, the old hash entry removed). Pattern RAM is cleared at the start so the cache (all zero) agrees.

**Copper list** per frame: for each river line, the bank colour where it changes (Layer 2 entry 1) and player 3's colour where it changes on a line with player 3 (sprite entry 1), each set on the line before. Then the panel's part (from `copper_panel_ntsc` or `_pal`): fallback grey, tilemap Y per character row, X scroll for the scrolling line (patched by `panel_frame` with the frame's fine scroll).

## The panel and the scrolling line
Character sets built at the start where the game builds them (A0FB–A143): the OS font's pages $E000/$E100/$E300 (AltirraOS's, `src/font.inc`, made by `tools/mkfont` from the C++ port with its notice) and the cartridge's symbols ($BEEE logo lettering, $BF2E panel symbols, $BF9E player labels, $BFB6 year digits). They stay at $0600–$09FF (start_attract leaves that range). Each character is two tiles (left and right 4 colour clocks, two dots each): tiles 0–127 the panel's set, 128–255 the scrolling line's.

Map rows: the panel's three at 20, 22, 23, the scrolling line at 26; the Copper sets the tilemap's Y scroll so that they come at lines 202/211/219 and 231 (NTSC) or 206/218/226 and 243 (PAL), from `status_bar.cpp`'s layouts plus 20. The panel's first character starts 8 dots left of the screen: column 0 is its right half, column 39 empty.

The scrolling line moves 1 colour clock (2 dots) a frame: its text starts 38 − 2·fine dots left of the screen. The X scroll is s = (38 − 2·fine) & 7, the first half character H0 = (38 − 2·fine) / 8; column t shows half character H0 + t. Column 0 is seen twice: dots s..7 at the left edge (half H0) and dots 0..s−1 at the right edge (half H0 + 40), so tile 256 is made each frame from those two halves.

The panel's grey (COLBK $06) is the fallback colour from line 201: nothing else is drawn there, so the fuel needle (sprite, missile 1) is over it and the characters over the needle, as PRIOR 4 has it on the Atari. The logo is five sprites: three 16-dot parts of player 3 at quadruple width (data $FC) and two for player 2 (data $FF) one colour clock further left each row; seven colours from $B48D in sprite palette offset 5.

## The DLI model (display.asm)
As `display.cpp`'s Beam: 114 cycles a line; at the start ANTIC takes 5 (players and missiles) + 1 (display list) or + 3 (an instruction with an address: the top row and where screen memory goes on in the other block, and the panel's first line, 190 NTSC / 194 PAL, which takes 3 and leaves 20 after the draw); the line is drawn at cycle 28, then 9 refresh and 48 screen data on a river line; STA WSYNC waits for 106.

`op n` / `opa`: an instruction of n cycles; IXH holds the cycles to the next event (signed); events due before the instruction happen first (`bm_events`: the line drawn, then the next line). Instructions with nothing the beam sees between them are one op.

What a drawn line does (`bm_draw`): if player 3 is on it, its position, size and colour into `scan_x/size/col` (only there: the sprites and the Copper never look elsewhere); collisions if any player or missile is there. Player 3's data is kept as the lines latch it: `scan_p3` starts as a copy of its memory, and a write to a row whose line has not started yet goes into it too (`p3_scan`). The bank colour is recorded when it changes (`rec_set`: the lines since the last change get the old value; `rec_end` fills to the river's end).

### Fast loops
Inside an object's rows (B5CB–B5E5), after the first STA WSYNC, every line is the same: the colour part starts the next line (more than the 8 cycles left), writes the road's bank colour (on a bridge) and player 3's colour before the line is drawn (they come at cycle ≤ 21, the draw at 28), then the next row's shape part draws the line (before or after player 3's row is written, which does not matter: it is latched already) and STA WSYNC ends at cycle 106 again. So `.fast` does those events in that order, and the beam's count (IXH = 32 − cycles before STA COLPM3 − ANTIC's cycles at the line's start) is only worked out where the loop is left (`.row_tail`). The same for the wait for an object's first line (B567–B573: STA WSYNC past the line's end starts the next line and holds the CPU until it is drawn). Only river lines (28–187) go this way. This took a third of the frame's work off.

### Collisions
Only what the DLI reads (B5E8–B664, B6BC on): P3PF (edge), P1PF (edge), P2PF (bank), M0PF and M2PF (bank, edge); M2PL (player 3), P3PL (player 0), P2PL (players 0 and 3), M0PL (player 2). Per sprite on the line, the playfield's colours under it (`pf_under`): its bits doubled (2 bits a colour clock), 1, 2 or 4 bytes q, each shifted by the clock within the first screen byte is 3 bytes from `dsh_tables` (12 pages: for shift s, byte k), ORed at byte 2i; ANDed with the screen bytes; `pf_class` gives the colours of a byte (bits 1 bank, 2 edge, 4 water), accumulated in the other register set. Unrolled for normal, double and quadruple width when all bytes are on the line; byte by byte near the edges. Nothing to do if all bytes under it are water ($FF: water is never read), nor for player 3 once P3PF's edge bit is set (it stays until HITCLR). Two sprites touch: their spans (position to position + width) must meet, then each colour clock of one (over the playfield: 32–223) is looked up in the other's bits.

A line's screen memory: screen memory is a ring of 160 lines (80 in each block: +48, $2Fxx → $30xx, $3Fxx → $20xx); `ring_lo/hi` (built once) give each slot's address, and the river's top slot is found once per frame from $3F04.

## POKEY's RANDOM
`random_read` returns bits 16–9 of `rnd_state`, the counter at the game logic's read (scanline 192 cycle 13 NTSC, 191 cycle 24 PAL). `random_step` (each VBI) moves it one frame on: 262·114 or 312·114 steps, a linear map over GF(2) as 17 columns of 3 bytes (`src/random.inc`, `tools/mkrandom`). The start: `rnd_init` mixed with R (release) or `pokeyFirstRead(seed)` (checks). Test builds can take RANDOM from the checks instead (`rnd_feed`).

## PAL and NTSC
`tv_pal` (from `tv_init`, CAPS + 1 flips it and jumps to `restart`, which clears Layer 2 and starts the attract mode again). `tv_setup`: NR $05 50/60 Hz, `init_line_tables` (panel line), `wait_line`, the random map, the Copper's panel part and the tilemap's first Y scroll, clip windows. Elsewhere: depot limit ($2E/$2F, start_game), logo and needle rows ($DB/$E7, $CC/$D3), reset frames (13/8), the scrolling line's steps before the attract mode (28/17), and on PAL at a game over the VBI sees the frame counter, plane state and attract timer from before sub $B21A (`vbi_before`).

## Speed
In the core's ticks (28 MHz T-states); a 50 Hz frame is about 567 000, a 60 Hz one about 467 000. Two bot runs of 30 000 frames each:

| | average | busiest | frames late |
|---|---|---|---|
| attract mode with objects, first version | 540–590 000 | ~835 000 | 57% |
| the game, before speed work | 573–590 000 | ~1 000 000 | 62–64% |
| events, collisions, channels, render, pattern cache | 425–434 000 | 640–700 000 | 3.4–4% |
| fast loops, overlap by bits, pattern hash | 376–385 000 | 554–568 000 | 0.1–0.2% |
| water shortcut, screen line ring, pix_tab | 360–369 000 | 530–546 000 | 0.01–0.05% |

NTSC at 60 Hz: about 8% late. Where the time goes now (average): the DLI ~135 000, bm_draw ~31 000, build_copper ~24 000, channels ~21 000, events ~20 000, pf_under ~18 000, collide ~17 000, emit_sprite ~15 000, p3_channel ~14 000, render ~9 000 a line. Tried and dropped: skipping empty blocks in the Copper's list (slower), a lazily advanced screen pointer (slower than a table), keeping the beam's count in AF' (~700 ops a frame, too little).

Collisions over 20 000 bot frames (NXHISTALL, PAL; NTSC the same): about 21% of the work, ~79 000 ticks a frame on average (14% of a 50 Hz frame): bm_draw's test for anything on the line ~6.0%, collide_line + cl_get ~3.1%, collide ~5.8%, pf_under ~5.7%, bm_hitclr ~0.4%. Not tried: a per-object box test before the per-line work (skip all of an object's lines when its box meets neither a non-water byte nor another sprite).

## The checks (tools/nxcheck.cpp)
Xpeccy+'s ZX Spectrum Next core as a library (libxpeccy, MIT), headless: the SRAM loaded with the test pages (4, 6, 7) and the ROM (page 5), a `jp $8000` at 0, run instruction by instruction. Hooks: `frame_done` (a frame worked out), `apply_done` (live).
- **Against the C++ port** (default): `rr::Game::frame` beside it with the same POKEY counter and the same controls from a made-up player (Bot: waits, selects, starts, steers to the water's middle, dodges, refuels, fires, pauses). After every frame: the generator (`RiverGen::diffWithRam`), the game's fields (game_ram.cpp's list, the scrolling line too), high scores, panel, player-missile memory, screen lines, the DLI's record per line (player 3's x/size/colour only where it is). At the end the picture: the core's frame buffer against `drawRiver` + `drawStatusBar` in the Next's colours, Layer 2 rows 40–255. Before taking it, the program is stopped (JR $ at apply_done) so the next frame's apply cannot come in (at 60 Hz it did). `-pal`/`-ntsc`, `-switch N` (CAPS + 1 before frame N, both restart), `-bot N`, `-seed N`, `-attract`.
- **Against the original** (`-oracle DIR`, `make check-original`): rr_oracle's runs (ram.bin, random.log, frames.csv) from the attract mode's start (frame 38 / 25), the original's input and its game logic's RANDOM values (reads on scanlines < 240; the VBI's are sound); after every frame the program's RAM through `Game::loadFromRam` + `diffWithRam` against the original's, with a display list made as the original's (the program keeps none), half-done snapshots (the original not waiting at AE99–AE9E) and reset frames not compared, and after a difference the original's RAM copied into the program's.
- **Profiling**: `NXHISTALL=file` (all frames' work), `NXHIST=file` (the frame after FRAMES), `NXPROF=addr,...`; `tools/prof.py build/test.sym file` per routine.

## Things learned the hard way
- sjasmplus: a `name = value` (DEFL) is a label and starts a new scope for local `.labels`; use local names or unroll. `PM_X << 8 | n` with a 16-bit address loses the page: write `high PM_X << 8 | n`. Out-of-range `jr` after growing code: `jp`.
- Xpeccy+ in non-firmware mode: palettes are all zero after reset, so the program sets every entry it uses; `comp_power_on` breaks the setup.
- At 60 Hz the core's picture has no top border rows before Layer 2 row 0 (at 50 Hz 24).
- The display list is not kept by the program: the river is drawn from Layer 2, the DLI's lines from the ring; only $3F04 (top line) and $3FB3 (the scrolling line's text) are kept, as the C++ port's state has them.
- Before trusting a check, make sure the assembly succeeded: a failed build leaves the old pages, and nxcheck runs those.
