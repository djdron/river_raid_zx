# El código fuente en ensamblador del port para TS-Conf, archivo por archivo

[English](CODE.md) | [Русский](CODE.ru.md) | [Українська](CODE.uk.md) | [Deutsch](CODE.de.md) | [Polski](CODE.pl.md) | [Italiano](CODE.it.md) | Español | [中文](CODE.zh.md) | [日本語](CODE.ja.md)

Para programadores de Z80 que quieran leer el código del port para TS-Conf o hacerlo más rápido.
El juego en sí (la lógica, el generador del río, la colocación de objetos y las colisiones) es el
código del Next, copiado en `src/`; [docs/CODE.es.md](../docs/CODE.es.md) describe esas rutinas, y
este documento solo dice cómo se cambiaron. Lo propio de TS-Conf (la imagen, el color de la orilla
por línea, los sprites, el panel, el sonido en una General Sound, el arranque desde una tarjeta
SD) se describe aquí rutina por rutina, con su coste. La visión general está en
[README.es.md](README.es.md).

## Las dos máquinas comparadas

El mismo juego, dos formas de mostrarlo. Qué difiere y dónde se ve en el código:

| | ZX Spectrum Next | TS-Conf (ZX Evolution) |
|---|---|---|
| Procesador | Z80N a 28 MHz (3,5 / 7 / 14 / 28), interrupciones desactivadas: el fotograma consultando la línea del raster | Z80 a 14 MHz (3,5 / 7 / 14), caché activada; la interrupción del fotograma, IM 2, desplazada por el fotograma de un evento al siguiente |
| Instrucciones Z80N | `nextreg`, `mul`, `bsla de,b`, `outinb`… | ninguna: un registro es `ld bc,puerto / out (c),a`; `bsla de,b` un bucle (`shl_de_b`, display_hits.asm); `mul` no hace falta (el periodo del AY con sumas) |
| Memoria | slots de 8K (MMU, NR $50–$57) | ventanas de 16K (PAGE0–PAGE3); la ventana 0 es RAM escribible (MEMCONFIG), así que la RAM del Atari está en $0000 |
| El río | Layer 2, 320×256, 8 bits, por columnas: una línea son 320 escrituras columna abajo, 10 páginas por turno | 16 colores, 320×240, una línea de la imagen de 256 bytes (2 puntos por byte): una línea son 160 bytes a lo largo de la línea, una página |
| Desplazamiento | NR $17, un anillo de 256 líneas | GYOFFS, un anillo de 512 líneas (`scroll` de 9 bits) |
| El color de la orilla por línea | el Copper: una lista de WAIT/MOVE, enviada cuando cambia | una paleta por color de orilla (PALSEL 0–7, CRAM); la interrupción del fotograma pone PALSEL una línea antes de un cambio (`build_events`, `irq`) |
| Sprites | 128 patrones de 16×16, 4 u 8 bits, escala ×2 ×4; un objeto es un sprite por cada 16 líneas | una única memoria de imágenes de 512×512 a 4 bits (SGPAGE), cualquier tamaño hasta 64×64, sin escala: cada imagen se guarda con 16, 32 y 64 puntos de ancho; un objeto es un sprite |
| Colores | NR $41 etc., 9 bits | la CRAM a través de la ventana FM en $E000 (`CRAM_SHADOW`): los colores y la lista de sprites (SFILE) en $E200 son simples escrituras en memoria |
| El panel y el rótulo desplazable | el tilemap sobre todo, su desplazamiento Y y X desde el Copper; el rótulo un anillo de tiles + un sprite en la unión | una imagen propia (256 colores, páginas 64–79) activada desde la línea 184 por la interrupción del fotograma (VPAGE, GYOFFS, VCONFIG con GFXOVR), sus caracteres dibujados una vez y copiados por el DMA; el rótulo un anillo de 32 caracteres en 512 puntos, GXOFFS puesto por la interrupción; la capa de tiles 0 el gris bajo los caracteres y el negro encima y debajo del río |
| Sonido | los ruidos que hace POKEY en un anillo, el zxnDMA al DAC (`pokey_frame` en el procesador principal, ~26 000–39 000 de sus ciclos a 28 MHz por fotograma); tonos puros en 3 AY | el Z80 propio de una General Sound reproduce todo POKEY (`gs/`); el procesador principal envía 8 bytes por fotograma (~3 400 con el controlador). Sin tarjeta: los tonos puros en los 2 AY del TurboSound |
| El cartucho | esxDOS: River_Raid.rom desde la carpeta del programa | código propio para SD y FAT16/FAT32: se recorre la tarjeta (Wild Commander no da carpeta) |
| TV | 50 o 60 Hz (CAPS + 1) | solo 50 Hz: el fotograma de la placa |
| Limpiar la imagen | PUSH, dos páginas del Layer 2 por fotograma | el relleno del DMA, media imagen por fotograma |
| Herramientas | `nxcheck` (núcleo del Next), `NXHISTALL` + `tools/prof.py` | `tscheck` (núcleo TSConf), `TSHISTALL` + `../tools/prof.py` |

## Las cifras

Los tiempos son ciclos del núcleo TSConf a 14 MHz (el reloj del procesador); un fotograma tiene
~286 800. Del histograma de tscheck (`TSHISTALL=archivo`, luego `python3 ../tools/prof.py
build/test.sym archivo 60`, dividido entre los fotogramas), sobre la compilación de verificación
(`-DTEST`: con la memoria de pantalla del Atari, que el juego no tiene: `line_done` y `draw_line`
pesan ~1 000–2 000 más que en el juego). Con una General Sound, así que los ruidos no le cuestan
nada al procesador principal. Dos ejecuciones:

- **A**: bot 1, 3 000 fotogramas desde el inicio: el trabajo ~69 000 por fotograma de media, como máximo ~120 000;
- **B**: `-stress` desde el puente 80, 6 000 fotogramas (`TSBRIDGE=80 TSGHOST=1 NXGAME=1 … -bot 1 -stress`: todos los slots ocupados, a toda velocidad, disparando siempre): ~108 000 de media, como máximo ~144 000.

El trabajo va de `apply_done` a `frame_done` (la espera de la interrupción del fotograma no se
cuenta); las partes de abajo cuentan también `apply` y las interrupciones (~7 000).

Por partes (A / B):

| parte | A | B |
|---|---|---|
| el display: colocación de objetos y colisiones (`display`, `ds_*`, `dh_*`, `sp_*`, `hit_*`) | 38 300 | 51 000 |
| líneas nuevas del río (`river_gen`, `render_line`, `span_line`, `line_done`, `push_line`) | 13 600 | 32 200 |
| sprites y los eventos de la orilla (`build_sprites`, `ob_*`, `pl_*`, `obj_lookup`, `sfile_put`, `build_events`, `pal_get`) | 10 300 | 14 900 |
| `apply`, el panel y las interrupciones (`apply`, `panel_frame`, `panel_draw`, `pc_*`, `pal_edges`, `irq`, la impresión del panel) | 7 900 | 7 500 |
| sonido (`sound_driver`, `snd_*`, `gs_*`; sin tarjeta `ay_*`: ~5 800 en A) | 3 400 | 3 500 |
| la lógica del juego y el resto (`move_objects`, `main_loop`, `random_step`, `vbi`, …) | 7 000 | 8 800 |

Las rutinas más costosas (A / B):

| rutina | A | B | archivo |
|---|---|---|---|
| `display` (código propio) | 11 200 | 12 900 | display_simple |
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
| `line_done` (la copia a la memoria de pantalla, solo compilación de verificación) | 1 100 | 2 500 | game |
| `gs_send` + `gs_wait_c` + `gs_wait_d` | 2 400 | 2 300 | sound_gs |
| `pl_keep` | 800 | 1 600 | sprites |
| `panel_frame` | 1 600 | 1 600 | panel_ts |
| `irq` | 1 400 | 1 400 | river_raid |
| `dh_lists` | 1 300 | 1 300 | display_hits |
| `sfile_put` | 1 200 | 1 300 | river_raid |
| `apply` (código propio) | 1 200 | 1 200 | river_raid |
| `pal_edges` | 1 100 | 1 100 | river_raid |
| `build_events` | 1 000 | 1 000 | river_raid |
| `hit_setup` | 500 | 700 | display_hits |

A 7 MHz (`TSSPEED=1`, ~143 400 ciclos por fotograma) el trabajo son las mismas instrucciones:
`-stress` ~93 000 de media, como máximo ~125 000, cabe justo; a 3,5 MHz no da. `gs_send` espera
a que la tarjeta lea cada byte (~300 ciclos por byte a 14 MHz).

(`prof.py` toma el nombre de una rutina de la etiqueta global más cercana por debajo de la
dirección. Las direcciones por debajo de $4000 son el trabajo del arranque en INIT_PAGE: déjalas
fuera.)

## La memoria mientras se ejecuta el código

Ventanas de 16K y las páginas que contienen (las páginas de 16K de la placa):

| ventana | dirección | normalmente | remapeada por |
|---|---|---|---|
| 0 | $0000–$3FFF | 1 (`ATARI_PAGE`): la RAM del Atari en las direcciones del original | al arrancar: 3 (`INIT_PAGE`: allí se ejecutan `sprite_pics.asm`, `gs_load.asm`, `load_rom.asm`) |
| 1 | $4000–$7FFF | 5 (`WORK_PAGE`): los tramos de las líneas desde $4000 (`SPANS`, 32 bytes × 256 líneas), búferes desde $6000 (`scan_*`, `edge_runs`, `ring_*`, `ds_objs`, `ov_exp2/4`, `eg_*`, `bg_*`, `line_*`, `edge_lo/hi`, `rnd_tab`), la fuente del sistema en $7D00 | `render_line`: una página de la imagen del río (32–47); `panel_draw`/`pc_*`: la imagen del panel (64–79); al arrancar el mapa de tiles (7), los tiles (8), las imágenes de los sprites (24–31); siempre se vuelve a poner la 5 |
| 2 | $8000–$BFFF | 2 (`CODE_PAGE`): código hasta ~$9F6F, el cartucho desde $A000 | — |
| 3 | $C000–$FFFF | 6 (`HIGH_PAGE`): código hasta ~$D7EC, luego en $E000 la ventana FM (`CRAM_SHADOW`: CRAM $E000–$E1FF, el SFILE $E200–$E3FF; las escrituras van también a la RAM de debajo), tablas y variables hasta ~$FD65, la pila, los vectores IM 2 en $FE00 | — |

Las imágenes: el río desde la página 32 (`VID_PAGE`, 16 páginas: 512 líneas de 512 bytes, de cada
una se muestran 320 puntos), el panel desde la página 64 (`VPANEL`), el mapa de tiles en la página
7, los puntos de los tiles en la página 8, los 512×512 puntos de los sprites en las páginas 24–31
(`SGPAGE`). El código de INIT_PAGE termina en ~$11DF, los búferes de la página de trabajo en
$7C00. La ventana FM está activa siempre: nada más puede usar $E000–$E3FF, y $E400–$E4FF son sus
registros (`palette_lo` está ahí, solo lectura).

## El fotograma

`main_frame` (river_raid.asm), en cada fotograma:

1. Una instantánea de lo que muestra la imagen de este fotograma (`scroll`, los colores del borde y del agua, el jugador), `read_input`.
2. Normalmente: `prepare` → `display` → `build_sprites` → `build_events` → `main_loop` → `vbi` → `snd_frame`. Durante un reinicio (`busy`): `display` → `build_sprites` → `build_events` → `clear_layer2_page` → (`finish_reset` en el último) → `vbi` → `snd_frame`.
3. `wait_frame`: HALT hasta que haya llegado la interrupción del fotograma (`frame_flag`), en `FRAME_LINE`, debajo del panel.
4. `apply`: todo lo construido se activa (el desplazamiento, el sonido, los colores, el SFILE, la paleta de la orilla arriba y los eventos de la interrupción para el fotograma que viene).
5. `panel_draw`: los caracteres del panel que han cambiado y los nuevos del rótulo desplazable, en su imagen (tras `apply`: puede tardar, y el panel solo se ve desde la línea 184).

Mientras se dibuja la imagen, la interrupción llega en cada evento de la lista que `apply` ha
preparado: EV_PAL (la paleta del río desde la línea siguiente), EV_PANEL (la imagen del panel
desde la línea 184), EV_GX (la X del rótulo desplazable), luego la del fotograma. Cada una llega
en el borde derecho de la línea anterior (HSINT = 208), y PALSEL, VPAGE, GYOFFS se toman al final
de una línea, así que un cambio es exacto a cualquier velocidad del procesador y esté donde esté
el trabajo.

---

## Los archivos del Next, tal como están aquí

Copiados de `../src`, el mismo código:

- `river_gen.asm`, `display_objs.asm`, `panel.asm`, `vars.inc`, `font.inc`, `random.inc`: sin cambios.
- `display.asm`, `display_simple.asm`, `spans.asm`: la página SPANS no se mapea (`nextreg $52,SPAN_PAGE` quitado: la ventana 1 tiene SPANS todo el tiempo); `spans.asm` sin `rl_fill`/`rl_next` (los ayudantes de `render_line` en el Next).
- `display_hits.asm`: `bsla de,b` (Z80N) como `shl_de_b`, un bucle de 0–7 `sla e / rl d` (en `hit_line`: hasta ~100 ciclos más por prueba, unos cientos por fotograma).
- `game.asm`: `tm_colour` escribe BORDER (una entrada de la CRAM: `TM_*` son las entradas libres del grupo 11 desde la 2, sus colores los pone `tm_cram`), y `TM_COLOUR` lo llama solo con T activado; `push_line` mueve `scroll` en un anillo de 512 líneas (9 bits) y dibuja en la línea de la imagen `scroll + RIVER_TOP`.
- `play.asm`: `clear_layer2_page` es el de TS-Conf (river_raid.asm, el DMA); `read_input` sin CAPS + 1 (no hay 60 Hz), CAPS + 2 (sonido apagado), CAPS + 3 (velocidad), el segundo Kempston y el mando de Mega Drive.
- `sound.asm`: solo `sound_driver` y `sound_random`: `pokey_frame` se ejecuta en la General Sound (`gs/`).
- `render.asm`, `sprites.asm`, `sound_ay.asm`, `load_rom.asm`, `river_raid.asm`: los propios de TS-Conf (abajo), con los nombres del Next donde hacen el mismo trabajo.

Las rutinas de los tres primeros grupos se describen en [docs/CODE.es.md](../docs/CODE.es.md);
su coste aquí está en la tabla de arriba.

## river_raid.asm: el fotograma, el arranque, la interrupción, los colores

El archivo principal: los puertos de la placa, la memoria, las páginas, los `include`, el
fotograma, la interrupción, `apply`, las paletas del río, variables y búferes.

| rutina | llamada | qué y cómo | A / B |
|---|---|---|---|
| `start` | al cargar | 14 MHz y la caché (SYSCONFIG $06), ventana 0 RAM (MEMCONFIG $0E), las páginas, `screen_black`, `load_rom` (compilación SPG), `init_tables`, `init_video`, las imágenes de los sprites (`obj_pics`, `pl_pics`, `panel_pics`), `gs_load`, luego la RAM del Atari en la ventana 0, `panel_init`, `ay_quiet`, la semilla de RANDOM, IM 2 (vectores en $FE00), `restart`. | una vez |
| `restart` | `start` | `tv_setup`, la imagen limpia (ambas mitades por el DMA, esperadas), la interrupción del fotograma en `FRAME_LINE`, `start_attract`, el panel dibujado entero, cae en `main_frame`. | una vez |
| `main_frame` | cada fotograma | Ver *El fotograma*. | 340 / 340 |
| `wait_frame` | `main_frame` | HALT hasta la siguiente INT del fotograma (`frame_flag` puesto a cero antes: una llegada durante el trabajo es tarde para `apply`): ocio, no trabajo. | — |
| `irq` | la interrupción | El evento en `ev_ptr`: EV_PAL PALSEL; EV_PANEL VPAGE = `VPANEL`, GYOFFS = 0, VCONFIG $8A (256 colores, el mapa de bits sobre tiles y sprites); EV_GX GXOFFS; el del fotograma (EV_END) `frame_flag`. Los eventos en la misma línea se hacen juntos; luego VSINT puesto en la línea del siguiente (`vsint_set`), o en la del fotograma. En el evento del fotograma vuelve a poner también los registros de la imagen y los eventos de `apply` (`river_regs`, `ap_pal`, `ev_go` desde `ap_list`): un fotograma tardío muestra el último otra vez. | 1 400 / 1 400 |
| `vsint_set` | `irq`, `apply`, `restart` | VSINT = HL (9 bits), guardado en `ev_line`. | 340 / 330 |
| `apply` | tras `wait_frame` | GYOFFS = `show_scroll`, VPAGE la del río, VCONFIG $81 (16 colores), GXOFFS 0; `snd_out` (los registros del AY o el fotograma de la tarjeta); `panel_frame`; los colores del proyectil y del avión en la CRAM; `sfile_put`; mientras la imagen se limpia tras un reinicio (desde su segundo fotograma): el río en negro (paleta del color 0, borde y agua 0, solo los eventos del panel); si no, PALSEL la paleta de arriba (`ev_built`), `pal_edges`, los eventos del panel copiados tras los de la orilla (`ev_tail`); la interrupción puesta en el primer evento (DI alrededor); `ev_show` = la lista recién puesta (`build_events` escribe la otra). | 1 200 / 1 200 |
| `pal_get` | `build_events`, `apply` | La paleta del río (PALSEL 0–7) del color Atari E: cada color de orilla tiene la suya, hecha la primera vez que aparece (`pal_of`, `pal_n`): su color 1 ese color, en la CRAM. Pasadas 8, otra vez la última (nunca ha pasado). | 110 / 110 |
| `pal_edges` | `apply` | Los colores 2 y 3 (borde, agua) de todas las paletas hechas hasta ahora. | 1 100 / 1 100 |
| `sfile_put` | `apply` | El SFILE, armado en `spr_list`: los sprites del río (S0), tras ellos se copia `sf_tail` (una entrada final con LEAP, los 3 del panel: aguja y logo, S1, un final); las entradas tras él hasta el final del fotograma anterior (`sf_end`) a cero allí mismo; luego el DMA lo copia al SFILE (DMACTRL $85, de RAM al SFILE, una sola ráfaga; la CPU solo lo programa). Mientras el DMA está ocupado (el borrado del reinicio) copia la CPU a través de la ventana FM en $E200. | 1 200 / 1 300 |
| `build_events` | `main_frame` | El color de la orilla por línea, como el `build_copper` del Next desde `ds_bank_ev`: en el búfer que no leen las interrupciones (`ev_a`/`ev_b`), la paleta en lo alto del río, luego un evento EV_PAL por cada cambio, 5 bytes (tipo, paleta, color para la verificación, línea VSINT una línea antes); `ev_tail` donde apply pone los dos del panel. | 1 000 / 1 000 |
| `clear_layer2_page` | `main_frame` durante `busy`, `restart` | Media imagen del río (256 líneas × 160 bytes, 4 páginas) por fotograma con el relleno del DMA (DMACTRL $14, 80 palabras × 256 líneas desde `dma_zero`); nada en el primer fotograma del reinicio (`l2_wait`); nada mientras el DMA está ocupado. El procesador solo lo programa (~150 ciclos). | |
| `dma_wait` | `restart`, `init_video` | Hasta que el DMA esté libre (DMACTRL bit 7). | |
| `init_tables` | `start` | Como las del Next (`edge_runs_init`, `ov_exp2/4`, `ring_*`, `span_class`, `edge_lo/hi`, `span_init`), `pix_tab` con el índice en ambos nibbles (los 2 puntos por byte del modo de 16 colores). | una vez |
| `init_video` | `start` | El modo del río (VPAGE 32, VCONFIG $81, PALSEL 0); el mapa de tiles (página 7: filas 0–23 tile 1 negro, 184 tile 3 una línea negra sobre el gris, 185–223 tile 2 gris, 224–239 negro; las filas del río ninguno) y los puntos de los tiles (página 8); los 128K de los sprites limpiados por el DMA; TSCONFIG $A0 (capa de tiles 0 y sprites activados); la ventana FM activada para siempre, CRAM y SFILE a cero; el color del tanque; HSINT, solo la interrupción del fotograma (INTMASK 1). | una vez |
| `screen_black` | lo primero en `start` | TSCONFIG 0, BORDER 0, todo el 1K de CRAM y SFILE a cero por la ventana FM: negro, sea cual sea el modo que dejó Wild Commander (su pantalla ZX en la página 5 es donde van los búferes del arranque). | una vez |
| `tv_setup` | `restart` | Solo PAL: `init_line_tables`, las columnas PAL de RANDOM, `rnd_tables`. | |
| `test_ghost` | compilaciones de prueba | TSGHOST de tscheck, como en el Next. | |

`span_rec` (HL = el registro de una línea en SPANS) es la misma macro que en el Next, en $4000.

## render.asm: una línea en la imagen

| rutina | llamada | qué y cómo | A / B |
|---|---|---|---|
| `render_line` | `line_done` | Los ciclos de color 20–179 de la línea en la línea de la imagen HL (0–511): la página `VID_PAGE` + línea / 64 en la ventana 1, la línea en $4000 + (línea & 63) × 256; a partir de las piezas de `dl_seg` como en el Next: una pieza de un solo valor es su byte de `pix_tab` 4 veces por byte (`.fill`: `ld (hl),a / inc l`), los bytes de un borde (la tabla de la ROM) y una fila de decoración a través de `pix_tab`, 4 bytes de salida cada uno. 160 escrituras por línea a lo largo de la línea (el Next escribe 320 columna abajo, 10 páginas). WORK_PAGE se vuelve a poner al final. Una pieza de un solo valor de 5 bytes o más (`RL_DMA_MIN`) va en cambio al DMA si está libre: un relleno (DMACTRL $04) desde `rl_word` (el valor dos veces) en la página `rl_page`. En la página $C000 (movida desde $8000 por espacio). | 3 500 / 8 400 |

## sprites.asm: los sprites del río

Los sprites de TS-Conf no tienen escala, así que cada imagen se guarda con 16, 32 y 64 puntos de
ancho (un píxel del Atari son 2 puntos; un player 8 píxeles con tamaño ×1, ×2, ×4). Un objeto es
un único sprite de hasta 24 filas (el Next hace uno por cada 16 filas). Paletas: objetos 14 y 15
(`OBJ_PAL_A`, `OBJ_PAL_B`, los colores de las filas en las posiciones 1–15), proyectil y misil 8,
tanque 9, avión y bala 10. Las entradas (6 bytes cada una, el formato del SFILE: Y con YS y ACT,
X con XS y los bits de reflejo, el tile y la paleta) van a `spr_list`; las copia `apply`.

| rutina | llamada | qué y cómo | A / B |
|---|---|---|---|
| `build_sprites` | `main_frame` | `ob_list`; luego el avión, su bala, el tanque, el misil del helicóptero, el proyectil (el orden en que los dibuja `drawRiver`) mediante `pl_pattern` + `pl_sprite`; `pl_keep`. Durante un reinicio `pl_again`. | 800 / 800 |
| `ob_list` | `build_sprites` | Por entrada de `ds_objs` con sus filas (`ds_objf`): `obj_lookup` a partir de las direcciones de forma y color de la fila superior; no encontrada: ningún sprite; primera fila bajo el río: ninguno; si no, `ob_attr`. | 2 400 / 3 100 |
| `obj_lookup` | `ob_list` | La imagen del byte de forma en $B900 + E y del byte de color en $B700 + D: `obj_head` (desde el byte de forma) y luego su cadena en `obj_e`; A = imagen + bit 7 para `OBJ_PAL_B`. | 1 000 / 1 300 |
| `ob_attr` | `ob_list` | La entrada del SFILE: Y = `RIVER_TOP` + la posición de su fila en el río (9 bits) con YS desde `pic_h` y ACT; X = 2 × (posición − 52) (9 bits) con XS 1, 3 o 7 según el tamaño; el tile del ancho adecuado (`pic_tn16/32/64_lo/hi`), la paleta. | 2 500 / 5 200 |
| `pl_pattern`, `pl_sprite` | `build_sprites` | La imagen del fotograma desde su tabla ($FF: ninguna); un sprite de 16 puntos de ancho en la línea D (ninguno bajo el río), posición E, paleta C. | ~100 por sprite |
| `pl_keep`, `pl_again` | `build_sprites` | Las entradas de los players guardadas; los fotogramas de un reinicio las vuelven a mostrar (como en el Next). | 800 / 1 600 |
| `cram_set` | el arranque, `init_video` | Entrada CRAM A × 16 + B = color Atari E (`palette_lo`). | |

## sprite_pics.asm (INIT_PAGE, al arrancar): las imágenes de los sprites

En la memoria de imágenes de 512×512 puntos (SGPAGE, 4 bits por punto, una fila 256 bytes) a
través de la ventana 1; los tiles de una imagen son de 8×8, numerados (fila / 8) × 64 + x / 8.

| rutina | llamada | qué y cómo |
|---|---|---|
| `gfx_alloc` | `pic_set`, `pl_pics`, `panel_pics` | Un sitio para una imagen de BC puntos de ancho y A filas de alto (un múltiplo de 8): a lo largo de las filas mientras quepa, luego en las filas siguientes (`gfx_cx`, `gfx_cy`, `gfx_rh`). |
| `gfx_tile` | | El número de tile de un punto. |
| `gfx_row` | | La fila C de una imagen: los puntos del byte D (bit 7 primero) en el color E en los tres anchos (2, 4, 8 puntos por bit), o solo el primero (B 1). |
| `obj_pics` | `start` | Como el `obj_pics` del Next: para los tipos 7–15 los tipos de aspecto que pueden tener (el suyo, los de `ROM_NEXT_KIND` por debajo de $0C, los de la explosión), cada uno también reflejado, height + 1 filas como las dibuja el DLI; cada imagen una vez (por sus direcciones) en los tres anchos; el valor de un punto la posición del color de su fila en la paleta 14 o 15 (puesto cuando es nuevo: `cram_set`); `obj_head`/`obj_e` para `obj_lookup`. |
| `pic_set` | `obj_pics` | Los tres tiles de la imagen `op_p` (en gfx_x, + 16, + 48) y su YS. |
| `pl_pics` | `start` | Los 10 fotogramas del avión, los 8 del tanque, los 7 del proyectil (desde sus tablas de punteros en la ROM, como `prepare` los copia), la bala y el misil del helicóptero: 16 puntos de ancho, color 1; una imagen por dirección, $FF para un fotograma vacío. |
| `panel_pics` | `start` | La aguja (misil 1: 2 ciclos de color, 10 filas) y el logo: player 3 en 64 puntos (datos $FC), player 2 (datos $FF) un ciclo más a la izquierda en cada fila (7 filas en 32 puntos). |

## panel_ts.asm: el panel y el rótulo desplazable

El panel es una imagen propia (páginas 64–79, 256 colores, 512 bytes por línea), mostrada desde
la línea de pantalla 184 (EV_PANEL de la interrupción del fotograma) con el mapa de bits sobre
tiles y sprites (GFXOVR): sus puntos a 0 son agujeros, que dejan ver la capa de tiles 0 (el gris,
el negro) y los sprites del panel. Colores 4–7 los PF0–PF3 del panel, 8 el del rótulo
desplazable. El rótulo es un anillo de 32 caracteres en los 512 puntos de la imagen, mostrado
mediante GXOFFS (EV_GX en su primera línea).

| rutina | llamada | qué y cómo | A / B |
|---|---|---|---|
| `panel_init` | `start` | Los dos juegos de caracteres del Atari en su RAM donde los construye el juego (A0FB–A143: el del rótulo en $0600, el del panel en $0800); los colores (CRAM: los de los caracteres como entradas 4–8 de la paleta 0, el de la aguja, las filas del logo desde $B48D, el negro y el gris de los tiles como entradas 14 y 15 de la paleta 3: una paleta del río solo usa las entradas 0–3); los caracteres dibujados una vez (`GLYPHS`: los del rótulo, los del panel en sus 4 colores) para que `pc_put` los copie; la imagen del panel limpia; todo marcado para escribirse en el primer fotograma. | una vez |
| `panel_frame` | `apply` | La X del rótulo (`pf_gx` = 16 TEXT_LO + 38 − 2 FINE_SCROLL, 9 bits) para el EV_GX de la interrupción; la aguja (misil 1 en fuel / 8 + $5C) y los dos sprites del logo en `spr_s1` (`.spr`). | 1 600 / 1 600 |
| `panel_draw` | tras `apply` | Los caracteres que `panel_put` ha enumerado (`pf_dirty`, los 60 tras una copia) mediante `panel_frame.char`; el rótulo: cuando TEXT_LO avanza uno, su carácter 24 más allá; cuando salta, los 25 (`panel_frame.text`: el carácter t en el punto 16 t mod 512 del anillo). | 160 / 160 (+ `pc_*`) |
| `pc_put` | `.char`, `.text` | Un carácter copiado por el DMA desde donde se dibujó una vez (`pc_bank`) a la imagen del panel en la fila E, punto HL; mientras el DMA está ocupado (la limpieza de un reinicio), dibujado por `pc_draw`. | |
| `pc_draw` | `pc_put`, `panel_init` | Las 8 filas de un carácter dibujadas: los puntos encendidos en el color B, los demás 0 (agujeros); los puntos a la izquierda de 0 no se dibujan. | 700 en A |
| `pc_bank`, `pc_adr`, `pc_reg` | | Dónde se dibujó un glifo; la página y la dirección de una fila; una dirección de DMA en sus registros. | |

## sound.asm, sound_gs.asm, gs_load.asm y gs/: el sonido en una General Sound

El `pokey_frame` del Next (sus muestras, los pulsos, el contador de 17 bits) se ejecuta en el Z80
propio de la tarjeta a 12 MHz; el procesador principal envía los registros de POKEY una vez por
fotograma.

| rutina | llamada | qué y cómo | A / B |
|---|---|---|---|
| `sound_driver` | `vbi` | El controlador del original (como en el Next). | 840 / 1 000 |
| `snd_frame` | `main_frame` | Con tarjeta, nada; si no, `ay_frame`. | |
| `snd_out` | `apply` | Con tarjeta `gs_send`; si no, `ay_out`. | |
| `gs_send` | `snd_out` | El comando `GS_FRAME` ($A5) al puerto $BB, luego AUDF1–4 y AUDC1–4 a $B3, cada uno cuando la tarjeta ha leído el anterior (`gs_wait_c`: bit 0 de $BB a cero; `gs_wait_d`: bit 7). Un tiempo agotado (~0,2 s): se abandona la tarjeta (`gs_on` 0), desde entonces el AY. La mayor parte de su tiempo es esperar a la tarjeta. | 2 400 / 2 400 |
| `gs_load` | `start` (INIT_PAGE) | Comando $F0 (el estado del firmware): sin respuesta, no hay tarjeta; `GS_READY` ($5A) el programa ya está de una ejecución anterior, se sigue con él. Si no, a través del firmware: #12 página 2 en $8000, #18 la dirección, #19/#1B los bytes del programa (`gs_prog`: `build/gs_pokey.bin` con incbin), #13 un salto a `GS_ORG` ($8400), luego se espera `GS_READY` (el programa primero hace sus tablas). `gs_on` = 1. | una vez |

El programa de la tarjeta, `gs/gs_pokey.asm` (compilado aparte en `build/gs_pokey.bin`):

| rutina | qué y cómo |
|---|---|
| `gs_start` | IM 2 (todos los vectores a `INT_AT` $4141, el manejador copiado allí), las variables a cero, $6000–$63FF cada byte su propio valor (una lectura en $6000 + 256 (n − 1) + v fija v en el DAC n), los cuatro volúmenes a 63; `poly_make`, `tables_make`, el anillo en silencio, `GS_READY` a la salida. |
| `main` | Espera un comando: $F4 (`GS_RESET`) DI, IM 1, JP 0 (otra vez el firmware); $F0 (`GS_STATE`) `GS_READY` como respuesta; cualquier otro los 8 bytes de datos en `pokey_audf`/`pokey_audc`, luego `pokey_frame`. |
| `gs_int` | La interrupción de la tarjeta, 37 500 por segundo: un DDA (`DDA_STEP` 108 de 256) toma una muestra del anillo 15 820 veces por segundo y la fija en los cuatro DAC (`ld a,(hl)` desde $6000, $6100, $6200, $6300 + nivel): 1 y 2 a la izquierda, 3 y 4 a la derecha, cada lado la suma de sus dos. |
| `poly_make` | Los bits del contador de 17 bits de POKEY en $C000–$FFFF (16K), a partir de la recurrencia q(k) = q(k−9) ^ q(k−11) ^ q(k−12) ^ q(k−17) y sus valores iniciales; el Next los lee de `poly17.bin` (en el programa de la tarjeta no hay sitio para 16K). |
| `tables_make` | `snd_tables`, `snd_mod15/31`, `g4_tab` (como el `sound_init7` del Next). |
| `pokey_frame`, `snd_fill`, `snd_sum` | Los del Next, sin el AY, el zxnDMA y el límite de tiempo, y a 4 por paso de volumen, no 8: aquí están los cuatro canales (en el Next los tonos los toman los AY), hasta 60 × 4 = 240; a 8 pasaban de 255 cuando las explosiones se sumaban (un siseo), y los dos DAC por lado dan el mismo volumen. Además: las muestras por delante de la posición de la interrupción (`rp`) hasta `SND_LEAD`, como máximo `SND_CAP`, más allá se mantiene el último nivel (`SND_HOLD`). |
| `gs_pulses.asm`, `gs_handlers.asm` | `sound_pulses.asm`, `sound_handlers.asm` del Next: el puntero del contador de 17 bits da la vuelta en $C0 (sus 16K en $C000), y sin `mul`. |

Su memoria: $4000 los vectores, $4141 el manejador, desde $4200 las variables, `snd_tables` en
$4300, `snd_mod15/31` en $4400/$4500, `g4_tab` que termina en $4800, la pila por debajo de $6000;
página 2 en $8000: el anillo $8000–$83FF, el programa desde $8400; $C000 los bits del contador de
17 bits.

## sound_ay.asm: los tonos puros sin tarjeta

| rutina | llamada | qué y cómo | A |
|---|---|---|---|
| `ay_frame` | `snd_frame` | Como en el Next: los canales de POKEY que tocan un tono puro, cada uno en un canal AY (1 la A del segundo chip, 2 su B, 3 la B del primero, 4 su C), N = (AUDF + 1) × 3,454 con sumas (`3a + round(a × 116 / 256)`, sin `mul`), el volumen mediante `ay_vol`; en `ay_regs`. Sin el retraso de 2 fotogramas: sin un DAC al que seguir, `apply` envía los de este fotograma. | 1 100 |
| `ay_out` | `snd_out` | Los registros 0–10 de los dos chips (el puerto $FFFD elige chip y registro, $BFFD el valor). | 2 100 (+ 600 `ay_clear`) |
| `ay_quiet` | `start` | Todo en silencio. | |

## load_rom.asm (INIT_PAGE, compilación SPG): el cartucho desde la tarjeta SD

Wild Commander arranca el .spg sin carpeta y sin DOS, así que el programa lee la tarjeta por sí
mismo a través del Z-controller (puerto $77 bit 1 su /CS, puerto $57 un byte en cada sentido). El
búfer del sector es SPANS (rehecho tras el arranque).

| rutina | qué y cómo |
|---|---|
| `load_rom` | `sd_init`, la primera partición del MBR (o la propia tarjeta sin tabla de particiones: `lr_bpb`), los valores del volumen FAT, `lr_search` desde la raíz; los clústeres del archivo leídos en $A000 (8192 bytes). Sin él, `lr_fail`: la entrada 1 de la CRAM en rojo y BORDER 1, luego una parada. |
| `sd_init`, `sd_cmd`, `sd_read` | Modo SPI (CMD0, CMD8, CMD55 + ACMD41, CMD58: direcciones por bloque SDHC, si no CMD16 512 y direcciones por byte, `lr_hc`), un sector de 512 bytes. |
| `lr_bpb` | Un sector de arranque: FAT16 o FAT32, sectores por clúster, las direcciones de la FAT, la raíz y los datos. |
| `lr_search`, `lr_get`, `lr_advance`, `lr_rewind` | Las entradas de una carpeta en orden (la raíz fija de FAT16 o una cadena de clústeres); primero los archivos, luego las carpetas, en profundidad, hasta 8 niveles (`lr_save`/`lr_restore` guardan el camino). |
| `lr_lfn`, `lr_name`, `lr_upper` | El nombre largo a partir de sus entradas LFN (13 caracteres cada una), comparado con RIVER_RAID.ROM sin distinguir mayúsculas; si no, el nombre corto RIVER_~1.ROM. |
| `lr_next`, `lr_clus_lba` | La cadena de clústeres desde la FAT (16 o 32 bits); el primer sector de un clúster. |

## Includes y herramientas

- `palette_ts.inc`: color Atari → palabra CRAM (5 bits por componente, niveles 0–24), los colores PAL del port en C++ (`make palette`: `tools/mkpalette_ts`).
- `vars.inc`, `font.inc`, `random.inc`: los del Next.
- `gs/poly.inc`: las secuencias de 4 y 5 bits de POKEY (`tools/mkpoly`).
- `tools/mkspg.py`: el archivo SPG 1.0 a partir de las páginas (`spg_page2/6/5/3.bin`): $8000–$9FFF, $C000–$FFFF, la fuente, el código de INIT_PAGE.
- `tools/tscheck.cpp`: el núcleo TSConf de Xpeccy+ (y su General Sound) junto al port en C++, en cada fotograma.

## Lo que conviene saber antes de cambiar el código

- **El código común**: un cambio en el juego (lógica, generador, display, colisiones) va primero al port en C++, luego al `src/` del Next, luego a la copia de aquí (`diff ../src/X.asm src/X.asm` muestra solo los cambios enumerados arriba). Un cambio en cómo lo muestra TS-Conf se queda aquí.
- **La ventana 1** es WORK_PAGE salvo mientras `render_line`, `panel_draw` o el arranque mapean otra página en ella; cada uno vuelve a poner WORK_PAGE (allí viven SPANS y los búferes).
- **La ventana FM** en $E000 está siempre activa: las escrituras en $E000–$E3FF van a la CRAM y al SFILE (y a la RAM de debajo, que es como `apply` las relee); no pongas nunca otra cosa ahí.
- **Los eventos de la interrupción** están en dos búferes (`ev_a`, `ev_b`): `build_events` escribe el que no nombra `ev_show`; `apply` lo activa con DI.
- **Los registros tomados al final de la línea** (PALSEL, VPAGE, GYOFFS, GXOFFS): ponlos en la interrupción de la línea anterior; la interrupción llega en HSINT 208 (el borde derecho), así que a 3,5–14 MHz hay tiempo.
- **El DMA** lo comparten la limpieza de la imagen (`clear_layer2_page`) y los caracteres del panel (`pc_put`): `pc_put` dibuja con el procesador mientras el DMA está ocupado; también lo usan la copia del SFILE (`sfile_put`) y los tramos largos de una línea nueva (`render_line`), cada uno con el procesador en su lugar mientras está ocupado.
- **Las verificaciones**: `make check` (3 000 fotogramas; `FRAMES=`), y con un bot, `-stress`, TSBRIDGE, TSSPEED=1 (7 MHz), TSGS=neo o 0, como en [README.es.md](README.es.md). Tras cada cambio: el estado, el color de la orilla por línea (`ev_built`), los registros de la General Sound y la imagen de la máquina de cada fotograma, píxel a píxel.
- **Medir**: `TSHISTALL=archivo` (el tiempo de cada instrucción en toda la ejecución, arranque, interrupciones y espera incluidos), luego `python3 ../tools/prof.py build/test.sym archivo 60`; la media y el máximo del trabajo están en las últimas líneas de tscheck. `TSBORDER=1` activa T; `TSSHOT=k` con `TSFULL=1` escribe los fotogramas desde k con el borde (la última imagen de una ejecución muestra un solo color en el borde: la ejecución se detiene en `apply_done`). `TSTIME=N` imprime el trabajo de los fotogramas N−2..N+2. `TSVOL=1`: las sumas de los volúmenes de POKEY de los fotogramas y el nivel más alto de la tarjeta (debe quedarse en 255 como máximo).
