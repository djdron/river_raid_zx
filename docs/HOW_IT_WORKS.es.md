# Cómo funciona River Raid en el ZX Spectrum Next

[English](HOW_IT_WORKS.md) | [Русский](HOW_IT_WORKS.ru.md) | [Українська](HOW_IT_WORKS.uk.md) | [Deutsch](HOW_IT_WORKS.de.md) | [Polski](HOW_IT_WORKS.pl.md) | [Italiano](HOW_IT_WORKS.it.md) | Español | [中文](HOW_IT_WORKS.zh.md) | [日本語](HOW_IT_WORKS.ja.md)

Esto es para cualquier curioso, sin necesidad de programar. Cómo funciona el juego en sí (el río, los enemigos, los puentes, por qué se vuelve más difícil) lo cuenta [docs/HOW_IT_WORKS.es.md](https://github.com/djdron/river_raid/blob/main/docs/HOW_IT_WORKS.es.md) del port a C++. Aquí: cómo se hacen la imagen del Atari y sus colisiones en otro ordenador, el ZX Spectrum Next.

## Dos máquinas distintas

El Atari 800 de 1979 tiene un procesador 6502 a 1,79 MHz; el Next, un Z80 a hasta 28 MHz. Ambos son ordenadores de 8 bits, pero sus chips de vídeo funcionan de forma muy distinta.

El **Atari** dibuja la pantalla línea a línea, como avanza el haz del televisor. Para las cosas que se mueven solo tiene ocho "sprites": cuatro **players** (de 8 puntos de ancho cada uno) y cuatro **missiles** (de 2 puntos cada uno). Ocho son demasiado pocos para el avión de River Raid, los cazas, los helicópteros, los barcos, los tanques, los globos, los depósitos de combustible y los puentes, así que el juego hace trampa: reutiliza un mismo player para cada enemigo a lo largo de la pantalla. Mientras el haz dibuja la pantalla, un pequeño trozo de código (la *display list interrupt*, DLI) despierta antes de cada objeto, mueve el player 3 al sitio del objeto, le da la forma y el color del objeto fila a fila y, cuando el objeto termina, baja ese mismo player hasta el objeto siguiente. Diez objetos en pantalla son en realidad un player, movido diez veces durante una imagen.

¿Qué es una DLI? Una *interrupción* es el hardware dando un toque en el hombro al procesador: el procesador deja lo que estaba haciendo, ejecuta un trozo corto de código y vuelve. El chip de vídeo del Atari sigue una *display list*, un pequeño programa que dice qué muestra cada franja de la pantalla. Cualquiera de sus líneas puede llevar una marca; cuando el haz llega a una línea marcada, el procesador se interrumpe: una display list interrupt. La DLI principal de River Raid empieza justo encima del río y retiene el procesador hasta el fondo del río. En cada línea espera al haz (el chip puede retener el procesador hasta que empiece la línea siguiente) y cambia el player 3 justo a tiempo. Solo entonces vuelve el procesador al juego.

El **Next** tiene un chip de vídeo mucho más generoso: una capa de fondo a todo color (*Layer 2*), hasta 128 sprites por hardware de 16×16 puntos, una capa de tiles para texto y un ayudante llamado *Copper* que puede cambiar colores en cualquier línea de la pantalla. No puede hacer lo que hace el Atari, reutilizar un sprite mientras se dibuja la imagen. Pero no lo necesita: sencillamente tiene suficientes sprites.

Así que el port no copia lo que hacen los chips del Atari. Copia **lo que el Atari muestra**, y luego construye la misma imagen con las piezas del Next.

## Cada fotograma, primero el trabajo del Atari

Cincuenta veces por segundo (sesenta en una máquina americana NTSC) el Next hace exactamente el trabajo que hacía el Atari para ese fotograma: hace avanzar el río, mueve a los enemigos, el avión, la bala, lee el joystick, cuenta el combustible y la puntuación. Lo guarda todo en la misma memoria, en los mismos sitios que el Atari. Eso es lo que lo hace comprobable: la copia de la memoria del Atari en el Next se puede comparar byte a byte, tras cada fotograma, con la de un Atari de verdad (un emulador suyo) y con el port a C++.

Después viene la imagen.

## El río

El río, sus orillas, islas, carreteras y casas son el **playfield** del Atari: el fondo. En el Atari cada línea del río son 48 bytes de memoria de pantalla, cuatro puntos por byte, cada punto de uno de cuatro colores: fondo (negro), orilla (verde o gris), borde de la orilla, agua (azul).

En el Next el río está en el Layer 2, una imagen de 320×256. Cada línea nueva de río que hace el juego se copia en una fila del Layer 2, cada punto del Atari como dos puntos del Next juntos (los puntos del Atari son anchos). Los colores no se guardan como colores sino como "color 1, 2 o 3", y la paleta del Next dice qué son los colores 1, 2 y 3. Así es como todo un río puede volverse rojo cuando se alcanza un puente: cambia una entrada de la paleta.

El río se desplaza hacia abajo. El Atari lo hace apuntando su pantalla a otra memoria; el Next diciéndole al Layer 2 que empiece a mostrar desde otra fila. Por cada línea de río se escribe solo una fila nueva; no se mueve nada de sitio.

Cerca de un puente el color de la orilla cambia de una línea a otra (la carretera). Eso lo hace el Copper: antes de que se dibuje una línea así, cambia el "color 1" de la paleta.

## Los enemigos: de un player a muchos sprites

El Next ya no reproduce la DLI del Atari, ni siquiera su horario. Cada enemigo simplemente está a la altura que le da su hueco, recortado donde el río empieza y termina. (La DLI del Atari podría en principio llegar a un objeto unas líneas tarde cuando viene demasiado cerca por debajo del anterior; medido en cientos de miles de fotogramas nunca ocurrió, así que la regla sencilla da la misma imagen.)

Cada objeto se convierte entonces en un sprite del Next ya hecho (dos si mide más de 16 líneas). El Atari cambia el color del player 3 en cada línea (así tienen rayas los enemigos); un sprite del Next puede tener un color propio en cada punto, así que las rayas simplemente se dibujan en él. Cada punto del Atari se convierte en dos puntos del sprite (los puntos del Atari son anchos), y el ancho doble o cuádruple es el sprite dibujado dos o cuatro veces más ancho. Un objeto que entra por arriba se dibuja entero y la parte por encima del río la recorta la ventana de recorte de los sprites.

Las imágenes de todos los enemigos (cada tipo, cada fotograma de animación, cada explosión, también en espejo) se hacen una vez al arrancar el programa: unas sesenta. Después cada fotograma solo dice qué imagen muestra cada sprite y dónde; durante el juego no se dibuja nada.

El avión, su bala, los tanques en las orillas, el proyectil del tanque y el misil del helicóptero usan los otros players y missiles del Atari, que tienen un color cada uno y se quedan en un mismo sitio toda la pantalla. El juego pone cada uno en una línea conocida (el avión siempre a la misma altura, el proyectil donde el tanque lo disparó...), así que cada uno es un sprite hecho con sus filas en ese sitio.

## Colisiones: quién tocó qué

En el Atari el juego nunca calcula las colisiones por sí mismo. Lo hace el chip de vídeo: mientras dibuja, cada vez que un punto de un player cae sobre un punto de color del playfield, o sobre un punto de otro player, pone un bit en un registro de colisión ("el player 2 tocó el color 1", "el missile 2 tocó el player 3"). La DLI lee estos registros después de cada objeto: así sabe el juego que la bala dio en este barco, que el avión chocó contra la orilla, que un caza llegó al borde y debe dar la vuelta.

Estos bits solo se ponen, el chip nunca los borra: se quedan hasta que el programa los borra todos de una vez (escribiendo en un registro llamado HITCLR). Y el player 3 es, por turnos, cada enemigo. Leídos una vez al final del fotograma, los registros solo dirían "el player 3 tocó algo", no qué barco. Así que después de cada objeto la DLI copia los registros en la memoria del juego, junto a ese objeto ("la bala dio en el objeto del hueco 5"), los borra y pasa el player 3 al objeto siguiente. El juego mira ahí más tarde.

El chip de vídeo del Next no tiene nada parecido, así que el Next lo calcula por su cuenta, y solo lo que lee el juego: el avión con la orilla, la bala con la orilla y con los objetos, los objetos con el borde de la orilla, el tanque con el borde, el misil del helicóptero con el avión y la orilla, el proyectil con el avión y los objetos.

El Next sí tiene un indicador por hardware de este tipo: "dos sprites se han solapado". Aquí no sirve. No dice qué sprites ni nada del río (las orillas están en el Layer 2, no son sprites). Con hasta sesenta sprites por fotograma, lo activarían sprites que el Atari nunca habría comparado (el logotipo, la aguja). Y solo se activa mientras el haz dibuja de verdad los sprites, un fotograma después, cuando el juego necesita saberlo en este.

Cada cosa que se mueve está donde la puso el juego, así que cada colisión es una pregunta sobre unas pocas líneas. Para cada sprite: en sus líneas, ¿tocan sus puntos la orilla (o el borde)? Para dos sprites: en las líneas en las que están ambos, ¿se encuentran sus puntos? El trabajo va "primero lo barato, lo exacto solo si hace falta": primero si sus recuadros se tocan siquiera; solo entonces los puntos, línea a línea: los puntos de cada línea alineados con los del otro (el procesador del Next puede desplazar una fila de puntos cualquier número de posiciones con una sola instrucción) y comparados todos a la vez (las formas tienen huecos por los que puede pasar una bala). Para un helicóptero, un globo o un barco contra el borde de la orilla bastan los extremos de cada una de sus filas: un borde entre ellos cuenta como contacto. La orilla se mira sin sus casas ni carreteras: entonces cada línea del río es solo orilla, borde, agua, borde, orilla (dos veces con una isla), un puñado de números guardados al hacer la línea. Y en River Raid el agua nunca es una colisión.

Aquí el Next ya no sigue los tiempos del Atari. La DLI del Atari lee los registros del chip justo después de cada objeto y los borra, así que solo ve un contacto dentro de una ventana de líneas; una bala que toca solo la última fila de un objeto, por ejemplo, cae entre dos ventanas y se cuenta un fotograma después, cuando la bala está más dentro. El Next cuenta un contacto dondequiera que ocurra. En más o menos un fotograma de cada mil (uno de cada cuatrocientos en los puentes lejanos, donde todos los huecos de enemigos están ocupados) esto decide distinto: siempre un impacto o un choque un fotograma antes que en el Atari. Nadie que juegue lo notaría, pero el juego ya no sigue al original fotograma a fotograma. Es el precio de la velocidad: el horario y sus lecturas se llevaban más de la mitad del trabajo de los fotogramas más cargados.

Lo que cuesta: colocar a los enemigos y todas las colisiones, unos 45 000 ciclos del procesador del Next en el fotograma más cargado, un 8% de una quincuagésima de segundo. La mayor parte se evita con "¿está siquiera cerca?": cada línea del río recuerda dónde empieza y termina su agua, así que un sprite o un enemigo bien dentro del agua se descarta con dos comparaciones, y solo de uno cerca de la orilla se miran los puntos. Cuando la DLI aún se reproducía con su horario y sus lecturas, el fotograma más cargado necesitaba unos 145 000 para esto; ciclo a ciclo, con los registros del chip emulados línea a línea, unos 210 000 de media.

## El panel y el texto desplazable

Bajo el río el Atari muestra un panel con letras grandes (puntuación, número de partida, indicador de combustible, récord, puente) y una línea que desplaza los créditos, con un logotipo arcoíris de Activision.

En el Next están hechos de *tiles*: pequeñas imágenes de 8×8 colocadas en una cuadrícula, como letras en una página. Al arrancar, el programa construye las propias letras del Atari (las que el juego hace con la fuente del ordenador y sus propios símbolos) y convierte cada una en dos tiles. Después, una letra del panel se escribe en la cuadrícula solo cuando cambia (una cifra de la puntuación, una vida). El texto desplazable es un anillo: toda la fila de tiles se desliza de lado dos puntos por fotograma, y solo la letra que entra por la derecha se escribe en la columna que acaba de salir por la izquierda. Como la capa de tiles es exactamente tan ancha como la pantalla, esa columna también se ve en el borde derecho; allí se oculta, y un único sprite muestra en su lugar la letra que entra.

El fondo gris del panel es la propia capa del río, con sus cuatro colores vueltos grises por el Copper para las líneas del panel, así que es exactamente tan ancho como el río, y la aguja del combustible (un sprite) aparece encima del gris pero debajo de las letras, como en el Atari. El logotipo arcoíris son cinco sprites.

La imagen del Next tiene 320 puntos de ancho: todo lo que puede dibujar está ahí dentro, y alrededor solo un color (el borde). La imagen del Atari es un poco más ancha: el río y el panel por 8 de sus píxeles a la izquierda, el texto desplazable por unas 3 de sus letras. Así que en el modo attract el texto desplazable sale cortado en los bordes. Una franja de color en el borde no ayudaría: ahí no puede ir ninguna imagen, y los aviones desaparecerían sobre ella.

## Sonido

El chip de sonido del Atari, el POKEY, tiene cuatro canales. Cada uno cuenta hacia atrás un reloj rápido (64 000 tics por segundo) desde un número que fija el juego, y cada vez que la cuenta se acaba da un pulso; lo que hace un pulso depende de otro ajuste: invertir la salida del canal (un tono limpio, más agudo cuanto menor es el número) o tomar un bit de uno de los registros de desplazamiento del POKEY, que dan un flujo de bits largo y de aspecto aleatorio (ruido: el motor, las explosiones). Cada canal tiene también un volumen. El propio juego solo fija estos números una vez por fotograma: el tono del motor según la velocidad, un silbido descendente para el proyectil del tanque, un siseo para una explosión.

El Next no tiene POKEY, pero tiene un DAC: un puerto donde un número se convierte en una tensión, así que un flujo de números es una onda de sonido. Así que el Next calcula él mismo la salida del POKEY, 15 909 números por segundo, unos 320 por fotograma, y los deja en un anillo de memoria. Enviarlos al DAC uno a uno, exactamente en los momentos justos, ocuparía todo el tiempo del procesador; en su lugar lo hace el DMA del Next, una pieza de hardware que por sí sola copia un byte de la memoria al puerto cada 1/15 909 de segundo, dando vueltas al anillo. El procesador solo tiene que mantener el anillo lleno un poco por delante y mantenerlo donde mira el DMA (el sonido es tan fuerte como el mezclador del Next deja ser a un DAC: más o menos la mitad que el del port a C++ con los mismos ajustes, el mismo sonido por debajo; y mono, como el del Atari): el DMA lee la memoria por las mismas ventanas que el procesador, y cuando el código ponía un momento otro trozo de memoria en la ventana del anillo, el DMA tocaba eso, un clic en cada fotograma.

Los tonos puros (los pitidos, el repostaje, el disparo, el silbido del proyectil) se saltan todo esto: el Next también tiene chips de sonido AY, que hacen exactamente esa onda cuadrada por sí mismos, así que esos canales del POKEY simplemente se pasan a un AY con el tono y el volumen convertidos. Solo los ruidos (el motor, las explosiones, el misil del helicóptero) se calculan para el DAC.

Calcular la onda tic a tic sería demasiado lento. En su lugar cada canal salta de pulso en pulso: sabe a cuántas muestras está su próximo pulso, y entre pulsos su salida no cambia. Donde la salida se enciende o se apaga, escribe "+ volumen" o "− volumen" en el anillo; al final una pasada los suma en la onda. Esto cuesta unos 25 000 ciclos del procesador por fotograma, un 4% de una quincuagésima de segundo; el más cargado (motor, explosión, disparo y un misil a la vez) más del doble. El anillo se mantiene unos dos fotogramas y medio por delante del DMA, así que un fotograma con mucho otro trabajo puede hacer menos números y dejar el resto a los siguientes; y cuando el juego tiene más trabajo que tiempo, cede el sonido, no el juego.

## Por qué no las interrupciones de línea del Next

El Next también puede interrumpir su procesador en cualquier línea de la pantalla que se elija. El port no lo usa, porque no necesita seguir al haz. Lo que hacía la DLI del Atari se calcula de antemano, como una cuenta, mientras todavía se muestra la imagen anterior. Lo que tiene que cambiar en una línea concreta de la pantalla real (el color de la carretera) se escribe en la lista del Copper, y el Copper, que nunca se salta una línea, lo hace; la lista solo se vuelve a enviar al Copper cuando cambia. El procesador solo tiene que vigilar en qué línea está el haz, para pasar al nuevo fotograma por debajo del texto desplazable, donde nada cambia en la pantalla (las interrupciones siguen desactivadas). El sonido, tocado muestra a muestra por el DAC del Next, tampoco las necesita: lo hace el DMA del Next sin el procesador (véase Sonido).

## Tiempo

Todo esto tiene que ocurrir en una quincuagésima de segundo. El Next va a 28 MHz, unas dieciséis veces más rápido que el Atari. Un fotograma medio ocupa ahora un 21% del tiempo que puede ocupar; el más cargado que se le puede imponer al programa (todos los huecos de enemigos ocupados, volando a toda velocidad y disparando todo el rato, en el puente 80), un 41%. Así que también funcionaría a 14 MHz.

No siempre fue así. Reproducir la DLI del Atari ciclo a ciclo, con sus registros de colisión emulados línea a línea, ocupaba de media un 60% del fotograma y hasta un 88%; en los puentes cargados un fotograma llegaba tarde a menudo. Después, paso a paso, primero en el port a C++ y comprobándolo cada vez con el original: se abandonaron los ciclos salvo unas pocas reglas; los enemigos pasaron a ser sprites multicolor ya hechos; los demás sprites se tomaron de donde los puso el juego en lugar de buscarlos; las colisiones se calcularon a partir de las filas de los sprites; el bucle de la DLI se convirtió en un horario; todas las imágenes de los sprites pasaron a hacerse al arrancar; el panel y el texto desplazable pasaron a escribirse solo donde cambian; y al final la DLI desapareció del todo, con las colisiones como pura geometría y "¿está siquiera cerca?" primero.

Adónde va ahora el tiempo en los fotogramas más cargados: las dos líneas nuevas del río en el Layer 2, unos 31 000 ciclos; el sonido, hasta 40 000; colocar a los enemigos y las colisiones, unos 45 000; los sprites, unos 13 000; el juego en sí, unos 14 000.

El programa pone él mismo el Next a 28 MHz. De ello solo depende la velocidad, no lo que pasa en el juego, y un fotograma que llega tarde simplemente se muestra dos veces. Todo Next y sus emuladores van a 28 MHz con un núcleo actual. A 28 MHz un Next real de vez en cuando hace esperar al procesador por la memoria; el núcleo del emulador en el que se midió la velocidad debería tenerlo en cuenta, pero no se ha comprobado en hardware real.

## Cómo sabemos que está bien

Cada cambio en lo que hace el juego se hace primero en el port a C++ y allí se compara con el juego original corriendo en un emulador de Atari: tras cada fotograma, toda la memoria del Atari (el río, cada objeto, la puntuación, el combustible, las colisiones), y el río tal como se dibuja contra la pantalla del original, punto por punto.

Después el Next: tras cada fotograma su copia de la memoria del Atari se compara con el port a C++, igual que los objetos que dibuja, los colores de la orilla línea a línea y la lista del Copper; al final, la imagen entera, punto por punto. Cientos de miles de fotogramas de partidas de un jugador robot sencillo, en PAL y NTSC, desde el primer puente hasta el puente 200 (al robot se le puede hacer incapaz de chocar, en ambos lados, para llegar tan lejos), son iguales.

Se conoce una diferencia con el original, y es elegida: las colisiones (arriba, un impacto o un choque un fotograma antes en más o menos un fotograma de cada mil). La manera propia del Atari se conserva en el port a C++, que todavía puede comprobarse contra el original.
