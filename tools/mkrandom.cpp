// Writes src/random.inc: the maps that move POKEY's counter one frame on (NTSC, PAL), 17 columns of 3
// bytes: the new counter is the XOR of the columns of the counter's set bits.
//
// usage: mkrandom <out.inc>
#include <cstdio>

#include "pokey_counter.h"

int main(int argc, char **argv) {
	if (argc < 2) {
		std::fprintf(stderr, "usage: %s <out.inc>\n", argv[0]);
		return 2;
	}
	uint32_t column[2][17];
	for (int j = 0; j < 17; j++) {
		column[0][j] = rrzx::pokeyAdvance(1u << j, rrzx::kFrameCycles);
		column[1][j] = rrzx::pokeyAdvance(1u << j, rrzx::kPalFrameCycles);
	}
	FILE *f = std::fopen(argv[1], "w");
	if (!f) {
		std::fprintf(stderr, "cannot write %s\n", argv[1]);
		return 1;
	}
	std::fprintf(f, "; POKEY's counter one frame on (NTSC, then PAL): the XOR of column j for each set bit j\n"
		"; of the counter, 3 bytes each from the low one. Made by tools/mkrandom.\n");
	for (int t = 0; t < 2; t++) {
		std::fprintf(f, "%s\n", t ? "random_columns_pal:" : "random_columns_ntsc:");
		for (int j = 0; j < 17; j++)
			std::fprintf(f, "\tdb $%02X,$%02X,$%02X\t; bit %d\n", column[t][j] & 0xFF, (column[t][j] >> 8) & 0xFF,
				column[t][j] >> 16, j);
	}
	std::fclose(f);
	return 0;
}
