// tscheck: runs a TS-Conf program on Xpeccy+'s TSConf core with no window and writes the
// frame as a PPM. usage: tscheck <prog.bin> <frames> <out.ppm>
// (the first step of the TS-Conf port: the program is loaded at $8000, page 2's window)
#include <cstdio>
#include <cstdlib>
#include <cstring>
#include <vector>
#include "spectrum.h"
#include "cpu/Z80/z80.h"

int main(int argc, char **argv) {
	if (argc < 4) { std::fprintf(stderr, "usage: tscheck prog.bin frames out.ppm\n"); return 2; }
	FILE *f = std::fopen(argv[1], "rb");
	if (!f) { std::perror(argv[1]); return 2; }
	std::vector<uint8_t> prog(0x4000);
	const size_t n = std::fread(prog.data(), 1, prog.size(), f);
	std::fclose(f);
	const int frames = std::atoi(argv[2]);
	Computer *comp = compCreate();
	comp->vid->drawAll = 1;
	if (!compSetHardware(comp, "TSConf")) { std::fprintf(stderr, "no TSConf core\n"); return 1; }
	compSetBaseFrq(comp, 3.5);
	memSetSize(comp->mem, MEM_4M, -1);   // the TS-Conf board's 4 MB (the core starts with 128K)
	compReset(comp, RES_DEFAULT);
	bytesPerLine = comp->vid->full.x * 8;
	bufSize = bytesPerLine * comp->vid->full.y;
	const int codePage = 2;
	std::memcpy(comp->mem->ramData + codePage * 0x4000, prog.data(), n);
	memSetBank(comp->mem, 0x80, MEM_RAM, codePage, MEM_16K, NULL, NULL, NULL);
	comp->cpu->regPC = 0x8000;
	if (std::getenv("TSTRACE")) {   // the last PCs before the program leaves $8000-$BFFF
		int hist[64] = {}; int hn = 0; long steps = 0;
		while (comp->cpu->regPC >= 0x8000 && comp->cpu->regPC < 0xC000 && steps < 400000000L) { hist[hn++ & 63] = comp->cpu->regPC; compExec(comp); steps++; }
		std::printf("left at PC %04X after %ld steps; before:", comp->cpu->regPC, steps);
		for (int k = 0; k < 24; k++) std::printf(" %04X", hist[(hn - 24 + k) & 63]);
		std::printf("\nSP %04X IFF1 %d IM %d; stack top %02X%02X\n", comp->cpu->regSP, comp->cpu->flgIFF1, comp->cpu->regIM, comp->mem->ramData[2 * 0x4000 + (comp->cpu->regSP & 0x3FFF) + 1], comp->mem->ramData[2 * 0x4000 + (comp->cpu->regSP & 0x3FFF)]);
	}
	for (int i = 0; i < frames; i++) {
		const int swaps = bufSwaps;
		while (bufSwaps == swaps) compExec(comp);
	}
	// The picture: the TS-Conf screen (scrsize at xPos/yPos from the start of the buffer's
	// rows), one dot per pixel (two buffer pixels a dot); TSFULL dumps the whole buffer
	const bool full = std::getenv("TSFULL") != nullptr;
	const int width = full ? comp->vid->full.x * 2 : comp->vid->scrsize.x, height = full ? comp->vid->full.y : comp->vid->scrsize.y;
	const int x0 = full ? 0 : comp->vid->tsconf.xPos * 2, y0 = full ? 0 : comp->vid->tsconf.yPos, step = full ? 1 : 2;
	FILE *o = std::fopen(argv[3], "wb");
	if (!o) { std::perror(argv[3]); return 2; }
	std::fprintf(o, "P6\n%d %d\n255\n", width, height);
	for (int y = 0; y < height; y++)
		for (int x = 0; x < width; x++) std::fwrite(bufimg + (y0 + y) * bytesPerLine + (x0 + x * step) * 4, 1, 3, o);
	std::fclose(o);
	std::printf("%d frames, %dx%d, PC %04X; VConfig %02X, VPage %02X, latched %04X\n", frames, width, height, comp->cpu->regPC,
		comp->vid->tsconf.p00af, comp->vid->vidPage, comp->vid->tsconf.lat.mask);
	return 0;
}
