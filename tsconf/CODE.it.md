# Il sorgente assembly del port per TS-Conf, file per file

[English](CODE.md) | [Русский](CODE.ru.md) | [Українська](CODE.uk.md) | [Deutsch](CODE.de.md) | [Polski](CODE.pl.md) | Italiano | [Español](CODE.es.md) | [中文](CODE.zh.md) | [日本語](CODE.ja.md)

Per i programmatori Z80 che vogliono leggere il codice del port per TS-Conf o renderlo più veloce.
Il gioco in sé (la logica, il generatore del fiume, il posizionamento degli oggetti e le
collisioni) è il codice del Next, copiato in `src/`; [docs/CODE.it.md](../docs/CODE.it.md)
descrive quelle routine, e questo documento dice solo come sono state modificate. Ciò che è
proprio di TS-Conf (l'immagine, il colore della riva per riga, gli sprite, il pannello, il suono
su una General Sound, l'avvio da una scheda SD) è descritto qui routine per routine, con il suo
costo. La panoramica è in [README.it.md](README.it.md).

## Le due macchine a confronto

Lo stesso gioco, due modi di mostrarlo. Cosa differisce, e dove si vede nel codice:

| | ZX Spectrum Next | TS-Conf (ZX Evolution) |
|---|---|---|
| Processore | Z80N a 28 MHz (3,5 / 7 / 14 / 28), interrupt spenti: il fotogramma interrogando la riga raster | Z80 a 14 MHz (3,5 / 7 / 14), cache accesa; l'interrupt del fotogramma, IM 2, spostato giù per il fotogramma da un evento all'altro |
| Istruzioni Z80N | `nextreg`, `mul`, `bsla de,b`, `outinb`… | nessuna: un registro è `ld bc,porta / out (c),a`; `bsla de,b` un ciclo (`shl_de_b`, display_hits.asm); `mul` non serve (il periodo dell'AY con addizioni) |
| Memoria | slot da 8K (MMU, NR $50–$57) | finestre da 16K (PAGE0–PAGE3); la finestra 0 è RAM scrivibile (MEMCONFIG), quindi la RAM dell'Atari sta a $0000 |
| Il fiume | Layer 2, 320×256, 8 bit, per colonne: una riga sono 320 scritture giù per le colonne, 10 pagine a turno | 16 colori, 320×240, una riga dell'immagine di 256 byte (2 punti per byte): una riga sono 160 byte lungo la riga, una pagina |
| Scorrimento | NR $17, un anello di 256 righe | GYOFFS, un anello di 512 righe (`scroll` 9 bit) |
| Il colore della riva per riga | il Copper: una lista di WAIT/MOVE, inviata quando cambia | una palette per colore della riva (PALSEL 0–7, CRAM); l'interrupt del fotogramma imposta PALSEL una riga prima di un cambio (`build_events`, `irq`) |
| Sprite | 128 pattern di 16×16, 4 o 8 bit, scala ×2 ×4; un oggetto è uno sprite ogni 16 righe | una sola memoria di immagini 512×512 a 4 bit (SGPAGE), qualsiasi dimensione fino a 64×64, niente scala: ogni immagine tenuta larga 16, 32 e 64 punti; un oggetto è uno sprite |
| Colori | NR $41 ecc., 9 bit | la CRAM attraverso la finestra FM a $E000 (`CRAM_SHADOW`): i colori e la lista degli sprite (SFILE) a $E200 sono semplici scritture in memoria |
| Il pannello e la scritta scorrevole | la tilemap sopra tutto, il suo scorrimento Y e X dal Copper; la scritta scorrevole un anello di tile + uno sprite alla giuntura | un'immagine propria (256 colori, pagine 64–79) accesa dalla riga 184 dall'interrupt del fotogramma (VPAGE, GYOFFS, VCONFIG con GFXOVR), i suoi caratteri disegnati una volta e copiati dal DMA; la scritta scorrevole un anello di 32 caratteri su 512 punti, GXOFFS impostato dall'interrupt; lo strato di tile 0 il grigio sotto i caratteri e il nero sopra e sotto il fiume |
| Suono | i rumori che fa POKEY in un anello, lo zxnDMA al DAC (`pokey_frame` sul processore principale, ~26 000–39 000 dei suoi cicli a 28 MHz a fotogramma); toni puri su 3 AY | lo Z80 proprio di una General Sound suona tutto POKEY (`gs/`); il processore principale invia 8 byte a fotogramma (~3 400 con il driver). Senza scheda: i toni puri sui 2 AY del TurboSound |
| La cartuccia | esxDOS: River_Raid.rom dalla cartella del programma | codice proprio per SD e FAT16/FAT32: la scheda viene perlustrata (Wild Commander non dà una cartella) |
| TV | 50 o 60 Hz (CAPS + 1) | solo 50 Hz: il fotogramma della scheda |
| Pulire l'immagine | PUSH, due pagine del Layer 2 a fotogramma | il riempimento del DMA, metà immagine a fotogramma |
| Strumenti | `nxcheck` (core del Next), `NXHISTALL` + `tools/prof.py` | `tscheck` (core TSConf), `TSHISTALL` + `../tools/prof.py` |

## I numeri

I tempi sono cicli del core TSConf a 14 MHz (il clock del processore), un fotogramma ne ha
~286 800. Dall'istogramma di tscheck (`TSHISTALL=file`, poi `python3 ../tools/prof.py
build/test.sym file 60`, diviso per i fotogrammi), sulla build di verifica (`-DTEST`: con la
memoria dello schermo dell'Atari, che il gioco non ha: `line_done` e `draw_line` sono ~1 000–2 000
più pesanti che nel gioco). Con una General Sound, quindi i rumori non costano nulla al
processore principale. Due esecuzioni:

- **A**: bot 1, 3 000 fotogrammi dall'inizio: il lavoro ~69 000 a fotogramma in media, al massimo ~120 000;
- **B**: `-stress` dal ponte 80, 6 000 fotogrammi (`TSBRIDGE=80 TSGHOST=1 NXGAME=1 … -bot 1 -stress`: tutti gli slot occupati, tutta velocità, sempre sparando): ~108 000 in media, al massimo ~144 000.

Il lavoro va da `apply_done` a `frame_done` (l'attesa dell'interrupt del fotogramma non contata);
le parti sotto contano anche `apply` e gli interrupt (~7 000).

Per parti (A / B):

| parte | A | B |
|---|---|---|
| il display: posizionamento degli oggetti e collisioni (`display`, `ds_*`, `dh_*`, `sp_*`, `hit_*`) | 38 300 | 51 000 |
| nuove righe del fiume (`river_gen`, `render_line`, `span_line`, `line_done`, `push_line`) | 13 600 | 32 200 |
| sprite e gli eventi della riva (`build_sprites`, `ob_*`, `pl_*`, `obj_lookup`, `sfile_put`, `build_events`, `pal_get`) | 10 300 | 14 900 |
| `apply`, il pannello e gli interrupt (`apply`, `panel_frame`, `panel_draw`, `pc_*`, `pal_edges`, `irq`, la stampa del pannello) | 7 900 | 7 500 |
| suono (`sound_driver`, `snd_*`, `gs_*`; senza scheda `ay_*`: ~5 800 in A) | 3 400 | 3 500 |
| la logica del gioco e il resto (`move_objects`, `main_loop`, `random_step`, `vbi`, …) | 7 000 | 8 800 |

Le routine più costose (A / B):

| routine | A | B | file |
|---|---|---|---|
| `display` (codice proprio) | 11 200 | 12 900 | display_simple |
| `dh_pf` | 8 700 | 9 800 | display_hits |
| `span_line` | 3 900 | 9 500 | spans |
| `ds_edge_test` | 2 800 | 8 700 | display_simple |
| `render_line` | 3 500 | 8 400 | render |
| `ds_obj` | 5 300 | 6 200 | display_objs |
| `dh_obj` | 4 400 | 5 500 | display_hits |
| `ob_attr` | 2 500 | 5 100 | sprites |
| `move_objects` | 1 700 | 3 300 | game |
| `dl_fill` | 1 500 | 3 300 | river_gen |
| `ob_list` | 2 400 | 3 200 | sprites |
| `line_done` (la copia nella memoria dello schermo, solo build di verifica) | 1 100 | 2 500 | game |
| `gs_send` + `gs_wait_c` + `gs_wait_d` | 2 400 | 2 300 | sound_gs |
| `pl_keep` | 800 | 1 600 | sprites |
| `panel_frame` | 1 600 | 1 600 | panel_ts |
| `irq` | 1 400 | 1 400 | river_raid |
| `dh_lists` | 1 300 | 1 300 | display_hits |
| `sfile_put` | 1 200 | 1 300 | river_raid |
| `apply` (codice proprio) | 1 200 | 1 200 | river_raid |
| `pal_edges` | 1 100 | 1 100 | river_raid |
| `build_events` | 1 000 | 1 000 | river_raid |
| `hit_setup` | 500 | 700 | display_hits |

A 7 MHz (`TSSPEED=1`, ~143 400 cicli a fotogramma) il lavoro sono le stesse istruzioni:
`-stress` ~93 000 in media, al massimo ~125 000, ci sta appena; a 3,5 MHz non regge. `gs_send`
aspetta che la scheda legga ogni byte (~300 cicli per byte a 14 MHz).

(`prof.py` prende il nome di una routine dall'etichetta globale più vicina sotto l'indirizzo. Gli
indirizzi sotto $4000 sono il lavoro dell'avvio in INIT_PAGE: lasciarli fuori.)

## La memoria mentre il codice gira

Finestre da 16K e le pagine al loro interno (le pagine da 16K della scheda):

| finestra | indirizzo | normalmente | rimappata da |
|---|---|---|---|
| 0 | $0000–$3FFF | 1 (`ATARI_PAGE`): la RAM dell'Atari agli indirizzi dell'originale | all'avvio: 3 (`INIT_PAGE`: lì girano `sprite_pics.asm`, `gs_load.asm`, `load_rom.asm`) |
| 1 | $4000–$7FFF | 5 (`WORK_PAGE`): le sequenze delle righe da $4000 (`SPANS`, 32 byte × 256 righe), buffer da $6000 (`scan_*`, `edge_runs`, `ring_*`, `ds_objs`, `ov_exp2/4`, `eg_*`, `bg_*`, `line_*`, `edge_lo/hi`, `rnd_tab`), il font del sistema a $7D00 | `render_line`: una pagina dell'immagine del fiume (32–47); `panel_draw`/`pc_*`: l'immagine del pannello (64–79); all'avvio la mappa dei tile (7), i tile (8), le immagini degli sprite (24–31); sempre rimessa a 5 |
| 2 | $8000–$BFFF | 2 (`CODE_PAGE`): codice fino a ~$9FBF, la cartuccia da $A000 | — |
| 3 | $C000–$FFFF | 6 (`HIGH_PAGE`): codice fino a ~$D7EC, poi a $E000 la finestra FM (`CRAM_SHADOW`: CRAM $E000–$E1FF, lo SFILE $E200–$E3FF; le scritture vanno anche nella RAM sotto), tabelle e variabili fino a ~$FD65, lo stack, i vettori IM 2 a $FE00 | — |

Le immagini: il fiume dalla pagina 32 (`VID_PAGE`, 16 pagine: 512 righe da 512 byte, di ognuna
mostrati 320 punti), il pannello dalla pagina 64 (`VPANEL`), la mappa dei tile nella pagina 7, i
punti dei tile nella pagina 8, i 512×512 punti degli sprite nelle pagine 24–31 (`SGPAGE`). Il
codice di INIT_PAGE finisce a ~$11DF, i buffer della pagina di lavoro a $7C00. La finestra FM è
accesa per sempre: niente altro può usare $E000–$E3FF, e $E400–$E4FF sono i suoi registri
(`palette_lo` sta lì, solo in lettura).

## Il fotogramma

`main_frame` (river_raid.asm), a ogni fotogramma:

1. Un'istantanea di ciò che mostra l'immagine di questo fotogramma (`scroll`, i colori del bordo e dell'acqua, il giocatore), `read_input`.
2. Normalmente: `prepare` → `display` → `build_sprites` → `build_events` → `main_loop` → `vbi` → `snd_frame`. Durante un reset (`busy`): `display` → `build_sprites` → `build_events` → `clear_layer2_page` → (`finish_reset` nell'ultimo) → `vbi` → `snd_frame`.
3. `wait_frame`: HALT finché non è arrivato l'interrupt del fotogramma (`frame_flag`), a `FRAME_LINE`, sotto il pannello.
4. `apply`: tutto ciò che è stato costruito diventa attivo (lo scorrimento, il suono, i colori, lo SFILE, la palette della riva in cima e gli eventi dell'interrupt per il fotogramma che viene).
5. `panel_draw`: i caratteri del pannello che sono cambiati e quelli nuovi della scritta scorrevole, nella sua immagine (dopo `apply`: può richiedere un po', e il pannello si vede solo dalla riga 184).

Mentre si disegna l'immagine l'interrupt arriva a ogni evento della lista che `apply` ha
impostato: EV_PAL (la palette del fiume dalla riga successiva), EV_PANEL (l'immagine del pannello
dalla riga 184), EV_GX (la X della scritta scorrevole), poi quello del fotogramma. Ognuno arriva
al bordo destro della riga prima (HSINT = 208), e PALSEL, VPAGE, GYOFFS vengono presi alla fine di
una riga, quindi un cambio è esatto a qualsiasi velocità del processore e ovunque sia il lavoro.

---

## I file del Next, come sono qui

Copiati da `../src`, lo stesso codice:

- `river_gen.asm`, `display_objs.asm`, `panel.asm`, `vars.inc`, `font.inc`, `random.inc`: invariati.
- `display.asm`, `display_simple.asm`, `spans.asm`: la pagina SPANS non viene mappata (`nextreg $52,SPAN_PAGE` tolto: la finestra 1 tiene SPANS per tutto il tempo); `spans.asm` senza `rl_fill`/`rl_next` (gli aiutanti di `render_line` sul Next).
- `display_hits.asm`: `bsla de,b` (Z80N) come `shl_de_b`, un ciclo di 0–7 `sla e / rl d` (in `hit_line`: fino a ~100 cicli in più per verifica, qualche centinaio a fotogramma).
- `game.asm`: `tm_colour` scrive BORDER (una voce della CRAM: `TM_*` sono le voci libere del gruppo 11 dalla 2, i loro colori li imposta `tm_cram`), e `TM_COLOUR` lo chiama solo con T acceso; `push_line` muove `scroll` in un anello di 512 righe (9 bit) e disegna nella riga dell'immagine `scroll + RIVER_TOP`.
- `play.asm`: `clear_layer2_page` è quello di TS-Conf (river_raid.asm, il DMA); `read_input` senza CAPS + 1 (niente 60 Hz), CAPS + 2 (suono spento), CAPS + 3 (velocità), il secondo Kempston e il pad Mega Drive.
- `sound.asm`: solo `sound_driver` e `sound_random`: `pokey_frame` gira sulla General Sound (`gs/`).
- `render.asm`, `sprites.asm`, `sound_ay.asm`, `load_rom.asm`, `river_raid.asm`: quelli propri di TS-Conf (sotto), con i nomi del Next dove fanno lo stesso lavoro.

Le routine dei primi tre gruppi sono descritte in [docs/CODE.it.md](../docs/CODE.it.md); il loro
costo qui è nella tabella sopra.

## river_raid.asm: il fotogramma, l'avvio, l'interrupt, i colori

Il file principale: le porte della scheda, la memoria, le pagine, gli `include`, il fotogramma,
l'interrupt, `apply`, le palette del fiume, variabili e buffer.

| routine | chiamata | cosa e come | A / B |
|---|---|---|---|
| `start` | al caricamento | 14 MHz e la cache (SYSCONFIG $06), finestra 0 RAM (MEMCONFIG $0E), le pagine, `screen_black`, `load_rom` (build SPG), `init_tables`, `init_video`, le immagini degli sprite (`obj_pics`, `pl_pics`, `panel_pics`), `gs_load`, poi la RAM dell'Atari nella finestra 0, `panel_init`, `ay_quiet`, il seme di RANDOM, IM 2 (vettori a $FE00), `restart`. | una volta |
| `restart` | `start` | `tv_setup`, l'immagine pulita (entrambe le metà dal DMA, attese), l'interrupt del fotogramma a `FRAME_LINE`, `start_attract`, il pannello disegnato intero, cade in `main_frame`. | una volta |
| `main_frame` | ogni fotogramma | Vedi *Il fotogramma*. | 340 / 340 |
| `wait_frame` | `main_frame` | Un ciclo fino al prossimo INT del fotogramma (`frame_flag` prima azzerato: uno arrivato durante il lavoro è troppo tardi per `apply`; niente HALT né DI: vedi NOTES): inattività, non lavoro. | — |
| `irq` | l'interrupt | L'evento a `ev_ptr`: EV_PAL PALSEL; EV_PANEL VPAGE = `VPANEL`, GYOFFS = 0, VCONFIG $8A (256 colori, la bitmap sopra tile e sprite); EV_GX GXOFFS; quello del fotogramma (EV_END) `frame_flag`. Gli eventi sulla stessa riga si fanno insieme; poi VSINT impostato alla riga del successivo (`vsint_set`), o a quella del fotogramma. All'evento del fotogramma rimette anche i registri dell'immagine e gli eventi di `apply` (`river_regs`, `ap_pal`, `ev_go` da `ap_list`): un fotogramma in ritardo mostra di nuovo l'ultimo. A 3,5 MHz (l'avvio conta i giri di un ciclo in un fotogramma) `.cmp` diventa JP `.gap`: l'evento successivo fino a `EV_GAP` (2) righe dopo si fa subito. | 1 400 / 1 400 |
| `vsint_set` | `irq`, `apply`, `restart` | VSINT = HL (9 bit), tenuto in `ev_line`. | 340 / 330 |
| `apply` | dopo `wait_frame` | GYOFFS = `show_scroll`, VPAGE quella del fiume, VCONFIG $81 (16 colori), GXOFFS 0; `snd_out` (i registri dell'AY o il fotogramma della scheda); `panel_frame`; i colori del colpo e dell'aereo nella CRAM; `sfile_put`; mentre l'immagine si pulisce dopo un reset (dal suo secondo fotogramma): il fiume nero (palette del colore 0, bordo e acqua 0, solo gli eventi del pannello); altrimenti PALSEL la palette in cima (`ev_built`), `pal_edges`, gli eventi del pannello copiati dopo quelli della riva (`ev_tail`); l'interrupt impostato sul primo evento (DI intorno); `ev_show` = la lista appena impostata (`build_events` scrive l'altra). | 1 200 / 1 200 |
| `pal_get` | `build_events`, `apply` | La palette del fiume (PALSEL 0–7) del colore Atari E: ogni colore della riva ha la sua, fatta la prima volta che compare (`pal_of`, `pal_n`): il suo colore 1 quel colore, nella CRAM. Oltre 8, di nuovo l'ultima (mai successo). | 110 / 110 |
| `pal_edges` | `apply` | I colori 2 e 3 (bordo, acqua) di tutte le palette fatte finora. | 1 100 / 1 100 |
| `sfile_put` | `apply` | Lo SFILE, costruito in `spr_list`: gli sprite del fiume (S0), dietro di loro copiato `sf_tail` (una voce finale con LEAP, i 3 del pannello: lancetta e logo, S1, una fine); le voci dopo fino alla fine del fotogramma precedente (`sf_end`) azzerate lì; poi il DMA lo copia nello SFILE (DMACTRL $85, da RAM a SFILE, un solo burst; la CPU lo programma soltanto). Mentre il DMA è occupato (la pulizia del reset) copia la CPU attraverso la finestra FM a $E200. | 1 200 / 1 300 |
| `build_events` | `main_frame` | Il colore della riva per riga, come il `build_copper` del Next da `ds_bank_ev`: nel buffer che gli interrupt non leggono (`ev_a`/`ev_b`), la palette alla cima del fiume, poi un evento EV_PAL per ogni cambio, 5 byte (tipo, palette, colore per la verifica, riga VSINT una riga prima); `ev_tail` dove apply mette i due del pannello. | 1 000 / 1 000 |
| `clear_layer2_page` | `main_frame` durante `busy`, `restart` | Metà dell'immagine del fiume (256 righe × 160 byte, 4 pagine) a fotogramma con il riempimento del DMA (DMACTRL $14, 80 parole × 256 righe da `dma_zero`); niente nel primo fotogramma del reset (`l2_wait`); niente mentre il DMA è occupato. Il processore lo programma soltanto (~150 cicli). | |
| `dma_wait` | `restart`, `init_video` | Finché il DMA non è libero (DMACTRL bit 7). | |
| `init_tables` | `start` | Come quelle del Next (`edge_runs_init`, `ov_exp2/4`, `ring_*`, `span_class`, `edge_lo/hi`, `span_init`), `pix_tab` con l'indice in entrambi i nibble (i 2 punti per byte della modalità a 16 colori). | una volta |
| `init_video` | `start` | La modalità del fiume (VPAGE 32, VCONFIG $81, PALSEL 0); la mappa dei tile (pagina 7: righe 0–23 tile 1 nero, 184 tile 3 una linea nera sopra il grigio, 185–223 tile 2 grigio, 224–239 nero; le righe del fiume nessuno) e i punti dei tile (pagina 8); i 128K degli sprite puliti dal DMA; TSCONFIG $A0 (strato di tile 0 e sprite accesi); la finestra FM accesa per sempre, CRAM e SFILE azzerati; il colore del carro; HSINT, solo l'interrupt del fotogramma (INTMASK 1). | una volta |
| `screen_black` | per prima in `start` | TSCONFIG 0, BORDER 0, tutto il 1K di CRAM e SFILE azzerato attraverso la finestra FM: nero, qualunque modalità abbia lasciato Wild Commander (il suo schermo ZX nella pagina 5 è dove vanno i buffer dell'avvio). | una volta |
| `tv_setup` | `restart` | Solo PAL: `init_line_tables`, le colonne PAL di RANDOM, `rnd_tables`. | |
| `test_ghost` | build di prova | TSGHOST di tscheck, come sul Next. | |

`span_rec` (HL = il record di una riga in SPANS) è la stessa macro del Next, a $4000.

## render.asm: una riga nell'immagine

| routine | chiamata | cosa e come | A / B |
|---|---|---|---|
| `render_line` | `line_done` | I cicli di colore 20–179 della riga nella riga dell'immagine HL (0–511): la pagina `VID_PAGE` + riga / 64 nella finestra 1, la riga a $4000 + (riga & 63) × 256; dai pezzi di `dl_seg` come sul Next: un pezzo di un valore è il suo byte di `pix_tab` 4 volte per byte (`.fill`: `ld (hl),a / inc l`), i byte di un bordo (la tabella della ROM) e una riga di decorazione attraverso `pix_tab`, 4 byte d'uscita ciascuno. 160 scritture per riga lungo la riga (il Next ne scrive 320 giù per le colonne, 10 pagine). WORK_PAGE rimessa alla fine. Un pezzo di un valore lungo 5 byte o più (`RL_DMA_MIN`) va invece al DMA quando è libero: un riempimento (DMACTRL $04) da `rl_word` (il valore due volte) nella pagina `rl_page`. Nella pagina $C000 (spostata da $8000 per fare spazio). | 3 500 / 8 400 |

## sprites.asm: gli sprite del fiume

Gli sprite di TS-Conf non hanno scala, quindi ogni immagine è tenuta larga 16, 32 e 64 punti (un
pixel dell'Atari sono 2 punti; un player 8 pixel a dimensione ×1, ×2, ×4). Un oggetto è un unico
sprite fino a 24 righe (il Next ne fa uno ogni 16 righe). Palette: oggetti 14 e 15 (`OBJ_PAL_A`,
`OBJ_PAL_B`, i colori delle righe ai posti 1–15), colpo e missile 8, carro 9, aereo e proiettile
10. Le voci (6 byte ciascuna, il formato dello SFILE: Y con YS e ACT, X con XS e i bit di
specchiatura, il tile e la palette) vanno in `spr_list`; le copia `apply`.

| routine | chiamata | cosa e come | A / B |
|---|---|---|---|
| `build_sprites` | `main_frame` | `ob_list`; poi l'aereo, il suo proiettile, il carro, il missile dell'elicottero, il colpo (l'ordine in cui li disegna `drawRiver`) tramite `pl_pattern` + `pl_sprite`; `pl_keep`. Durante un reset `pl_again`. | 800 / 800 |
| `ob_list` | `build_sprites` | Per voce di `ds_objs` con le sue righe (`ds_objf`): `obj_lookup` dagli indirizzi di forma e colore della riga in alto; non trovata: nessuno sprite; prima riga sotto il fiume: nessuno; altrimenti `ob_attr`. | 2 400 / 3 100 |
| `obj_lookup` | `ob_list` | L'immagine del byte di forma a $B900 + E e del byte di colore a $B700 + D: `obj_head` (dal byte di forma) poi la sua catena in `obj_e`; A = immagine + bit 7 per `OBJ_PAL_B`. | 1 000 / 1 300 |
| `ob_attr` | `ob_list` | La voce dello SFILE: Y = `RIVER_TOP` + il posto della sua riga nel fiume (9 bit) con YS da `pic_h` e ACT; X = 2 × (posizione − 52) (9 bit) con XS 1, 3 o 7 secondo la dimensione; il tile della larghezza giusta (`pic_tn16/32/64_lo/hi`), la palette. | 2 500 / 5 200 |
| `pl_pattern`, `pl_sprite` | `build_sprites` | L'immagine del fotogramma dalla sua tabella ($FF: nessuna); uno sprite largo 16 punti alla riga D (nessuno sotto il fiume), posizione E, palette C. | ~100 per sprite |
| `pl_keep`, `pl_again` | `build_sprites` | Le voci dei player conservate; i fotogrammi di un reset le mostrano di nuovo (come sul Next). | 800 / 1 600 |
| `cram_set` | l'avvio, `init_video` | Voce CRAM A × 16 + B = colore Atari E (`palette_lo`). | |

## sprite_pics.asm (INIT_PAGE, all'avvio): le immagini degli sprite

Nella memoria delle immagini di 512×512 punti (SGPAGE, 4 bit per punto, una riga 256 byte)
attraverso la finestra 1; i tile di un'immagine sono 8×8, numerati (riga / 8) × 64 + x / 8.

| routine | chiamata | cosa e come |
|---|---|---|
| `gfx_alloc` | `pic_set`, `pl_pics`, `panel_pics` | Un posto per un'immagine larga BC punti, alta A righe (un multiplo di 8): lungo le righe finché ci sta, poi sulle righe successive (`gfx_cx`, `gfx_cy`, `gfx_rh`). |
| `gfx_tile` | | Il numero di tile di un punto. |
| `gfx_row` | | La riga C di un'immagine: i punti del byte D (bit 7 per primo) nel colore E nelle tre larghezze (2, 4, 8 punti per bit), o solo la prima (B 1). |
| `obj_pics` | `start` | Come l'`obj_pics` del Next: per i tipi 7–15 i tipi d'aspetto che possono avere (il proprio, quelli di `ROM_NEXT_KIND` sotto $0C, quelli dell'esplosione), ciascuno anche specchiato, height + 1 righe come le disegna il DLI; ogni immagine una volta (dai suoi indirizzi) nelle tre larghezze; il valore di un punto il posto del colore della sua riga nella palette 14 o 15 (impostato quando nuovo: `cram_set`); `obj_head`/`obj_e` per `obj_lookup`. |
| `pic_set` | `obj_pics` | I tre tile dell'immagine `op_p` (a gfx_x, + 16, + 48) e il suo YS. |
| `pl_pics` | `start` | I 10 fotogrammi dell'aereo, gli 8 del carro, i 7 del colpo (dalle loro tabelle di puntatori nella ROM, come `prepare` li copia), il proiettile e il missile dell'elicottero: larghi 16 punti, colore 1; un'immagine per indirizzo, $FF per un fotogramma vuoto. |
| `panel_pics` | `start` | La lancetta (missile 1: 2 cicli di colore, 10 righe) e il logo: player 3 a 64 punti (dati $FC), player 2 (dati $FF) un ciclo più a sinistra a ogni riga (7 righe in 32 punti). |

## panel_ts.asm: il pannello e la scritta scorrevole

Il pannello è un'immagine propria (pagine 64–79, 256 colori, 512 byte per riga), mostrata dalla
riga dello schermo 184 (EV_PANEL dell'interrupt del fotogramma) con la bitmap sopra tile e sprite
(GFXOVR): i suoi punti a 0 sono buchi, che mostrano lo strato di tile 0 (il grigio, il nero) e gli
sprite del pannello. Colori 4–7 i PF0–PF3 del pannello, 8 quello della scritta scorrevole. La
scritta scorrevole è un anello di 32 caratteri sui 512 punti dell'immagine, mostrato da GXOFFS
(EV_GX alla sua prima riga).

| routine | chiamata | cosa e come | A / B |
|---|---|---|---|
| `panel_init` | `start` | I due set di caratteri dell'Atari nella sua RAM dove li costruisce il gioco (A0FB–A143: quello della scritta scorrevole a $0600, quello del pannello a $0800); i colori (CRAM: quelli dei caratteri come voci 4–8 della palette 0, quello della lancetta, le righe del logo da $B48D, il nero e il grigio dei tile come voci 14 e 15 della palette 3: una palette del fiume usa solo le voci 0–3); i caratteri disegnati una volta (`GLYPHS`: quelli della scritta scorrevole, quelli del pannello nei suoi 4 colori) perché `pc_put` li copi; l'immagine del pannello pulita; tutto segnato da scrivere al primo fotogramma. | una volta |
| `panel_frame` | `apply` | La X della scritta scorrevole (`pf_gx` = 16 TEXT_LO + 38 − 2 FINE_SCROLL, 9 bit) per l'EV_GX dell'interrupt; la lancetta (missile 1 a fuel / 8 + $5C) e i due sprite del logo in `spr_s1` (`.spr`). | 1 600 / 1 600 |
| `panel_draw` | dopo `apply` | I caratteri che `panel_put` ha elencato (`pf_dirty`, tutti e 60 dopo una copia) tramite `panel_frame.char`; la scritta scorrevole: quando TEXT_LO è avanzato di uno, il suo carattere 24 più in là; quando è saltato, tutti e 25 (`panel_frame.text`: il carattere t al punto 16 t mod 512 dell'anello). | 160 / 160 (+ `pc_*`) |
| `pc_put` | `.char`, `.text` | Un carattere copiato dal DMA da dove è stato disegnato una volta (`pc_bank`) all'immagine del pannello alla riga E, punto HL; mentre il DMA è occupato (la pulizia di un reset), disegnato da `pc_draw`. | |
| `pc_draw` | `pc_put`, `panel_init` | Le 8 righe di un carattere disegnate: i punti accesi nel colore B, gli altri 0 (buchi); i punti a sinistra di 0 non disegnati. | 700 in A |
| `pc_bank`, `pc_adr`, `pc_reg` | | Dove è stato disegnato un glifo; la pagina e l'indirizzo di una riga; un indirizzo DMA nei suoi registri. | |

## sound.asm, sound_gs.asm, gs_load.asm e gs/: il suono su una General Sound

Il `pokey_frame` del Next (i suoi campioni, gli impulsi, il contatore a 17 bit) gira sullo Z80
proprio della scheda a 12 MHz; il processore principale invia i registri di POKEY una volta per
fotogramma.

| routine | chiamata | cosa e come | A / B |
|---|---|---|---|
| `sound_driver` | `vbi` | Il driver dell'originale (come sul Next). | 840 / 1 000 |
| `snd_frame` | `main_frame` | Con una scheda nulla; altrimenti `ay_frame`. | |
| `snd_out` | `apply` | Con una scheda `gs_send`; altrimenti `ay_out`. | |
| `gs_send` | `snd_out` | Il comando `GS_FRAME` ($A5) alla porta $BB, poi AUDF1–4 e AUDC1–4 a $B3, ciascuno quando la scheda ha letto il precedente (`gs_wait_c`: bit 0 di $BB azzerato; `gs_wait_d`: bit 7). Un timeout (~0,2 s): la scheda viene lasciata (`gs_on` 0), da lì l'AY. Gran parte del suo tempo è attesa della scheda. | 2 400 / 2 400 |
| `gs_load` | `start` (INIT_PAGE) | Comando $F0 (lo stato del firmware): nessuna risposta, nessuna scheda; `GS_READY` ($5A) il programma c'è da un'esecuzione precedente, si prosegue con quello. Altrimenti attraverso il firmware: #12 pagina 2 a $8000, #18 l'indirizzo, #19/#1B i byte del programma (`gs_prog`: `build/gs_pokey.bin` con incbin), #13 un salto a `GS_ORG` ($8400), poi si aspetta `GS_READY` (il programma prima fa le sue tabelle). `gs_on` = 1. | una volta |

Il programma della scheda, `gs/gs_pokey.asm` (costruito a parte in `build/gs_pokey.bin`):

| routine | cosa e come |
|---|---|
| `gs_start` | IM 2 (tutti i vettori a `INT_AT` $4141, il gestore copiato lì), le variabili azzerate, $6000–$63FF ogni byte il proprio valore (una lettura a $6000 + 256 (n − 1) + v aggancia v nel DAC n), tutti e quattro i volumi a 63; `poly_make`, `tables_make`, l'anello silenzioso, `GS_READY` in uscita. |
| `main` | Aspetta un comando: $F4 (`GS_RESET`) DI, IM 1, JP 0 (di nuovo il firmware); $F0 (`GS_STATE`) `GS_READY` in risposta; qualsiasi altro gli 8 byte di dati in `pokey_audf`/`pokey_audc`, poi `pokey_frame`. |
| `gs_int` | L'interrupt della scheda, 37 500 al secondo: un DDA (`DDA_STEP` 108 su 256) prende un campione dall'anello 15 820 volte al secondo e lo aggancia in tutti e quattro i DAC (`ld a,(hl)` da $6000, $6100, $6200, $6300 + livello): 1 e 2 a sinistra, 3 e 4 a destra, ogni lato la somma dei suoi due. |
| `poly_make` | I bit del contatore a 17 bit di POKEY in $C000–$FFFF (16K), dalla ricorrenza q(k) = q(k−9) ^ q(k−11) ^ q(k−12) ^ q(k−17) e dai suoi valori iniziali; il Next li legge da `poly17.bin` (nel programma della scheda non c'è posto per 16K). |
| `tables_make` | `snd_tables`, `snd_mod15/31`, `g4_tab` (come il `sound_init7` del Next). |
| `pokey_frame`, `snd_fill`, `snd_sum` | Quelli del Next, senza l'AY, lo zxnDMA e il limite di tempo, e a 4 per passo di volume, non 8: qui ci sono tutti e quattro i canali (sul Next i toni li prendono gli AY), fino a 60 × 4 = 240; a 8 superavano 255 quando le esplosioni si sommavano (un sibilo), e i due DAC per lato rendono lo stesso volume. Inoltre: i campioni davanti al posto dell'interrupt (`rp`) fino a `SND_LEAD`, al massimo `SND_CAP`, oltre a essi l'ultimo livello tenuto (`SND_HOLD`). |
| `gs_pulses.asm`, `gs_handlers.asm` | `sound_pulses.asm`, `sound_handlers.asm` del Next: il puntatore del contatore a 17 bit si riavvolge a $C0 (i suoi 16K a $C000), e niente `mul`. |

La sua memoria: $4000 i vettori, $4141 il gestore, da $4200 le variabili, `snd_tables` a $4300,
`snd_mod15/31` a $4400/$4500, `g4_tab` che finisce a $4800, lo stack sotto $6000; pagina 2 a
$8000: l'anello $8000–$83FF, il programma da $8400; $C000 i bit del contatore a 17 bit.

## sound_ay.asm: i toni puri senza scheda

| routine | chiamata | cosa e come | A |
|---|---|---|---|
| `ay_frame` | `snd_frame` | Come sul Next: i canali di POKEY che suonano un tono puro, ciascuno su un canale AY (1 la A del secondo chip, 2 la sua B, 3 la B del primo, 4 la sua C), N = (AUDF + 1) × 3,454 con addizioni (`3a + round(a × 116 / 256)`, niente `mul`), il volume tramite `ay_vol`; in `ay_regs`. Non in ritardo di 2 fotogrammi: senza un DAC con cui tenere il passo, `apply` manda fuori quelli di questo fotogramma. | 1 100 |
| `ay_out` | `snd_out` | I registri 0–10 dei due chip (la porta $FFFD sceglie chip e registro, $BFFD il valore). | 2 100 (+ 600 `ay_clear`) |
| `ay_quiet` | `start` | Tutto silenzioso. | |

## load_rom.asm (INIT_PAGE, build SPG): la cartuccia dalla scheda SD

Wild Commander avvia il .spg senza cartella e senza DOS, quindi il programma legge la scheda da sé
attraverso lo Z-controller (porta $77 bit 1 il suo /CS, porta $57 un byte in ciascun senso). Il
buffer del settore è SPANS (rifatto dopo l'avvio).

| routine | cosa e come |
|---|---|
| `load_rom` | `sd_init`, la prima partizione del MBR (o la scheda stessa senza tabella delle partizioni: `lr_bpb`), i valori del volume FAT, `lr_search` dalla radice; i cluster del file letti a $A000 (8192 byte). Senza, `lr_fail`: la voce 1 della CRAM rossa e BORDER 1, poi uno stop. |
| `sd_init`, `sd_cmd`, `sd_read` | Modalità SPI (CMD0, CMD8, CMD55 + ACMD41, CMD58: indirizzi a blocchi SDHC, altrimenti CMD16 512 e indirizzi a byte, `lr_hc`), un settore di 512 byte. |
| `lr_bpb` | Un settore di avvio: FAT16 o FAT32, settori per cluster, gli indirizzi di FAT, radice e dati. |
| `lr_search`, `lr_get`, `lr_advance`, `lr_rewind` | Le voci di una cartella in fila (la radice fissa di FAT16 o una catena di cluster); prima i file, poi le cartelle, in profondità, fino a 8 livelli (`lr_save`/`lr_restore` mettono da parte il percorso). |
| `lr_lfn`, `lr_name`, `lr_upper` | Il nome lungo dalle sue voci LFN (13 caratteri ciascuna), confrontato con RIVER_RAID.ROM in qualunque maiuscolo/minuscolo; altrimenti il nome corto RIVER_~1.ROM. |
| `lr_next`, `lr_clus_lba` | La catena di cluster dalla FAT (16 o 32 bit); il primo settore di un cluster. |

## Include e strumenti

- `palette_ts.inc`: colore Atari → parola CRAM (5 bit per componente, livelli 0–24), i colori PAL del port in C++ (`make palette`: `tools/mkpalette_ts`).
- `vars.inc`, `font.inc`, `random.inc`: quelli del Next.
- `gs/poly.inc`: le sequenze a 4 e 5 bit di POKEY (`tools/mkpoly`).
- `tools/mkspg.py`: il file SPG 1.0 dalle pagine (`spg_page2/6/5/3.bin`): $8000–$9FFF, $C000–$FFFF, il font, il codice di INIT_PAGE.
- `tools/tscheck.cpp`: il core TSConf di Xpeccy+ (e la sua General Sound) accanto al port in C++, a ogni fotogramma.

## Cose da sapere prima di modificare il codice

- **Il codice in comune**: una modifica al gioco (logica, generatore, display, collisioni) va prima nel port in C++, poi nello `src/` del Next, poi nella copia qui (`diff ../src/X.asm src/X.asm` mostra solo le modifiche elencate sopra). Una modifica a come TS-Conf lo mostra resta qui.
- **La finestra 1** è WORK_PAGE tranne mentre `render_line`, `panel_draw` o l'avvio vi mappano un'altra pagina; ciascuno rimette WORK_PAGE (lì vivono SPANS e i buffer).
- **La finestra FM** a $E000 è sempre accesa: le scritture su $E000–$E3FF vanno nella CRAM e nello SFILE (e nella RAM sotto, ed è così che `apply` le rilegge); non metterci mai altro.
- **Gli eventi dell'interrupt** sono in due buffer (`ev_a`, `ev_b`): `build_events` scrive quello che `ev_show` non nomina; `apply` lo imposta sotto DI.
- **I registri presi a fine riga** (PALSEL, VPAGE, GYOFFS, GXOFFS): impostarli nell'interrupt della riga prima; l'interrupt arriva a HSINT 208 (il bordo destro), quindi a 3,5–14 MHz c'è tempo.
- **Il DMA** è condiviso dalla pulizia dell'immagine (`clear_layer2_page`) e dai caratteri del pannello (`pc_put`): `pc_put` disegna con il processore mentre il DMA è occupato; lo usano anche la copia dello SFILE (`sfile_put`) e i tratti lunghi di una nuova riga (`render_line`), ognuno col processore al suo posto mentre è occupato.
- **Le verifiche**: `make check` (3 000 fotogrammi; `FRAMES=`), e con un bot, `-stress`, TSBRIDGE, TSSPEED=1 (7 MHz), TSGS=neo o 0, come in [README.it.md](README.it.md). Dopo ogni modifica: lo stato, il colore della riva per riga (`ev_built`), i registri della General Sound e l'immagine della macchina di ogni fotogramma, pixel per pixel.
- **Misurare**: `TSHISTALL=file` (il tempo di ogni istruzione su tutta l'esecuzione, avvio, interrupt e attesa compresi), poi `python3 ../tools/prof.py build/test.sym file 60`; media e massimo del lavoro sono nelle ultime righe di tscheck. `TSMSHOT=k` scrive ogni fotogramma della macchina dal fotogramma k (32, anche il secondo di uno in ritardo); `TSBORDER=1` accende T; `TSSHOT=k` con `TSFULL=1` scrive i fotogrammi da k col bordo (l'ultima immagine di un'esecuzione mostra un solo colore sul bordo: l'esecuzione si ferma a `apply_done`). `TSTIME=N` stampa il lavoro dei fotogrammi N−2..N+2. `TSVOL=1`: le somme dei volumi di POKEY dei fotogrammi e il livello più alto della scheda (deve restare al massimo 255).
