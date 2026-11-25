# River Raid na współczesne ZX Spectrum

[English](README.md) | [Русский](README.ru.md) | [Українська](README.uk.md) | [Deutsch](README.de.md) | Polski | [Italiano](README.it.md) | [Español](README.es.md) | [中文](README.zh.md) | [日本語](README.ja.md)

River Raid (Activision, Atari 8-bit, 1983, autorka Carol Shaw) na dzisiejszych komputerach ZX
Spectrum: **ZX Spectrum Next** i **TS-Conf** (ZX Evolution / Pentevo). Oba porty powstały na
bazie portu C++ w [djdron/river_raid](https://github.com/djdron/river_raid), który ustala, jak
oryginał robi wszystko, i jest z nim porównywany klatka po klatce. Logika gry jest taka jak w
oryginale, klatka po klatce, w tym samym RAM pod tymi samymi adresami; każdy komputer pokazuje
ją własnym sprzętem.

Nieoficjalny projekt fanowski w celach edukacyjnych, niezwiązany z Activision ani Microsoft.
Gry w nim nie ma: program w czasie działania czyta twój własny obraz kartridża.

## Porty

| | [ZX Spectrum Next](NEXT.pl.md) | [TS-Conf](tsconf/README.pl.md) (ZX Evolution / Pentevo) |
|---|---|---|
| Plik | `river_raid.nex` (otwierany w Browserze) | `river_raid.spg` (uruchamiany z Wild Commandera) |
| ROM | `River_Raid.rom` w tym samym folderze co .nex | `River_Raid.rom` gdziekolwiek na karcie SD (FAT16/32) |
| Rzeka | Layer 2, punkty brzegu każdej linii rysowane wpisem jej koloru (jedna paleta) | tryb 16 kolorów przewijany sprzętowo, punkty brzegu każdej linii rysowane wpisem jej koloru (jedna paleta) |
| Wrogowie, samolot, pociski | sprite'y | sprite'y |
| Panel, przewijany napis | tilemap | osobny obraz włączany pod rzeką, kafelki, sprite'y |
| Dźwięk | POKEY emulowany przez program do DAC (zxnDMA), czyste tony na AY | cały na General Sound (POKEY emulowany przez własny Z80 karty, mono); bez niej czyste tony na AY TurboSound |
| Procesor | 28 MHz (mieści się też w 14) | 14 MHz (mieści się też w 7) |
| TV | PAL 50 Hz lub NTSC 60 Hz (CAPS + 1) | PAL 50 Hz |
| Szczegóły | [NEXT.pl.md](NEXT.pl.md) | [tsconf/README.pl.md](tsconf/README.pl.md) |

Gra jest kompletna na obu: tryb attract, gry 1-8 (start od mostu 1, 5, 20 lub 50; jeden gracz
albo dwóch na zmianę), samolot, paliwo i składy, wrogowie, czołgi, pociski helikopterów, mosty,
punkty, życia, rekord, pauza, panel i przewijany napis z tęczowym logo. Na prawdziwym sprzęcie
jeszcze nie były uruchamiane: oba sprawdzane są na emulatorze
[Xpeccy+](https://github.com/dotkoval/xpeccy-plus) (jego rdzeniach Next i TSConf).

## Skąd wziąć

Programy budują się na GitHubie przy każdym pushu: [Actions](https://github.com/djdron/river_raid_zx/actions),
workflow `build` (.nex) lub `tsconf` (.spg), jego artefakt. Potrzebny jest własny
`River_Raid.rom`: obraz kartridża, 8192 bajty, bez nagłówka (taki, jakiego używa port C++). Bez
niego ramka robi się czerwona.

## Sterowanie

| | Klawiatura | Joystick |
|---|---|---|
| lot | Q A O P | Kempston |
| ogień | Spacja lub M | ogień |
| START | Enter | (Next: START na padzie Mega Drive) |
| SELECT (gra, 1-8) | G | (Next: A na padzie Mega Drive) |
| pauza | H | |

Next ma jeszcze kilka klawiszy (PAL/NTSC, dźwięk, szybkość procesora, czas klatki na ramce):
[NEXT.pl.md](NEXT.pl.md).

## Jak to jest sprawdzane

Wszystko, co zmienia działanie gry, robi się najpierw w porcie C++, potem na Next, potem w kopii
tego samego kodu w porcie na TS-Conf. Każdy port ma swój test: program działa bez okna na
rdzeniu Xpeccy+ obok portu C++, z tym samym wejściem i tym samym licznikiem POKEY, a po każdej
klatce porównuje się je: stan gry, generator rzeki, panel i obraz piksel w piksel (`make check`,
`make -C tsconf check`; wymyślony gracz rozgrywa setki tysięcy klatek). Program na Next jest
też porównany z samym oryginalnym kartridżem uruchomionym na libatari800
(`make check-original`).

## Budowanie

```
make deps          # sjasmplus, port C++ i Xpeccy+ do deps/ (git, kompilator C/C++, make, cmake, zlib)
make               # build/river_raid.nex
make -C tsconf     # tsconf/build/river_raid.spg
```

Do zbudowania wystarczy sjasmplus; testy potrzebują reszty i twojego ROM-u w `rom/River_Raid.rom`.

## Repozytorium

| Ścieżka | Co |
|---|---|
| `src/`, `tools/`, `Makefile` | program na ZX Spectrum Next i jego testy ([NEXT.pl.md](NEXT.pl.md)) |
| `tsconf/` | port na TS-Conf: osobny projekt i budowanie, kod gry skopiowany z `src/` ([tsconf/README.pl.md](tsconf/README.pl.md)) |
| [docs/HOW_IT_WORKS.pl.md](docs/HOW_IT_WORKS.pl.md) | jak obraz, kolizje i dźwięk Atari powstają na Next i na TS-Conf, dla wszystkich |
| [docs/NOTES.pl.md](docs/NOTES.pl.md) | jak zrobiony jest program na Next i co się okazało, z liczbami |
| [tsconf/NOTES.pl.md](tsconf/NOTES.pl.md) | własne portu na TS-Conf: płyta, przerwanie, General Sound, start, z liczbami |
| [docs/CODE.pl.md](docs/CODE.pl.md) | kod źródłowy w asemblerze dla Next, procedura po procedurze |
| [tsconf/CODE.pl.md](tsconf/CODE.pl.md) | kod źródłowy w asemblerze dla TS-Conf, procedura po procedurze, i czym różnią się obie maszyny |
| [HANDOFF.pl.md](HANDOFF.pl.md) | stan projektu, żeby podjąć pracę |

## Licencja

Własny kod i dokumentacja projektu są na licencji MIT, zob. [LICENSE](LICENSE).
`src/palette.inc` i `tsconf/src/palette_ts.inc` powstały z modelu palety portu C++ (MIT).
`src/font.inc` i `tsconf/src/font.inc` to czcionka AltirraOS (Copyright (C) 2008-2018 Avery
Lee; wolno ją kopiować i rozpowszechniać z jej informacją, którą pliki zachowują), tak jak ma
ją port C++: ROM systemu Atari nie należy do kartridża. Testy używają
[Xpeccy+](https://github.com/dotkoval/xpeccy-plus) (MIT) i asemblera
[sjasmplus](https://github.com/z00m128/sjasmplus) (BSD-3); żadne z nich nie jest dołączone,
`make deps` je pobiera. Sam River Raid (ROM, jego kod, grafika i dźwięk) należy do właścicieli
praw i nie jest objęty tą licencją.
