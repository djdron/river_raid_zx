# River Raid für TS-Conf

[English](README.md) | [Русский](README.ru.md) | [Українська](README.uk.md) | Deutsch | [Polski](README.pl.md) | [Italiano](README.it.md) | [Español](README.es.md) | [中文](README.zh.md) | [日本語](README.ja.md)

Der Port auf TS-Conf (ZX Evolution / Pentevo): ein eigenes Projekt mit eigenem Build, getrennt
von dem für den ZX Spectrum Next ([NEXT.de.md](../NEXT.de.md); beide: [die Hauptseite](../README.de.md)).
Gemeinsam ist nur `../deps` (sjasmplus, der C++-Port, Xpeccy+: `make deps` oben).

Das Spiel läuft wie auf dem Next (dieselbe Spiellogik, derselbe Display und Flussgenerator,
nach `src/` kopiert) und wird auf die Art des TS-Conf gezeigt. Nur 50 Hz (PAL): das Bild der
Platine.

Wie es auf beiden Maschinen funktioniert, für alle: [../docs/HOW_IT_WORKS.de.md](../docs/HOW_IT_WORKS.de.md).

Wie es auf dieser Platine gemacht ist und was sich zeigte, mit Zahlen: [NOTES.de.md](NOTES.de.md).

Der Quelltext Routine für Routine, was am gemeinsamen Code des Next geändert ist, und eine Tabelle, wie sich die beiden Maschinen unterscheiden: [CODE.de.md](CODE.de.md).

- Der Fluss: der 16-Farben-Modus, 320x240, eine Bildzeile 256 Bytes (160 an ihrem Anfang), 512
  Zeilen als Ring, von der Hardware gescrollt (GYOFFS); eine neue Flusszeile wird direkt in
  ihre Reihe geschrieben (`render.asm`), ohne Kopien.
- Die Uferfarbe pro Zeile: eine Palette (PALSEL 0) hält die Uferfarben, die zwei Grüntöne
  und die Straßenfarben an der Brücke (Einträge 1 und 9-15, einmal beim Start gesetzt), dazu 2
  und 3 Kante und Wasser; die Uferpunkte jeder neuen Zeile werden im Eintrag ihrer Farbe
  gezeichnet (`line_bank`, ein Satz Punkttabellen pro Farbe), so geht die Farbe mit der Zeile:
  kein INT pro Wechsel, nichts zu setzen, während das Bild gezeigt wird.
- Die Objekte, das Flugzeug, sein Geschoss, der Panzer und die Raketen: Sprites
  (`sprites.asm`), ihre Bilder beim Start aus den Formen der Cartridge gemacht, jedes Objekt
  16, 32 und 64 Punkte breit (die Sprites haben keine Skalierung).
- Die Anzeige und die Laufschrift (`panel_ts.asm`): Die Reihen 184-239 kommen aus einem eigenen
  Bild, das der Bild-INT an Reihe 184 einsetzt (VPAGE, GYOFFS), im 256-Farben-Modus mit der
  Bitmap über Tiles und Sprites (GFXOVR); Tile-Ebene 0 das Grau unter den Zeichen (sie verdeckt
  dort die Sprites des Flusses); die Nadel und das Logo als Sprites darüber. Die Zeichen werden
  einmal beim Start gezeichnet und vom DMA kopiert; die Laufschrift ist ein Ring aus 32 Zeichen
  über die 512 Punkte des Bildes, gezeigt ab GXOFFS.
- Tile-Ebene 0 auch schwarz über dem Fluss.
- Steuerung: Q A O P, Leertaste oder M feuern, Enter START, G SELECT, H Pause, T die Arbeit des Frames am Rand (eine Farbe je Teil, wie auf dem Next); Kempston.
- Der Ton: alles auf einer General Sound (der ursprünglichen Karte oder einer NeoGS), wenn eine
  da ist: Der eigene Z80 der Karte spielt POKEY wie der DAC des Next (`gs/`, `pokey_frame` des
  Next und seine Impulse, die Bits des 17-Bit-Zählers macht die Karte selbst aus ihrer
  Rekursion), in Mono (dieselben Samples in alle vier Kanäle: 1 und 2 links, 3 und 4 rechts), mit 15 820
  Samples pro Sekunde (ihr INT, 37 500 pro Sekunde, nimmt 108 von 256). Der Start legt das
  Programm über die Firmware der Karte hinein (`gs_load.asm`; erneut gestartet, findet er es
  noch dort); danach schickt das Apply einmal pro Bild die Register des POKEY (`sound_gs.asm`).
  Ohne Karte (oder wenn sie nicht antwortet): nur die reinen Töne (Motor, Pieptöne, Schießen,
  Bonus, das Pfeifen der Granate) auf den zwei AYs des TurboSound, wie sie der Next spielt
  (`sound_ay.asm`): POKEY-Kanäle 1 und 2 auf A und B des zweiten Chips, 3 und 4 auf B und C
  des ersten. In Xpeccy: General Sound einschalten (und TurboSound NedoPC für die AYs).

Bei 14 MHz braucht die Arbeit eines Bildes im Attract-Modus durchschnittlich ~65 000 Takte,
~108 000 bei voller Geschwindigkeit mit Dauerfeuer ab Brücke 80 (-stress), höchstens ~178 000,
von ~287 000; bei 7 MHz passt es noch, knapp (höchstens ~125 000 mit -stress, von ~143 400;
kein Bild verspätet); bei 3,5 MHz kommt es nicht mit.

Speicher (16K-Fenster): $0000 das RAM des Atari (Seite 1; während des Starts Seite 3 mit seiner
Arbeit), $4000 die Läufe der Zeilen und Puffer, der Zeichensatz des OS ab $7D00 (Seite 5;
`render_line` blendet dort beim Zeichnen eine Seite des Bildes ein), $8000 das Programm und die
Cartridge ab $A000 (Seite 2), $C000 Programm, Puffer und Stack (Seite 6); das Bild des Flusses
ab Seite 32, das der Anzeige ab 64, die Tile-Map in Seite 7, die Punkte der Tiles in Seite 8,
die der Sprites ab 24.

    make          build/river_raid.spg: das Programm für den Wild Commander (SPG 1.0); es
                  findet River_Raid.rom selbst auf der SD-Karte (unten)
    make sna      build/river_raid.sna: ein 128K-Snapshot mit deinem ROM darin (../rom/River_Raid.rom)
    make check    lässt den Test-Build auf dem TSConf-Kern von Xpeccy+ laufen und vergleicht
                  ihn Bild für Bild mit dem C++-Port: den Zustand und das Bild jedes Bildes
                  (FRAMES=... wie viele, standardmäßig 3000), mit einer General Sound (der von
                  Xpeccy+, Firmware gs105b.rom) auch die Register, die die Karte bekommt
    make palette  schreibt src/palette_ts.inc neu (die Farben des C++-Ports in den Stufen der Platine)

`build/tools/tscheck` spielt auch: `-bot N` (der erfundene Spieler von nxcheck), `-stress`,
`-start N`; TSBRIDGE, TSGHOST, NXGAME wie bei nxcheck; TSSPEED=1 mit 7 MHz; TSBORDER=1 T an (TSFULL=1 mit TSSHOT=k: die Frames mit Rand); TSGS=neo eine
NeoGS, TSGS=0 keine Karte (die Töne des AY werden geprüft); TSWAV=Datei, TSWAVCPP=Datei die
Samples der Karte und der POKEY des C++-Ports mit dieser Rate (WAVs zum Anhören).

Die .spg wird auch auf GitHub gebaut (der Workflow `tsconf`: sein Artefakt). Lege
River_Raid.rom (das Cartridge-Abbild, 8192 Bytes) irgendwo auf die SD-Karte: Das Programm
durchsucht die Karte beim Start (`load_rom.asm`: ihre erste Partition oder die ganze Karte,
FAT16 oder FAT32, zuerst das Hauptverzeichnis, dann seine Ordner, 8 tief; der lange Name in
beliebiger Schreibung oder der kurze RIVER_~1.ROM). Ohne es: ein roter Rand. Während der Start
arbeitet, ist der Bildschirm schwarz (`screen_black`: das ganze CRAM auf einmal schwarz, egal
welchen Modus der Wild Commander hinterlassen hat: Sein ZX-Bildschirm in Seite 5 ist genau dort,
wo der Start seine Puffer anlegt).

`build/tools/tscheck -spg build/river_raid.spg 600 out.ppm -sd Ordner` lässt die .spg mit einem
Ordner des Hosts als SD-Karte laufen (`-img Datei`: ein Kartenabbild); `-sna
build/river_raid.sna 600 out.ppm` den Snapshot.
