# River Raid for TS-Conf

The port to TS-Conf (ZX Evolution / Pentevo): its own project with its own build, apart from
the ZX Spectrum Next's (the repository's top). It shares only `../deps` (sjasmplus, Xpeccy+:
`make deps` at the top).

So far: `tools/tscheck` runs a program on Xpeccy+'s TSConf core with no window and writes the
320x240 picture as a PPM; `src/ts_test.asm` is the smoke test (the 256-colour mode, 320x240,
a gradient and its palette).

    make          build/ts_test.bin
    make check    runs it, the frame in build/ts_test.ppm (FRAMES=... how many)

Next: the viewer, the attract mode with no sound (320x240).

Russian: [README.ru.md](README.ru.md).
