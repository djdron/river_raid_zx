# River Raid per lo ZX Spectrum Next

[English](NEXT.md) | [Русский](NEXT.ru.md) | [Українська](NEXT.uk.md) | [Deutsch](NEXT.de.md) | [Polski](NEXT.pl.md) | Italiano | [Español](NEXT.es.md) | [中文](NEXT.zh.md) | [日本語](NEXT.ja.md)

Parte di [River Raid per gli ZX Spectrum moderni](README.it.md); l'altro port: [TS-Conf](tsconf/README.it.md). La licenza: [README.it.md](README.it.md#licenza).

Un port di River Raid (Activision, Atari 8-bit, 1983, di Carol Shaw) per lo ZX Spectrum Next,
basato sul port in C++ di [djdron/river_raid](https://github.com/djdron/river_raid), che
ricostruisce come l'originale fa ogni cosa ed è verificato con esso fotogramma per fotogramma.

Un progetto amatoriale non ufficiale a scopo didattico, non affiliato ad Activision né a
Microsoft. Il gioco non è incluso: il programma legge durante l'esecuzione la tua immagine
della cartuccia.

Come funziona sul Next, per tutti: [docs/HOW_IT_WORKS.it.md](docs/HOW_IT_WORKS.it.md). Per riprendere il lavoro: [HANDOFF.it.md](HANDOFF.it.md); come è fatto, con i numeri: [docs/NOTES.it.md](docs/NOTES.it.md); il sorgente assembly routine per routine: [docs/CODE.it.md](docs/CODE.it.md).

## Stato

Il gioco, con il suo suono. All'avvio parte la modalità attract; START comincia una partita:
l'aereo vola, sterza, accelera e rallenta, spara, consuma carburante e fa rifornimento sopra i
depositi; nemici, ponti e depositi esplodono e danno punti; i carri armati sparano all'aereo,
gli elicotteri lanciano missili; schianti, nuovi aerei dall'ultimo ponte, un aereo in più ogni
10 000 punti, fine partita e record; SELECT cambia partita (1-8: quattro ponti di partenza, un
giocatore o due a turno), un tasto qualsiasi mette in pausa. Sotto il fiume il pannello
(punteggio, numero della partita, indicatore del carburante, vite, record o punteggio
dell'altro giocatore, ponte) e la scritta scorrevole con il logo arcobaleno, che fa scorrere i
titoli quando non si gioca. Ogni fotogramma fa ciò che fa l'originale (la logica del gioco, il
generatore del fiume, e ciò che mostra l'interrupt della display list e le collisioni che
legge, ricavati senza eseguirlo) ed è verificato con il port in C++ fotogramma per
fotogramma.

Il suono: il driver audio dell'originale imposta a ogni fotogramma i quattro canali del POKEY
(verificati con il port in C++); il POKEY stesso è emulato in software, la sua uscita scritta
in un anello di campioni che lo zxnDMA invia da solo al DAC (15 909 al secondo). Non ancora
ascoltato su un Next reale: sul core di Xpeccy+ suona, e le verifiche lo scrivono in un WAV
(`-wav`). In Xpeccy+ porta i volumi di DAC e PSG a 100 (sono 80 di default): il DAC suona i
rumori, il PSG (AY) i toni puri.

PAL o NTSC: il programma parte come un Atari PAL (il Next a 50 Hz), CAPS + 1 passa a uno NTSC
(60 Hz) e ritorno, come se la macchina venisse riaccesa. Differiscono come gli originali: il
gioco NTSC va il 17% più veloce (60 fotogrammi al secondo invece di 50), il pannello e la
scritta scorrevole sono più in alto, la pulizia della memoria dopo uno schianto dura 13
fotogrammi invece di 8, sul PAL dal livello $2F i depositi sono un po' più rari e così via (le
varianti PAL e NTSC del port in C++).

Velocità: a 28 MHz il lavoro di un fotogramma occupa in media circa il 21% di un fotogramma a
50 Hz all'inizio di una partita, al massimo circa il 41% nelle scene più pesanti (tutti gli
slot dei nemici occupati, velocità massima, fuoco continuo, dal ponte 80); nessun fotogramma è
in ritardo né in PAL né in NTSC. Quindi gira anche a 14 MHz: anche i fotogrammi più pesanti
occupano circa l'83% di un fotogramma a 50 Hz e il 98% di uno a 60 Hz. Il suono ne è circa
25 000 cicli (il 4% di un fotogramma), fino a ~40 000 con esplosioni e il missile
dell'elicottero; in un fotogramma pieno fa meno campioni e lascia il resto ai fotogrammi
successivi.

## Avvio

Metti `build/river_raid.nex` e il tuo `River_Raid.rom` (l'immagine della cartuccia: 8192
byte, senza intestazione, come la usa il port in C++) nella stessa cartella della scheda SD del
Next e apri il .nex dal Browser. Senza la ROM (o con un file che non è la cartuccia) il bordo
diventa rosso e il programma si ferma. La ROM si cerca per nome lungo, poi per nome corto
`RIVER_~1.ROM`.

| | Tastiera | Joystick |
|---|---|---|
| volare | Q A O P | Kempston 1 (il secondo giocatore in una partita a due: Kempston 2, o lo stesso) |
| fuoco | Spazio o M | fuoco |
| START | Invio | START su un pad Mega Drive |
| SELECT (la partita, 1-8) | G | A su un pad Mega Drive |
| pausa | H (premi e rilascia; di nuovo per continuare) | |
| PAL / NTSC | CAPS + 1 (riparte) | |
| suono spento / acceso | CAPS + 2 | |
| 28 MHz / 14 MHz (la velocità del gioco è la stessa: cambia solo il tempo che resta nel fotogramma) | CAPS + 3 | |
| il lavoro del fotogramma sul bordo, un colore per parte: arancione apply, grigio prepare (e clear_layer2_page durante un reset), rosso display, giallo build_sprites, blu main_loop, magenta push_line (una nuova riga del fiume, dentro main_loop), bianco vbi, ciano pokey_frame, nero il tempo che resta | T (acceso / spento) | |

Le partite 1-8 come sull'Atari: partenza dal ponte 1, 5, 20 o 50, i numeri dispari un
giocatore, i pari due (giocano a turno; la tastiera pilota per entrambi).

Il contatore del POKEY, che decide quale nemico si sveglia e quando, parte a ogni avvio da un
valore diverso, come sulla macchina reale.

## Compilazione

```
make deps    # sjasmplus, il port in C++ e Xpeccy+ in deps/ (git, un compilatore C/C++, make, cmake, zlib)
make         # build/river_raid.nex
```

`make` da solo richiede solo sjasmplus (`make SJASMPLUS=...` per uno installato altrove).
`src/palette.inc` (il modello di palette del port in C++), `src/random.inc`, `src/font.inc`,
`src/poly.inc` e `src/poly17.bin` (il rumore del POKEY) li crea `make palette`.

## Verifiche

```
make check     # FRAMES=... fotogrammi (3000 di default); la tua ROM in rom/River_Raid.rom
make profile   # dove va il tempo di un fotogramma (quello dopo FRAMES)
```

`make check-original` confronta il programma con la cartuccia originale stessa, come è stato
confrontato il port in C++: `rr_oracle` (dal repository del port in C++, compilato dal target:
l'originale su libatari800, che richiede git, un compilatore C, make, autoconf, automake)
registra esecuzioni dell'originale (la sua RAM dopo ogni fotogramma, ciò che la sua logica ha
letto da RANDOM, l'input), e `nxcheck -oracle DIR` esegue il programma con lo stesso input e
gli stessi valori di RANDOM e confronta la sua RAM con quella dell'originale dopo ogni
fotogramma (`Game::diffWithRam`: il generatore del fiume, gli oggetti, lo stato del gioco, le
collisioni, la memoria player-missile, le righe del fiume), ripartendo dallo stato
dell'originale dopo una differenza. Otto esecuzioni, 37 000 fotogrammi: la modalità attract,
una partita del bot fino alla fine e una nuova partenza, una partita a due, il volo, il
rifornimento, NTSC e PAL. Tutto uguale, tranne il fotogramma di una fine partita in due
esecuzioni NTSC: lì l'originale imposta il contatore dei fotogrammi appena prima o appena dopo
il suo VBI, a seconda di quanto dura il lavoro di quel fotogramma (il port in C++, e quindi il
programma, prende il caso più comune).

`make check` lo esegue in PAL e in NTSC (`-pal`, `-ntsc`; `-switch N`: CAPS + 1 prima del
fotogramma N). `tools/nxcheck` esegue il programma senza finestra sul core ZX Spectrum Next di
[Xpeccy+](https://github.com/dotkoval/xpeccy-plus) e accanto il port in C++
(`rr::Game::frame`, con lo stesso contatore POKEY e gli stessi comandi). I comandi vengono da
un giocatore inventato: aspetta nella modalità attract, a volte sceglie un'altra partita, preme
START, vola verso il centro dell'acqua, schiva i nemici davanti, passa sopra i depositi quando
è a corto di carburante, spara, mette in pausa ogni tanto (`-bot N` per altre scelte,
`-stress` a tutta velocità sparando sempre, `-seed N` per un altro contatore POKEY, `-attract`
senza giocatore). Dopo ogni fotogramma confronta lo stato del generatore del fiume
(`RiverGen::diffWithRam`), lo stato del gioco (anche quello della scritta scorrevole), i
record e i caratteri del pannello, la memoria dello schermo (presente solo nella build di
verifica), gli oggetti come disegnati (`Game::drawn`), la memoria del Copper con la sua
lista, la voce dei punti della riva di ogni riga del fiume con `lineBank` del port C++; alla fine
l'immagine dell'ultimo fotogramma pixel per pixel: il fiume, il pannello e la scritta
scorrevole (`Game::drawRiver` e `drawStatusBar` nei colori del Next). Riporta anche cosa è
stato giocato e quanto durano i fotogrammi. 4 x 40 000 fotogrammi con giocatori diversi
(partite 1-8, circa 70 partite e 300 schianti) sono uguali. Una modifica che lo rompe mostra il
primo fotogramma diverso e i campi.

## Come funziona

| Z80 | Pagina da 8K | Cosa |
|---|---|---|
| $0000-$3FFF | 30, 31 | la RAM dell'Atari: lo stato del gioco agli indirizzi dell'originale, la memoria player-missile, la memoria dello schermo (solo nella build di verifica); un dump coincide byte per byte con l'originale e con il port in C++ |
| $4000-$5FFF | 18-27 | una finestra sul Layer 2 |
| $6000-$7FFF | 12 | le righe degli oggetti (`ds_objs`), tabelle, gli attributi degli sprite, la lista del Copper |
| $8000-$9FFF | 4 | il programma: il fotogramma, il generatore del fiume, il ciclo principale del gioco |
| $A000-$BFFF | 5 | l'immagine della cartuccia, ai suoi indirizzi: le tabelle si leggono dove le legge l'originale |
| $C000-$DFFF | 6 | il programma: il gioco, il display, gli sprite, il pannello |
| ($6000-$7FFF) | 7 | solo all'avvio: i set di caratteri, i tile, gli sprite della lancetta e del logo |
| $E000-$FFFF | 1 | buffer, tabelle e lo stack |

Ogni fotogramma (`src/river_raid.asm`):

1. `src/game.asm`, `prepare`: il carro armato e il suo colpo usciti sotto lo schermo, il
   colore del colpo, le vite, i ponti e il punteggio nei caratteri del pannello
   (`Game::prepare`). Il Next non scrive la memoria player-missile: le immagini degli sprite e
   le righe delle collisioni vengono dalle forme della ROM.
2. `src/display_simple.asm`, `src/display_hits.asm`: il lavoro del DLI, senza il DLI
   (`Game::displayGeometry` nel ramo `dli_removed` del port in C++). Ogni oggetto sta
   all'altezza del suo slot, tagliato al fiume; le sue righe vanno in `ds_objs`. Le collisioni
   che il gioco legge sono pura geometria: prima i riquadri (contro i varchi d'acqua di ogni
   riga, l'uno contro l'altro), poi i punti, ovunque si tocchino. L'originale le legge a
   finestre, oggetto per oggetto: lo 0,01–0,25% dei fotogrammi decide diversamente, un contatto
   un fotogramma prima.
3. `src/sprites.asm`: ciò che mostra l'Atari diventa hardware del Next. Ogni oggetto (il player
   3, il cui colore cambia a ogni riga) è uno sprite pronto con le righe nei loro colori,
   posto nella posizione dell'oggetto. Anche gli altri player e missili sono uno sprite
   ciascuno, nella posizione data dal gioco. Tutte le loro immagini sono pattern a 4 bit fatti
   una volta all'avvio dalle forme della ROM (`src/obj_pics.asm`), quindi un fotogramma sceglie
   solo un pattern e scrive gli attributi dello sprite (un pixel dell'Atari sono due pixel
   dello sprite; la larghezza doppia e quadrupla è la scala dello sprite). Il colore della riva
   cambia vicino a un ponte: i punti della riva di ogni nuova riga sono disegnati con la voce del suo colore nella palette del Layer 2.
4. `src/play.asm`, `main_loop`: il ciclo principale (`Game::mainLoop`): i comandi (tastiera e
   joystick, letti come quelli dell'Atari), la pausa, un nemico svegliato ogni 16 fotogrammi
   dal RANDOM del POKEY, il carro armato, gli oggetti, l'aereo (carburante, sterzata,
   velocità, il proiettile, cosa ha colpito), il missile, il colpo del carro, START e SELECT,
   nuove partite, schianti e nuovi aerei, e le righe del fiume secondo la velocità
   (`src/river_gen.asm`, `river_gen.cpp` riga per riga) scritte nel Layer 2. Mentre
   l'originale pulisce la memoria dopo uno schianto o START (13 fotogrammi) girano solo il
   display e il VBI, e il Layer 2 viene pulito due pagine per fotogramma, dal secondo
   fotogramma del reset, e nascosto finché dura (la sua finestra di clip tiene solo le righe
   del pannello): il fiume diventa nero subito, come nel port in C++, senza una striscia che
   attraversa lo schermo.
5. `src/game.asm`, `vbi`: il driver audio (`src/sound.asm`: i registri del POKEY), il contatore
   dei fotogrammi, i colori del fotogramma successivo (l'acqua lampeggia di rosso quando un
   ponte è colpito), il contatore del POKEY avanti di un fotogramma (una matrice,
   `src/random.inc`). Poi `pokey_frame` (`src/sound.asm`) produce i campioni dell'uscita del
   POKEY per il DMA.
6. Sotto la scritta scorrevole (riga raster 208) la nuova immagine diventa attiva: lo
   scorrimento e i colori del Layer 2, gli attributi degli sprite, il pannello e la scritta
   scorrevole, la lista del Copper.

Il pannello e la scritta scorrevole sono la tilemap (40 x 32, tile 8x8 a 4 bit per pixel):
ogni carattere dell'Atari (8x8, un ciclo di colore per pixel) sono due tile, creati all'avvio
dai set di caratteri che il gioco costruisce all'accensione (le lettere e le cifre del font del
sistema operativo, i simboli propri della cartuccia); si scrivono solo i caratteri che
cambiano. Il Copper sposta la tilemap su ogni riga di caratteri; la scritta scorrevole è un
anello nella sua riga della mappa, spostato di lato dallo scorrimento X, e il mezzo carattere
che si vede a entrambi i bordi è tagliato a destra dalla finestra di clip della tilemap e
mostrato lì da uno sprite. Il grigio del pannello è del Layer 2 (i suoi colori resi grigi dal
Copper sulle righe del pannello), quindi la lancetta del carburante (uno sprite) sta sopra di
esso e sotto i caratteri, come sull'Atari. Il logo è fatto di cinque sprite.

Il Layer 2 (320x256, 256 colori) contiene gli indici di colore a 2 bit del playfield; si
mostrano 160 dei 192 cicli di colore di una riga (dal 20°; l'acqua non si avvicina mai di più
ai bordi), due punti ciascuno, quindi le proporzioni sono quelle dell'Atari entro il 2%. I
colori sono i colori PAL del port in C++ (il modello di Altirra) come voci a 8 bit della
palette del Next.
