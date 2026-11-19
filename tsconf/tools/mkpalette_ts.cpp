// Writes src/palette_ts.inc: Atari colour code -> TS-Conf's CRAM word, the C++ port's PAL
// colours (Altirra model) at the board's levels: 0-24 a channel (the VDAC's; bit 15 clear),
// the word 0RRRRRGG GGGBBBBB. Two tables of 256: the low bytes, then the high ones.
//
// usage: mkpalette_ts <out.inc>
#include <cmath>
#include <cstdio>

#include "palette.h"
#include "ts_palette.h"

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
	std::fprintf(f, "; Atari colour code (hue << 4 | luminance) -> TS-Conf's CRAM word (levels 0-24): the\n"
		"; low bytes, then the high bytes. PAL colours of the C++ port's Altirra model. Made by\n"
		"; tools/mkpalette_ts.\n");
	for (int half = 0; half < 2; half++)
		for (int code = 0; code < 256; code += 8) {
			std::fprintf(f, "\tdb ");
			for (int i = 0; i < 8; i++) {
				const uint16_t w = rrts::cramWord(uint8_t(code + i));
				std::fprintf(f, "$%02X%s", half ? w >> 8 : w & 0xFF, i < 7 ? "," : "");
			}
			std::fprintf(f, "\t; $%02X%s\n", code, half ? " (high)" : "");
		}
	std::fclose(f);
	return 0;
}
