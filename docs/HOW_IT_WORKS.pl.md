# Jak River Raid działa na ZX Spectrum Next

[English](HOW_IT_WORKS.md) | [Русский](HOW_IT_WORKS.ru.md) | [Українська](HOW_IT_WORKS.uk.md) | [Deutsch](HOW_IT_WORKS.de.md) | Polski | [Italiano](HOW_IT_WORKS.it.md) | [Español](HOW_IT_WORKS.es.md) | [中文](HOW_IT_WORKS.zh.md) | [日本語](HOW_IT_WORKS.ja.md)

To dla wszystkich ciekawych, bez programowania. Jak działa sama gra (rzeka, wrogowie, mosty, dlaczego robi się trudniej), opowiada [docs/HOW_IT_WORKS.pl.md](https://github.com/djdron/river_raid/blob/main/docs/HOW_IT_WORKS.pl.md) portu C++. Tutaj: jak obraz Atari i jego kolizje powstają na innym komputerze, ZX Spectrum Next.

## Dwie różne maszyny

Atari 800 z 1979 roku ma procesor 6502 z zegarem 1,79 MHz; Next ma Z80 do 28 MHz. Oba to komputery 8-bitowe, ale ich układy wideo działają zupełnie inaczej.

**Atari** rysuje ekran linia po linii, tak jak biegnie promień telewizora. Do ruchomych rzeczy ma tylko osiem „sprite'ów”: czterech **graczy** (players, każdy szeroki na 8 punktów) i cztery **pociski** (missiles, każdy na 2 punkty). Osiem to o wiele za mało na samolot River Raid, odrzutowce, helikoptery, statki, czołgi, balony, składy paliwa i mosty, więc gra oszukuje: używa jednego gracza do każdego wroga w dół ekranu. Gdy promień rysuje ekran, mały kawałek kodu (*przerwanie listy wyświetlania*, DLI) budzi się przed każdym obiektem, przenosi gracza 3 na miejsce obiektu, nadaje mu kształt i kolor obiektu wiersz po wierszu, a gdy obiekt jest gotowy, przenosi tego samego gracza niżej, do następnego obiektu. Dziesięć obiektów na ekranie to tak naprawdę jeden gracz, przeniesiony dziesięć razy w czasie jednego obrazu.

Czym jest DLI? *Przerwanie* to sprzęt klepiący procesor w ramię: procesor odkłada to, co robił, wykonuje krótki kawałek kodu i wraca. Układ wideo Atari wykonuje *listę wyświetlania*, mały program mówiący, co pokazuje każdy pas ekranu. Każda jej linia może mieć znacznik; gdy promień dochodzi do oznaczonej linii, procesor zostaje przerwany: to przerwanie listy wyświetlania. Główne DLI River Raid zaczyna się tuż nad rzeką i trzyma procesor aż do jej dołu. W każdej linii czeka na promień (układ może wstrzymać procesor do początku następnej linii) i zmienia gracza 3 dokładnie na czas. Dopiero potem procesor wraca do gry.

**Next** ma znacznie hojniejszy układ wideo: pełnokolorową warstwę tła (*Layer 2*), do 128 sprzętowych sprite'ów 16×16 punktów, warstwę kafelków na tekst i pomocnika zwanego *Copper*, który może zmieniać kolory w dowolnej linii ekranu. Nie potrafi tego, co Atari, czyli ponownie użyć sprite'a w trakcie rysowania obrazu. Ale nie musi: po prostu ma dość sprite'ów.

Port nie kopiuje więc tego, co robią układy Atari. Kopiuje **to, co Atari pokazuje**, a potem buduje ten sam obraz z części Next.

## Każda klatka: najpierw praca Atari

Pięćdziesiąt razy na sekundę (sześćdziesiąt na amerykańskiej maszynie NTSC) Next wykonuje dokładnie tę pracę, którą Atari wykonywał dla tej klatki: przesuwa rzekę, porusza wrogów, samolot, pocisk, czyta joystick, liczy paliwo i punkty. Wszystko to trzyma w tej samej pamięci, w tych samych miejscach co Atari. Dzięki temu da się to sprawdzić: kopię pamięci Atari w Next można po każdej klatce porównać bajt po bajcie z prawdziwym Atari (jego emulatorem) i z portem C++.

Potem przychodzi obraz.

## Rzeka

Rzeka, jej brzegi, wyspy, drogi i domy to **playfield** Atari: tło. Na Atari każda linia rzeki to 48 bajtów pamięci ekranu, cztery punkty na bajt, każdy punkt w jednym z czterech kolorów: tło (czarne), brzeg (zielony lub szary), krawędź brzegu, woda (niebieska).

Na Next rzeka jest w Layer 2, obrazie 320×256. Każda nowa linia rzeki, którą robi gra, jest kopiowana do jednego wiersza Layer 2, każdy punkt Atari jako dwa punkty Next obok siebie (punkty Atari są szerokie). Kolory nie są zapisywane jako kolory, lecz jako „kolor 1, 2 lub 3”, a paleta Next mówi, czym są kolory 1, 2 i 3. Dlatego cała rzeka może zrobić się czerwona, gdy trafiony zostanie most: zmienia się jeden wpis palety.

Rzeka przewija się w dół. Atari robi to, kierując wyświetlanie na inną pamięć; Next — każąc Layer 2 zaczynać pokazywanie od innego wiersza. Na każdą linię rzeki zapisywany jest tylko jeden nowy wiersz; nic nie jest przenoszone.

Przy moście kolor brzegu zmienia się z linii na linię (droga). Robi to Copper: zanim taka linia zostanie narysowana, zmienia „kolor 1” palety.

## Wrogowie: od jednego gracza do wielu sprite'ów

Next nie odgrywa już DLI Atari, nawet jego rozkładu. Każdy wróg po prostu stoi na wysokości, którą daje mu jego slot, przycięty tam, gdzie rzeka się zaczyna i kończy. (DLI Atari mogło w zasadzie dotrzeć do obiektu kilka linii za późno, gdy ten był zbyt blisko pod poprzednim; w setkach tysięcy klatek nigdy się to nie zdarzyło, więc prosta reguła daje ten sam obraz.)

Każdy obiekt staje się wtedy jednym gotowym sprite'em Next (dwoma, jeśli jest wyższy niż 16 linii). Atari zmienia kolor gracza 3 w każdej linii (stąd paski u wrogów); sprite Next może mieć własny kolor w każdym punkcie, więc paski są po prostu w nim narysowane. Każdy punkt Atari staje się dwoma punktami sprite'a (punkty Atari są szerokie), a podwójna lub poczwórna szerokość to sprite narysowany dwa lub cztery razy szerzej. Obiekt wchodzący od góry jest rysowany w całości, a część nad rzeką obcina okno przycinania sprite'ów.

Obrazy wszystkich wrogów (każdego rodzaju, każdej klatki animacji, każdego wybuchu, także w lustrzanym odbiciu) robione są raz przy starcie programu: około sześćdziesięciu. Potem każda klatka mówi tylko, jaki obraz pokazuje każdy sprite i gdzie; w czasie gry nic nie jest rysowane.

Samolot, jego pocisk, czołgi na brzegach, pocisk czołgu i rakieta helikoptera używają pozostałych graczy i pocisków Atari, z których każdy ma jeden kolor i przez cały ekran stoi w jednym miejscu. Gra stawia każdy w znanej linii (samolot zawsze na tej samej wysokości, pocisk tam, gdzie czołg go wystrzelił…), więc każdy to jeden sprite zrobiony z jego wierszy w tym miejscu.

## Kolizje: kto czego dotknął

Na Atari gra nigdy sama nie liczy kolizji. Robi to układ wideo: rysując, za każdym razem, gdy punkt gracza trafi na kolorowy punkt playfieldu albo na punkt innego gracza, ustawia bit w rejestrze kolizji („gracz 2 dotknął koloru 1”, „pocisk 2 dotknął gracza 3”). DLI czyta te rejestry po każdym obiekcie: w ten sposób gra wie, że pocisk trafił właśnie ten statek, że samolot wleciał w brzeg, że odrzutowiec dotarł do krawędzi i musi zawrócić.

Te bity są tylko ustawiane, układ nigdy ich nie kasuje: zostają, aż program skasuje je wszystkie naraz (zapisem do rejestru HITCLR). A gracz 3 to po kolei każdy wróg. Przeczytane raz na końcu klatki, rejestry mówiłyby tylko „gracz 3 czegoś dotknął”, a nie który statek. Dlatego po każdym obiekcie DLI kopiuje rejestry do pamięci gry, obok tego obiektu („pocisk trafił obiekt w slocie 5”), kasuje je i przenosi gracza 3 do następnego obiektu. Gra zagląda tam później.

Układ wideo Next nie ma nic takiego, więc Next liczy to sam, i tylko to, co czyta gra: samolot z brzegiem, pocisk z brzegiem i z obiektami, obiekty z krawędzią brzegu, czołg z krawędzią, rakietę helikoptera z samolotem i brzegiem, pocisk czołgu z samolotem i obiektami.

Jedną sprzętową flagę tego rodzaju Next jednak ma: „dwa sprite'y się nałożyły”. Tu nie pomaga. Nie mówi, które sprite'y, ani nic o rzece (brzegi są w Layer 2, nie w sprite'ach). Przy nawet sześćdziesięciu sprite'ach na klatkę ustawiałyby ją sprite'y, których Atari nigdy by nie porównywał (logo, wskazówka). I ustawiana jest tylko wtedy, gdy promień naprawdę rysuje sprite'y, klatkę później, a gra musi wiedzieć w tej.

Każda ruchoma rzecz jest tam, gdzie postawiła ją gra, więc każda kolizja to pytanie o kilka linii. Dla każdego sprite'a: czy na jego liniach jego punkty dotykają brzegu (lub krawędzi)? Dla dwóch sprite'ów: czy na liniach, na których są oba, ich punkty się spotykają? Praca idzie według zasady „najpierw tanio, dokładnie tylko w razie potrzeby”: najpierw, czy ich prostokąty w ogóle się spotykają; dopiero potem punkty, linia po linii: punkty każdej linii wyrównane do punktów drugiego (procesor Next może przesunąć rząd punktów o dowolną liczbę miejsc jedną instrukcją) i porównane wszystkie naraz (kształty mają szczeliny, przez które może przelecieć pocisk). Dla helikoptera, balonu lub statku przeciw krawędzi brzegu wystarczą końce każdego jego wiersza: krawędź między nimi liczy się jako dotknięcie. Na brzeg patrzy się bez domów i dróg: wtedy każda linia rzeki to po prostu brzeg, krawędź, woda, krawędź, brzeg (dwa razy z wyspą), garść liczb zachowanych przy robieniu tej linii. A woda nigdy nie jest kolizją w River Raid.

Tu Next nie trzyma się już czasu Atari. DLI Atari czyta rejestry układu tuż po każdym obiekcie i je kasuje, więc widzi dotknięcie tylko w oknie linii; pocisk dotykający na przykład tylko ostatniego wiersza obiektu wpada między dwa okna i liczy się klatkę później, gdy pocisk jest głębiej. Next liczy dotknięcie, gdziekolwiek się zdarzy. Mniej więcej w jednej klatce na tysiąc (w jednej na czterysta przy dalekich mostach, gdzie każdy slot wroga jest zajęty) rozstrzyga to się inaczej: zawsze trafienie albo katastrofa o klatkę wcześniej niż na Atari. Nikt grający by tego nie zauważył, ale gra nie podąża już za oryginałem klatka w klatkę. To cena szybkości: rozkład i jego odczyty zajmowały ponad połowę pracy najbardziej zajętych klatek.

Ile to kosztuje: rozmieszczenie wrogów i wszystkie kolizje około 45 000 taktów procesora Next w najbardziej zajętej klatce, około 8% pięćdziesiątej części sekundy. Większości unika się dzięki „czy to w ogóle blisko?”: każda linia rzeki pamięta, gdzie zaczyna się i kończy jej woda, więc sprite czy wróg głęboko w wodzie jest pomijany dwoma porównaniami, a punkty ogląda się tylko przy brzegu. Gdy DLI było jeszcze odgrywane z rozkładem i odczytami, najbardziej zajęta klatka potrzebowała na to około 145 000; takt po takcie, z rejestrami układu emulowanymi linia po linii, średnio około 210 000.

## Panel i przewijany napis

Pod rzeką Atari pokazuje panel dużymi literami (punkty, numer gry, wskaźnik paliwa, rekord, most) i linię przewijającą napisy końcowe, z tęczowym logo Activision.

Na Next są one zrobione z *kafelków*: małych obrazków 8×8 ułożonych w siatkę jak litery na stronie. Przy starcie program buduje własne litery Atari (te, które gra robi z czcionki komputera i swoich symboli) i zamienia każdą w dwa kafelki. Potem litera panelu jest wpisywana do siatki tylko wtedy, gdy się zmienia (cyfra punktów, życie). Przewijany napis to pierścień: cały wiersz kafelków przesuwa się w bok o dwa punkty na klatkę, a tylko litera wchodząca z prawej jest wpisywana do kolumny, która właśnie wysunęła się z lewej. Ponieważ warstwa kafelków jest dokładnie tak szeroka jak ekran, ta kolumna widać też przy prawej krawędzi; tam jest ukrywana, a wchodzącą literę pokazuje zamiast niej jeden sprite.

Szare tło panelu to własna warstwa rzeki, której cztery kolory Copper robi szarymi na liniach panelu, więc jest dokładnie tak szerokie jak rzeka, a wskazówka paliwa (sprite) pojawia się nad szarością, ale pod literami, jak na Atari. Tęczowe logo to pięć sprite'ów.

Obraz Next ma 320 punktów szerokości: wszystko, co potrafi narysować, jest w nim, a wokół tylko jeden kolor (ramka). Obraz Atari jest trochę szerszy: rzeka i panel o 8 jego pikseli z lewej, przewijany napis o mniej więcej 3 jego litery. Dlatego w trybie attract przewijany tekst jest obcięty na brzegach. Pas koloru w ramce by nie pomógł: nie można tam umieścić żadnego obrazu, a samoloty znikałyby nad nim.

## Dźwięk

Układ dźwiękowy Atari, POKEY, ma cztery kanały. Każdy odlicza szybki zegar (64 000 tyknięć na sekundę) od liczby ustawionej przez grę i za każdym razem, gdy odliczanie się skończy, daje impuls; co robi impuls, zależy od innego ustawienia: przełączyć wyjście kanału (czysty ton, tym wyższy, im mniejsza liczba) albo wziąć bit z jednego z rejestrów przesuwnych POKEY, które dają długi, losowo wyglądający strumień bitów (szum: silnik, wybuchy). Każdy kanał ma też głośność. Sama gra ustawia te liczby tylko raz na klatkę: wysokość silnika z prędkości, opadający gwizd pocisku czołgu, syk wybuchu.

Next nie ma POKEY, ale ma DAC: port, w którym liczba staje się napięciem, więc strumień liczb to fala dźwiękowa. Next liczy więc wyjście POKEY sam, 15 909 liczb na sekundę, około 320 na klatkę, i zostawia je w pierścieniu w pamięci. Wysyłanie ich do DAC po jednej, dokładnie w odpowiednich chwilach, zajęłoby cały czas procesora; robi to zamiast niego DMA Next, sprzęt, który sam kopiuje bajt z pamięci do portu co 1/15 909 sekundy, w kółko po pierścieniu. Procesor musi tylko utrzymywać pierścień wypełniony trochę naprzód i trzymać pierścień tam, gdzie patrzy DMA (dźwięk jest tak głośny, jak mikser Next pozwala być jednemu DAC: mniej więcej o połowę ciszej niż w porcie C++ przy tych samych ustawieniach, pod spodem ten sam dźwięk; i mono, jak w Atari): DMA czyta pamięć przez te same okna co procesor, a gdy kod na chwilę wstawiał w okno pierścienia inny kawałek pamięci, DMA grał właśnie jego, trzask w każdej klatce.

Czyste tony (sygnały, tankowanie, strzał, gwizd pocisku) to wszystko omijają: Next ma też układy dźwiękowe AY, które same robią dokładnie taką falę prostokątną, więc te kanały POKEY są po prostu przekazywane do AY z przeliczoną wysokością i głośnością. Dla DAC liczone są tylko szumy (silnik, wybuchy, rakieta helikoptera).

Liczenie fali tyknięcie po tyknięciu byłoby o wiele za wolne. Zamiast tego każdy kanał skacze od impulsu do impulsu: wie, o ile próbek jest jego następny impuls, a między impulsami jego wyjście się nie zmienia. Tam, gdzie wyjście się włącza lub wyłącza, zapisuje w pierścieniu „+ głośność” albo „− głośność”; na końcu jedno przejście sumuje je w falę. Kosztuje to około 25 000 taktów procesora na klatkę, 4% pięćdziesiątej części sekundy; najbardziej zajęta (silnik, wybuch, strzał i rakieta naraz) ponad dwa razy więcej. Pierścień jest utrzymywany mniej więcej dwie i pół klatki przed DMA, więc klatka z dużą ilością innej pracy może zrobić mniej liczb i zostawić resztę następnym klatkom; a gdy gra ma więcej pracy niż czasu, ustępuje dźwięk, nie gra.

## Dlaczego nie przerwania liniowe Next

Next też potrafi przerwać swój procesor w dowolnie wybranej linii ekranu. Port z tego nie korzysta, bo nie musi nadążać za promieniem. To, co robiło DLI Atari, jest wyliczane z wyprzedzeniem, jako obliczenie, gdy jeszcze pokazywany jest poprzedni obraz. To, co musi się zmienić w konkretnej linii prawdziwego ekranu (kolor drogi), jest wpisywane na listę Coppera, a Copper, który nigdy nie gubi linii, to robi; lista jest wysyłana do Coppera ponownie tylko wtedy, gdy się zmienia. Procesor musi jedynie pilnować, w której linii jest promień, żeby przełączyć się na nową klatkę pod przewijanym napisem, gdzie na ekranie nic się nie zmienia (przerwania pozostają wyłączone). Dźwiękowi, granemu próbka po próbce przez DAC Next, też nie są potrzebne: robi to DMA Next bez procesora (zob. Dźwięk).

## Czas

Wszystko to musi się zmieścić w pięćdziesiątej części sekundy. Next działa z zegarem 28 MHz, około szesnaście razy szybciej niż Atari. Przeciętna klatka zajmuje teraz około 21% dozwolonego czasu; najbardziej zajęta, jaką da się programowi narzucić (każdy slot wroga zajęty, lot z pełną prędkością i ciągły ogień, przy moście 80), około 41%. Działałoby więc też przy 14 MHz.

Nie zawsze tak było. Odgrywanie DLI Atari takt po takcie, z rejestrami kolizji emulowanymi linia po linii, zajmowało średnio około 60% klatki i do 88%; przy zatłoczonych mostach klatka często się spóźniała. Potem krok po kroku, najpierw w porcie C++ i za każdym razem sprawdzając z oryginałem: takty odrzucono poza kilkoma regułami; wrogowie stali się gotowymi wielokolorowymi sprite'ami; pozostałe sprite'y brano z miejsc, w które postawiła je gra, zamiast ich szukać; kolizje liczono z wierszy sprite'ów; pętla DLI stała się rozkładem; wszystkie obrazy sprite'ów zaczęto robić przy starcie; panel i przewijany napis zapisywano tylko tam, gdzie się zmieniają; i w końcu DLI zniknęło całkiem, a kolizje stały się zwykłą geometrią z „czy to w ogóle blisko?” na początku.

Na co idzie teraz czas w najbardziej zajętych klatkach: dwie nowe linie rzeki do Layer 2 około 31 000 taktów, dźwięk do 40 000, rozmieszczenie wrogów i kolizje około 45 000, sprite'y około 13 000, sama gra około 14 000.

Program sam przełącza Next na 28 MHz. Zależy od tego tylko szybkość, a nie to, co dzieje się w grze, a spóźniona klatka jest po prostu pokazywana dwa razy. Każdy Next i jego emulatory z aktualnym rdzeniem działają z 28 MHz. Przy 28 MHz prawdziwy Next od czasu do czasu każe procesorowi czekać na pamięć; rdzeń emulatora, na którym mierzono szybkość, powinien to uwzględniać, ale nie zostało to sprawdzone na prawdziwym sprzęcie.

## Skąd wiemy, że to jest dobrze

Każda zmiana tego, co robi gra, jest najpierw robiona w porcie C++ i tam porównywana z oryginalną grą działającą w emulatorze Atari: po każdej klatce cała pamięć Atari (rzeka, każdy obiekt, punkty, paliwo, kolizje), a rzeka w postaci narysowanej z ekranem oryginału punkt w punkt.

Potem Next: po każdej klatce jego kopia pamięci Atari jest porównywana z portem C++, tak samo obiekty, które rysuje, kolory brzegu linia po linii i lista Coppera; na końcu cały obraz punkt w punkt. Setki tysięcy klatek gier prostego gracza-robota, na PAL i NTSC, od pierwszego mostu do mostu 200 (robota można uczynić niezdolnym do katastrofy, po obu stronach, żeby dotarł tak daleko), są takie same.

Jedna różnica względem oryginału jest znana i wybrana świadomie: kolizje (wyżej, trafienie lub katastrofa o klatkę wcześniej mniej więcej w jednej klatce na tysiąc). Własny sposób Atari zachowano w porcie C++, który wciąż można sprawdzać z oryginałem.
