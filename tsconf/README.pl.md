# River Raid na TS-Conf

[English](README.md) | [Русский](README.ru.md) | [Українська](README.uk.md) | [Deutsch](README.de.md) | Polski | [Italiano](README.it.md) | [Español](README.es.md) | [中文](README.zh.md) | [日本語](README.ja.md)

Port na TS-Conf (ZX Evolution / Pentevo): osobny projekt z własnym budowaniem, oddzielnie od
wersji na ZX Spectrum Next ([NEXT.pl.md](../NEXT.pl.md); obie: [strona główna](../README.pl.md)).
Wspólne jest tylko `../deps` (sjasmplus, port C++, Xpeccy+: `make deps` w katalogu głównym).

Gra działa tak samo jak na Next (ta sama logika gry, display i generator rzeki, skopiowane do
`src/`), a pokazywana jest na sposób TS-Conf. Tylko 50 Hz (PAL): ramka płyty.

- Rzeka: tryb 16 kolorów, 320x240, linia obrazu ma 256 bajtów (160 na jej początku), 512 linii
  w pierścieniu przewijanym sprzętowo (GYOFFS); nowa linia rzeki jest pisana od razu w swój
  wiersz (`render.asm`), bez kopiowania.
- Kolor brzegu w każdej linii: każdy kolor, jaki miał brzeg, ma własną paletę (PALSEL 0-7: jej
  kolor 1 to ten kolor, ustawiany raz; 2 i 3 to krawędź i woda, w każdej klatce). Przerwanie
  ramki, przesuwane w dół klatki od zmiany do zmiany (`build_events`, `irq`), ustawia PALSEL
  linię przed zmianą; rejestr jest przejmowany na końcu linii, więc zmiana jest dokładna przy
  każdej szybkości procesora.
- Obiekty, samolot, jego pocisk, czołg i pociski rakietowe: sprite'y (`sprites.asm`), ich
  obrazy tworzone przy starcie z kształtów w kartridżu, każdy obiekt o szerokości 16, 32 i 64
  punktów (sprite'y nie mają skalowania).
- Panel i przewijany napis (`panel_ts.asm`): wiersze 184-239 pochodzą z osobnego obrazu, który
  przerwanie ramki włącza w wierszu 184 (VPAGE, GYOFFS), w trybie 256 kolorów, z bitmapą nad
  kafelkami i sprite'ami (GFXOVR); warstwa kafelków 0 to szarość pod znakami (zasłania tam
  sprite'y rzeki); wskazówka i logo to sprite'y nad nią. Znaki rysowane są raz przy starcie i
  kopiowane przez DMA; przewijany napis to pierścień 32 znaków na 512 punktach obrazu,
  pokazywany od GXOFFS.
- Warstwa kafelków 0 jest też czarna nad rzeką.
- Sterowanie: Q A O P, Spacja lub M ogień, Enter START, G SELECT, H pauza; Kempston.
- Dźwięk: cały na General Sound (oryginalnej karcie lub NeoGS), jeśli jest: własny Z80 karty
  gra POKEY tak jak DAC na Next (`gs/`: `pokey_frame` z Next i jego impulsy, bity 17-bitowego
  licznika karta tworzy sama z ich rekurencji), mono (te same próbki do kanałów 1 i 3, lewego i
  prawego), 15 820 próbek na sekundę (jej przerwanie, 37 500 na sekundę, bierze 108 z 256).
  Start wgrywa program do karty przez jej firmware (`gs_load.asm`; uruchomiony ponownie, znajduje
  program już tam); potem apply raz na klatkę wysyła rejestry POKEY (`sound_gs.asm`). Bez karty
  (albo gdy nie odpowiada): tylko czyste tony (silnik, sygnały, strzał, premia, gwizd pocisku)
  na dwóch AY TurboSound, tak jak gra je Next (`sound_ay.asm`): kanały POKEY 1 i 2 na A i B
  drugiego układu, 3 i 4 na B i C pierwszego. W Xpeccy: włącz General Sound (i TurboSound
  NedoPC dla AY).

Przy 14 MHz praca klatki zajmuje średnio ~69 000 taktów w trybie attract, ~111 000 przy pełnej
prędkości z ciągłym ogniem od mostu 80 (-stress), najwyżej ~181 000, z ~287 000; przy 7 MHz
też się mieści, na styk (najwyżej ~143 000 w -stress, z ~143 400; żadna klatka się nie
spóźnia); przy 3,5 MHz nie nadąża.

Pamięć (okna po 16K): $0000 RAM Atari (strona 1; na czas startu strona 3 z jego pracą), $4000
przebiegi linii i bufory, czcionka OS od $7D00 (strona 5; `render_line` na czas rysowania
wstawia tam stronę obrazu), $8000 program i kartridż od $A000 (strona 2), $C000 program,
bufory i stos (strona 6); obraz rzeki od strony 32, panelu od 64, mapa kafelków w stronie 7,
punkty kafelków w stronie 8, sprite'ów od 24.

    make          build/river_raid.spg: program dla Wild Commandera (SPG 1.0); River_Raid.rom
                  znajduje sam na karcie SD (niżej)
    make sna      build/river_raid.sna: snapshot 128K z twoim ROM-em w środku (../rom/River_Raid.rom)
    make check    uruchamia wersję testową na rdzeniu TSConf z Xpeccy+ i porównuje ją z portem
                  C++ klatka po klatce: stan i obraz każdej klatki (FRAMES=... ile, domyślnie
                  3000), a z General Sound (z Xpeccy+, firmware gs105b.rom) także rejestry,
                  które dostaje karta
    make palette  pisze od nowa src/palette_ts.inc (kolory portu C++ w poziomach płyty)

`build/tools/tscheck` umie też grać: `-bot N` (wymyślony gracz z nxcheck), `-stress`,
`-start N`; TSBRIDGE, TSGHOST, NXGAME jak w nxcheck; TSSPEED=1 przy 7 MHz; TSGS=neo NeoGS,
TSGS=0 bez karty (sprawdzane są tony AY); TSWAV=plik, TSWAVCPP=plik próbki karty i POKEY portu
C++ z tą samą częstotliwością (pliki WAV do posłuchania).

.spg buduje się też na GitHubie (workflow `tsconf`: jego artefakt). Połóż River_Raid.rom (obraz
kartridża, 8192 bajty) gdziekolwiek na karcie SD: program przy starcie przeszukuje kartę
(`load_rom.asm`: jej pierwszą partycję albo całą kartę, FAT16 lub FAT32, najpierw katalog
główny, potem jego foldery, do 8 poziomów; długa nazwa w dowolnej wielkości liter lub krótka
RIVER_~1.ROM). Bez niego: czerwona ramka. Dopóki trwa start, ekran jest czarny
(`screen_black`: cała CRAM od razu czarna, niezależnie od trybu, który zostawił Wild Commander:
jego ekran ZX w stronie 5 jest akurat tam, gdzie start pisze swoje bufory).

`build/tools/tscheck -spg build/river_raid.spg 600 out.ppm -sd folder` uruchamia .spg z folderem
hosta zamiast karty SD (`-img plik`: obraz karty); `-sna build/river_raid.sna 600 out.ppm` —
snapshot.
