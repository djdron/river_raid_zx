# River Raid für den ZX Spectrum Next

[English](NEXT.md) | [Русский](NEXT.ru.md) | [Українська](NEXT.uk.md) | Deutsch | [Polski](NEXT.pl.md) | [Italiano](NEXT.it.md) | [Español](NEXT.es.md) | [中文](NEXT.zh.md) | [日本語](NEXT.ja.md)

Teil von [River Raid für moderne ZX Spectrums](README.de.md); der andere Port: [TS-Conf](tsconf/README.de.md). Die Lizenz: [README.de.md](README.de.md#lizenz).

Ein Port von River Raid (Activision, Atari 8-bit, 1983, von Carol Shaw) auf den ZX Spectrum
Next, auf Grundlage des C++-Ports in [djdron/river_raid](https://github.com/djdron/river_raid),
der ermittelt, wie das Original alles macht, und Bild für Bild mit ihm abgeglichen ist.

Ein inoffizielles Fanprojekt zu Lernzwecken, ohne Verbindung zu Activision oder Microsoft. Das
Spiel ist nicht enthalten: Das Programm liest zur Laufzeit dein eigenes Cartridge-Abbild.

Wie es auf dem Next funktioniert, für alle: [docs/HOW_IT_WORKS.de.md](docs/HOW_IT_WORKS.de.md). Um die Arbeit fortzusetzen: [HANDOFF.de.md](HANDOFF.de.md); wie es gemacht ist, mit Zahlen: [docs/NOTES.de.md](docs/NOTES.de.md); der Assembler-Quelltext Routine für Routine: [docs/CODE.de.md](docs/CODE.de.md).

## Stand

Das Spiel, mit Ton. Beim Start läuft der Attract-Modus; START beginnt ein Spiel: Das Flugzeug
fliegt, lenkt, beschleunigt und bremst, schießt, verbraucht Treibstoff und tankt über den
Depots; Gegner, Brücken und Depots explodieren und bringen Punkte; Panzer schießen auf das
Flugzeug, Hubschrauber feuern Raketen; Abstürze, neue Flugzeuge ab der letzten Brücke, ein
Extraflugzeug alle 10 000 Punkte, Spielende und Rekord; SELECT wechselt das Spiel (1-8: vier
Startbrücken, ein Spieler oder zwei abwechselnd), jede Taste pausiert. Unter dem Fluss die
Anzeige (Punkte, Spielnummer, Tankanzeige, Leben, Rekord oder die Punkte des anderen
Spielers, Brücke) und die Laufschrift mit dem Regenbogenlogo, die den Abspann zeigt, solange
kein Spiel läuft. Jedes Bild tut, was das Original tut (die Spiellogik, der Flussgenerator
und was der Display-List-Interrupt zeigt und welche Kollisionen er liest, ermittelt, ohne ihn
abzuspielen), und wird Bild für Bild mit dem C++-Port abgeglichen.

Der Ton: Der Soundtreiber des Originals setzt in jedem Bild die vier Kanäle des POKEY
(abgeglichen mit dem C++-Port); der POKEY selbst wird in Software emuliert, seine Ausgabe in
einen Ring von Samples geschrieben, den der zxnDMA selbstständig an den DAC schickt (15 909
pro Sekunde). Auf einem echten Next noch nicht gehört: Auf dem Kern von Xpeccy+ spielt er,
und die Prüfungen schreiben ihn in eine WAV (`-wav`). In Xpeccy+ die Lautstärken von DAC und
PSG auf 100 stellen (standardmäßig 80): Der DAC spielt die Geräusche, der PSG (AY) die reinen
Töne.

PAL oder NTSC: Das Programm startet als PAL-Atari (der Next mit 50 Hz), CAPS + 1 schaltet auf
einen NTSC-Atari (60 Hz) und zurück, als würde der Rechner neu eingeschaltet. Sie
unterscheiden sich wie die Originale: Das NTSC-Spiel läuft 17% schneller (60 Bilder pro
Sekunde statt 50), Anzeige und Laufschrift liegen höher, das Löschen des Speichers nach einem
Absturz dauert 13 Bilder statt 8, Depots sind auf PAL ab Level $2F etwas seltener und so
weiter (die PAL- und NTSC-Varianten des C++-Ports).

Geschwindigkeit: Bei 28 MHz braucht die Arbeit eines Bildes am Anfang eines Spiels im Schnitt
etwa 21% eines 50-Hz-Bildes, in den schwersten Szenen (alle Gegnerplätze belegt, volle
Geschwindigkeit, Dauerfeuer, ab Brücke 80) höchstens etwa 41%; kein Bild kommt zu spät, weder
auf PAL noch auf NTSC. Also läuft es auch mit 14 MHz: Selbst die schwersten Bilder brauchen
etwa 83% eines 50-Hz-Bildes und 98% eines 60-Hz-Bildes. Der Ton macht davon etwa 25 000 Takte
aus (4% eines Bildes), bis ~40 000 mit Explosionen und der Rakete des Hubschraubers; in einem
vollen Bild macht er weniger Samples und überlässt den Rest den nächsten Bildern.

## Starten

Lege `build/river_raid.nex` und dein `River_Raid.rom` (das Cartridge-Abbild: 8192 Bytes, ohne
Header, wie es der C++-Port verwendet) in denselben Ordner der SD-Karte des Next und öffne die
.nex im Browser. Ohne das ROM (oder mit einer Datei, die nicht die Cartridge ist) wird der Rand
rot und das Programm hält an. Das ROM wird unter seinem langen Namen gesucht, dann unter dem
kurzen `RIVER_~1.ROM`.

| | Tastatur | Joystick |
|---|---|---|
| fliegen | Q A O P | Kempston 1 (der zweite Spieler in einem Zweispielerspiel: Kempston 2 oder derselbe) |
| feuern | Leertaste oder M | Feuer |
| START | Enter | START auf einem Mega-Drive-Pad |
| SELECT (das Spiel, 1-8) | G | A auf einem Mega-Drive-Pad |
| Pause | H (drücken und loslassen; noch einmal zum Weitermachen) | |
| PAL / NTSC | CAPS + 1 (startet neu) | |
| Ton aus / an | CAPS + 2 | |
| 28 MHz / 14 MHz (das Spieltempo bleibt gleich: nur die Restzeit im Bild ändert sich) | CAPS + 3 | |
| die Arbeit des Bildes am Rand, eine Farbe pro Teil: orange apply, grau prepare (und clear_layer2_page während eines Resets), rot display, gelb build_sprites, blau main_loop, magenta push_line (eine neue Flusszeile, innerhalb von main_loop), weiß vbi, cyan pokey_frame, schwarz die übrige Zeit | T (an / aus) | |

Die Spiele 1-8 wie auf dem Atari: Start an Brücke 1, 5, 20 oder 50, ungerade Nummern ein
Spieler, gerade zwei (sie wechseln sich ab; die Tastatur fliegt für beide).

Der Zähler des POKEY, der entscheidet, welcher Gegner wann erwacht, beginnt bei jedem Start
mit einem anderen Wert, wie auf der echten Maschine.

## Bauen

```
make deps    # sjasmplus, der C++-Port und Xpeccy+ nach deps/ (git, ein C/C++-Compiler, make, cmake, zlib)
make         # build/river_raid.nex
```

`make` allein braucht nur sjasmplus (`make SJASMPLUS=...` für eins, das woanders installiert
ist). `src/palette.inc` (das Palettenmodell des C++-Ports), `src/random.inc`, `src/font.inc`,
`src/poly.inc` und `src/poly17.bin` (das Rauschen des POKEY) erzeugt `make palette`.

## Prüfungen

```
make check     # FRAMES=... Bilder (standardmäßig 3000); dein ROM unter rom/River_Raid.rom
make profile   # wohin die Zeit eines Bildes geht (das Bild nach FRAMES)
```

`make check-original` vergleicht das Programm mit der Original-Cartridge selbst, so wie der
C++-Port verglichen wurde: `rr_oracle` (aus dem Repository des C++-Ports, vom Target gebaut:
das Original auf libatari800, braucht git, einen C-Compiler, make, autoconf, automake)
zeichnet Läufe des Originals auf (sein RAM nach jedem Bild, was seine Spiellogik aus RANDOM
gelesen hat, die Eingabe), und `nxcheck -oracle DIR` lässt das Programm mit derselben Eingabe
und denselben RANDOM-Werten laufen und vergleicht nach jedem Bild sein RAM mit dem des
Originals (`Game::diffWithRam`: der Flussgenerator, die Objekte, der Spielzustand, die
Kollisionen, der Player-Missile-Speicher, die Flusszeilen) und macht nach einem Unterschied
vom Zustand des Originals aus weiter. Acht Läufe, 37 000 Bilder: der Attract-Modus, ein
Bot-Spiel bis zum Spielende und ein neuer Start, ein Zweispielerspiel, Fliegen, Tanken, NTSC
und PAL. Alles gleich, bis auf das Bild eines Spielendes in zwei NTSC-Läufen: Dort setzt das
Original den Bildzähler kurz vor oder kurz nach seinem VBI, je nachdem, wie lange die Arbeit
dieses Bildes dauert (der C++-Port, und damit das Programm, nimmt den üblicheren Fall).

`make check` lässt es auf PAL und auf NTSC laufen (`-pal`, `-ntsc`; `-switch N`: CAPS + 1 vor
Bild N). `tools/nxcheck` lässt das Programm ohne Fenster auf dem ZX-Spectrum-Next-Kern von
[Xpeccy+](https://github.com/dotkoval/xpeccy-plus) laufen und daneben den C++-Port
(`rr::Game::frame`, mit demselben POKEY-Zähler und derselben Steuerung). Die Steuerung kommt
von einem erfundenen Spieler: Er wartet im Attract-Modus, wählt manchmal ein anderes Spiel,
drückt START, fliegt zur Mitte des Wassers, weicht Gegnern vor sich aus, fliegt bei wenig
Treibstoff über Depots, schießt, pausiert ab und zu (`-bot N` für andere Entscheidungen,
`-stress` mit voller Geschwindigkeit und Dauerfeuer, `-seed N` für einen anderen
POKEY-Zähler, `-attract` ohne Spieler). Nach jedem Bild vergleicht es den Zustand des
Flussgenerators (`RiverGen::diffWithRam`), den Spielzustand (auch den der Laufschrift), die
Rekorde und die Zeichen der Anzeige, den Bildschirmspeicher (nur im Build für die Prüfung
vorhanden), die Objekte wie gezeichnet (`Game::drawn`), den Speicher des Coppers gegen
seine Liste, den Eintrag der Uferpunkte jeder Flusszeile gegen `lineBank` des C++-Ports; am Ende das Bild des
letzten Bildes Pixel für Pixel: den Fluss, die Anzeige und die Laufschrift (`Game::drawRiver`
und `drawStatusBar` in den Farben des Next). Es meldet auch, was gespielt wurde und wie lange
die Bilder dauern. 4 x 40 000 Bilder mit verschiedenen Spielern (Spiele 1-8, etwa 70 Spiele und
300 Abstürze) sind gleich. Eine Änderung, die etwas kaputt macht, zeigt das erste Bild mit
einem Unterschied und die Felder.

## Wie es funktioniert

| Z80 | 8K-Seite | Was |
|---|---|---|
| $0000-$3FFF | 30, 31 | das RAM des Atari: der Spielzustand an den Adressen des Originals, Player-Missile-Speicher, Bildschirmspeicher (nur im Build für die Prüfung); ein Abzug stimmt Byte für Byte mit dem Original und dem C++-Port überein |
| $4000-$5FFF | 18-27 | ein Fenster auf Layer 2 |
| $6000-$7FFF | 12 | die Zeilen der Objekte (`ds_objs`), Tabellen, die Attribute der Sprites, die Liste des Coppers |
| $8000-$9FFF | 4 | das Programm: das Bild, der Flussgenerator, die Hauptschleife des Spiels |
| $A000-$BFFF | 5 | das Cartridge-Abbild an seinen eigenen Adressen: Die Tabellen werden dort gelesen, wo das Original sie liest |
| $C000-$DFFF | 6 | das Programm: das Spiel, das Display, die Sprites, die Anzeige |
| ($6000-$7FFF) | 7 | nur beim Start: die Zeichensätze, die Tiles, die Sprites der Nadel und des Logos |
| $E000-$FFFF | 1 | Puffer, Tabellen und der Stack |

Jedes Bild (`src/river_raid.asm`):

1. `src/game.asm`, `prepare`: der Panzer und seine Granate unten aus dem Bild verschwunden, die
   Farbe der Granate, die Leben, Brücken und Punkte in die Zeichen der Anzeige
   (`Game::prepare`). Der Next schreibt keinen Player-Missile-Speicher: Die Bilder der Sprites
   und die Zeilen der Kollisionen kommen aus den Formen im ROM.
2. `src/display_simple.asm`, `src/display_hits.asm`: die Arbeit des DLI, ohne den DLI
   (`Game::displayGeometry` im Zweig `dli_removed` des C++-Ports). Jedes Objekt steht in der
   Höhe seines Slots, auf den Fluss zugeschnitten; seine Zeilen gehen nach `ds_objs`. Die
   Kollisionen, die das Spiel liest, sind reine Geometrie: zuerst Rechtecke (gegen die
   Wasserlücken jeder Zeile, gegeneinander), dann die Punkte, wo immer sie sich berühren. Das
   Original liest sie in Fenstern, Objekt für Objekt: 0,01–0,25% der Bilder entscheiden
   anders, eine Berührung ein Bild früher.
3. `src/sprites.asm`: Was der Atari zeigt, wird zu Next-Hardware. Jedes Objekt (Player 3,
   dessen Farbe sich in jeder Zeile ändert) ist ein fertiges Sprite mit seinen Zeilen in ihren
   Farben, an die Position des Objekts gesetzt. Die anderen Player und Missiles sind ebenfalls
   je ein Sprite, an der Position, die das Spiel ihnen gab. Alle ihre Bilder sind 4-Bit-Muster,
   einmal beim Start aus den Formen im ROM gemacht (`src/obj_pics.asm`), also wählt ein Bild
   nur ein Muster und schreibt die Attribute des Sprites (ein Atari-Pixel sind zwei
   Sprite-Pixel; doppelte und vierfache Breite sind die Skalierung des Sprites). Die Uferfarbe
   ändert sich neben einer Brücke: Die Uferpunkte jeder neuen Zeile werden im Eintrag ihrer Farbe in der Palette von Layer 2 gezeichnet.
4. `src/play.asm`, `main_loop`: die Hauptschleife (`Game::mainLoop`): die Steuerung (Tastatur
   und Joysticks, gelesen wie die des Atari), Pause, ein Gegner, der alle 16 Bilder durch das
   RANDOM des POKEY geweckt wird, der Panzer, die Objekte, das Flugzeug (Treibstoff, Lenken,
   Geschwindigkeit, das Geschoss, was es getroffen hat), die Rakete, die Granate, START und
   SELECT, neue Spiele, Abstürze und neue Flugzeuge, und die Flusszeilen für die
   Geschwindigkeit (`src/river_gen.asm`, `river_gen.cpp` Zeile für Zeile), nach Layer 2
   geschrieben. Während das Original nach einem Absturz oder START den Speicher löscht (13
   Bilder), laufen nur das Display und der VBI, und Layer 2 wird zwei Seiten pro Bild
   gelöscht, ab dem zweiten Bild des Resets und verborgen, solange das dauert (sein
   Clip-Fenster enthält nur die Reihen der Anzeige): Der Fluss wird sofort schwarz, wie im
   C++-Port, ohne einen Wisch über den Bildschirm.
5. `src/game.asm`, `vbi`: der Soundtreiber (`src/sound.asm`: die Register des POKEY), der
   Bildzähler, die Farben des nächsten Bildes (das Wasser blinkt rot, wenn eine Brücke
   getroffen wird), der POKEY-Zähler ein Bild weiter (eine Matrix, `src/random.inc`). Dann
   macht `pokey_frame` (`src/sound_frame.asm`) die Samples der POKEY-Ausgabe für den DMA.
6. Unter der Laufschrift (Rasterzeile 208) wird das neue Bild aktiv: Scroll und Farben von
   Layer 2, die Attribute der Sprites, die Anzeige und die Laufschrift, die Liste des Coppers.

Die Anzeige und die Laufschrift sind die Tilemap (40 x 32, 8x8-Tiles mit 4 Bit pro Pixel):
Jedes Atari-Zeichen (8x8, ein Farbtakt pro Pixel) sind zwei Tiles, beim Start aus den
Zeichensätzen gemacht, die das Spiel beim Einschalten aufbaut (die Buchstaben und Ziffern des
OS-Zeichensatzes, die eigenen Symbole der Cartridge); nur die Zeichen, die sich ändern, werden
geschrieben. Der Copper verschiebt die Tilemap zu jeder Zeichenreihe; die Laufschrift ist ein
Ring in ihrer Kartenreihe, seitlich durch den X-Scroll bewegt, und das halbe Zeichen, das an
beiden Rändern zu sehen ist, wird rechts vom Clip-Fenster der Tilemap abgeschnitten und dort
von einem Sprite gezeigt. Das Grau der Anzeige ist das von Layer 2 (seine Farben vom Copper
auf den Zeilen der Anzeige grau gemacht), daher liegt die Tankanzeige (ein Sprite) darüber
und unter den Zeichen, wie auf dem Atari. Das Logo besteht aus fünf Sprites.

Layer 2 (320x256, 256 Farben) hält die 2-Bit-Farbindizes des Playfields; 160 der 192 Farbtakte
einer Zeile werden gezeigt (ab dem 20.; das Wasser kommt den Rändern nie näher), je zwei
Punkte, daher stimmen die Proportionen mit denen des Atari auf 2% überein. Die Farben sind
die PAL-Farben des C++-Ports (Altirras Modell) als 8-Bit-Paletteneinträge des Next.
