# River Raid na TS-Conf — notatki

[English](NOTES.md) | [Русский](NOTES.ru.md) | [Українська](NOTES.uk.md) | [Deutsch](NOTES.de.md) | Polski | [Italiano](NOTES.it.md) | [Español](NOTES.es.md) | [中文](NOTES.zh.md) | [日本語](NOTES.ja.md)

Jak zrobiony jest port na TS-Conf i co wyszło po drodze, z liczbami. Sama gra (logika, generator rzeki, rozmieszczanie obiektów i kolizje) to kod Next skopiowany do `src/`: czego się o nim dowiedziano, jest w [docs/NOTES.pl.md](../docs/NOTES.pl.md) Next. Tutaj: to, co własne TS-Conf. Procedury po kolei są w [CODE.pl.md](CODE.pl.md).

## Płyta, jak jest używana
- **Procesor**: Z80 na 14 MHz z włączoną pamięcią podręczną (SYSCONFIG $06), ustawiany przy starcie. Brak instrukcji Z80N: `nextreg` stał się `ld bc,port / out (c),a`, `bsla de,b` pętlą (`shl_de_b`), `mul` dodawaniami.
- **Pamięć**: okna 16K (PAGE0–PAGE3). Okno 0 to RAM z zapisem (MEMCONFIG $0E), więc RAM Atari leży od $0000 pod adresami oryginału (strona 1), jak na Next. Praca startu (obrazki sprite'ów, karta SD, program General Sound) jest, póki trwa, we własnej stronie (3) od $0000; potem wchodzi tam RAM Atari.
- **Rzeka**: 16 kolorów (VCONFIG $81), 320×240, linia 256 bajtów (2 punkty w bajcie, widać 160 bajtów), 512 linii w pierścieniu od strony 32 (16 stron), przewijane przez GYOFFS (9 bitów). Nowa linia to 160 bajtów wzdłuż jej wiersza w jednej stronie (Next pisze 320 bajtów w dół kolumn na 10 stronach). Linie rzeki to linie ekranu 24–183.
- **Kolory**: CRAM (512 bajtów, kolor to 15-bitowe słowo, 5 bitów na składową z poziomami 0–24, `palette_ts.inc` z kolorów PAL portu C++) i lista sprite'ów (SFILE, 512 bajtów) przez okno FM pod $E000, włączone na stałe. Zapis tam idzie do CRAM i do RAM pod nim, z którego `apply` czyta z powrotem.
- **Kolor brzegu linia po linii**: kolory trybu 16-kolorowego pochodzą z jednej z 16 palet, której — mówi PALSEL, zatrzaskiwany na końcu linii. Każdy kolor brzegu, jaki rzeka już miała, dostaje własną paletę (`pal_get`: jej kolor 1; kolory 2 i 3, krawędź i woda, wpisywane do wszystkich co klatkę); przerwanie, przesuwane w dół klatki od zmiany do zmiany, ustawia PALSEL linię wcześniej. Coppera nie ma: przerwanie jest Copperem.
- **Przerwanie**: tylko przerwanie klatki (INTMASK 1), IM 2, wektor pod $FEFF. VSINT stawia je na dowolną linię, HSINT 208 na prawą ramkę linii. Lista na klatkę (`build_events`, `apply`): EV_PAL paleta rzeki, EV_PANEL obraz panelu od linii 184, EV_GX X przewijanego napisu, potem przerwanie klatki pod panelem (`FRAME_LINE`), które kończy HALT w `wait_frame`. Zdarzenia z jednej linii są obsługiwane razem. Dwa bufory (`ev_a`, `ev_b`): jeden się buduje, gdy drugi jest pokazywany.
- **Sprite'y**: do 85 w SFILE, dowolnego rozmiaru do 64×64 w krokach po 8 punktów, 16 kolorów z palety 16, ich punkty w jednym obrazie 512×512 (SGPAGE, strony 24–31, 4 bity na punkt). Bez skalowania, więc każdy obrazek powstaje przy starcie trzy razy, szeroki na 16, 32 i 64 punkty. S0, sprite'y rzeki, pod warstwą kafelków 0; S1, wskazówka i logo, nad nią.
- **Warstwa kafelków 0** (mapa w stronie 7, kafelki w stronie 8): czarna w liniach 0–23 (nad rzeką) i 224–239, szara pod panelem (185–223, linia 184 to czarna kreska, potem szarość). Zakrywa to, co sprite'y rzeki mają poza rzeką: okno przycinania niepotrzebne.
- **Panel**: własny obraz (strony 64–79, 256 kolorów), włączany od linii 184 zdarzeniem EV_PANEL (VPAGE, GYOFFS = 0, VCONFIG $8A: 256 kolorów, bitmapa nad kafelkami i sprite'ami, GFXOVR). Jego punkty o wartości 0 to dziury: pod nimi szarość warstwy kafelków 0 i sprite'y S1. Kolory 4–7 to PF0–PF3 panelu, 8 — przewijanego napisu.
- **DMA**: czyści obraz rzeki po resecie (wypełnienie, pół obrazu na klatkę) i 128K sprite'ów przy starcie oraz kopiuje znaki panelu stamtąd, gdzie zostały raz narysowane.
- **Sterowanie**: klawiatura (Q A O P, Space lub M, Enter, G, H) i Kempston pod $1F. Brak 60 Hz (klatka płyty to 50 Hz), brak CAPS + 2/3 i T.

## Klatka
`main_frame`: jak na Next (`prepare`, `display`, `build_sprites`, `main_loop`, `vbi`), z `build_events` po sprite'ach i `snd_frame` na końcu; potem `wait_frame` (HALT do przerwania klatki), `apply`, `panel_draw`. `apply` przychodzi z przerwaniem klatki pod panelem (linia 241 z 240: w dolnej ramce), więc wszystko, co ustawia, jest gotowe na pierwszą linię następnego obrazu: przewijanie i tryb rzeki, dźwięk, kolory, SFILE, paleta u góry i przerwanie ustawione na pierwsze zdarzenie listy. `panel_draw` pisze znaki panelu po nim: panel widać dopiero od linii 184, ponad klatkę pracy później.

Gdy po resecie czyszczony jest obraz (od jego drugiej klatki), paleta rzeki i kolory krawędzi i wody są czarne, więc rzeka od razu czernieje, jak ekran portu C++.

## Start
- **SPG** (SPG 1.0, `tools/mkspg.py`): ładowany i uruchamiany przez Wild Commandera. Jego obszar rezydentny musi być $5B00: z 0 WC go nie uruchamiał.
- **Czarny ekran**: Wild Commander zostawia własny tryb (VPAGE 5, VCONFIG 0: ekran ZX w stronie 5), a strona 5 to miejsce, gdzie start pisze bufory, więc przez ~40 klatek startu widać było śmieci. `screen_black`, pierwsze wywołanie startu: TSCONFIG 0 (bez sprite'ów i kafelków), BORDER 0, cały 1K CRAM i SFILE wyzerowany przez okno FM. Jakikolwiek tryb zostanie, pokazuje czerń. (Sprawdzone w tscheck z CRAM wcześniej wypełnioną kolorem, `TSCRAM=1`: stara wersja pokazywała nieczarne klatki, ta żadnej.)
- **Kartridż z karty SD**: WC nie daje programowi ani folderu, ani DOS, więc `load_rom.asm` czyta kartę przez Z-kontroler (SPI, adresy bloków SDHC albo bajtowe adresy SD), pierwszą partycję MBR albo całą kartę, FAT16 lub FAT32, najpierw katalog główny, potem każdy folder w głąb, do 8 poziomów; długa nazwa River_Raid.rom w dowolnej wielkości liter albo krótka RIVER_~1.ROM. Bez pliku: wpis CRAM 1 czerwony i BORDER 1 (reszta CRAM czarna), i zatrzymanie.

## Dźwięk
- **Na General Sound**: Z80 karty (12 MHz) wykonuje `pokey_frame` Next i jego impulsy (`gs/`: bez AY, zxnDMA i limitu czasu; wskaźnik 17-bitowego licznika zawija się na $C0, bez `mul`). Jej własne przerwanie, 37 500 razy na sekundę, bierze próbkę z pierścienia 108 razy na 256 (DDA: 15 820 na sekundę, częstotliwość PAL POKEY 15 834) i zatrzaskuje ją w czterech DAC (odczyt pod $6000 + 256 (n − 1) + poziom). Główny procesor co klatkę wysyła komendę i 8 rejestrów POKEY (`gs_send`), każdy gdy karta przeczyta poprzedni: ~2 400 taktów na klatkę, głównie czekanie.
- **17-bitowy licznik** to 16K bitów; program karty go nie przenosi (ładowanie miałoby 18K zamiast ~1,9K), tylko buduje przy starcie z rekurencji q(k) = q(k−9) ^ q(k−11) ^ q(k−12) ^ q(k−17) z trzech bajtów startowych ($CF, $37, $33). tscheck porównuje go z `poly17.bin`: dokładnie.
- **Wzmocnienie**: wszystkie cztery kanały POKEY idą na DAC karty (na Next czyste tony idą na AY), a ich głośności sumują się do 41 (`-stress` od mostu 30: dwa wybuchy z szumem silnika). Przy 8 na stopień głośności, jak na Next, to ponad 255, suma bieżąca się zawijała i dźwięk syczał (usłyszał to użytkownik: wybuch pocisku czołgu, gdy trafiano statek). Teraz 4 na stopień (najwyżej 240, wszystkie cztery na 15) i ta sama próbka we wszystkich czterech DAC, 1 i 2 lewy, 3 i 4 prawy: każda strona to suma swoich dwóch, tak głośno jak 8 na jednym. `TSVOL=1` drukuje sumy i najwyższy poziom karty (164 w tym przebiegu).
- **Ładowanie programu** (`gs_load`): najpierw komenda $F0, „status” firmware'u. Brak odpowiedzi: brak karty. `GS_READY` ($5A): nasz program jest już tam z poprzedniego uruchomienia (karta trzyma go do wyłączenia zasilania), działamy z nim. W przeciwnym razie przez firmware: #12 strona 2 pod $8000, #18 adres, #19/#1B bajty, #13 skok do $8400, potem czekanie na `GS_READY` (program najpierw buduje tablice). Pierwsza wersja najpierw resetowała kartę komendą $F4: na karcie 2M w Xpeccy+ firmware startuje ~5 s i ładowanie przekraczało limit czasu. Karta, która przestaje odpowiadać w trakcie gry, jest porzucana (`gs_on` 0) i od tej pory gra AY. Otwarte: nowsza wersja nie jest ładowana na stary program, który został w karcie.
- **Bez karty**: czyste tony na dwóch AY TurboSound (NedoPC), jak na Next: POKEY 1 i 2 to A i B drugiego układu, 3 i 4 to B i C pierwszego, okresy dodawaniami. Bez opóźnienia o 2 klatki jak na Next (tam czekają na próbki DAC); `apply` wypuszcza rejestry tej klatki. ~5 800 taktów na klatkę ze sterownikiem.
- **Sprawdzone**: po każdej klatce rejestry, które ma karta, wobec POKEY portu C++ z klatki wcześniej (wysokość szumu z RANDOM pomijana, jak w nxcheck); `TSWAV`/`TSWAVCPP` zapisują próbki karty i PokeySound portu C++ z częstotliwością karty, obwiednie poziomu podobne (0,96 przy przesunięciu ~2 klatek). Także NeoGS (`TSGS=neo`) i bez karty (`TSGS=0`).

## Szybkość
Takty przy 14 MHz, ~286 800 na klatkę. tscheck: praca od `apply_done` do `frame_done` (bez czekania na przerwanie); `TSHISTALL` dla procedur.

| przebieg | średnio | najcięższa | spóźnione |
|---|---|---|---|
| bot 1, 3 000 klatek od startu | ~74 000 | ~124 000 | 0 |
| `-stress` od mostu 80 (wszystkie sloty zajęte, pełny gaz, ciągły ogień), 6 000 | ~116 000 | ~153 000 | 0 |
| to samo przy 7 MHz (~143 400 na klatkę) | ~96 000 | ~143 000 | 0 |

Przy 3,5 MHz nie nadąża. Według części w najcięższych scenach: wyświetlanie (rozmieszczanie i kolizje) ~57 000, nowe linie rzeki ~34 000, sprite'y i zdarzenia palety ~16 000, apply, panel i przerwania ~7 000, logika gry ~9 000, dźwięk ~3 500 (na karcie).

Liczby pochodzą z wersji testowej (`-DTEST`: z pamięcią ekranu Atari, której gra nie ma); gra jest lżejsza o ~1 000–2 500.

## Testy (tools/tscheck.cpp)
Rdzeń TSConf z Xpeccy+ (i jego General Sound) jako biblioteka, bez okna, obok portu C++. Wersja testowa: strony programu wkładane do RAM, kartridż pod $A000, start od $8000; ten sam licznik POKEY i sterowanie (bot z nxcheck) dla obu. Po każdej klatce: stan gry, kolor brzegu linia po linii (`ev_built` wobec portu C++), rejestry General Sound i obraz maszyny dla klatki, piksel w piksel (także panel). `make check` 3 000 klatek; poza tym `-bot N`, `-stress`, `TSBRIDGE`, `TSGHOST`, `NXGAME`, `TSSPEED=1`, `TSGS=neo|0`. `-spg plik klatki out.ppm -sd folder` uruchamia sam plik .spg z folderem hosta jako kartą SD (`-img` obraz karty), `-sna` snapshot.

## Czego nauczyły błędy
- Pierwszy sposób zmiany koloru brzegu linia po linii zapisywał kolor do CRAM w przerwaniu: przy 7 MHz przerwanie przychodziło za późno i linia pokazywała zły kolor. Paleta na kolor i PALSEL (zatrzaskiwany na końcu linii) są dokładne przy każdej szybkości (pomysł użytkownika: wypełnić palety raz).
- W emulatorze bajt zapisany wprost do CRAM nie zmienia widocznych kolorów, dopóki jego paleta nie zostanie przeliczona: test wypełniający CRAM potrzebuje `tslUpdatePal`.
- Własny reset firmware'u GS ($F4) trwa sekundy; zamiast tego pytać o jej stan ($F0).
- Suma poziomów ponad 255 zawija się po cichu: próbki wyglądają normalnie, znajduje to tylko ucho. Sumować głośności (`TSVOL`), a nie oglądać próbki.
- `make check` nie uruchamia pliku .spg: start (karta SD, ekran, ładowanie do GS) sprawdza się przez `-spg … -sd`.
- Jeszcze nie uruchamiane na prawdziwej płycie: klawiatura, Kempston, karta SD, prawdziwy firmware GS i NeoGS są takie, jak modeluje je Xpeccy+.
