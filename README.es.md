# River Raid para los ZX Spectrum modernos

[English](README.md) | [Русский](README.ru.md) | [Українська](README.uk.md) | [Deutsch](README.de.md) | [Polski](README.pl.md) | [Italiano](README.it.md) | Español | [中文](README.zh.md) | [日本語](README.ja.md)

River Raid (Activision, Atari 8-bit, 1983, de Carol Shaw) en las máquinas ZX Spectrum de hoy:
el **ZX Spectrum Next** y **TS-Conf** (ZX Evolution / Pentevo). Ambos ports se basan en el
port a C++ de [djdron/river_raid](https://github.com/djdron/river_raid), que averigua cómo lo
hace todo el original y está contrastado con él fotograma a fotograma. La lógica del juego es
la del original, fotograma a fotograma, en la misma RAM y en las mismas direcciones; cada
máquina la muestra con su propio hardware.

Un proyecto de aficionados no oficial con fines educativos, sin relación con Activision ni con
Microsoft. El juego no está incluido: el programa lee en tiempo de ejecución tu propia imagen
del cartucho.

## Los ports

| | [ZX Spectrum Next](NEXT.es.md) | [TS-Conf](tsconf/README.es.md) (ZX Evolution / Pentevo) |
|---|---|---|
| Archivo | `river_raid.nex` (se abre desde el Browser) | `river_raid.spg` (se arranca desde Wild Commander) |
| La ROM | `River_Raid.rom` en la misma carpeta que el .nex | `River_Raid.rom` en cualquier lugar de la tarjeta SD (FAT16/32) |
| El río | Layer 2, el color de la orilla por línea mediante el Copper | el modo de 16 colores con desplazamiento por hardware, el color de la orilla por línea mediante la INT de cuadro (una paleta por color) |
| Enemigos, avión, misiles | sprites | sprites |
| Panel, texto desplazable | el tilemap | una imagen propia activada bajo el río, tiles, sprites |
| El sonido | POKEY emulado por el programa hacia el DAC (zxnDMA), los tonos puros en el AY | todo en una General Sound (POKEY emulado por el propio Z80 de la tarjeta, mono); sin ella, los tonos puros en los AY del TurboSound |
| CPU | 28 MHz (cabe también en 14) | 14 MHz (cabe también en 7) |
| TV | PAL 50 Hz o NTSC 60 Hz (CAPS + 1) | PAL 50 Hz |
| Detalles | [NEXT.es.md](NEXT.es.md) | [tsconf/README.es.md](tsconf/README.es.md) |

El juego está completo en ambos: el modo attract, las partidas 1-8 (salida en el puente 1, 5,
20 o 50; un jugador o dos por turnos), el avión, el combustible y los depósitos, los enemigos,
los tanques, los misiles de los helicópteros, los puentes, la puntuación, las vidas, el récord,
la pausa, el panel y el texto desplazable con el logotipo arcoíris. Ninguno se ha ejecutado aún
en hardware real: ambos se comprueban en el emulador
[Xpeccy+](https://github.com/dotkoval/xpeccy-plus) (sus núcleos Next y TSConf).

## Dónde conseguirlo

Los programas se compilan en GitHub con cada push: [Actions](https://github.com/djdron/river_raid_zx/actions),
el workflow `build` (el .nex) o `tsconf` (el .spg), su artefacto. Necesitas tu propio
`River_Raid.rom`: la imagen del cartucho, 8192 bytes, sin cabecera (como la usa el port a
C++). Sin ella el borde se vuelve rojo.

## Controles

| | Teclado | Joystick |
|---|---|---|
| volar | Q A O P | Kempston |
| disparar | Espacio o M | disparo |
| START | Enter | (Next: START en un mando Mega Drive) |
| SELECT (la partida, 1-8) | G | (Next: A en un mando Mega Drive) |
| pausa | H | |

El Next tiene algunas teclas más (PAL/NTSC, el sonido, la velocidad de la CPU, el tiempo del
fotograma en el borde): [NEXT.es.md](NEXT.es.md).

## Cómo se comprueba

Todo lo que cambia lo que hace el juego se hace primero en el port a C++, luego en el Next y
luego en la copia del mismo código en el port a TS-Conf. Cada port tiene una comprobación que
ejecuta el programa en el núcleo de Xpeccy+ sin ventana, junto al port a C++ con la misma
entrada y el mismo contador POKEY, y los compara tras cada fotograma: el estado del juego, el
generador del río, el panel y la imagen píxel a píxel (`make check`, `make -C tsconf check`; un
jugador inventado juega cientos de miles de fotogramas). El programa del Next se compara además
con el propio cartucho original, ejecutado en libatari800 (`make check-original`).

## Compilación

```
make deps          # sjasmplus, el port a C++ y Xpeccy+ en deps/ (git, un compilador C/C++, make, cmake, zlib)
make               # build/river_raid.nex
make -C tsconf     # tsconf/build/river_raid.spg
```

Para compilar basta con sjasmplus; las comprobaciones necesitan el resto y tu ROM en `rom/River_Raid.rom`.

## El repositorio

| Ruta | Qué |
|---|---|
| `src/`, `tools/`, `Makefile` | el programa para el ZX Spectrum Next y sus comprobaciones ([NEXT.es.md](NEXT.es.md)) |
| `tsconf/` | el port a TS-Conf: proyecto y compilación propios, el código del juego copiado de `src/` ([tsconf/README.es.md](tsconf/README.es.md)) |
| [docs/HOW_IT_WORKS.es.md](docs/HOW_IT_WORKS.es.md) | cómo se hacen en el Next la imagen y las colisiones del Atari, para todos |
| [docs/NOTES.es.md](docs/NOTES.es.md) | cómo está hecho el programa del Next y qué se descubrió, con cifras |
| [docs/CODE.md](docs/CODE.md) | el código fuente en ensamblador del Next, rutina a rutina (en inglés y en ruso) |
| [tsconf/CODE.md](tsconf/CODE.md) | el código fuente en ensamblador de TS-Conf, rutina a rutina, y en qué se diferencian las dos máquinas (en inglés y en ruso) |
| [HANDOFF.es.md](HANDOFF.es.md) | el estado del proyecto, para retomar el trabajo |

## Licencia

El código y la documentación propios del proyecto están bajo la licencia MIT, véase
[LICENSE](LICENSE). `src/palette.inc` y `tsconf/src/palette_ts.inc` se generan a partir del
modelo de paleta del port a C++ (MIT). `src/font.inc` y `tsconf/src/font.inc` son la fuente de
AltirraOS (Copyright (C) 2008-2018 Avery Lee; se puede copiar y distribuir con su aviso, que los
archivos conservan), tal como la tiene el port a C++: la ROM del sistema operativo de Atari no
forma parte del cartucho. Las comprobaciones usan
[Xpeccy+](https://github.com/dotkoval/xpeccy-plus) (MIT) y el ensamblador
[sjasmplus](https://github.com/z00m128/sjasmplus) (BSD-3); ninguno está incluido, `make deps`
los descarga. River Raid en sí (la ROM, su código, gráficos y sonido) pertenece a sus titulares
de derechos y no está cubierto por esta licencia.
