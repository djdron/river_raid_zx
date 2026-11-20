# River Raid für moderne ZX Spectrums

[English](README.md) | [Русский](README.ru.md) | [Українська](README.uk.md) | Deutsch | [Polski](README.pl.md) | [Italiano](README.it.md) | [Español](README.es.md) | [中文](README.zh.md) | [日本語](README.ja.md)

River Raid (Activision, Atari 8-bit, 1983, von Carol Shaw) auf den heutigen ZX-Spectrum-
Rechnern: dem **ZX Spectrum Next** und **TS-Conf** (ZX Evolution / Pentevo). Beide beruhen auf
dem C++-Port in [djdron/river_raid](https://github.com/djdron/river_raid), der ermittelt, wie
das Original alles macht, und Bild für Bild mit ihm abgeglichen ist. Die Spiellogik ist die des
Originals, Bild für Bild, im selben RAM an denselben Adressen; jeder Rechner zeigt sie mit
seiner eigenen Hardware.

Ein inoffizielles Fanprojekt zu Lernzwecken, ohne Verbindung zu Activision oder Microsoft. Das
Spiel ist nicht enthalten: Das Programm liest zur Laufzeit dein eigenes Cartridge-Abbild.

## Die Ports

| | [ZX Spectrum Next](NEXT.de.md) | [TS-Conf](tsconf/README.de.md) (ZX Evolution / Pentevo) |
|---|---|---|
| Datei | `river_raid.nex` (im Browser geöffnet) | `river_raid.spg` (aus dem Wild Commander gestartet) |
| Das ROM | `River_Raid.rom` im selben Ordner wie die .nex | `River_Raid.rom` irgendwo auf der SD-Karte (FAT16/32) |
| Der Fluss | Layer 2, die Uferfarbe pro Zeile durch den Copper | der 16-Farben-Modus, per Hardware gescrollt, die Uferfarbe pro Zeile durch den Bild-INT (eine Palette pro Farbe) |
| Gegner, Flugzeug, Raketen | Sprites | Sprites |
| Anzeige, Laufschrift | die Tilemap | ein eigenes Bild, unter dem Fluss eingeschaltet, Tiles, Sprites |
| Ton | POKEY vom Programm in den DAC emuliert (zxnDMA), die reinen Töne auf dem AY | alles auf einer General Sound (POKEY vom eigenen Z80 der Karte emuliert, mono); ohne sie die reinen Töne auf den AYs des TurboSound |
| CPU | 28 MHz (reicht auch mit 14) | 14 MHz (reicht auch mit 7) |
| TV | PAL 50 Hz oder NTSC 60 Hz (CAPS + 1) | PAL 50 Hz |
| Einzelheiten | [NEXT.de.md](NEXT.de.md) | [tsconf/README.de.md](tsconf/README.de.md) |

Das Spiel ist auf beiden vollständig: der Attract-Modus, die Spiele 1-8 (Start an Brücke 1, 5,
20 oder 50; ein Spieler oder zwei abwechselnd), das Flugzeug, Treibstoff und Depots, Gegner,
Panzer, die Raketen der Hubschrauber, Brücken, Punkte, Leben, Rekord, Pause, die Anzeige und
die Laufschrift mit dem Regenbogenlogo. Auf echter Hardware lief noch keiner: Beide werden auf
dem Emulator [Xpeccy+](https://github.com/dotkoval/xpeccy-plus) geprüft (seinen Next- und
TSConf-Kernen).

## Bezugsquelle

Die Programme werden bei jedem Push auf GitHub gebaut: [Actions](https://github.com/djdron/river_raid_zx/actions),
der Workflow `build` (die .nex) oder `tsconf` (die .spg), sein Artefakt. Du brauchst dein
eigenes `River_Raid.rom`: das Cartridge-Abbild, 8192 Bytes, ohne Header (wie es der C++-Port
verwendet). Ohne es wird der Rand rot.

## Steuerung

| | Tastatur | Joystick |
|---|---|---|
| fliegen | Q A O P | Kempston |
| feuern | Leertaste oder M | Feuer |
| START | Enter | (Next: START auf einem Mega-Drive-Pad) |
| SELECT (das Spiel, 1-8) | G | (Next: A auf einem Mega-Drive-Pad) |
| Pause | H | |

Der Next hat noch ein paar Tasten mehr (PAL/NTSC, Ton, CPU-Takt, die Zeit des Bildes am
Rand): [NEXT.de.md](NEXT.de.md).

## Wie geprüft wird

Alles, was ändert, was das Spiel tut, kommt zuerst in den C++-Port, dann auf den Next, dann in
die Kopie desselben Codes im TS-Conf-Port. Jeder Port hat eine Prüfung, die das Programm ohne
Fenster auf dem Xpeccy+-Kern laufen lässt, neben dem C++-Port mit derselben Eingabe und
demselben POKEY-Zähler, und beide nach jedem Bild vergleicht: den Spielzustand, den
Flussgenerator, die Anzeige und das Bild Pixel für Pixel (`make check`, `make -C tsconf
check`; ein erfundener Spieler spielt Hunderttausende Bilder). Das Programm für den Next ist
außerdem mit der Original-Cartridge selbst abgeglichen, auf libatari800
(`make check-original`).

## Bauen

```
make deps          # sjasmplus, der C++-Port und Xpeccy+ nach deps/ (git, ein C/C++-Compiler, make, cmake, zlib)
make               # build/river_raid.nex
make -C tsconf     # tsconf/build/river_raid.spg
```

Zum Bauen genügt sjasmplus; die Prüfungen brauchen den Rest und dein ROM unter `rom/River_Raid.rom`.

## Das Repository

| Pfad | Was |
|---|---|
| `src/`, `tools/`, `Makefile` | das Programm für den ZX Spectrum Next und seine Prüfungen ([NEXT.de.md](NEXT.de.md)) |
| `tsconf/` | der TS-Conf-Port: eigenes Projekt und eigener Build, der Spielcode aus `src/` kopiert ([tsconf/README.de.md](tsconf/README.de.md)) |
| [docs/HOW_IT_WORKS.de.md](docs/HOW_IT_WORKS.de.md) | wie Bild, Kollisionen und Ton des Atari auf dem Next und auf TS-Conf entstehen, für alle |
| [docs/NOTES.de.md](docs/NOTES.de.md) | wie das Programm für den Next gemacht ist und was sich zeigte, mit Zahlen |
| [tsconf/NOTES.de.md](tsconf/NOTES.de.md) | das Eigene des TS-Conf-Ports: die Platine, der Interrupt, die General Sound, der Start, mit Zahlen |
| [docs/CODE.de.md](docs/CODE.de.md) | der Assembler-Quelltext für den Next, Routine für Routine |
| [tsconf/CODE.de.md](tsconf/CODE.de.md) | der Assembler-Quelltext für TS-Conf, Routine für Routine, und wie sich die beiden Maschinen unterscheiden |
| [HANDOFF.de.md](HANDOFF.de.md) | der Stand des Projekts, um die Arbeit fortzusetzen |

## Lizenz

Der eigene Code und die Dokumentation des Projekts stehen unter der MIT-Lizenz, siehe
[LICENSE](LICENSE). `src/palette.inc` und `tsconf/src/palette_ts.inc` sind aus dem
Palettenmodell des C++-Ports (MIT) erzeugt. `src/font.inc` und `tsconf/src/font.inc` sind der
Zeichensatz von AltirraOS (Copyright (C) 2008-2018 Avery Lee; frei zu kopieren und zu
verbreiten mit seinem Hinweis, den die Dateien behalten), wie ihn der C++-Port hat: Das ROM des
Atari-OS gehört nicht zur Cartridge. Die Prüfungen verwenden
[Xpeccy+](https://github.com/dotkoval/xpeccy-plus) (MIT) und den Assembler
[sjasmplus](https://github.com/z00m128/sjasmplus) (BSD-3); keins davon ist enthalten,
`make deps` holt sie. River Raid selbst (das ROM, sein Code, Grafik und Ton) gehört seinen
Rechteinhabern und fällt nicht unter diese Lizenz.
