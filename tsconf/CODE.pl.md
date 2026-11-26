# Kod źródłowy portu na TS-Conf w asemblerze, plik po pliku

[English](CODE.md) | [Русский](CODE.ru.md) | [Українська](CODE.uk.md) | [Deutsch](CODE.de.md) | Polski | [Italiano](CODE.it.md) | [Español](CODE.es.md) | [中文](CODE.zh.md) | [日本語](CODE.ja.md)

Dla programistów Z80, którzy chcą czytać kod portu na TS-Conf albo go przyspieszyć. Sama gra
(jej logika, generator rzeki, rozmieszczanie obiektów i kolizje) to kod Next skopiowany do
`src/`; te procedury opisuje [docs/CODE.pl.md](../docs/CODE.pl.md), a ten dokument mówi tylko,
co w nich zmieniono. To, co własne TS-Conf (obraz, kolor brzegu linia po linii, sprite'y, panel,
dźwięk na General Sound, start z karty SD), opisano tu procedura po procedurze, z kosztem.
Przegląd jest w [README.pl.md](README.pl.md).

## Dwie maszyny obok siebie

Ta sama gra, dwa sposoby jej pokazania. Co się różni i gdzie widać to w kodzie:

| | ZX Spectrum Next | TS-Conf (ZX Evolution) |
|---|---|---|
| Procesor | Z80N na 28 MHz (3,5 / 7 / 14 / 28), przerwania wyłączone: klatka przez odpytywanie linii rastra | Z80 na 14 MHz (3,5 / 7 / 14), pamięć podręczna włączona; przerwanie klatki, IM 2, przesuwane w dół klatki od zdarzenia do zdarzenia |
| Instrukcje Z80N | `nextreg`, `mul`, `bsla de,b`, `outinb`… | brak: rejestr to `ld bc,port / out (c),a`; `bsla de,b` pętla (`shl_de_b`, display_hits.asm); `mul` niepotrzebne (okres AY przez dodawanie) |
| Pamięć | sloty 8K (MMU, NR $50–$57) | okna 16K (PAGE0–PAGE3); okno 0 to RAM z zapisem (MEMCONFIG), więc RAM Atari leży od $0000 |
| Rzeka | Layer 2, 320×256, 8 bitów, kolumnami: linia to 320 zapisów w dół kolumn, 10 stron po kolei | 16 kolorów, 320×240, linia obrazu 256 bajtów (2 punkty w bajcie): linia to 160 bajtów wzdłuż wiersza, jedna strona |
| Przewijanie | NR $17, pierścień 256 linii | GYOFFS, pierścień 512 linii (`scroll` 9 bitów) |
| Kolor brzegu linia po linii | wpisy 1 i 4–10 Layer 2, ustawiane raz; punkty brzegu linii wpisem jej koloru (`line_bank`) | wpisy 1 i 9–15 jednej palety (PALSEL 0, CRAM), ustawiane raz; punkty brzegu linii wpisem jej koloru (`line_bank`) |
| Sprite'y | 128 wzorów 16×16, 4 lub 8 bitów, skala ×2 ×4; obiekt to sprite na każde 16 wierszy | jedna pamięć obrazków 512×512 po 4 bity (SGPAGE), dowolny rozmiar do 64×64, bez skalowania: każdy obrazek trzymany w szerokości 16, 32 i 64 punktów; obiekt to jeden sprite |
| Kolory | NR $41 itd., 9 bitów | CRAM przez okno FM pod $E000 (`CRAM_SHADOW`): kolory i lista sprite'ów (SFILE) pod $E200 to zwykłe zapisy do pamięci |
| Panel i przewijany napis | tilemapa nad wszystkim, jej przewinięcie Y i X przez Copper; napis to pierścień kafelków + jeden sprite na złączu | osobny obraz (256 kolorów, strony 64–79) włączany od linii 184 przez przerwanie klatki (VPAGE, GYOFFS, VCONFIG z GFXOVR), jego znaki narysowane raz i kopiowane przez DMA; napis to pierścień 32 znaków na 512 punktach, GXOFFS ustawiany przez przerwanie; warstwa kafelków 0 to szarość pod znakami i czerń nad rzeką i pod nią |
| Dźwięk | szumy POKEY do pierścienia, zxnDMA do DAC (`pokey_frame` na głównym procesorze, ~26 000–39 000 jego taktów 28 MHz na klatkę); czyste tony na 3 AY | cały POKEY gra własny Z80 General Sound (`gs/`); główny procesor wysyła 8 bajtów na klatkę (~3 400 ze sterownikiem). Bez karty: czyste tony na 2 AY TurboSound |
| Kartridż | esxDOS: River_Raid.rom z folderu programu | własny kod SD i FAT16/FAT32: karta jest przeszukiwana (Wild Commander nie daje folderu) |
| TV | 50 lub 60 Hz (CAPS + 1) | tylko 50 Hz: klatka płyty |
| Czyszczenie obrazu | PUSH, dwie strony Layer 2 na klatkę | wypełnienie DMA, pół obrazu na klatkę |
| Narzędzia | `nxcheck` (rdzeń Next), `NXHISTALL` + `tools/prof.py` | `tscheck` (rdzeń TSConf), `TSHISTALL` + `../tools/prof.py` |

## Liczby

Czasy to takty rdzenia TSConf przy 14 MHz (zegar procesora), klatka ma ~286 800. Z histogramu
tscheck (`TSHISTALL=plik`, potem `python3 ../tools/prof.py build/test.sym plik 60`, podzielone
przez liczbę klatek), na wersji testowej (`-DTEST`: z pamięcią ekranu Atari, której gra nie ma:
`line_done` i `draw_line` są cięższe niż w grze o ~1 000–2 000). Z General Sound, więc szumy nic
nie kosztują głównego procesora. Dwa przebiegi:

- **A**: bot 1, 3 000 klatek od startu: praca średnio ~53 000 na klatkę, najwyżej ~109 000;
- **B**: `-stress` od mostu 80, 6 000 klatek (`TSBRIDGE=80 TSGHOST=1 NXGAME=1 … -bot 1 -stress`: wszystkie sloty zajęte, pełny gaz, ciągły ogień): średnio ~89 000, najwyżej ~127 000.

Praca to odcinek od `apply_done` do `frame_done` (czekanie na przerwanie klatki niewliczone);
części niżej liczą też `apply` i przerwania (~7 000).

Według części (A / B):

| część | A | B |
|---|---|---|
| wyświetlanie: rozmieszczanie obiektów i kolizje (`display`, `ds_*`, `dh_*`, `sp_*`, `hit_*`) | 23 800 | 34 900 |
| nowe linie rzeki (`river_gen`, `render_line`, `span_line`, `line_done`, `push_line`) | 12 800 | 29 800 |
| sprite'y (`build_sprites`, `ob_*`, `pl_*`, `obj_lookup`, `sfile_put`) | 8 700 | 12 700 |
| `apply`, panel i przerwania (`apply`, `panel_frame`, `panel_draw`, `pc_*`, `irq`, wypisywanie panelu) | 5 700 | 5 500 |
| dźwięk (`sound_driver`, `snd_*`, `gs_*`; bez karty `ay_*`: ~5 800 w A) | 3 200 | 3 300 |
| logika gry i reszta (`move_objects`, `main_loop`, `random_step`, `vbi`, …) | 8 900 | 11 800 |

Najdroższe procedury (A / B):

| procedura | A | B | plik |
|---|---|---|---|
| `display` (własny kod) | 9 600 | 11 200 | display_simple |
| `span_line` | 3 700 | 8 900 | spans |
| `render_line` | 3 500 | 8 400 | render |
| `ds_edge_test` | 2 300 | 7 500 | display_simple |
| `dh_pf` | 4 000 | 5 500 | display_hits |
| `ob_attr` | 2 700 | 5 400 | sprites |
| `move_objects` | 1 700 | 3 300 | game |
| `dl_fill` | 1 500 | 3 300 | river_gen |
| `ob_list` | 2 400 | 3 200 | sprites |
| `ds_obj` | 2 400 | 2 900 | display_objs |
| `line_done` (kopia do pamięci ekranu, tylko wersja testowa) | 1 100 | 2 500 | game |
| `gs_send` + `gs_wait_c` + `gs_wait_d` | 2 300 | 2 100 | sound_gs |
| `dh_obj` | 1 200 | 1 600 | display_hits |
| `panel_frame` | 1 600 | 1 600 | panel_ts |
| `sfile_put` | 1 300 | 1 400 | river_raid |
| `dh_lists` | 1 300 | 1 300 | display_hits |
| `irq` | 1 200 | 1 200 | river_raid |
| `apply` (własny kod) | 800 | 800 | river_raid |
| `hit_setup` | 500 | 700 | display_hits |
| `pl_keep` | 100 | 100 | sprites |

Przy 7 MHz (`TSSPEED=1`, ~143 400 taktów na klatkę) praca to te same instrukcje: `-stress`
średnio ~75 000, najwyżej ~102 000, mieści się na styk; przy 3,5 MHz (`TSSPEED=0`, ~71 700 na klatkę), w buildzie jak w grze (bez pamięci ekranu: `-DNOSCREEN`, w tscheck `TSNOSCREEN=1`), bot 1 średnio ~43 000, najwyżej ~71 700, spóźnionych 10 klatek z 3 000; `-stress` ~57 000 / ~88 500, spóźnionych 465. `gs_send`
czeka, aż karta przeczyta każdy bajt (~300 taktów na bajt przy 14 MHz).

(`prof.py` bierze nazwę procedury z najbliższej globalnej etykiety poniżej adresu. Adresy poniżej
$4000 to praca startu w INIT_PAGE: pomijać.)

## Pamięć podczas działania kodu

Okna 16K i strony w nich (strony 16K płyty):

| okno | adres | zwykle | kto przemapowuje |
|---|---|---|---|
| 0 | $0000–$3FFF | 1 (`ATARI_PAGE`): RAM Atari pod adresami oryginału | przy starcie: 3 (`INIT_PAGE`: tam działają `sprite_pics.asm`, `gs_load.asm`, `load_rom.asm`) |
| 1 | $4000–$7FFF | 5 (`WORK_PAGE`): odcinki linii od $4000 (`SPANS`, 32 bajty × 256 linii), bufory od $6000 (`scan_*`, `edge_runs`, `ring_*`, `ds_objs`, `ov_exp2/4`, `eg_*`, `bg_*`, `line_*`, `edge_lo/hi`, `rnd_tab`), czcionka systemu pod $7D00 | `render_line`: strona obrazu rzeki (32–47); `panel_draw`/`pc_*`: obraz panelu (64–79); przy starcie mapa kafelków (7), kafelki (8), obrazki sprite'ów (24–31); zawsze z powrotem 5 |
| 2 | $8000–$BFFF | 2 (`CODE_PAGE`): kod do ~$9FBF, kartridż od $A000 | — |
| 3 | $C000–$FFFF | 6 (`HIGH_PAGE`): kod do ~$D7EC, potem pod $E000 okno FM (`CRAM_SHADOW`: CRAM $E000–$E1FF, SFILE $E200–$E3FF; zapisy idą też do RAM pod nim), tablice i zmienne do ~$FD65, stos, wektory IM 2 pod $FE00 | — |

Obrazy: rzeka od strony 32 (`VID_PAGE`, 16 stron: 512 linii po 512 bajtów, z każdej widać 320
punktów), panel od strony 64 (`VPANEL`), mapa kafelków w stronie 7, punkty kafelków w stronie 8,
punkty sprite'ów 512×512 w stronach 24–31 (`SGPAGE`). Kod INIT_PAGE kończy się na ~$11DF,
bufory strony roboczej na $7C00. Okno FM jest włączone na stałe: nic innego nie może używać
$E000–$E3FF, a $E400–$E4FF to jego rejestry (leży tam `palette_lo`, tylko do odczytu).

## Klatka

`main_frame` (river_raid.asm), co klatkę:

1. Utrwala to, co pokazuje obraz tej klatki (`scroll`, kolory krawędzi i wody, gracz), `read_input`.
2. Zwykle: `prepare` → `display` → `build_sprites` → `main_loop` → `vbi` → `snd_frame`. Podczas resetu (`busy`): `display` → `build_sprites` → `clear_layer2_page` → (`finish_reset` w ostatniej) → `vbi` → `snd_frame`.
3. `wait_frame`: HALT, aż przyjdzie przerwanie klatki (`frame_flag`), na `FRAME_LINE`, pod panelem.
4. `apply`: wszystko zbudowane zaczyna działać (przewijanie, dźwięk, kolory, SFILE, paleta brzegu na górze i zdarzenia przerwania na nadchodzącą klatkę).
5. `panel_draw`: znaki panelu, które się zmieniły, i nowe znaki napisu, do jego obrazu (po `apply`: może to trochę potrwać, a panel widać dopiero od linii 184).

Gdy obraz jest rysowany, przerwanie przychodzi trzy razy, przy zdarzeniach listy, którą uzbroił `apply` (`ev_panel`): EV_PANEL (obraz panelu od linii 184), EV_GX (X przewijanego napisu), potem przerwanie klatki. Każde przychodzi na prawym brzegu linii przed (HSINT = 208), a VPAGE, GYOFFS, GXOFFS działają od linii po następnej, więc panel jest na miejscu przy każdej szybkości i gdziekolwiek jest praca. Kolory brzegu nie potrzebują przerwania: punkty każdej linii są w pozycji jej koloru jedynej palety.

---

## Pliki Next, takie jak tutaj

Skopiowane z `../src`, ten sam kod:

- `river_gen.asm`, `panel.asm`, `vars.inc`, `font.inc`, `random.inc`: bez zmian.
- `display.asm`, `display_simple.asm`, `spans.asm`: strona SPANS nie jest mapowana (`nextreg $52,SPAN_PAGE` usunięte: okno 1 trzyma SPANS cały czas); `spans.asm` bez `rl_fill`/`rl_next` (pomocników `render_line` w Next).
- `display_hits.asm`: `bsla de,b` (Z80N) jako `shl_de_b`, pętla 0–7 `sla e / rl d` (w `hit_line`: do ~100 taktów więcej na test, kilkaset na klatkę).
- `display_objs.asm`: `ds_obj` zapisuje tylko bajty, które czyta `ob_list` (bez wierszy i `ds_objf`, według których Next rysuje sprite'y i które porównuje nxcheck).
- `game.asm`: `tm_colour` zapisuje BORDER (wpis CRAM: `TM_*` to wolne wpisy grupy 11 od 2, ich kolory ustawia `tm_cram`), a `TM_COLOUR` wywołuje go tylko przy włączonym T; `push_line` przesuwa `scroll` w pierścieniu 512 linii (9 bitów) i rysuje do linii obrazu `scroll + RIVER_TOP`.
- `play.asm`: `clear_layer2_page` jest z TS-Conf (river_raid.asm, DMA); `read_input` bez CAPS + 1 (brak 60 Hz), CAPS + 2 (dźwięk), drugiego Kempstona i pada Mega Drive; jego CAPS + 3 zmienia po kolei trzy taktowania (14, 7, 3,5 MHz).
- `sound.asm`: tylko `sound_driver` i `sound_random`: `pokey_frame` działa na General Sound (`gs/`).
- `render.asm`, `sprites.asm`, `sound_ay.asm`, `load_rom.asm`, `river_raid.asm`: własne TS-Conf (niżej), z nazwami Next tam, gdzie wykonują tę samą pracę.

Procedury pierwszych trzech grup opisuje [docs/CODE.pl.md](../docs/CODE.pl.md); ich koszt tutaj
jest w tabeli wyżej.

## river_raid.asm: klatka, start, przerwanie, kolory

Plik główny: porty płyty, pamięć, strony, `include`, klatka, przerwanie, `apply`, palety rzeki,
zmienne i bufory.

| procedura | wywołanie | co i jak | A / B |
|---|---|---|---|
| `start` | przy ładowaniu | 14 MHz i pamięć podręczna (SYSCONFIG $06), okno 0 RAM (MEMCONFIG $0E), strony, `screen_black`, `load_rom` (wersje SPG), `init_tables`, `init_video`, obrazki sprite'ów (`obj_pics`, `pl_pics`, `panel_pics`), `gs_load`, potem RAM Atari w oknie 0, `panel_init`, `ay_quiet`, ziarno RANDOM, IM 2 (wektory pod $FE00), `restart`. | raz |
| `restart` | `start` | `tv_setup`, obraz wyczyszczony (obie połowy przez DMA, z czekaniem), przerwanie klatki na `FRAME_LINE`, `start_attract`, panel narysowany w całości, przechodzi do `main_frame`. | raz |
| `main_frame` | co klatkę | Zob. *Klatka*. | 340 / 340 |
| `wait_frame` | `main_frame` | HALT do następnego przerwania klatki (`frame_flag` najpierw zerowany: to, które przyszło w trakcie pracy, jest dla `apply` za późne; to tuż przed HALT odsyła go do testu, `irq.frame`): bezczynność, nie praca. | — |
| `irq` | przerwanie | Zdarzenie spod `ev_ptr`: EV_PANEL VPAGE = `VPANEL`, GYOFFS = 0, VCONFIG $8A (256 kolorów, bitmapa nad kafelkami i sprite'ami); EV_GX GXOFFS; zdarzenie klatki (EV_END) `frame_flag`. Przy zdarzeniu klatki przywraca też rejestry obrazu i zdarzenia apply (`river_regs`, `ap_pal`, `ev_go` z `ap_list`): spóźniona klatka pokazuje ostatnią jeszcze raz. Każdy rekord zdarzenia trzyma linię VSINT następnego. EV_PANEL i EV_GX zapisują najpierw swoje porty (zatrzaskiwane na linię po następnej: przy 3,5 MHz akurat na czas), potem VSINT, EI przed popami. Przy 3,5 MHz (linia 224 takty) nic nie ginie ani się nie spóźnia. Trzy na klatkę. | 1 200 / 1 200 |
| `vsint_set` | `irq`, `apply`, `restart` | VSINT = HL (9 bitów), zapamiętany w `ev_line`. | 340 / 330 |
| `apply` | po `wait_frame` | GYOFFS = `show_scroll`, VPAGE rzeki, VCONFIG $81 (16 kolorów), GXOFFS 0; `snd_out` (rejestry AY albo ramka karty); `panel_frame` (X przewijanego napisu do `ev_panel`); kolory pocisku i samolotu do CRAM; `sfile_put`; PALSEL 0 (paleta rzeki) z krawędzią i wodą tej klatki w pozycjach 2 i 3, albo PALSEL 1 (czarna poza kolorami panelu), gdy obraz jest czyszczony po resecie (od jego drugiej klatki) lub kolory są wyłączone (`show_bank` 0); przerwanie uzbrojone na pierwsze zdarzenie `ev_panel` (wokół DI). | 800 / 800 |
| `sfile_put` | `apply` | SFILE budowany w `spr_list`: sprite'y rzeki (S0), za nimi kopiowany `sf_tail` (wpis końcowy z LEAP, 3 sprite'y panelu: wskazówka i logo, S1, koniec); wpisy po nim do końca poprzedniej klatki (`sf_end`) zerowane tamże; potem DMA kopiuje to do SFILE (DMACTRL $85, RAM do SFILE, jedna seria; procesor tylko go programuje). Gdy DMA jest zajęty (czyszczenie po resecie), kopiuje procesor przez okno FM pod $E200. | 1 200 / 1 300 |
| `clear_layer2_page` | `main_frame` podczas `busy`, `restart` | Połowa obrazu rzeki (256 linii × 160 bajtów, 4 strony) na klatkę przez wypełnienie DMA (DMACTRL $14, 80 słów × 256 linii z `dma_zero`); żadnej w pierwszej klatce resetu (`l2_wait`); nic, gdy DMA jest zajęty. Procesor tylko go programuje (~150 taktów). | |
| `dma_wait` | `restart`, `init_video` | Aż DMA będzie wolny (DMACTRL bit 7). | |
| `init_tables` | `start` | Jak na Next (`edge_runs_init`, `ov_exp2/4`, `ring_*`, `span_class`, `edge_lo/hi`, `span_init`); tablice punktów robi `bank_init` (`pix_sets`). | raz |
| `init_video` | `start` | Tryb rzeki (VPAGE 32, VCONFIG $81, PALSEL 0); mapa kafelków (strona 7: linie 0–23 kafelek 1 czarny, 184 kafelek 3 czarna kreska nad szarością, 185–223 kafelek 2 szary, 224–239 czarny; linie rzeki żadne) i punkty kafelków (strona 8); 128K sprite'ów wyczyszczone przez DMA; TSCONFIG $A0 (warstwa kafelków 0 i sprite'y włączone); okno FM włączone na stałe, CRAM i SFILE wyzerowane; kolor czołgu; HSINT, tylko przerwanie klatki (INTMASK 1). | raz |
| `screen_black` | jako pierwsze w `start` | TSCONFIG 0, BORDER 0, cały 1K CRAM i SFILE wyzerowany przez okno FM: czerń, jakikolwiek tryb zostawił Wild Commander (jego ekran ZX w stronie 5 jest tam, gdzie idą bufory startu). | raz |
| `tv_setup` | `restart` | Tylko PAL: `init_line_tables`, kolumny RANDOM dla PAL, `rnd_tables`. | |
| `test_ghost` | wersje testowe | TSGHOST z tscheck, jak w Next. | |

`span_rec` (HL = rekord linii w SPANS) to to samo makro co w Next, pod $4000.

## render.asm: linia do obrazu

| procedura | wywołanie | co i jak | A / B |
|---|---|---|---|
| `render_line` | `line_done` | Najpierw `line_bank`. Takty kolorów 20–179 linii do linii obrazu HL (0–511): strona `VID_PAGE` + linia / 64 w okno 1, linia pod $4000 + (linia & 63) × 256; z kawałków `dl_seg` jak na Next: kawałek jednej wartości to jego kolor z `rl_k1`, 4 razy na bajt (`.fill`: `ld (hl),a / inc l`), bajty krawędzi (tablica w ROM) i wiersz dekoracji przez zestaw tablic punktów linii (`rl_set`: jednej z zieleni), po 4 bajty wyjścia; na linii drogi (`.table_k`) przez tablice pierwszej zieleni, punkty brzegu w pozycji drogi (`rl_sub`). 160 zapisów na linię wzdłuż wiersza (Next pisze 320 w dół kolumn, 10 stron). Na końcu WORK_PAGE z powrotem. Kawałek jednej wartości od 5 bajtów (`RL_DMA_MIN`) idzie zamiast tego do DMA, gdy jest wolne: wypełnienie (DMACTRL $04) z `rl_word` (wartość dwa razy) do strony `rl_page`. W stronie $C000 (przeniesione z $8000 dla miejsca). | 3 700 / 8 700 |
| `line_bank` | `render_line` | `lineBankColour` portu C++, liczony tylko wtedy, gdy może się zmienić: za drogą mostu (`road_row` $7F) nic; na pierwszej linii za nią (`road_row` $7E) raz nowa zieleń (`bank_colour`); na wierszu drogi jego kolor z tablicy pod $B4E5; przed drogą (`road_row` ujemny) `bank_colour`. Kolor inny niż linii przed: jego pozycja do `rl_k1` + $55 i `rl_sub`, `rl_set` (`pix_set0` lub `pix_set1`), skok dla kawałków rodzaju 0/2 (`render_line.kind`: `.table` albo, dla koloru drogi, `.table_k`). `road_row` = $FF, gdy most jest stawiany (`place_object`) lub przywracany (`restore_checkpoint`: $4A + wysokość − $5E), przesuwany o linię w `scroll_objects` do wysokości mostu. | 50 / 100 |
| `bank_init` | `init_video` | Kolory brzegu, każdy raz: $D2, $D6, potem 20 wierszy drogi (`bank_cols`, `bank_n`, najwyżej 8); ich pozycje CRAM w grupie 0: 1, potem 9–15 (`cram_set`); potem `pix_sets`. | raz |
| `pix_sets` | `bank_init` | Tablice punktów dwóch zieleni, po 4 strony (`pix_set0` pod $E700, `pix_set1` pod $DC00): bajt b strony k to punkt k bajtu b, oba półbajty jego pozycja (0, 2, 3 same, 1 zieleni: 1, 9); `rl_k1` (pod $DB00): wartość kawałka 0, $AA, $FF jako jego kolor ($55 ustawia `line_bank`). | raz |

## sprites.asm: sprite'y rzeki

Sprite'y TS-Conf nie mają skalowania, więc każdy obrazek jest trzymany w szerokości 16, 32 i 64
punktów (piksel Atari to 2 punkty; player to 8 pikseli przy rozmiarze ×1, ×2, ×4). Obiekt to
jeden sprite do 24 wierszy (Next robi jeden na 16 wierszy). Palety: obiekty 14 i 15
(`OBJ_PAL_A`, `OBJ_PAL_B`, kolory wierszy na miejscach 1–15), pocisk czołgu i rakieta 8, czołg 9,
samolot i pocisk 10. Wpisy (po 6 bajtów, format SFILE: Y z YS i ACT, X z XS i bitami odbicia,
kafelek i paleta) trafiają do `spr_list`; kopiuje je `apply`.

| procedura | wywołanie | co i jak | A / B |
|---|---|---|---|
| `build_sprites` | `main_frame` | `ob_list`; potem samolot, jego pocisk, czołg, rakieta helikoptera, pocisk czołgu (w kolejności, w jakiej rysuje je `drawRiver`) przez `pl_pattern` + `pl_sprite`; `pl_keep`. Podczas resetu `pl_again`. | 800 / 800 |
| `ob_list` | `build_sprites` | Dla każdego wpisu `ds_objs`: `obj_lookup` po adresach kształtu i koloru górnego wiersza; nieznaleziony: bez sprite'a; pierwszy wiersz poniżej rzeki: bez; inaczej `ob_attr`. | 2 400 / 3 100 |
| `obj_lookup` | `ob_list` | Obrazek bajtu kształtu pod $B900 + E i bajtu koloru pod $B700 + D: `obj_head` (według bajtu kształtu), potem jego łańcuch w `obj_e`; A = obrazek + bit 7 dla `OBJ_PAL_B`. | 1 000 / 1 300 |
| `ob_attr` | `ob_list` | Wpis SFILE: Y = `RIVER_TOP` + miejsce jego linii w rzece (9 bitów) z YS z `pic_h` i ACT; X = 2 × (pozycja − 52) (9 bitów) z XS 1, 3 lub 7 według rozmiaru; kafelek właściwej szerokości (`pic_tn16/32/64_lo/hi`), paleta. | 2 500 / 5 200 |
| `pl_pattern`, `pl_sprite` | `build_sprites` | Obrazek klatki z jej tablicy ($FF: brak); sprite szeroki na 16 punktów na linii D (brak poniżej rzeki), pozycja E, paleta C. | ~100 na sprite |
| `pl_keep`, `pl_again` | `build_sprites` | Wpisy graczy policzone (zostają w `spr_list` do następnej klatki); klatka resetu najpierw je kopiuje (`pl_save`) i pokazuje znowu. | ~100 |
| `cram_set` | start, `init_video` | Wpis CRAM A × 16 + B = kolor Atari E (`palette_lo`). | |

## sprite_pics.asm (INIT_PAGE, przy starcie): obrazki sprite'ów

Do pamięci obrazków 512×512 punktów (SGPAGE, 4 bity na punkt, linia 256 bajtów) przez okno 1;
kafelki obrazka mają 8×8, numerowane (linia / 8) × 64 + x / 8.

| procedura | wywołanie | co i jak |
|---|---|---|
| `gfx_alloc` | `pic_set`, `pl_pics`, `panel_pics` | Miejsce na obrazek szeroki na BC punktów, wysoki na A wierszy (wielokrotność 8): wzdłuż linii, dopóki się mieści, potem na następnych liniach (`gfx_cx`, `gfx_cy`, `gfx_rh`). |
| `gfx_tile` | | Numer kafelka punktu. |
| `gfx_row` | | Wiersz C obrazka: punkty bajtu D (bit 7 pierwszy) w kolorze E w trzech szerokościach (2, 4, 8 punktów na bit) albo tylko w pierwszej (B 1). |
| `obj_pics` | `start` | Jak `obj_pics` w Next: dla typów 7–15 rodzaje, które mogą mieć (własny, rodzaje `ROM_NEXT_KIND` poniżej $0C, rodzaje wybuchu), każdy też odbity, height + 1 wierszy, tak jak rysuje je DLI; każdy obrazek raz (według adresów) w trzech szerokościach; wartość punktu to miejsce koloru jego wiersza w palecie 14 lub 15 (nowy ustawia `cram_set`); `obj_head`/`obj_e` dla `obj_lookup`. |
| `pic_set` | `obj_pics` | Trzy kafelki obrazka `op_p` (przy gfx_x, + 16, + 48) i jego YS. |
| `pl_pics` | `start` | 10 klatek samolotu, 8 czołgu, 7 pocisku czołgu (z ich tablic wskaźników w ROM, jak kopiuje je `prepare`), pocisk i rakieta helikoptera: szerokość 16 punktów, kolor 1; jeden obrazek na adres, $FF dla pustej klatki. |
| `panel_pics` | `start` | Wskazówka (missile 1: 2 takty koloru, 10 wierszy) i logo: player 3 o szerokości 64 punktów (dane $FC), player 2 (dane $FF) w każdym wierszu o takt dalej w lewo (7 wierszy w 32 punktach). |

## panel_ts.asm: panel i przewijany napis

Panel to osobny obraz (strony 64–79, 256 kolorów, 512 bajtów na linię), pokazywany od linii
ekranu 184 (EV_PANEL przerwania klatki), z bitmapą nad kafelkami i sprite'ami (GFXOVR): jego
punkty o wartości 0 to dziury, przez które widać warstwę kafelków 0 (szarość, czerń) i sprite'y
panelu. Kolory 4–7 to PF0–PF3 panelu, 8 — napisu. Napis to pierścień 32 znaków na 512 punktach
obrazu, pokazywany od GXOFFS (EV_GX w jego pierwszej linii).

| procedura | wywołanie | co i jak | A / B |
|---|---|---|---|
| `panel_init` | `start` | Dwa zestawy znaków Atari do jego RAM tam, gdzie buduje je gra (A0FB–A143: napisu pod $0600, panelu pod $0800); kolory (CRAM: znaków jako wpisy 4–8 palety 0, wskazówki, wierszy logo od $B48D, czerń i szarość kafelków jako wpisy 14 i 15 palety 3: paleta rzeki używa tylko wpisów 0–3); znaki narysowane raz (`GLYPHS`: napisu i panelu w jego 4 kolorach), by kopiował je `pc_put`; obraz panelu wyczyszczony; wszystko oznaczone do zapisu w pierwszej klatce. | raz |
| `panel_frame` | `apply` | X napisu (`pf_gx` = 16 TEXT_LO + 38 − 2 FINE_SCROLL, 9 bitów) dla EV_GX przerwania; wskazówka (missile 1 przy fuel / 8 + $5C) i dwa sprite'y logo do `spr_s1` (`.spr`). | 1 600 / 1 600 |
| `panel_draw` | po `apply` | Znaki, które wymienił `panel_put` (`pf_dirty`, wszystkie 60 po kopii), przez `panel_frame.char`; napis: gdy TEXT_LO przesunął się o jeden, jego znak 24 dalej; gdy skoczył, wszystkie 25 (`panel_frame.text`: znak t w punkcie pierścienia 16 t mod 512). | 160 / 160 (+ `pc_*`) |
| `pc_put` | `.char`, `.text` | Znak skopiowany przez DMA stamtąd, gdzie został raz narysowany (`pc_bank`), do obrazu panelu na linię E, punkt HL; gdy DMA jest zajęty (czyszczenie przy resecie), rysuje go `pc_draw`. | |
| `pc_draw` | `pc_put`, `panel_init` | Rysuje 8 wierszy znaku: ustawione punkty w kolorze B, pozostałe 0 (dziury); punkty na lewo od 0 nierysowane. | 700 w A |
| `pc_bank`, `pc_adr`, `pc_reg` | | Gdzie narysowano glif; strona i adres linii; adres DMA do jego rejestrów. | |

## sound.asm, sound_gs.asm, gs_load.asm i gs/: dźwięk na General Sound

`pokey_frame` z Next (jego próbki, impulsy, 17-bitowy licznik) działa na własnym Z80 karty przy
12 MHz; główny procesor raz na klatkę wysyła rejestry POKEY.

| procedura | wywołanie | co i jak | A / B |
|---|---|---|---|
| `sound_driver` | `vbi` | Sterownik oryginału (jak w Next). | 840 / 1 000 |
| `snd_frame` | `main_frame` | Z kartą nic; inaczej `ay_frame`. | |
| `snd_out` | `apply` | Z kartą `gs_send`; inaczej `ay_out`. | |
| `gs_send` | `snd_out` | Komenda `GS_FRAME` ($A5) do portu $BB, potem AUDF1–4 i AUDC1–4 do $B3, każdy gdy karta przeczyta poprzedni (`gs_wait_c`: bit 0 $BB wyzerowany; `gs_wait_d`: bit 7). Przekroczenie czasu (~0,2 s): karta porzucona (`gs_on` 0), od tej pory AY. Większość czasu to czekanie na kartę. | 2 400 / 2 400 |
| `gs_load` | `start` (INIT_PAGE) | Komenda $F0 (status firmware'u): brak odpowiedzi, brak karty; `GS_READY` ($5A) program jest tam z poprzedniego uruchomienia, działamy z nim. Inaczej przez firmware: #12 strona 2 pod $8000, #18 adres, #19/#1B bajty programu (`gs_prog`: `build/gs_pokey.bin` przez incbin), #13 skok do `GS_ORG` ($8400), potem czekanie na `GS_READY` (program najpierw buduje tablice). `gs_on` = 1. | raz |

Program karty, `gs/gs_pokey.asm` (budowany osobno do `build/gs_pokey.bin`):

| procedura | co i jak |
|---|---|
| `gs_start` | IM 2 (wszystkie wektory na `INT_AT` $4141, procedura obsługi tam skopiowana), zmienne wyzerowane, $6000–$63FF każdy bajt równy swojej wartości (odczyt pod $6000 + 256 (n − 1) + v zatrzaskuje v w DAC n), wszystkie cztery głośności na 63; `poly_make`, `tables_make`, pierścień wyciszony, `GS_READY` na zewnątrz. |
| `main` | Czeka na komendę: $F4 (`GS_RESET`) DI, IM 1, JP 0 (znowu firmware); $F0 (`GS_STATE`) w odpowiedzi `GS_READY`; każda inna — 8 bajtów danych do `pokey_audf`/`pokey_audc`, potem `pokey_frame`. |
| `gs_int` | Przerwanie karty, 37 500 na sekundę: DDA (`DDA_STEP` 108 z 256) 15 820 razy na sekundę bierze próbkę z pierścienia i zatrzaskuje ją we wszystkich czterech DAC (`ld a,(hl)` z $6000, $6100, $6200, $6300 + poziom): 1 i 2 lewy, 3 i 4 prawy, każda strona to suma swoich dwóch. |
| `poly_make` | Bity 17-bitowego licznika POKEY do $C000–$FFFF (16K), z rekurencji q(k) = q(k−9) ^ q(k−11) ^ q(k−12) ^ q(k−17) i jej wartości startowych; Next czyta je z `poly17.bin` (16K nie zmieści się w programie karty). |
| `tables_make` | `snd_tables`, `snd_mod15/31`, `g4_tab` (jak `sound_init7` w Next). |
| `pokey_frame`, `snd_fill`, `snd_sum` | Jak w Next, bez AY, zxnDMA i limitu czasu, i po 4 na stopień głośności, a nie 8: tu są wszystkie cztery kanały (w Next tony biorą AY), do 60 × 4 = 240; przy 8 poziomy przekraczały 255, gdy spotykały się wybuchy (syk), a dwa DAC na stronę dają tę samą głośność. Poza tym: próbki przed miejscem przerwania (`rp`) do `SND_LEAD`, najwyżej `SND_CAP`, po nich trzymany ostatni poziom (`SND_HOLD`). |
| `gs_pulses.asm`, `gs_handlers.asm` | `sound_pulses.asm`, `sound_handlers.asm` z Next: wskaźnik 17-bitowego licznika zawija się na $C0 (jego 16K pod $C000), i bez `mul`. |

Jej pamięć: $4000 wektory, $4141 procedura obsługi, od $4200 zmienne, `snd_tables` pod $4300,
`snd_mod15/31` pod $4400/$4500, `g4_tab` kończy się na $4800, stos poniżej $6000; strona 2 pod
$8000: pierścień $8000–$83FF, program od $8400; pod $C000 bity 17-bitowego licznika.

## sound_ay.asm: czyste tony bez karty

| procedura | wywołanie | co i jak | A |
|---|---|---|---|
| `ay_frame` | `snd_frame` | Jak w Next: kanały POKEY grające czysty ton, każdy na własny kanał AY (1 A drugiego układu, 2 jego B, 3 B pierwszego, 4 jego C), N = (AUDF + 1) × 3,454 przez dodawania (`3a + round(a × 116 / 256)`, bez `mul`), głośność przez `ay_vol`; do `ay_regs`. Bez opóźnienia o 2 klatki: bez DAC, z którym trzeba iść w krok, `apply` wypuszcza rejestry tej klatki. | 1 100 |
| `ay_out` | `snd_out` | Rejestry 0–10 dwóch układów (port $FFFD wybiera układ i rejestr, $BFFD wartość). | 2 100 (+ 600 `ay_clear`) |
| `ay_quiet` | `start` | Wszystko wyciszone. | |

## load_rom.asm (INIT_PAGE, wersje SPG): kartridż z karty SD

Wild Commander uruchamia .spg bez folderu i bez DOS, więc program sam czyta kartę przez
Z-kontroler (port $77 bit 1 jego /CS, port $57 bajt w każdą stronę). Bufor sektora to SPANS (po
starcie robiony od nowa).

| procedura | co i jak |
|---|---|
| `load_rom` | `sd_init`, pierwsza partycja MBR (albo cała karta bez tablicy partycji: `lr_bpb`), parametry woluminu FAT, `lr_search` od katalogu głównego; klastry pliku czytane pod $A000 (8192 bajty). Bez niego `lr_fail`: wpis CRAM 1 czerwony i BORDER 1, potem zatrzymanie. |
| `sd_init`, `sd_cmd`, `sd_read` | Tryb SPI (CMD0, CMD8, CMD55 + ACMD41, CMD58: adresy bloków SDHC, inaczej CMD16 512 i adresy bajtowe, `lr_hc`), sektor 512 bajtów. |
| `lr_bpb` | Sektor rozruchowy: FAT16 lub FAT32, sektorów na klaster, adresy FAT, katalogu głównego i danych. |
| `lr_search`, `lr_get`, `lr_advance`, `lr_rewind` | Wpisy folderu po kolei (stały katalog główny FAT16 albo łańcuch klastrów); najpierw pliki, potem foldery, w głąb, do 8 poziomów (`lr_save`/`lr_restore` odkładają przejście). |
| `lr_lfn`, `lr_name`, `lr_upper` | Długa nazwa z jej wpisów LFN (po 13 znaków), porównana z RIVER_RAID.ROM w dowolnej wielkości liter; inaczej krótka nazwa RIVER_~1.ROM. |
| `lr_next`, `lr_clus_lba` | Łańcuch klastrów z FAT (16 lub 32 bity); pierwszy sektor klastra. |

## Pliki dołączane i narzędzia

- `palette_ts.inc`: kolor Atari → słowo CRAM (5 bitów na składową, poziomy 0–24), kolory PAL portu C++ (`make palette`: `tools/mkpalette_ts`).
- `vars.inc`, `font.inc`, `random.inc`: z Next.
- `gs/poly.inc`: 4- i 5-bitowe ciągi POKEY (`tools/mkpoly`).
- `tools/mkspg.py`: plik SPG 1.0 ze stron (`spg_page2/6/5/3.bin`): $8000–$9FFF, $C000–$FFFF, czcionka, kod INIT_PAGE.
- `tools/tscheck.cpp`: rdzeń TSConf z Xpeccy+ (i jego General Sound) obok portu C++, co klatkę.

## Co warto wiedzieć, zanim zmieni się kod

- **Wspólny kod**: zmiana gry (logika, generator, wyświetlanie, kolizje) idzie najpierw do portu C++, potem do `src/` Next, potem do kopii tutaj (`diff ../src/X.asm src/X.asm` pokazuje tylko zmiany wymienione wyżej). Zmiana tego, jak TS-Conf to pokazuje, zostaje tutaj.
- **Okno 1** to WORK_PAGE, poza chwilami, gdy `render_line`, `panel_draw` albo start mapują tam inną stronę; każde z nich przywraca WORK_PAGE (tam żyją SPANS i bufory).
- **Okno FM** pod $E000 jest włączone cały czas: zapisy do $E000–$E3FF idą do CRAM i SFILE (i do RAM pod nimi, tak `apply` je odczytuje); nigdy nie kłaść tam niczego innego.
- **Lista przerwań** jest jedna (`ev_panel`): `apply` wpisuje do niej X przewijanego napisu i uzbraja ją pod DI; jej przerwania przychodzą potem, w pokazywanej klatce.
- **Rejestry zatrzaskiwane na końcu linii** (VPAGE, GYOFFS, GXOFFS): ustawiać w przerwaniu poprzedniej linii; przerwanie przychodzi przy HSINT 208 (prawa ramka), więc przy 3,5–14 MHz jest czas.
- **DMA** dzielą czyszczenie obrazu (`clear_layer2_page`) i znaki panelu (`pc_put`): gdy DMA jest zajęty, `pc_put` rysuje procesorem; korzystają z niego też kopia SFILE (`sfile_put`) i długie odcinki nowej linii (`render_line`), każde zastępowane procesorem, gdy jest zajęty.
- **Testy**: `make check` (3 000 klatek; `FRAMES=`), a także z botem, `-stress`, TSBRIDGE, TSSPEED=1 (7 MHz), TSGS=neo albo 0, jak w [README.pl.md](README.pl.md). Po każdej zmianie: stan, kolor brzegu linia po linii, rejestry General Sound i obraz maszyny co klatkę, piksel w piksel.
- **Pomiary**: `TSHISTALL=plik` (czas każdej instrukcji przez cały przebieg, ze startem, przerwaniami i czekaniem), potem `python3 ../tools/prof.py build/test.sym plik 60`; średnia i najwyższa praca są w ostatnich wierszach tscheck. `TSMSHOT=k` zapisuje każdą klatkę maszyny od klatki k (32, także drugą spóźnionej); `TSBORDER=1` włącza T; `TSSHOT=k` z `TSFULL=1` zapisuje klatki od k z ramką (ostatni obraz przebiegu ma na ramce jeden kolor: przebieg zatrzymuje się na `apply_done`). `TSTIME=N` wypisuje pracę klatek N−2..N+2. `TSVOL=1`: sumy głośności POKEY w klatkach i najwyższy poziom karty (nie może przekroczyć 255). `TSHISTMIN=n` razem z `TSHISTALL`: tylko klatki z pracą n taktów lub więcej (ciężkie; ich liczba jest wypisywana). `TSHISTN=plik` (razem z `TSHISTALL`): ile razy wykonała się każda instrukcja. `TSPAGES=1`: zapisy do PAGE0–3 na klatkę i skąd. `TSNOSCREEN=1`: build z `-DNOSCREEN` (bez pamięci ekranu, jak gra; tylko do pomiarów, pamięć ekranu nie porównywana).
