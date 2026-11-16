// Writes src/palette.inc: Atari colour code -> the Next's colour as nextreg $41 takes it.
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
	std::fprintf(f, "; Atari colour code (hue << 4 | luminance) -> the Next's colour as nextreg $41 takes it\n"
		"; (RRRGGGBB): PAL colours of the C++ port's Altirra model. Made by tools/mkpalette.\n");
	for (int code = 0; code < 256; code += 8) {
		std::fprintf(f, "\tdb ");
		for (int i = 0; i < 8; i++) std::fprintf(f, "$%02X%s", rrzx::nextColour8(uint8_t(code + i)), i < 7 ? "," : "");
		std::fprintf(f, "\t; $%02X\n", code);
	}
	std::fclose(f);
	return 0;
}
