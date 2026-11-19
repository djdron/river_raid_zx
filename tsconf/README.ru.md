# River Raid для TS-Conf

Порт на TS-Conf (ZX Evolution / Pentevo): отдельный проект со своей сборкой, отдельно от
версии для ZX Spectrum Next (корень репозитория). Общая только `../deps` (sjasmplus, Xpeccy+:
`make deps` в корне).

Пока: `tools/tscheck` запускает программу на ядре TSConf из Xpeccy+ без окна и пишет картинку
320x240 в PPM; `src/ts_test.asm` — проверочный тест (режим 256 цветов, 320x240, градиент и его
палитра).

    make          build/ts_test.bin
    make check    запускает его, кадр в build/ts_test.ppm (FRAMES=... сколько кадров)

Дальше: вьювер, attract mode без звука (320x240).

English: [README.md](README.md).
