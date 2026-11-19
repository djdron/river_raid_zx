# River Raid для современных ZX Spectrum

[English](README.md) | Русский | [Українська](README.uk.md) | [Deutsch](README.de.md) | [Polski](README.pl.md) | [Italiano](README.it.md) | [Español](README.es.md) | [中文](README.zh.md) | [日本語](README.ja.md)

River Raid (Activision, Atari 8-bit, 1983, автор Кэрол Шоу) на сегодняшних машинах ZX Spectrum:
**ZX Spectrum Next** и **TS-Conf** (ZX Evolution / Pentevo). Оба порта сделаны на основе
C++-порта [djdron/river_raid](https://github.com/djdron/river_raid): в нём разобрано, как
оригинал делает всё, и он сверен с оригиналом кадр за кадром. Логика игры — как в оригинале,
кадр за кадром, в той же RAM по тем же адресам; каждая машина показывает её своим железом.

Неофициальный любительский проект в учебных целях, не связан с Activision и Microsoft. Игры
в нём нет: программа читает ваш собственный образ картриджа во время работы.

## Порты

| | [ZX Spectrum Next](NEXT.ru.md) | [TS-Conf](tsconf/README.ru.md) (ZX Evolution / Pentevo) |
|---|---|---|
| Файл | `river_raid.nex` (открывается в Browser) | `river_raid.spg` (запускается из Wild Commander) |
| ROM | `River_Raid.rom` в той же папке, что и .nex | `River_Raid.rom` где угодно на SD-карте (FAT16/32) |
| Река | Layer 2, цвет берега по строкам — Copper | режим 16 цветов с аппаратной прокруткой, цвет берега по строкам — кадровое прерывание (палитра на каждый цвет) |
| Враги, самолёт, ракеты | спрайты | спрайты |
| Панель, бегущая строка | tilemap | своя картинка, включаемая под рекой, тайлы, спрайты |
| Звук | POKEY эмулирует программа в ЦАП (zxnDMA), чистые тоны на AY | весь на General Sound (POKEY эмулирует свой Z80 карты, моно); без неё — чистые тоны на AY TurboSound |
| Процессор | 28 МГц (успевает и на 14) | 14 МГц (успевает и на 7) |
| ТВ | PAL 50 Гц или NTSC 60 Гц (CAPS + 1) | PAL 50 Гц |
| Подробно | [NEXT.ru.md](NEXT.ru.md) | [tsconf/README.ru.md](tsconf/README.ru.md) |

Игра готова на обоих: attract mode, игры 1-8 (старт с моста 1, 5, 20 или 50; один игрок или
двое по очереди), самолёт, топливо и базы, враги, танки, ракеты вертолётов, мосты, очки,
жизни, рекорд, пауза, панель и бегущая строка с радужным логотипом. На настоящем железе пока
не запускались: оба сверяются на эмуляторе [Xpeccy+](https://github.com/dotkoval/xpeccy-plus)
(его ядра Next и TSConf).

## Где взять

Программы собираются на GitHub при каждом push: [Actions](https://github.com/djdron/river_raid_zx/actions),
workflow `build` (.nex) или `tsconf` (.spg), его артефакт. Нужен свой `River_Raid.rom`: образ
картриджа, 8192 байта, без заголовка (как у C++-порта). Без него бордюр становится красным.

## Управление

| | Клавиатура | Джойстик |
|---|---|---|
| полёт | Q A O P | Kempston |
| огонь | Space или M | огонь |
| START | Enter | (Next: START на джойпаде Mega Drive) |
| SELECT (игра, 1-8) | G | (Next: A на джойпаде Mega Drive) |
| пауза | H | |

На Next есть ещё несколько клавиш (PAL/NTSC, звук, частота процессора, время кадра на
бордюре): [NEXT.ru.md](NEXT.ru.md).

## Как проверяется

Всё, что меняет поведение игры, делается сначала в C++-порте, потом на Next, потом в копии
того же кода в порте на TS-Conf. У каждого порта своя проверка: программа идёт на ядре
Xpeccy+ без окна рядом с C++-портом, с тем же вводом и тем же счётчиком POKEY, и после
каждого кадра они сравниваются: состояние игры, генератор реки, панель и картинка пиксель в
пиксель (`make check`, `make -C tsconf check`; придуманный игрок играет сотни тысяч кадров).
Программа для Next сверена ещё и с самим оригинальным картриджем на libatari800
(`make check-original`).

## Сборка

```
make deps          # sjasmplus, C++-порт и Xpeccy+ в deps/ (git, компилятор C/C++, make, cmake, zlib)
make               # build/river_raid.nex
make -C tsconf     # tsconf/build/river_raid.spg
```

Для сборки нужен только sjasmplus; проверкам — остальное и ваш ROM в `rom/River_Raid.rom`.

## Репозиторий

| Путь | Что |
|---|---|
| `src/`, `tools/`, `Makefile` | программа для ZX Spectrum Next и её проверки ([NEXT.ru.md](NEXT.ru.md)) |
| `tsconf/` | порт на TS-Conf: свой проект и сборка, код игры скопирован из `src/` ([tsconf/README.ru.md](tsconf/README.ru.md)) |
| [docs/HOW_IT_WORKS.ru.md](docs/HOW_IT_WORKS.ru.md) | как картинка и столкновения Atari сделаны на Next, для всех |
| [docs/NOTES.ru.md](docs/NOTES.ru.md) | как сделана программа для Next и что выяснилось, с цифрами |
| [docs/CODE.ru.md](docs/CODE.ru.md) | исходный код для Next на ассемблере по процедурам |
| [HANDOFF.ru.md](HANDOFF.ru.md) | состояние проекта, чтобы продолжить работу |

## Лицензия

Собственный код и документация проекта под лицензией MIT, см. [LICENSE](LICENSE).
`src/palette.inc` и `tsconf/src/palette_ts.inc` сделаны из модели палитры C++-порта (MIT).
`src/font.inc` и `tsconf/src/font.inc` — шрифт AltirraOS (Copyright (C) 2008-2018 Avery Lee;
копировать и распространять можно с его уведомлением, которое файлы сохраняют), как в
C++-порте: ROM OS Atari не входит в картридж. Проверки используют
[Xpeccy+](https://github.com/dotkoval/xpeccy-plus) (MIT) и ассемблер
[sjasmplus](https://github.com/z00m128/sjasmplus) (BSD-3); в репозиторий они не входят,
`make deps` их скачивает. Сам River Raid (ROM, его код, графика и звук) принадлежит
правообладателям, и эта лицензия на него не распространяется.
