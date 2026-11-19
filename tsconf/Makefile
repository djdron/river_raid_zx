# River Raid for TS-Conf (ZX Evolution / Pentevo), its own build, apart from the Next's.
# Uses the repository's deps/ (make deps at the top: sjasmplus, the C++ port, Xpeccy+).
#
# make            build/river_raid.spg: the game for Wild Commander; it
#                 reads River_Raid.rom from the SD card itself (anywhere on it)
# make sna        build/river_raid.sna: a 128K snapshot with your ROM in (../rom/River_Raid.rom)
# make check      runs it on Xpeccy+'s TSConf core and compares it with the C++ port (needs
#                 your ROM at ../rom/River_Raid.rom; FRAMES=... how many, 3000 by default)
# make palette    writes src/palette_ts.inc again (the C++ port's palette model)

SJASMPLUS ?= ../deps/sjasmplus/sjasmplus
ROM ?= ../rom/River_Raid.rom
FRAMES ?= 3000
SOURCES := $(wildcard src/*.asm src/*.inc)

all: build/river_raid.spg

build/river_raid.spg: $(SOURCES) tools/mkspg.py
	@mkdir -p build
	$(SJASMPLUS) --nologo --msg=war -isrc -DSPG --sym=build/spg.sym src/river_raid.asm
	python3 tools/mkspg.py build $@

sna: build/river_raid.sna

build/river_raid.sna: $(SOURCES) $(ROM)
	@mkdir -p build
	$(SJASMPLUS) --nologo --msg=war -isrc -DROM_FILE='"$(ROM)"' src/river_raid.asm

# the check's build: the program's pages (the check puts the cartridge in and starts it)
build/ts_page2.bin: $(SOURCES)
	@mkdir -p build
	$(SJASMPLUS) --nologo --msg=war -isrc -DTEST --sym=build/test.sym src/river_raid.asm

build/tools/tscheck build/tools/mkpalette_ts: tools/*.cpp tools/*.h tools/CMakeLists.txt
	cmake -S tools -B build/tools -DCMAKE_BUILD_TYPE=Release
	cmake --build build/tools -j8

check: build/ts_page2.bin build/tools/tscheck
	build/tools/tscheck $(ROM) build $(FRAMES) build/check_frame.ppm

palette: build/tools/mkpalette_ts
	build/tools/mkpalette_ts src/palette_ts.inc

clean:
	rm -rf build

.PHONY: all sna check palette clean
