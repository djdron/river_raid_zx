# River Raid for TS-Conf (ZX Evolution / Pentevo), its own build, apart from the Next's.
# Uses the repository's deps/ (make deps at the top: sjasmplus, Xpeccy+).
#
# make            build/ts_test.bin (for now: the 320x240 256-colour smoke test)
# make check      runs it on Xpeccy+'s TSConf core, the frame in build/ts_test.ppm
#                 (FRAMES=... how many, 40 by default)

SJASMPLUS ?= ../deps/sjasmplus/sjasmplus
FRAMES ?= 40
SOURCES := $(wildcard src/*.asm src/*.inc)

all: build/ts_test.bin

build/ts_test.bin: $(SOURCES)
	@mkdir -p build
	$(SJASMPLUS) --nologo --msg=war -isrc --raw=$@ src/ts_test.asm

build/tools/tscheck: tools/*.cpp tools/CMakeLists.txt
	cmake -S tools -B build/tools -DCMAKE_BUILD_TYPE=Release
	cmake --build build/tools -j8

check: build/ts_test.bin build/tools/tscheck
	build/tools/tscheck build/ts_test.bin $(FRAMES) build/ts_test.ppm

clean:
	rm -rf build

.PHONY: all check clean
