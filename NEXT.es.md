# River Raid para el ZX Spectrum Next

[English](NEXT.md) | [Русский](NEXT.ru.md) | [Українська](NEXT.uk.md) | [Deutsch](NEXT.de.md) | [Polski](NEXT.pl.md) | [Italiano](NEXT.it.md) | Español | [中文](NEXT.zh.md) | [日本語](NEXT.ja.md)

Parte de [River Raid para los ZX Spectrum modernos](README.es.md); el otro port: [TS-Conf](tsconf/README.es.md). La licencia: [README.es.md](README.es.md#licencia).

Un port de River Raid (Activision, Atari 8-bit, 1983, de Carol Shaw) al ZX Spectrum Next,
basado en el port a C++ de [djdron/river_raid](https://github.com/djdron/river_raid), que
averigua cómo lo hace todo el original y está contrastado con él fotograma a fotograma.

Un proyecto de aficionados no oficial con fines educativos, sin relación con Activision ni con
Microsoft. El juego no está incluido: el programa lee en tiempo de ejecución tu propia imagen
del cartucho.

Cómo funciona en el Next, para todos: [docs/HOW_IT_WORKS.es.md](docs/HOW_IT_WORKS.es.md). Para retomar el trabajo: [HANDOFF.es.md](HANDOFF.es.md); cómo está hecho, con cifras: [docs/NOTES.es.md](docs/NOTES.es.md); el código fuente en ensamblador rutina a rutina (en inglés y en ruso): [docs/CODE.md](docs/CODE.md).

## Estado

El juego, con su sonido. Al arrancar corre el modo attract; START empieza una partida: el
avión vuela, gira, acelera y frena, dispara, gasta combustible y repone sobre los depósitos;
los enemigos, los puentes y los depósitos explotan y dan puntos; los tanques disparan al
avión, los helicópteros lanzan misiles; choques, aviones nuevos desde el último puente, un
avión extra cada 10 000 puntos, fin de partida y récord; SELECT cambia la partida (1-8: cuatro
puentes de salida, un jugador o dos por turnos), cualquier tecla pausa. Bajo el río, el panel
(puntuación, número de partida, indicador de combustible, vidas, récord o puntuación del otro
jugador, puente) y el texto desplazable con el logotipo arcoíris, que muestra los créditos
mientras no se juega. Cada fotograma hace lo que hace el original (la lógica del juego, el
generador del río, y lo que muestra la interrupción de la display list y las colisiones que
lee, calculado sin ejecutarla), y se contrasta con el port a C++ fotograma a fotograma.

El sonido: el controlador de sonido del original fija en cada fotograma los cuatro canales del
POKEY (contrastados con el port a C++); el POKEY mismo se emula por software, su salida se
escribe en un anillo de muestras que el zxnDMA envía solo al DAC (15 909 por segundo). Aún no
se ha escuchado en un Next real: en el núcleo de Xpeccy+ suena, y las comprobaciones lo
escriben en un WAV (`-wav`). En Xpeccy+ pon los volúmenes de DAC y PSG a 100 (por defecto
son 80): el DAC toca los ruidos, el PSG (AY) los tonos puros.

PAL o NTSC: el programa arranca como un Atari PAL (el Next a 50 Hz), CAPS + 1 cambia a uno
NTSC (60 Hz) y vuelta, como si se encendiera de nuevo la máquina. Se diferencian como los
originales: el juego NTSC va un 17% más rápido (60 fotogramas por segundo en vez de 50), el
panel y el texto desplazable están más arriba, el borrado de memoria tras un choque dura 13
fotogramas en vez de 8, en PAL a partir del nivel $2F los depósitos son algo más escasos,
etc. (las variantes PAL y NTSC del port a C++).

Velocidad: a 28 MHz el trabajo de un fotograma ocupa de media un 21% de un fotograma de 50 Hz
al principio de una partida, como mucho un 41% en las escenas más pesadas (todos los huecos de
enemigos ocupados, velocidad máxima, disparando sin parar, desde el puente 80); ningún
fotograma llega tarde ni en PAL ni en NTSC. Así que también funciona a 14 MHz: incluso los
fotogramas más pesados ocupan un 83% de un fotograma de 50 Hz y un 98% de uno de 60 Hz. El
sonido es unos 25 000 ciclos de eso (un 4% de un fotograma), hasta ~40 000 con explosiones y
el misil del helicóptero; en un fotograma cargado hace menos muestras y deja el resto a los
siguientes.

## Ejecutarlo

Pon `build/river_raid.nex` y tu `River_Raid.rom` (la imagen del cartucho: 8192 bytes, sin
cabecera, como la usa el port a C++) en la misma carpeta de la tarjeta SD del Next y abre el
.nex desde el Browser. Sin la ROM (o con un archivo que no sea el cartucho) el borde se vuelve
rojo y el programa se detiene. La ROM se busca por su nombre largo y luego por el corto
`RIVER_~1.ROM`.

| | Teclado | Joystick |
|---|---|---|
| volar | Q A O P | Kempston 1 (el segundo jugador en una partida de dos: Kempston 2, o el mismo) |
| disparar | Espacio o M | disparo |
| START | Enter | START en un mando Mega Drive |
| SELECT (la partida, 1-8) | G | A en un mando Mega Drive |
| pausa | H (pulsar y soltar; otra vez para seguir) | |
| PAL / NTSC | CAPS + 1 (vuelve a empezar) | |
| sonido sí / no | CAPS + 2 | |
| 28 MHz / 14 MHz (la velocidad del juego es la misma: solo cambia el tiempo que queda en el fotograma) | CAPS + 3 | |
| el trabajo del fotograma en el borde, un color por parte: naranja apply, gris prepare (y clear_layer2_page durante un reinicio), rojo display, amarillo build_sprites, azul main_loop, magenta push_line (una línea nueva del río, dentro de main_loop), blanco vbi, cian pokey_frame, negro el tiempo que queda | T (sí / no) | |

Las partidas 1-8 como en el Atari: salida en el puente 1, 5, 20 o 50, los números impares un
jugador, los pares dos (se turnan; el teclado vuela para ambos).

El contador del POKEY, que decide qué enemigo despierta y cuándo, empieza en cada arranque con
un valor distinto, como en la máquina real.

## Compilación

```
make deps    # sjasmplus, el port a C++ y Xpeccy+ en deps/ (git, un compilador C/C++, make, cmake, zlib)
make         # build/river_raid.nex
```

`make` solo necesita sjasmplus (`make SJASMPLUS=...` para uno instalado en otro sitio).
`src/palette.inc` (el modelo de paleta del port a C++), `src/random.inc`, `src/font.inc`,
`src/poly.inc` y `src/poly17.bin` (el ruido del POKEY) los genera `make palette`.

## Comprobaciones

```
make check     # FRAMES=... fotogramas (3000 por defecto); tu ROM en rom/River_Raid.rom
make profile   # adónde va el tiempo de un fotograma (el que sigue a FRAMES)
```

`make check-original` compara el programa con el propio cartucho original, como se comparó el
port a C++: `rr_oracle` (del repositorio del port a C++, compilado por el objetivo: el
original en libatari800, que necesita git, un compilador C, make, autoconf, automake) graba
ejecuciones del original (su RAM tras cada fotograma, lo que su lógica leyó de RANDOM, la
entrada), y `nxcheck -oracle DIR` ejecuta el programa con la misma entrada y los mismos
valores de RANDOM y compara su RAM con la del original tras cada fotograma
(`Game::diffWithRam`: el generador del río, los objetos, el estado del juego, las colisiones,
la memoria player-missile, las líneas del río), siguiendo desde el estado del original tras
una diferencia. Ocho ejecuciones, 37 000 fotogramas: el modo attract, una partida del bot
hasta el final y una nueva salida, una partida de dos, volar, repostar, NTSC y PAL. Todo igual
salvo el fotograma de un fin de partida en dos ejecuciones NTSC: ahí el original pone el
contador de fotogramas justo antes o justo después de su VBI, según lo que dure el trabajo de
ese fotograma (el port a C++, y por tanto el programa, toma el caso más habitual).

`make check` lo ejecuta en PAL y en NTSC (`-pal`, `-ntsc`; `-switch N`: CAPS + 1 antes del
fotograma N). `tools/nxcheck` ejecuta el programa sin ventana en el núcleo ZX Spectrum Next de
[Xpeccy+](https://github.com/dotkoval/xpeccy-plus) y a su lado el port a C++
(`rr::Game::frame`, con el mismo contador POKEY y los mismos controles). Los controles vienen
de un jugador inventado: espera en el modo attract, a veces elige otra partida, pulsa START,
vuela hacia el centro del agua, esquiva a los enemigos de delante, pasa sobre los depósitos
cuando le queda poco combustible, dispara, pausa de vez en cuando (`-bot N` para otras
decisiones, `-stress` a toda velocidad disparando siempre, `-seed N` para otro contador
POKEY, `-attract` sin jugador). Tras cada fotograma compara el estado del generador del río
(`RiverGen::diffWithRam`), el estado del juego (también el del texto desplazable), los récords
y los caracteres del panel, la memoria de pantalla (solo existe en la compilación de
comprobación), los objetos tal como se dibujan (`Game::drawn`), la memoria del Copper y los
colores de la orilla de su lista con el color de la orilla por línea (`Game::scan`); al final,
la imagen del último fotograma píxel a píxel: el río, el panel y el texto desplazable
(`Game::drawRiver` y `drawStatusBar` en los colores del Next). También informa de lo que se
jugó y de cuánto duran los fotogramas. 4 x 40 000 fotogramas con jugadores distintos (partidas
1-8, unas 70 partidas y 300 choques) son iguales. Un cambio que lo rompe muestra el primer
fotograma distinto y los campos.

## Cómo funciona

| Z80 | Página de 8K | Qué |
|---|---|---|
| $0000-$3FFF | 30, 31 | la RAM del Atari: el estado del juego en las direcciones del original, la memoria player-missile, la memoria de pantalla (solo en la compilación de comprobación); un volcado coincide byte a byte con el original y con el port a C++ |
| $4000-$5FFF | 18-27 | una ventana al Layer 2 |
| $6000-$7FFF | 12 | las filas de los objetos (`ds_objs`), tablas, los atributos de los sprites, la lista del Copper |
| $8000-$9FFF | 4 | el programa: el fotograma, el generador del río, el bucle principal del juego |
| $A000-$BFFF | 5 | la imagen del cartucho, en sus propias direcciones: las tablas se leen donde las lee el original |
| $C000-$DFFF | 6 | el programa: el juego, el display, los sprites, el panel |
| ($6000-$7FFF) | 7 | solo al arrancar: los juegos de caracteres, los tiles, los sprites de la aguja y del logotipo |
| $E000-$FFFF | 1 | búferes, tablas y la pila |

Cada fotograma (`src/river_raid.asm`):

1. `src/game.asm`, `prepare`: el tanque y su proyectil desaparecidos por debajo de la
   pantalla, el color del proyectil, las vidas, los puentes y la puntuación en los caracteres
   del panel (`Game::prepare`). El Next no escribe la memoria player-missile: las imágenes de
   los sprites y las filas de las colisiones salen de las formas de la ROM.
2. `src/display_simple.asm`, `src/display_hits.asm`: el trabajo del DLI, sin el DLI
   (`Game::displayGeometry` en la rama `dli_removed` del port a C++). Cada objeto está a la
   altura de su hueco, recortado al río; sus filas van a `ds_objs`. Las colisiones que lee el
   juego son pura geometría: primero los recuadros (contra los huecos de agua de cada línea,
   entre sí), luego los puntos, dondequiera que se toquen. El original las lee por ventanas,
   objeto a objeto: un 0,01–0,25% de los fotogramas decide distinto, un contacto un fotograma
   antes.
3. `src/sprites.asm`: lo que muestra el Atari se convierte en hardware del Next. Cada objeto
   (el player 3, cuyo color cambia en cada línea) es un sprite ya hecho con sus filas en sus
   colores, colocado en la posición del objeto. Los demás players y misiles también son un
   sprite cada uno, en la posición que les dio el juego. Todas sus imágenes son patrones de 4
   bits hechos una vez al arrancar a partir de las formas de la ROM (`src/obj_pics.asm`), así
   que un fotograma solo elige un patrón y escribe los atributos del sprite (un píxel del
   Atari son dos píxeles del sprite; el ancho doble y cuádruple es la escala del sprite). El
   color de la orilla cambia junto a un puente: el Copper lo fija por línea en la paleta del
   Layer 2.
4. `src/play.asm`, `main_loop`: el bucle principal (`Game::mainLoop`): los controles (el
   teclado y los joysticks, leídos como los del Atari), la pausa, un enemigo despertado cada
   16 fotogramas por el RANDOM del POKEY, el tanque, los objetos, el avión (combustible, giro,
   velocidad, la bala, a qué dio), el misil, el proyectil, START y SELECT, partidas nuevas,
   choques y aviones nuevos, y las líneas del río según la velocidad (`src/river_gen.asm`,
   `river_gen.cpp` línea a línea) escritas en el Layer 2. Mientras el original borra la memoria
   tras un choque o START (13 fotogramas) solo corren el display y el VBI, y el Layer 2 se borra
   a dos páginas por fotograma, desde el segundo fotograma del reinicio, y oculto mientras
   tanto (su ventana de recorte deja solo las filas del panel): el río se pone negro al
   instante, como en el port a C++, sin una franja que barra la pantalla.
5. `src/game.asm`, `vbi`: el controlador de sonido (`src/sound.asm`: los registros del POKEY),
   el contador de fotogramas, los colores del fotograma siguiente (el agua parpadea en rojo
   cuando se alcanza un puente), el contador del POKEY un fotograma adelante (una matriz,
   `src/random.inc`). Después `pokey_frame` (`src/sound.asm`) genera las muestras de la salida
   del POKEY para el DMA.
6. Bajo el texto desplazable (línea de raster 208) la nueva imagen se activa: el
   desplazamiento y los colores del Layer 2, los atributos de los sprites, el panel y el texto
   desplazable, la lista del Copper.

El panel y el texto desplazable son el tilemap (40 x 32, tiles de 8x8 a 4 bits por píxel):
cada carácter del Atari (8x8, un ciclo de color por píxel) son dos tiles, hechos al arrancar a
partir de los juegos de caracteres que el juego construye al encenderse (las letras y cifras
de la fuente del sistema operativo, los símbolos propios del cartucho); solo se escriben los
caracteres que cambian. El Copper mueve el tilemap a cada fila de caracteres; el texto
desplazable es un anillo en su fila del mapa, movido de lado por el desplazamiento X, y el
medio carácter que se ve en ambos bordes lo recorta a la derecha la ventana de recorte del
tilemap y lo muestra allí un sprite. El gris del panel es del Layer 2 (el Copper vuelve grises
sus colores en las líneas del panel), así que la aguja del combustible (un sprite) queda
encima de él y debajo de los caracteres, como en el Atari. El logotipo son cinco sprites.

El Layer 2 (320x256, 256 colores) guarda los índices de color de 2 bits del playfield; se
muestran 160 de los 192 ciclos de color de una línea (desde el 20.º; el agua nunca se acerca
más a los bordes), dos puntos cada uno, así que las proporciones son las del Atari con un
margen del 2%. Los colores son los colores PAL del port a C++ (el modelo de Altirra) como
entradas de 8 bits de la paleta del Next.
