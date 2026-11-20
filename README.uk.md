# River Raid для сучасних ZX Spectrum

[English](README.md) | [Русский](README.ru.md) | Українська | [Deutsch](README.de.md) | [Polski](README.pl.md) | [Italiano](README.it.md) | [Español](README.es.md) | [中文](README.zh.md) | [日本語](README.ja.md)

River Raid (Activision, Atari 8-bit, 1983, авторка Керол Шоу) на сьогоднішніх машинах ZX
Spectrum: **ZX Spectrum Next** і **TS-Conf** (ZX Evolution / Pentevo). Обидва порти зроблено
на основі C++-порту [djdron/river_raid](https://github.com/djdron/river_raid): у ньому
розібрано, як оригінал робить усе, і його звірено з оригіналом кадр за кадром. Логіка гри —
як в оригіналі, кадр за кадром, у тій самій RAM за тими самими адресами; кожна машина показує
її своїм залізом.

Неофіційний аматорський проєкт з навчальною метою, не пов'язаний з Activision і Microsoft.
Гри в ньому немає: програма читає ваш власний образ картриджа під час роботи.

## Порти

| | [ZX Spectrum Next](NEXT.uk.md) | [TS-Conf](tsconf/README.uk.md) (ZX Evolution / Pentevo) |
|---|---|---|
| Файл | `river_raid.nex` (відкривається в Browser) | `river_raid.spg` (запускається з Wild Commander) |
| ROM | `River_Raid.rom` у тій самій теці, що й .nex | `River_Raid.rom` будь-де на SD-картці (FAT16/32) |
| Річка | Layer 2, колір берега по рядках — Copper | режим 16 кольорів з апаратним прокручуванням, колір берега по рядках — кадрове переривання (палітра на кожен колір) |
| Вороги, літак, ракети | спрайти | спрайти |
| Панель, рядок, що біжить | tilemap | власна картинка, що вмикається під річкою, тайли, спрайти |
| Звук | POKEY емулює програма в ЦАП (zxnDMA), чисті тони на AY | увесь на General Sound (POKEY емулює власний Z80 картки, моно); без неї — чисті тони на AY TurboSound |
| Процесор | 28 МГц (встигає і на 14) | 14 МГц (встигає і на 7) |
| ТБ | PAL 50 Гц або NTSC 60 Гц (CAPS + 1) | PAL 50 Гц |
| Докладно | [NEXT.uk.md](NEXT.uk.md) | [tsconf/README.uk.md](tsconf/README.uk.md) |

Гра готова на обох: attract mode, ігри 1-8 (старт з мосту 1, 5, 20 або 50; один гравець або
двоє по черзі), літак, пальне й бази, вороги, танки, ракети гелікоптерів, мости, очки, життя,
рекорд, пауза, панель і рядок, що біжить, з райдужним логотипом. На справжньому залізі поки не
запускалися: обидва звіряються на емуляторі [Xpeccy+](https://github.com/dotkoval/xpeccy-plus)
(його ядра Next і TSConf).

## Де взяти

Програми збираються на GitHub при кожному push: [Actions](https://github.com/djdron/river_raid_zx/actions),
workflow `build` (.nex) або `tsconf` (.spg), його артефакт. Потрібен власний `River_Raid.rom`:
образ картриджа, 8192 байти, без заголовка (як у C++-порту). Без нього бордюр стає червоним.

## Керування

| | Клавіатура | Джойстик |
|---|---|---|
| політ | Q A O P | Kempston |
| вогонь | Space або M | вогонь |
| START | Enter | (Next: START на джойпаді Mega Drive) |
| SELECT (гра, 1-8) | G | (Next: A на джойпаді Mega Drive) |
| пауза | H | |

На Next є ще кілька клавіш (PAL/NTSC, звук, частота процесора, час кадру на бордюрі):
[NEXT.uk.md](NEXT.uk.md).

## Як перевіряється

Усе, що змінює поведінку гри, робиться спочатку в C++-порті, потім на Next, потім у копії
того самого коду в порті на TS-Conf. Кожен порт має свою перевірку: програма йде на ядрі
Xpeccy+ без вікна поруч із C++-портом, з тим самим введенням і тим самим лічильником POKEY, і
після кожного кадру вони порівнюються: стан гри, генератор річки, панель і картинка піксель у
піксель (`make check`, `make -C tsconf check`; вигаданий гравець грає сотні тисяч кадрів).
Програму для Next звірено ще й із самим оригінальним картриджем на libatari800
(`make check-original`).

## Збирання

```
make deps          # sjasmplus, C++-порт і Xpeccy+ у deps/ (git, компілятор C/C++, make, cmake, zlib)
make               # build/river_raid.nex
make -C tsconf     # tsconf/build/river_raid.spg
```

Для збирання потрібен лише sjasmplus; перевіркам — решта і ваш ROM у `rom/River_Raid.rom`.

## Репозиторій

| Шлях | Що |
|---|---|
| `src/`, `tools/`, `Makefile` | програма для ZX Spectrum Next і її перевірки ([NEXT.uk.md](NEXT.uk.md)) |
| `tsconf/` | порт на TS-Conf: власний проєкт і збирання, код гри скопійовано з `src/` ([tsconf/README.uk.md](tsconf/README.uk.md)) |
| [docs/HOW_IT_WORKS.uk.md](docs/HOW_IT_WORKS.uk.md) | як картинку, зіткнення і звук Atari зроблено на Next і на TS-Conf, для всіх |
| [docs/NOTES.uk.md](docs/NOTES.uk.md) | як зроблено програму для Next і що з'ясувалося, з цифрами |
| [tsconf/NOTES.uk.md](tsconf/NOTES.uk.md) | власне в порту для TS-Conf: плата, переривання, General Sound, старт, з цифрами |
| [docs/CODE.uk.md](docs/CODE.uk.md) | вихідний код для Next на асемблері за процедурами |
| [tsconf/CODE.uk.md](tsconf/CODE.uk.md) | вихідний код для TS-Conf на асемблері за процедурами і чим дві машини відрізняються |
| [HANDOFF.uk.md](HANDOFF.uk.md) | стан проєкту, щоб продовжити роботу |

## Ліцензія

Власний код і документація проєкту — під ліцензією MIT, див. [LICENSE](LICENSE).
`src/palette.inc` і `tsconf/src/palette_ts.inc` зроблено з моделі палітри C++-порту (MIT).
`src/font.inc` і `tsconf/src/font.inc` — шрифт AltirraOS (Copyright (C) 2008-2018 Avery Lee;
копіювати й поширювати можна з його повідомленням, яке файли зберігають), як у C++-порті: ROM
OS Atari не входить у картридж. Перевірки використовують
[Xpeccy+](https://github.com/dotkoval/xpeccy-plus) (MIT) і асемблер
[sjasmplus](https://github.com/z00m128/sjasmplus) (BSD-3); у репозиторій вони не входять,
`make deps` їх завантажує. Сам River Raid (ROM, його код, графіка і звук) належить
правовласникам, і ця ліцензія на нього не поширюється.
