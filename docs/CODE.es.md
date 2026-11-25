# El código fuente en ensamblador del port para ZX Spectrum Next, archivo por archivo

[English](CODE.md) | [Русский](CODE.ru.md) | [Українська](CODE.uk.md) | [Deutsch](CODE.de.md) | [Polski](CODE.pl.md) | [Italiano](CODE.it.md) | Español | [中文](CODE.zh.md) | [日本語](CODE.ja.md)

Para programadores de Z80 que quieran leer el código o hacerlo más rápido. Para cada archivo: qué
contiene, qué hace cada rutina, quién la llama y cuándo, cómo funciona y cuánto cuesta. El porqué
de las decisiones está en [NOTES.es.md](NOTES.es.md) y [HANDOFF.es.md](../HANDOFF.es.md); la
visión general en palabras sencillas, en [HOW_IT_WORKS.es.md](HOW_IT_WORKS.es.md).

Este es el código del Next (`src/`). El port para TS-Conf ([tsconf/CODE.es.md](../tsconf/CODE.es.md))
usa una copia de su parte de juego: `play.asm`, `game.asm`, `river_gen.asm`, `spans.asm`, los
archivos `display*.asm`, `panel.asm` y `sound_driver` se describen aquí para ambos (los pocos
cambios de TS-Conf se enumeran allí); el resto de aquí, la imagen, los sprites, el Copper, el
panel, el sonido por el DAC, el arranque, es propio del Next. Una tabla de las diferencias entre
las dos máquinas está al principio de tsconf/CODE.es.md. El hardware propio del Next tal como lo
usa este código: instrucciones Z80N (`nextreg`, `mul`, `bsla`), slots de 8K, Layer 2 por
columnas, el Copper, el tilemap, sprites con escala, zxnDMA y DAC, tres AY, 50 y 60 Hz.

## Las cifras

Los tiempos son ciclos del núcleo del Next a 28 MHz por fotograma, en promedio, del histograma
de nxcheck (`NXHISTALL=archivo`, luego `python3 tools/prof.py build/test.sym archivo 60`,
dividido entre los fotogramas), sobre la compilación de verificación sin memoria de pantalla,
como la tiene el juego (`-DNOSCREEN`, `NXNOSCREEN=1`). Dos ejecuciones:

- **A**: PAL, bot 1, 3 000 fotogramas desde el inicio (el comienzo habitual de una partida): ~102 000 por fotograma de media, como máximo ~158 000;
- **B**: `-stress` desde el puente 80, PAL, 6 000 fotogramas (`NXBRIDGE=80 NXGHOST=1 NXGAME=1`: todos los slots ocupados, a toda velocidad, disparando siempre): ~159 000 de media, como máximo ~198 000 (NTSC ~160 000 / ~202 000; a 14 MHz NTSC ~131 000 / ~165 000 de ~240 000).

Un fotograma tiene ~567 000 ciclos en PAL y ~481 000 en NTSC (la mitad a 14 MHz). `apply` (y
con ella `panel_frame`) se ejecuta tras el trabajo medido (debajo del rótulo desplazable) y no
está en estas cifras: ~7 400 por fotograma. El tiempo de una rutina son solo sus propias
instrucciones: las rutinas a las que llama se cuentan bajo su propio nombre.

Por partes (A / B):

| parte | A | B |
|---|---|---|
| el display: colocación de objetos y colisiones (`display_simple`, `display_objs`, `display_hits`, `sp_*`) | 40 400 | 54 300 |
| sonido (`pokey_frame`, `snd_*`, `pk_*`, `ay_*`, `sound_driver`) | 26 900 | 39 300 |
| líneas nuevas del río (`river_gen`, `render_line`, `rl_fill`, `span_line`, `push_line`) | 19 500 | 45 400 |
| sprites y la lista del Copper (`build_sprites`, `ob_*`, `pl_*`, `build_copper`) | 9 900 | 15 000 |
| la lógica del juego y el resto (`prepare`, `main_loop`, `move_objects`, `random_step`, la impresión del panel, …) | 9 400 | 10 500 |

Las rutinas más costosas (A / B):

| rutina | A | B | archivo |
|---|---|---|---|
| `display` (código propio) | 10 900 | 12 600 | display_simple |
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
| `pokey_frame` (código propio) | 2 500 | 2 700 | sound |
| `draw_line` | 900 | 2 300 | river_gen |
| `pk_g4` | 0 | 1 400 (~9 000 en un fotograma en que suena el misil) | sound_pulses |
| `dh_lists` | 1 300 | 1 300 | display_hits |
| `hit_setup` | 500 | 700 | display_hits |

El fotograma más pesado de B (~198 000): el sonido hasta ~60 000 (el ruido y el misil por el
DAC, ~180 pulsos), la colocación y las pruebas del borde (`display`, `ds_obj`, `ds_edge_test`)
~30 000, las colisiones (`dh_pf`, `dh_bits`, `dh_obj`, `hit_*`) ~25 000, las líneas nuevas del
río ~25 000.

(`prof.py` toma el nombre de una rutina de la etiqueta global más cercana por debajo de la
dirección, así que una etiqueta de datos justo antes del código puede quedarse con su tiempo;
los símbolos de la página 12 en $6000-$7FFF corresponden a `panel_init` en la página 7 en las
mismas direcciones, que se ejecuta una vez al arrancar.)

## La memoria mientras se ejecuta el código

Slots de 8K ($0000, $2000, … $E000) y las páginas que contienen:

| slot | dirección | normalmente | remapeado por |
|---|---|---|---|
| 0–1 | $0000–$3FFF | 30–31: la RAM del Atari en las direcciones del original | `pokey_frame`: 14–15, el contador de 17 bits de POKEY (`poly17.bin`), mientras genera las muestras |
| 2 | $4000–$5FFF | variable: ninguna página fija | `render_line`: 18–27 (Layer 2, una página por cada 32 columnas); `display`, `span_line`, `spans_clear`: 28 (`SPAN_PAGE`, los tramos de las líneas); `panel_frame`: 11 (el mapa del tilemap); `panel_init`: 10, 11 |
| 3 | $6000–$7FFF | 12: búferes (`copper_list`, `ds_objs`, `sprite_list`, `ov_exp2`/`ov_exp4` (los puntos de un byte ensanchados, `dh_obj`), los huecos del borde `eg_*` (`ds_edge_test`), el anillo del DAC en $7C00) | solo al arrancar: 7 (`panel_init`, `sound_init7`, `load_rom`). **Nunca mientras suena el sonido**: el DMA lee el anillo a través de este slot |
| 4 | $8000–$9FFF | 4: código | — |
| 5 | $A000–$BFFF | 5: el cartucho, leído de River_Raid.rom | — |
| 6 | $C000–$DFFF | 6: código | — |
| 7 | $E000–$FFFF | 1: variables, tablas (entre ellas los huecos de la orilla `bg_*`), la pila (desde $0000 hacia abajo hasta por encima de $FF00) | — |

La página 4 termina en ~$9E2C (de $A000), la 6 en ~$DD53 (de $E000), la 7 en ~$6913 (la
compilación lo imprime): el horario del DLI eliminado dejó algo de espacio. Mover código entre
páginas es como se encontró espacio antes (`display_objs.asm` estaba en el hueco antes de la
alineación de la paleta en la página 4, ahora al final).

Las interrupciones están siempre desactivadas (`di` al arrancar): el fotograma se marca
consultando la línea del raster (`wait_frame`), el sonido lo lleva el DMA, los colores por línea
el Copper.

## El fotograma

`main_frame` (river_raid.asm), en cada fotograma:

1. Una instantánea de lo que muestra la imagen de este fotograma (`scroll`, los colores del borde y del agua, el jugador), `read_input`, CAPS + 1 (`restart` en el otro estándar).
2. Normalmente: `prepare` → `display` → `build_sprites` → `main_loop` → `vbi`. Durante un reinicio (`busy`, los fotogramas en que el original limpia la memoria: 13 NTSC, 8 PAL): `display` → `build_sprites` → `clear_layer2_page` → (`finish_reset` en el último) → `vbi`.
3. `pokey_frame`: las muestras del fotograma en el anillo del DAC y los tonos del AY.
4. `wait_frame`: consulta la línea de vídeo activa (NR $1E/$1F) hasta `wait_line` (208 NTSC, 220 PAL), debajo del rótulo desplazable, donde en pantalla no cambia nada.
5. `apply`: todo lo construido se activa a la vez (desplazamiento y colores del Layer 2, los atributos de los sprites, los tiles del panel, la lista del Copper).

Con T activado (`tm_show`), cada una de estas partes pone primero el color del borde (`TM_COLOUR`: llama a `tm_colour` solo con T activado; apagado cuesta ~30 ciclos por parte): naranja `apply`, gris `prepare` (y `clear_layer2_page` durante un reinicio), rojo `display`, amarillo `build_sprites`, azul `main_loop`, magenta `push_line` (una línea nueva del río, dentro de `main_loop`), blanco `vbi`, cian `pokey_frame`, negro el tiempo que sobra. `push_line` pone magenta y luego de nuevo azul.

El orden importa: `display` usa el estado que dejó el `main_loop` del fotograma anterior (igual
que el DLI del Atari muestra el estado del fotograma anterior), y `build_sprites` usa lo que dejó
`display`.

---

## river_raid.asm: el fotograma, el arranque, la memoria

El archivo principal: disposición de la memoria, `include`, ensamblado de las páginas
(`mmu`/`org`), variables de la página 1 y búferes de la página 12, ganchos para las
compilaciones de prueba.

| rutina | llamada | qué y cómo |
|---|---|---|
| `start` | al cargar | `load_rom` (no en las compilaciones de prueba), RANDOM sembrado desde R, 28 MHz, mapea las páginas, `init_tables`, `init_video`, `panel_init` (página 7 mapeada), luego `restart`. |
| `restart` | `start`; CAPS + 1 | La máquina "encendida" en el estándar de `tv_pal`: `tv_setup`, Layer 2 limpio (las 10 páginas de una vez), `sound_init`, `start_attract`, cae en `main_frame`. |
| `main_frame` | cada fotograma | Ver *El fotograma*. ~340 ciclos propios. |
| `wait_frame` | `main_frame` | Espera activa sobre NR $1F frente a `wait_line`. Su tiempo es ocio, no trabajo. |
| `init_tables` | `start` | Una vez: las tablas: `ring_lo`/`ring_hi` (las 160 líneas de la memoria de pantalla en orden), `span_class` (el color de un byte si sus 4 píxeles son iguales), `span_init` (las máscaras), una lista del Copper vacía. |
| `tv_setup` | `restart` | Los ajustes del estándar: NR $05 50/60 Hz, `init_line_tables`, `wait_line`, el mapa aleatorio, la parte del panel del Copper (`copper_panel_ntsc`/`_pal` copiadas, el gris insertado, `COPPER_GREY`), el primer desplazamiento Y del tilemap, ventanas de recorte (Layer 2 hasta la última línea gris del panel, sprites, tilemap). |
| `init_video` | `start` | Borde negro, sin ULA, transparencia global $E3, Layer 2 de 320×256×8 en el banco 9, orden de capas (tilemap sobre sprites sobre Layer 2), las paletas: las 4 entradas del Layer 2, las 128–255 de los sprites = los colores del Atari, NR $15 con el recorte de sprites en modo sobre el borde. |
| `test_ghost` | compilaciones de prueba, tras `display` cuando `test_ghost_on` | NXGHOST de nxcheck: las colisiones del avión y el combustible ajustados para que no pueda estrellarse. |

Además: `span_rec` (macro: HL = el registro de 32 bytes de la línea del río A en SPAN_PAGE), la
`palette` (color Atari → color Next, 256 bytes) y `random_columns`, las variables `TEST`
(`start_bridges_hi`, `snd_passed`, `test_ghost_on`).

## play.asm: el bucle principal (A197–A6EA)

La lógica del juego que el original ejecuta en su bucle principal, como la tiene el port en C++.
El estado está en las direcciones de la RAM del original.

| rutina | llamada | qué y cómo | A / B |
|---|---|---|---|
| `main_loop` | `main_frame` (no durante un reinicio) | A197–A6EA: lee RANDOM (`random_read`), el avión (`fly_plane`) o la explosión/vuelta (`respawn_or_game_over`), `drive_tank`, `move_objects`, luego `main_loop_end`. Vuelve antes cuando empieza un reinicio. | 620 / 620 |
| `main_loop_end` | `main_loop`, `finish_reset` | A5B7–A6EA: el misil y el proyectil del tanque (`move_missile`, `move_shell`), `scroll_river`, START/SELECT. | 180 / 170 |
| `scroll_river` | `main_loop_end` | A6FD: la velocidad sumada dos veces por fotograma a una fracción; cada acarreo es un `push_line` (una línea nueva del río: la parte cara, ver river_gen). | 140 / 160 |
| `fly_plane` | `main_loop` | A3E9–A5B4: combustible, giro (`steer`), velocidad (`change_speed`), disparo, la bala (`move_bullet`), los resultados de las colisiones: `explode` (un objeto alcanzado o embestido: puntos), `crash`. | 290 / 480 |
| `steer`, `change_speed` | `fly_plane` | La X del avión con una fracción por debajo del píxel; la velocidad $40–$FE. | |
| `explode` | `fly_plane` | A4E0–A589: el slot se convierte en una explosión, los puntos (BCD), la bonificación de un puente. | |
| `crash` | `fly_plane`, `explode` | sub $B1C0: el avión se estrella, con un sonido de evento; `section_checkpoint`. | |
| `draw_bullet`, `move_bullet` | `fly_plane`, `crash` | Las 8 líneas de la bala en la memoria del misil 2 (solo `-DBEAM`; si no, `draw_bullet` vuelve enseguida). | 380 / 520 |
| `new_game`, `reset` | START, fin de partida, vuelta | sub $B0F1: el río y los objetos a cero (`restore_checkpoint`), `clear_screen_memory` (solo con memoria de pantalla: compilaciones de verificación y del haz), `busy` = 13 u 8 fotogramas. | |
| `clear_layer2_page` | `main_frame` durante `busy`, `restart` | Dos de las 10 páginas del Layer 2 limpiadas por fotograma (`l2_clear` cuenta); ninguna en el primer fotograma del reinicio (`l2_wait`: su imagen aún se muestra), y mientras tanto `apply` oculta las líneas del río (`l2_hidden`). ~1 100 por fotograma de media en A, pero una página son 8 KB de escrituras en los fotogramas en que se ejecuta. | 1 100 / 570 |
| `finish_reset`, `finish_respawn`, `respawn_or_game_over` | | Tras el reinicio: el río sigue desde el punto de control, el siguiente jugador o el fin de partida. | |
| `swap_players`, `update_high_score`, `set_up_game`, `select_game` | | Dos jugadores, récord con sus bytes de comprobación, el número de partida. | |
| `show_lives`, `show_score`, `show_bridges`, … | el bucle, el VBI | Los caracteres del panel en la RAM del Atari ($1000). | 620 / 720 |
| `print_bcd` | las `show_*` | B086: bytes BCD como dígitos, ceros a la izquierda en blanco. | 1 200 / 1 400 |
| `read_input` | `main_frame` (no en las compilaciones de prueba) | El teclado (Q A O P, Espacio/M, Intro, G, H, CAPS + 1/2), Kempston 1 y 2 y el mando de Mega Drive en los bytes de joystick, gatillo y consola del Atari. T (al pulsar) conmuta `tm_show`, apagado: el color de respaldo negro. | — |

## game.asm: partes del juego por fotograma y el VBI

| rutina | llamada | qué y cómo | A / B |
|---|---|---|---|
| `random_read` | `main_loop` (A205) | El RANDOM de POKEY: el contador de 17 bits tal como está en el punto de lectura. Las verificaciones cuentan estas lecturas. | |
| `random_step` | `vbi` | El contador avanza un fotograma: una aplicación lineal fija (17 columnas en `random.inc`, NTSC o PAL), 4 bits a la vez: para cada uno de los 4 nibbles de los bits 0–15 una entrada de 3 bytes de `rnd_tab` (página 1, 256 bytes alineados: 64 k + 4 v) por XOR, la columna del bit 16 (`rnd_col16`) si está puesto. Antes era bit a bit, ~2 300. | 560 / 560 |
| `rnd_tables` | final de `tv_setup` | `rnd_tab` y `rnd_col16` a partir de las columnas del estándar (`rnd_cols`): cada entrada el XOR de las columnas de su valor. | |
| `bank_colour` | `vbi`, `start_attract` | sub $AFD0: el tono de la orilla (cambia mientras entra un puente arriba). | 200 / 200 |
| `start_attract` | `restart` | El estado del modo de demostración en su primera línea (partida 1, sin avión). | |
| `draw_logo_and_needle` | `reset`, `start_attract` | El arcoíris y la aguja del combustible en la memoria de player-missile, como los deja sub $B0F1 (solo `-DBEAM`; en el Next son sprites). | |
| `push_line` | `scroll_river`, `start_attract` | Una línea nueva del río: `next_line` (river_gen) registra sus piezas en `dl_seg`, luego en `line_done` `render_line` (Layer 2) y `span_line` (los tramos para las colisiones) dibujan a partir de ellas; con memoria de pantalla (compilaciones de verificación y del haz, `SCREEN_MEMORY`) los bytes de la línea van también por `line_buf` a la memoria de pantalla (48 LDI, la dirección de la línea superior una línea más arriba). | |
| `prepare` | `main_frame` | AE99–AF38 al empezar el fotograma: el tanque y el proyectil salidos por debajo de la pantalla, el color del proyectil, vidas, puentes y puntuación del panel. Las formas en la memoria de player-missile ($0B00–$0FFF) solo en la compilación del modelo de ciclos (`-DBEAM`): los sprites y las colisiones del Next las toman de la ROM. | ~2 000 (3 000 con las copias) |
| `drive_tank` | `main_loop` | A21B: el tanque en la carretera avanza, dispara en el borde del río. | |
| `move_objects` | `main_loop` | A26C–A2ED: los objetos en los slots se animan y se mueven (barcos y helicópteros giran en el borde: el indicador de borde del slot desde el display). | 2 000 / 3 700 |
| `move_missile`, `move_shell` | `main_loop_end` | El misil del helicóptero, el proyectil del tanque. | |
| `vbi` | `main_frame` | B2A5–B43E: `sound_driver`, el contador de fotogramas, los colores del fotograma siguiente (`bank_colour`), `scroller_step`, `random_step`. En PAL al terminar la partida ve algunos valores de antes de sub $B21A (`vbi_before`). | 420 / 430 |
| `scroller_step` | `vbi`, `start_attract` | B44B: el rótulo desplazable un ciclo de color por fotograma en modo de demostración, quieto en el juego. | |

## river_gen.asm: el generador del río (A711–AE93)

Una línea del río cada vez, como la genera el original: el LFSR de 24 bits, secciones y bloques,
anchos de orilla e isla, decoraciones (casas, montañas), carreteras y puentes, los objetos
colocados cada 16 líneas. Su resultado son las piezas de la línea en `dl_seg` (4 bytes cada una:
el byte en que empieza, su tipo, sus datos: 0 un borde, el desplazamiento de su pieza en la
tabla en $B800; 1 bytes de un solo valor, el valor; 2 una fila de decoración, la dirección de su
mapa de bits; terminadas por el byte 48) y los slots. En el juego no hay búfer de línea:
`line_buf` (48 bytes, 192 ciclos de color de 2 bits; no se limpia antes, las piezas van una tras
otra del byte 0 al 48) solo se escribe con memoria de pantalla.

| rutina | llamada | qué y cómo | A / B |
|---|---|---|---|
| `next_line` | `push_line` | Una línea: `count_lines`, `move_bank`, `change_island`, `scroll_objects`, `place_object`, luego `draw_line`. | 210 / 290 |
| `count_lines` | `next_line` | A711: cuenta las líneas; al empezar bloques y secciones prepara lo que viene (`choose_section_width`, `start_decoration`, puntos de control). | 160 / 210 |
| `move_bank` (+ `bank_hit_setup`, `bank_hits_left/right`) | `next_line` | A826: la posición de la orilla para esta línea, sin chocar con el objeto que todavía está entrando. | 350 / 570 |
| `change_island`, `choose_section_width` | | La isla hacia el ancho deseado. | |
| `draw_line` | `next_line` | Las piezas de la línea: relleno de la orilla (`dl_fill`, `dl_fill_bank`), bordes (`dl_edge`, `dl_bank_edge`: piezas de 2 bytes desde $B800), la fila de la decoración (`dl_deco_row`, la dirección de su mapa de bits avanzada), agua; cada una en `dl_seg` con sus datos, DRAW_POS avanzado; sus bytes en `line_buf` solo con memoria de pantalla. | 900 / 2 300 |
| `dl_fill` | `draw_line` | B bytes de C desde DRAW_POS: una pieza de tipo 1 (los bytes en sí solo con memoria de pantalla). | 500 / 1 300 |
| `scroll_objects` | `next_line` | AB76: todo una línea más abajo; cuando el slot más bajo sale de la pantalla, los slots se desplazan. | 560 / 820 |
| `place_object`, `choose_enemy`, `position_object`, `place_tank` | `next_line` | Cada 16 líneas un objeto nuevo en el siguiente slot libre; al empezar un bloque, quizá un tanque en una carretera. | |
| `step_lfsr` | muchas | sub $B183: el LFSR de 24 bits. | 140 / 200 |
| `section_checkpoint`, `restore_checkpoint`, `start_game` | | El punto de reanudación; una partida nueva desde el puente 1 (o `start_bridges_hi` en las compilaciones de prueba). | |

El coste del generador es por cada línea nueva: la velocidad se suma dos veces por fotograma a
una fracción y cada acarreo es una línea, así que 0–2 líneas por fotograma, más cuanto más rápido
vuela el avión.

## render.asm: una línea en el Layer 2

| rutina | llamada | qué y cómo | A / B |
|---|---|---|---|
| `render_line` | `line_done` | Primero `line_bank`. Los ciclos de color 20–179 (`WINDOW_FIRST`) de la línea en la fila A del Layer 2, de las piezas de `dl_seg` (sin búfer de línea). El Layer 2 se guarda por columnas (byte x·256 + y, 32 columnas por página de 8K), así que la fila se escribe bajando por las columnas (`inc h` = la columna siguiente), 10 páginas por turno en el slot 2 (`rl_next`). Una pieza de un valor: su color de `rl_k1`, luego `rl_fill` (8 columnas por byte, página a página; `rl_fill`, `rl_next` en la página 6, spans.asm); los bytes de un borde (de la tabla de la ROM) y la fila de una decoración (de su mapa de bits en la ROM): por byte el juego de tablas de puntos de la línea (`rl_set`: el de un verde) da 2 puntos por ciclo, cada uno escrito dos veces; en una línea de carretera (`.table_k`) el del primer verde, sus puntos de orilla en la entrada de la carretera (`rl_sub`); los bytes antes de la ventana saltados en los datos. 320 escrituras por línea. En la página 6 (movida desde la página 4 por espacio). | 4 100 + 3 800 / 10 000 + 8 300 |
| `line_bank` | `render_line` | Como el de TS-Conf (tsconf/CODE.md): `lineBankColour` del port a C++, calculado solo cuando puede cambiar, en un puente (`road_row`, llevado por `place_object`, `restore_checkpoint` y `scroll_objects`); un color nuevo pone `rl_k1` + $55, `rl_sub`, `rl_set` (`pix_set0` o `pix_set1`) y el salto para las piezas de tipo 0/2 (`render_line.kind`: `.table` o `.table_k`). Entradas 1, luego 4–10. En bank_colours.asm (página 6). | 50 (tras un puente: 30) |
| `bank_init`, `pix_sets` | `start` (página 7, tras `panel_init`) | Los colores de la orilla, cada uno una vez: $D2, $D6, los de las 20 filas de carretera (`bank_cols`, `bank_n`, como mucho 8), las entradas del Layer 2: 1, luego 4–10 (`bank_set`); las tablas de puntos de los dos verdes, 4 páginas cada una (`pix_set0` en $F700 en la página 1, `pix_set1` en $6C00 en la página 12, escrita a través del slot 2): el byte b de la página k es el punto k de b como lo guarda el Layer 2 (0, 2, 3 ellos mismos, 1 la entrada del verde); `rl_k1` ($6B00): el valor de una pieza 0, $AA, $FF como su color ($55 lo pone `line_bank`). | una vez |
| `bank_set` | `bank_init`, `apply` | Las entradas de la orilla del Layer 2: sus colores (E = 1) o negro (E = 0, los colores apagados: `apply`, cuando cambia `show_bank`, `ap_bank_on`). | |

## spans.asm: los tramos de las líneas para las colisiones con el playfield

Cada línea del río tiene un registro de 32 bytes en SPAN_PAGE (página 28 en $4000), en un anillo
de 256: los ciclos de color donde empiezan y terminan sus tramos de orilla (color 1) y de borde
(color 2). Las colisiones comprueban las filas de los sprites contra estos tramos en lugar de
contra los píxeles. Con el mismo índice del anillo, sus huecos: `eg_e1`–`eg_s2` y
`eg_e3`–`eg_s4` (página 12) el agua entre los tramos del borde (con 2 tramos la que hay entre
ellos, con 4 entre el 1.º y el 2.º y entre el 3.º y el 4.º, sin ninguno toda la línea, si no
ninguno: $FF); `bg_e1`–`bg_s2`, `bg_e3`–`bg_s4` (página 1) los dos huecos más anchos entre los
tramos de la orilla (desde el ciclo 32 antes del primero hasta 224 después del último). Una caja
dentro de un hueco no toca nada en la línea.

| rutina | llamada | qué y cómo | A / B |
|---|---|---|---|
| `span_line` | `line_done` | El registro de la línea nueva a partir de las piezas de `dl_seg`, sin mirar ningún píxel: una pieza de un solo valor es toda de un color (`span_class`), una fila de decoración el de la orilla (como los bankRuns del port en C++, la línea sin decoración), los tramos de un borde ya preparados en `edge_runs` según su pieza (el ciclo en la pieza y su color, recortado en el byte 48); cada cambio de color cierra un tramo (`.change`). Luego sus huecos (`.gaps` a partir de los tramos del borde, `.bgaps` de los de la orilla: se guardan los dos más anchos, `.gap`). | 4 200 / 10 300 |
| `edge_runs_init` | `init_tables` (arranque) | Cada pieza de borde que usa el generador (desplazamientos 0–30 de la tabla en $B800) en `edge_runs` (página 12, 16 bytes por pieza): los píxeles 0–7 de sus dos bytes, un par (el píxel, su color; 3, el agua, como 0) en el primero y en cada cambio, $FF después. | una vez |
| `spans_clear` | `start_attract` | Ningún tramo en ninguna línea (memoria de pantalla limpia). Los huecos se quedan: sin tramos no se puede tocar nada, digan lo que digan, y cada línea nueva los rehace. | |
| `span_init` | `init_tables` | Las máscaras: los bits i..j de un byte (`span_masks`). | |

## display_simple.asm: los objetos colocados, sus colisiones

Como el `displayGeometry` del port en C++ (rama `dli_removed`): sin DLI. Cada objeto está en la y
de su slot, recortado al río, y sus colisiones son geometría sencilla. Lo que deja: `ds_objs`
(las filas de cada objeto para los sprites: 8 bytes, primera línea, número de filas, punteros de
forma y color, x, tamaño), los resultados de las colisiones en HIT y los indicadores de borde de los slots.

`display` (~11 800 / 13 500 propios):

1. Mapea SPAN_PAGE, `dh_lists` (los descriptores de los otros sprites), los registros limpiados y ajustados como B527–B55C, `bm_hitclr`, `dh_sprites` (HIT = $FF, luego los otros sprites contra la orilla y entre sí).
2. `.slot`, para cada slot desde FIRST_SLOT: IY sobre el tipo de aspecto del slot (página 5: tipo, X, tamaño en IY + 11, + 22, + 33, leídos allí, sin copia), Y e indicadores guardados (`ds_y`, `ds_flags`), `ds_edge_kind`; el inicio = max(y, $5D); la primera fila = y + height[type] − inicio (≥ $80: desaparecido arriba, el siguiente); X = inicio + 3 (pasado 255: el final); filas = min(fila + 1, 256 − X); `ds_rowp` el byte de la primera fila; `ds_obj` (las filas en `ds_objs`); un puente: `.road` (`-DBEAM`) (el color de la carretera desde la línea de barrido tras cada una de sus filas, X − 69 + 1; el color de la orilla de la sección tras la última salvo que X haya dado la vuelta, mediante `ds_bank`; el color de una línea solo cuando difiere de la línea de encima). Las primeras filas de forma y colores se calculan en el sitio (DE, BC para `ds_obj`). Las tablas de la ROM (altura, forma, colores) se leen con sumas de 8 bits (`ROM_SHAPES` y `ROM_COLOURS` empiezan al principio de página).
3. El borde (P3PF) para los tipos 8–$0D (`ds_edge_kind`: helicópteros, globos, barcos giran en él): `ds_edge_test`, luego `ds_set_flags`.
4. Contra la bala, el proyectil del tanque (no un puente) y el avión: `dh_obj`; un contacto guarda el slot (HIT_BULLET_OBJECT, HIT_SHELL_OBJECT, HIT_PLANE_OBJECT), así que queda el último bajando por la pantalla.
5. `.end`: `test_ghost` (compilaciones de prueba); `ds_bank_fill` solo con `-DBEAM`.

| rutina | llamada | qué y cómo | A / B |
|---|---|---|---|
| `ds_edge_test` | `display`, por objeto de los tipos 8–$0D | A = $02 si la extensión de una fila (de su primer punto al último) se encuentra con un tramo de borde en su línea (el `edgeTouches` del port en C++). La caja del objeto (de X a X + 8, 16 o 32 ciclos; nada pasado el ciclo 255) por fila contra los huecos de agua de la línea (`eg_*`, el índice de anillo de la línea avanza de uno en uno); dentro de uno, la fila siguiente. Si no, el primer y el último punto de la fila (`edge_lo`/`edge_hi` escalados por el tamaño: `.s1`/`.s2`, más X: `.ex1`/`.ex2`) contra los tramos de borde de la línea (su registro): un tramo entre ellos es un contacto, nada punto por punto. | 3 200 / 10 200 |
| `ds_set_flags` | `display` | El bit de borde del objeto en los indicadores de su slot (bit 0). | 1 100 / 1 300 |
| `ds_bank` | `display` (`-DBEAM`) | Un cambio del color de la orilla desde la línea de barrido A (la carretera de un puente y vuelta): en `ds_bank_ev`. | |
| `ds_bank_fill` | final de `display`, solo `-DBEAM` | `scan_bank` para cada línea del río a partir de `ds_bank_ev` (solo lo lee el display del haz; en el juego el color de la orilla va por línea: `line_bank`). | |
| `ds_edge_only` | `display` | El bit de borde solo para los tipos que lo leen. | |

## display_objs.asm

| rutina | llamada | qué y cómo | A / B |
|---|---|---|---|
| `ds_obj` | `display`, por objeto con filas | Las filas del objeto para los sprites: primera línea de barrido, número de filas, las direcciones de forma y color de la primera fila (DE, IY), x, tamaño: 8 bytes en `ds_objs` (`DS_OBJS` = como máximo 16). Un objeto cuya primera fila está en la línea 28 o por encima (encima de lo alto del río) se amplía a toda su forma (k = inicio − y filas más), así el sprite se dibuja entero y la ventana de recorte de los sprites lo corta. Al final de la página 4. | 5 300 / 6 100 |

## display_hits.asm: las colisiones como geometría

Ningún registro de colisión ni lectura: una colisión cuenta si ocurre en cualquier punto de las
filas de los sprites. Cinco sprites más se describen con descriptores de 10 bytes en `dh_desc`
(lo que no cambia se copia de `dh_template` una vez al arrancar, `dh_init`; el resto lo rellena `dh_lists` en cada fotograma): la base de las filas (baja), máscara (ya girada a los sitios de los puntos), el final de las filas (la línea tras la última; pasado 255, 255), x, tamaño, número de sprite, primera línea, filas, ancho en ciclos, la base (alta)
(`DH_SIZE` = 10; `DH_SHELL`, `DH_TANK`, `DH_PLANE`, `DH_MISSILE`, `DH_BULLET`). Una fila en la
línea L es el byte en base + L: la forma del fotograma desde la ROM (base = su dirección − la
primera línea, `dh_shape`, `dh_base`); las filas del misil y de la bala son `dh_ones` (todo unos)
bajo sus máscaras, giradas a los sitios de los puntos ya en la plantilla ($03 en 6: $C0; el bit 5 de la bala en 2: $80), así que ninguna fila se gira. Tras un reinicio (`pm_empty`, hasta el siguiente `prepare`)
ninguna fila.

| rutina | llamada | qué y cómo | A / B |
|---|---|---|---|
| `dh_lists` | inicio de `display` | Filas, posiciones y bases de los descriptores; luego el final de cada uno (campo 2). | 1 300 / 1 300 |
| `dh_sprites` | `display` | HIT = $FF, luego HIT 0 donde: el tanque toca el borde (P1PF), el avión la orilla (P2PF), el misil y la bala la orilla o el borde (M0PF, M2PF): `dh_pf`; el avión y el proyectil del tanque (P2PL bit 0), el misil y el avión (M0PL): `dh_pair`. | |
| `dh_pf` | `dh_sprites` | NZ: las filas del sprite IX tocan el playfield (DE: `sp_edge`, `sp_bank`, `sp_under`). Por línea del río: primero el byte de la fila bajo la máscara (sin puntos: la línea siguiente), luego su caja (de X a X + sus ciclos) en los huecos de la línea (A: bit 0 los `eg_*` del borde, bit 1 los `bg_*` de la orilla); dentro, nada; si no, los extremos de la fila contra los tramos (la función `sp_*`). Se detiene en el primer contacto. | 10 200 / 11 200 |
| `sp_edge`, `sp_bank`, `sp_under` | `dh_pf` | La fila de un sprite contra los tramos de la línea de borde (marrón), orilla (verde) o ambos, como el `spanTouches` del port en C++: su primer y último punto (`sp_ends`: `edge_lo`, `edge_hi`, el ancho del tamaño, más X) contra los tramos (`sp_runs`), un tramo entre ellos es un contacto; el registro de la línea vía `sp_rec`. | |
| `dh_pair` | `dh_sprites` | NZ: las filas de dos sprites se encuentran: `hit_setup` sobre sus ciclos, luego por cada línea que tengan ambos los bits de cada uno (`dh_bits`, `hit_wide` según su tamaño) en `hit_a`, `hit_b`, y `hit_line`. | |
| `dh_bits`, `dh_end` | `dh_pf`, `dh_pair`, `dh_obj` | Los bits del sprite IX en la línea A: el byte de la fila bajo la máscara, ya arriba (Z: ninguno); la línea tras la última suya (`dh_lists` la pone en el campo 2 una vez por fotograma). | 400 / 500 |
| `dh_obj` | `display`, por objeto (bala, proyectil, avión) | NZ: el sprite IX toca las filas del objeto actual (`ds_rowp`, desde la línea de X = `ds_counter`, `ds_rows` de ellas, en X y tamaño del slot: IY + 22, + 33). Primero las líneas que tienen ambos (`ds_l1`, `ds_l2` de `display`, el final del sprite: la mayoría de los objetos no comparte ninguna), luego `hit_setup` sobre los ciclos del objeto (8, 16 o 32) y del sprite; por línea el byte de la fila del objeto (cero: la siguiente) y los bits del sprite, cada uno ensanchado (`hit_wide`), `hit_line`. | 4 900 / 6 100 |
| `hit_setup` | `dh_obj`, `dh_pair` | Z: los ciclos de las dos cajas (B desde, C ancho; D desde, E ancho) no se cruzan; si no, la ventana donde ambas están en los ciclos del playfield (32–223, como mucho 8 de ancho): dónde empieza en los puntos de cada una (`hit_ka`/`hit_sa`, `hit_kb`/`hit_sb`: byte, bit) y los bits de sus ciclos (`hit_w`). | 500 / 700 |
| `hit_wide` | `dh_obj`, `dh_pair` | Los puntos del byte A un ciclo por bit en DE y siguientes (tamaño C: 1, 2 o 4 ciclos por punto, desde `ov_exp2`, `ov_exp4`: tablas hechas por `init_tables`), luego un cero. | |
| `hit_line` | `dh_obj`, `dh_pair` | NZ: los puntos de `hit_a` y `hit_b` se encuentran en la ventana: los dos bytes de cada uno desde su inicio desplazados con `bsla de,b` (Z80N, 8 ciclos), con AND entre ellos y con `hit_w`. | |

## display.asm: las pruebas del playfield (y el viejo modelo del haz)

Gran parte de este archivo es el modelo completo, exacto al ciclo, del DLI (`op`, `bm_events`,
`bm_draw`, `rec_set`, `p3_scan`, `bm_wsync`, el cuerpo de `collide` del haz…), guardado como
referencia y ensamblado solo con `-DBEAM`. Se ensambla siempre:

| rutina | llamada | qué y cómo | A / B |
|---|---|---|---|
| `pf_under`, `pf_bank`, `pf_edge`, `pf_none` | el display del haz (`-DBEAM`) | ¿La fila del sprite (bits D desde el bit 7, posición E, tamaño A: 1, 2 o 4 ciclos por bit) en la línea `bm_line` está sobre la orilla, el borde o cualquiera de los dos, punto por punto? Busca el registro de la línea (`pf_line`), luego recorre sus tramos (`pf_size`). El juego ya no las usa. | |
| `pf_line` | `pf_bank`, `pf_edge` | HL = el registro de la línea `bm_line` (acarreo: una línea del río). | |
| `pf_size`, `pf_v1`, `pf_v2`, `pf_v4` | `pf_*` | Los tramos bajo el sprite: un tramo que se solapa con los ciclos del sprite se comprueba contra sus bits con `span_masks` (D: la página de las máscaras); una variante por tamaño (N desplazamientos convierten un desplazamiento en ciclos en un índice de bit). | |
| `collide` (`.add`, `.pair`, `.overlap`, `.entry`) | el display del haz (`-DBEAM`) | Una lista de los sprites en una línea (bits, posición, tamaño) y la prueba punto por punto del solapamiento de dos de ellos; el juego ya no la usa. | |
| `bm_hitclr` | `display` | HITCLR: los bits de colisión limpiados. | 1 500 / 1 700 |
| `init_line_tables` | `tv_setup` | Por línea de barrido: los ciclos de ANTIC al principio (`line_start`) y los que quedan tras dibujar (`line_after_draw`); ahora solo los lee el modelo `-DBEAM`. | |

## sprites.asm: sprites, el Copper, `apply`, el panel

| rutina | llamada | qué y cómo | A / B |
|---|---|---|---|
| `build_sprites` | `main_frame` | `ob_list` (los objetos); el avión, su bala, el tanque, el misil del helicóptero, el proyectil (en el orden en que los dibuja `drawRiver`, el último encima): cada uno el patrón de su fotograma hecho al arrancar (`pl_plane`, `pl_tank`, `pl_shell`, `pl_bullet`, `pl_missile`) en su posición, `pl_sprite`; `pl_keep` guarda sus atributos, que los fotogramas de un reinicio (`busy`) vuelven a mostrar (`pl_again`); `build_copper`. | 1 000 / 1 100 |
| `pl_sprite` | `build_sprites` | Patrón A ($FF: ninguno) en la línea D (ninguno bajo el río), posición E, desplazamiento de paleta C: sus 5 bytes de atributos en `sprite_list` (X = 2·(x − 52), 9 bits; Y; el desplazamiento; el patrón; 4 bits, el medio patrón). | ~100 por sprite |
| `ob_list` | `build_sprites` | Por entrada de `ds_objs`, sus filas desde `ds_objf` (todas): su imagen hecha al arrancar, encontrada por las direcciones de forma y color de la fila superior (`obj_lookup`; no encontrada: `ob_miss`, no se dibuja), un sprite cada 16 filas (`ob_attr`: X = 2·(x − 52), Y, el banco, 4 bits, el medio patrón, la escala para el ancho doble o cuádruple), ninguno para una pieza cuya primera fila está bajo el río. | 5 700 / 6 400 |
| `build_copper` | `build_sprites` | Solo cuando cambió el estándar (`cp_built` 0, `tv_setup`) o los colores se apagaron o encendieron (`colour_bank` 0 o no, contra `cp_bank_on`): las entradas de la orilla restauradas tras el gris del panel (`CP_RESTORE`: sus colores, negro mientras los colores están apagados), luego `copper_start` y la parte del panel (`copper_panel`) en la lista, el WAIT final. `cp_full` = 1. En bank_colours.asm. | 100 / 100 |
| `apply` | tras `wait_frame` | El desplazamiento del Layer 2 (NR $17), los atributos de los sprites (puerto $57, OTIR 5 por sprite; los sobrantes del fotograma anterior ocultos), los colores del proyectil, del tanque y del avión (paleta de sprites), los colores 0, 2, 3 del Layer 2, su ventana de recorte (mientras el Layer 2 se limpia tras un reinicio, desde su segundo fotograma: solo las filas del panel, `l2_hidden`; `l2_clip_y2` la última fila de la ventana desde `tv_setup`), `panel_frame`, el Copper: detenido, toda la lista enviada si `cp_full`, si no solo el byte de desplazamiento X del rótulo desplazable, reiniciado (modo %11). La pantalla se apaga tras mucho tiempo de inactividad (IDLE_TIME). No está en las cifras de arriba. | — |
| `panel_frame` | `apply` | El panel: solo las posiciones que `panel_put` ha enumerado (`pf_dirty`; todas tras la copia de `start_attract` y `tv_setup`), cada una desde `.cells` (la celda de su mitad izquierda; el primer carácter de la fila solo su mitad derecha), 2 celdas del tile 2·código + mitad y los bits del color como desplazamiento de paleta. El rótulo desplazable (mitad h en 8h − X0, X0 = 16·TEXT_LO + 38 − 2·FINE_SCROLL): un anillo en la fila de mapa 26 (mitad h en la columna h mod 40; solo se escriben las mitades nuevas desde el último fotograma, `.ring_write`; las 40 tras un salto), el desplazamiento X X0 mod 320 (9 bits: `CP_XSCROLL_HI_BACK`, `CP_XSCROLL_BACK`); la ventana de recorte del tilemap S = X0 & 7 puntos más corta por la derecha (la columna que da la vuelta); el sprite 70 (patrón 20, desplazamiento de paleta 6) en X 320 − S con la mitad h0 + 40 (sus 64 bytes escritos cuando cambia: `.spr_pattern`). Los sprites de la aguja y del logo. | ~1 700 el rótulo desplazable, ~200 el panel, ~1 400 aguja y logo |

Datos: `copper_start` (índice 1 de la paleta del Layer 2, un NOP donde estaba NR $4A (el color de T), scroll Y y X del tilemap 0: sus líneas las de la pantalla, nada en las filas fuera del panel), `copper_panel_ntsc`/`_pal` (en la página 7, copper_panels.asm: `tv_setup` copia una en `copper_panel` a través del slot 2; la misma disposición, así que los desplazamientos valen para ambas: línea 200: el scroll Y del tilemap para la primera fila del panel (`CP_PANEL_Y`, puesto por `tv_setup`), los colores 0–10 del Layer 2 negros (`CP_COLOURS`: también las entradas de la orilla, ya que las filas bajo el panel muestran líneas viejas del río) y la ventana de los sprites desde la línea 215 hacia abajo (`OBJ_LAST` + 1, bajo las filas de cualquier objeto; la aguja y el logo más abajo); 201: gris (`COPPER_GREY`, puesto por `tv_setup`); el scroll Y del tilemap por fila del panel; línea 230 (240 PAL): los colores 0–10 de vuelta (`CP_RESTORE`: los de la orilla por `build_copper`, los del borde y el agua por `apply`, `CP_EDGE_BACK`); scroll Y y X del texto desplazable (`CP_XSCROLL_HI_BACK`, `CP_XSCROLL_BACK`); en `wait_line`: la ventana de los sprites otra vez la del río). `apply` envía los bytes del borde al scroll X (`.cp_send`) cuando la lista no se envía entera.

## panel.asm (página 6): los caracteres del panel

| rutina | llamada | qué y cómo |
|---|---|---|
| `panel_put`, `panel_put_de` | quien escribe en el panel | Un carácter en el panel en HL (DE): nada si ya está ahí; si no, se escribe y su posición se apunta en `pf_dirty` (60 o más: todas). |
| `print_bcd` | `show_score`, `show_other_score`, `show_high_score`, `show_bridges`, el fin de partida | B bytes BCD en HL como dígitos en DE, '0' = C, ceros a la izquierda en blanco; nada en modo de demostración. Para cada lugar (puntuación, récord o puntuación del otro, puentes, puentes del otro) guarda la base de los dígitos y los bytes impresos (`pb_cache`) y vuelve enseguida cuando son iguales. |
| `show_lives` | `prepare` y otros | Los símbolos de las vidas; nada cuando su número es el impreso la última vez (`sl_last`). |
| `pb_forget` | `start_attract` | Se olvidan los últimos números impresos (todo se vuelve a imprimir). |

Los lugares que se solapan olvidan los de los otros: las vidas y los puentes del otro jugador,
el texto de fin de partida en el lugar de las vidas.

## sound.asm: el controlador de sonido y las muestras de POKEY

| rutina | llamada | qué y cómo | A / B |
|---|---|---|---|
| `sound_driver` | `vbi` | B2A5–B3D8: el controlador del original: canal 1 el pitido de salida, sonidos de evento, el pitido de combustible bajo o el motor; 2 una explosión o el misil; 3 el disparo o una vida extra; 4 el proyectil del tanque. Escribe AUDF/AUDC de POKEY (`pokey_audf`, `pokey_audc`). | 770 / 930 |
| `sound_init` | `restart` | Los DAC encendidos (NR $08), el anillo y los canales en silencio, `sound_init7` (página 7: el AY, las tablas de POKEY, el DMA programado), luego el DMA habilitado ($87) una vez remapeada la página 12. | |
| `pokey_frame` | `main_frame` | `ay_frame` (los tonos puros al AY; los cuatro allí: el anillo silenciado una vez, `snd_idle`, y listo), luego cuántas muestras: las líneas que quedan antes de `wait_line` (NR $1E/$1F), dónde está el DMA (su dirección releída), hasta `SND_LEAD` (760) por delante, al menos `SND_MIN_LEAD` (200), como máximo `SND_CAP` (700). Luego: `snd_fill` (el tramo a 0), cada canal que no está en el AY: volumen × la ganancia del fotograma (`snd_gain_set`: 8, o 7–4 cuando los volúmenes suman más de 31, `mul d,e`) como nivel constante (solo volumen, o AUDF ≤ 4: la mitad) o `pk_channel` (sus conmutaciones como + y − en el anillo), luego `snd_sum` (la suma acumulada da los niveles). Páginas 14–15 en $0000 mientras tanto (el contador de 17 bits). | 2 400 / 2 500 |
| `snd_gain_set` | `pokey_frame` | `snd_gain`: 8 por paso de volumen, o el mayor que mantiene los niveles en 255 o menos cuando los volúmenes de los canales en el DAC suman más de 31 (7 hasta 36, 6 hasta 42, 5 hasta 51, si no 4). | ~150 |
| `snd_fill` | `pokey_frame` | DE bytes de A desde HL en el anillo (dos tramos al dar la vuelta), cada uno con PUSH desde su final hacia abajo (SP guardado). | 2 800 / 2 400 |
| `snd_sum` | `pokey_frame` | La suma acumulada sobre DE muestras: `add a,(hl) / ld (hl),a / inc l`, desenrollada 8 veces, con entrada en el punto adecuado para el resto (`jp` automodificado), página a página en el anillo. ~8 400 ciclos para ~270 muestras: unos 31 por muestra. | 8 600 / 7 300 |
| `sound_random` | `sound_driver` | RANDOM para el tono de un ruido (no `random_read`, que cuentan las verificaciones). | |

El anillo: 1024 bytes en $7C00 (página 12), alineados a 1K, enviados al puerto $DF por el zxnDMA
en modo ráfaga con preescalador 55 (15 909 Hz), reiniciado al final. Niveles 0–240.

## sound_pulses.asm, sound_handlers.asm: las conmutaciones de un canal

| rutina | llamada | qué y cómo | A / B |
|---|---|---|---|
| `pk_channel` | `pokey_frame`, por canal con AUDF ≥ 5 | Prepara: los valores parciales del volumen (× 0–3 de 4, para una conmutación dentro de una muestra), los pasos del periodo para los contadores de 4 y 5 bits (`snd_mod15/31`), el periodo como muestras y ciclos × 64 insertado en los bucles; el primer pulso (`CH_D`, `CH_F`); K = pulsos en este fotograma (una división de 12 bits, desenrollada: los ticks están por debajo de 4 × SND_CAP < 4096); luego el bucle de su tipo. | 1 200 / 2 800 |
| `pk_tone` | `pk_channel` | Un tono: la salida conmuta en cada pulso. | |
| `pk_noise` | `pk_channel` | Ruido: el siguiente bit del contador de 17 bits en cada pulso (los bits en fila, mapeados en $0000); sus conmutaciones al inicio de la muestra (+ o − el volumen, sin repartir entre dos muestras). | 4 600 / 12 900 |
| `pk_g4` | `pk_channel` | El contador de 4 bits filtrado por el de 5 bits (AUDC 010: el misil del helicóptero): ambos contadores como un solo número m (`g4_crt`: m = b + 31 ((e − b) mod 15)), un pulso m + s, `g4_tab` para cada m ($FF no pasa, si no el bit); los contadores recuperados de m al final. Conmutaciones al inicio de la muestra. | 0 / 1 400 |
| `pk_other` + `pk_handlers` (`adv31`, `adv15`) | `pk_channel` | Los demás tipos mediante manejadores. | |
| `pk_on`, `pk_off`, `pk_part*` | los bucles | La conmutación de un tono o del resto en un pulso: la muestra recibe el cambio menos la parte anterior a la conmutación, la muestra siguiente esa parte (sin zumbido de muestras enteras; el ruido y el misil conmutan en cambio al inicio de la muestra). | |
| `pk_done` | los bucles | El resto de los ticks del fotograma en `CH_D`, `CH_F`, la salida guardada. | |

## sound_ay.asm (página 7), sound_ay_run.asm (página 6): los tonos puros en el AY

| rutina | llamada | qué y cómo | A / B |
|---|---|---|---|
| `ay_init` | `sound_init7` | TurboSound encendido, el primer AY en mono, solo tonos, en silencio. | |
| `sound_init7` | `sound_init` | `ay_init`, las tablas de POKEY en la página 1, `snd_mod15/31`, el DMA programado (no habilitado). | |
| `ay_frame` | `pokey_frame` | Para cada canal de POKEY con un tono puro (AUDC 101x o 111x, no solo volumen, volumen ≠ 0): su propio canal AY (`ay_slot`: 1 la A del segundo AY, 2 la A del tercero, 3 la B del primero, 4 la C del primero), el periodo N = (AUDF + 1) × 3,454 (PAL) / 3,422 (NTSC) mediante `mul d,e`, el volumen mediante `ay_vol`, el bit de tono del mezclador; `ay_mask` le dice a `pokey_frame` que los salte. Los registros de este fotograma en `ay_q` (3 fotogramas × 33: los 0–10 de los tres chips, por turno vía `ay_qi`), y salen los de 2 fotogramas antes. | 2 200 / 2 800 |
| `ay_out` | `ay_frame`, `ay_init`, `ay_quiet` | Los registros 0–10 de los tres AY desde HL (el primero queda seleccionado, B = $FF). | 3 400 / 3 400 |
| `ay_quiet` | `pokey_frame` (sonido apagado), `ay_init` | Todo en silencio (volúmenes 0, mezclador $3F). | |

`sound_ay_run.asm` está en la página 6, no en la 7, para que `pokey_frame` nunca mapee la página
7 sobre el anillo (ver NOTES: el chasquido).

## panel_init.asm (página 7, al arrancar)

| rutina | llamada | qué y cómo |
|---|---|---|
| `panel_init` | `start` (página 7 en $6000) | Los juegos de caracteres del Atari construidos donde los construye el juego (fuente del sistema de `font.inc`, los símbolos del cartucho), cada carácter como dos tiles (tiles 0–127 los del panel, 128–255 los del rótulo desplazable) en las páginas 10–11, la paleta y los registros del tilemap (NR $6B/$6C/$6E/$6F, recorte), los patrones de los sprites de la aguja y del logo, `edge_lo`/`edge_hi` (el primer y el último punto encendido de cada byte, para la prueba del borde). |
| `pl_pics` | `panel_init`, antes de `obj_pics` (página 7) | Los 10 fotogramas del avión (14 filas), los 8 del tanque (11 filas) y los 7 del proyectil (16 filas) desde sus tablas de punteros en la ROM, como `prepare` los copia a la memoria de player-missile: un patrón de 4 bits cada uno (un punto: 2 píxeles de valor 1), compartido por los fotogramas con una misma dirección, ninguno para uno totalmente vacío ($FF); la bala (8 filas de un punto) y el misil del helicóptero (una fila de 4 puntos). Patrones desde 0 (20 en total). |
| `obj_pics` | `panel_init` (página 7) | Las imágenes de los objetos: para los tipos 7–15 los tipos de aspecto que pueden tener (el suyo, los de `ROM_NEXT_KIND` por debajo de $0C, los de la explosión desde 2 y 3), cada uno también reflejado, height + 1 filas; 58 imágenes como patrones de 4 bits desde 24, el valor de un punto la posición del color de su fila en el banco de paleta 14 (tipos 12, 15) o 15 (los demás); `obj_head`/`obj_e` para `obj_lookup`. |

## load_rom.asm (página 7)

| rutina | llamada | qué y cómo |
|---|---|---|
| `load_rom` | `start` (no en las compilaciones de prueba) | Abre River_Raid.rom en la carpeta del programa mediante esxDOS (F_OPEN, F_READ, F_CLOSE; con el nombre corto donde no se ven los nombres largos) y lee sus 8192 bytes en $A000 (página 5). Sin él: un borde rojo y una parada. Comprobado solo en un Next real. |

## Includes

- `vars.inc`: las direcciones de RAM del Atari de las variables del juego (los nombres del original).
- `palette.inc`: la paleta del Atari como colores del Next (hecha por `tools/mkpalette`).
- `random.inc`: las columnas del paso de RANDOM (`tools/mkrandom`).
- `font.inc`: la fuente del sistema (`tools/mkfont`, la de AltirraOS, con su nota).
- `poly.inc`, `poly17.bin`: las secuencias de 4, 5 y 17 bits de POKEY (`tools/mkpoly`).

## Lo que conviene saber antes de cambiar el código

- **El código automodificable** es habitual en los bucles calientes: valores inmediatos y destinos de salto insertados (`.bx1/.be1/.bx2/.be2/.ex1/.ex2/.s1/.s2/.pv/.pv_bits/.pv_end/.pv_x` de `ds_edge_test`; `.mode/.x0a…/.x1d/.bits/.fn` de `dh_pf`; `.jp` de `snd_sum`; `.pf/.pq` de los `pk_*`). Una variante se comprueba byte a byte (un `add a,a` que se quedó una vez duplicó el sonido).
- **Puntos de entrada desenrollados**: `snd_sum` salta al medio de un bloque `rept` para el resto.
- **El slot 2** es una ventana de trabajo: una rutina que necesita una página ahí la mapea y no la restaura; el siguiente usuario mapea la suya. **El slot 3** debe seguir siendo la página 12 mientras suena el sonido.
- **Las tablas están alineadas a página** para que `ld h,high table / ld l,index` sea la búsqueda: `span_masks`, `span_class`, `edge_lo/edge_hi`, `obj_head`, `ov_exp2`/`ov_exp4`, `eg_*`, `bg_*`, la paleta.
- **Las verificaciones**: tras cada cambio, `nxcheck` compara en cada fotograma con el port en C++ el estado y la memoria de pantalla, el color de la orilla por línea, los objetos tal como se dibujan, la lista y la memoria del Copper, y al final la imagen. El conjunto completo tarda ~25 minutos en 2 núcleos (HANDOFF.es.md, *Método*). Un ensamblado fallido deja las páginas viejas: mira primero la salida de la compilación.
- **Medir**: `NXHISTALL=archivo` (todos los fotogramas) o `NXHIST=archivo` (un fotograma) y `tools/prof.py`; `NXSLOW=T` lista los fotogramas de más de T ciclos. `NXHISTAPPLY=archivo` hace lo mismo para `apply` (desde el final de `wait_frame`) e imprime su media y su máximo; `tools/prof_local.py build/test.sym archivo fotogramas [rutina…]` reparte el tiempo también por etiquetas locales (`ds_edge_test.row`, `panel_frame.mod`, …). Los fotogramas más pesados: `-stress` con `NXBRIDGE=80 NXGHOST=1 NXGAME=1`.
- **apply** (~7 400 por fotograma, no está en las tablas de arriba): el rótulo desplazable ~1 700 (el desplazamiento X mod 320 por resta ~650 de ellos), aguja y logo ~1 400, el panel ~200 (solo lo que ha cambiado), los atributos de los sprites ~1 800, la lista del Copper ~1 200.
- **Una reescritura** se comprueba más rápido con una compilación de prueba que en cada fotograma ejecuta la forma nueva junto a la vieja y cuenta dónde difieren (hecho para las filas de las colisiones, la colocación, los cursores), y luego se borra la vieja.
