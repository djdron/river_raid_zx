# Come funziona River Raid sullo ZX Spectrum Next

[English](HOW_IT_WORKS.md) | [Русский](HOW_IT_WORKS.ru.md) | [Українська](HOW_IT_WORKS.uk.md) | [Deutsch](HOW_IT_WORKS.de.md) | [Polski](HOW_IT_WORKS.pl.md) | Italiano | [Español](HOW_IT_WORKS.es.md) | [中文](HOW_IT_WORKS.zh.md) | [日本語](HOW_IT_WORKS.ja.md)

Per chiunque sia curioso, senza bisogno di saper programmare. Come funziona il gioco in sé (il fiume, i nemici, i ponti, perché diventa più difficile) lo racconta [docs/HOW_IT_WORKS.it.md](https://github.com/djdron/river_raid/blob/main/docs/HOW_IT_WORKS.it.md) del port in C++. Qui: come l'immagine dell'Atari e le sue collisioni si ottengono su un computer diverso, lo ZX Spectrum Next.

## Due macchine diverse

L'Atari 800 del 1979 ha un processore 6502 a 1,79 MHz; il Next uno Z80 fino a 28 MHz. Sono entrambi computer a 8 bit, ma i loro chip video funzionano in modo molto diverso.

L'**Atari** disegna lo schermo riga per riga, come procede il raggio del televisore. Per le cose in movimento ha solo otto "sprite": quattro **player** (larghi 8 punti ciascuno) e quattro **missile** (larghi 2 punti ciascuno). Otto sono troppo pochi per l'aereo di River Raid, i jet, gli elicotteri, le navi, i carri armati, le mongolfiere, i depositi di carburante e i ponti, quindi il gioco bara: riusa un solo player per ogni nemico lungo lo schermo. Mentre il raggio disegna lo schermo, un piccolo pezzo di codice (il *display list interrupt*, DLI) si sveglia prima di ogni oggetto, sposta il player 3 al posto dell'oggetto, gli dà la forma e il colore dell'oggetto riga per riga e, quando l'oggetto è finito, sposta lo stesso player più in basso, all'oggetto successivo. Dieci oggetti sullo schermo sono in realtà un solo player, spostato dieci volte durante un'immagine.

Che cos'è un DLI? Un *interrupt* è l'hardware che dà un colpetto sulla spalla al processore: il processore mette giù ciò che stava facendo, esegue un breve pezzo di codice e torna indietro. Il chip video dell'Atari segue una *display list*, un piccolo programma che dice cosa mostra ogni fascia dello schermo. Qualsiasi sua riga può portare un segno; quando il raggio raggiunge una riga segnata, il processore viene interrotto: un display list interrupt. Il DLI principale di River Raid comincia appena sopra il fiume e tiene il processore fino al fondo del fiume. A ogni riga aspetta il raggio (il chip può trattenere il processore fino all'inizio della riga successiva) e cambia il player 3 giusto in tempo. Solo dopo il processore torna al gioco.

Il **Next** ha un chip video molto più generoso: un livello di sfondo a colori pieni (*Layer 2*), fino a 128 sprite hardware di 16×16 punti, un livello di tile per il testo e un aiutante chiamato *Copper* che può cambiare i colori a qualsiasi riga dello schermo. Non sa fare ciò che fa l'Atari, cioè riusare uno sprite mentre l'immagine viene disegnata. Ma non ne ha bisogno: ha semplicemente abbastanza sprite.

Così il port non copia ciò che fanno i chip dell'Atari. Copia **ciò che l'Atari mostra**, poi costruisce la stessa immagine con i pezzi del Next.

## Ogni fotogramma, prima il lavoro dell'Atari

Cinquanta volte al secondo (sessanta su una macchina americana NTSC) il Next fa esattamente il lavoro che l'Atari faceva per quel fotogramma: fa avanzare il fiume, muove i nemici, l'aereo, il proiettile, legge il joystick, conta carburante e punteggio. Tiene tutto nella stessa memoria, negli stessi posti in cui lo teneva l'Atari. È questo che lo rende verificabile: la copia della memoria dell'Atari nel Next si può confrontare byte per byte, dopo ogni fotogramma, con quella di un Atari vero (un suo emulatore) e con il port in C++.

Poi viene l'immagine.

## Il fiume

Il fiume, le sue rive, le isole, le strade e le case sono il **playfield** dell'Atari: lo sfondo. Sull'Atari ogni riga del fiume è di 48 byte di memoria dello schermo, quattro punti per byte, ogni punto di uno di quattro colori: sfondo (nero), riva (verde o grigia), bordo della riva, acqua (blu).

Sul Next il fiume sta nel Layer 2, un'immagine di 320×256. Ogni nuova riga di fiume che il gioco produce viene copiata in una riga del Layer 2, ogni punto dell'Atari come due punti del Next affiancati (i punti dell'Atari sono larghi). I colori non vengono memorizzati come colori ma come "colore 1, 2 o 3", e la palette del Next dice quali sono i colori 1, 2 e 3. Così un fiume intero può diventare rosso quando un ponte viene colpito: cambia una voce della palette.

Il fiume scorre verso il basso. L'Atari lo fa puntando il suo display su un'altra memoria; il Next dicendo al Layer 2 di cominciare a mostrare da un'altra riga. Per ogni riga di fiume si scrive una sola riga nuova; non si sposta niente.

Vicino a un ponte il colore della riva cambia da una riga all'altra (la strada). Lo fa il Copper: prima che una riga del genere venga disegnata, cambia il "colore 1" della palette.

## I nemici: da un player a molti sprite

Il Next non riproduce più il DLI dell'Atari, nemmeno il suo orario. Ogni nemico sta semplicemente all'altezza che gli dà il suo slot, tagliato dove il fiume comincia e finisce. (Il DLI dell'Atari potrebbe in linea di principio raggiungere un oggetto qualche riga in ritardo quando arriva troppo vicino sotto il precedente; misurato su centinaia di migliaia di fotogrammi non è mai successo, quindi la regola semplice dà la stessa immagine.)

Ogni oggetto diventa poi uno sprite del Next già pronto (due se è più alto di 16 righe). L'Atari cambia il colore del player 3 a ogni riga (è così che i nemici hanno le strisce); uno sprite del Next può avere un colore proprio in ogni punto, quindi le strisce vengono semplicemente disegnate dentro. Ogni punto dell'Atari diventa due punti dello sprite (i punti dell'Atari sono larghi), e la larghezza doppia o quadrupla è lo sprite disegnato due o quattro volte più largo. Un oggetto che entra dall'alto viene disegnato intero e la parte sopra il fiume viene tagliata dalla finestra di clip degli sprite.

Le immagini di tutti i nemici (ogni tipo, ogni fotogramma dell'animazione, ogni esplosione, anche specchiate) si creano una volta all'avvio del programma: una sessantina. Ogni fotogramma poi dice soltanto quale immagine mostra ogni sprite e dove; durante il gioco non si disegna niente.

L'aereo, il suo proiettile, i carri armati sulle rive, il colpo del carro e il missile dell'elicottero usano gli altri player e missile dell'Atari, che hanno un colore ciascuno e restano in un posto per tutto lo schermo. Il gioco mette ciascuno a una riga nota (l'aereo sempre alla stessa altezza, il colpo dove il carro lo ha sparato...), quindi ciascuno è uno sprite fatto con le sue righe lì.

## Collisioni: chi ha toccato cosa

Sull'Atari il gioco non calcola mai le collisioni da sé. Lo fa il chip video: mentre disegna, ogni volta che un punto di un player cade su un punto colorato del playfield, o sul punto di un altro player, imposta un bit in un registro di collisione ("il player 2 ha toccato il colore 1", "il missile 2 ha toccato il player 3"). Il DLI legge questi registri dopo ogni oggetto: è così che il gioco sa che il proiettile ha colpito proprio questa nave, che l'aereo è finito contro la riva, che un jet ha raggiunto il bordo e deve girarsi.

Questi bit vengono solo impostati, il chip non li azzera mai: restano finché il programma non li azzera tutti insieme (scrivendo in un registro chiamato HITCLR). E il player 3 è, a turno, ogni nemico. Letti una volta alla fine del fotogramma, i registri direbbero solo "il player 3 ha toccato qualcosa", non quale nave. Così dopo ogni oggetto il DLI copia i registri nella memoria del gioco, accanto a quell'oggetto ("il proiettile ha colpito l'oggetto nello slot 5"), li azzera e sposta il player 3 all'oggetto successivo. Il gioco guarda lì più tardi.

Il chip video del Next non ha niente del genere, quindi il Next lo calcola da sé, e solo ciò che il gioco legge: l'aereo con la riva, il proiettile con la riva e con gli oggetti, gli oggetti con il bordo della riva, il carro armato con il bordo, il missile dell'elicottero con l'aereo e la riva, il colpo del carro con l'aereo e gli oggetti.

Il Next ha un unico flag hardware di questo tipo: "due sprite si sono sovrapposti". Qui non serve. Non dice né quali sprite né nulla del fiume (le rive sono nel Layer 2, non sprite). Con fino a sessanta sprite per fotogramma, lo imposterebbero sprite che l'Atari non avrebbe mai confrontato (il logo, la lancetta). E si imposta solo mentre il raggio disegna davvero gli sprite, un fotogramma dopo, quando il gioco deve saperlo in questo.

Ogni cosa che si muove sta dove il gioco l'ha messa, quindi ogni collisione è una domanda su poche righe. Per ogni sprite: sulle sue righe, i suoi punti toccano la riva (o il bordo)? Per due sprite: sulle righe in cui ci sono entrambi, i loro punti si incontrano? Il lavoro va "prima il poco costoso, l'esatto solo se serve": prima se i loro riquadri si incontrano; solo dopo i punti, una riga alla volta: i punti di ogni riga allineati a quelli dell'altro (il processore del Next può spostare una fila di punti di un numero qualsiasi di posizioni con una sola istruzione) e confrontati tutti insieme (le forme hanno varchi da cui può passare un proiettile). Per un elicottero, una mongolfiera o una nave contro il bordo della riva bastano le estremità di ciascuna sua riga: un bordo in mezzo conta come contatto. La riva si guarda senza case e strade: allora ogni riga del fiume è solo riva, bordo, acqua, bordo, riva (due volte con un'isola), una manciata di numeri conservati quando la riga è stata fatta. E in River Raid l'acqua non è mai una collisione.

Qui il Next non segue più i tempi dell'Atari. Il DLI dell'Atari legge i registri del chip subito dopo ogni oggetto e li azzera, quindi vede un contatto solo entro una finestra di righe; un proiettile che tocca solo l'ultima riga di un oggetto, per esempio, cade tra due finestre e viene contato un fotogramma dopo, quando il proiettile è più dentro. Il Next conta un contatto ovunque avvenga. In circa un fotogramma su mille (uno su quattrocento ai ponti lontani, dove ogni slot dei nemici è occupato) questo decide diversamente: sempre un colpo o uno schianto un fotogramma prima che sull'Atari. Nessun giocatore se ne accorgerebbe, ma il gioco non segue più l'originale fotogramma per fotogramma. È il prezzo della velocità: l'orario e le sue letture richiedevano più di metà del lavoro dei fotogrammi più carichi.

Quanto costa: il posizionamento dei nemici e tutte le collisioni circa 45 000 cicli del processore del Next nel fotogramma più carico, circa l'8% di un cinquantesimo di secondo. La maggior parte si evita con "è almeno vicino?": ogni riga del fiume ricorda dove la sua acqua comincia e finisce, quindi uno sprite o un nemico ben dentro l'acqua viene scartato con due confronti, e solo per uno vicino alla riva si guardano i punti. Quando il DLI veniva ancora riprodotto con il suo orario e le sue letture, il fotogramma più carico ne richiedeva circa 145 000; ciclo per ciclo, con i registri del chip emulati riga per riga, circa 210 000 in media.

## Il pannello e la scritta scorrevole

Sotto il fiume l'Atari mostra un pannello a lettere grandi (punteggio, numero della partita, indicatore del carburante, record, ponte) e una riga che fa scorrere i titoli, con un logo Activision arcobaleno.

Sul Next questi sono fatti di *tile*: piccole immagini 8×8 disposte in una griglia, come le lettere su una pagina. All'avvio il programma costruisce le lettere dell'Atari (quelle che il gioco ricava dal font del computer e dai propri simboli) e trasforma ciascuna in due tile. Poi una lettera del pannello si scrive nella griglia solo quando cambia (una cifra del punteggio, una vita). La scritta scorrevole è un anello: tutta la riga di tile scivola di lato di due punti a fotogramma, e solo la lettera che entra da destra si scrive nella colonna appena uscita a sinistra. Poiché il livello dei tile è largo esattamente quanto lo schermo, quella colonna si vede anche sul bordo destro; lì viene nascosta, e al suo posto un solo sprite mostra la lettera che entra.

Lo sfondo grigio del pannello è il livello del fiume stesso, con i suoi quattro colori resi grigi dal Copper per le righe del pannello, quindi è largo esattamente quanto il fiume, e la lancetta del carburante (uno sprite) appare sopra il grigio ma sotto le lettere, come sull'Atari. Il logo arcobaleno è fatto di cinque sprite.

L'immagine del Next è larga 320 punti: tutto ciò che può disegnare sta lì dentro, e intorno c'è un solo colore (il bordo). L'immagine dell'Atari è un po' più larga: il fiume e il pannello di 8 suoi pixel a sinistra, la scritta scorrevole di circa 3 sue lettere. Così nella modalità attract il testo scorrevole è tagliato ai bordi. Una striscia di colore nel bordo non aiuterebbe: lì non può andare nessuna immagine, e gli aerei sparirebbero sopra di essa.

## Suono

Il chip audio dell'Atari, il POKEY, ha quattro canali. Ciascuno conta all'indietro un clock veloce (64 000 tick al secondo) da un numero che imposta il gioco, e ogni volta che il conteggio finisce dà un impulso; cosa fa un impulso dipende da un'altra impostazione: invertire l'uscita del canale (un tono pulito, più acuto quanto più piccolo è il numero) oppure prendere un bit da uno dei registri a scorrimento del POKEY, che danno un lungo flusso di bit dall'aria casuale (rumore: il motore, le esplosioni). Ogni canale ha anche un volume. Il gioco stesso imposta questi numeri solo una volta a fotogramma: l'altezza del motore dalla velocità, un fischio discendente per il colpo del carro, un sibilo per un'esplosione.

Il Next non ha un POKEY, ma ha un DAC: una porta in cui un numero diventa una tensione, quindi un flusso di numeri è un'onda sonora. Così il Next calcola da sé l'uscita del POKEY, 15 909 numeri al secondo, circa 320 a fotogramma, e li lascia in un anello di memoria. Mandarli al DAC uno per uno, esattamente nei momenti giusti, occuperebbe tutto il tempo del processore; lo fa invece il DMA del Next, un pezzo di hardware che da solo copia un byte dalla memoria alla porta ogni 1/15 909 di secondo, girando e rigirando sull'anello. Il processore deve solo tenere l'anello riempito un po' in anticipo e tenerlo dove guarda il DMA (il suono è forte quanto il mixer del Next lascia essere un DAC: circa metà di quello del port in C++ con le stesse impostazioni, lo stesso suono sotto; e mono, come quello dell'Atari): il DMA legge la memoria attraverso le stesse finestre del processore, e quando il codice metteva per un attimo un altro pezzo di memoria nella finestra dell'anello, il DMA suonava quello, un clic a ogni fotogramma.

I toni puri (i bip, il rifornimento, lo sparo, il fischio del colpo) saltano tutto questo: il Next ha anche chip audio AY, che producono da sé esattamente quell'onda quadra, quindi quei canali del POKEY vengono semplicemente passati a un AY con altezza e volume convertiti. Solo i rumori (il motore, le esplosioni, il missile dell'elicottero) vengono calcolati per il DAC.

Calcolare l'onda tick per tick sarebbe troppo lento. Invece ogni canale salta da un impulso all'altro: sa a quanti campioni di distanza è il suo prossimo impulso, e tra un impulso e l'altro la sua uscita non cambia. Dove l'uscita si accende o si spegne, scrive "+ volume" o "− volume" nell'anello; alla fine un solo passaggio li somma nell'onda. Costa circa 25 000 cicli del processore a fotogramma, il 4% di un cinquantesimo di secondo; il più carico (motore, esplosione, sparo e un missile insieme) più del doppio. L'anello è tenuto circa due fotogrammi e mezzo davanti al DMA, quindi un fotogramma con molto altro lavoro può fare meno numeri e lasciare il resto ai successivi; e quando il gioco ha più lavoro che tempo, cede il suono, non il gioco.

## Perché non gli interrupt di riga del Next

Anche il Next può interrompere il suo processore a una qualsiasi riga dello schermo. Il port non lo usa, perché non ha bisogno di stare al passo con il raggio. Ciò che faceva il DLI dell'Atari si calcola in anticipo, come un conto, mentre l'immagine precedente è ancora mostrata. Ciò che deve cambiare a una certa riga dello schermo vero (il colore della strada) si scrive nella lista del Copper, e il Copper, che non perde mai una riga, lo fa; la lista viene rimandata al Copper solo quando cambia. Il processore deve solo guardare a che riga è il raggio, per passare al nuovo fotogramma sotto la scritta scorrevole, dove sullo schermo non cambia niente (gli interrupt restano spenti). Nemmeno il suono, suonato campione per campione attraverso il DAC del Next, ne ha bisogno: lo fa il DMA del Next senza il processore (vedi Suono).

## Tempo

Tutto questo deve avvenire entro un cinquantesimo di secondo. Il Next va a 28 MHz, circa sedici volte più veloce dell'Atari. Un fotogramma medio ora occupa circa il 21% del tempo concesso; il più carico che si possa imporre al programma (ogni slot dei nemici occupato, volando a tutta velocità e sparando sempre, al ponte 80) circa il 41%. Quindi girerebbe anche a 14 MHz.

Non è stato sempre così. Riprodurre il DLI dell'Atari ciclo per ciclo, con i suoi registri di collisione emulati riga per riga, richiedeva in media circa il 60% del fotogramma e fino all'88%; ai ponti affollati un fotogramma era spesso in ritardo. Poi, passo dopo passo, prima nel port in C++ e verificando ogni volta con l'originale: i cicli sono stati abbandonati tranne poche regole; i nemici sono diventati sprite multicolori già pronti; gli altri sprite si prendevano dove il gioco li aveva messi invece di cercarli; le collisioni si calcolavano dalle righe degli sprite; il ciclo del DLI è diventato un orario; tutte le immagini degli sprite si sono fatte all'avvio; il pannello e la scritta scorrevole si scrivevano solo dove cambiano; e infine il DLI è sparito del tutto, le collisioni pura geometria con "è almeno vicino?" per primo.

Dove va ora il tempo nei fotogrammi più carichi: le due nuove righe del fiume nel Layer 2 circa 31 000 cicli, il suono fino a 40 000, il posizionamento dei nemici e le collisioni circa 45 000, gli sprite circa 13 000, il gioco stesso circa 14 000.

Il programma porta da sé il Next a 28 MHz. Ne dipende solo la velocità, non ciò che accade nel gioco, e un fotogramma in ritardo viene semplicemente mostrato due volte. Ogni Next e i suoi emulatori girano a 28 MHz con un core aggiornato. A 28 MHz un Next vero ogni tanto fa aspettare il processore per la memoria; il core dell'emulatore su cui è stata misurata la velocità dovrebbe tenerne conto, ma non è stato verificato su hardware reale.

## Come sappiamo che è giusto

Ogni modifica a ciò che fa il gioco si fa prima nel port in C++ e lì si confronta con il gioco originale che gira in un emulatore Atari: dopo ogni fotogramma tutta la memoria dell'Atari (il fiume, ogni oggetto, il punteggio, il carburante, le collisioni), e il fiume come disegnato con lo schermo dell'originale, punto per punto.

Poi il Next: dopo ogni fotogramma la sua copia della memoria dell'Atari si confronta con il port in C++, e così gli oggetti che disegna, i colori della riva riga per riga e la lista del Copper; alla fine l'intera immagine, punto per punto. Centinaia di migliaia di fotogrammi di partite giocate da un semplice giocatore robot, in PAL e NTSC, dal primo ponte al ponte 200 (il robot si può rendere incapace di schiantarsi, da entrambe le parti, per arrivare così lontano), sono uguali.

Una differenza dall'originale è nota, e scelta: le collisioni (sopra, un colpo o uno schianto un fotogramma prima in circa un fotogramma su mille). Il modo proprio dell'Atari è conservato nel port in C++, che si può ancora verificare con l'originale.
