# River Raid per TS-Conf

[English](README.md) | [Русский](README.ru.md) | [Українська](README.uk.md) | [Deutsch](README.de.md) | [Polski](README.pl.md) | Italiano | [Español](README.es.md) | [中文](README.zh.md) | [日本語](README.ja.md)

Il port per TS-Conf (ZX Evolution / Pentevo): un progetto a sé con la propria compilazione,
separato da quello per lo ZX Spectrum Next ([NEXT.it.md](../NEXT.it.md); entrambi: [la pagina
principale](../README.it.md)). Condivide solo `../deps` (sjasmplus, il port in C++, Xpeccy+:
`make deps` nella cartella principale).

Il gioco funziona come sul Next (la stessa logica, lo stesso display e generatore del fiume,
copiati in `src/`), mostrato alla maniera del TS-Conf. Solo 50 Hz (PAL): il quadro della
scheda.

Come funziona su entrambe le macchine, per tutti: [../docs/HOW_IT_WORKS.it.md](../docs/HOW_IT_WORKS.it.md).

Come è fatto su questa scheda e cosa si è scoperto, con i numeri: [NOTES.it.md](NOTES.it.md).

Il sorgente routine per routine, cosa è cambiato nel codice in comune con il Next e una tabella delle differenze tra le due macchine: [CODE.it.md](CODE.it.md).

- Il fiume: la modalità a 16 colori, 320x240, una riga dell'immagine di 256 byte (160 al suo
  inizio), 512 righe ad anello con scorrimento hardware (GYOFFS); una nuova riga del fiume si
  scrive direttamente nella sua riga (`render.asm`), senza copie.
- Il colore della riva riga per riga: ogni colore che la riva ha avuto ha una palette propria
  (PALSEL 0-7: il suo colore 1 è quel colore, impostato una volta; 2 e 3 il bordo e l'acqua, a
  ogni fotogramma). L'INT di quadro, spostato in giù nel fotogramma da un cambio all'altro
  (`build_events`, `irq`), imposta PALSEL una riga prima del cambio; il registro viene preso a
  fine riga, quindi il cambio è esatto a qualsiasi velocità della CPU.
- Gli oggetti, l'aereo, il suo proiettile, il carro armato e i missili: sprite (`sprites.asm`),
  le loro immagini create all'avvio dalle forme della cartuccia, ogni oggetto largo 16, 32 e 64
  punti (gli sprite non hanno scala).
- Il pannello e la scritta scorrevole (`panel_ts.asm`): le righe 184-239 vengono da
  un'immagine propria, che l'INT di quadro inserisce alla riga 184 (VPAGE, GYOFFS) nella
  modalità a 256 colori con la bitmap sopra tile e sprite (GFXOVR); il livello di tile 0 è il
  grigio sotto i caratteri (lì nasconde gli sprite del fiume); la lancetta e il logo sono
  sprite sopra di esso. I caratteri si disegnano una volta all'avvio e li copia il DMA; la
  scritta scorrevole è un anello di 32 caratteri sui 512 punti dell'immagine, mostrato da
  GXOFFS.
- Il livello di tile 0 è anche il nero sopra il fiume.
- I comandi: Q A O P, Spazio o M per sparare, Invio START, G SELECT, H pausa; Kempston.
- Il suono: tutto su una General Sound (la scheda originale o una NeoGS), se c'è: lo Z80 della
  scheda suona il POKEY come il DAC del Next (`gs/`, `pokey_frame` del Next e i suoi impulsi, i
  bit del contatore a 17 bit li crea la scheda stessa dalla loro ricorrenza), in mono (gli stessi campioni a tutti e quattro i canali: 1 e 2 sinistro, 3 e 4 destro), a 15 820 campioni al secondo (il suo INT,
  37 500 al secondo, ne prende 108 su 256). L'avvio carica il programma nella scheda tramite il
  suo firmware (`gs_load.asm`; avviato di nuovo, trova il programma ancora lì); poi l'apply
  invia i registri del POKEY una volta per fotogramma (`sound_gs.asm`). Senza scheda (o se non
  risponde): solo i toni puri (il motore, i bip, lo sparo, il bonus, il fischio del colpo del
  carro) sui due AY del TurboSound, come li suona il Next (`sound_ay.asm`): i canali 1 e 2 del
  POKEY su A e B del secondo chip, 3 e 4 su B e C del primo. In Xpeccy: attiva la General Sound
  (e il TurboSound NedoPC per gli AY).

A 14 MHz il lavoro di un fotogramma richiede in media ~69 000 cicli nella modalità attract,
~111 000 a tutta velocità sparando sempre dal ponte 80 (-stress), al massimo ~181 000, su
~287 000; a 7 MHz ci sta ancora, di poco (al massimo ~143 000 con -stress, su ~143 400; nessun
fotogramma in ritardo); a 3,5 MHz non ce la fa.

Memoria (finestre da 16K): $0000 la RAM dell'Atari (pagina 1; durante l'avvio la pagina 3 con
il suo lavoro), $4000 le sequenze delle righe e i buffer, il font del sistema operativo da
$7D00 (pagina 5; `render_line` ci mette una pagina dell'immagine mentre disegna), $8000 il
programma e la cartuccia da $A000 (pagina 2), $C000 il programma, i buffer e lo stack (pagina
6); l'immagine del fiume dalla pagina 32, quella del pannello dalla 64, la mappa dei tile nella
pagina 7, i punti dei tile nella pagina 8, quelli degli sprite dalla 24.

    make          build/river_raid.spg: il programma per Wild Commander (SPG 1.0); trova da
                  solo River_Raid.rom sulla scheda SD (sotto)
    make sna      build/river_raid.sna: uno snapshot 128K con dentro la tua ROM (../rom/River_Raid.rom)
    make check    esegue la build di prova sul core TSConf di Xpeccy+ e la confronta con il port
                  in C++ fotogramma per fotogramma: lo stato e l'immagine di ogni fotogramma
                  (FRAMES=... quanti, 3000 di default) e, con una General Sound (quella di
                  Xpeccy+, firmware gs105b.rom), i registri che riceve la scheda
    make palette  riscrive src/palette_ts.inc (i colori del port in C++ ai livelli della scheda)

`build/tools/tscheck` sa anche giocare: `-bot N` (il giocatore inventato di nxcheck), `-stress`,
`-start N`; TSBRIDGE, TSGHOST, NXGAME come in nxcheck; TSSPEED=1 a 7 MHz; TSGS=neo una NeoGS,
TSGS=0 nessuna scheda (si verificano i toni dell'AY); TSWAV=file, TSWAVCPP=file i campioni
della scheda e il POKEY del port in C++ alla stessa frequenza (WAV da ascoltare).

Lo .spg viene compilato anche su GitHub (il workflow `tsconf`: il suo artefatto). Metti
River_Raid.rom (l'immagine della cartuccia, 8192 byte) ovunque sulla scheda SD: il programma la
cerca all'avvio (`load_rom.asm`: la sua prima partizione o l'intera scheda, FAT16 o FAT32,
prima la radice, poi le sue cartelle, fino a 8 livelli; il nome lungo con qualsiasi maiuscola o
quello corto RIVER_~1.ROM). Senza: un bordo rosso. Mentre l'avvio lavora lo schermo è nero
(`screen_black`: tutta la CRAM nera in un colpo, qualunque modalità abbia lasciato Wild
Commander: il suo schermo ZX nella pagina 5 è proprio dove l'avvio mette i suoi buffer).

`build/tools/tscheck -spg build/river_raid.spg 600 out.ppm -sd cartella` esegue lo .spg con una
cartella dell'host come scheda SD (`-img file`: l'immagine di una scheda); `-sna
build/river_raid.sna 600 out.ppm` lo snapshot.
