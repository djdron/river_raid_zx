# Il sorgente assembly del port per ZX Spectrum Next, file per file

[English](CODE.md) | [Русский](CODE.ru.md) | [Українська](CODE.uk.md) | [Deutsch](CODE.de.md) | [Polski](CODE.pl.md) | Italiano | [Español](CODE.es.md) | [中文](CODE.zh.md) | [日本語](CODE.ja.md)

Per i programmatori Z80 che vogliono leggere il codice o renderlo più veloce. Per ogni file: cosa
contiene, cosa fa ogni routine, chi la chiama e quando, come funziona e quanto costa. Il perché
delle scelte è in [NOTES.it.md](NOTES.it.md) e [HANDOFF.it.md](../HANDOFF.it.md); il quadro a
parole semplici in [HOW_IT_WORKS.it.md](HOW_IT_WORKS.it.md).

Questo è il codice del Next (`src/`). Il port per TS-Conf ([tsconf/CODE.it.md](../tsconf/CODE.it.md))
usa una copia della sua parte di gioco: `play.asm`, `game.asm`, `river_gen.asm`, `spans.asm`, i
file `display*.asm`, `panel.asm` e `sound_driver` sono descritti qui per entrambi (le poche
modifiche di TS-Conf sono elencate là); il resto qui, l'immagine, gli sprite, il Copper, il
pannello, il suono sul DAC, l'avvio, è proprio del Next. Una tabella delle differenze tra le due
macchine è all'inizio di tsconf/CODE.it.md. L'hardware proprio del Next come lo usa questo
codice: istruzioni Z80N (`nextreg`, `mul`, `bsla`), slot da 8K, Layer 2 per colonne, il Copper, la
tilemap, sprite con scala, zxnDMA e DAC, tre AY, 50 e 60 Hz.

## I numeri

I tempi sono cicli del core del Next a 28 MHz per fotogramma, in media, dall'istogramma di
nxcheck (`NXHISTALL=file`, poi `python3 tools/prof.py build/test.sym file 60`, diviso per i
fotogrammi), sulla build di verifica senza memoria dello schermo, come la ha il gioco
(`-DNOSCREEN`, `NXNOSCREEN=1`). Due esecuzioni:

- **A**: PAL, bot 1, 3 000 fotogrammi dall'inizio (il solito inizio di partita): ~102 000 a fotogramma in media, al massimo ~158 000;
- **B**: `-stress` dal ponte 80, PAL, 6 000 fotogrammi (`NXBRIDGE=80 NXGHOST=1 NXGAME=1`: tutti gli slot occupati, tutta velocità, sempre sparando): ~159 000 in media, al massimo ~198 000 (NTSC ~160 000 / ~202 000; a 14 MHz NTSC ~131 000 / ~165 000 su ~240 000).

Un fotogramma ha ~567 000 cicli in PAL e ~481 000 in NTSC (la metà a 14 MHz). `apply` (e quindi
`panel_frame`) gira dopo il lavoro misurato (sotto la scritta scorrevole) e non è in questi
numeri: ~7 400 a fotogramma. Il tempo di una routine sono solo le sue istruzioni: le routine
che chiama sono contate sotto il loro nome.

Per parti (A / B):

| parte | A | B |
|---|---|---|
| il display: posizionamento degli oggetti e collisioni (`display_simple`, `display_objs`, `display_hits`, `sp_*`) | 40 400 | 54 300 |
| suono (`pokey_frame`, `snd_*`, `pk_*`, `ay_*`, `sound_driver`) | 26 900 | 39 300 |
| nuove righe del fiume (`river_gen`, `render_line`, `rl_fill`, `span_line`, `push_line`) | 19 500 | 45 400 |
| sprite e lista del Copper (`build_sprites`, `ob_*`, `pl_*`, `build_copper`) | 9 900 | 15 000 |
| la logica del gioco e il resto (`prepare`, `main_loop`, `move_objects`, `random_step`, la stampa del pannello, …) | 9 400 | 10 500 |

Le routine più costose (A / B):

| routine | A | B | file |
|---|---|---|---|
| `display` (codice proprio) | 10 900 | 12 600 | display_simple |
| `pk_noise` | 4 600 | 12 900 | sound_pulses |
| `dh_pf` | 10 200 | 11 200 | display_hits |
| `span_line` | 4 200 | 10 300 | spans |
| `ds_edge_test` | 3 200 | 10 200 | display_simple |
| `render_line` | 4 100 | 10 000 | render |
| `snd_sum` | 8 600 | 8 600 | sound |
| `rl_fill` | 3 800 | 8 300 | spans |
| `ds_obj` | 5 300 | 6 100 | display_objs |
| `dh_obj` | 4 900 | 6 100 | display_hits |
| `ob_list` | 4 100 | 5 600 | sprites |
| `ob_attr` | 2 900 | 5 200 | sprites |
| `move_objects` | 2 000 | 3 900 | game |
| `dl_fill` | 1 600 | 3 700 | river_gen |
| `ay_out` | 3 400 | 3 400 | sound_ay_run |
| `snd_fill` | 2 800 | 2 800 | sound |
| `ay_frame` | 2 200 | 2 800 | sound_ay_run |
| `pk_channel` | 1 200 | 2 700 | sound_pulses |
| `pokey_frame` (codice proprio) | 2 500 | 2 700 | sound |
| `draw_line` | 900 | 2 300 | river_gen |
| `pk_g4` | 0 | 1 400 (~9 000 in un fotogramma in cui suona il missile) | sound_pulses |
| `dh_lists` | 1 300 | 1 300 | display_hits |
| `hit_setup` | 500 | 700 | display_hits |

Il fotogramma più pesante di B (~198 000): il suono fino a ~60 000 (il rumore e il missile sul
DAC, ~180 impulsi), il posizionamento e le verifiche del bordo (`display`, `ds_obj`,
`ds_edge_test`) ~30 000, le collisioni (`dh_pf`, `dh_bits`, `dh_obj`, `hit_*`) ~25 000, le nuove
righe del fiume ~25 000.

(`prof.py` prende il nome di una routine dall'etichetta globale più vicina sotto l'indirizzo,
quindi un'etichetta di dati subito prima del codice può prenderne il tempo; i simboli della
pagina 12 a $6000-$7FFF stanno per `panel_init` nella pagina 7 agli stessi indirizzi, che gira
una volta all'avvio.)

## La memoria mentre il codice gira

Slot da 8K ($0000, $2000, … $E000) e le pagine al loro interno:

| slot | indirizzo | normalmente | rimappato da |
|---|---|---|---|
| 0–1 | $0000–$3FFF | 30–31: la RAM dell'Atari agli indirizzi dell'originale | `pokey_frame`: 14–15, il contatore a 17 bit di POKEY (`poly17.bin`), mentre fa i campioni |
| 2 | $4000–$5FFF | varia: nessuna pagina fissa | `render_line`: 18–27 (Layer 2, una pagina ogni 32 colonne); `display`, `span_line`, `spans_clear`: 28 (`SPAN_PAGE`, le sequenze delle righe); `panel_frame`: 11 (la mappa della tilemap); `panel_init`: 10, 11 |
| 3 | $6000–$7FFF | 12: buffer (`copper_list`, `ds_objs`, `sprite_list`, `ov_exp2`/`ov_exp4` (i punti di un byte allargati, `dh_obj`), i varchi del bordo `eg_*` (`ds_edge_test`), l'anello del DAC a $7C00) | solo all'avvio: 7 (`panel_init`, `sound_init7`, `load_rom`). **Mai mentre suona il suono**: il DMA legge l'anello attraverso questo slot |
| 4 | $8000–$9FFF | 4: codice | — |
| 5 | $A000–$BFFF | 5: la cartuccia, letta da River_Raid.rom | — |
| 6 | $C000–$DFFF | 6: codice | — |
| 7 | $E000–$FFFF | 1: variabili, tabelle (tra cui i varchi della riva `bg_*`), lo stack (da $0000 in giù fin sopra $FF00) | — |

La pagina 4 finisce a ~$9E2C (su $A000), la 6 a ~$DD53 (su $E000), la 7 a ~$6913 (la build lo
stampa): l'orario del DLI eliminato ha lasciato un po' di spazio. Spostare codice tra le pagine
è il modo in cui si è trovato spazio prima (`display_objs.asm` stava nel varco prima
dell'allineamento della palette nella pagina 4, ora alla sua fine).

Gli interrupt sono sempre spenti (`di` all'avvio): il fotogramma è scandito interrogando la riga
raster (`wait_frame`), il suono dal DMA, i colori per riga dal Copper.

## Il fotogramma

`main_frame` (river_raid.asm), a ogni fotogramma:

1. Un'istantanea di ciò che mostra l'immagine di questo fotogramma (`scroll`, i colori del bordo e dell'acqua, il giocatore), `read_input`, CAPS + 1 (`restart` nell'altro standard).
2. Normalmente: `prepare` → `display` → `build_sprites` → `main_loop` → `vbi`. Durante un reset (`busy`, i fotogrammi in cui l'originale pulisce la memoria: 13 NTSC, 8 PAL): `display` → `build_sprites` → `clear_layer2_page` → (`finish_reset` nell'ultimo) → `vbi`.
3. `pokey_frame`: i campioni del fotogramma nell'anello del DAC e i toni dell'AY.
4. `wait_frame`: interroga la riga video attiva (NR $1E/$1F) fino a `wait_line` (208 NTSC, 220 PAL), sotto la scritta scorrevole, dove sullo schermo non cambia nulla.
5. `apply`: tutto ciò che è stato costruito diventa attivo insieme (scorrimento e colori del Layer 2, gli attributi degli sprite, i tile del pannello, la lista del Copper).

Con T acceso (`tm_show`), ognuna di queste parti imposta prima il colore del bordo (`TM_COLOUR`: chiama `tm_colour` solo con T acceso; spento costa ~30 cicli per parte): arancione `apply`, grigio `prepare` (e `clear_layer2_page` durante un reset), rosso `display`, giallo `build_sprites`, blu `main_loop`, magenta `push_line` (una nuova riga del fiume, dentro `main_loop`), bianco `vbi`, ciano `pokey_frame`, nero il tempo che resta. `push_line` imposta magenta e poi di nuovo blu.

L'ordine conta: `display` usa lo stato che ha lasciato il `main_loop` del fotogramma precedente
(come il DLI dell'Atari mostra lo stato del fotogramma precedente), e `build_sprites` usa ciò che
ha lasciato `display`.

---

## river_raid.asm: il fotogramma, l'avvio, la memoria

Il file principale: disposizione della memoria, `include`, assemblaggio delle pagine
(`mmu`/`org`), variabili della pagina 1 e buffer della pagina 12, agganci per le build di prova.

| routine | chiamata | cosa e come |
|---|---|---|
| `start` | al caricamento | `load_rom` (non nelle build di prova), RANDOM inizializzato da R, 28 MHz, mappa le pagine, `init_tables`, `init_video`, `panel_init` (pagina 7 mappata), poi `restart`. |
| `restart` | `start`; CAPS + 1 | La macchina "accesa" nello standard di `tv_pal`: `tv_setup`, Layer 2 pulito (tutte le 10 pagine insieme), `sound_init`, `start_attract`, cade in `main_frame`. |
| `main_frame` | ogni fotogramma | Vedi *Il fotogramma*. ~340 cicli propri. |
| `wait_frame` | `main_frame` | Attende attivamente su NR $1F rispetto a `wait_line`. Il suo tempo è inattività, non lavoro. |
| `init_tables` | `start` | Una volta: le tabelle: `ring_lo`/`ring_hi` (le 160 righe della memoria dello schermo in ordine), `span_class` (il colore di un byte se i suoi 4 pixel sono uguali), `span_init` (le maschere), una lista del Copper vuota. |
| `tv_setup` | `restart` | Le impostazioni dello standard: NR $05 50/60 Hz, `init_line_tables`, `wait_line`, la mappa casuale, la parte del pannello del Copper (`copper_panel_ntsc`/`_pal` copiate, il grigio inserito, `COPPER_GREY`), il primo scorrimento Y della tilemap, finestre di clip (Layer 2 fino all'ultima riga grigia del pannello, sprite, tilemap). |
| `init_video` | `start` | Bordo nero, niente ULA, trasparenza globale $E3, Layer 2 320×256×8 nel banco 9, ordine dei livelli (tilemap sopra gli sprite sopra il Layer 2), le palette: le 4 voci del Layer 2, le 128–255 degli sprite = i colori dell'Atari, NR $15 con il clip degli sprite in modalità sopra il bordo. |
| `test_ghost` | build di prova, dopo `display` quando `test_ghost_on` | NXGHOST di nxcheck: le collisioni dell'aereo e il carburante impostati in modo che non possa schiantarsi. |

Inoltre: `span_rec` (macro: HL = il record da 32 byte della riga del fiume A in SPAN_PAGE), la
`palette` (colore Atari → colore Next, 256 byte) e `random_columns`, le variabili `TEST`
(`start_bridges_hi`, `snd_passed`, `test_ghost_on`).

## play.asm: il ciclo principale (A197–A6EA)

La logica del gioco che l'originale esegue nel suo ciclo principale, come la ha il port in C++.
Lo stato sta agli indirizzi della RAM dell'originale.

| routine | chiamata | cosa e come | A / B |
|---|---|---|---|
| `main_loop` | `main_frame` (non durante un reset) | A197–A6EA: legge RANDOM (`random_read`), l'aereo (`fly_plane`) o l'esplosione/ritorno (`respawn_or_game_over`), `drive_tank`, `move_objects`, poi `main_loop_end`. Torna prima quando inizia un reset. | 620 / 620 |
| `main_loop_end` | `main_loop`, `finish_reset` | A5B7–A6EA: il missile e il colpo del carro (`move_missile`, `move_shell`), `scroll_river`, START/SELECT. | 180 / 170 |
| `scroll_river` | `main_loop_end` | A6FD: la velocità aggiunta due volte a fotogramma a una frazione; ogni riporto è un `push_line` (una nuova riga del fiume: la parte costosa, vedi river_gen). | 140 / 160 |
| `fly_plane` | `main_loop` | A3E9–A5B4: carburante, sterzata (`steer`), velocità (`change_speed`), sparo, il proiettile (`move_bullet`), gli esiti delle collisioni: `explode` (un oggetto colpito o speronato: punti), `crash`. | 290 / 480 |
| `steer`, `change_speed` | `fly_plane` | La X dell'aereo con una frazione sotto il pixel; la velocità $40–$FE. | |
| `explode` | `fly_plane` | A4E0–A589: lo slot diventa un'esplosione, i punti (BCD), il bonus di un ponte. | |
| `crash` | `fly_plane`, `explode` | sub $B1C0: l'aereo si schianta, con un suono d'evento; `section_checkpoint`. | |
| `draw_bullet`, `move_bullet` | `fly_plane`, `crash` | Le 8 righe del proiettile nella memoria del missile 2 (solo `-DBEAM`; altrimenti `draw_bullet` torna subito). | 380 / 520 |
| `new_game`, `reset` | START, fine partita, ritorno | sub $B0F1: il fiume e gli oggetti azzerati (`restore_checkpoint`), `clear_screen_memory` (solo con la memoria dello schermo: build di verifica e del raggio), `busy` = 13 o 8 fotogrammi. | |
| `clear_layer2_page` | `main_frame` durante `busy`, `restart` | Due delle 10 pagine del Layer 2 pulite a fotogramma (`l2_clear` conta); nessuna nel primo fotogramma del reset (`l2_wait`: la sua immagine è ancora mostrata), e intanto `apply` nasconde le righe del fiume (`l2_hidden`). ~1 100 a fotogramma in media su A, ma una pagina sono 8 KB di scritture nei fotogrammi in cui gira. | 1 100 / 570 |
| `finish_reset`, `finish_respawn`, `respawn_or_game_over` | | Dopo il reset: il fiume continua dal checkpoint, il giocatore successivo o la fine partita. | |
| `swap_players`, `update_high_score`, `set_up_game`, `select_game` | | Due giocatori, record con i suoi byte di controllo, il numero di partita. | |
| `show_lives`, `show_score`, `show_bridges`, … | il ciclo, il VBI | I caratteri del pannello nella RAM dell'Atari ($1000). | 620 / 720 |
| `print_bcd` | le `show_*` | B086: byte BCD come cifre, zeri iniziali vuoti. | 1 200 / 1 400 |
| `read_input` | `main_frame` (non nelle build di prova) | La tastiera (Q A O P, Spazio/M, Invio, G, H, CAPS + 1/2), Kempston 1 e 2 e il pad Mega Drive nei byte di joystick, grilletto e console dell'Atari. T (alla pressione) commuta `tm_show`, spento: il colore di fallback nero. | — |

## game.asm: parti del gioco per fotogramma e il VBI

| routine | chiamata | cosa e come | A / B |
|---|---|---|---|
| `random_read` | `main_loop` (A205) | Il RANDOM di POKEY: il contatore a 17 bit com'è al punto di lettura. Le verifiche contano queste letture. | |
| `random_step` | `vbi` | Il contatore avanti di un fotogramma: una mappa lineare fissa (17 colonne in `random.inc`, NTSC o PAL), 4 bit alla volta: per ognuno dei 4 nibble dei bit 0–15 una voce da 3 byte di `rnd_tab` (pagina 1, 256 byte allineati: 64 k + 4 v) in XOR, la colonna del bit 16 (`rnd_col16`) se impostato. Era bit per bit, ~2 300. | 560 / 560 |
| `rnd_tables` | fine di `tv_setup` | `rnd_tab` e `rnd_col16` dalle colonne dello standard (`rnd_cols`): ogni voce lo XOR delle colonne del suo valore. | |
| `bank_colour` | `vbi`, `start_attract` | sub $AFD0: la tonalità della riva (cambia mentre in alto entra un ponte). | 200 / 200 |
| `start_attract` | `restart` | Lo stato della modalità attract alla sua prima riga (partita 1, niente aereo). | |
| `draw_logo_and_needle` | `reset`, `start_attract` | L'arcobaleno e la lancetta del carburante nella memoria player-missile, come li lascia sub $B0F1 (solo `-DBEAM`; sul Next sono sprite). | |
| `push_line` | `scroll_river`, `start_attract` | Una nuova riga del fiume: `next_line` (river_gen) registra i suoi pezzi in `dl_seg`, poi a `line_done` `render_line` (Layer 2) e `span_line` (le sequenze per le collisioni) disegnano da quelli; con la memoria dello schermo (build di verifica e del raggio, `SCREEN_MEMORY`) i byte della riga vanno anche attraverso `line_buf` nella memoria dello schermo (48 LDI, l'indirizzo della riga in alto una riga più su). | |
| `prepare` | `main_frame` | AE99–AF38 all'inizio del fotogramma: il carro e il colpo usciti sotto lo schermo, il colore del colpo, vite, ponti e punteggio del pannello. Le forme nella memoria player-missile ($0B00–$0FFF) solo nella build del modello a cicli (`-DBEAM`): gli sprite e le collisioni del Next le prendono dalla ROM. | ~2 000 (3 000 con le copie) |
| `drive_tank` | `main_loop` | A21B: il carro sulla strada avanza, spara sul bordo del fiume. | |
| `move_objects` | `main_loop` | A26C–A2ED: gli oggetti negli slot si animano e si muovono (navi ed elicotteri girano al bordo: il flag del bordo dello slot dal display). | 2 000 / 3 700 |
| `move_missile`, `move_shell` | `main_loop_end` | Il missile dell'elicottero, il colpo del carro. | |
| `vbi` | `main_frame` | B2A5–B43E: `sound_driver`, il contatore dei fotogrammi, i colori del fotogramma successivo (`bank_colour`), `scroller_step`, `random_step`. In PAL a fine partita vede alcuni valori di prima di sub $B21A (`vbi_before`). | 420 / 430 |
| `scroller_step` | `vbi`, `start_attract` | B44B: la scritta scorrevole di un ciclo di colore a fotogramma in modalità attract, ferma in gioco. | |

## river_gen.asm: il generatore del fiume (A711–AE93)

Una riga del fiume alla volta, come la genera l'originale: il LFSR a 24 bit, sezioni e blocchi,
larghezze di riva e isola, decorazioni (case, montagne), strade e ponti, gli oggetti piazzati ogni
16 righe. Il suo risultato sono i pezzi della riga in `dl_seg` (4 byte ciascuno: il byte da cui
inizia, il suo tipo, i suoi dati: 0 un bordo, l'offset del suo pezzo nella tabella a $B800; 1 byte
di un valore, il valore; 2 una riga di decorazione, l'indirizzo della sua bitmap; terminati dal
byte 48) e gli slot. Nel gioco nessun buffer di riga: `line_buf` (48 byte, 192 cicli di colore da
2 bit; non pulito prima, i pezzi vengono uno dopo l'altro dal byte 0 al 48) si scrive solo con la
memoria dello schermo.

| routine | chiamata | cosa e come | A / B |
|---|---|---|---|
| `next_line` | `push_line` | Una riga: `count_lines`, `move_bank`, `change_island`, `scroll_objects`, `place_object`, poi `draw_line`. | 210 / 290 |
| `count_lines` | `next_line` | A711: conta le righe; all'inizio di blocchi e sezioni prepara ciò che viene (`choose_section_width`, `start_decoration`, checkpoint). | 160 / 210 |
| `move_bank` (+ `bank_hit_setup`, `bank_hits_left/right`) | `next_line` | A826: la posizione della riva per questa riga, senza finire contro l'oggetto che sta ancora entrando. | 350 / 570 |
| `change_island`, `choose_section_width` | | L'isola verso la larghezza voluta. | |
| `draw_line` | `next_line` | I pezzi della riga: riempimento della riva (`dl_fill`, `dl_fill_bank`), bordi (`dl_edge`, `dl_bank_edge`: pezzi da 2 byte da $B800), la riga della decorazione (`dl_deco_row`, l'indirizzo della sua bitmap avanzato), acqua; ciascuno in `dl_seg` con i suoi dati, DRAW_POS avanzato; i loro byte in `line_buf` solo con la memoria dello schermo. | 900 / 2 300 |
| `dl_fill` | `draw_line` | B byte di C da DRAW_POS: un pezzo di tipo 1 (i byte stessi solo con la memoria dello schermo). | 500 / 1 300 |
| `scroll_objects` | `next_line` | AB76: tutto una riga più giù; quando lo slot più basso lascia lo schermo, gli slot scorrono. | 560 / 820 |
| `place_object`, `choose_enemy`, `position_object`, `place_tank` | `next_line` | Ogni 16 righe un nuovo oggetto nel prossimo slot libero; all'inizio di un blocco forse un carro su una strada. | |
| `step_lfsr` | molti | sub $B183: il LFSR a 24 bit. | 140 / 200 |
| `section_checkpoint`, `restore_checkpoint`, `start_game` | | Il punto di ripartenza; una nuova partita dal ponte 1 (o `start_bridges_hi` nelle build di prova). | |

Il costo del generatore è per ogni nuova riga: la velocità si aggiunge due volte a fotogramma a
una frazione e ogni riporto è una riga, quindi 0–2 righe a fotogramma, di più quanto più veloce
vola l'aereo.

## render.asm: una riga nel Layer 2

| routine | chiamata | cosa e come | A / B |
|---|---|---|---|
| `render_line` | `line_done` | Prima `line_bank`. I clock di colore 20–179 (`WINDOW_FIRST`) della riga nella riga A del Layer 2, dai pezzi di `dl_seg` (nessun buffer di riga). Il Layer 2 è memorizzato per colonne (byte x·256 + y, 32 colonne per pagina da 8K), quindi la riga si scrive giù per le colonne (`inc h` = la colonna dopo), 10 pagine a turno nello slot 2 (`rl_next`). Un pezzo di un valore: il suo colore da `rl_k1`, poi `rl_fill` (8 colonne per byte, pagina per pagina; `rl_fill`, `rl_next` nella pagina 6, spans.asm); i byte di un bordo (dalla tabella della ROM) e la riga di una decorazione (dalla sua bitmap nella ROM): per byte il set di tabelle dei punti della riga (`rl_set`: quello di un verde) dà 2 punti per clock, ciascuno scritto due volte; su una riga di strada (`.table_k`) quello del primo verde, i punti di riva nella voce della strada (`rl_sub`); i byte prima della finestra saltati nei dati. 320 scritture per riga. Nella pagina 6 (spostata dalla pagina 4 per spazio). | 4 100 + 3 800 / 10 000 + 8 300 |
| `line_bank` | `render_line` | Come quello di TS-Conf (tsconf/CODE.md): `lineBankColour` del port in C++, calcolato solo quando può cambiare, a un ponte (`road_row`, tenuto da `place_object`, `restore_checkpoint` e `scroll_objects`); un nuovo colore imposta `rl_k1` + $55, `rl_sub`, `rl_set` (`pix_set0` o `pix_set1`) e il salto per i pezzi di tipo 0/2 (`render_line.kind`: `.table` o `.table_k`). Voci 1, poi 4–10. In bank_colours.asm (pagina 6). | 50 (dopo un ponte: 30) |
| `bank_init`, `pix_sets` | `start` (pagina 7, dopo `panel_init`) | I colori della riva, ciascuno una volta: $D2, $D6, quelli delle 20 righe di strada (`bank_cols`, `bank_n`, al massimo 8), le voci del Layer 2: 1, poi 4–10 (`bank_set`); le tabelle dei punti dei due verdi, 4 pagine ciascuna (`pix_set0` a $F700 nella pagina 1, `pix_set1` a $6C00 nella pagina 12, scritta attraverso lo slot 2): il byte b della pagina k è il punto k di b come lo tiene il Layer 2 (0, 2, 3 se stessi, 1 la voce del verde); `rl_k1` ($6B00): il valore di un pezzo 0, $AA, $FF come suo colore ($55 lo mette `line_bank`). | una volta |
| `bank_set` | `bank_init`, `apply` | Le voci della riva del Layer 2: i loro colori (E = 1) o nero (E = 0, i colori spenti: `apply`, quando cambia `show_bank`, `ap_bank_on`). | |

## spans.asm: le sequenze delle righe per le collisioni con il playfield

Ogni riga del fiume ha un record da 32 byte in SPAN_PAGE (pagina 28 a $4000), in un anello di 256:
i cicli di colore dove iniziano e finiscono le sue sequenze di riva (colore 1) e di bordo (colore
2). Le collisioni verificano le righe degli sprite contro queste sequenze invece che contro i
pixel. Con lo stesso indice dell'anello, i suoi varchi: `eg_e1`–`eg_s2` e `eg_e3`–`eg_s4`
(pagina 12) l'acqua tra le sequenze del bordo (con 2 sequenze quella tra loro, con 4 tra la 1ª e
la 2ª e tra la 3ª e la 4ª, con nessuna tutta la riga, altrimenti nessuna: $FF); `bg_e1`–`bg_s2`,
`bg_e3`–`bg_s4` (pagina 1) i due varchi più larghi tra le sequenze della riva (dal ciclo 32 prima
della prima a 224 dopo l'ultima). Un riquadro dentro un varco non tocca nulla sulla riga.

| routine | chiamata | cosa e come | A / B |
|---|---|---|---|
| `span_line` | `line_done` | Il record della nuova riga dai pezzi di `dl_seg`, senza guardare alcun pixel: un pezzo di un valore è tutto un colore (`span_class`), una riga di decorazione quello della riva (come i bankRuns del port in C++, la riga senza decorazione), le sequenze di un bordo pronte da `edge_runs` secondo il suo pezzo (il ciclo nel pezzo e il suo colore, tagliato al byte 48); ogni cambio di colore chiude una sequenza (`.change`). Poi i suoi varchi (`.gaps` dalle sequenze del bordo, `.bgaps` da quelle della riva: i due più larghi tenuti, `.gap`). | 4 200 / 10 300 |
| `edge_runs_init` | `init_tables` (avvio) | Ogni pezzo di bordo che il generatore usa (offset 0–30 della tabella a $B800) in `edge_runs` (pagina 12, 16 byte per pezzo): i pixel 0–7 dei suoi due byte, una coppia (il pixel, il suo colore; 3, l'acqua, come 0) al primo e a ogni cambio, $FF dopo. | una volta |
| `spans_clear` | `start_attract` | Nessuna sequenza su nessuna riga (memoria dello schermo pulita). I varchi restano: senza sequenze non si può toccare nulla, qualunque cosa dicano, e ogni nuova riga li rifà. | |
| `span_init` | `init_tables` | Le maschere: i bit i..j di un byte (`span_masks`). | |

## display_simple.asm: gli oggetti piazzati, le loro collisioni

Come il `displayGeometry` del port in C++ (ramo `dli_removed`): niente DLI. Ogni oggetto sta alla
y del suo slot, tagliato sul fiume, e le sue collisioni sono semplice geometria. Cosa lascia:
`ds_objs` (le righe di ogni oggetto per gli sprite: 8 byte, prima riga, numero di righe,
puntatori di forma e colore, x, dimensione), i risultati delle collisioni in HIT e i flag del bordo degli slot.

`display` (~11 800 / 13 500 propri):

1. Mappa SPAN_PAGE, `dh_lists` (i descrittori degli altri sprite), i registri puliti e impostati come B527–B55C, `bm_hitclr`, `dh_sprites` (HIT = $FF, poi gli altri sprite con la riva e tra loro).
2. `.slot`, per ogni slot da FIRST_SLOT: IY sul tipo d'aspetto dello slot (pagina 5: tipo, X, dimensione a IY + 11, + 22, + 33, letti lì, nessuna copia), Y e i flag tenuti (`ds_y`, `ds_flags`), `ds_edge_kind`; l'inizio = max(y, $5D); la prima riga = y + height[type] − inizio (≥ $80: sparita in alto, il successivo); X = inizio + 3 (oltre 255: la fine); righe = min(riga + 1, 256 − X); `ds_rowp` il byte della prima riga; `ds_obj` (le righe in `ds_objs`); un ponte: `.road` (`-DBEAM`) (il colore della strada dalla riga di scansione dopo ciascuna sua riga, X − 69 + 1; il colore della riva della sezione dopo l'ultima a meno che X non si sia riavvolto, tramite `ds_bank`; il colore di una riga solo quando differisce dalla riga sopra). Le prime righe di forma e colori si calcolano sul posto (DE, BC per `ds_obj`). Le tabelle della ROM (altezza, forma, colori) si leggono con somme a 8 bit (`ROM_SHAPES` e `ROM_COLOURS` iniziano a inizio pagina).
3. Il bordo (P3PF) per i tipi 8–$0D (`ds_edge_kind`: elicotteri, mongolfiere, navi ci girano): `ds_edge_test`, poi `ds_set_flags`.
4. Contro il proiettile, il colpo del carro (non un ponte) e l'aereo: `dh_obj`; un contatto memorizza lo slot (HIT_BULLET_OBJECT, HIT_SHELL_OBJECT, HIT_PLANE_OBJECT), quindi resta l'ultimo scendendo lungo lo schermo.
5. `.end`: `test_ghost` (build di prova); `ds_bank_fill` solo con `-DBEAM`.

| routine | chiamata | cosa e come | A / B |
|---|---|---|---|
| `ds_edge_test` | `display`, per oggetto dei tipi 8–$0D | A = $02 se l'estensione di una riga (dal suo primo punto all'ultimo) incontra una sequenza di bordo sulla sua riga (l'`edgeTouches` del port in C++). Il riquadro dell'oggetto (da X a X + 8, 16 o 32 cicli; niente oltre il ciclo 255) per riga contro i varchi d'acqua della riga (`eg_*`, l'indice d'anello della riga avanza di uno); dentro uno, la riga successiva. Altrimenti il primo e l'ultimo punto della riga (`edge_lo`/`edge_hi` scalati dalla dimensione: `.s1`/`.s2`, più X: `.ex1`/`.ex2`) contro le sequenze di bordo della riga (il suo record): una sequenza in mezzo è un contatto, niente punto per punto. | 3 200 / 10 200 |
| `ds_set_flags` | `display` | Il bit del bordo dell'oggetto nei flag del suo slot (bit 0). | 1 100 / 1 300 |
| `ds_bank` | `display` (`-DBEAM`) | Un cambio del colore della riva dalla riga di scansione A (la strada di un ponte e ritorno): in `ds_bank_ev`. | |
| `ds_bank_fill` | fine di `display`, solo `-DBEAM` | `scan_bank` per ogni riga del fiume da `ds_bank_ev` (lo legge solo il display del raggio; nel gioco il colore della riva va per riga: `line_bank`). | |
| `ds_edge_only` | `display` | Il bit del bordo solo per i tipi che lo leggono. | |

## display_objs.asm

| routine | chiamata | cosa e come | A / B |
|---|---|---|---|
| `ds_obj` | `display`, per oggetto con righe | Le righe dell'oggetto per gli sprite: prima riga di scansione, numero di righe, gli indirizzi di forma e colore della prima riga (DE, IY), x, dimensione: 8 byte in `ds_objs` (`DS_OBJS` = al massimo 16). Un oggetto la cui prima riga è alla riga 28 o sopra (sopra la cima del fiume) viene esteso a tutta la sua forma (k = inizio − y righe in più), così lo sprite si disegna intero e la finestra di clip degli sprite lo taglia. Alla fine della pagina 4. | 5 300 / 6 100 |

## display_hits.asm: le collisioni come geometria

Nessun registro di collisione e nessuna lettura: una collisione conta se avviene in qualunque
punto delle righe degli sprite. Cinque altri sprite sono descritti da descrittori da 10 byte in
`dh_desc` (ciò che resta uguale copiato da `dh_template` una volta all'avvio, `dh_init`; il resto lo compila `dh_lists` a ogni fotogramma): la base delle righe (bassa), maschera (già girata ai posti dei punti), la fine delle righe (la riga dopo l'ultima; oltre 255, 255), x, dimensione, numero di sprite, prima riga, righe, larghezza in cicli, la
base (alta) (`DH_SIZE` = 10; `DH_SHELL`, `DH_TANK`, `DH_PLANE`, `DH_MISSILE`, `DH_BULLET`). Una
riga sulla riga L è il byte a base + L: la forma del fotogramma dalla ROM (base = il suo indirizzo
− la prima riga, `dh_shape`, `dh_base`); le righe del missile e del proiettile sono `dh_ones`
(tutti a uno) sotto le loro maschere, girate ai posti dei punti già nel modello ($03 di 6: $C0; il bit 5 del proiettile di 2: $80), così nessuna riga viene girata. Dopo un reset (`pm_empty`, fino al
prossimo `prepare`) nessuna riga.

| routine | chiamata | cosa e come | A / B |
|---|---|---|---|
| `dh_lists` | inizio di `display` | Righe, posizioni e basi dei descrittori; poi la fine di ciascuno (campo 2). | 1 300 / 1 300 |
| `dh_sprites` | `display` | HIT = $FF, poi HIT 0 dove: il carro incontra il bordo (P1PF), l'aereo la riva (P2PF), il missile e il proiettile la riva o il bordo (M0PF, M2PF): `dh_pf`; l'aereo e il colpo del carro (P2PL bit 0), il missile e l'aereo (M0PL): `dh_pair`. | |
| `dh_pf` | `dh_sprites` | NZ: le righe dello sprite IX incontrano il playfield (DE: `sp_edge`, `sp_bank`, `sp_under`). Per riga del fiume: prima il byte della riga sotto la maschera (nessun punto: la riga successiva), poi il suo riquadro (da X a X + i suoi cicli) nei varchi della riga (A: bit 0 gli `eg_*` del bordo, bit 1 i `bg_*` della riva); dentro, nulla; altrimenti le estremità della riga contro le sequenze (la funzione `sp_*`). Si ferma al primo contatto. | 10 200 / 11 200 |
| `sp_edge`, `sp_bank`, `sp_under` | `dh_pf` | La riga di uno sprite contro le sequenze della riga di bordo (marrone), riva (verde) o entrambi, come lo `spanTouches` del port in C++: il suo primo e ultimo punto (`sp_ends`: `edge_lo`, `edge_hi`, la larghezza della dimensione, più X) contro le sequenze (`sp_runs`), una sequenza in mezzo è un contatto; il record della riga tramite `sp_rec`. | |
| `dh_pair` | `dh_sprites` | NZ: le righe di due sprite si incontrano: `hit_setup` sui loro cicli, poi per ogni riga che hanno entrambi i bit di ciascuno (`dh_bits`, `hit_wide` secondo la sua dimensione) in `hit_a`, `hit_b`, e `hit_line`. | |
| `dh_bits`, `dh_end` | `dh_pf`, `dh_pair`, `dh_obj` | I bit dello sprite IX sulla riga A: il byte della riga sotto la maschera, già in alto (Z: nessuno); la riga dopo la sua ultima (`dh_lists` la mette nel campo 2 una volta per fotogramma). | 400 / 500 |
| `dh_obj` | `display`, per oggetto (proiettile, colpo, aereo) | NZ: lo sprite IX tocca le righe dell'oggetto corrente (`ds_rowp`, dalla riga di X = `ds_counter`, `ds_rows` di esse, a X e dimensione dello slot: IY + 22, + 33). Prima le righe che hanno entrambi (`ds_l1`, `ds_l2` da `display`, la fine dello sprite: la maggior parte degli oggetti non ne ha in comune), poi `hit_setup` sui cicli dell'oggetto (8, 16 o 32) e dello sprite; per riga il byte della riga dell'oggetto (zero: la successiva) e i bit dello sprite, ciascuno allargato (`hit_wide`), `hit_line`. | 4 900 / 6 100 |
| `hit_setup` | `dh_obj`, `dh_pair` | Z: i cicli dei due riquadri (B da, C largo; D da, E largo) non si incontrano; altrimenti la finestra dove entrambi sono sui cicli del playfield (32–223, al massimo 8 di larghezza): dove inizia nei punti di ciascuno (`hit_ka`/`hit_sa`, `hit_kb`/`hit_sb`: byte, bit) e i bit dei suoi cicli (`hit_w`). | 500 / 700 |
| `hit_wide` | `dh_obj`, `dh_pair` | I punti del byte A un ciclo per bit in DE e oltre (dimensione C: 1, 2 o 4 cicli per punto, da `ov_exp2`, `ov_exp4`: tabelle fatte da `init_tables`), poi uno zero. | |
| `hit_line` | `dh_obj`, `dh_pair` | NZ: i punti di `hit_a` e `hit_b` si incontrano nella finestra: i due byte di ciascuno dal suo inizio spostati con `bsla de,b` (Z80N, 8 cicli), messi in AND tra loro e con `hit_w`. | |

## display.asm: le verifiche del playfield (e il vecchio modello del raggio)

Gran parte di questo file è il modello completo, esatto al ciclo, del DLI (`op`, `bm_events`,
`bm_draw`, `rec_set`, `p3_scan`, `bm_wsync`, il corpo di `collide` del raggio…), conservato come
riferimento e assemblato solo con `-DBEAM`. Assemblato sempre:

| routine | chiamata | cosa e come | A / B |
|---|---|---|---|
| `pf_under`, `pf_bank`, `pf_edge`, `pf_none` | il display del raggio (`-DBEAM`) | La riga dello sprite (bit D dal bit 7, posizione E, dimensione A: 1, 2 o 4 cicli per bit) sulla riga `bm_line` è sopra la riva, il bordo o uno dei due, punto per punto? Trova il record della riga (`pf_line`), poi ne percorre le sequenze (`pf_size`). Il gioco non le usa più. | |
| `pf_line` | `pf_bank`, `pf_edge` | HL = il record della riga `bm_line` (carry: una riga del fiume). | |
| `pf_size`, `pf_v1`, `pf_v2`, `pf_v4` | `pf_*` | Le sequenze sotto lo sprite: una sequenza che sovrappone i cicli dello sprite si verifica contro i suoi bit con `span_masks` (D: la pagina delle maschere); una variante per dimensione (N spostamenti trasformano un offset in cicli in un indice di bit). | |
| `collide` (`.add`, `.pair`, `.overlap`, `.entry`) | il display del raggio (`-DBEAM`) | Una lista degli sprite su una riga (bit, posizione, dimensione) e la verifica punto per punto della sovrapposizione di due di loro; il gioco non la usa più. | |
| `bm_hitclr` | `display` | HITCLR: i bit di collisione puliti. | 1 500 / 1 700 |
| `init_line_tables` | `tv_setup` | Per riga di scansione: i cicli di ANTIC al suo inizio (`line_start`) e quelli rimasti dopo il disegno (`line_after_draw`); ora li legge solo il modello `-DBEAM`. | |

## sprites.asm: sprite, il Copper, `apply`, il pannello

| routine | chiamata | cosa e come | A / B |
|---|---|---|---|
| `build_sprites` | `main_frame` | `ob_list` (gli oggetti); l'aereo, il suo proiettile, il carro, il missile dell'elicottero, il colpo (nell'ordine in cui li disegna `drawRiver`, l'ultimo sopra): ciascuno il pattern del suo fotogramma fatto all'avvio (`pl_plane`, `pl_tank`, `pl_shell`, `pl_bullet`, `pl_missile`) nella sua posizione, `pl_sprite`; `pl_keep` salva i loro attributi, che i fotogrammi di un reset (`busy`) mostrano di nuovo (`pl_again`); `build_copper`. | 1 000 / 1 100 |
| `pl_sprite` | `build_sprites` | Pattern A ($FF: nessuno) alla riga D (nessuno sotto il fiume), posizione E, offset di palette C: i suoi 5 byte di attributi in `sprite_list` (X = 2·(x − 52), 9 bit; Y; l'offset; il pattern; 4 bit, il mezzo pattern). | ~100 per sprite |
| `ob_list` | `build_sprites` | Per voce di `ds_objs`, le sue righe da `ds_objf` (tutte): la sua immagine fatta all'avvio trovata dagli indirizzi di forma e colore della riga in alto (`obj_lookup`; non trovata: `ob_miss`, non disegnata), uno sprite ogni 16 righe (`ob_attr`: X = 2·(x − 52), Y, il banco, 4 bit, il mezzo pattern, la scala per la larghezza doppia o quadrupla), nessuno per un pezzo la cui prima riga è sotto il fiume. | 5 700 / 6 400 |
| `build_copper` | `build_sprites` | Solo quando è cambiato lo standard (`cp_built` 0, `tv_setup`) o i colori si sono spenti o accesi (`colour_bank` 0 o no, contro `cp_bank_on`): le voci della riva rimesse dopo il grigio del pannello (`CP_RESTORE`: i loro colori, nero mentre i colori sono spenti), poi `copper_start` e la parte del pannello (`copper_panel`) nella lista, il WAIT finale. `cp_full` = 1. In bank_colours.asm. | 100 / 100 |
| `apply` | dopo `wait_frame` | Lo scorrimento del Layer 2 (NR $17), gli attributi degli sprite (porta $57, OTIR 5 per sprite; quelli in più del fotogramma precedente nascosti), i colori del colpo, del carro e dell'aereo (palette degli sprite), i colori 0, 2, 3 del Layer 2, la sua finestra di clip (mentre il Layer 2 si pulisce dopo un reset, dal suo secondo fotogramma: solo le righe del pannello, `l2_hidden`; `l2_clip_y2` l'ultima riga della finestra da `tv_setup`), `panel_frame`, il Copper: fermato, tutta la lista inviata se `cp_full`, altrimenti solo il byte di scorrimento X della scritta scorrevole, riavviato (modalità %11). Lo schermo spento dopo una lunga inattività (IDLE_TIME). Non nei numeri sopra. | — |
| `panel_frame` | `apply` | Il pannello: solo le posizioni che `panel_put` ha elencato (`pf_dirty`; tutte dopo la copia di `start_attract` e `tv_setup`), ciascuna da `.cells` (la cella della sua metà sinistra; il primo carattere della riga solo la sua metà destra), 2 celle del tile 2·codice + metà e i bit del colore come offset di palette. La scritta scorrevole (metà h a 8h − X0, X0 = 16·TEXT_LO + 38 − 2·FINE_SCROLL): un anello nella riga di mappa 26 (metà h nella colonna h mod 40; scritte solo le metà nuove dall'ultimo fotogramma, `.ring_write`; tutte e 40 dopo un salto), lo scorrimento X X0 mod 320 (9 bit: `CP_XSCROLL_HI_BACK`, `CP_XSCROLL_BACK`); la finestra di clip della tilemap più corta di S = X0 & 7 punti a destra (la colonna che si riavvolge); lo sprite 70 (pattern 20, offset di palette 6) a X 320 − S con la metà h0 + 40 (i suoi 64 byte scritti quando cambia: `.spr_pattern`). Gli sprite della lancetta e del logo. | ~1 700 la scritta scorrevole, ~200 il pannello, ~1 400 lancetta e logo |

Dati: `copper_start` (indice 1 della palette del Layer 2, un NOP dove c'era NR $4A (il colore di T), scroll Y e X della tilemap 0: le sue righe quelle dello schermo, niente nelle righe fuori dal pannello), `copper_panel_ntsc`/`_pal` (nella pagina 7, copper_panels.asm: `tv_setup` ne copia una in `copper_panel` attraverso lo slot 2; la stessa disposizione, quindi gli scostamenti valgono per entrambe: riga 200: lo scroll Y della tilemap per la prima riga del pannello (`CP_PANEL_Y`, messo da `tv_setup`), i colori 0–10 del Layer 2 neri (`CP_COLOURS`: anche le voci della riva, perché le righe sotto il pannello mostrano vecchie righe del fiume) e la finestra degli sprite dalla riga 215 in giù (`OBJ_LAST` + 1, sotto le righe di ogni oggetto; ago e logo più in basso); 201: grigio (`COPPER_GREY`, messo da `tv_setup`); lo scroll Y della tilemap per ogni riga del pannello; riga 230 (240 PAL): i colori 0–10 rimessi (`CP_RESTORE`: quelli della riva da `build_copper`, quelli di bordo e acqua da `apply`, `CP_EDGE_BACK`); scroll Y e X della scritta scorrevole (`CP_XSCROLL_HI_BACK`, `CP_XSCROLL_BACK`); a `wait_line`: la finestra degli sprite di nuovo quella del fiume). `apply` manda i byte dal bordo allo scroll X (`.cp_send`) quando la lista non è mandata intera.

## panel.asm (pagina 6): i caratteri del pannello

| routine | chiamata | cosa e come |
|---|---|---|
| `panel_put`, `panel_put_de` | chi scrive nel pannello | Un carattere nel pannello a HL (DE): nulla se è già lì; altrimenti scritto e la sua posizione elencata in `pf_dirty` (60 o più: tutte). |
| `print_bcd` | `show_score`, `show_other_score`, `show_high_score`, `show_bridges`, la fine partita | B byte BCD a HL come cifre a DE, '0' = C, zeri iniziali vuoti; nulla in modalità attract. Per ogni posto (punteggio, record o punteggio dell'altro, ponti, ponti dell'altro) tiene la base delle cifre e i byte stampati (`pb_cache`) e torna subito quando sono gli stessi. |
| `show_lives` | `prepare` e altri | I simboli delle vite; nulla quando il loro numero è quello stampato per ultimo (`sl_last`). |
| `pb_forget` | `start_attract` | I numeri stampati per ultimi dimenticati (tutti ristampati). |

I posti che si sovrappongono dimenticano quelli degli altri: le vite e i ponti dell'altro
giocatore, il testo di fine partita al posto delle vite.

## sound.asm: il driver del suono e i campioni di POKEY

| routine | chiamata | cosa e come | A / B |
|---|---|---|---|
| `sound_driver` | `vbi` | B2A5–B3D8: il driver dell'originale: canale 1 il bip di partenza, suoni d'evento, il bip di carburante basso o il motore; 2 un'esplosione o il missile; 3 lo sparo o una vita bonus; 4 il colpo del carro. Scrive AUDF/AUDC di POKEY (`pokey_audf`, `pokey_audc`). | 770 / 930 |
| `sound_init` | `restart` | I DAC accesi (NR $08), l'anello e i canali silenziosi, `sound_init7` (pagina 7: l'AY, le tabelle di POKEY, il DMA programmato), poi il DMA abilitato ($87) una volta che la pagina 12 è rimappata. | |
| `pokey_frame` | `main_frame` | `ay_frame` (i toni puri all'AY; tutti e quattro lì: l'anello reso silenzioso una volta, `snd_idle`, e fatto), poi quanti campioni: le righe rimaste prima di `wait_line` (NR $1E/$1F), dove si trova il DMA (il suo indirizzo riletto), fino a `SND_LEAD` (760) avanti, almeno `SND_MIN_LEAD` (200), al massimo `SND_CAP` (700). Poi: `snd_fill` (il tratto a 0), ogni canale non sull'AY: volume × il guadagno del fotogramma (`snd_gain_set`: 8, o 7–4 quando i volumi sommano più di 31, `mul d,e`) come livello costante (solo volume, o AUDF ≤ 4: metà) o `pk_channel` (le sue commutazioni come + e − nell'anello), poi `snd_sum` (la somma progressiva fa i livelli). Pagine 14–15 a $0000 nel frattempo (il contatore a 17 bit). | 2 400 / 2 500 |
| `snd_gain_set` | `pokey_frame` | `snd_gain`: 8 per passo di volume, o il massimo che tiene i livelli a 255 o meno quando i volumi dei canali sul DAC sommano più di 31 (7 fino a 36, 6 fino a 42, 5 fino a 51, altrimenti 4). | ~150 |
| `snd_fill` | `pokey_frame` | DE byte di A da HL nell'anello (due tratti al riavvolgimento), ciascuno con PUSH dalla sua fine in giù (SP salvato). | 2 800 / 2 400 |
| `snd_sum` | `pokey_frame` | La somma progressiva su DE campioni: `add a,(hl) / ld (hl),a / inc l`, srotolata 8 volte, con ingresso al punto giusto per il resto (`jp` automodificato), pagina per pagina nell'anello. ~8 400 cicli per ~270 campioni: circa 31 per campione. | 8 600 / 7 300 |
| `sound_random` | `sound_driver` | RANDOM per l'altezza di un rumore (non `random_read`, che le verifiche contano). | |

L'anello: 1024 byte a $7C00 (pagina 12), allineati a 1K, inviati alla porta $DF dallo zxnDMA in
modalità burst con prescaler 55 (15 909 Hz), riavviato alla fine. Livelli 0–240.

## sound_pulses.asm, sound_handlers.asm: le commutazioni di un canale

| routine | chiamata | cosa e come | A / B |
|---|---|---|---|
| `pk_channel` | `pokey_frame`, per canale con AUDF ≥ 5 | Prepara: i valori parziali del volume (× 0–3 su 4, per una commutazione dentro un campione), i passi del periodo per i contatori a 4 e 5 bit (`snd_mod15/31`), il periodo come campioni e cicli × 64 inseriti nei cicli; il primo impulso (`CH_D`, `CH_F`); K = impulsi in questo fotogramma (una divisione a 12 bit, srotolata: i tick sono sotto 4 × SND_CAP < 4096); poi il ciclo per il suo tipo. | 1 200 / 2 800 |
| `pk_tone` | `pk_channel` | Un tono: l'uscita commuta a ogni impulso. | |
| `pk_noise` | `pk_channel` | Rumore: il bit successivo del contatore a 17 bit a ogni impulso (i bit in fila, mappati a $0000); le sue commutazioni all'inizio del campione (+ o − il volume, nessuna parte su due campioni). | 4 600 / 12 900 |
| `pk_g4` | `pk_channel` | Il contatore a 4 bit fatto passare da quello a 5 bit (AUDC 010: il missile dell'elicottero): entrambi i contatori come un solo numero m (`g4_crt`: m = b + 31 ((e − b) mod 15)), un impulso m + s, `g4_tab` per ogni m ($FF non passa, altrimenti il bit); i contatori ricavati da m alla fine. Commutazioni all'inizio del campione. | 0 / 1 400 |
| `pk_other` + `pk_handlers` (`adv31`, `adv15`) | `pk_channel` | Gli altri tipi tramite gestori. | |
| `pk_on`, `pk_off`, `pk_part*` | i cicli | La commutazione di un tono o del resto a un impulso: il campione riceve il cambio meno la parte prima della commutazione, il campione successivo quella parte (nessun ronzio da campioni interi; il rumore e il missile commutano invece all'inizio del campione). | |
| `pk_done` | i cicli | Il resto dei tick del fotogramma in `CH_D`, `CH_F`, l'uscita conservata. | |

## sound_ay.asm (pagina 7), sound_ay_run.asm (pagina 6): i toni puri sull'AY

| routine | chiamata | cosa e come | A / B |
|---|---|---|---|
| `ay_init` | `sound_init7` | TurboSound acceso, il primo AY mono, solo toni, silenzioso. | |
| `sound_init7` | `sound_init` | `ay_init`, le tabelle di POKEY nella pagina 1, `snd_mod15/31`, il DMA programmato (non abilitato). | |
| `ay_frame` | `pokey_frame` | Per ogni canale di POKEY con un tono puro (AUDC 101x o 111x, non solo volume, volume ≠ 0): il proprio canale AY (`ay_slot`: 1 la A del secondo AY, 2 la A del terzo, 3 la B del primo, 4 la C del primo), il periodo N = (AUDF + 1) × 3,454 (PAL) / 3,422 (NTSC) tramite `mul d,e`, il volume tramite `ay_vol`, il bit del tono del mixer; `ay_mask` dice a `pokey_frame` di saltarli. I registri di questo fotogramma in `ay_q` (3 fotogrammi × 33: gli 0–10 dei tre chip, a turno tramite `ay_qi`), in uscita quelli di 2 fotogrammi prima. | 2 200 / 2 800 |
| `ay_out` | `ay_frame`, `ay_init`, `ay_quiet` | I registri 0–10 dei tre AY da HL (il primo resta selezionato, B = $FF). | 3 400 / 3 400 |
| `ay_quiet` | `pokey_frame` (suono spento), `ay_init` | Tutto silenzioso (volumi 0, mixer $3F). | |

`sound_ay_run.asm` è nella pagina 6, non 7, così che `pokey_frame` non mappi mai la pagina 7
sopra l'anello (vedi NOTES: lo scricchiolio).

## panel_init.asm (pagina 7, all'avvio)

| routine | chiamata | cosa e come |
|---|---|---|
| `panel_init` | `start` (pagina 7 a $6000) | I set di caratteri dell'Atari costruiti dove li costruisce il gioco (font del sistema da `font.inc`, i simboli della cartuccia), ogni carattere come due tile (tile 0–127 quelli del pannello, 128–255 quelli della scritta scorrevole) nelle pagine 10–11, la palette e i registri della tilemap (NR $6B/$6C/$6E/$6F, clip), i pattern degli sprite della lancetta e del logo, `edge_lo`/`edge_hi` (il primo e l'ultimo punto acceso di ogni byte, per la verifica del bordo). |
| `pl_pics` | `panel_init`, prima di `obj_pics` (pagina 7) | I 10 fotogrammi dell'aereo (14 righe), gli 8 del carro (11 righe) e i 7 del colpo (16 righe) dalle loro tabelle di puntatori nella ROM, come `prepare` li copia nella memoria player-missile: un pattern a 4 bit ciascuno (un punto: 2 pixel di valore 1), condiviso da fotogrammi con un unico indirizzo, nessuno per uno tutto vuoto ($FF); il proiettile (8 righe di un punto) e il missile dell'elicottero (una riga di 4 punti). Pattern da 0 (20 in tutto). |
| `obj_pics` | `panel_init` (pagina 7) | Le immagini degli oggetti: per i tipi 7–15 i tipi d'aspetto che possono avere (il proprio, quelli di `ROM_NEXT_KIND` sotto $0C, quelli dell'esplosione da 2 e 3), ciascuno anche specchiato, height + 1 righe; 58 immagini come pattern a 4 bit da 24, il valore di un punto il posto del colore della sua riga nel banco di palette 14 (tipi 12, 15) o 15 (gli altri); `obj_head`/`obj_e` per `obj_lookup`. |

## load_rom.asm (pagina 7)

| routine | chiamata | cosa e come |
|---|---|---|
| `load_rom` | `start` (non nelle build di prova) | Apre River_Raid.rom nella cartella del programma tramite esxDOS (F_OPEN, F_READ, F_CLOSE; con il nome corto dove i nomi lunghi non si vedono) e legge i suoi 8192 byte a $A000 (pagina 5). Senza: un bordo rosso e uno stop. Verificato solo su un Next reale. |

## Include

- `vars.inc`: gli indirizzi RAM dell'Atari delle variabili del gioco (i nomi dell'originale).
- `palette.inc`: la palette dell'Atari come colori del Next (fatta da `tools/mkpalette`).
- `random.inc`: le colonne del passo di RANDOM (`tools/mkrandom`).
- `font.inc`: il font del sistema (`tools/mkfont`, quello di AltirraOS, con la sua nota).
- `poly.inc`, `poly17.bin`: le sequenze a 4, 5 e 17 bit di POKEY (`tools/mkpoly`).

## Cose da sapere prima di modificare il codice

- **Il codice automodificante** è comune nei cicli caldi: valori immediati e destinazioni di salto inseriti (`.bx1/.be1/.bx2/.be2/.ex1/.ex2/.s1/.s2/.pv/.pv_bits/.pv_end/.pv_x` di `ds_edge_test`; `.mode/.x0a…/.x1d/.bits/.fn` di `dh_pf`; `.jp` di `snd_sum`; `.pf/.pq` dei `pk_*`). Una variante va verificata byte per byte (un `add a,a` rimasto ha una volta raddoppiato il suono).
- **Punti d'ingresso srotolati**: `snd_sum` salta nel mezzo di un blocco `rept` per il resto.
- **Lo slot 2** è una finestra di lavoro: una routine che vi serve una pagina la mappa e non la ripristina; il prossimo utente mappa la sua. **Lo slot 3** deve restare la pagina 12 mentre suona il suono.
- **Le tabelle sono allineate alla pagina** così che `ld h,high table / ld l,index` sia la ricerca: `span_masks`, `span_class`, `edge_lo/edge_hi`, `obj_head`, `ov_exp2`/`ov_exp4`, `eg_*`, `bg_*`, la palette.
- **Le verifiche**: dopo ogni modifica, `nxcheck` confronta a ogni fotogramma con il port in C++ stato e memoria dello schermo, il colore della riva per riga, gli oggetti come disegnati, la lista e la memoria del Copper, e alla fine l'immagine. Il set completo richiede ~25 minuti su 2 core (HANDOFF.it.md, *Metodo*). Un assemblaggio fallito lascia le vecchie pagine: controllare prima l'output della build.
- **Misurare**: `NXHISTALL=file` (tutti i fotogrammi) o `NXHIST=file` (un fotogramma) e `tools/prof.py`; `NXSLOW=T` elenca i fotogrammi oltre T cicli. `NXHISTAPPLY=file` fa lo stesso per `apply` (dalla fine di `wait_frame`) e ne stampa media e massimo; `tools/prof_local.py build/test.sym file fotogrammi [routine…]` divide il tempo anche per etichette locali (`ds_edge_test.row`, `panel_frame.mod`, …). I fotogrammi più pesanti: `-stress` con `NXBRIDGE=80 NXGHOST=1 NXGAME=1`.
- **apply** (~7 400 a fotogramma, non nelle tabelle sopra): la scritta scorrevole ~1 700 (lo scorrimento X mod 320 per sottrazione ~650 di questi), lancetta e logo ~1 400, il pannello ~200 (solo ciò che è cambiato), gli attributi degli sprite ~1 800, la lista del Copper ~1 200.
- **Una riscrittura** si verifica più in fretta con una build di prova che a ogni fotogramma esegue il nuovo modo accanto al vecchio e conta dove differiscono (fatto per le righe delle collisioni, il posizionamento, i cursori), poi si elimina il vecchio.
