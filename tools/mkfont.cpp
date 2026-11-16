// Writes src/font.inc: the pages of the Atari OS character set that the game copies at
// power-on (A0FB-A113): $E000, $E100 and $E300, 256 bytes each. The font is AltirraOS's, as
// the C++ port has it built in (river_raid/port/src/os_font.cpp), with its notice.
//
// usage: mkfont <out.inc>
#include <cstdio>

#include "os_font.h"

int main(int argc, char **argv) {
	if (argc < 2) {
		std::fprintf(stderr, "usage: %s <out.inc>\n", argv[0]);
		return 2;
	}
	uint8_t font[rr::kOsFontBytes];
	rr::builtinOsFont(font);
	FILE *f = std::fopen(argv[1], "w");
	if (!f) {
		std::fprintf(stderr, "cannot write %s\n", argv[1]);
		return 1;
	}
	std::fprintf(f,
		"; The Atari OS character set's pages $E000, $E100 and $E300 (ATASCII internal order). Made by\n"
		"; tools/mkfont from the font of AltirraOS, the replacement OS that comes with the atari800\n"
		"; emulator (src/roms/altirraos_800.c, $E000-$E3FF). Its notice:\n"
		";\n"
		";   Altirra - Atari 800/800XL emulator\n"
		";   Kernel ROM replacement, version 3.11\n"
		";   Copyright (C) 2008-2018 Avery Lee\n"
		";\n"
		";   Copying and distribution of this file, with or without modification,\n"
		";   are permitted in any medium without royalty provided the copyright\n"
		";   notice and this notice are preserved.  This file is offered as-is,\n"
		";   without any warranty.\n");
	const int pages[3] = {0, 1, 3};
	const char *names[3] = {"font_e000", "font_e100", "font_e300"};
	for (int p = 0; p < 3; p++) {
		std::fprintf(f, "%s:\n", names[p]);
		for (int c = 0; c < 32; c++) {
			std::fprintf(f, "\tdb ");
			for (int r = 0; r < 8; r++)
				std::fprintf(f, "$%02X%s", font[pages[p] * 256 + c * 8 + r], r < 7 ? "," : "");
			std::fprintf(f, "\t; %d\n", pages[p] * 32 + c);
		}
	}
	std::fclose(f);
	return 0;
}
