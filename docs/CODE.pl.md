# Kod źródłowy portu na ZX Spectrum Next w asemblerze, plik po pliku

[English](CODE.md) | [Русский](CODE.ru.md) | [Українська](CODE.uk.md) | [Deutsch](CODE.de.md) | Polski | [Italiano](CODE.it.md) | [Español](CODE.es.md) | [中文](CODE.zh.md) | [日本語](CODE.ja.md)

Dla programistów Z80, którzy chcą czytać kod albo go przyspieszyć. Dla każdego pliku: co w nim
jest, co robi każda procedura, kto i kiedy ją wywołuje, jak działa i ile kosztuje. Dlaczego
zrobiono to tak, opisują [NOTES.pl.md](NOTES.pl.md) i [HANDOFF.pl.md](../HANDOFF.pl.md); obraz
prostymi słowami — [HOW_IT_WORKS.pl.md](HOW_IT_WORKS.pl.md).

To jest kod Next (`src/`). Port na TS-Conf ([tsconf/CODE.pl.md](../tsconf/CODE.pl.md)) używa
kopii jego części z grą: `play.asm`, `game.asm`, `river_gen.asm`, `spans.asm`, pliki
`display*.asm`, `panel.asm` i `sound_driver` są tu opisane dla obu (nieliczne zmiany TS-Conf
wymieniono tam); reszta tutaj — obraz, sprite'y, Copper, panel, dźwięk przez DAC, start — jest
własna Next. Tabela różnic obu maszyn jest na początku tsconf/CODE.pl.md. Własny sprzęt Next,
jak używa go ten kod: instrukcje Z80N (`nextreg`, `mul`, `bsla`), sloty 8K, Layer 2 kolumnami,
Copper, tilemapa, sprite'y ze skalowaniem, zxnDMA i DAC, trzy AY, 50 i 60 Hz.

## Liczby

Czasy to takty rdzenia Next przy 28 MHz na klatkę, średnio, z histogramu nxcheck
(`NXHISTALL=plik`, potem `python3 tools/prof.py build/test.sym plik 60`, podzielone przez liczbę
klatek), na wersji testowej bez pamięci ekranu, jak w grze (`-DNOSCREEN`, `NXNOSCREEN=1`). Dwa
przebiegi:

- **A**: PAL, bot 1, 3 000 klatek od startu (zwykły początek gry): średnio ~102 000 na klatkę, najwyżej ~158 000;
- **B**: `-stress` od mostu 80, PAL, 6 000 klatek (`NXBRIDGE=80 NXGHOST=1 NXGAME=1`: wszystkie sloty zajęte, pełny gaz, ciągły ogień): średnio ~159 000, najwyżej ~198 000 (NTSC ~160 000 / ~202 000; przy 14 MHz NTSC ~131 000 / ~165 000 z ~240 000).

Klatka ma ~567 000 taktów w PAL i ~481 000 w NTSC (przy 14 MHz połowę). `apply` (a z nim
`panel_frame`) działa po mierzonej pracy (pod przewijanym napisem) i nie ma go w tych liczbach:
~7 400 na klatkę. Czas procedury to tylko jej własne instrukcje: procedury, które wywołuje, są
liczone pod własnymi nazwami.

Według części (A / B):

| część | A | B |
|---|---|---|
| wyświetlanie: rozmieszczanie obiektów i kolizje (`display_simple`, `display_objs`, `display_hits`, `sp_*`) | 40 400 | 54 300 |
| dźwięk (`pokey_frame`, `snd_*`, `pk_*`, `ay_*`, `sound_driver`) | 26 900 | 39 300 |
| nowe linie rzeki (`river_gen`, `render_line`, `rl_fill`, `span_line`, `push_line`) | 19 500 | 45 400 |
| sprite'y i lista Coppera (`build_sprites`, `ob_*`, `pl_*`, `build_copper`) | 9 900 | 15 000 |
| logika gry i reszta (`prepare`, `main_loop`, `move_objects`, `random_step`, wypisywanie panelu, …) | 9 400 | 10 500 |

Najdroższe procedury (A / B):

| procedura | A | B | plik |
|---|---|---|---|
| `display` (własny kod) | 10 900 | 12 600 | display_simple |
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
| `pokey_frame` (własny kod) | 2 500 | 2 700 | sound |
| `draw_line` | 900 | 2 300 | river_gen |
| `pk_g4` | 0 | 1 400 (~9 000 w klatce, gdy brzmi rakieta) | sound_pulses |
| `dh_lists` | 1 300 | 1 300 | display_hits |
| `hit_setup` | 500 | 700 | display_hits |

Najcięższa klatka B (~198 000): dźwięk do ~60 000 (szum i rakieta na DAC, ~180 impulsów),
rozmieszczanie i testy krawędzi (`display`, `ds_obj`, `ds_edge_test`) ~30 000, kolizje
(`dh_pf`, `dh_bits`, `dh_obj`, `hit_*`) ~25 000, nowe linie rzeki ~25 000.

(`prof.py` bierze nazwę procedury z najbliższej globalnej etykiety poniżej adresu, więc etykieta
danych tuż przed kodem może zabrać jego czas; symbole strony 12 pod $6000-$7FFF oznaczają
`panel_init` w stronie 7 pod tymi samymi adresami, który działa raz przy starcie.)

## Pamięć podczas działania kodu

Sloty 8K ($0000, $2000, … $E000) i strony w nich:

| slot | adres | zwykle | kto przemapowuje |
|---|---|---|---|
| 0–1 | $0000–$3FFF | 30–31: RAM Atari pod adresami oryginału | `pokey_frame`: 14–15, 17-bitowy licznik POKEY (`poly17.bin`), gdy robi próbki |
| 2 | $4000–$5FFF | różnie: brak stałej strony | `render_line`: 18–27 (Layer 2, strona na 32 kolumny); `display`, `span_line`, `spans_clear`: 28 (`SPAN_PAGE`, odcinki linii); `panel_frame`: 11 (mapa tilemapy); `panel_init`: 10, 11 |
| 3 | $6000–$7FFF | 12: bufory (`copper_list`, `ds_objs`, `sprite_list`, `ov_exp2`/`ov_exp4` (punkty bajtu poszerzone, `dh_obj`), przerwy krawędzi `eg_*` (`ds_edge_test`), pierścień DAC pod $7C00) | tylko przy starcie: 7 (`panel_init`, `sound_init7`, `load_rom`). **Nigdy, gdy gra dźwięk**: DMA czyta pierścień przez ten slot |
| 4 | $8000–$9FFF | 4: kod | — |
| 5 | $A000–$BFFF | 5: kartridż, wczytany z River_Raid.rom | — |
| 6 | $C000–$DFFF | 6: kod | — |
| 7 | $E000–$FFFF | 1: zmienne, tablice (wśród nich przerwy brzegu `bg_*`), stos (od $0000 w dół, ponad $FF00) | — |

Strona 4 kończy się na ~$9E2C (z $A000), strona 6 na ~$DD53 (z $E000), strona 7 na ~$6913
(wersja to wypisuje): usunięty rozkład DLI zostawił trochę miejsca. Przenoszenie kodu między
stronami to sposób, w jaki wcześniej znajdowano miejsce (`display_objs.asm` stał w przerwie przed
wyrównaniem palety w stronie 4, teraz na jej końcu).

Przerwania są wyłączone przez cały czas (`di` na starcie): klatkę wyznacza odpytywanie linii
rastra (`wait_frame`), dźwięk DMA, kolory linia po linii Copper.

## Klatka

`main_frame` (river_raid.asm), co klatkę:

1. Utrwala to, co pokazuje obraz tej klatki (`scroll`, kolory krawędzi i wody, gracz), `read_input`, CAPS + 1 (`restart` w drugim standardzie).
2. Zwykle: `prepare` → `display` → `build_sprites` → `main_loop` → `vbi`. Podczas resetu (`busy`, klatki, w których oryginał czyści pamięć: 13 NTSC, 8 PAL): `display` → `build_sprites` → `clear_layer2_page` → (`finish_reset` w ostatniej) → `vbi`.
3. `pokey_frame`: próbki klatki do pierścienia DAC i tony AY.
4. `wait_frame`: odpytuje aktywną linię obrazu (NR $1E/$1F) do `wait_line` (208 NTSC, 220 PAL), pod przewijanym napisem, gdzie na ekranie nic się nie zmienia.
5. `apply`: wszystko zbudowane zaczyna działać naraz (przewijanie i kolory Layer 2, atrybuty sprite'ów, kafelki panelu, lista Coppera).

Z włączonym T (`tm_show`) każda z tych części najpierw ustawia kolor ramki (`TM_COLOUR`: wywołuje `tm_colour` tylko przy włączonym T; wyłączone kosztuje ~30 taktów na część): pomarańczowy `apply`, szary `prepare` (i `clear_layer2_page` podczas resetu), czerwony `display`, żółty `build_sprites`, niebieski `main_loop`, purpurowy `push_line` (nowa linia rzeki, wewnątrz `main_loop`), biały `vbi`, błękitny `pokey_frame`, czarny pozostały czas. `push_line` ustawia purpurowy i z powrotem niebieski.

Kolejność ma znaczenie: `display` używa stanu, który zostawił `main_loop` poprzedniej klatki
(tak jak DLI Atari pokazuje stan poprzedniej klatki), a `build_sprites` tego, co zostawił
`display`.

---

## river_raid.asm: klatka, start, pamięć

Plik główny: układ pamięci, `include`, składanie stron (`mmu`/`org`), zmienne strony 1 i bufory
strony 12, zaczepy wersji testowych.

| procedura | wywołanie | co i jak |
|---|---|---|
| `start` | przy ładowaniu | `load_rom` (nie w wersjach testowych), ziarno RANDOM z R, 28 MHz, mapowanie stron, `init_tables`, `init_video`, `panel_init` (strona 7 zmapowana), potem `restart`. |
| `restart` | `start`; CAPS + 1 | Maszyna „włączona” w standardzie `tv_pal`: `tv_setup`, Layer 2 wyczyszczony (wszystkie 10 stron naraz), `sound_init`, `start_attract`, przechodzi do `main_frame`. |
| `main_frame` | co klatkę | Zob. *Klatka*. ~340 własnych taktów. |
| `wait_frame` | `main_frame` | Aktywnie czeka na NR $1F wobec `wait_line`. Jego czas to bezczynność, nie praca. |
| `init_tables` | `start` | Raz: tablice: `ring_lo`/`ring_hi` (160 linii pamięci ekranu po kolei), `span_class` (kolor bajtu, jeśli jego 4 piksele są jednakowe), `span_init` (maski), pusta lista Coppera. |
| `tv_setup` | `restart` | Ustawienia standardu: NR $05 50/60 Hz, `init_line_tables`, `wait_line`, mapa losowa, część panelu Coppera (`copper_panel_ntsc`/`_pal` skopiowane, szarość wpisana, `COPPER_GREY`), pierwsze przewinięcie Y tilemapy, okna przycinania (Layer 2 do ostatniej szarej linii panelu, sprite'y, tilemapa). |
| `init_video` | `start` | Czarna ramka, bez ULA, globalna przezroczystość $E3, Layer 2 320×256×8 w banku 9, kolejność warstw (tilemapa nad sprite'ami nad Layer 2), palety: 4 wpisy Layer 2, 128–255 sprite'ów = kolory Atari, NR $15 z przycinaniem sprite'ów w trybie nad ramką. |
| `test_ghost` | wersje testowe, po `display`, gdy `test_ghost_on` | NXGHOST z nxcheck: kolizje samolotu i paliwo ustawione tak, by nie mógł się rozbić. |

Poza tym: `span_rec` (makro: HL = 32-bajtowy rekord linii rzeki A w SPAN_PAGE), `palette`
(kolor Atari → kolor Next, 256 bajtów) i `random_columns`, zmienne `TEST` (`start_bridges_hi`,
`snd_passed`, `test_ghost_on`).

## play.asm: pętla główna (A197–A6EA)

Logika gry, którą oryginał wykonuje w pętli głównej, tak jak ma ją port C++. Stan żyje pod
adresami RAM oryginału.

| procedura | wywołanie | co i jak | A / B |
|---|---|---|---|
| `main_loop` | `main_frame` (nie podczas resetu) | A197–A6EA: czyta RANDOM (`random_read`), samolot (`fly_plane`) albo wybuch/powrót (`respawn_or_game_over`), `drive_tank`, `move_objects`, potem `main_loop_end`. Wraca wcześniej, gdy zaczyna się reset. | 620 / 620 |
| `main_loop_end` | `main_loop`, `finish_reset` | A5B7–A6EA: rakieta i pocisk czołgu (`move_missile`, `move_shell`), `scroll_river`, START/SELECT. | 180 / 170 |
| `scroll_river` | `main_loop_end` | A6FD: prędkość dodawana dwa razy na klatkę do ułamka; każde przeniesienie to jeden `push_line` (nowa linia rzeki: droga część, zob. river_gen). | 140 / 160 |
| `fly_plane` | `main_loop` | A3E9–A5B4: paliwo, sterowanie (`steer`), prędkość (`change_speed`), strzał, pocisk (`move_bullet`), skutki kolizji: `explode` (obiekt zestrzelony lub staranowany: punkty), `crash`. | 290 / 480 |
| `steer`, `change_speed` | `fly_plane` | X samolotu z ułamkiem poniżej piksela; prędkość $40–$FE. | |
| `explode` | `fly_plane` | A4E0–A589: slot staje się wybuchem, punkty (BCD), premia za most. | |
| `crash` | `fly_plane`, `explode` | sub $B1C0: samolot się rozbija, z dźwiękiem zdarzenia; `section_checkpoint`. | |
| `draw_bullet`, `move_bullet` | `fly_plane`, `crash` | 8 wierszy pocisku do pamięci missile 2 (tylko `-DBEAM`; inaczej `draw_bullet` od razu wraca). | 380 / 520 |
| `new_game`, `reset` | START, koniec gry, powrót | sub $B0F1: rzeka i obiekty zresetowane (`restore_checkpoint`), `clear_screen_memory` (tylko z pamięcią ekranu: wersje testowa i promienia), `busy` = 13 lub 8 klatek. | |
| `clear_layer2_page` | `main_frame` podczas `busy`, `restart` | Dwie z 10 stron Layer 2 czyszczone na klatkę (`l2_clear` liczy); żadnej w pierwszej klatce resetu (`l2_wait`: jej obraz jest jeszcze pokazywany), a `apply` ukrywa tymczasem wiersze rzeki (`l2_hidden`). Średnio ~1 100 na klatkę w A, ale jedna strona to 8 KB zapisów w klatkach, w których działa. | 1 100 / 570 |
| `finish_reset`, `finish_respawn`, `respawn_or_game_over` | | Po resecie: rzeka biegnie dalej od punktu kontrolnego, następny gracz albo koniec gry. | |
| `swap_players`, `update_high_score`, `set_up_game`, `select_game` | | Dwóch graczy, rekord z bajtami kontrolnymi, numer gry. | |
| `show_lives`, `show_score`, `show_bridges`, … | pętla, VBI | Znaki panelu w RAM Atari ($1000). | 620 / 720 |
| `print_bcd` | `show_*` | B086: bajty BCD jako cyfry, wiodące zera puste. | 1 200 / 1 400 |
| `read_input` | `main_frame` (nie w wersjach testowych) | Klawiatura (Q A O P, Space/M, Enter, G, H, CAPS + 1/2), Kempston 1 i 2 oraz pad Mega Drive do bajtów joysticka, przycisku i konsoli Atari. T (przy naciśnięciu) przełącza `tm_show`, wyłączone: kolor zastępczy czarny. | — |

## game.asm: części gry co klatkę i VBI

| procedura | wywołanie | co i jak | A / B |
|---|---|---|---|
| `random_read` | `main_loop` (A205) | RANDOM POKEY: 17-bitowy licznik, jaki jest w punkcie odczytu. Testy liczą te odczyty. | |
| `random_step` | `vbi` | Licznik o klatkę dalej: stałe przekształcenie liniowe (17 kolumn w `random.inc`, NTSC lub PAL), po 4 bity: dla każdego z 4 półbajtów bitów 0–15 3-bajtowy wpis `rnd_tab` (strona 1, 256 bajtów wyrównane: 64 k + 4 v) dodany XOR, kolumna bitu 16 (`rnd_col16`), jeśli ustawiony. Było bit po bicie, ~2 300. | 560 / 560 |
| `rnd_tables` | koniec `tv_setup` | `rnd_tab` i `rnd_col16` z kolumn standardu (`rnd_cols`): każdy wpis to XOR kolumn swojej wartości. | |
| `bank_colour` | `vbi`, `start_attract` | sub $AFD0: odcień brzegu (przełącza się, gdy u góry wjeżdża most). | 200 / 200 |
| `start_attract` | `restart` | Stan trybu demonstracyjnego w jego pierwszej linii (gra 1, bez samolotu). | |
| `draw_logo_and_needle` | `reset`, `start_attract` | Tęcza i wskazówka paliwa do pamięci player-missile, tak jak zostawia je sub $B0F1 (tylko `-DBEAM`; w Next to sprite'y). | |
| `push_line` | `scroll_river`, `start_attract` | Nowa linia rzeki: `next_line` (river_gen) zapisuje jej kawałki w `dl_seg`, potem przy `line_done` rysują z nich `render_line` (Layer 2) i `span_line` (odcinki dla kolizji); z pamięcią ekranu (wersje testowa i promienia, `SCREEN_MEMORY`) bajty linii idą też przez `line_buf` do pamięci ekranu (48 LDI, adres górnej linii o linię wyżej). | |
| `prepare` | `main_frame` | AE99–AF38 na początku klatki: czołg i pocisk, które zeszły pod ekran, kolor pocisku, życia, mosty i punkty na panelu. Kształty do pamięci player-missile ($0B00–$0FFF) tylko w wersji modelu taktów (`-DBEAM`): sprite'y i kolizje Next biorą je z ROM. | ~2 000 (3 000 z kopiami) |
| `drive_tank` | `main_loop` | A21B: czołg na drodze jedzie, strzela przy brzegu rzeki. | |
| `move_objects` | `main_loop` | A26C–A2ED: obiekty w slotach animują się i poruszają (statki i helikoptery zawracają przy krawędzi: flaga krawędzi slotu z wyświetlania). | 2 000 / 3 700 |
| `move_missile`, `move_shell` | `main_loop_end` | Rakieta helikoptera, pocisk czołgu. | |
| `vbi` | `main_frame` | B2A5–B43E: `sound_driver`, licznik klatek, kolory następnej klatki (`bank_colour`), `scroller_step`, `random_step`. W PAL przy końcu gry widzi niektóre wartości sprzed sub $B21A (`vbi_before`). | 420 / 430 |
| `scroller_step` | `vbi`, `start_attract` | B44B: przewijany napis o takt koloru na klatkę w trybie demonstracyjnym, nieruchomy w grze. | |

## river_gen.asm: generator rzeki (A711–AE93)

Linia rzeki po linii, tak jak generuje ją oryginał: 24-bitowy LFSR, sekcje i bloki, szerokości
brzegu i wyspy, ozdoby (domy, góry), drogi i mosty, obiekty stawiane co 16 linii. Jego wynik to
kawałki linii w `dl_seg` (po 4 bajty: bajt, od którego się zaczyna, jego rodzaj, jego dane: 0
krawędź, przesunięcie jej kawałka w tablicy pod $B800; 1 bajty jednej wartości, wartość; 2
wiersz ozdoby, adres jej bitmapy; zakończone bajtem 48) i sloty. W grze nie ma bufora linii:
`line_buf` (48 bajtów, 192 takty koloru po 2 bity; nieczyszczony wcześniej, kawałki idą jeden
po drugim od bajtu 0 do 48) jest pisany tylko z pamięcią ekranu.

| procedura | wywołanie | co i jak | A / B |
|---|---|---|---|
| `next_line` | `push_line` | Jedna linia: `count_lines`, `move_bank`, `change_island`, `scroll_objects`, `place_object`, potem `draw_line`. | 210 / 290 |
| `count_lines` | `next_line` | A711: liczy linie; na początkach bloków i sekcji przygotowuje to, co nadchodzi (`choose_section_width`, `start_decoration`, punkty kontrolne). | 160 / 210 |
| `move_bank` (+ `bank_hit_setup`, `bank_hits_left/right`) | `next_line` | A826: położenie brzegu dla tej linii, bez wjeżdżania w obiekt, który jeszcze się pojawia. | 350 / 570 |
| `change_island`, `choose_section_width` | | Wyspa ku docelowej szerokości. | |
| `draw_line` | `next_line` | Kawałki linii: wypełnienie brzegu (`dl_fill`, `dl_fill_bank`), krawędzie (`dl_edge`, `dl_bank_edge`: 2-bajtowe kawałki z $B800), wiersz ozdoby (`dl_deco_row`, adres jej bitmapy przesunięty), woda; każdy do `dl_seg` ze swoimi danymi, DRAW_POS przesunięty; ich bajty do `line_buf` tylko z pamięcią ekranu. | 900 / 2 300 |
| `dl_fill` | `draw_line` | B bajtów C od DRAW_POS: kawałek rodzaju 1 (same bajty tylko z pamięcią ekranu). | 500 / 1 300 |
| `scroll_objects` | `next_line` | AB76: wszystko o linię w dół; gdy najniższy slot opuszcza ekran, sloty się przesuwają. | 560 / 820 |
| `place_object`, `choose_enemy`, `position_object`, `place_tank` | `next_line` | Co 16 linii nowy obiekt w następnym wolnym slocie; na początku bloku może czołg na drodze. | |
| `step_lfsr` | wiele miejsc | sub $B183: 24-bitowy LFSR. | 140 / 200 |
| `section_checkpoint`, `restore_checkpoint`, `start_game` | | Punkt restartu; nowa gra od mostu 1 (albo `start_bridges_hi` w wersjach testowych). | |

Koszt generatora jest na każdą nową linię: prędkość jest dodawana dwa razy na klatkę do ułamka,
a każde przeniesienie to linia, więc 0–2 linie na klatkę, tym więcej, im szybciej leci samolot.

## render.asm: linia do Layer 2

| procedura | wywołanie | co i jak | A / B |
|---|---|---|---|
| `render_line` | `line_done` | Najpierw `line_bank` (zestaw tablic linii), strona 29 (`PIX_PAGE`) na ten czas w slocie 0. Takty kolorów 20–179 (`WINDOW_FIRST`) linii do wiersza A Layer 2, z kawałków `dl_seg` (bez bufora linii). Layer 2 jest zapisany kolumnami (bajt x·256 + y, 32 kolumny na stronę 8K), więc wiersz pisze się w dół kolumn (`inc h` = następna kolumna), 10 stron kolejno w slocie 2 (`rl_next`). Kawałek jednej wartości: jego kolor raz z pierwszej strony zestawu, potem `rl_fill` (8 kolumn na bajt, strona po stronie; `rl_fill`, `rl_next` w stronie 6, spans.asm); bajty krawędzi (z tablicy w ROM) i wiersz dekoracji (z jej bitmapy w ROM): na bajt 4 strony zestawu dają 2 punkty na takt, każdy zapisany dwa razy; bajty przed oknem pomijane w danych. 320 zapisów na linię. Na końcu RAM Atari z powrotem w slocie 0. W stronie 6 (przeniesione ze strony 4 dla miejsca). | 4 100 + 3 800 / 10 000 + 8 300 |
| `line_bank` | `render_line` | `lineBankColour` portu C++ na stanie po linii: sloty od `FIRST_SLOT` w dół, dopóki któryś może pokazać wiersz drogi (y ≤ $5E: y rośnie w dół slotów); przy moście jego wiersz drogi y + wysokość − $5E, kolor z tablicy pod $B4E5; inaczej `bank_colour` (zieleń). Ten sam kolor co linia przed: nic więcej; inaczej jego miejsce w `bank_cols` × 4 do `rl_set` (starszy bajt zestawu). W bank_colours.asm (strona 6). | 240 / 510 (+ `bank_colour` 370 / 580) |
| `bank_init`, `pix_sets` | `start` (strona 7, po `panel_init`) | Kolory brzegu, każdy raz: $D2, $D6, 20 wierszy drogi (`bank_cols`, `bank_n`, najwyżej 8), pozycje Layer 2: 1, potem 4–10 (`bank_set`); strona 29 w slocie 0: zestaw 4 stron na kolor (zestaw i pod 4i × 256), bajt b strony k to punkt k bajtu b, jak trzyma go Layer 2 (0, 2, 3 same, 1 pozycja koloru i). | raz |
| `bank_set` | `bank_init`, `apply` | Pozycje brzegu Layer 2: ich kolory (E = 1) albo czerń (E = 0, kolory wyłączone: `apply`, gdy zmienia się `show_bank`, `ap_bank_on`). | |

## spans.asm: odcinki linii dla kolizji z polem gry

Każda linia rzeki ma 32-bajtowy rekord w SPAN_PAGE (strona 28 pod $4000), w pierścieniu 256:
takty koloru, gdzie zaczynają się i kończą jej odcinki brzegu (kolor 1) i krawędzi (kolor 2).
Kolizje testują wiersze sprite'ów wobec tych odcinków zamiast pikseli. Z tym samym indeksem
pierścienia — jej przerwy: `eg_e1`–`eg_s2` i `eg_e3`–`eg_s4` (strona 12) woda między odcinkami
krawędzi (przy 2 odcinkach ta między nimi, przy 4 między 1. a 2. i 3. a 4., przy żadnym cała
linia, inaczej żadna: $FF); `bg_e1`–`bg_s2`, `bg_e3`–`bg_s4` (strona 1) dwie najszersze przerwy
między odcinkami brzegu (od taktu 32 przed pierwszym do 224 po ostatnim). Prostokąt wewnątrz
przerwy niczego na tej linii nie dotyka.

| procedura | wywołanie | co i jak | A / B |
|---|---|---|---|
| `span_line` | `line_done` | Rekord nowej linii z kawałków `dl_seg`, bez oglądania pikseli: kawałek jednej wartości to w całości jeden kolor (`span_class`), wiersz ozdoby — kolor brzegu (jak bankRuns portu C++, linia bez ozdoby), odcinki krawędzi gotowe z `edge_runs` według jej kawałka (takt w kawałku i jego kolor, przycięte na bajcie 48); każda zmiana koloru zamyka odcinek (`.change`). Potem jej przerwy (`.gaps` z odcinków krawędzi, `.bgaps` z odcinków brzegu: dwie najszersze zachowane, `.gap`). | 4 200 / 10 300 |
| `edge_runs_init` | `init_tables` (start) | Każdy kawałek krawędzi, którego używa generator (przesunięcia 0–30 tablicy pod $B800), do `edge_runs` (strona 12, 16 bajtów na kawałek): piksele 0–7 jego dwóch bajtów, para (piksel, jego kolor; 3, woda, jako 0) przy pierwszym i przy każdej zmianie, potem $FF. | raz |
| `spans_clear` | `start_attract` | Żadnych odcinków na żadnej linii (pamięć ekranu wyczyszczona). Przerwy zostają: bez odcinków nic nie może być dotknięte, cokolwiek mówią, a każda nowa linia robi je od nowa. | |
| `span_init` | `init_tables` | Maski: bity i..j bajtu (`span_masks`). | |

## display_simple.asm: rozmieszczone obiekty, ich kolizje

Jak `displayGeometry` portu C++ (gałąź `dli_removed`): bez DLI. Każdy obiekt stoi na y swojego
slotu, przycięty do rzeki, a jego kolizje to prosta geometria. Co zostawia: `ds_objs` (wiersze
każdego obiektu dla sprite'ów: 8 bajtów, pierwsza linia, liczba wierszy, wskaźniki kształtu i
koloru, x, rozmiar), wyniki kolizji w
HIT i flagi krawędzi slotów.

`display` (~11 800 / 13 500 własnych):

1. Mapuje SPAN_PAGE, `dh_lists` (deskryptory innych sprite'ów), rejestry wyczyszczone i ustawione jak B527–B55C, `bm_hitclr`, `dh_sprites` (HIT = $FF, potem inne sprite'y z brzegiem i ze sobą).
2. `.slot`, dla każdego slotu od FIRST_SLOT: IY na rodzaju slotu (strona 5: typ, X, rozmiar pod IY + 11, + 22, + 33, czytane tam, bez kopii), Y i flagi zachowane (`ds_y`, `ds_flags`), `ds_edge_kind`; początek = max(y, $5D); pierwszy wiersz = y + height[type] − początek (≥ $80: zniknął w górę, następny); X = początek + 3 (ponad 255: koniec); wierszy = min(wiersz + 1, 256 − X); `ds_rowp` bajt pierwszego wiersza; `ds_obj` (wiersze do `ds_objs`); most: `.road` (`-DBEAM`) (kolor drogi od linii rastra po każdym jej wierszu, X − 69 + 1; kolor brzegu sekcji po ostatnim, o ile X się nie zawinął, przez `ds_bank`; kolor wiersza tylko wtedy, gdy różni się od wiersza wyżej). Pierwsze wiersze kształtu i kolorów wylicza się na miejscu (DE, BC dla `ds_obj`). Tablice ROM (wysokość, kształt, kolory) czytane są dodawaniem 8-bitowym (`ROM_SHAPES` i `ROM_COLOURS` zaczynają się od początku strony).
3. Krawędź (P3PF) dla rodzajów 8–$0D (`ds_edge_kind`: helikoptery, balony, statki zawracają przy niej): `ds_edge_test`, potem `ds_set_flags`.
4. Wobec pocisku, pocisku czołgu (nie most) i samolotu: `dh_obj`; dotknięcie zapisuje slot (HIT_BULLET_OBJECT, HIT_SHELL_OBJECT, HIT_PLANE_OBJECT), więc zostaje ostatni w dół ekranu.
5. `.end`: `test_ghost` (wersje testowe); `ds_bank_fill` tylko z `-DBEAM`.

| procedura | wywołanie | co i jak | A / B |
|---|---|---|---|
| `ds_edge_test` | `display`, dla każdego obiektu rodzajów 8–$0D | A = $02, jeśli rozpiętość wiersza (od jego pierwszego punktu do ostatniego) trafia na odcinek krawędzi na jego linii (`edgeTouches` portu C++). Prostokąt obiektu (X do X + 8, 16 lub 32 taktów; nic ponad takt 255) wiersz po wierszu wobec przerw wody linii (`eg_*`, indeks pierścienia linii rośnie o jeden); wewnątrz — następny wiersz. W przeciwnym razie pierwszy i ostatni punkt wiersza (`edge_lo`/`edge_hi` przeskalowane rozmiarem: `.s1`/`.s2`, plus X: `.ex1`/`.ex2`) wobec odcinków krawędzi linii (jej rekord): odcinek między nimi to dotknięcie, bez punkt po punkcie. | 3 200 / 10 200 |
| `ds_set_flags` | `display` | Bit krawędzi obiektu do flag jego slotu (bit 0). | 1 100 / 1 300 |
| `ds_bank` | `display` (`-DBEAM`) | Zmiana koloru brzegu od linii rastra A (droga mostu i z powrotem): do `ds_bank_ev`. | |
| `ds_bank_fill` | koniec `display`, tylko `-DBEAM` | `scan_bank` dla każdej linii rzeki z `ds_bank_ev` (czyta go tylko wyświetlanie promienia; w grze kolor brzegu idzie linia po linii: `line_bank`). | |
| `ds_edge_only` | `display` | Bit krawędzi tylko dla rodzajów, które go czytają. | |

## display_objs.asm

| procedura | wywołanie | co i jak | A / B |
|---|---|---|---|
| `ds_obj` | `display`, dla każdego obiektu z wierszami | Wiersze obiektu dla sprite'ów: pierwsza linia rastra, liczba wierszy, adresy kształtu i koloru pierwszego wiersza (DE, IY), x, rozmiar: 8 bajtów do `ds_objs` (`DS_OBJS` = najwyżej 16). Obiekt, którego pierwsza linia jest na linii 28 lub wyżej (ponad górą rzeki), jest rozszerzany do całego kształtu (k = początek − y wierszy więcej), więc sprite rysuje się w całości, a okno przycinania sprite'ów go obcina. Na końcu strony 4. | 5 300 / 6 100 |

## display_hits.asm: kolizje jako geometria

Bez rejestrów kolizji i bez odczytów: kolizja się liczy, jeśli zdarza się gdziekolwiek na
wierszach sprite'ów. Pięć innych sprite'ów opisują 10-bajtowe deskryptory w `dh_desc`
(to, co stałe, kopiowane z `dh_template` raz na starcie, `dh_init`; resztę co klatkę wypełnia `dh_lists`): baza wierszy (młodsza), maska (już obrócona na miejsca punktów), koniec wierszy (linia po ostatnim; ponad 255 255), x,
rozmiar, numer sprite'a, pierwsza linia, wiersze, szerokość w taktach, baza (starsza)
(`DH_SIZE` = 10; `DH_SHELL`, `DH_TANK`, `DH_PLANE`, `DH_MISSILE`, `DH_BULLET`). Wiersz na linii L
to bajt pod bazą + L: kształt klatki z ROM (baza = jego adres − pierwsza linia, `dh_shape`,
`dh_base`); wiersze rakiety i pocisku to `dh_ones` (wszystkie ustawione) pod ich maskami, obróconymi na miejsca punktów już w szablonie ($03 o 6: $C0; bit 5 pocisku o 2: $80), więc żaden wiersz nie jest obracany. Po resecie (`pm_empty`, do następnego `prepare`) brak wierszy.

| procedura | wywołanie | co i jak | A / B |
|---|---|---|---|
| `dh_lists` | początek `display` | Wiersze, pozycje i bazy deskryptorów; potem koniec każdego (pole 2). | 1 300 / 1 300 |
| `dh_sprites` | `display` | HIT = $FF, potem HIT 0 tam, gdzie: czołg trafia na krawędź (P1PF), samolot na brzeg (P2PF), rakieta i pocisk na brzeg lub krawędź (M0PF, M2PF): `dh_pf`; samolot i pocisk czołgu (P2PL bit 0), rakieta i samolot (M0PL): `dh_pair`. | |
| `dh_pf` | `dh_sprites` | NZ: wiersze sprite'a IX trafiają w pole gry (DE: `sp_edge`, `sp_bank`, `sp_under`). Dla każdej linii rzeki: najpierw bajt wiersza pod maską (brak punktów: następna linia), potem jego prostokąt (X do X + jego takty) w przerwach linii (A: bit 0 `eg_*` krawędzi, bit 1 `bg_*` brzegu); wewnątrz nic; inaczej końce wiersza wobec odcinków (funkcja `sp_*`). Zatrzymuje się na pierwszym dotknięciu. | 10 200 / 11 200 |
| `sp_edge`, `sp_bank`, `sp_under` | `dh_pf` | Wiersz sprite'a wobec odcinków linii: krawędzi (brązowej), brzegu (zielonego) lub któregokolwiek, jak `spanTouches` portu C++: jego pierwszy i ostatni punkt (`sp_ends`: `edge_lo`, `edge_hi`, szerokość rozmiaru, plus X) wobec odcinków (`sp_runs`), odcinek między nimi to dotknięcie; rekord linii przez `sp_rec`. | |
| `dh_pair` | `dh_sprites` | NZ: wiersze dwóch sprite'ów się spotykają: `hit_setup` na ich taktach, potem na każdej linii, którą mają oba, bity każdego (`dh_bits`, `hit_wide` według jego rozmiaru) do `hit_a`, `hit_b` i `hit_line`. | |
| `dh_bits`, `dh_end` | `dh_pf`, `dh_pair`, `dh_obj` | Bity sprite'a IX na linii A: bajt wiersza pod maską, już przy najstarszym bicie (Z: brak); linia po jego ostatnim wierszu (`dh_lists` wpisuje ją raz na klatkę do pola 2). | 400 / 500 |
| `dh_obj` | `display`, dla każdego obiektu (pocisk, pocisk czołgu, samolot) | NZ: sprite IX dotyka wierszy bieżącego obiektu (`ds_rowp`, od linii X = `ds_counter`, `ds_rows` z nich, przy X i rozmiarze slotu: IY + 22, + 33). Najpierw linie, które mają oba (`ds_l1`, `ds_l2` z `display`, koniec sprite'a: większość obiektów nie ma z nim wspólnych), potem `hit_setup` na taktach obiektu (8, 16 lub 32) i sprite'a; na każdej linii bajt wiersza obiektu (zero: następna) i bity sprite'a, każde poszerzone (`hit_wide`), `hit_line`. | 4 900 / 6 100 |
| `hit_setup` | `dh_obj`, `dh_pair` | Z: takty dwóch prostokątów (B od, C szerokość; D od, E szerokość) się nie spotykają; inaczej okno, w którym oba są na taktach pola gry (32–223, najwyżej 8 szerokie): gdzie zaczyna się ono w punktach każdego (`hit_ka`/`hit_sa`, `hit_kb`/`hit_sb`: bajt, bit) i bity jego taktów (`hit_w`). | 500 / 700 |
| `hit_wide` | `dh_obj`, `dh_pair` | Punkty bajtu A po takcie na bit do DE i dalej (rozmiar C: 1, 2 lub 4 takty na punkt, z `ov_exp2`, `ov_exp4`: tablic robionych przez `init_tables`), potem zero. | |
| `hit_line` | `dh_obj`, `dh_pair` | NZ: punkty `hit_a` i `hit_b` spotykają się w oknie: dwa bajty każdego od jego początku przesunięte przez `bsla de,b` (Z80N, 8 taktów), AND ze sobą i z `hit_w`. | |

## display.asm: testy pola gry (i stary model promienia)

Większość tego pliku to pełny, dokładny co do taktu model DLI (`op`, `bm_events`, `bm_draw`,
`rec_set`, `p3_scan`, `bm_wsync`, ciało `collide` promienia…), zachowany dla odniesienia i
składany tylko z `-DBEAM`. Składane zawsze:

| procedura | wywołanie | co i jak | A / B |
|---|---|---|---|
| `pf_under`, `pf_bank`, `pf_edge`, `pf_none` | wyświetlanie promienia (`-DBEAM`) | Czy wiersz sprite'a (bity D od bitu 7, pozycja E, rozmiar A: 1, 2 lub 4 takty na bit) na linii `bm_line` jest nad brzegiem, krawędzią lub którymkolwiek, punkt po punkcie? Znajduje rekord linii (`pf_line`), potem przechodzi jej odcinki (`pf_size`). Gra już ich nie używa. | |
| `pf_line` | `pf_bank`, `pf_edge` | HL = rekord linii `bm_line` (przeniesienie: linia rzeki). | |
| `pf_size`, `pf_v1`, `pf_v2`, `pf_v4` | `pf_*` | Odcinki pod sprite'em: odcinek, który nakłada się na takty sprite'a, jest testowany wobec jego bitów przez `span_masks` (D: strona masek); po wariancie na rozmiar (N przesunięć zamienia przesunięcie w taktach na indeks bitu). | |
| `collide` (`.add`, `.pair`, `.overlap`, `.entry`) | wyświetlanie promienia (`-DBEAM`) | Lista sprite'ów na linii (bity, pozycja, rozmiar) i test nałożenia dwóch z nich punkt po punkcie; gra już go nie używa. | |
| `bm_hitclr` | `display` | HITCLR: bity kolizji wyczyszczone. | 1 500 / 1 700 |
| `init_line_tables` | `tv_setup` | Na każdą linię rastra: cykle ANTIC na jej początku (`line_start`) i te, które zostają po jej narysowaniu (`line_after_draw`); czyta je teraz tylko model `-DBEAM`. | |

## sprites.asm: sprite'y, Copper, `apply`, panel

| procedura | wywołanie | co i jak | A / B |
|---|---|---|---|
| `build_sprites` | `main_frame` | `ob_list` (obiekty); samolot, jego pocisk, czołg, rakieta helikoptera, pocisk czołgu (w kolejności, w jakiej rysuje je `drawRiver`, ostatni na wierzchu): każdy to wzór jego klatki zrobiony przy starcie (`pl_plane`, `pl_tank`, `pl_shell`, `pl_bullet`, `pl_missile`) w jego pozycji, `pl_sprite`; `pl_keep` zachowuje ich atrybuty, które klatki resetu (`busy`) pokazują znowu (`pl_again`); `build_copper`. | 1 000 / 1 100 |
| `pl_sprite` | `build_sprites` | Wzór A ($FF: brak) na linii D (brak poniżej rzeki), pozycja E, przesunięcie palety C: jego 5 bajtów atrybutów do `sprite_list` (X = 2·(x − 52), 9 bitów; Y; przesunięcie; wzór; 4 bity, połowa wzoru). | ~100 na sprite |
| `ob_list` | `build_sprites` | Dla każdego wpisu `ds_objs` jego wiersze z `ds_objf` (wszystkie): jego obrazek zrobiony przy starcie odnaleziony po adresach kształtu i koloru górnego wiersza (`obj_lookup`; nieznaleziony: `ob_miss`, nierysowany), sprite na każde 16 wierszy (`ob_attr`: X = 2·(x − 52), Y, bank, 4 bity, połowa wzoru, skala dla podwójnej lub poczwórnej szerokości), żaden dla kawałka, którego pierwsza linia jest poniżej rzeki. | 5 700 / 6 400 |
| `build_copper` | `build_sprites` | Tylko gdy zmienił się standard (`cp_built` 0, `tv_setup`) albo kolory się wyłączyły lub włączyły (`colour_bank` 0 lub nie, wobec `cp_bank_on`): pozycje brzegu przywracane po szarości panelu (`CP_RESTORE`: ich kolory, czerń gdy kolory są wyłączone), potem `copper_start` i część panelu (`copper_panel`) do listy, końcowy WAIT. `cp_full` = 1. W bank_colours.asm. | 100 / 100 |
| `apply` | po `wait_frame` | Przewijanie Layer 2 (NR $17), atrybuty sprite'ów (port $57, OTIR 5 na sprite; nadmiarowe z poprzedniej klatki ukryte), kolory pocisku czołgu, czołgu i samolotu (paleta sprite'ów), kolory 0, 2, 3 Layer 2, jego okno przycinania (gdy Layer 2 jest czyszczony po resecie, od jego drugiej klatki: tylko wiersze panelu, `l2_hidden`; `l2_clip_y2` ostatni wiersz okna z `tv_setup`), `panel_frame`, Copper: zatrzymany, cała lista wysłana, jeśli `cp_full`, inaczej tylko bajt przewinięcia X napisu, uruchomiony ponownie (tryb %11). Ekran wyłączany po długiej bezczynności (IDLE_TIME). Nie ma go w liczbach wyżej. | — |
| `panel_frame` | `apply` | Panel: tylko pozycje, które wymienił `panel_put` (`pf_dirty`; wszystkie po kopii `start_attract` i `tv_setup`), każda z `.cells` (komórka jego lewej połowy; pierwszy znak wiersza tylko prawa połowa), 2 komórki kafelka 2·kod + połowa, a bity koloru jako przesunięcie palety. Przewijany napis (połowa h w 8h − X0, X0 = 16·TEXT_LO + 38 − 2·FINE_SCROLL): pierścień w wierszu mapy 26 (połowa h w kolumnie h mod 40; zapisywane tylko połowy nowe od ostatniej klatki, `.ring_write`; wszystkie 40 po skoku), przewinięcie X równe X0 mod 320 (9 bitów: `CP_XSCROLL_HI_BACK`, `CP_XSCROLL_BACK`); okno przycinania tilemapy krótsze z prawej o S = X0 & 7 punktów (kolumna, która się zawija); sprite 70 (wzór 20, przesunięcie palety 6) przy X 320 − S z połową h0 + 40 (jego 64 bajty zapisywane, gdy się zmienia: `.spr_pattern`). Sprite'y wskazówki i logo. | ~1 700 napis, ~200 panel, ~1 400 wskazówka i logo |

Dane: `copper_start` (indeks 1 palety Layer 2, NOP tam, gdzie był NR $4A (kolor T), przewijanie Y i X tilemapy 0: jej linie to linie ekranu, w wierszach poza panelem nic nie ma), `copper_panel_ntsc`/`_pal` (w stronie 7, copper_panels.asm: `tv_setup` kopiuje jedną do `copper_panel` przez slot 2; ten sam układ, więc przesunięcia pasują do obu: linia 200: przewijanie Y tilemapy dla pierwszego wiersza panelu (`CP_PANEL_Y`, wstawiane przez `tv_setup`), kolory 0–10 Layer 2 czarne (`CP_COLOURS`: także pozycje brzegu, bo wiersze pod panelem pokazują stare linie rzeki) i okno sprite'ów od linii 215 w dół (`OBJ_LAST` + 1, poniżej wierszy każdego obiektu; wskazówka i logo niżej); 201: szary (`COPPER_GREY`, wstawiany przez `tv_setup`); przewijanie Y tilemapy na każdy wiersz panelu; linia 230 (240 PAL): kolory 0–10 z powrotem (`CP_RESTORE`: brzegu przez `build_copper`, krawędzi i wody przez `apply`, `CP_EDGE_BACK`); przewijanie Y i X przewijanego napisu (`CP_XSCROLL_HI_BACK`, `CP_XSCROLL_BACK`); na `wait_line`: okno sprite'ów znów rzeki). `apply` wysyła bajty od krawędzi do przewijania X (`.cp_send`), gdy lista nie jest wysyłana cała.

## panel.asm (strona 6): znaki panelu

| procedura | wywołanie | co i jak |
|---|---|---|
| `panel_put`, `panel_put_de` | ci, którzy piszą do panelu | Znak do panelu pod HL (DE): nic, jeśli już tam jest; inaczej zapisany, a jego pozycja dopisana do `pf_dirty` (60 lub więcej: wszystkie). |
| `print_bcd` | `show_score`, `show_other_score`, `show_high_score`, `show_bridges`, koniec gry | B bajtów BCD pod HL jako cyfry pod DE, '0' = C, wiodące zera puste; nic w trybie demonstracyjnym. Dla każdego miejsca (punkty, rekord lub punkty drugiego gracza, mosty, mosty drugiego) pamięta podstawę cyfr i wypisane bajty (`pb_cache`) i od razu wraca, gdy są takie same. |
| `show_lives` | `prepare` i inne | Symbole żyć; nic, gdy ich liczba jest tą wypisaną ostatnio (`sl_last`). |
| `pb_forget` | `start_attract` | Ostatnio wypisane liczby zapomniane (wszystko wypisywane znowu). |

Miejsca, które się nakładają, zapominają nawzajem swoje: życia i mosty drugiego gracza, tekst
końca gry w miejscu żyć.

## sound.asm: sterownik dźwięku i próbki POKEY

| procedura | wywołanie | co i jak | A / B |
|---|---|---|---|
| `sound_driver` | `vbi` | B2A5–B3D8: sterownik oryginału: kanał 1 pisk startu, dźwięki zdarzeń, pisk niskiego paliwa albo silnik; 2 wybuch albo rakieta; 3 strzał albo dodatkowe życie; 4 pocisk czołgu. Zapisuje AUDF/AUDC POKEY (`pokey_audf`, `pokey_audc`). | 770 / 930 |
| `sound_init` | `restart` | DAC włączone (NR $08), pierścień i kanały wyciszone, `sound_init7` (strona 7: AY, tablice POKEY, DMA zaprogramowany), potem DMA włączony ($87), gdy strona 12 jest z powrotem zmapowana. | |
| `pokey_frame` | `main_frame` | `ay_frame` (czyste tony na AY; jeśli wszystkie cztery tam są — pierścień raz wyciszony, `snd_idle`, i koniec), potem ile próbek: linie do `wait_line` (NR $1E/$1F), gdzie jest DMA (jego adres odczytany), do `SND_LEAD` (760) do przodu, co najmniej `SND_MIN_LEAD` (200), najwyżej `SND_CAP` (700). Potem: `snd_fill` (odcinek na 0), każdy kanał nie na AY: głośność × wzmocnienie klatki (`snd_gain_set`: 8 albo 7–4, gdy głośności dają razem ponad 31, `mul d,e`) jako stały poziom (tylko głośność albo AUDF ≤ 4: połowa) albo `pk_channel` (jego przełączenia jako + i − do pierścienia), potem `snd_sum` (suma bieżąca robi poziomy). Strony 14–15 pod $0000 na ten czas (17-bitowy licznik). | 2 400 / 2 500 |
| `snd_gain_set` | `pokey_frame` | `snd_gain`: 8 na stopień głośności albo najwięcej, przy czym poziomy nie przekraczają 255, gdy głośności kanałów na DAC dają razem ponad 31 (7 do 36, 6 do 42, 5 do 51, inaczej 4). | ~150 |
| `snd_fill` | `pokey_frame` | DE bajtów A od HL w pierścieniu (dwa odcinki na zawinięciu), każdy przez PUSH od swojego końca w dół (SP zachowany). | 2 800 / 2 400 |
| `snd_sum` | `pokey_frame` | Suma bieżąca po DE próbkach: `add a,(hl) / ld (hl),a / inc l`, rozwinięta 8 razy, wejście we właściwym miejscu dla reszty (samomodyfikujący się `jp`), strona po stronie w pierścieniu. ~8 400 taktów na ~270 próbek: ok. 31 na próbkę. | 8 600 / 7 300 |
| `sound_random` | `sound_driver` | RANDOM dla wysokości szumu (nie `random_read`, które liczą testy). | |

Pierścień: 1024 bajty pod $7C00 (strona 12), wyrównane do 1K, wysyłane do portu $DF przez
zxnDMA w trybie burst z dzielnikiem 55 (15 909 Hz), restartowane na końcu. Poziomy 0–240.

## sound_pulses.asm, sound_handlers.asm: przełączenia jednego kanału

| procedura | wywołanie | co i jak | A / B |
|---|---|---|---|
| `pk_channel` | `pokey_frame`, dla każdego kanału z AUDF ≥ 5 | Przygotowanie: częściowe wartości głośności (× 0–3 z 4, dla przełączenia wewnątrz próbki), kroki okresu dla 4- i 5-bitowego licznika (`snd_mod15/31`), okres jako próbki i takty × 64 wpisane w pętle; pierwszy impuls (`CH_D`, `CH_F`); K = impulsów w tej klatce (12-bitowe dzielenie, rozwinięte: tyknięcia są poniżej 4 × SND_CAP < 4096); potem pętla dla jego rodzaju. | 1 200 / 2 800 |
| `pk_tone` | `pk_channel` | Ton: wyjście przełącza się przy każdym impulsie. | |
| `pk_noise` | `pk_channel` | Szum: następny bit 17-bitowego licznika przy każdym impulsie (bity po kolei, zmapowane pod $0000); jego przełączenia na początku próbki (+ lub − głośność, bez części na dwie próbki). | 4 600 / 12 900 |
| `pk_g4` | `pk_channel` | 4-bitowy licznik przepuszczany przez 5-bitowy (AUDC 010: rakieta helikoptera): oba liczniki jako jedna liczba m (`g4_crt`: m = b + 31 ((e − b) mod 15)), impuls m + s, `g4_tab` na każde m ($FF nieprzepuszczony, inaczej bit); liczniki odtwarzane z m na końcu. Przełączenia na początku próbki. | 0 / 1 400 |
| `pk_other` + `pk_handlers` (`adv31`, `adv15`) | `pk_channel` | Pozostałe rodzaje przez procedury obsługi. | |
| `pk_on`, `pk_off`, `pk_part*` | pętle | Przełączenie tonu lub reszty przy impulsie: próbka dostaje zmianę pomniejszoną o część przed przełączeniem, następna próbka tę część (bez buczenia od całych próbek; szum i rakieta przełączają się zamiast tego na początku próbki). | |
| `pk_done` | pętle | Reszta tyknięć klatki do `CH_D`, `CH_F`, wyjście zachowane. | |

## sound_ay.asm (strona 7), sound_ay_run.asm (strona 6): czyste tony na AY

| procedura | wywołanie | co i jak | A / B |
|---|---|---|---|
| `ay_init` | `sound_init7` | TurboSound włączony, pierwszy AY mono, tylko tony, cisza. | |
| `sound_init7` | `sound_init` | `ay_init`, tablice POKEY do strony 1, `snd_mod15/31`, DMA zaprogramowany (niewłączony). | |
| `ay_frame` | `pokey_frame` | Dla każdego kanału POKEY z czystym tonem (AUDC 101x lub 111x, nie tylko głośność, głośność ≠ 0): własny kanał AY (`ay_slot`: 1 A drugiego AY, 2 A trzeciego, 3 B pierwszego, 4 C pierwszego), okres N = (AUDF + 1) × 3,454 (PAL) / 3,422 (NTSC) przez `mul d,e`, głośność przez `ay_vol`, bit tonu miksera; `ay_mask` mówi `pokey_frame`, by je pominął. Rejestry tej klatki do `ay_q` (3 klatki × 33: 0–10 trzech układów, po kolei według `ay_qi`), na zewnątrz te sprzed 2 klatek. | 2 200 / 2 800 |
| `ay_out` | `ay_frame`, `ay_init`, `ay_quiet` | Rejestry 0–10 trzech AY z HL (pierwszy zostaje wybrany, B = $FF). | 3 400 / 3 400 |
| `ay_quiet` | `pokey_frame` (dźwięk wyłączony), `ay_init` | Wszystko wyciszone (głośności 0, miksery $3F). | |

`sound_ay_run.asm` jest w stronie 6, nie 7, żeby `pokey_frame` nigdy nie mapował strony 7 na
pierścień (zob. NOTES: trzaski).

## panel_init.asm (strona 7, przy starcie)

| procedura | wywołanie | co i jak |
|---|---|---|
| `panel_init` | `start` (strona 7 pod $6000) | Zestawy znaków Atari budowane tam, gdzie buduje je gra (czcionka systemu z `font.inc`, symbole kartridża), każdy znak jako dwa kafelki (kafelki 0–127 panelu, 128–255 napisu) w stronach 10–11, paleta i rejestry tilemapy (NR $6B/$6C/$6E/$6F, przycinanie), wzory sprite'ów wskazówki i logo, `edge_lo`/`edge_hi` (pierwszy i ostatni ustawiony punkt każdego bajtu, dla testu krawędzi). |
| `pl_pics` | `panel_init`, przed `obj_pics` (strona 7) | 10 klatek samolotu (14 wierszy), 8 czołgu (11 wierszy) i 7 pocisku czołgu (16 wierszy) z ich tablic wskaźników w ROM, tak jak `prepare` kopiuje je do pamięci player-missile: po 4-bitowym wzorze (punkt: 2 piksele wartości 1), wspólny dla klatek z jednym adresem, żaden dla całkiem pustej ($FF); pocisk (8 wierszy po punkcie) i rakieta helikoptera (jeden wiersz 4 punktów). Wzory od 0 (20 sztuk). |
| `obj_pics` | `panel_init` (strona 7) | Obrazki obiektów: dla typów 7–15 rodzaje, które mogą mieć (własny, rodzaje `ROM_NEXT_KIND` poniżej $0C, wybuchu z 2 i 3), każdy też odbity, height + 1 wierszy; 58 obrazków jako 4-bitowe wzory od 24, wartość punktu to miejsce koloru jego wiersza w banku palety 14 (typy 12, 15) lub 15 (pozostałe); `obj_head`/`obj_e` dla `obj_lookup`. |

## load_rom.asm (strona 7)

| procedura | wywołanie | co i jak |
|---|---|---|
| `load_rom` | `start` (nie w wersjach testowych) | Otwiera River_Raid.rom w folderze programu przez esxDOS (F_OPEN, F_READ, F_CLOSE; po krótkiej nazwie, gdzie długich nazw nie widać) i czyta jego 8192 bajty pod $A000 (strona 5). Bez niego: czerwona ramka i zatrzymanie. Sprawdzone tylko na prawdziwym Next. |

## Pliki dołączane

- `vars.inc`: adresy zmiennych gry w RAM Atari (nazwy oryginału).
- `palette.inc`: paleta Atari jako kolory Next (robi ją `tools/mkpalette`).
- `random.inc`: kolumny kroku RANDOM (`tools/mkrandom`).
- `font.inc`: czcionka systemu (`tools/mkfont`, z AltirraOS, z jej informacją).
- `poly.inc`, `poly17.bin`: 4-, 5- i 17-bitowe ciągi POKEY (`tools/mkpoly`).

## Co warto wiedzieć, zanim zmieni się kod

- **Kod samomodyfikujący się** jest częsty w gorących pętlach: wpisywane wartości natychmiastowe i cele skoków (`.bx1/.be1/.bx2/.be2/.ex1/.ex2/.s1/.s2/.pv/.pv_bits/.pv_end/.pv_x` w `ds_edge_test`; `.mode/.x0a…/.x1d/.bits/.fn` w `dh_pf`; `.jp` w `snd_sum`; `.pf/.pq` w `pk_*`). Wariant trzeba sprawdzać bajt po bajcie (pozostawione `add a,a` raz podwoiło dźwięk).
- **Rozwinięte punkty wejścia**: `snd_sum` skacze w środek bloku `rept` dla reszty.
- **Slot 2** to okno robocze: procedura, której potrzebna jest tam strona, mapuje ją i nie przywraca; następny użytkownik mapuje swoją. **Slot 3** musi zostać stroną 12, gdy gra dźwięk.
- **Tablice są wyrównane do strony**, żeby odczytem było `ld h,high table / ld l,index`: `span_masks`, `span_class`, `edge_lo/edge_hi`, `obj_head`, `ov_exp2`/`ov_exp4`, `eg_*`, `bg_*`, paleta.
- **Testy**: po każdej zmianie `nxcheck` porównuje co klatkę z portem C++ stan i pamięć ekranu, kolor brzegu na linię, obiekty, jak je narysowano, listę i pamięć Coppera, a na końcu obraz. Pełny zestaw trwa ~25 minut na 2 rdzeniach (HANDOFF.pl.md, *Metoda*). Nieudane składanie zostawia stare strony: najpierw sprawdzić wyjście wersji.
- **Pomiary**: `NXHISTALL=plik` (wszystkie klatki) albo `NXHIST=plik` (jedna klatka) i `tools/prof.py`; `NXSLOW=T` wypisuje klatki ponad T taktów. `NXHISTAPPLY=plik` robi to samo dla `apply` (od końca `wait_frame`) i wypisuje jego średnią i maksimum; `tools/prof_local.py build/test.sym plik klatki [procedura…]` dzieli czas także według lokalnych etykiet (`ds_edge_test.row`, `panel_frame.mod`, …). Najcięższe klatki: `-stress` z `NXBRIDGE=80 NXGHOST=1 NXGAME=1`.
- **apply** (~7 400 na klatkę, nie ma go w tabelach wyżej): napis ~1 700 (przewinięcie X mod 320 przez odejmowanie ~650 z tego), wskazówka i logo ~1 400, panel ~200 (tylko to, co się zmieniło), atrybuty sprite'ów ~1 800, lista Coppera ~1 200.
- **Przepisanie** najszybciej potwierdza wersja testowa, która co klatkę wykonuje nowy sposób obok starego i liczy, gdzie się różnią (tak zrobiono dla wierszy kolizji, rozmieszczania, kursorów), a potem usuwa się stary.
