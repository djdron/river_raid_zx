# Jak River Raid działa na współczesnych ZX Spectrum

[English](HOW_IT_WORKS.md) | [Русский](HOW_IT_WORKS.ru.md) | [Українська](HOW_IT_WORKS.uk.md) | [Deutsch](HOW_IT_WORKS.de.md) | Polski | [Italiano](HOW_IT_WORKS.it.md) | [Español](HOW_IT_WORKS.es.md) | [中文](HOW_IT_WORKS.zh.md) | [日本語](HOW_IT_WORKS.ja.md)

To dla wszystkich ciekawych, nie trzeba umieć programować. Jak działa sama gra (rzeka, wrogowie, mosty, dlaczego robi się trudniej), opisano w [docs/HOW_IT_WORKS.pl.md](https://github.com/djdron/river_raid/blob/main/docs/HOW_IT_WORKS.pl.md) portu C++. Tutaj: jak obraz Atari, jego kolizje i dźwięk powstają na dwóch innych komputerach, ZX Spectrum Next i płycie ZX Evolution z konfiguracją TS-Conf. Większość jest na obu taka sama; tam, gdzie się różnią, każdy ma swoją część (**Na Next**, **Na TS-Conf**).

## Trzy różne maszyny

Atari 800 z 1979 roku ma procesor 6502 taktowany 1,79 MHz. Next ma Z80 do 28 MHz, TS-Conf — Z80 do 14 MHz. Wszystkie trzy to komputery 8-bitowe, ale ich układy wideo działają zupełnie inaczej.

**Atari** rysuje ekran linia po linii, tak jak biegnie promień telewizora. Do ruchomych rzeczy ma tylko osiem „sprite'ów”: czterech **graczy** (po 8 punktów szerokości) i cztery **pociski** (po 2 punkty). Osiem to o wiele za mało na samolot, odrzutowce, helikoptery, statki, czołgi, balony, stacje paliw i mosty River Raid, więc gra oszukuje: używa jednego gracza dla każdego wroga w dół ekranu. Gdy promień rysuje ekran, mały kawałek kodu (*przerwanie listy wyświetlania*, DLI) budzi się przed każdym obiektem, przenosi gracza 3 na miejsce obiektu, daje mu kształt i kolor obiektu wiersz po wierszu, a gdy obiekt się kończy, przenosi tego samego gracza niżej, do następnego. Dziesięć obiektów na ekranie to w rzeczywistości jeden gracz, przestawiony dziesięć razy w trakcie jednego obrazu.

Czym jest DLI? *Przerwanie* to sprzęt klepiący procesor w ramię: procesor odkłada to, co robił, wykonuje krótki kawałek kodu i wraca. Układ wideo Atari postępuje według *listy wyświetlania*, małego programu, który mówi, co pokazuje każdy pas ekranu. Każda jej linia może nieść znacznik; gdy promień dochodzi do oznaczonej linii, procesor zostaje przerwany: to przerwanie listy wyświetlania. Główne DLI River Raid zaczyna się tuż nad rzeką i trzyma procesor aż do jej dołu. W każdej linii czeka na promień (układ potrafi wstrzymać procesor do początku następnej linii) i zmienia gracza 3 dokładnie na czas. Dopiero potem procesor wraca do gry.

**Next** ma znacznie hojniejszy układ wideo: pełnokolorową warstwę tła (*Layer 2*), do 128 sprzętowych sprite'ów 16×16 punktów, które można narysować dwa lub cztery razy szerzej, warstwę kafelków na tekst i pomocnika zwanego *Copper*, który potrafi zmieniać kolory w dowolnej linii ekranu.

**TS-Conf** to konfiguracja układu wideo płyty ZX Evolution (Pentevo): obraz tła w 16 lub 256 kolorach, który sprzęt umie przewijać, dwie warstwy kafelków, do 85 sprite'ów dowolnego rozmiaru do 64×64 punktów (ale żadnego nie da się rozciągnąć), własny DMA do szybkiego kopiowania pamięci i przerwanie, które można ustawić na dowolną linię ekranu. Coppera nie ma. Jej dźwięk to zwykle *General Sound*: karta z własnym Z80 i czterema 8-bitowymi przetwornikami DAC.

Żadna z nich nie umie tego, co robi Atari — ponownie używać sprite'a, gdy rysuje się obraz. Ale też nie musi: po prostu ma dość sprite'ów. Dlatego porty nie kopiują tego, co robią układy Atari. Kopiują **to, co Atari pokazuje**, i budują ten sam obraz z części każdej z maszyn.

## Co klatkę najpierw praca Atari

Pięćdziesiąt razy na sekundę (na Next także sześćdziesiąt, jak na amerykańskiej maszynie NTSC; klatka TS-Conf to 50) program wykonuje dokładnie tę pracę, którą Atari wykonywało w tej klatce: przesuwa rzekę, wrogów, samolot, pocisk, czyta joystick, liczy paliwo i punkty. Trzyma to wszystko w tej samej pamięci, w tych samych miejscach co Atari. To właśnie pozwala to sprawdzać: kopię pamięci Atari można po każdej klatce porównać bajt po bajcie z prawdziwym Atari (jego emulatorem) i z portem C++.

Ta część to na obu maszynach ten sam program: port na TS-Conf używa kopii kodu Next do gry, generatora rzeki, rozmieszczania wrogów i kolizji. Własne każdej maszyny są tylko obraz i dźwięk.

## Rzeka

Rzeka, jej brzegi, wyspy, drogi i domy to **pole gry** Atari: tło. Na Atari każda linia rzeki to 48 bajtów pamięci ekranu, cztery punkty na bajt, każdy punkt w jednym z czterech kolorów: tło (czarne), brzeg (zielony lub szary), krawędź brzegu, woda (niebieska).

Każda nowa linia rzeki, którą tworzy gra, jest kopiowana do jednego wiersza obrazu tła, każdy punkt Atari jako dwa punkty obok siebie (punkty Atari są szerokie). Kolory nie są zapisane jako kolory, lecz jako „kolor 1, 2 lub 3”, a paleta mówi, czym są kolory 1, 2 i 3. Dzięki temu cała rzeka może zrobić się czerwona po trafieniu mostu: zmienia się jeden wpis palety. Rzeka przewija się w dół: Atari robi to, kierując wyświetlanie na inną pamięć, porty — mówiąc tłu, by zaczynało pokazywać od innego wiersza. Na każdą linię rzeki zapisuje się tylko jeden nowy wiersz; nic nie jest przenoszone.

Przy moście kolor brzegu zmienia się z linii na linię (droga). Każda maszyna robi to na swój sposób.

**Na Next** rzeka jest w Layer 2, obrazie 320×256 w 256 kolorach. Layer 2 jest zapisany kolumnami, więc nowa linia jest pisana w dół 320 kolumn. Kolorami drogi zajmuje się Copper: zanim taka linia zostanie narysowana, zmienia w palecie „kolor 1”.

**Na TS-Conf** rzeka to 16-kolorowy obraz 320×240, dwa punkty w bajcie, więc nowa linia to 160 bajtów zapisanych wprost wzdłuż jej wiersza. Coppera nie ma, ale TS-Conf ma 16 palet po 16 kolorów i rejestr, który mówi, której używa rzeka; rejestr działa od końca linii. Dlatego każdy kolor brzegu, jaki rzeka już miała, dostaje własną paletę, a przerwanie jest przesuwane w dół ekranu od jednej zmiany do następnej: linię przed początkiem drogi przełącza rzekę na paletę tego koloru, na końcu drogi z powrotem. Gdziekolwiek procesor jest w swojej pracy, zmiana trafia dokładnie we właściwą linię.

## Wrogowie: z jednego gracza wiele sprite'ów

Porty nie odtwarzają już DLI Atari, nawet jego rozkładu. Każdy wróg po prostu stoi na wysokości, jaką daje mu jego slot, przycięty tam, gdzie rzeka zaczyna się i kończy. (DLI Atari mogło w zasadzie dotrzeć do obiektu kilka linii za późno, gdy ten jest zbyt blisko pod poprzednim; zmierzone na stu tysiącach klatek, nigdy się to nie zdarzyło, więc prosta reguła daje ten sam obraz.)

Potem każdy obiekt staje się gotowym sprite'em. Atari zmienia kolor gracza 3 w każdej linii (tak wrogowie mają paski); sprite'y portów mogą mieć własny kolor w każdym punkcie, więc paski są po prostu w nich narysowane. Każdy punkt Atari staje się dwoma punktami sprite'a.

Obrazki wszystkich wrogów (każdego rodzaju, każdej klatki animacji, każdego wybuchu, także odbite) są robione raz przy starcie programu: około sześćdziesięciu. Każda klatka mówi potem tylko, który obrazek pokazuje każdy sprite i gdzie; podczas gry nic się nie rysuje.

Samolot, jego pocisk, czołgi na brzegach, pocisk czołgu i rakieta helikoptera to inni gracze i pociski Atari, które mają po jednym kolorze i stoją w jednym miejscu przez cały ekran. Gra stawia każdy w znanej linii (samolot zawsze na tej samej wysokości, pocisk czołgu tam, gdzie czołg go wystrzelił…), więc każdy to jeden sprite, którego obrazek też powstaje przy starcie.

**Na Next** sprite ma 16×16 punktów, więc obiekt wyższy niż 16 linii to dwa sprite'y. Podwójna lub poczwórna szerokość to sprite narysowany przez sprzęt dwa lub cztery razy szerzej. Obiekt wjeżdżający od góry jest rysowany w całości, a część nad rzeką odcina okno przycinania sprite'ów.

**Na TS-Conf** sprite może mieć do 64×64 punktów, więc każdy obiekt to jeden sprite, ale sprzęt nie umie go rozciągnąć: każdy obrazek powstaje przy starcie trzy razy, szeroki na 16, 32 i 64 punkty. To, co leży poza rzeką, chowa się pod warstwą kafelków, czarną nad rzeką i szarą pod panelem.

## Kolizje: kto czego dotknął

Na Atari gra nigdy sama nie liczy kolizji. Robi to układ wideo: podczas rysowania, za każdym razem gdy punkt gracza trafi na kolorowy punkt pola gry albo na punkt innego gracza, ustawia bit w rejestrze kolizji („gracz 2 dotknął koloru 1”, „pocisk 2 dotknął gracza 3”). DLI czyta te rejestry po każdym obiekcie: tak gra wie, że pocisk trafił ten statek, że samolot wleciał w brzeg, że odrzutowiec doleciał do krawędzi i musi zawrócić.

Te bity układ tylko ustawia, nigdy nie kasuje: zostają, aż program skasuje je wszystkie naraz (zapisem do rejestru HITCLR). A gracz 3 to po kolei każdy wróg. Odczytane raz na końcu klatki, rejestry powiedziałyby tylko „gracz 3 czegoś dotknął”, a nie którego statku. Dlatego po każdym obiekcie DLI kopiuje rejestry do pamięci gry, obok tego obiektu („pocisk trafił obiekt w slocie 5”), kasuje je i przenosi gracza 3 do następnego obiektu. Gra zagląda tam później.

Ani układ wideo Next, ani TS-Conf nie ma niczego takiego, więc program liczy to sam, i tylko to, co gra czyta: samolot z brzegiem, pocisk z brzegiem i z obiektami, obiekty z krawędzią brzegu, czołg z krawędzią, rakietę helikoptera z samolotem i brzegiem, pocisk czołgu z samolotem i obiektami. (Next ma jedną sprzętową flagę tego rodzaju, „dwa sprite'y się nałożyły”, ale nie mówi ani które sprite'y, ani nic o rzece, i przychodzi o klatkę za późno.)

Wszystko, co się rusza, stoi tam, gdzie postawiła to gra, więc każda kolizja to pytanie o kilka linii. Dla sprite'a: czy na jego liniach jego punkty dotykają brzegu (albo krawędzi)? Dla dwóch sprite'ów: czy na liniach, na których są oba, ich punkty się spotykają? Praca idzie „najpierw tanio, dokładnie tylko gdy trzeba”: najpierw, czy ich prostokąty w ogóle się spotykają; dopiero potem punkty, linia po linii: punkty każdej linii wyrównane z punktami drugiego i porównane wszystkie naraz (kształty mają dziury, przez które przeleci pocisk). Dla helikoptera, balonu czy statku wobec krawędzi brzegu wystarczą końce każdej jego linii: krawędź między nimi liczy się jako dotknięcie. Na brzeg patrzy się bez domów i dróg: wtedy każda linia rzeki to tylko brzeg, krawędź, woda, krawędź, brzeg (dwa razy z wyspą), garść liczb zapamiętanych przy tworzeniu linii. A woda w River Raid nigdy nie jest kolizją. Większość odpada przy pytaniu „czy to w ogóle blisko?”: każda linia rzeki pamięta, gdzie zaczyna się i kończy jej woda, więc sprite czy wróg głęboko w wodzie jest pomijany po dwóch porównaniach.

Tutaj porty nie trzymają się już synchronizacji Atari. DLI Atari czyta rejestry układu zaraz po każdym obiekcie i je kasuje, więc widzi dotknięcie tylko w oknie linii; pocisk dotykający na przykład tylko ostatniego wiersza obiektu wpada między dwa okna i jest liczony klatkę później, gdy pocisk jest już głębiej. Porty liczą dotknięcie, gdziekolwiek ono nastąpi. W mniej więcej jednej klatce na tysiąc (jednej na czterysta przy dalekich mostach, gdzie wszystkie sloty wrogów są zajęte) rozstrzyga to inaczej: zawsze trafienie albo rozbicie o klatkę wcześniej niż na Atari. Nikt grający by tego nie zauważył, ale gra nie odtwarza już oryginału klatka w klatkę. To cena szybkości: rozkład i jego odczyty zajmowały ponad połowę pracy najbardziej obciążonych klatek.

**Na Next** wyrównanie punktów to jedna instrukcja (jego procesor przesuwa rząd punktów o dowolną liczbę miejsc naraz); rozmieszczanie wrogów i wszystkie kolizje zajmują około 45 000 jego taktów w najbardziej obciążonej klatce, około 8% pięćdziesiątej części sekundy.

**Na TS-Conf** Z80 nie ma takiej instrukcji, przesunięcie to krótka pętla; ta sama praca zajmuje średnio około 57 000 jego taktów na klatkę w najbardziej obciążonych scenach, około 20% jego klatki przy 14 MHz.

## Panel i przewijany napis

Pod rzeką Atari pokazuje panel dużymi literami (punkty, numer gry, wskaźnik paliwa, rekord, most) i linię, w której przewijają się napisy, z tęczowym logo Activision. Oba porty przy starcie budują własne litery Atari (te, które gra robi z czcionki komputera i swoich symboli), a litera panelu jest pisana tylko wtedy, gdy się zmienia (cyfra punktów, życie). Wskazówka paliwa i tęczowe logo to sprite'y.

**Na Next** litery to *kafelki*: małe obrazki 8×8 ułożone w siatkę, jak litery na stronie, każda litera Atari to dwa kafelki. Przewijany napis to pierścień: cały wiersz kafelków przesuwa się w bok o dwa punkty na klatkę, i tylko litera wjeżdżająca z prawej jest pisana do kolumny, która właśnie wyjechała z lewej. Ponieważ warstwa kafelków jest dokładnie tak szeroka jak ekran, tę kolumnę widać też przy prawej krawędzi; tam jest ukryta, a wjeżdżającą literę pokazuje jeden sprite. Szare tło panelu to warstwa samej rzeki, której cztery kolory Copper na liniach panelu zmienia na szare; wskazówka paliwa pojawia się nad szarością, ale pod literami, jak na Atari.

**Na TS-Conf** panel to osobny obraz w 256 kolorach, na który przerwanie przełącza ekran w pierwszej linii panelu (to samo przerwanie, które zmienia paletę rzeki; tam zmieniają się jego obraz, przewijanie i tryb). Jego litery są rysowane raz przy starcie i kopiowane na miejsce przez DMA. Obraz panelu leży nad sprite'ami, z dziurami tam, gdzie nie ma liter; pod dziurami warstwa kafelków pokazuje szarość, a wskazówka i logo to sprite'y nad nią. Przewijany napis to pierścień 32 liter w obrazie szerokim na 512 punktów; przerwanie ustawia, od którego miejsca ekran go pokazuje, więc pisana jest tylko wjeżdżająca litera.

Obrazy mają 320 punktów szerokości: wszystko, co maszyny umieją narysować, jest w środku, a wokół tylko jeden kolor (ramka). Obraz Atari jest trochę szerszy: rzeka i panel o 8 jego pikseli z lewej, przewijany napis o mniej więcej 3 jego litery. Dlatego w trybie demonstracyjnym przewijany tekst jest obcięty na brzegach.

## Dźwięk

Układ dźwiękowy Atari, POKEY, ma cztery kanały. Każdy odlicza szybki zegar (64 000 tyknięć na sekundę) w dół od liczby, którą ustawia gra, i za każdym razem, gdy licznik się wyczerpie, daje impuls; co robi impuls, zależy od innego ustawienia: przełączyć wyjście kanału (czysty ton, tym wyższy, im mniejsza liczba) albo wziąć bit z jednego z rejestrów przesuwnych POKEY, które dają długi, losowo wyglądający strumień bitów (szum: silnik, wybuchy). Każdy kanał ma też głośność. Sama gra ustawia te liczby tylko raz na klatkę: wysokość silnika z prędkości, opadający gwizd pocisku czołgu, syk wybuchu.

Żadna z maszyn nie ma POKEY, ale obie potrafią grać strumień liczb przez DAC (port, w którym liczba staje się napięciem, więc strumień liczb to fala dźwiękowa). Dlatego wyjście POKEY liczy program, około 15 800–15 900 liczb na sekundę, około 320 na klatkę, i zostawia je w pierścieniu pamięci, który potem sprzęt sam gra w kółko.

Liczenie fali tyknięcie po tyknięciu byłoby o wiele za wolne. Zamiast tego każdy kanał skacze od impulsu do impulsu: wie, ile próbek dalej jest jego następny impuls, a między impulsami jego wyjście się nie zmienia. Tam, gdzie wyjście się włącza lub wyłącza, pisze do pierścienia „+ głośność” albo „− głośność”; na końcu jedno przejście sumuje to w falę. Pierścień jest utrzymywany mniej więcej dwie i pół klatki przed miejscem, w którym jest grany, więc klatka z dużą ilością pracy może zrobić mniej liczb i zostawić resztę następnym. DAC przyjmuje jeden bajt, od 0 do 255: cztery kanały na pełnej głośności by go przekroczyły, więc liczby są skalowane, żeby się zmieściły (gdy dwa wybuchy spotykają się z szumem silnika, najgłośniejsze momenty gry).

**Na Next** program liczy falę sam, a gra ją jego DMA (kawałek sprzętu, który sam kopiuje bajt z pamięci do DAC co 1/15 909 sekundy). Czyste tony (piski, tankowanie, strzelanie, gwizd pocisku) omijają to wszystko: Next ma też układy dźwiękowe AY, które same robią dokładnie taką falę prostokątną, więc te kanały POKEY są po prostu oddawane AY z przeliczoną wysokością i głośnością. Do DAC idą tylko szumy (silnik, wybuchy, rakieta helikoptera). Kosztuje to około 25 000 taktów procesora na klatkę, 4% pięćdziesiątej części sekundy; najbardziej obciążone (silnik, wybuch, strzelanie i rakieta naraz) ponad dwa razy więcej. Gdy gra ma więcej pracy niż czasu, ustępuje dźwięk, nie gra. DMA czyta pamięć przez te same okna co procesor: gdy kod na chwilę wstawiał inny kawałek pamięci w okno pierścienia, DMA grało właśnie to, trzask co klatkę, więc gdy gra dźwięk, nic nie może się tam zmieniać.

**Na TS-Conf** wszystko to działa na karcie General Sound. Przy starcie gra wkłada do karty mały program (ten sam kod robiący falę co na Next), a od tej pory tylko raz na klatkę wysyła karcie osiem liczb POKEY; falę robi własny Z80 karty, wszystkie cztery kanały, a jej własne przerwanie gra ją, 15 820 liczb na sekundę, do jej DAC. Procesor główny zużywa na dźwięk około 3 400 taktów na klatkę, głównie czekając, aż karta weźmie kolejną liczbę. Bez karty grają tylko czyste tony, na dwóch układach AY płyty, tak jak gra je Next.

## Przerwania

**Na Next** w ogóle nie są używane. To, co robiło DLI Atari, jest liczone z góry, jako obliczenie, gdy na ekranie widać jeszcze poprzedni obraz. To, co musi się zmienić w konkretnej linii prawdziwego ekranu (kolor drogi), jest zapisywane na liście Coppera, a Copper, który nigdy nie gubi linii, to robi. Procesor musi tylko patrzeć, na której linii jest promień, żeby przełączyć się na nową klatkę pod przewijanym napisem, gdzie na ekranie nic się nie zmienia. Dźwięk też ich nie potrzebuje: DMA gra go bez procesora.

**Na TS-Conf**, bez Coppera, jego pracę robi przerwanie. Przed każdą klatką program robi listę tego, co i gdzie ma się zmienić: paleta rzeki przy każdej zmianie koloru brzegu, obraz panelu w jego pierwszej linii, położenie przewijanego napisu i koniec klatki. Przerwanie jest ustawiane na pierwszą z nich; za każdym razem, gdy przychodzi, robi tę zmianę i ustawia się na następną. Zmiana działa od końca linii, więc nie ma znaczenia, jak długo przerwanie idzie. Ostatnie, pod panelem, mówi programowi, że klatka się skończyła.

## Start

**Na Next** program wczytuje obraz kartridża, River_Raid.rom, z własnego folderu przez DOS Next.

**Na TS-Conf** program uruchamia się z Wild Commandera, który nie daje mu ani folderu, ani DOS, więc sam czyta kartę SD (FAT16 lub FAT32) i szuka na niej River_Raid.rom, najpierw w katalogu głównym, potem w każdym folderze. Gdy pracuje, ekran pozostaje czarny. Bez pliku: czerwona ramka.

## Czas

Wszystko to musi się zmieścić w pięćdziesiątej części sekundy.

**Na Next** przy 28 MHz, mniej więcej szesnaście razy szybciej niż Atari, przeciętna klatka zajmuje teraz około 21% dostępnego czasu; najbardziej obciążona, jaką można programowi urządzić (wszystkie sloty wrogów zajęte, lot na pełnym gazie z ciągłym strzelaniem, przy moście 80), około 41%. Działałby więc i przy 14 MHz. Gdzie idzie czas w najbardziej obciążonych klatkach: dwie nowe linie rzeki około 31 000 taktów, dźwięk do 40 000, rozmieszczanie wrogów i kolizje około 45 000, sprite'y około 13 000, sama gra około 14 000. Program sam przełącza Next na 28 MHz; prawdziwy Next przy 28 MHz czasem każe procesorowi czekać na pamięć, co rdzeń emulatora powinien uwzględniać, ale nie zostało to sprawdzone na prawdziwym sprzęcie.

**Na TS-Conf** przy 14 MHz przeciętna klatka zajmuje około 26% swojego czasu, najbardziej obciążone sceny średnio około 40% i najwyżej 53%. Przy 7 MHz jeszcze się mieści, na styk; przy 3,5 MHz nie nadąża. Bez pracy dźwięku (ta jest na karcie) nowe linie rzeki w najbardziej obciążonych scenach zajmują około 34 000 taktów, rozmieszczanie wrogów i kolizje około 57 000, sprite'y i zmiany palety około 16 000, sama gra około 9 000.

Nie zawsze było tak szybko. Odtwarzanie DLI Atari takt po takcie, z rejestrami kolizji emulowanymi linia po linii, zajmowało średnio około 60% klatki Next i do 88%; przy obciążonych mostach klatka często się spóźniała. Potem, krok po kroku, najpierw w porcie C++ i za każdym razem sprawdzane z oryginałem: takty usunięto, poza kilkoma regułami; wrogowie stali się gotowymi wielokolorowymi sprite'ami; inne sprite'y brano stamtąd, gdzie postawiła je gra, zamiast ich szukać; kolizje liczono z wierszy sprite'ów; pętla DLI stała się rozkładem; wszystkie obrazki sprite'ów robiono przy starcie; panel i przewijany napis pisano tylko tam, gdzie się zmieniają; i w końcu DLI zniknęło całkiem, kolizje to prosta geometria z „czy to w ogóle blisko?” na początku. Dopiero potem na tym samym kodzie powstał port na TS-Conf. Spóźniona klatka jest po prostu pokazywana dwa razy: od procesora zależy tylko szybkość, a nie to, co dzieje się w grze.

## Skąd wiemy, że to jest dobrze

Każda zmiana tego, co robi gra, jest najpierw robiona w porcie C++ i tam porównywana z oryginalną grą działającą w emulatorze Atari: po każdej klatce cała pamięć Atari (rzeka, każdy obiekt, punkty, paliwo, kolizje), a narysowana rzeka z ekranem oryginału, punkt w punkt.

Potem porty, każdy w emulatorze swojej maszyny (rdzenie Next i TS-Conf z Xpeccy+, TS-Conf razem z jego General Sound): po każdej klatce kopia pamięci Atari jest porównywana z portem C++, podobnie rysowane obiekty, kolory brzegu linia po linii (lista Coppera na Next, lista przerwania na TS-Conf) i liczby, które dostaje karta dźwiękowa; oraz obraz, punkt w punkt (na TS-Conf każdej klatki). Setki tysięcy klatek gier prostego robota-gracza, od pierwszego mostu do mostu 200 (robota można uczynić niezniszczalnym, po obu stronach, żeby dotarł tak daleko), są takie same. TS-Conf sprawdzono na razie tylko w emulatorze, nie na prawdziwej płycie.

Jedna różnica względem oryginału jest znana i wybrana: kolizje (wyżej, trafienie albo rozbicie o klatkę wcześniej w mniej więcej jednej klatce na tysiąc). Sposób samego Atari jest zachowany w porcie C++, który wciąż można sprawdzać z oryginałem.
