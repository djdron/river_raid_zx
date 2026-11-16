# make            build/river_view.nex (needs deps/: make deps)
# make check      runs the viewer on Xpeccy+'s Next core and compares it with the C++ port
#                 (needs your ROM at rom/River_Raid.rom; FRAMES=... how many, 3000 by default)
# make profile    where the time of one frame goes on the Next (FRAMES=... which one)
# make palette    writes src/palette.inc and src/random.inc again (the C++ port's palette
#                 model, POKEY's counter)
# make deps       fetches and builds sjasmplus, the C++ port and Xpeccy+ into deps/

SJASMPLUS ?= deps/sjasmplus/sjasmplus
ROM ?= rom/River_Raid.rom
FRAMES ?= 3000
SOURCES := $(wildcard src/*.asm src/*.inc)

all: build/river_view.nex

build/river_view.nex: $(SOURCES)
	@mkdir -p build
	$(SJASMPLUS) --nologo --msg=war -isrc src/viewer.asm

build/test_page4.bin: $(SOURCES)
	@mkdir -p build
	$(SJASMPLUS) --nologo --msg=war -isrc -DTEST --sym=build/test.sym src/viewer.asm

build/tools/nxcheck build/tools/mkpalette build/tools/mkrandom: tools/*.cpp tools/*.h tools/CMakeLists.txt
	cmake -S tools -B build/tools -DCMAKE_BUILD_TYPE=Release
	cmake --build build/tools

check: build/test_page4.bin build/tools/nxcheck
	build/tools/nxcheck $(ROM) build $(FRAMES) build/check_frame.ppm

# where a frame's time goes (the frame after FRAMES), per routine
profile: build/test_page4.bin build/tools/nxcheck
	NXHIST=build/profile.txt build/tools/nxcheck $(ROM) build $(FRAMES) > /dev/null
	python3 tools/prof.py build/test.sym build/profile.txt

palette: build/tools/mkpalette build/tools/mkrandom
	build/tools/mkpalette src/palette.inc
	build/tools/mkrandom src/random.inc

deps:
	sh tools/get_deps.sh

clean:
	rm -rf build

.PHONY: all check profile palette deps clean
