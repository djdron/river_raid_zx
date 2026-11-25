# River Raid para TS-Conf

[English](README.md) | [Русский](README.ru.md) | [Українська](README.uk.md) | [Deutsch](README.de.md) | [Polski](README.pl.md) | [Italiano](README.it.md) | Español | [中文](README.zh.md) | [日本語](README.ja.md)

El port a TS-Conf (ZX Evolution / Pentevo): un proyecto propio con su propia compilación,
aparte del del ZX Spectrum Next ([NEXT.es.md](../NEXT.es.md); ambos: [la página
principal](../README.es.md)). Solo comparte `../deps` (sjasmplus, el port a C++, Xpeccy+:
`make deps` en la raíz).

El juego funciona como en el Next (la misma lógica, el mismo display y generador del río,
copiados en `src/`), mostrado a la manera del TS-Conf. Solo 50 Hz (PAL): el cuadro de la placa.

Cómo funciona en las dos máquinas, para todos: [../docs/HOW_IT_WORKS.es.md](../docs/HOW_IT_WORKS.es.md).

Cómo está hecho en esta placa y qué se descubrió, con cifras: [NOTES.es.md](NOTES.es.md).

El código fuente rutina a rutina, qué cambió en el código compartido con el Next y una tabla de en qué se diferencian las dos máquinas: [CODE.es.md](CODE.es.md).

- El río: el modo de 16 colores, 320x240, una línea de imagen de 256 bytes (160 al principio),
  512 líneas en anillo desplazadas por el hardware (GYOFFS); una línea nueva del río se escribe
  directamente en su fila (`render.asm`), sin copias.
- El color de la orilla por línea: una paleta (PALSEL 0) guarda los colores de la orilla, los
  dos verdes y los de la carretera del puente (entradas 1 y 9-15, puestas una vez al arrancar),
  con 2 y 3 el borde y el agua; los puntos de orilla de cada línea nueva se dibujan en la
  entrada de su color (`line_bank`, calculado solo en un puente; por línea no se conmuta nada), así el color va
  con la línea: ninguna INT por cambio, nada que poner mientras se muestra la imagen.
- Los objetos, el avión, su bala, el tanque y los misiles: sprites (`sprites.asm`), sus
  imágenes hechas al arrancar a partir de las formas del cartucho, cada objeto de 16, 32 y 64
  puntos de ancho (los sprites no tienen escala).
- El panel y el texto desplazable (`panel_ts.asm`): las filas 184-239 vienen de una imagen
  propia, que la INT de cuadro pone en la fila 184 (VPAGE, GYOFFS) en el modo de 256 colores
  con el bitmap por encima de tiles y sprites (GFXOVR); la capa de tiles 0 es el gris bajo los
  caracteres (allí oculta los sprites del río); la aguja y el logotipo son sprites encima. Los
  caracteres se dibujan una vez al arrancar y los copia el DMA; el texto desplazable es un anillo
  de 32 caracteres sobre los 512 puntos de la imagen, mostrado desde GXOFFS.
- La capa de tiles 0 también es el negro por encima del río.
- Los controles: Q A O P, Espacio o M para disparar, Enter START, G SELECT, H pausa, T el trabajo del fotograma en el borde (un color por parte, como en la Next); Kempston.
- El sonido: todo en una General Sound (la tarjeta original o una NeoGS), si la hay: el propio
  Z80 de la tarjeta toca el POKEY como lo hace el DAC del Next (`gs/`, el `pokey_frame` del Next
  y sus pulsos, los bits del contador de 17 bits los genera la propia tarjeta a partir de su
  recurrencia), en mono (las mismas muestras a los cuatro canales: 1 y 2 izquierdo, 3 y 4 derecho), a
  15 820 muestras por segundo (su INT, 37 500 por segundo, toma 108 de cada 256). El arranque
  carga el programa en la tarjeta mediante su firmware (`gs_load.asm`; ejecutado otra vez,
  encuentra el programa todavía allí); después el apply envía los registros del POKEY una vez
  por fotograma (`sound_gs.asm`). Sin tarjeta (o si no responde): solo los tonos puros (el
  motor, los pitidos, el disparo, la bonificación, el silbido del proyectil) en los dos AY del
  TurboSound, como los toca el Next (`sound_ay.asm`): los canales 1 y 2 del POKEY en A y B del
  segundo chip, 3 y 4 en B y C del primero. En Xpeccy: activa la General Sound (y el TurboSound
  NedoPC para los AY).

A 14 MHz el trabajo de un fotograma ocupa de media ~65 000 ciclos en el modo attract, ~108 000
a toda velocidad disparando siempre desde el puente 80 (-stress), ~178 000 como máximo, de
~287 000; a 7 MHz todavía cabe, por poco (~125 000 como máximo con -stress, de ~143 400; ningún
fotograma se retrasa); a 3,5 MHz no da abasto.

Memoria (ventanas de 16K): $0000 la RAM del Atari (página 1; durante el arranque la página 3 con
su trabajo), $4000 las secuencias de las líneas y los búferes, la fuente del sistema operativo
desde $7D00 (página 5; `render_line` pone ahí una página de la imagen mientras dibuja), $8000
el programa y el cartucho desde $A000 (página 2), $C000 el programa, los búferes y la pila
(página 6); la imagen del río desde la página 32, la del panel desde la 64, el mapa de tiles en
la página 7, los puntos de los tiles en la página 8, los de los sprites desde la 24.

    make          build/river_raid.spg: el programa para Wild Commander (SPG 1.0); encuentra él
                  mismo River_Raid.rom en la tarjeta SD (abajo)
    make sna      build/river_raid.sna: una instantánea de 128K con tu ROM dentro (../rom/River_Raid.rom)
    make check    ejecuta la compilación de prueba en el núcleo TSConf de Xpeccy+ y la compara
                  con el port a C++ fotograma a fotograma: el estado y la imagen de cada
                  fotograma (FRAMES=... cuántos, 3000 por defecto) y, con una General Sound (la
                  de Xpeccy+, firmware gs105b.rom), los registros que recibe la tarjeta
    make palette  vuelve a escribir src/palette_ts.inc (los colores del port a C++ en los niveles de la placa)

`build/tools/tscheck` también juega: `-bot N` (el jugador inventado de nxcheck), `-stress`,
`-start N`; TSBRIDGE, TSGHOST, NXGAME como en nxcheck; TSSPEED=1 a 7 MHz; TSBORDER=1 T encendido (TSFULL=1 con TSSHOT=k: los fotogramas con el borde); TSGS=neo una NeoGS,
TSGS=0 sin tarjeta (se comprueban los tonos del AY); TSWAV=archivo, TSWAVCPP=archivo las
muestras de la tarjeta y el POKEY del port a C++ a esa frecuencia (WAV para escuchar).

El .spg también se compila en GitHub (el workflow `tsconf`: su artefacto). Pon River_Raid.rom
(la imagen del cartucho, 8192 bytes) en cualquier lugar de la tarjeta SD: el programa la busca
al arrancar (`load_rom.asm`: su primera partición o la tarjeta entera, FAT16 o FAT32, primero
la raíz, luego sus carpetas, hasta 8 niveles; el nombre largo con cualquier combinación de
mayúsculas o el corto RIVER_~1.ROM). Sin ella: un borde rojo. Mientras trabaja el arranque la
pantalla está negra (`screen_black`: toda la CRAM negra de golpe, sea cual sea el modo que dejó
Wild Commander: su pantalla ZX en la página 5 es justo donde el arranque pone sus búferes).

`build/tools/tscheck -spg build/river_raid.spg 600 out.ppm -sd carpeta` ejecuta el .spg con una
carpeta del anfitrión como tarjeta SD (`-img archivo`: la imagen de una tarjeta); `-sna
build/river_raid.sna 600 out.ppm` la instantánea.
