# make            build/river_view.nex (needs deps/: make deps)
# make check      runs the viewer on Xpeccy+'s Next core and compares it with the C++ port
#                 (needs your ROM at rom/River_Raid.rom; LINES=... how many lines, 3000 by default)
# make palette    writes src/palette.inc again from the C++ port's palette model
# make deps       fetches and builds sjasmplus, the C++ port and Xpeccy+ into deps/

SJASMPLUS ?= deps/sjasmplus/sjasmplus
ROM ?= rom/River_Raid.rom
LINES ?= 3000
SOURCES := $(wildcard src/*.asm src/*.inc)

all: build/river_view.nex

build/river_view.nex: $(SOURCES)
	@mkdir -p build
	$(SJASMPLUS) --nologo --msg=war -isrc src/viewer.asm

build/test_page4.bin: $(SOURCES)
	@mkdir -p build
	$(SJASMPLUS) --nologo --msg=war -isrc -DTEST src/viewer.asm

build/tools/nxcheck build/tools/mkpalette: tools/*.cpp tools/*.h tools/CMakeLists.txt
	cmake -S tools -B build/tools -DCMAKE_BUILD_TYPE=Release
	cmake --build build/tools

check: build/test_page4.bin build/tools/nxcheck
	build/tools/nxcheck $(ROM) build/test_page4.bin $(LINES) build/check_frame.ppm

palette: build/tools/mkpalette
	build/tools/mkpalette src/palette.inc

deps:
	sh tools/get_deps.sh

clean:
	rm -rf build

.PHONY: all check palette deps clean
