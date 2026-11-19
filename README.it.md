# River Raid per gli ZX Spectrum moderni

[English](README.md) | [Русский](README.ru.md) | [Українська](README.uk.md) | [Deutsch](README.de.md) | [Polski](README.pl.md) | Italiano | [Español](README.es.md) | [中文](README.zh.md) | [日本語](README.ja.md)

River Raid (Activision, Atari 8-bit, 1983, di Carol Shaw) sulle macchine ZX Spectrum di oggi:
lo **ZX Spectrum Next** e **TS-Conf** (ZX Evolution / Pentevo). Entrambi i port si basano sul
port in C++ di [djdron/river_raid](https://github.com/djdron/river_raid), che ricostruisce come
l'originale fa ogni cosa ed è verificato con esso fotogramma per fotogramma. La logica del gioco
è quella dell'originale, fotogramma per fotogramma, nella stessa RAM agli stessi indirizzi;
ogni macchina la mostra con il proprio hardware.

Un progetto amatoriale non ufficiale a scopo didattico, non affiliato ad Activision né a
Microsoft. Il gioco non è incluso: il programma legge durante l'esecuzione la tua immagine
della cartuccia.

## I port

| | [ZX Spectrum Next](NEXT.it.md) | [TS-Conf](tsconf/README.it.md) (ZX Evolution / Pentevo) |
|---|---|---|
| File | `river_raid.nex` (aperto dal Browser) | `river_raid.spg` (avviato da Wild Commander) |
| La ROM | `River_Raid.rom` nella stessa cartella del .nex | `River_Raid.rom` ovunque sulla scheda SD (FAT16/32) |
| Il fiume | Layer 2, il colore della riva riga per riga dal Copper | la modalità a 16 colori con scorrimento hardware, il colore della riva riga per riga dall'INT di quadro (una palette per colore) |
| Nemici, aereo, missili | sprite | sprite |
| Pannello, scritta scorrevole | la tilemap | un'immagine propria attivata sotto il fiume, tile, sprite |
| Il suono | POKEY emulato dal programma nel DAC (zxnDMA), i toni puri sull'AY | tutto su una General Sound (POKEY emulato dallo Z80 della scheda, mono); senza, i toni puri sugli AY del TurboSound |
| CPU | 28 MHz (basta anche 14) | 14 MHz (basta anche 7) |
| TV | PAL 50 Hz o NTSC 60 Hz (CAPS + 1) | PAL 50 Hz |
| Dettagli | [NEXT.it.md](NEXT.it.md) | [tsconf/README.it.md](tsconf/README.it.md) |

Il gioco è completo su entrambi: la modalità attract, le partite 1-8 (partenza dal ponte 1, 5,
20 o 50; un giocatore o due a turno), l'aereo, il carburante e i depositi, i nemici, i carri
armati, i missili degli elicotteri, i ponti, il punteggio, le vite, il record, la pausa, il
pannello e la scritta scorrevole con il logo arcobaleno. Nessuno dei due è ancora stato provato
su hardware reale: entrambi sono verificati sull'emulatore
[Xpeccy+](https://github.com/dotkoval/xpeccy-plus) (i suoi core Next e TSConf).

## Dove trovarlo

I programmi vengono compilati su GitHub a ogni push: [Actions](https://github.com/djdron/river_raid_zx/actions),
il workflow `build` (il .nex) o `tsconf` (lo .spg), il suo artefatto. Serve il tuo
`River_Raid.rom`: l'immagine della cartuccia, 8192 byte, senza intestazione (come la usa il
port in C++). Senza di essa il bordo diventa rosso.

## Comandi

| | Tastiera | Joystick |
|---|---|---|
| volare | Q A O P | Kempston |
| fuoco | Spazio o M | fuoco |
| START | Invio | (Next: START su un pad Mega Drive) |
| SELECT (la partita, 1-8) | G | (Next: A su un pad Mega Drive) |
| pausa | H | |

Il Next ha qualche tasto in più (PAL/NTSC, il suono, la velocità della CPU, il tempo del
fotogramma sul bordo): [NEXT.it.md](NEXT.it.md).

## Come viene verificato

Tutto ciò che cambia il comportamento del gioco si fa prima nel port in C++, poi sul Next, poi
nella copia dello stesso codice nel port per TS-Conf. Ogni port ha una verifica che esegue il
programma sul core di Xpeccy+ senza finestra, accanto al port in C++ con lo stesso input e lo
stesso contatore POKEY, e li confronta dopo ogni fotogramma: lo stato del gioco, il generatore
del fiume, il pannello e l'immagine pixel per pixel (`make check`, `make -C tsconf check`; un
giocatore inventato gioca centinaia di migliaia di fotogrammi). Il programma per il Next è
anche confrontato con la cartuccia originale stessa, eseguita su libatari800
(`make check-original`).

## Compilazione

```
make deps          # sjasmplus, il port in C++ e Xpeccy+ in deps/ (git, un compilatore C/C++, make, cmake, zlib)
make               # build/river_raid.nex
make -C tsconf     # tsconf/build/river_raid.spg
```

Per compilare basta sjasmplus; le verifiche richiedono il resto e la tua ROM in `rom/River_Raid.rom`.

## Il repository

| Percorso | Cosa |
|---|---|
| `src/`, `tools/`, `Makefile` | il programma per lo ZX Spectrum Next e le sue verifiche ([NEXT.it.md](NEXT.it.md)) |
| `tsconf/` | il port per TS-Conf: progetto e compilazione propri, il codice del gioco copiato da `src/` ([tsconf/README.it.md](tsconf/README.it.md)) |
| [docs/HOW_IT_WORKS.it.md](docs/HOW_IT_WORKS.it.md) | come l'immagine e le collisioni dell'Atari sono fatte sul Next, per tutti |
| [docs/NOTES.it.md](docs/NOTES.it.md) | come è fatto il programma per il Next e cosa si è scoperto, con i numeri |
| [docs/CODE.md](docs/CODE.md) | il sorgente assembly per il Next, routine per routine (in inglese e in russo) |
| [tsconf/CODE.md](tsconf/CODE.md) | il sorgente assembly per TS-Conf, routine per routine, e in cosa differiscono le due macchine (in inglese e in russo) |
| [HANDOFF.it.md](HANDOFF.it.md) | lo stato del progetto, per riprendere il lavoro |

## Licenza

Il codice e la documentazione propri del progetto sono sotto licenza MIT, vedi
[LICENSE](LICENSE). `src/palette.inc` e `tsconf/src/palette_ts.inc` sono generati dal modello
di palette del port in C++ (MIT). `src/font.inc` e `tsconf/src/font.inc` sono il font di
AltirraOS (Copyright (C) 2008-2018 Avery Lee; libero da copiare e distribuire con la sua nota,
che i file conservano), come lo ha il port in C++: la ROM del sistema operativo Atari non fa
parte della cartuccia. Le verifiche usano [Xpeccy+](https://github.com/dotkoval/xpeccy-plus)
(MIT) e l'assembler [sjasmplus](https://github.com/z00m128/sjasmplus) (BSD-3); nessuno dei due
è incluso, `make deps` li scarica. River Raid stesso (la ROM, il suo codice, la grafica e il
suono) appartiene ai titolari dei diritti e non è coperto da questa licenza.
