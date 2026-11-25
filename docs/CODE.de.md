# Der Assembler-Quelltext des Ports für den ZX Spectrum Next, Datei für Datei

[English](CODE.md) | [Русский](CODE.ru.md) | [Українська](CODE.uk.md) | Deutsch | [Polski](CODE.pl.md) | [Italiano](CODE.it.md) | [Español](CODE.es.md) | [中文](CODE.zh.md) | [日本語](CODE.ja.md)

Für Z80-Programmierer, die den Code lesen oder schneller machen wollen. Zu jeder Datei: was
darin steht, was jede Routine tut, wer sie wann aufruft, wie sie funktioniert und was sie
kostet. Das Warum hinter dem Entwurf steht in [NOTES.de.md](NOTES.de.md) und
[HANDOFF.de.md](../HANDOFF.de.md); das Bild in einfachen Worten in [HOW_IT_WORKS.de.md](HOW_IT_WORKS.de.md).

Das ist der Code des Next (`src/`). Der TS-Conf-Port ([tsconf/CODE.de.md](../tsconf/CODE.de.md))
verwendet eine Kopie seines Spielteils: `play.asm`, `game.asm`, `river_gen.asm`, `spans.asm`,
die `display*.asm`-Dateien, `panel.asm` und `sound_driver` werden hier für beide beschrieben
(die wenigen Änderungen von TS-Conf sind dort aufgezählt); der Rest hier, das Bild, die Sprites,
der Copper, das Panel, der Ton über den DAC, der Start, gehört dem Next. Eine Tabelle, wie sich
die beiden Maschinen unterscheiden, steht am Anfang von tsconf/CODE.de.md. Die eigene Hardware
des Next, wie dieser Code sie nutzt: Z80N-Befehle (`nextreg`, `mul`, `bsla`), 8K-Slots, Layer 2
spaltenweise, der Copper, die Tilemap, Sprites mit Skalierung, zxnDMA und DAC, drei AYs, 50 und
60 Hz.

## Die Zahlen

Zeiten sind Takte des Next-Kerns bei 28 MHz pro Frame, gemittelt, aus dem Histogramm von nxcheck
(`NXHISTALL=Datei`, dann `python3 tools/prof.py build/test.sym Datei 60`, geteilt durch die
Frames), auf dem Prüf-Build ohne Bildschirmspeicher, wie das Spiel ihn hat (`-DNOSCREEN`,
`NXNOSCREEN=1`). Zwei Läufe:

- **A**: PAL, Bot 1, 3 000 Frames ab dem Start (der übliche frühe Spielverlauf): im Mittel ~102 000 pro Frame, höchstens ~158 000;
- **B**: `-stress` ab Brücke 80, PAL, 6 000 Frames (`NXBRIDGE=80 NXGHOST=1 NXGAME=1`: alle Slots belegt, Vollgas, Dauerfeuer): im Mittel ~159 000, höchstens ~198 000 (NTSC ~160 000 / ~202 000; bei 14 MHz NTSC ~131 000 / ~165 000 von ~240 000).

Ein Frame hat ~567 000 Takte bei PAL und ~481 000 bei NTSC (bei 14 MHz die Hälfte). `apply` (und
damit `panel_frame`) läuft nach der gemessenen Arbeit (unter der Laufschrift) und ist nicht in
diesen Zahlen: ~7 400 pro Frame. Die Zeit einer Routine sind nur ihre eigenen Befehle: Die
Routinen, die sie aufruft, zählen unter ihren eigenen Namen.

Nach Teilen (A / B):

| Teil | A | B |
|---|---|---|
| das Display: Platzieren der Objekte und Kollisionen (`display_simple`, `display_objs`, `display_hits`, `sp_*`) | 40 400 | 54 300 |
| Ton (`pokey_frame`, `snd_*`, `pk_*`, `ay_*`, `sound_driver`) | 26 900 | 39 300 |
| neue Flusszeilen (`river_gen`, `render_line`, `rl_fill`, `span_line`, `push_line`) | 19 500 | 45 400 |
| Sprites und die Liste des Coppers (`build_sprites`, `ob_*`, `pl_*`, `build_copper`) | 9 900 | 15 000 |
| die Spiellogik und der Rest (`prepare`, `main_loop`, `move_objects`, `random_step`, das Drucken des Panels, …) | 9 400 | 10 500 |

Die teuersten Routinen (A / B):

| Routine | A | B | Datei |
|---|---|---|---|
| `display` (eigener Code) | 10 900 | 12 600 | display_simple |
| `pk_noise` | 4 600 | 12 900 | sound_pulses |
| `dh_pf` | 10 200 | 11 200 | display_hits |
| `span_line` | 4 200 | 10 300 | spans |
| `ds_edge_test` | 3 200 | 10 200 | display_simple |
| `render_line` | 4 100 | 10 000 | render |
| `snd_sum` | 8 600 | 8 600 | sound |
| `rl_fill` | 3 800 | 8 300 | spans |
| `ds_obj` | 5 300 | 6 100 | display_objs |
| `dh_obj` | 4 900 | 6 100 | display_hits |
| `ob_list` | 4 100 | 5 600 | sprites |
| `ob_attr` | 2 900 | 5 200 | sprites |
| `move_objects` | 2 000 | 3 900 | game |
| `dl_fill` | 1 600 | 3 700 | river_gen |
| `ay_out` | 3 400 | 3 400 | sound_ay_run |
| `snd_fill` | 2 800 | 2 800 | sound |
| `ay_frame` | 2 200 | 2 800 | sound_ay_run |
| `pk_channel` | 1 200 | 2 700 | sound_pulses |
| `pokey_frame` (eigener Code) | 2 500 | 2 700 | sound |
| `draw_line` | 900 | 2 300 | river_gen |
| `pk_g4` | 0 | 1 400 (~9 000 in einem Frame, in dem die Rakete klingt) | sound_pulses |
| `dh_lists` | 1 300 | 1 300 | display_hits |
| `hit_setup` | 500 | 700 | display_hits |

Das schwerste Frame von B (~198 000): der Ton bis ~60 000 (das Rauschen und die Rakete auf dem
DAC, ~180 Impulse), Platzieren und Kantentests (`display`, `ds_obj`, `ds_edge_test`) ~30 000,
die Kollisionen (`dh_pf`, `dh_bits`, `dh_obj`, `hit_*`) ~25 000, die neuen Flusszeilen ~25 000.

(`prof.py` nimmt den Namen einer Routine vom nächsten globalen Label unterhalb der Adresse,
also kann ein Daten-Label direkt vor Code dessen Zeit bekommen; die Symbole von Seite 12 bei
$6000-$7FFF stehen für `panel_init` in Seite 7 an denselben Adressen, das einmal beim Start
läuft.)

## Speicher, während der Code läuft

8K-Slots ($0000, $2000, … $E000) und die Seiten darin:

| Slot | Adresse | normalerweise | umgemappt von |
|---|---|---|---|
| 0–1 | $0000–$3FFF | 30–31: das RAM des Atari an den Adressen des Originals | `pokey_frame`: 14–15, POKEYs 17-Bit-Zähler (`poly17.bin`), während es Samples macht |
| 2 | $4000–$5FFF | wechselnd: keine feste Seite | `render_line`: 18–27 (Layer 2, eine Seite pro 32 Spalten); `display`, `span_line`, `spans_clear`: 28 (`SPAN_PAGE`, die Läufe der Zeilen); `panel_frame`: 11 (die Karte der Tilemap); `panel_init`: 10, 11 |
| 3 | $6000–$7FFF | 12: Puffer (`copper_list`, `ds_objs`, `sprite_list`, `ov_exp2`/`ov_exp4` (die Punkte eines Bytes verbreitert, `dh_obj`), die Lücken der Kante `eg_*` (`ds_edge_test`), der Ring des DAC bei $7C00) | nur beim Start: 7 (`panel_init`, `sound_init7`, `load_rom`). **Nie, während der Ton spielt**: Der DMA liest den Ring durch diesen Slot |
| 4 | $8000–$9FFF | 4: Code | — |
| 5 | $A000–$BFFF | 5: die Cartridge, aus River_Raid.rom gelesen | — |
| 6 | $C000–$DFFF | 6: Code | — |
| 7 | $E000–$FFFF | 1: Variablen, Tabellen (darunter die Lücken des Ufers `bg_*`), der Stack (von $0000 abwärts bis über $FF00) | — |

Seite 4 endet bei ~$9E2C (von $A000), Seite 6 bei ~$DD53 (von $E000), Seite 7 bei ~$6913 (der
Build druckt das): Der weggefallene Fahrplan des DLI hat etwas Platz gelassen. Code zwischen
Seiten zu verschieben ist die Art, wie früher Platz gefunden wurde (`display_objs.asm` stand in
der Lücke vor der Ausrichtung der Palette in Seite 4, jetzt an ihrem Ende).

Interrupts sind die ganze Zeit aus (`di` beim Start): Das Frame wird durch Abfragen der
Rasterzeile getaktet (`wait_frame`), der Ton durch den DMA, die Farben pro Zeile durch den Copper.

## Das Frame

`main_frame` (river_raid.asm), jedes Frame:

1. Hält fest, was das Bild dieses Frames zeigt (`scroll`, die Farben von Kante und Wasser, den Spieler), `read_input`, CAPS + 1 (`restart` in der anderen Norm).
2. Normalerweise: `prepare` → `display` → `build_sprites` → `main_loop` → `vbi`. Während eines Resets (`busy`, die Frames, in denen das Original den Speicher löscht: 13 NTSC, 8 PAL): `display` → `build_sprites` → `clear_layer2_page` → (`finish_reset` im letzten) → `vbi`.
3. `pokey_frame`: die Samples des Frames in den Ring des DAC und die Töne des AY.
4. `wait_frame`: fragt die aktive Videozeile ab (NR $1E/$1F) bis `wait_line` (208 NTSC, 220 PAL), unter der Laufschrift, wo sich auf dem Bildschirm nichts ändert.
5. `apply`: Alles Gebaute wird auf einmal wirksam (Scroll und Farben von Layer 2, die Attribute der Sprites, die Kacheln des Panels, die Liste des Coppers).

Mit eingeschaltetem T (`tm_show`) setzt jeder dieser Teile zuerst die Farbe des Rands (`TM_COLOUR`: es ruft `tm_colour` nur bei eingeschaltetem T; aus kostet es ~30 Takte pro Teil): orange `apply`, grau `prepare` (und `clear_layer2_page` während eines Resets), rot `display`, gelb `build_sprites`, blau `main_loop`, magenta `push_line` (eine neue Flusszeile, innerhalb von `main_loop`), weiß `vbi`, cyan `pokey_frame`, schwarz die übrige Zeit. `push_line` setzt magenta und zurück auf blau.

Die Reihenfolge zählt: `display` nutzt den Zustand, den `main_loop` des vorigen Frames
hinterließ (so wie der DLI des Atari den Zustand des vorigen Frames zeigt), und `build_sprites`
nutzt, was `display` hinterließ.

---

## river_raid.asm: das Frame, der Start, der Speicher

Die oberste Datei: Speicheraufteilung, `include`s, Zusammenbau der Seiten (`mmu`/`org`),
Variablen von Seite 1 und Puffer von Seite 12, Haken für Test-Builds.

| Routine | aufgerufen | was und wie |
|---|---|---|
| `start` | beim Laden | `load_rom` (nicht in Test-Builds), RANDOM aus R gesät, 28 MHz, Seiten gemappt, `init_tables`, `init_video`, `panel_init` (Seite 7 gemappt), dann `restart`. |
| `restart` | `start`; CAPS + 1 | Die Maschine „eingeschaltet“ in der Norm von `tv_pal`: `tv_setup`, Layer 2 gelöscht (alle 10 Seiten auf einmal), `sound_init`, `start_attract`, fällt in `main_frame`. |
| `main_frame` | jedes Frame | Siehe *Das Frame*. ~340 eigene Takte. |
| `wait_frame` | `main_frame` | Wartet aktiv auf NR $1F gegen `wait_line`. Seine Zeit ist Leerlauf, keine Arbeit. |
| `init_tables` | `start` | Einmal: die Tabellen: `ring_lo`/`ring_hi` (die 160 Zeilen des Bildschirmspeichers der Reihe nach), `span_class` (die Farbe eines Bytes, wenn seine 4 Pixel gleich sind), `span_init` (die Masken), eine leere Copper-Liste. |
| `tv_setup` | `restart` | Die Einstellungen der Norm: NR $05 50/60 Hz, `init_line_tables`, `wait_line`, die Zufallskarte, der Panel-Teil des Coppers (`copper_panel_ntsc`/`_pal` kopiert, das Grau hineingepatcht, `COPPER_GREY`), der erste Y-Scroll der Tilemap, Clip-Fenster (Layer 2 bis zur letzten grauen Zeile des Panels, Sprites, Tilemap). |
| `init_video` | `start` | Schwarzer Rand, keine ULA, globale Transparenz $E3, Layer 2 320×256×8 in Bank 9, Ebenenreihenfolge (Tilemap über Sprites über Layer 2), die Paletten: die 4 Einträge von Layer 2, die 128–255 der Sprites = die Farben des Atari, NR $15 mit dem Clip der Sprites im Modus über dem Rand. |
| `test_ghost` | Test-Builds, nach `display`, wenn `test_ghost_on` | NXGHOST von nxcheck: die Kollisionen des Flugzeugs und der Treibstoff so gesetzt, dass es nicht abstürzen kann. |

Außerdem: `span_rec` (Makro: HL = der 32-Byte-Datensatz der Flusszeile A in SPAN_PAGE), die
`palette` (Atari-Farbe → Next-Farbe, 256 Byte) und `random_columns`, die `TEST`-Variablen
(`start_bridges_hi`, `snd_passed`, `test_ghost_on`).

## play.asm: die Hauptschleife (A197–A6EA)

Die Spiellogik, die das Original in seiner Hauptschleife ausführt, wie der C++-Port sie hat. Der
Zustand liegt an den RAM-Adressen des Originals.

| Routine | aufgerufen | was und wie | A / B |
|---|---|---|---|
| `main_loop` | `main_frame` (nicht während eines Resets) | A197–A6EA: liest RANDOM (`random_read`), das Flugzeug (`fly_plane`) oder die Explosion/Wiederkehr (`respawn_or_game_over`), `drive_tank`, `move_objects`, dann `main_loop_end`. Kehrt früher zurück, wenn ein Reset beginnt. | 620 / 620 |
| `main_loop_end` | `main_loop`, `finish_reset` | A5B7–A6EA: die Rakete und die Granate (`move_missile`, `move_shell`), `scroll_river`, START/SELECT. | 180 / 170 |
| `scroll_river` | `main_loop_end` | A6FD: die Geschwindigkeit zweimal pro Frame zu einem Bruch addiert; jeder Übertrag ist ein `push_line` (eine neue Flusszeile: der teure Teil, siehe river_gen). | 140 / 160 |
| `fly_plane` | `main_loop` | A3E9–A5B4: Treibstoff, Steuern (`steer`), Geschwindigkeit (`change_speed`), Schießen, die Kugel (`move_bullet`), die Folgen der Kollisionen: `explode` (ein Objekt abgeschossen oder gerammt: Punkte), `crash`. | 290 / 480 |
| `steer`, `change_speed` | `fly_plane` | Das X des Flugzeugs mit einem Bruchteil unter einem Pixel; die Geschwindigkeit $40–$FE. | |
| `explode` | `fly_plane` | A4E0–A589: Der Slot wird eine Explosion, die Punkte (BCD), der Bonus einer Brücke. | |
| `crash` | `fly_plane`, `explode` | sub $B1C0: Das Flugzeug stürzt ab, mit einem Ereignisgeräusch; `section_checkpoint`. | |
| `draw_bullet`, `move_bullet` | `fly_plane`, `crash` | Die 8 Zeilen der Kugel in den Speicher von Missile 2 (nur `-DBEAM`; sonst kehrt `draw_bullet` sofort zurück). | 380 / 520 |
| `new_game`, `reset` | START, Spielende, Wiederkehr | sub $B0F1: Fluss und Objekte zurückgesetzt (`restore_checkpoint`), `clear_screen_memory` (nur mit Bildschirmspeicher: Prüf- und Strahl-Builds), `busy` = 13 oder 8 Frames. | |
| `clear_layer2_page` | `main_frame` während `busy`, `restart` | Zwei der 10 Seiten von Layer 2 pro Frame gelöscht (`l2_clear` zählt); keine im ersten Frame des Resets (`l2_wait`: sein Bild wird noch gezeigt), und `apply` versteckt währenddessen die Zeilen des Flusses (`l2_hidden`). ~1 100 pro Frame im Mittel über A, aber eine Seite sind 8 KB Schreibzugriffe in den Frames, in denen es läuft. | 1 100 / 570 |
| `finish_reset`, `finish_respawn`, `respawn_or_game_over` | | Nach dem Reset: Der Fluss geht ab dem Checkpoint weiter, der nächste Spieler oder Spielende. | |
| `swap_players`, `update_high_score`, `set_up_game`, `select_game` | | Zwei Spieler, Rekord mit seinen Prüfbytes, die Spielnummer. | |
| `show_lives`, `show_score`, `show_bridges`, … | die Schleife, der VBI | Die Zeichen des Panels im RAM des Atari ($1000). | 620 / 720 |
| `print_bcd` | die `show_*` | B086: BCD-Bytes als Ziffern, führende Nullen leer. | 1 200 / 1 400 |
| `read_input` | `main_frame` (nicht in Test-Builds) | Die Tastatur (Q A O P, Space/M, Enter, G, H, CAPS + 1/2), Kempston 1 und 2 und das Mega-Drive-Pad in die Joystick-, Feuer- und Konsolen-Bytes des Atari. T (beim Drücken) schaltet `tm_show` um, aus: die Ausweichfarbe schwarz. | — |

## game.asm: Spielteile pro Frame und der VBI

| Routine | aufgerufen | was und wie | A / B |
|---|---|---|---|
| `random_read` | `main_loop` (A205) | POKEYs RANDOM: der 17-Bit-Zähler, wie er am Lesepunkt steht. Die Prüfungen zählen diese Lesezugriffe. | |
| `random_step` | `vbi` | Der Zähler ein Frame weiter: eine feste lineare Abbildung (17 Spalten in `random.inc`, NTSC oder PAL), 4 Bit auf einmal: für jedes der 4 Nibbles der Bits 0–15 ein 3-Byte-Eintrag von `rnd_tab` (Seite 1, 256 Byte ausgerichtet: 64 k + 4 v) per XOR, die Spalte von Bit 16 (`rnd_col16`), wenn gesetzt. War Bit für Bit, ~2 300. | 560 / 560 |
| `rnd_tables` | Ende von `tv_setup` | `rnd_tab` und `rnd_col16` aus den Spalten der Norm (`rnd_cols`): jeder Eintrag das XOR der Spalten seines Werts. | |
| `bank_colour` | `vbi`, `start_attract` | sub $AFD0: der Farbton des Ufers (wechselt, während oben eine Brücke hereingezeichnet wird). | 200 / 200 |
| `start_attract` | `restart` | Der Zustand des Attract-Modus an seiner ersten Zeile (Spiel 1, kein Flugzeug). | |
| `draw_logo_and_needle` | `reset`, `start_attract` | Der Regenbogen und die Tanknadel in den Player-Missile-Speicher, wie sub $B0F1 sie hinterlässt (nur `-DBEAM`; beim Next sind es Sprites). | |
| `push_line` | `scroll_river`, `start_attract` | Eine neue Flusszeile: `next_line` (river_gen) hält ihre Stücke in `dl_seg` fest, dann bei `line_done` zeichnen `render_line` (Layer 2) und `span_line` (die Läufe für die Kollisionen) daraus; mit Bildschirmspeicher (Prüf- und Strahl-Builds, `SCREEN_MEMORY`) gehen die Bytes der Zeile auch über `line_buf` in den Bildschirmspeicher (48 LDIs, die Adresse der obersten Zeile eine Zeile höher). | |
| `prepare` | `main_frame` | AE99–AF38 am Anfang des Frames: Panzer und Granate unter den Bildschirm verschwunden, die Farbe der Granate, Leben, Brücken und Punkte des Panels. Die Formen in den Player-Missile-Speicher ($0B00–$0FFF) nur im Build des Taktmodells (`-DBEAM`): Sprites und Kollisionen des Next nehmen sie aus dem ROM. | ~2 000 (3 000 mit den Kopien) |
| `drive_tank` | `main_loop` | A21B: Der Panzer auf der Straße fährt, schießt an der Flusskante. | |
| `move_objects` | `main_loop` | A26C–A2ED: Die Objekte in den Slots werden animiert und bewegt (Schiffe und Hubschrauber wenden an der Kante: das Kantenflag des Slots aus dem Display). | 2 000 / 3 700 |
| `move_missile`, `move_shell` | `main_loop_end` | Die Rakete des Hubschraubers, die Granate des Panzers. | |
| `vbi` | `main_frame` | B2A5–B43E: `sound_driver`, der Framezähler, die Farben des nächsten Frames (`bank_colour`), `scroller_step`, `random_step`. Bei PAL sieht es am Spielende einige Werte von vor sub $B21A (`vbi_before`). | 420 / 430 |
| `scroller_step` | `vbi`, `start_attract` | B44B: die Laufschrift einen Farbtakt pro Frame im Attract-Modus, still im Spiel. | |

## river_gen.asm: der Flussgenerator (A711–AE93)

Eine Flusszeile nach der anderen, wie das Original sie erzeugt: das 24-Bit-LFSR, Abschnitte und
Blöcke, Breiten von Ufer und Insel, Dekorationen (Häuser, Berge), Straßen und Brücken, die alle
16 Zeilen platzierten Objekte. Sein Ergebnis sind die Stücke der Zeile in `dl_seg` (je 4 Byte:
das Byte, an dem es beginnt, seine Art, seine Daten: 0 eine Kante, der Versatz ihres Stücks in
der Tabelle bei $B800; 1 Bytes eines Werts, der Wert; 2 eine Zeile einer Dekoration, die Adresse
ihres Bitmaps; beendet durch Byte 48) und die Slots. Im Spiel kein Zeilenpuffer: `line_buf` (48
Byte, 192 Farbtakte zu 2 Bit; nicht vorher gelöscht, die Stücke folgen einander von Byte 0 bis
48) wird nur mit Bildschirmspeicher geschrieben.

| Routine | aufgerufen | was und wie | A / B |
|---|---|---|---|
| `next_line` | `push_line` | Eine Zeile: `count_lines`, `move_bank`, `change_island`, `scroll_objects`, `place_object`, dann `draw_line`. | 210 / 290 |
| `count_lines` | `next_line` | A711: zählt Zeilen; an Block- und Abschnittsanfängen bereitet es vor, was kommt (`choose_section_width`, `start_decoration`, Checkpoints). | 160 / 210 |
| `move_bank` (+ `bank_hit_setup`, `bank_hits_left/right`) | `next_line` | A826: die Position des Ufers für diese Zeile, ohne in das Objekt zu laufen, das noch hereingezeichnet wird. | 350 / 570 |
| `change_island`, `choose_section_width` | | Die Insel zur Zielbreite. | |
| `draw_line` | `next_line` | Die Stücke der Zeile: Uferfüllung (`dl_fill`, `dl_fill_bank`), Kanten (`dl_edge`, `dl_bank_edge`: 2-Byte-Stücke aus $B800), die Zeile der Dekoration (`dl_deco_row`, die Adresse ihres Bitmaps weitergesetzt), Wasser; jedes mit seinen Daten in `dl_seg`, DRAW_POS weitergesetzt; ihre Bytes nur mit Bildschirmspeicher in `line_buf`. | 900 / 2 300 |
| `dl_fill` | `draw_line` | B Bytes von C ab DRAW_POS: ein Stück der Art 1 (die Bytes selbst nur mit Bildschirmspeicher). | 500 / 1 300 |
| `scroll_objects` | `next_line` | AB76: alles eine Zeile tiefer; wenn der unterste Slot den Bildschirm verlässt, rücken die Slots. | 560 / 820 |
| `place_object`, `choose_enemy`, `position_object`, `place_tank` | `next_line` | Alle 16 Zeilen ein neues Objekt im nächsten freien Slot; am Anfang eines Blocks vielleicht ein Panzer auf einer Straße. | |
| `step_lfsr` | viele | sub $B183: das 24-Bit-LFSR. | 140 / 200 |
| `section_checkpoint`, `restore_checkpoint`, `start_game` | | Der Neustartpunkt; ein neues Spiel ab Brücke 1 (oder `start_bridges_hi` in Test-Builds). | |

Die Kosten des Generators fallen pro neuer Zeile an: Die Geschwindigkeit wird zweimal pro Frame
zu einem Bruch addiert, und jeder Übertrag ist eine Zeile, also 0–2 Zeilen pro Frame, mehr, je
schneller das Flugzeug fliegt.

## render.asm: eine Zeile in Layer 2

| Routine | aufgerufen | was und wie | A / B |
|---|---|---|---|
| `render_line` | `line_done` | Zuerst `line_bank` (der Tabellensatz der Zeile), Seite 29 (`PIX_PAGE`) solange in Slot 0. Farbtakte 20–179 (`WINDOW_FIRST`) der Zeile in Reihe A von Layer 2, aus den Stücken von `dl_seg` (kein Zeilenpuffer). Layer 2 ist spaltenweise gespeichert (Byte x·256 + y, 32 Spalten pro 8K-Seite), also wird die Reihe die Spalten hinunter geschrieben (`inc h` = die nächste Spalte), 10 Seiten nacheinander in Slot 2 (`rl_next`). Ein Stück eines Werts: seine Farbe einmal aus der ersten Seite des Satzes, dann `rl_fill` (8 Spalten pro Byte, Seite für Seite; `rl_fill`, `rl_next` in Seite 6, spans.asm); die Bytes einer Kante (aus der Tabelle im ROM) und die Zeile einer Dekoration (aus ihrer Bitmap im ROM): pro Byte geben die 4 Seiten des Satzes 2 Punkte pro Takt, jeder zweimal geschrieben; die Bytes vor dem Fenster in den Daten übersprungen. 320 Schreibzugriffe pro Zeile. Am Ende das RAM des Atari zurück in Slot 0. In Seite 6 (aus Platzgründen von Seite 4 verschoben). | 4 100 + 3 800 / 10 000 + 8 300 |
| `line_bank` | `render_line` | `lineBankColour` des C++-Ports auf dem Zustand nach der Zeile: die Slots ab `FIRST_SLOT` abwärts, solange einer eine Straßenzeile zeigen kann (y ≤ $5E: y wächst die Slots hinunter); bei einer Brücke ihre Straßenzeile y + Höhe − $5E, die Farbe aus der Tabelle bei $B4E5; sonst `bank_colour` (das Grün). Dieselbe Farbe wie die Zeile davor: nichts weiter; sonst ihr Platz in `bank_cols` × 4 nach `rl_set` (das High-Byte des Satzes). In bank_colours.asm (Seite 6). | 240 / 510 (+ `bank_colour` 370 / 580) |
| `bank_init`, `pix_sets` | `start` (Seite 7, nach `panel_init`) | Die Uferfarben, jede einmal: $D2, $D6, die der 20 Straßenzeilen (`bank_cols`, `bank_n`, höchstens 8), Einträge 1, dann 4–10 von Layer 2 (`bank_set`); Seite 29 in Slot 0: ein Satz aus 4 Seiten pro Farbe (Satz i bei 4i × 256), Byte b der Seite k ist der Punkt k von b, wie Layer 2 ihn hält (0, 2, 3 sie selbst, 1 der Eintrag der Farbe i). | einmal |
| `bank_set` | `bank_init`, `apply` | Die Ufereinträge von Layer 2: ihre Farben (E = 1) oder schwarz (E = 0, die Farben aus: `apply`, wenn sich `show_bank` ändert, `ap_bank_on`). | |

## spans.asm: die Läufe der Zeilen für die Kollisionen mit dem Playfield

Jede Flusszeile hat einen 32-Byte-Datensatz in SPAN_PAGE (Seite 28 bei $4000), in einem Ring von
256: die Farbtakte, an denen ihre Läufe von Ufer (Farbe 1) und Kante (Farbe 2) beginnen und
enden. Die Kollisionen testen Zeilen der Sprites gegen diese Läufe statt gegen Pixel. Mit
demselben Ringindex ihre Lücken: `eg_e1`–`eg_s2` und `eg_e3`–`eg_s4` (Seite 12) das Wasser
zwischen den Läufen der Kante (bei 2 Läufen das zwischen ihnen, bei 4 das zwischen 1. und 2.
und 3. und 4., bei keinem die ganze Zeile, sonst keines: $FF); `bg_e1`–`bg_s2`, `bg_e3`–`bg_s4`
(Seite 1) die zwei breitesten Lücken zwischen den Läufen des Ufers (ab Takt 32 vor dem ersten
bis 224 nach dem letzten). Ein Rechteck in einer Lücke berührt auf der Zeile nichts.

| Routine | aufgerufen | was und wie | A / B |
|---|---|---|---|
| `span_line` | `line_done` | Der Datensatz der neuen Zeile aus den Stücken von `dl_seg`, ohne ein Pixel anzusehen: Ein Stück eines Werts ist ganz eine Farbe (`span_class`), eine Zeile einer Dekoration die des Ufers (wie bankRuns des C++-Ports, die Zeile ohne Dekoration), die Läufe einer Kante fertig aus `edge_runs` nach ihrem Stück (der Takt im Stück und seine Farbe, bei Byte 48 abgeschnitten); jeder Farbwechsel schließt einen Lauf (`.change`). Dann ihre Lücken (`.gaps` aus den Läufen der Kante, `.bgaps` aus denen des Ufers: die zwei breitesten behalten, `.gap`). | 4 200 / 10 300 |
| `edge_runs_init` | `init_tables` (Start) | Jedes Kantenstück, das der Generator benutzt (Versätze 0–30 der Tabelle bei $B800), in `edge_runs` (Seite 12, 16 Byte pro Stück): die Pixel 0–7 seiner zwei Bytes, ein Paar (das Pixel, seine Farbe; 3, das Wasser, als 0) am ersten und an jedem Wechsel, danach $FF. | einmal |
| `spans_clear` | `start_attract` | Keine Läufe auf irgendeiner Zeile (Bildschirmspeicher gelöscht). Die Lücken bleiben: Ohne Läufe kann nichts berührt werden, was immer sie sagen, und jede neue Zeile macht sie neu. | |
| `span_init` | `init_tables` | Die Masken: Bits i..j eines Bytes (`span_masks`). | |

## display_simple.asm: die platzierten Objekte, ihre Kollisionen

Wie `displayGeometry` des C++-Ports (Zweig `dli_removed`): kein DLI. Jedes Objekt steht an der
y seines Slots, auf den Fluss zugeschnitten, und seine Kollisionen sind einfache Geometrie. Was
es hinterlässt: `ds_objs` (die Zeilen jedes Objekts für die Sprites: 8 Byte, erste Zeile,
Zeilenzahl, Zeiger auf Form und Farbe, x, Größe), die Ergebnisse der Kollisionen in HIT und die Kantenflags der Slots.

`display` (~11 800 / 13 500 eigene):

1. Mappt SPAN_PAGE, `dh_lists` (die Deskriptoren der anderen Sprites), die Register gelöscht und gesetzt wie B527–B55C, `bm_hitclr`, `dh_sprites` (HIT = $FF, dann die anderen Sprites mit dem Ufer und untereinander).
2. `.slot`, pro Slot ab FIRST_SLOT: IY auf der Art des Slots (Seite 5: Typ, X, Größe bei IY + 11, + 22, + 33, dort gelesen, keine Kopien), Y und die Flags behalten (`ds_y`, `ds_flags`), `ds_edge_kind`; der Anfang = max(y, $5D); die erste Zeile = y + height[type] − Anfang (≥ $80: nach oben verschwunden, der nächste); X = Anfang + 3 (über 255: das Ende); Zeilen = min(Zeile + 1, 256 − X); `ds_rowp` das Byte der ersten Zeile; `ds_obj` (die Zeilen in `ds_objs`); eine Brücke: `.road` (`-DBEAM`) (die Farbe der Straße ab der Scanline nach jeder ihrer Zeilen, X − 69 + 1; die Uferfarbe des Abschnitts nach der letzten, sofern X nicht umgelaufen ist, über `ds_bank`; die Farbe einer Zeile nur, wenn sie sich von der darüber unterscheidet). Die ersten Zeilen von Form und Farben werden an Ort und Stelle ermittelt (DE, BC für `ds_obj`). Die Tabellen des ROM (Höhe, Form, Farben) werden mit 8-Bit-Summen gelesen (`ROM_SHAPES` und `ROM_COLOURS` beginnen am Seitenanfang).
3. Die Kante (P3PF) für die Arten 8–$0D (`ds_edge_kind`: Hubschrauber, Ballons, Schiffe wenden an ihr): `ds_edge_test`, dann `ds_set_flags`.
4. Gegen die Kugel, die Granate (keine Brücke) und das Flugzeug: `dh_obj`; eine Berührung speichert den Slot (HIT_BULLET_OBJECT, HIT_SHELL_OBJECT, HIT_PLANE_OBJECT), also bleibt der letzte den Bildschirm hinunter.
5. `.end`: `test_ghost` (Test-Builds); `ds_bank_fill` nur mit `-DBEAM`.

| Routine | aufgerufen | was und wie | A / B |
|---|---|---|---|
| `ds_edge_test` | `display`, pro Objekt der Arten 8–$0D | A = $02, wenn die Spanne einer Zeile (ihr erster Punkt bis zum letzten) einen Lauf der Kante auf ihrer Zeile trifft (`edgeTouches` des C++-Ports). Das Rechteck des Objekts (X bis X + 8, 16 oder 32 Takte; nichts über Takt 255) pro Zeile gegen die Wasserlücken der Zeile (`eg_*`, der Ringindex der Zeile schreitet um eins); darin: die nächste Zeile. Sonst der erste und der letzte Punkt der Zeile (`edge_lo`/`edge_hi` nach der Größe skaliert: `.s1`/`.s2`, plus X: `.ex1`/`.ex2`) gegen die Läufe der Kante der Zeile (ihr Datensatz): Ein Lauf dazwischen ist eine Berührung, kein Punkt für Punkt. | 3 200 / 10 200 |
| `ds_set_flags` | `display` | Das Kantenbit des Objekts in die Flags seines Slots (Bit 0). | 1 100 / 1 300 |
| `ds_bank` | `display` (`-DBEAM`) | Ein Wechsel der Uferfarbe ab Scanline A (die Straße einer Brücke und zurück): in `ds_bank_ev`. | |
| `ds_bank_fill` | Ende von `display`, nur `-DBEAM` | `scan_bank` für jede Flusszeile aus `ds_bank_ev` (nur das Strahl-Display liest es; im Spiel geht die Uferfarbe pro Zeile: `line_bank`). | |
| `ds_edge_only` | `display` | Das Kantenbit nur für die Arten, die es lesen. | |

## display_objs.asm

| Routine | aufgerufen | was und wie | A / B |
|---|---|---|---|
| `ds_obj` | `display`, pro Objekt mit Zeilen | Die Zeilen des Objekts für die Sprites: erste Scanline, Zeilenzahl, die Adressen von Form und Farbe der ersten Zeile (DE, IY), x, Größe: 8 Byte in `ds_objs` (`DS_OBJS` = höchstens 16). Ein Objekt, dessen erste Zeile auf oder über Zeile 28 (über der Oberkante des Flusses) liegt, wird auf seine ganze Form erweitert (k = Anfang − y Zeilen mehr), also wird das Sprite ganz gezeichnet und das Clip-Fenster der Sprites schneidet es. Am Ende von Seite 4. | 5 300 / 6 100 |

## display_hits.asm: die Kollisionen als Geometrie

Keine Kollisionsregister und keine Lesezugriffe: Eine Kollision zählt, wenn sie irgendwo auf den
Zeilen der Sprites geschieht. Fünf andere Sprites werden durch 10-Byte-Deskriptoren in `dh_desc`
beschrieben (was bleibt, einmal beim Start aus `dh_template` kopiert, `dh_init`; den Rest füllt `dh_lists` jedes Frame aus): die Basis der Zeilen (low), Maske (schon auf die Plätze der Punkte gedreht), das Ende der Zeilen (die Zeile nach der letzten; über 255 255), x, Größe, Spritenummer, erste Zeile, Zeilen, Breite in Takten, die Basis
(high) (`DH_SIZE` = 10; `DH_SHELL`, `DH_TANK`, `DH_PLANE`, `DH_MISSILE`, `DH_BULLET`). Eine Zeile
auf Zeile L ist das Byte bei Basis + L: die Form des Frames aus dem ROM (Basis = ihre Adresse −
die erste Zeile, `dh_shape`, `dh_base`); die Zeilen von Rakete und Kugel sind `dh_ones` (alle
gesetzt) unter ihren Masken, schon in der Vorlage auf die Plätze der Punkte gedreht ($03 um 6: $C0; Bit 5 der Kugel um 2: $80), also wird keine Zeile gedreht. Nach einem Reset (`pm_empty`, bis zum nächsten
`prepare`) keine Zeilen.

| Routine | aufgerufen | was und wie | A / B |
|---|---|---|---|
| `dh_lists` | Anfang von `display` | Zeilen, Positionen und Basen der Deskriptoren; dann das Ende jedes (Feld 2). | 1 300 / 1 300 |
| `dh_sprites` | `display` | HIT = $FF, dann HIT 0, wo: der Panzer die Kante trifft (P1PF), das Flugzeug das Ufer (P2PF), Rakete und Kugel Ufer oder Kante (M0PF, M2PF): `dh_pf`; das Flugzeug und die Granate (P2PL Bit 0), die Rakete und das Flugzeug (M0PL): `dh_pair`. | |
| `dh_pf` | `dh_sprites` | NZ: Die Zeilen von Sprite IX treffen das Playfield (DE: `sp_edge`, `sp_bank`, `sp_under`). Pro Flusszeile: zuerst das Byte der Zeile unter der Maske (keine Punkte: die nächste Zeile), dann sein Rechteck (X bis X + seine Takte) in den Lücken der Zeile (A: Bit 0 die `eg_*` der Kante, Bit 1 die `bg_*` des Ufers); darin nichts; sonst die Enden der Zeile gegen die Läufe (die `sp_*`-Funktion). Hält bei der ersten Berührung an. | 10 200 / 11 200 |
| `sp_edge`, `sp_bank`, `sp_under` | `dh_pf` | Eine Zeile eines Sprites gegen die Läufe der Zeile von Kante (braun), Ufer (grün) oder beidem, wie `spanTouches` des C++-Ports: ihr erster und letzter Punkt (`sp_ends`: `edge_lo`, `edge_hi`, die Breite der Größe, plus X) gegen die Läufe (`sp_runs`), ein Lauf dazwischen eine Berührung; der Datensatz der Zeile über `sp_rec`. | |
| `dh_pair` | `dh_sprites` | NZ: Die Zeilen zweier Sprites treffen sich: `hit_setup` auf ihren Takten, dann pro Zeile, die beide haben, die Bits jedes (`dh_bits`, `hit_wide` nach seiner Größe) in `hit_a`, `hit_b` und `hit_line`. | |
| `dh_bits`, `dh_end` | `dh_pf`, `dh_pair`, `dh_obj` | Die Bits von Sprite IX auf Zeile A: das Byte der Zeile unter der Maske, schon oben (Z: keine); die Zeile nach seiner letzten (`dh_lists` legt sie einmal pro Frame in Feld 2). | 400 / 500 |
| `dh_obj` | `display`, pro Objekt (Kugel, Granate, Flugzeug) | NZ: Sprite IX berührt die Zeilen des aktuellen Objekts (`ds_rowp`, ab der Zeile von X = `ds_counter`, `ds_rows` davon, bei X und Größe des Slots: IY + 22, + 33). Zuerst die Zeilen, die beide haben (`ds_l1`, `ds_l2` aus `display`, das Ende des Sprites: die meisten Objekte teilen keine mit ihm), dann `hit_setup` auf den Takten des Objekts (8, 16 oder 32) und des Sprites; pro Zeile das Zeilenbyte des Objekts (null: die nächste) und die Bits des Sprites, jedes verbreitert (`hit_wide`), `hit_line`. | 4 900 / 6 100 |
| `hit_setup` | `dh_obj`, `dh_pair` | Z: Die Takte der zwei Rechtecke (B ab, C breit; D ab, E breit) treffen sich nicht; sonst das Fenster, in dem beide auf den Takten des Playfields sind (32–223, höchstens 8 breit): wo es in den Punkten jedes beginnt (`hit_ka`/`hit_sa`, `hit_kb`/`hit_sb`: Byte, Bit) und die Bits seiner Takte (`hit_w`). | 500 / 700 |
| `hit_wide` | `dh_obj`, `dh_pair` | Die Punkte von Byte A einen Takt pro Bit in DE und weiter (Größe C: 1, 2 oder 4 Takte pro Punkt, aus `ov_exp2`, `ov_exp4`: Tabellen, die `init_tables` macht), danach eine Null. | |
| `hit_line` | `dh_obj`, `dh_pair` | NZ: Die Punkte von `hit_a` und `hit_b` treffen sich im Fenster: die zwei Bytes jedes ab seinem Anfang mit `bsla de,b` verschoben (Z80N, 8 Takte), miteinander und mit `hit_w` ver-UND-et. | |

## display.asm: die Tests gegen das Playfield (und das alte Strahlmodell)

Der größte Teil dieser Datei ist das vollständige taktgenaue Modell des DLI (`op`, `bm_events`,
`bm_draw`, `rec_set`, `p3_scan`, `bm_wsync`, der Körper von `collide` des Strahls…), zum
Nachschlagen behalten und nur mit `-DBEAM` assembliert. Immer assembliert:

| Routine | aufgerufen | was und wie | A / B |
|---|---|---|---|
| `pf_under`, `pf_bank`, `pf_edge`, `pf_none` | das Strahl-Display (`-DBEAM`) | Ist die Zeile des Sprites (Bits D ab Bit 7, Position E, Größe A: 1, 2 oder 4 Takte pro Bit) auf Zeile `bm_line` über dem Ufer, der Kante oder einem von beiden, Punkt für Punkt? Findet den Datensatz der Zeile (`pf_line`), dann geht es ihre Läufe ab (`pf_size`). Das Spiel benutzt sie nicht mehr. | |
| `pf_line` | `pf_bank`, `pf_edge` | HL = der Datensatz von Zeile `bm_line` (Carry: eine Flusszeile). | |
| `pf_size`, `pf_v1`, `pf_v2`, `pf_v4` | `pf_*` | Die Läufe unter dem Sprite: Ein Lauf, der die Takte des Sprites überlappt, wird mit `span_masks` gegen seine Bits getestet (D: die Seite der Masken); eine Variante pro Größe (N Verschiebungen machen aus einem Taktversatz einen Bitindex). | |
| `collide` (`.add`, `.pair`, `.overlap`, `.entry`) | das Strahl-Display (`-DBEAM`) | Eine Liste der Sprites auf einer Zeile (Bits, Position, Größe) und der Punkt-für-Punkt-Test der Überlappung zweier davon; das Spiel benutzt ihn nicht mehr. | |
| `bm_hitclr` | `display` | HITCLR: die Kollisionsbits gelöscht. | 1 500 / 1 700 |
| `init_line_tables` | `tv_setup` | Pro Scanline: die Zyklen von ANTIC an ihrem Anfang (`line_start`) und die nach ihrem Zeichnen übrigen (`line_after_draw`); nur das `-DBEAM`-Modell liest sie jetzt. | |

## sprites.asm: Sprites, der Copper, `apply`, das Panel

| Routine | aufgerufen | was und wie | A / B |
|---|---|---|---|
| `build_sprites` | `main_frame` | `ob_list` (die Objekte); das Flugzeug, seine Kugel, der Panzer, die Rakete des Hubschraubers, die Granate (in der Reihenfolge, in der `drawRiver` sie zeichnet, die letzte oben): jedes das beim Start gemachte Muster seines Frames (`pl_plane`, `pl_tank`, `pl_shell`, `pl_bullet`, `pl_missile`) an seiner Position, `pl_sprite`; `pl_keep` sichert ihre Attribute, die die Frames eines Resets (`busy`) wieder zeigen (`pl_again`); `build_copper`. | 1 000 / 1 100 |
| `pl_sprite` | `build_sprites` | Muster A ($FF: keines) auf Zeile D (keines unter dem Fluss), Position E, Paletten-Offset C: seine 5 Attributbytes in `sprite_list` (X = 2·(x − 52), 9 Bit; Y; der Offset; das Muster; 4 Bit, das halbe Muster). | ~100 pro Sprite |
| `ob_list` | `build_sprites` | Pro Eintrag von `ds_objs` seine Zeilen aus `ds_objf` (alle): sein beim Start gemachtes Bild über die Adressen von Form und Farbe der obersten Zeile gefunden (`obj_lookup`; nicht gefunden: `ob_miss`, nicht gezeichnet), ein Sprite pro 16 Zeilen (`ob_attr`: X = 2·(x − 52), Y, die Bank, 4 Bit, das halbe Muster, die Skalierung für doppelte oder vierfache Breite), keines für ein Stück, dessen erste Zeile unter dem Fluss liegt. | 5 700 / 6 400 |
| `build_copper` | `build_sprites` | Nur wenn die Norm gewechselt hat (`cp_built` 0, `tv_setup`) oder die Farben aus- oder angingen (`colour_bank` 0 oder nicht, gegen `cp_bank_on`): die nach dem Grau der Anzeige wiederhergestellten Ufereinträge (`CP_RESTORE`: ihre Farben, schwarz solange die Farben aus sind), dann `copper_start` und der Teil der Anzeige (`copper_panel`) in die Liste, das End-WAIT. `cp_full` = 1. In bank_colours.asm. | 100 / 100 |
| `apply` | nach `wait_frame` | Der Scroll von Layer 2 (NR $17), die Attribute der Sprites (Port $57, OTIR 5 pro Sprite; die überzähligen des vorigen Frames versteckt), die Farben von Granate, Panzer und Flugzeug (Sprite-Palette), die Farben 0, 2, 3 von Layer 2, sein Clip-Fenster (während Layer 2 nach einem Reset gelöscht wird, ab dessen zweitem Frame: nur die Zeilen des Panels, `l2_hidden`; `l2_clip_y2` die letzte Zeile des Fensters aus `tv_setup`), `panel_frame`, der Copper: gestoppt, die ganze Liste gesendet, wenn `cp_full`, sonst nur das X-Scroll-Byte der Laufschrift, neu gestartet (Modus %11). Der Bildschirm aus nach langem Leerlauf (IDLE_TIME). Nicht in den Zahlen oben. | — |
| `panel_frame` | `apply` | Das Panel: nur die Positionen, die `panel_put` aufgelistet hat (`pf_dirty`; alle nach der Kopie von `start_attract` und `tv_setup`), jede aus `.cells` (die Zelle ihrer linken Hälfte; das erste Zeichen der Zeile nur seine rechte Hälfte), 2 Zellen der Kachel 2·Code + Hälfte und die Farbbits als Paletten-Offset. Die Laufschrift (Hälfte h bei 8h − X0, X0 = 16·TEXT_LO + 38 − 2·FINE_SCROLL): ein Ring in Kartenzeile 26 (Hälfte h in Spalte h mod 40; nur die seit dem letzten Frame neuen Hälften geschrieben, `.ring_write`; alle 40 nach einem Sprung), der X-Scroll X0 mod 320 (9 Bit: `CP_XSCROLL_HI_BACK`, `CP_XSCROLL_BACK`); das Clip-Fenster der Tilemap rechts S = X0 & 7 Punkte kürzer (die Spalte, die umläuft); Sprite 70 (Muster 20, Paletten-Offset 6) bei X 320 − S mit Hälfte h0 + 40 (seine 64 Byte geschrieben, wenn sie sich ändert: `.spr_pattern`). Die Sprites von Nadel und Logo. | ~1 700 die Laufschrift, ~200 das Panel, ~1 400 Nadel und Logo |

Daten: `copper_start` (Index 1 der Palette von Layer 2, ein NOP, wo NR $4A war (die Farbe von T), Y- und X-Scroll der Tilemap 0: ihre Zeilen die des Bildschirms, nichts in den Reihen außerhalb der Anzeige), `copper_panel_ntsc`/`_pal` (in Seite 7, copper_panels.asm: `tv_setup` kopiert einen über Slot 2 nach `copper_panel`; derselbe Aufbau, also gelten die Abstände für beide: Zeile 200: der Y-Scroll der Tilemap für die erste Reihe der Anzeige (`CP_PANEL_Y`, von `tv_setup` gesetzt), die Farben 0–10 von Layer 2 schwarz (`CP_COLOURS`: auch die Ufereinträge, da die Reihen unter der Anzeige alte Flusszeilen zeigen) und das Fenster der Sprites ab Zeile 215 abwärts (`OBJ_LAST` + 1, unter den Zeilen jedes Objekts; Nadel und Logo tiefer); 201: grau (`COPPER_GREY`, von `tv_setup` gesetzt); der Y-Scroll der Tilemap pro Reihe der Anzeige; Zeile 230 (240 PAL): die Farben 0–10 zurück (`CP_RESTORE`: die des Ufers durch `build_copper`, die von Kante und Wasser durch `apply`, `CP_EDGE_BACK`); Y- und X-Scroll der Laufschrift (`CP_XSCROLL_HI_BACK`, `CP_XSCROLL_BACK`); bei `wait_line`: das Fenster der Sprites wieder das des Flusses). `apply` schickt die Bytes von der Kante bis zum X-Scroll (`.cp_send`), wenn die Liste nicht ganz geschickt wird.

## panel.asm (Seite 6): die Zeichen des Panels

| Routine | aufgerufen | was und wie |
|---|---|---|
| `panel_put`, `panel_put_de` | die Schreiber des Panels | Ein Zeichen ins Panel bei HL (DE): nichts, wenn es schon da ist; sonst geschrieben und seine Position in `pf_dirty` aufgelistet (60 oder mehr: alle). |
| `print_bcd` | `show_score`, `show_other_score`, `show_high_score`, `show_bridges`, das Spielende | B BCD-Bytes bei HL als Ziffern bei DE, '0' = C, führende Nullen leer; nichts im Attract-Modus. Pro Stelle (Punkte, Rekord oder Punkte des anderen, Brücken, Brücken des anderen) behält es die Basis der Ziffern und die gedruckten Bytes (`pb_cache`) und kehrt sofort zurück, wenn sie gleich sind. |
| `show_lives` | `prepare` und andere | Die Symbole der Leben; nichts, wenn ihre Zahl die zuletzt gedruckte ist (`sl_last`). |
| `pb_forget` | `start_attract` | Die zuletzt gedruckten Zahlen vergessen (alle neu gedruckt). |

Die Stellen, die sich überlappen, vergessen die der anderen: die Leben und die Brücken des
anderen Spielers, der Text des Spielendes an der Stelle der Leben.

## sound.asm: der Soundtreiber und POKEYs Samples

| Routine | aufgerufen | was und wie | A / B |
|---|---|---|---|
| `sound_driver` | `vbi` | B2A5–B3D8: der Treiber des Originals: Kanal 1 der Startpiep, Ereignisgeräusche, der Piep bei wenig Treibstoff oder der Motor; 2 eine Explosion oder die Rakete; 3 Schießen oder ein Bonusleben; 4 die Granate. Schreibt AUDF/AUDC von POKEY (`pokey_audf`, `pokey_audc`). | 770 / 930 |
| `sound_init` | `restart` | Die DACs an (NR $08), Ring und Kanäle still, `sound_init7` (Seite 7: der AY, POKEYs Tabellen, der DMA programmiert), dann der DMA eingeschaltet ($87), sobald Seite 12 wieder gemappt ist. | |
| `pokey_frame` | `main_frame` | `ay_frame` (die reinen Töne zum AY; alle vier dort: der Ring einmal still gemacht, `snd_idle`, und fertig), dann wie viele Samples: die Zeilen bis `wait_line` (NR $1E/$1F), wo der DMA ist (seine Adresse zurückgelesen), bis `SND_LEAD` (760) voraus, mindestens `SND_MIN_LEAD` (200), höchstens `SND_CAP` (700). Dann: `snd_fill` (der Abschnitt auf 0), jeder Kanal, der nicht auf dem AY ist: Lautstärke × die Verstärkung des Frames (`snd_gain_set`: 8, oder 7–4, wenn die Lautstärken zusammen über 31 liegen, `mul d,e`) als konstanter Pegel (nur Lautstärke, oder AUDF ≤ 4: die Hälfte) oder `pk_channel` (seine Wechsel als + und − in den Ring), dann `snd_sum` (die laufende Summe macht die Pegel). Seiten 14–15 währenddessen bei $0000 (der 17-Bit-Zähler). | 2 400 / 2 500 |
| `snd_gain_set` | `pokey_frame` | `snd_gain`: 8 pro Lautstärkestufe, oder das Höchste, das die Pegel bei 255 oder darunter hält, wenn die Lautstärken der Kanäle am DAC zusammen über 31 liegen (7 bis 36, 6 bis 42, 5 bis 51, sonst 4). | ~150 |
| `snd_fill` | `pokey_frame` | DE Bytes von A ab HL im Ring (zwei Abschnitte am Umlauf), jeder per PUSH von seinem Ende abwärts (SP gesichert). | 2 800 / 2 400 |
| `snd_sum` | `pokey_frame` | Die laufende Summe über DE Samples: `add a,(hl) / ld (hl),a / inc l`, 8-fach abgerollt, für den Rest an der richtigen Stelle betreten (selbstmodifizierter `jp`), Seite für Seite im Ring. ~8 400 Takte für ~270 Samples: etwa 31 pro Sample. | 8 600 / 7 300 |
| `sound_random` | `sound_driver` | RANDOM für die Tonhöhe eines Rauschens (nicht `random_read`, das die Prüfungen zählen). | |

Der Ring: 1024 Byte bei $7C00 (Seite 12), auf 1K ausgerichtet, vom zxnDMA im Burst-Modus mit
Vorteiler 55 (15 909 Hz) an Port $DF gesendet, an seinem Ende neu startend. Pegel 0–240.

## sound_pulses.asm, sound_handlers.asm: die Wechsel eines Kanals

| Routine | aufgerufen | was und wie | A / B |
|---|---|---|---|
| `pk_channel` | `pokey_frame`, pro Kanal mit AUDF ≥ 5 | Bereitet vor: die Teilwerte der Lautstärke (× 0–3 von 4, für einen Wechsel innerhalb eines Samples), die Schritte der Periode für die 4- und 5-Bit-Zähler (`snd_mod15/31`), die Periode als Samples und Takte × 64 in die Schleifen gepatcht; der erste Impuls (`CH_D`, `CH_F`); K = Impulse in diesem Frame (eine 12-Bit-Division, abgerollt: die Ticks liegen unter 4 × SND_CAP < 4096); dann die Schleife für seine Art. | 1 200 / 2 800 |
| `pk_tone` | `pk_channel` | Ein Ton: Der Ausgang wechselt bei jedem Impuls. | |
| `pk_noise` | `pk_channel` | Rauschen: das nächste Bit des 17-Bit-Zählers bei jedem Impuls (die Bits der Reihe nach, bei $0000 gemappt); seine Wechsel am Anfang des Samples (+ oder − die Lautstärke, kein Anteil über zwei Samples). | 4 600 / 12 900 |
| `pk_g4` | `pk_channel` | Der 4-Bit-Zähler, vom 5-Bit-Zähler durchgelassen (AUDC 010: die Rakete des Hubschraubers): beide Zähler als eine Zahl m (`g4_crt`: m = b + 31 ((e − b) mod 15)), ein Impuls m + s, `g4_tab` pro m ($FF nicht durchgelassen, sonst das Bit); die Zähler am Ende aus m zurückgewonnen. Wechsel am Anfang des Samples. | 0 / 1 400 |
| `pk_other` + `pk_handlers` (`adv31`, `adv15`) | `pk_channel` | Die anderen Arten über Handler. | |
| `pk_on`, `pk_off`, `pk_part*` | die Schleifen | Der Wechsel eines Tons oder des Rests bei einem Impuls: Das Sample bekommt den Wechsel abzüglich des Teils vor dem Wechsel, das nächste Sample diesen Teil (kein Brummen durch ganze Samples; Rauschen und Rakete wechseln stattdessen am Anfang des Samples). | |
| `pk_done` | die Schleifen | Der Rest der Ticks des Frames in `CH_D`, `CH_F`, der Ausgang behalten. | |

## sound_ay.asm (Seite 7), sound_ay_run.asm (Seite 6): die reinen Töne auf dem AY

| Routine | aufgerufen | was und wie | A / B |
|---|---|---|---|
| `ay_init` | `sound_init7` | TurboSound an, der erste AY mono, nur Töne, still. | |
| `sound_init7` | `sound_init` | `ay_init`, POKEYs Tabellen in Seite 1, `snd_mod15/31`, der DMA programmiert (nicht eingeschaltet). | |
| `ay_frame` | `pokey_frame` | Für jeden POKEY-Kanal mit reinem Ton (AUDC 101x oder 111x, nicht nur Lautstärke, Lautstärke ≠ 0): sein eigener AY-Kanal (`ay_slot`: 1 A des zweiten AY, 2 A des dritten, 3 B des ersten, 4 C des ersten), die Periode N = (AUDF + 1) × 3,454 (PAL) / 3,422 (NTSC) über `mul d,e`, die Lautstärke über `ay_vol`, das Tonbit des Mixers; `ay_mask` sagt `pokey_frame`, sie zu überspringen. Die Register dieses Frames in `ay_q` (3 Frames × 33: die 0–10 der drei Chips, der Reihe nach über `ay_qi`), hinaus die von vor 2 Frames. | 2 200 / 2 800 |
| `ay_out` | `ay_frame`, `ay_init`, `ay_quiet` | Die Register 0–10 der drei AYs ab HL (der erste bleibt ausgewählt, B = $FF). | 3 400 / 3 400 |
| `ay_quiet` | `pokey_frame` (Ton aus), `ay_init` | Alles still (Lautstärken 0, Mixer $3F). | |

`sound_ay_run.asm` liegt in Seite 6, nicht 7, damit `pokey_frame` nie Seite 7 über den Ring
mappt (siehe NOTES: das Knistern).

## panel_init.asm (Seite 7, beim Start)

| Routine | aufgerufen | was und wie |
|---|---|---|
| `panel_init` | `start` (Seite 7 bei $6000) | Die Zeichensätze des Atari dort gebaut, wo das Spiel sie baut (OS-Schrift aus `font.inc`, die Symbole der Cartridge), jedes Zeichen als zwei Kacheln (Kacheln 0–127 die des Panels, 128–255 die der Laufschrift) in Seiten 10–11, die Palette und die Register der Tilemap (NR $6B/$6C/$6E/$6F, Clip), die Sprite-Muster von Nadel und Logo, `edge_lo`/`edge_hi` (der erste und letzte gesetzte Punkt jedes Bytes, für den Kantentest). |
| `pl_pics` | `panel_init`, vor `obj_pics` (Seite 7) | Die 10 Frames des Flugzeugs (14 Zeilen), die 8 des Panzers (11 Zeilen) und die 7 der Granate (16 Zeilen) aus ihren Zeigertabellen im ROM, wie `prepare` sie in den Player-Missile-Speicher kopiert: je ein 4-Bit-Muster (ein Punkt: 2 Pixel mit Wert 1), geteilt von Frames mit einer Adresse, keines für ein ganz leeres ($FF); die Kugel (8 Zeilen zu einem Punkt) und die Rakete des Hubschraubers (eine Zeile zu 4 Punkten). Muster ab 0 (20 davon). |
| `obj_pics` | `panel_init` (Seite 7) | Die Bilder der Objekte: für Typen 7–15 die Arten, die sie haben können (ihre eigene, die von `ROM_NEXT_KIND` unter $0C, die der Explosion aus 2 und 3), jede auch gespiegelt, height + 1 Zeilen; 58 Bilder als 4-Bit-Muster ab 24, der Wert eines Punkts der Platz der Farbe seiner Zeile in Palettenbank 14 (Typen 12, 15) oder 15 (die anderen); `obj_head`/`obj_e` für `obj_lookup`. |

## load_rom.asm (Seite 7)

| Routine | aufgerufen | was und wie |
|---|---|---|
| `load_rom` | `start` (nicht in Test-Builds) | Öffnet River_Raid.rom im Ordner des Programms über esxDOS (F_OPEN, F_READ, F_CLOSE; über den Kurznamen, wo lange Namen nicht sichtbar sind) und liest seine 8192 Byte nach $A000 (Seite 5). Ohne sie: ein roter Rand und ein Halt. Nur auf einem echten Next geprüft. |

## Includes

- `vars.inc`: die RAM-Adressen der Spielvariablen im Atari (die Namen des Originals).
- `palette.inc`: die Atari-Palette als Next-Farben (von `tools/mkpalette` gemacht).
- `random.inc`: die Spalten des RANDOM-Schritts (`tools/mkrandom`).
- `font.inc`: die OS-Schrift (`tools/mkfont`, die von AltirraOS, mit ihrem Hinweis).
- `poly.inc`, `poly17.bin`: POKEYs 4-, 5- und 17-Bit-Folgen (`tools/mkpoly`).

## Was man wissen sollte, bevor man Code ändert

- **Selbstmodifizierender Code** ist in heißen Schleifen üblich: gepatchte Direktwerte und Sprungziele (`.bx1/.be1/.bx2/.be2/.ex1/.ex2/.s1/.s2/.pv/.pv_bits/.pv_end/.pv_x` von `ds_edge_test`; `.mode/.x0a…/.x1d/.bits/.fn` von `dh_pf`; `.jp` von `snd_sum`; `.pf/.pq` der `pk_*`). Eine Variante muss Byte für Byte geprüft werden (ein übrig gebliebenes `add a,a` hat einmal den Ton verdoppelt).
- **Abgerollte Einsprungpunkte**: `snd_sum` springt für den Rest in die Mitte eines `rept`-Blocks.
- **Slot 2** ist ein Arbeitsfenster: Eine Routine, die dort eine Seite braucht, mappt sie und stellt nichts zurück; der nächste Benutzer mappt seine eigene. **Slot 3** muss Seite 12 bleiben, solange der Ton spielt.
- **Tabellen sind seitenausgerichtet**, damit `ld h,high table / ld l,index` der Zugriff ist: `span_masks`, `span_class`, `edge_lo/edge_hi`, `obj_head`, `ov_exp2`/`ov_exp4`, `eg_*`, `bg_*`, die Palette.
- **Die Prüfungen**: Nach jeder Änderung vergleicht `nxcheck` jedes Frame Zustand und Bildschirmspeicher, die Uferfarbe pro Zeile, die Objekte wie gezeichnet, die Liste und den Speicher des Coppers und am Ende das Bild mit dem C++-Port. Der volle Satz dauert ~25 Minuten auf 2 Kernen (HANDOFF.de.md, *Methode*). Ein misslungenes Assemblieren hinterlässt die alten Seiten: zuerst die Ausgabe des Builds prüfen.
- **Messen**: `NXHISTALL=Datei` (alle Frames) oder `NXHIST=Datei` (ein Frame) und `tools/prof.py`; `NXSLOW=T` listet die Frames über T Takten. `NXHISTAPPLY=Datei` tut dasselbe für `apply` (ab dem Ende von `wait_frame`) und druckt dessen Mittel und Maximum; `tools/prof_local.py build/test.sym Datei Frames [Routine…]` teilt die Zeit auch nach lokalen Labels auf (`ds_edge_test.row`, `panel_frame.mod`, …). Die schwersten Frames: `-stress` mit `NXBRIDGE=80 NXGHOST=1 NXGAME=1`.
- **apply** (~7 400 pro Frame, nicht in den Tabellen oben): die Laufschrift ~1 700 (der X-Scroll mod 320 per Subtraktion ~650 davon), Nadel und Logo ~1 400, das Panel ~200 (nur was sich geändert hat), die Attribute der Sprites ~1 800, die Liste des Coppers ~1 200.
- **Eine Neufassung** stellt man am schnellsten durch einen Test-Build sicher, der den neuen Weg jedes Frame neben dem alten ausführt und zählt, wo sie sich unterscheiden (so gemacht für die Kollisionszeilen, das Platzieren, die Cursor), und lässt dann den alten fallen.
