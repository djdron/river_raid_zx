# River Raid na ZX Spectrum Next

[English](NEXT.md) | [Русский](NEXT.ru.md) | [Українська](NEXT.uk.md) | [Deutsch](NEXT.de.md) | Polski | [Italiano](NEXT.it.md) | [Español](NEXT.es.md) | [中文](NEXT.zh.md) | [日本語](NEXT.ja.md)

Część [River Raid na współczesne ZX Spectrum](README.pl.md); drugi port: [TS-Conf](tsconf/README.pl.md). Licencja: [README.pl.md](README.pl.md#licencja).

Port River Raid (Activision, Atari 8-bit, 1983, autorka Carol Shaw) na ZX Spectrum Next,
oparty na porcie C++ w [djdron/river_raid](https://github.com/djdron/river_raid), który
ustala, jak oryginał robi wszystko, i jest z nim porównywany klatka po klatce.

Nieoficjalny projekt fanowski w celach edukacyjnych, niezwiązany z Activision ani Microsoft.
Gry w nim nie ma: program w czasie działania czyta twój własny obraz kartridża.

Jak to działa na Next, dla wszystkich: [docs/HOW_IT_WORKS.pl.md](docs/HOW_IT_WORKS.pl.md). Żeby podjąć pracę: [HANDOFF.pl.md](HANDOFF.pl.md); jak to zrobiono, z liczbami: [docs/NOTES.pl.md](docs/NOTES.pl.md); kod źródłowy w asemblerze procedura po procedurze (po angielsku i rosyjsku): [docs/CODE.md](docs/CODE.md).

## Stan

Gra z dźwiękiem. Po uruchomieniu działa tryb attract; START zaczyna grę: samolot leci,
skręca, przyspiesza i zwalnia, strzela, zużywa paliwo i tankuje nad składami; wrogowie, mosty
i składy wybuchają i dają punkty; czołgi strzelają do samolotu, helikoptery wystrzeliwują
pociski; katastrofy, nowe samoloty od ostatniego mostu, dodatkowy samolot co 10 000 punktów,
koniec gry i rekord; SELECT zmienia grę (1-8: cztery mosty startowe, jeden gracz albo dwóch na
zmianę), dowolny klawisz włącza pauzę. Pod rzeką panel (punkty, numer gry, wskaźnik paliwa,
życia, rekord lub punkty drugiego gracza, most) i przewijany napis z tęczowym logo, który
przewija napisy końcowe, gdy nie toczy się gra. Każda klatka robi to, co oryginał (logika gry,
generator rzeki oraz to, co pokazuje przerwanie listy wyświetlania, i kolizje, które ono
czyta, wyliczone bez jego odgrywania), i jest porównywana z portem C++ klatka po klatce.

Dźwięk: sterownik dźwięku oryginału w każdej klatce ustawia cztery kanały POKEY (porównane z
portem C++); sam POKEY jest emulowany programowo, jego wyjście trafia do pierścienia próbek,
który zxnDMA sam wysyła do DAC (15 909 na sekundę). Jeszcze nie słuchany na prawdziwym Next: na
rdzeniu Xpeccy+ gra, a testy zapisują go do WAV (`-wav`). W Xpeccy+ ustaw głośności DAC i PSG
na 100 (domyślnie 80): DAC gra szumy, PSG (AY) czyste tony.

PAL lub NTSC: program startuje jako Atari PAL (Next przy 50 Hz), CAPS + 1 przełącza na Atari
NTSC (60 Hz) i z powrotem, jakby komputer włączono od nowa. Różnią się tak jak oryginały: gra
NTSC idzie o 17% szybciej (60 klatek na sekundę zamiast 50), panel i przewijany napis są
wyżej, czyszczenie pamięci po katastrofie trwa 13 klatek zamiast 8, na PAL od poziomu $2F
składy paliwa są trochę rzadsze itd. (warianty PAL i NTSC portu C++).

Szybkość: przy 28 MHz praca klatki na początku gry zajmuje średnio około 21% klatki 50 Hz, w
najcięższych scenach (wszystkie miejsca wrogów zajęte, pełna prędkość, ciągły ogień, od mostu
80) najwyżej około 41%; żadna klatka się nie spóźnia ani na PAL, ani na NTSC. Działa więc też
przy 14 MHz: nawet najcięższe klatki zajmują około 83% klatki 50 Hz i 98% klatki 60 Hz.
Dźwięk to z tego około 25 000 taktów (4% klatki), do ~40 000 z wybuchami i pociskiem
helikoptera; w zajętej klatce robi mniej próbek i resztę zostawia następnym klatkom.

## Uruchamianie

Połóż `build/river_raid.nex` i swój `River_Raid.rom` (obraz kartridża: 8192 bajty, bez
nagłówka, taki, jakiego używa port C++) w tym samym folderze karty SD Next i otwórz .nex w
Browserze. Bez ROM-u (albo z plikiem, który nie jest kartridżem) ramka robi się czerwona i
program się zatrzymuje. ROM jest szukany po długiej nazwie, potem po krótkiej `RIVER_~1.ROM`.

| | Klawiatura | Joystick |
|---|---|---|
| lot | Q A O P | Kempston 1 (drugi gracz w grze dwuosobowej: Kempston 2 albo ten sam) |
| ogień | Spacja lub M | ogień |
| START | Enter | START na padzie Mega Drive |
| SELECT (gra, 1-8) | G | A na padzie Mega Drive |
| pauza | H (naciśnij i puść; jeszcze raz, żeby grać dalej) | |
| PAL / NTSC | CAPS + 1 (zaczyna od nowa) | |
| dźwięk wył. / wł. | CAPS + 2 | |
| 28 MHz / 14 MHz (szybkość gry jest ta sama: zmienia się tylko czas, jaki zostaje w klatce) | CAPS + 3 | |
| praca klatki na ramce, kolor na każdą część: pomarańczowy apply, szary prepare (i clear_layer2_page podczas resetu), czerwony display, żółty build_sprites, niebieski main_loop, purpurowy push_line (nowa linia rzeki, wewnątrz main_loop), biały vbi, cyjan pokey_frame, czarny pozostały czas | T (wł. / wył.) | |

Gry 1-8 jak na Atari: start od mostu 1, 5, 20 lub 50, nieparzyste jeden gracz, parzyste dwóch
(grają na zmianę; klawiatura steruje oboma).

Licznik POKEY, który decyduje, który wróg i kiedy się budzi, startuje przy każdym
uruchomieniu od innej wartości, jak na prawdziwym komputerze.

## Budowanie

```
make deps    # sjasmplus, port C++ i Xpeccy+ do deps/ (git, kompilator C/C++, make, cmake, zlib)
make         # build/river_raid.nex
```

Samo `make` potrzebuje tylko sjasmplus (`make SJASMPLUS=...` dla zainstalowanego gdzie
indziej). `src/palette.inc` (model palety portu C++), `src/random.inc`, `src/font.inc`,
`src/poly.inc` i `src/poly17.bin` (szum POKEY) tworzy `make palette`.

## Testy

```
make check     # FRAMES=... klatek (domyślnie 3000); twój ROM w rom/River_Raid.rom
make profile   # na co idzie czas jednej klatki (klatki po FRAMES)
```

`make check-original` porównuje program z samym oryginalnym kartridżem, tak jak porównywano
port C++: `rr_oracle` (z repozytorium portu C++, budowany przez ten cel: oryginał na
libatari800, potrzebuje git, kompilatora C, make, autoconf, automake) nagrywa przebiegi
oryginału (jego RAM po każdej klatce, co jego logika gry przeczytała z RANDOM, wejście), a
`nxcheck -oracle DIR` uruchamia program z tym samym wejściem i tymi samymi wartościami RANDOM i
po każdej klatce porównuje jego RAM z RAM-em oryginału (`Game::diffWithRam`: generator rzeki,
obiekty, stan gry, kolizje, pamięć player-missile, linie rzeki), a po różnicy kontynuuje od
stanu oryginału. Osiem przebiegów, 37 000 klatek: tryb attract, gra bota do końca gry i nowy
start, gra dwuosobowa, lot, tankowanie, NTSC i PAL. Wszystko to samo, oprócz klatki końca gry
w dwóch przebiegach NTSC: tam oryginał ustawia licznik klatek tuż przed albo tuż po swoim VBI,
zależnie od tego, jak długo trwa praca tej klatki (port C++, a więc i program, przyjmuje
częstszy przypadek).

`make check` uruchamia go na PAL i na NTSC (`-pal`, `-ntsc`; `-switch N`: CAPS + 1 przed
klatką N). `tools/nxcheck` uruchamia program bez okna na rdzeniu ZX Spectrum Next emulatora
[Xpeccy+](https://github.com/dotkoval/xpeccy-plus), a obok port C++ (`rr::Game::frame`, z tym
samym licznikiem POKEY i tym samym sterowaniem). Sterowanie daje wymyślony gracz: czeka w
trybie attract, czasem wybiera inną grę, naciska START, leci ku środkowi wody, omija wrogów
przed sobą, przelatuje nad składami, gdy brakuje paliwa, strzela, czasem robi pauzę (`-bot N`
dla innych decyzji, `-stress` z pełną prędkością i ciągłym ogniem, `-seed N` dla innego
licznika POKEY, `-attract` bez gracza). Po każdej klatce porównuje stan generatora rzeki
(`RiverGen::diffWithRam`), stan gry (także przewijanego napisu), rekordy i znaki panelu,
pamięć ekranu (jest tylko w wersji do testów), obiekty tak, jak narysowane (`Game::drawn`),
pamięć Coppera i kolory brzegu na jego liście z kolorem brzegu w każdej linii (`Game::scan`);
na końcu obraz ostatniej klatki piksel w piksel: rzekę, panel i przewijany napis
(`Game::drawRiver` i `drawStatusBar` w kolorach Next). Podaje też, co zostało rozegrane i ile
trwają klatki. 4 x 40 000 klatek z różnymi graczami (gry 1-8, około 70 gier i 300 katastrof)
jest takich samych. Zmiana, która to psuje, pokazuje pierwszą klatkę z różnicą i pola.

## Jak to działa

| Z80 | Strona 8K | Co |
|---|---|---|
| $0000-$3FFF | 30, 31 | RAM Atari: stan gry pod adresami oryginału, pamięć player-missile, pamięć ekranu (tylko w wersji do testów); zrzut zgadza się bajt w bajt z oryginałem i portem C++ |
| $4000-$5FFF | 18-27 | okno na Layer 2 |
| $6000-$7FFF | 12 | wiersze obiektów (`ds_objs`), tablice, atrybuty sprite'ów, lista Coppera |
| $8000-$9FFF | 4 | program: klatka, generator rzeki, główna pętla gry |
| $A000-$BFFF | 5 | obraz kartridża pod jego własnymi adresami: tablice są czytane tam, gdzie czyta je oryginał |
| $C000-$DFFF | 6 | program: gra, display, sprite'y, panel |
| ($6000-$7FFF) | 7 | tylko przy starcie: zestawy znaków, kafelki, sprite'y wskazówki i logo |
| $E000-$FFFF | 1 | bufory, tablice i stos |

Każda klatka (`src/river_raid.asm`):

1. `src/game.asm`, `prepare`: czołg i jego pocisk, które zniknęły pod ekranem, kolor pocisku,
   życia, mosty i punkty do znaków panelu (`Game::prepare`). Next nie pisze pamięci
   player-missile: obrazy sprite'ów i wiersze kolizji pochodzą z kształtów w ROM-ie.
2. `src/display_simple.asm`, `src/display_hits.asm`: praca DLI, bez DLI
   (`Game::displayGeometry` w gałęzi `dli_removed` portu C++). Każdy obiekt stoi na wysokości
   swojego slotu, przycięty do rzeki; jego wiersze trafiają do `ds_objs`. Kolizje, które
   czyta gra, to zwykła geometria: najpierw prostokąty (z przerwami wody w każdej linii, ze
   sobą nawzajem), potem punkty, gdziekolwiek się stykają. Oryginał czyta je oknami, obiekt po
   obiekcie: 0,01–0,25% klatek rozstrzyga się inaczej, dotknięcie o klatkę wcześniej.
3. `src/sprites.asm`: to, co pokazuje Atari, staje się sprzętem Next. Każdy obiekt (gracz 3,
   którego kolor zmienia się w każdej linii) to gotowy sprite z wierszami w ich kolorach,
   ustawiony w pozycji obiektu. Pozostali gracze i pociski to też po jednym spricie, w
   pozycji, jaką dała im gra. Wszystkie ich obrazy to 4-bitowe wzory zrobione raz przy starcie
   z kształtów w ROM-ie (`src/obj_pics.asm`), więc klatka tylko wybiera wzór i pisze atrybuty
   sprite'a (piksel Atari to dwa piksele sprite'a; podwójna i poczwórna szerokość to skala
   sprite'a). Kolor brzegu zmienia się przy moście: Copper ustawia go w każdej linii w
   palecie Layer 2.
4. `src/play.asm`, `main_loop`: główna pętla (`Game::mainLoop`): sterowanie (klawiatura i
   joysticki, czytane jak na Atari), pauza, wróg budzony co 16 klatek przez RANDOM POKEY,
   czołg, obiekty, samolot (paliwo, skręty, prędkość, pocisk, w co trafił), pocisk
   helikoptera, pocisk czołgu, START i SELECT, nowe gry, katastrofy i nowe samoloty, oraz
   linie rzeki według prędkości (`src/river_gen.asm`, `river_gen.cpp` linia po linii) pisane
   do Layer 2. Gdy oryginał czyści pamięć po katastrofie lub START (13 klatek), działają tylko
   display i VBI, a Layer 2 jest czyszczony po dwie strony na klatkę, od drugiej klatki resetu,
   i przez ten czas ukryty (jego okno przycinania obejmuje tylko wiersze panelu): rzeka gaśnie
   od razu, jak w porcie C++, bez pasa przesuwającego się po ekranie.
5. `src/game.asm`, `vbi`: sterownik dźwięku (`src/sound.asm`: rejestry POKEY), licznik
   klatek, kolory następnej klatki (woda miga na czerwono, gdy trafiono most), licznik POKEY o
   klatkę dalej (macierz, `src/random.inc`). Potem `pokey_frame` (`src/sound.asm`) robi
   próbki wyjścia POKEY z tej klatki dla DMA.
6. Pod przewijanym napisem (linia rastra 208) włącza się nowy obraz: przewijanie i kolory
   Layer 2, atrybuty sprite'ów, panel i przewijany napis, lista Coppera.

Panel i przewijany napis to tilemap (40 x 32, kafelki 8x8 po 4 bity na piksel): każdy znak
Atari (8x8, takt koloru na piksel) to dwa kafelki, zrobione przy starcie z zestawów znaków,
które gra buduje przy włączeniu (litery i cyfry czcionki OS, własne symbole kartridża);
pisane są tylko znaki, które się zmieniają. Copper przesuwa tilemap do każdego wiersza
znaków; przewijany napis to pierścień w jego wierszu mapy, przesuwany w bok przewijaniem X, a
pół znaku widoczne przy obu krawędziach jest z prawej obcinane oknem przycinania tilemapy i
pokazywane tam przez sprite. Szarość panelu to Layer 2 (Copper robi jego kolory szare na
liniach panelu), więc wskazówka paliwa (sprite) jest nad nią i pod znakami, jak na Atari.
Logo to pięć sprite'ów.

Layer 2 (320x256, 256 kolorów) przechowuje 2-bitowe indeksy kolorów playfieldu; pokazane jest
160 ze 192 taktów koloru linii (od 20.; woda nigdy nie podchodzi bliżej krawędzi), po dwa
punkty, więc proporcje zgadzają się z Atari z dokładnością do 2%. Kolory to kolory PAL portu
C++ (model Altirry) jako 8-bitowe wpisy palety Next.
