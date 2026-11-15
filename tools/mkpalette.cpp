// Writes src/palette.inc: Layer 2's palette, index = Atari colour code, as the two bytes
// nextreg $44 takes (RRRGGGBB, then the low blue bit).
//
// usage: mkpalette <out.inc>
#include <cstdio>

#include "next_palette.h"

int main(int argc, char **argv) {
	if (argc < 2) {
		std::fprintf(stderr, "usage: %s <out.inc>\n", argv[0]);
		return 2;
	}
	FILE *f = std::fopen(argv[1], "w");
	if (!f) {
		std::fprintf(stderr, "cannot write %s\n", argv[1]);
		return 1;
	}
	std::fprintf(f, "; Layer 2 palette: index = Atari colour code (hue << 4 | luminance), PAL colours of\n"
		"; the C++ port's Altirra model, as nextreg $44 takes them. Made by tools/mkpalette.\n");
	for (int code = 0; code < 256; code++) {
		const uint16_t c = rrzx::nextColour(uint8_t(code));
		std::fprintf(f, "\tdb $%02X,$%02X\t; $%02X\n", c >> 1, c & 1, code);
	}
	std::fclose(f);
	return 0;
}
