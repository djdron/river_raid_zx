# Der Assembler-Quelltext des TS-Conf-Ports, Datei für Datei

[English](CODE.md) | [Русский](CODE.ru.md) | [Українська](CODE.uk.md) | Deutsch | [Polski](CODE.pl.md) | [Italiano](CODE.it.md) | [Español](CODE.es.md) | [中文](CODE.zh.md) | [日本語](CODE.ja.md)

Für Z80-Programmierer, die den Code des TS-Conf-Ports lesen oder schneller machen wollen. Das
Spiel selbst (seine Logik, der Flussgenerator, das Platzieren der Objekte und die Kollisionen)
ist der Code des Next, nach `src/` kopiert; [docs/CODE.de.md](../docs/CODE.de.md) beschreibt
diese Routinen, und dieses Dokument sagt nur, wie sie geändert wurden. Was TS-Conf eigen ist
(das Bild, die Uferfarbe pro Zeile, die Sprites, das Panel, der Ton auf einer General Sound, der
Start von einer SD-Karte), wird hier Routine für Routine beschrieben, mit seinen Kosten. Die
Übersicht steht in [README.de.md](README.de.md).

## Die beiden Maschinen nebeneinander

Dasselbe Spiel, zwei Arten, es zu zeigen. Was sich unterscheidet und wo es sich im Code zeigt:

| | ZX Spectrum Next | TS-Conf (ZX Evolution) |
|---|---|---|
| Prozessor | Z80N mit 28 MHz (3,5 / 7 / 14 / 28), Interrupts aus: das Frame durch Abfragen der Rasterzeile | Z80 mit 14 MHz (3,5 / 7 / 14), Cache an; der Frame-Interrupt, IM 2, von Ereignis zu Ereignis das Frame hinunter verschoben |
| Z80N-Befehle | `nextreg`, `mul`, `bsla de,b`, `outinb`… | keine: ein Register ist `ld bc,port / out (c),a`; `bsla de,b` eine Schleife (`shl_de_b`, display_hits.asm); `mul` nicht nötig (die Periode des AY per Additionen) |
| Speicher | 8K-Slots (MMU, NR $50–$57) | 16K-Fenster (PAGE0–PAGE3); Fenster 0 beschreibbares RAM (MEMCONFIG), also liegt das RAM des Atari bei $0000 |
| Der Fluss | Layer 2, 320×256, 8 Bit, spaltenweise: eine Zeile sind 320 Schreibzugriffe die Spalten hinunter, 10 Seiten der Reihe nach | 16 Farben, 320×240, eine Bildzeile 256 Byte (2 Punkte pro Byte): eine Zeile sind 160 Byte entlang der Zeile, eine Seite |
| Scrollen | NR $17, ein Ring von 256 Zeilen | GYOFFS, ein Ring von 512 Zeilen (`scroll` 9 Bit) |
| Die Uferfarbe pro Zeile | der Copper: eine Liste von WAIT/MOVE, gesendet, wenn sie sich ändert | eine Palette pro Uferfarbe (PALSEL 0–7, CRAM); der Frame-Interrupt setzt PALSEL eine Zeile vor einem Wechsel (`build_events`, `irq`) |
| Sprites | 128 Muster zu 16×16, 4 oder 8 Bit, Skalierung ×2 ×4; ein Objekt ist ein Sprite pro 16 Zeilen | ein Bildspeicher von 512×512 zu 4 Bit (SGPAGE), jede Größe bis 64×64, keine Skalierung: jedes Bild 16, 32 und 64 Punkte breit gehalten; ein Objekt ist ein Sprite |
| Farben | NR $41 usw., 9 Bit | CRAM über das FM-Fenster bei $E000 (`CRAM_SHADOW`): die Farben und die Liste der Sprites (SFILE) bei $E200 sind einfache Speicherzugriffe |
| Das Panel und die Laufschrift | die Tilemap über allem, ihr Y- und X-Scroll per Copper; die Laufschrift ein Ring aus Kacheln + ein Sprite an der Nahtstelle | ein eigenes Bild (256 Farben, Seiten 64–79), vom Frame-Interrupt ab Zeile 184 eingeschaltet (VPAGE, GYOFFS, VCONFIG mit GFXOVR), seine Zeichen einmal gezeichnet und vom DMA kopiert; die Laufschrift ein Ring aus 32 Zeichen über 512 Punkte, GXOFFS vom Interrupt gesetzt; Kachelebene 0 das Grau unter den Zeichen und das Schwarz über und unter dem Fluss |
| Ton | die Geräusche, die POKEY macht, in einen Ring, der zxnDMA zum DAC (`pokey_frame` auf dem Hauptprozessor, ~26 000–39 000 seiner 28-MHz-Takte pro Frame); reine Töne auf 3 AYs | der eigene Z80 einer General Sound spielt den ganzen POKEY (`gs/`); der Hauptprozessor sendet 8 Byte pro Frame (~3 400 mit dem Treiber). Ohne Karte: die reinen Töne auf den 2 AYs von TurboSound |
| Die Cartridge | esxDOS: River_Raid.rom aus dem Ordner des Programms | eigener Code für SD und FAT16/FAT32: die Karte wird durchsucht (Wild Commander gibt keinen Ordner) |
| TV | 50 oder 60 Hz (CAPS + 1) | nur 50 Hz: das Frame der Platine |
| Das Bild löschen | PUSH, zwei Seiten von Layer 2 pro Frame | die Füllung des DMA, ein halbes Bild pro Frame |
| Werkzeuge | `nxcheck` (Next-Kern), `NXHISTALL` + `tools/prof.py` | `tscheck` (TSConf-Kern), `TSHISTALL` + `../tools/prof.py` |

## Die Zahlen

Zeiten sind Takte des TSConf-Kerns bei 14 MHz (der Takt des Prozessors), ein Frame hat ~286 800.
Aus dem Histogramm von tscheck (`TSHISTALL=Datei`, dann `python3 ../tools/prof.py
build/test.sym Datei 60`, geteilt durch die Frames), auf dem Prüf-Build (`-DTEST`: mit dem
Bildschirmspeicher des Atari, den das Spiel nicht hat: `line_done` und `draw_line` sind ~1 000–
2 000 schwerer als im Spiel). Mit einer General Sound, also kosten die Geräusche den
Hauptprozessor nichts. Zwei Läufe:

- **A**: Bot 1, 3 000 Frames ab dem Start: die Arbeit im Mittel ~69 000 pro Frame, höchstens ~120 000;
- **B**: `-stress` ab Brücke 80, 6 000 Frames (`TSBRIDGE=80 TSGHOST=1 NXGAME=1 … -bot 1 -stress`: alle Slots belegt, Vollgas, Dauerfeuer): im Mittel ~108 000, höchstens ~144 000.

Die Arbeit reicht von `apply_done` bis `frame_done` (das Warten auf den Frame-Interrupt nicht
gezählt); die Teile unten zählen auch `apply` und die Interrupts (~7 000).

Nach Teilen (A / B):

| Teil | A | B |
|---|---|---|
| das Display: Platzieren der Objekte und Kollisionen (`display`, `ds_*`, `dh_*`, `sp_*`, `hit_*`) | 38 300 | 51 000 |
| neue Flusszeilen (`river_gen`, `render_line`, `span_line`, `line_done`, `push_line`) | 13 600 | 32 200 |
| Sprites und die Ereignisse des Ufers (`build_sprites`, `ob_*`, `pl_*`, `obj_lookup`, `sfile_put`, `build_events`, `pal_get`) | 10 300 | 14 900 |
| `apply`, das Panel und die Interrupts (`apply`, `panel_frame`, `panel_draw`, `pc_*`, `pal_edges`, `irq`, das Drucken des Panels) | 7 900 | 7 500 |
| Ton (`sound_driver`, `snd_*`, `gs_*`; ohne Karte `ay_*`: ~5 800 in A) | 3 400 | 3 500 |
| die Spiellogik und der Rest (`move_objects`, `main_loop`, `random_step`, `vbi`, …) | 7 000 | 8 800 |

Die teuersten Routinen (A / B):

| Routine | A | B | Datei |
|---|---|---|---|
| `display` (eigener Code) | 11 200 | 12 900 | display_simple |
| `dh_pf` | 8 700 | 9 800 | display_hits |
| `span_line` | 3 900 | 9 500 | spans |
| `ds_edge_test` | 2 800 | 8 700 | display_simple |
| `render_line` | 3 500 | 8 400 | render |
| `ds_obj` | 5 300 | 6 200 | display_objs |
| `dh_obj` | 4 400 | 5 500 | display_hits |
| `ob_attr` | 2 500 | 5 100 | sprites |
| `move_objects` | 1 700 | 3 300 | game |
| `dl_fill` | 1 500 | 3 300 | river_gen |
| `ob_list` | 2 400 | 3 200 | sprites |
| `line_done` (die Kopie in den Bildschirmspeicher, nur Prüf-Build) | 1 100 | 2 500 | game |
| `gs_send` + `gs_wait_c` + `gs_wait_d` | 2 400 | 2 300 | sound_gs |
| `pl_keep` | 800 | 1 600 | sprites |
| `panel_frame` | 1 600 | 1 600 | panel_ts |
| `irq` | 1 400 | 1 400 | river_raid |
| `dh_lists` | 1 300 | 1 300 | display_hits |
| `sfile_put` | 1 200 | 1 300 | river_raid |
| `apply` (eigener Code) | 1 200 | 1 200 | river_raid |
| `pal_edges` | 1 100 | 1 100 | river_raid |
| `build_events` | 1 000 | 1 000 | river_raid |
| `hit_setup` | 500 | 700 | display_hits |

Bei 7 MHz (`TSSPEED=1`, ~143 400 Takte pro Frame) ist die Arbeit dieselben Befehle: `-stress`
im Mittel ~93 000, höchstens ~125 000, es passt gerade noch; bei 3,5 MHz kommt es nicht mit.
`gs_send` wartet, bis die Karte jedes Byte gelesen hat (~300 Takte pro Byte bei 14 MHz).

(`prof.py` nimmt den Namen einer Routine vom nächsten globalen Label unterhalb der Adresse.
Adressen unter $4000 sind die Arbeit des Starts in INIT_PAGE: weglassen.)

## Speicher, während der Code läuft

16K-Fenster und die Seiten darin (die 16K-Seiten der Platine):

| Fenster | Adresse | normalerweise | umgemappt von |
|---|---|---|---|
| 0 | $0000–$3FFF | 1 (`ATARI_PAGE`): das RAM des Atari an den Adressen des Originals | beim Start: 3 (`INIT_PAGE`: dort laufen `sprite_pics.asm`, `gs_load.asm`, `load_rom.asm`) |
| 1 | $4000–$7FFF | 5 (`WORK_PAGE`): die Läufe der Zeilen ab $4000 (`SPANS`, 32 Byte × 256 Zeilen), Puffer ab $6000 (`scan_*`, `edge_runs`, `ring_*`, `ds_objs`, `ov_exp2/4`, `eg_*`, `bg_*`, `line_*`, `edge_lo/hi`, `rnd_tab`), die OS-Schrift bei $7D00 | `render_line`: eine Seite des Flussbilds (32–47); `panel_draw`/`pc_*`: das Bild des Panels (64–79); beim Start die Kachelkarte (7), die Kacheln (8), die Bilder der Sprites (24–31); immer zurück auf 5 |
| 2 | $8000–$BFFF | 2 (`CODE_PAGE`): Code bis ~$9FE1, die Cartridge ab $A000 | — |
| 3 | $C000–$FFFF | 6 (`HIGH_PAGE`): Code bis ~$D75A, dann bei $E000 das FM-Fenster (`CRAM_SHADOW`: CRAM $E000–$E1FF, das SFILE $E200–$E3FF; die Schreibzugriffe gehen auch ins RAM darunter), Tabellen und Variablen bis ~$FD65, der Stack, die IM-2-Vektoren bei $FE00 | — |

Die Bilder: der Fluss ab Seite 32 (`VID_PAGE`, 16 Seiten: 512 Zeilen zu 512 Byte, von jeder 320
Punkte gezeigt), das Panel ab Seite 64 (`VPANEL`), die Kachelkarte in Seite 7, die Punkte der
Kacheln in Seite 8, die 512×512 Punkte der Sprites in Seiten 24–31 (`SGPAGE`). Der Code von
INIT_PAGE endet bei ~$11DF, die Puffer der Arbeitsseite bei $7C00. Das FM-Fenster ist dauerhaft
an: Nichts anderes darf $E000–$E3FF benutzen, und $E400–$E4FF sind seine Register (`palette_lo`
liegt dort, nur gelesen).

## Das Frame

`main_frame` (river_raid.asm), jedes Frame:

1. Hält fest, was das Bild dieses Frames zeigt (`scroll`, die Farben von Kante und Wasser, den Spieler), `read_input`.
2. Normalerweise: `prepare` → `display` → `build_sprites` → `build_events` → `main_loop` → `vbi` → `snd_frame`. Während eines Resets (`busy`): `display` → `build_sprites` → `build_events` → `clear_layer2_page` → (`finish_reset` im letzten) → `vbi` → `snd_frame`.
3. `wait_frame`: HALT, bis der Frame-Interrupt gekommen ist (`frame_flag`), bei `FRAME_LINE`, unter dem Panel.
4. `apply`: Alles Gebaute wird wirksam (der Scroll, der Ton, die Farben, das SFILE, die Palette des Ufers oben und die Ereignisse des Interrupts für das kommende Frame).
5. `panel_draw`: die Zeichen des Panels, die sich geändert haben, und die neuen der Laufschrift in sein Bild (nach `apply`: Es kann eine Weile dauern, und das Panel ist erst ab Zeile 184 zu sehen).

Während das Bild gezeichnet wird, kommt der Interrupt bei jedem Ereignis der Liste, die `apply`
gestellt hat: EV_PAL (die Palette des Flusses ab der nächsten Zeile), EV_PANEL (das Bild des
Panels ab Zeile 184), EV_GX (das X der Laufschrift), dann der des Frames. Jeder kommt am rechten
Rand der Zeile davor (HSINT = 208), und PALSEL, VPAGE, GYOFFS werden am Ende einer Zeile
übernommen, also ist ein Wechsel bei jedem Prozessortakt exakt, wo immer die Arbeit gerade ist.

---

## Die Dateien des Next, wie sie hier sind

Aus `../src` kopiert, derselbe Code:

- `river_gen.asm`, `display_objs.asm`, `panel.asm`, `vars.inc`, `font.inc`, `random.inc`: unverändert.
- `display.asm`, `display_simple.asm`, `spans.asm`: Die Seite SPANS wird nicht gemappt (`nextreg $52,SPAN_PAGE` weg: Fenster 1 hält SPANS die ganze Zeit); `spans.asm` ohne `rl_fill`/`rl_next` (die Helfer von `render_line` beim Next).
- `display_hits.asm`: `bsla de,b` (Z80N) als `shl_de_b`, eine Schleife aus 0–7 `sla e / rl d` (in `hit_line`: bis zu ~100 Takte mehr pro Test, ein paar hundert pro Frame).
- `game.asm`: `tm_colour` schreibt BORDER (einen CRAM-Eintrag: `TM_*` sind die freien Einträge der Gruppe 11 ab 2, ihre Farben setzt `tm_cram`), und `TM_COLOUR` ruft es nur bei eingeschaltetem T; `push_line` bewegt `scroll` in einem Ring von 512 Zeilen (9 Bit) und zeichnet in die Bildzeile `scroll + RIVER_TOP`.
- `play.asm`: `clear_layer2_page` ist das von TS-Conf (river_raid.asm, der DMA); `read_input` ohne CAPS + 1 (keine 60 Hz), CAPS + 2 (Ton aus), CAPS + 3 (Takt), den zweiten Kempston und das Mega-Drive-Pad.
- `sound.asm`: nur `sound_driver` und `sound_random`: `pokey_frame` läuft auf der General Sound (`gs/`).
- `render.asm`, `sprites.asm`, `sound_ay.asm`, `load_rom.asm`, `river_raid.asm`: die von TS-Conf (unten), mit den Namen des Next, wo sie dieselbe Aufgabe haben.

Die Routinen der ersten drei Gruppen beschreibt [docs/CODE.de.md](../docs/CODE.de.md); ihre Kosten
hier stehen in der Tabelle oben.

## river_raid.asm: das Frame, der Start, der Interrupt, die Farben

Die oberste Datei: die Ports der Platine, Speicher, die Seiten, `include`s, das Frame, der
Interrupt, `apply`, die Paletten des Flusses, Variablen und Puffer.

| Routine | aufgerufen | was und wie | A / B |
|---|---|---|---|
| `start` | beim Laden | 14 MHz und der Cache (SYSCONFIG $06), Fenster 0 RAM (MEMCONFIG $0E), die Seiten, `screen_black`, `load_rom` (SPG-Builds), `init_tables`, `init_video`, die Bilder der Sprites (`obj_pics`, `pl_pics`, `panel_pics`), `gs_load`, dann das RAM des Atari in Fenster 0, `panel_init`, `ay_quiet`, die Saat von RANDOM, IM 2 (Vektoren bei $FE00), `restart`. | einmal |
| `restart` | `start` | `tv_setup`, das Bild gelöscht (beide Hälften per DMA, abgewartet), der Frame-Interrupt bei `FRAME_LINE`, `start_attract`, das Panel ganz gezeichnet, fällt in `main_frame`. | einmal |
| `main_frame` | jedes Frame | Siehe *Das Frame*. | 340 / 340 |
| `wait_frame` | `main_frame` | HALT bis `frame_flag`: Leerlauf, keine Arbeit. | — |
| `irq` | der Interrupt | Das Ereignis bei `ev_ptr`: EV_PAL PALSEL; EV_PANEL VPAGE = `VPANEL`, GYOFFS = 0, VCONFIG $8A (256 Farben, das Bitmap über Kacheln und Sprites); EV_GX GXOFFS; der des Frames (EV_END) `frame_flag`. Ereignisse auf derselben Zeile zusammen erledigt; dann VSINT auf die Zeile des nächsten gesetzt (`vsint_set`) oder auf die des Frames. | 1 400 / 1 400 |
| `vsint_set` | `irq`, `apply`, `restart` | VSINT = HL (9 Bit), in `ev_line` behalten. | 340 / 330 |
| `apply` | nach `wait_frame` | GYOFFS = `show_scroll`, VPAGE die des Flusses, VCONFIG $81 (16 Farben), GXOFFS 0; `snd_out` (die Register des AY oder das Frame der Karte); `panel_frame`; die Farben von Granate und Flugzeug ins CRAM; `sfile_put`; während das Bild nach einem Reset gelöscht wird (ab dessen zweitem Frame): der Fluss schwarz (Palette der Farbe 0, Kante und Wasser 0, nur die Ereignisse des Panels); sonst PALSEL die Palette oben (`ev_built`), `pal_edges`, die Ereignisse des Panels nach denen des Ufers kopiert (`ev_tail`); der Interrupt auf das erste Ereignis gestellt (DI darum herum); `ev_show` = die eben gestellte Liste (`build_events` schreibt die andere). | 1 200 / 1 200 |
| `pal_get` | `build_events`, `apply` | Die Palette des Flusses (PALSEL 0–7) für Atari-Farbe E: Jede Uferfarbe hat ihre eigene, gemacht, wenn sie zum ersten Mal vorkommt (`pal_of`, `pal_n`): ihre Farbe 1 diese Farbe, im CRAM. Über 8 wieder die letzte (nie vorgekommen). | 110 / 110 |
| `pal_edges` | `apply` | Die Farben 2 und 3 (Kante, Wasser) aller bisher gemachten Paletten. | 1 100 / 1 100 |
| `sfile_put` | `apply` | Das SFILE, in `spr_list` gebaut: die Sprites des Flusses (S0), dahinter `sf_tail` kopiert (ein End-Eintrag mit LEAP, die 3 des Panels: Nadel und Logo, S1, ein Ende); die Einträge danach bis zum Ende des vorigen Frames (`sf_end`) dort gelöscht; dann kopiert es der DMA ins SFILE (DMACTRL $85, RAM ins SFILE, ein Burst; die CPU programmiert ihn nur). Solange der DMA belegt ist (das Löschen beim Reset), kopiert die CPU über das FM-Fenster bei $E200. | 1 200 / 1 300 |
| `build_events` | `main_frame` | Die Uferfarbe pro Zeile, wie `build_copper` des Next aus `ds_bank_ev`: in den Puffer, den die Interrupts nicht lesen (`ev_a`/`ev_b`), die Palette an der Oberkante des Flusses, dann ein EV_PAL-Ereignis für jeden Wechsel, 5 Byte (Art, Palette, Farbe für die Prüfung, VSINT-Zeile eine Zeile davor); `ev_tail`, wohin `apply` die zwei des Panels legt. | 1 000 / 1 000 |
| `clear_layer2_page` | `main_frame` während `busy`, `restart` | Ein halbes Flussbild (256 Zeilen × 160 Byte, 4 Seiten) pro Frame per DMA-Füllung (DMACTRL $14, 80 Wörter × 256 Zeilen aus `dma_zero`); keines im ersten Frame des Resets (`l2_wait`); nichts, solange der DMA beschäftigt ist. Der Prozessor programmiert ihn nur (~150 Takte). | |
| `dma_wait` | `restart`, `init_video` | Bis der DMA frei ist (DMACTRL Bit 7). | |
| `init_tables` | `start` | Wie beim Next (`edge_runs_init`, `ov_exp2/4`, `ring_*`, `span_class`, `edge_lo/hi`, `span_init`), `pix_tab` mit dem Index in beiden Nibbles (die 2 Punkte pro Byte des 16-Farben-Modus). | einmal |
| `init_video` | `start` | Der Modus des Flusses (VPAGE 32, VCONFIG $81, PALSEL 0); die Kachelkarte (Seite 7: Zeilen 0–23 Kachel 1 schwarz, 184 Kachel 3 eine schwarze Linie über Grau, 185–223 Kachel 2 grau, 224–239 schwarz; die Zeilen des Flusses keine) und die Punkte der Kacheln (Seite 8); die 128K der Sprites per DMA gelöscht; TSCONFIG $A0 (Kachelebene 0 und Sprites an); das FM-Fenster dauerhaft an, CRAM und SFILE genullt; die Farbe des Panzers; HSINT, nur der Frame-Interrupt (INTMASK 1). | einmal |
| `screen_black` | als Erstes in `start` | TSCONFIG 0, BORDER 0, das ganze 1K von CRAM und SFILE über das FM-Fenster genullt: schwarz, welchen Modus Wild Commander auch hinterlassen hat (sein ZX-Bildschirm in Seite 5 ist dort, wohin die Puffer des Starts gehen). | einmal |
| `tv_setup` | `restart` | Nur PAL: `init_line_tables`, die PAL-Spalten von RANDOM, `rnd_tables`. | |
| `test_ghost` | Test-Builds | TSGHOST von tscheck, wie beim Next. | |

`span_rec` (HL = der Datensatz einer Zeile in SPANS) ist dasselbe Makro wie beim Next, bei $4000.

## render.asm: eine Zeile ins Bild

| Routine | aufgerufen | was und wie | A / B |
|---|---|---|---|
| `render_line` | `line_done` | Die Farbtakte 20–179 der Zeile in die Bildzeile HL (0–511): Seite `VID_PAGE` + Zeile / 64 in Fenster 1, die Zeile bei $4000 + (Zeile & 63) × 256; aus den Stücken von `dl_seg` wie beim Next: ein Stück eines Werts ist sein `pix_tab`-Byte 4-mal pro Byte (`.fill`: `ld (hl),a / inc l`), die Bytes einer Kante (die Tabelle des ROM) und eine Zeile einer Dekoration über `pix_tab`, je 4 Ausgabebytes. 160 Schreibzugriffe pro Zeile entlang der Zeile (der Next schreibt 320 die Spalten hinunter, 10 Seiten). Am Ende WORK_PAGE zurück. Ein Stück eines Werts ab 5 Bytes (`RL_DMA_MIN`) geht stattdessen an den DMA, wenn er frei ist: eine Füllung (DMACTRL $04) aus `rl_word` (der Wert zweimal) in die Seite `rl_page`. In Seite $C000 (aus Platzgründen aus $8000 verschoben). | 3 500 / 8 400 |

## sprites.asm: die Sprites des Flusses

Die Sprites von TS-Conf haben keine Skalierung, also wird jedes Bild 16, 32 und 64 Punkte breit
gehalten (ein Atari-Pixel sind 2 Punkte; ein Player 8 Pixel bei Größe ×1, ×2, ×4). Ein Objekt ist
ein einziges Sprite bis 24 Zeilen (der Next macht eines pro 16 Zeilen). Paletten: Objekte 14 und
15 (`OBJ_PAL_A`, `OBJ_PAL_B`, die Zeilenfarben an den Plätzen 1–15), Granate und Rakete 8, Panzer
9, Flugzeug und Kugel 10. Die Einträge (je 6 Byte, das Format des SFILE: Y mit YS und ACT, X mit
XS und den Spiegelbits, die Kachel und die Palette) gehen in `spr_list`; `apply` kopiert sie.

| Routine | aufgerufen | was und wie | A / B |
|---|---|---|---|
| `build_sprites` | `main_frame` | `ob_list`; dann das Flugzeug, seine Kugel, der Panzer, die Rakete des Hubschraubers, die Granate (die Reihenfolge, in der `drawRiver` sie zeichnet) über `pl_pattern` + `pl_sprite`; `pl_keep`. Während eines Resets `pl_again`. | 800 / 800 |
| `ob_list` | `build_sprites` | Pro Eintrag von `ds_objs` mit seinen Zeilen (`ds_objf`): `obj_lookup` über die Adressen von Form und Farbe der obersten Zeile; nicht gefunden: kein Sprite; erste Zeile unter dem Fluss: keines; sonst `ob_attr`. | 2 400 / 3 100 |
| `obj_lookup` | `ob_list` | Das Bild mit dem Formbyte bei $B900 + E und dem Farbbyte bei $B700 + D: `obj_head` (nach dem Formbyte), dann seine Kette in `obj_e`; A = Bild + Bit 7 für `OBJ_PAL_B`. | 1 000 / 1 300 |
| `ob_attr` | `ob_list` | Der SFILE-Eintrag: Y = `RIVER_TOP` + der Platz seiner Zeile im Fluss (9 Bit) mit YS aus `pic_h` und ACT; X = 2 × (Position − 52) (9 Bit) mit XS 1, 3 oder 7 nach seiner Größe; die Kachel der richtigen Breite (`pic_tn16/32/64_lo/hi`), die Palette. | 2 500 / 5 200 |
| `pl_pattern`, `pl_sprite` | `build_sprites` | Das Bild des Frames aus seiner Tabelle ($FF: keines); ein 16 Punkte breites Sprite auf Zeile D (keines unter dem Fluss), Position E, Palette C. | ~100 pro Sprite |
| `pl_keep`, `pl_again` | `build_sprites` | Die Einträge der Player behalten; die Frames eines Resets zeigen sie wieder (wie beim Next). | 800 / 1 600 |
| `cram_set` | der Start, `init_video` | CRAM-Eintrag A × 16 + B = Atari-Farbe E (`palette_lo`). | |

## sprite_pics.asm (INIT_PAGE, beim Start): die Bilder der Sprites

In den Bildspeicher von 512×512 Punkten (SGPAGE, 4 Bit pro Punkt, eine Zeile 256 Byte) über
Fenster 1; die Kacheln eines Bilds sind 8×8, nummeriert (Zeile / 8) × 64 + x / 8.

| Routine | aufgerufen | was und wie |
|---|---|---|
| `gfx_alloc` | `pic_set`, `pl_pics`, `panel_pics` | Ein Platz für ein Bild von BC Punkten Breite, A Zeilen (ein Vielfaches von 8): entlang der Zeilen, solange sie es fassen, dann auf den nächsten Zeilen (`gfx_cx`, `gfx_cy`, `gfx_rh`). |
| `gfx_tile` | | Die Kachelnummer eines Punkts. |
| `gfx_row` | | Zeile C eines Bilds: die Punkte von Byte D (Bit 7 zuerst) in Farbe E in den drei Breiten (2, 4, 8 Punkte pro Bit), oder nur der ersten (B 1). |
| `obj_pics` | `start` | Wie `obj_pics` des Next: für Typen 7–15 die Arten, die sie haben können (ihre eigene, die von `ROM_NEXT_KIND` unter $0C, die der Explosion), jede auch gespiegelt, height + 1 Zeilen, wie der DLI sie zeichnet; jedes Bild einmal (nach seinen Adressen) in den drei Breiten; der Wert eines Punkts der Platz der Farbe seiner Zeile in Palette 14 oder 15 (bei Neuem gesetzt: `cram_set`); `obj_head`/`obj_e` für `obj_lookup`. |
| `pic_set` | `obj_pics` | Die drei Kacheln von Bild `op_p` (bei gfx_x, + 16, + 48) und sein YS. |
| `pl_pics` | `start` | Die 10 Frames des Flugzeugs, die 8 des Panzers, die 7 der Granate (aus ihren Zeigertabellen im ROM, wie `prepare` sie kopiert), die Kugel und die Rakete des Hubschraubers: 16 Punkte breit, Farbe 1; ein Bild pro Adresse, $FF für ein leeres Frame. |
| `panel_pics` | `start` | Die Nadel (Missile 1: 2 Farbtakte, 10 Zeilen) und das Logo: Player 3 mit 64 Punkten (Daten $FC), Player 2 (Daten $FF) jede Zeile einen Takt weiter links (7 Zeilen in 32 Punkten). |

## panel_ts.asm: das Panel und die Laufschrift

Das Panel ist ein eigenes Bild (Seiten 64–79, 256 Farben, 512 Byte pro Zeile), ab
Bildschirmzeile 184 gezeigt (EV_PANEL des Frame-Interrupts) mit dem Bitmap über Kacheln und
Sprites (GFXOVR): Seine Punkte mit 0 sind Löcher, die Kachelebene 0 (das Grau, Schwarz) und die
Sprites des Panels zeigen. Farben 4–7 PF0–PF3 des Panels, 8 die der Laufschrift. Die Laufschrift
ist ein Ring aus 32 Zeichen über die 512 Punkte des Bilds, ab GXOFFS gezeigt (EV_GX an ihrer
ersten Zeile).

| Routine | aufgerufen | was und wie | A / B |
|---|---|---|---|
| `panel_init` | `start` | Die zwei Zeichensätze des Atari in sein RAM, wo das Spiel sie baut (A0FB–A143: der der Laufschrift bei $0600, der des Panels bei $0800); die Farben (CRAM: die der Zeichen als Einträge 4–8 von Palette 0, die der Nadel, die Zeilen des Logos ab $B48D, Schwarz und Grau der Kacheln als Einträge 14 und 15 von Palette 3: eine Palette des Flusses nutzt nur die Einträge 0–3); die Zeichen einmal gezeichnet (`GLYPHS`: die der Laufschrift, die des Panels in seinen 4 Farben), damit `pc_put` sie kopiert; das Bild des Panels gelöscht; alles zum Schreiben im ersten Frame markiert. | einmal |
| `panel_frame` | `apply` | Das X der Laufschrift (`pf_gx` = 16 TEXT_LO + 38 − 2 FINE_SCROLL, 9 Bit) für EV_GX des Interrupts; die Nadel (Missile 1 bei fuel / 8 + $5C) und die zwei Sprites des Logos in `spr_s1` (`.spr`). | 1 600 / 1 600 |
| `panel_draw` | nach `apply` | Die Zeichen, die `panel_put` aufgelistet hat (`pf_dirty`, alle 60 nach einer Kopie), über `panel_frame.char`; die Laufschrift: wenn TEXT_LO um eins weiterging, ihr Zeichen 24 weiter; wenn es sprang, alle 25 (`panel_frame.text`: Zeichen t am Punkt 16 t mod 512 des Rings). | 160 / 160 (+ `pc_*`) |
| `pc_put` | `.char`, `.text` | Ein Zeichen per DMA von dort kopiert, wo es einmal gezeichnet wurde (`pc_bank`), in das Bild des Panels bei Zeile E, Punkt HL; solange der DMA beschäftigt ist (das Löschen eines Resets), von `pc_draw` gezeichnet. | |
| `pc_draw` | `pc_put`, `panel_init` | Die 8 Zeilen eines Zeichens gezeichnet: gesetzte Punkte in Farbe B, die anderen 0 (Löcher); Punkte links von 0 nicht gezeichnet. | 700 in A |
| `pc_bank`, `pc_adr`, `pc_reg` | | Wo eine Glyphe gezeichnet wurde; Seite und Adresse einer Zeile; eine DMA-Adresse in seine Register. | |

## sound.asm, sound_gs.asm, gs_load.asm und gs/: der Ton auf einer General Sound

`pokey_frame` des Next (seine Samples, die Impulse, der 17-Bit-Zähler) läuft auf dem eigenen Z80
der Karte mit 12 MHz; der Hauptprozessor sendet einmal pro Frame POKEYs Register.

| Routine | aufgerufen | was und wie | A / B |
|---|---|---|---|
| `sound_driver` | `vbi` | Der Treiber des Originals (wie beim Next). | 840 / 1 000 |
| `snd_frame` | `main_frame` | Mit Karte nichts; sonst `ay_frame`. | |
| `snd_out` | `apply` | Mit Karte `gs_send`; sonst `ay_out`. | |
| `gs_send` | `snd_out` | Kommando `GS_FRAME` ($A5) an Port $BB, dann AUDF1–4 und AUDC1–4 an $B3, jedes, sobald die Karte das vorige gelesen hat (`gs_wait_c`: Bit 0 von $BB gelöscht; `gs_wait_d`: Bit 7). Eine Zeitüberschreitung (~0,2 s): Die Karte wird fallen gelassen (`gs_on` 0), ab dann der AY. Die meiste Zeit ist Warten auf die Karte. | 2 400 / 2 400 |
| `gs_load` | `start` (INIT_PAGE) | Kommando $F0 (der Status der Firmware): keine Antwort, keine Karte; `GS_READY` ($5A) das Programm ist von einem früheren Lauf da, damit weiter. Sonst über die Firmware: #12 Seite 2 bei $8000, #18 die Adresse, #19/#1B die Bytes des Programms (`gs_prog`: `build/gs_pokey.bin` per incbin), #13 ein Sprung nach `GS_ORG` ($8400), dann auf `GS_READY` warten (das Programm macht zuerst seine Tabellen). `gs_on` = 1. | einmal |

Das Programm der Karte, `gs/gs_pokey.asm` (getrennt zu `build/gs_pokey.bin` gebaut):

| Routine | was und wie |
|---|---|
| `gs_start` | IM 2 (alle Vektoren auf `INT_AT` $4141, der Handler dorthin kopiert), die Variablen gelöscht, $6000–$63FF jedes Byte sein eigener Wert (ein Lesezugriff bei $6000 + 256 (n − 1) + v übernimmt v in DAC n), alle vier Lautstärken auf 63; `poly_make`, `tables_make`, der Ring still, `GS_READY` hinaus. |
| `main` | Wartet auf ein Kommando: $F4 (`GS_RESET`) DI, IM 1, JP 0 (wieder die Firmware); $F0 (`GS_STATE`) `GS_READY` zurück; jedes andere die 8 Datenbytes in `pokey_audf`/`pokey_audc`, dann `pokey_frame`. |
| `gs_int` | Der Interrupt der Karte, 37 500 pro Sekunde: ein DDA (`DDA_STEP` 108 von 256) nimmt 15 820-mal pro Sekunde ein Sample aus dem Ring und übernimmt es in alle vier DACs (`ld a,(hl)` ab $6000, $6100, $6200, $6300 + Pegel): 1 und 2 links, 3 und 4 rechts, jede Seite die Summe ihrer zwei. |
| `poly_make` | Die Bits des 17-Bit-Zählers von POKEY in $C000–$FFFF (16K), aus der Rekursion q(k) = q(k−9) ^ q(k−11) ^ q(k−12) ^ q(k−17) und ihren Startwerten; der Next liest sie aus `poly17.bin` (kein Platz für 16K im Programm der Karte). |
| `tables_make` | `snd_tables`, `snd_mod15/31`, `g4_tab` (wie `sound_init7` des Next). |
| `pokey_frame`, `snd_fill`, `snd_sum` | Die des Next, ohne den AY, den zxnDMA und die Zeitgrenze, und mit 4 pro Lautstärkestufe, nicht 8: Alle vier Kanäle sind hier (beim Next nehmen die AYs die Töne), bis 60 × 4 = 240; bei 8 liefen sie über 255, wenn Explosionen zusammenkamen (ein Zischen), und die zwei DACs pro Seite machen es ebenso laut. Außerdem: die Samples vor der Stelle des Interrupts (`rp`) bis `SND_LEAD`, höchstens `SND_CAP`, danach der letzte Pegel gehalten (`SND_HOLD`). |
| `gs_pulses.asm`, `gs_handlers.asm` | `sound_pulses.asm`, `sound_handlers.asm` des Next: Der Zeiger des 17-Bit-Zählers läuft bei $C0 um (seine 16K bei $C000), und kein `mul`. |

Ihr Speicher: $4000 die Vektoren, $4141 der Handler, ab $4200 die Variablen, `snd_tables` bei
$4300, `snd_mod15/31` bei $4400/$4500, `g4_tab` endet bei $4800, der Stack unter $6000; Seite 2
bei $8000: der Ring $8000–$83FF, das Programm ab $8400; $C000 die Bits des 17-Bit-Zählers.

## sound_ay.asm: die reinen Töne ohne Karte

| Routine | aufgerufen | was und wie | A |
|---|---|---|---|
| `ay_frame` | `snd_frame` | Wie beim Next: Die POKEY-Kanäle, die einen reinen Ton spielen, je auf einen AY-Kanal (1 A des zweiten Chips, 2 dessen B, 3 B des ersten, 4 dessen C), N = (AUDF + 1) × 3,454 per Additionen (`3a + round(a × 116 / 256)`, kein `mul`), die Lautstärke über `ay_vol`; in `ay_regs`. Nicht 2 Frames verzögert: Ohne DAC, mit dem Schritt zu halten wäre, gibt `apply` die dieses Frames aus. | 1 100 |
| `ay_out` | `snd_out` | Die Register 0–10 der zwei Chips (Port $FFFD wählt Chip und Register, $BFFD der Wert). | 2 100 (+ 600 `ay_clear`) |
| `ay_quiet` | `start` | Alles still. | |

## load_rom.asm (INIT_PAGE, SPG-Builds): die Cartridge von der SD-Karte

Wild Commander startet die .spg ohne Ordner und ohne DOS, also liest das Programm die Karte selbst
über den Z-Controller (Port $77 Bit 1 sein /CS, Port $57 ein Byte in jede Richtung). Der
Sektorpuffer ist SPANS (nach dem Start neu gemacht).

| Routine | was und wie |
|---|---|
| `load_rom` | `sd_init`, die erste Partition des MBR (oder die Karte selbst ohne Partitionstabelle: `lr_bpb`), die Werte des FAT-Volumes, `lr_search` ab der Wurzel; die Cluster der Datei nach $A000 gelesen (8192 Byte). Ohne sie `lr_fail`: CRAM-Eintrag 1 rot und BORDER 1, dann ein Halt. |
| `sd_init`, `sd_cmd`, `sd_read` | SPI-Modus (CMD0, CMD8, CMD55 + ACMD41, CMD58: SDHC-Blockadressen, sonst CMD16 512 und Byteadressen, `lr_hc`), ein Sektor von 512 Byte. |
| `lr_bpb` | Ein Bootsektor: FAT16 oder FAT32, Sektoren pro Cluster, die Adressen von FAT, Wurzel und Daten. |
| `lr_search`, `lr_get`, `lr_advance`, `lr_rewind` | Die Einträge eines Ordners der Reihe nach (die feste Wurzel von FAT16 oder eine Clusterkette); zuerst die Dateien, dann die Ordner, in die Tiefe, 8 tief (`lr_save`/`lr_restore` legen den Durchlauf beiseite). |
| `lr_lfn`, `lr_name`, `lr_upper` | Der lange Name aus seinen LFN-Einträgen (je 13 Zeichen), mit RIVER_RAID.ROM in beliebiger Schreibung verglichen; sonst der Kurzname RIVER_~1.ROM. |
| `lr_next`, `lr_clus_lba` | Die Clusterkette aus der FAT (16 oder 32 Bit); der erste Sektor eines Clusters. |

## Includes und Werkzeuge

- `palette_ts.inc`: Atari-Farbe → CRAM-Wort (5 Bit pro Komponente, Stufen 0–24), die PAL-Farben des C++-Ports (`make palette`: `tools/mkpalette_ts`).
- `vars.inc`, `font.inc`, `random.inc`: die des Next.
- `gs/poly.inc`: POKEYs 4- und 5-Bit-Folgen (`tools/mkpoly`).
- `tools/mkspg.py`: die SPG-1.0-Datei aus den Seiten (`spg_page2/6/5/3.bin`): $8000–$9FFF, $C000–$FFFF, die Schrift, der Code von INIT_PAGE.
- `tools/tscheck.cpp`: der TSConf-Kern von Xpeccy+ (und seine General Sound) neben dem C++-Port, jedes Frame.

## Was man wissen sollte, bevor man Code ändert

- **Der gemeinsame Code**: Eine Änderung am Spiel (Logik, Generator, Display, Kollisionen) geht zuerst in den C++-Port, dann nach `src/` des Next, dann in die Kopie hier (`diff ../src/X.asm src/X.asm` zeigt nur die oben aufgezählten Änderungen). Eine Änderung daran, wie TS-Conf es zeigt, bleibt hier.
- **Fenster 1** ist WORK_PAGE, außer während `render_line`, `panel_draw` oder der Start dort eine andere Seite mappen; jede stellt WORK_PAGE zurück (SPANS und die Puffer liegen dort).
- **Das FM-Fenster** bei $E000 ist die ganze Zeit an: Schreibzugriffe auf $E000–$E3FF gehen in CRAM und SFILE (und ins RAM darunter, so liest `apply` sie zurück); nie etwas anderes dorthin legen.
- **Die Ereignisse des Interrupts** sind doppelt gepuffert (`ev_a`, `ev_b`): `build_events` schreibt den, den `ev_show` nicht nennt; `apply` stellt ihn unter DI.
- **Register, die am Zeilenende übernommen werden** (PALSEL, VPAGE, GYOFFS, GXOFFS): im Interrupt der Zeile davor setzen; der Interrupt kommt bei HSINT 208 (der rechte Rand), also ist bei 3,5–14 MHz Zeit.
- **Der DMA** wird vom Löschen des Bilds (`clear_layer2_page`) und von den Zeichen des Panels (`pc_put`) geteilt: `pc_put` zeichnet per Prozessor, solange der DMA beschäftigt ist; auch die SFILE-Kopie (`sfile_put`) und die langen Läufe einer neuen Zeile (`render_line`) nutzen ihn, jedes mit dem Prozessor als Ersatz, solange er beschäftigt ist.
- **Die Prüfungen**: `make check` (3 000 Frames; `FRAMES=`), und mit einem Bot, `-stress`, TSBRIDGE, TSSPEED=1 (7 MHz), TSGS=neo oder 0, wie in [README.de.md](README.de.md). Nach jeder Änderung: der Zustand, die Uferfarbe pro Zeile (`ev_built`), die Register der General Sound und das Bild der Maschine jedes Frames Pixel für Pixel.
- **Messen**: `TSHISTALL=Datei` (die Zeit jedes Befehls über den Lauf, Start, Interrupts und Warten eingeschlossen), dann `python3 ../tools/prof.py build/test.sym Datei 60`; Mittel und Maximum der Arbeit stehen in den letzten Zeilen von tscheck. `TSBORDER=1` schaltet T ein; `TSSHOT=k` mit `TSFULL=1` schreibt die Frames ab k mit Rand (das letzte Bild eines Laufs zeigt am Rand nur eine Farbe: der Lauf hält bei `apply_done`). `TSTIME=N` druckt die Arbeit der Frames N−2..N+2. `TSVOL=1`: die Summen der POKEY-Lautstärken der Frames und der höchste Pegel der Karte (er muss höchstens 255 bleiben).
