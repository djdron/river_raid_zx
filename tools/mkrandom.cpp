// Writes src/random.inc: the map that moves POKEY's counter 16 frames on, as 17 rows of 3
// bytes: bit i of the new counter = parity of (row i AND the counter).
//
// usage: mkrandom <out.inc>
#include <cstdio>

#include "pokey_counter.h"

int main(int argc, char **argv) {
	if (argc < 2) {
		std::fprintf(stderr, "usage: %s <out.inc>\n", argv[0]);
		return 2;
	}
	uint32_t column[17];
	for (int j = 0; j < 17; j++) column[j] = rrzx::pokeyAdvance(1u << j, rrzx::kReadEvery);
	FILE *f = std::fopen(argv[1], "w");
	if (!f) {
		std::fprintf(stderr, "cannot write %s\n", argv[1]);
		return 1;
	}
	std::fprintf(f, "; POKEY's counter 16 NTSC frames on: bit i = parity of (row i AND the counter),\n"
		"; rows from bit 0, 3 bytes each from the low one. Made by tools/mkrandom.\n");
	for (int i = 0; i < 17; i++) {
		uint32_t row = 0;
		for (int j = 0; j < 17; j++)
			if (column[j] >> i & 1) row |= 1u << j;
		std::fprintf(f, "\tdb $%02X,$%02X,$%02X\t; bit %d\n", row & 0xFF, (row >> 8) & 0xFF, row >> 16, i);
	}
	std::fclose(f);
	return 0;
}
