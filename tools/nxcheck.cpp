// Runs the viewer's test image on Xpeccy+'s ZX Spectrum Next core, with no window, and
// compares it with the C++ port as it goes:
//   - each line: the generator's state in the Atari's RAM (RiverGen::diffWithRam), the
//     48 bytes of the line, and the drawn row (drawScreenLine) in row_buf;
//   - at the end, the picture of the last whole frame, pixel by pixel: the river's rows on
//     Layer 2 in the Next's colours, black around them.
//
// usage: nxcheck <River_Raid.rom> <build/test_page4.bin> <lines> [frame.ppm]
#include <cstdio>
#include <cstdlib>
#include <cstring>
#include <deque>
#include <string>
#include <vector>

#include "spectrum.h"
#include "cpu/Z80/z80.h"

#include "next_palette.h"
#include "river_draw.h"
#include "river_gen.h"

namespace {

// The viewer's memory (src/viewer.asm)
constexpr int kAtariRamPage = 30;
constexpr int kCodePage = 4;
constexpr int kRomPage = 5;
constexpr uint16_t kLineBuf = 0xE000;
constexpr uint16_t kRowBuf = 0xE100;
constexpr int kWindowFirst = 20;   // first colour clock shown
constexpr int kRiverLines = 160;
constexpr int kRiverTop = 40;      // Layer 2 row of the river's top line
// Where Layer 2 (320x256) is in the core's picture (360 dots x 303 lines, 2 columns a dot)
constexpr int kL2Left = 8;         // dots
constexpr int kL2Top = 24;         // lines

int sramOffset(int page) { return 0x40000 + page * 0x2000; }

uint8_t readZ80(Computer *comp, uint16_t addr) {
	const int page = comp->next->mmu[addr >> 13];
	return comp->mem->ramData[sramOffset(page) + (addr & 0x1FFF)];
}

bool readFile(const char *path, std::vector<uint8_t> &data) {
	FILE *f = std::fopen(path, "rb");
	if (!f) return false;
	std::fseek(f, 0, SEEK_END);
	data.resize(size_t(std::ftell(f)));
	std::fseek(f, 0, SEEK_SET);
	const bool ok = std::fread(data.data(), 1, data.size(), f) == data.size();
	std::fclose(f);
	return ok;
}

}  // namespace

int main(int argc, char **argv) {
	if (argc < 4) {
		std::fprintf(stderr, "usage: %s <River_Raid.rom> <test_page4.bin> <lines> [frame.ppm]\n", argv[0]);
		return 2;
	}
	std::vector<uint8_t> romData, code;
	rr::Rom rom;
	if (!rom.load(argv[1]) || !readFile(argv[1], romData)) { std::fprintf(stderr, "cannot read %s\n", argv[1]); return 2; }
	if (!readFile(argv[2], code) || code.size() != 0x2000) { std::fprintf(stderr, "cannot read %s\n", argv[2]); return 2; }
	const int lines = std::atoi(argv[3]);
	if (lines <= kRiverLines) { std::fprintf(stderr, "lines: more than %d\n", kRiverLines); return 2; }

	// The machine as the core's own simulation runs it: a program in place of the firmware
	// (here a jump to $8000), the SRAM loaded with the program and the cartridge
	xhost_time_fixed = 1759665600;
	Computer *comp = compCreate();
	comp->vid->drawAll = 1;
	if (!compSetHardware(comp, "ZXNext")) { std::fprintf(stderr, "no ZXNext core\n"); return 1; }
	compSetBaseFrq(comp, 3.5);
	compReset(comp, RES_DEFAULT);
	bytesPerLine = comp->vid->full.x * 8;
	bufSize = bytesPerLine * comp->vid->full.y;
	comp_kbd_release(comp);
	comp->next->busRomcs = 1;
	next_reset_open = 1;
	next_ear_tied = 1;
	uint8_t *sram = comp->mem->ramData;
	std::memset(sram, 0, MEM_2M);
	sram[0] = 0xC3;   // jp $8000
	sram[1] = 0x00;
	sram[2] = 0x80;
	std::memcpy(sram + sramOffset(kCodePage), code.data(), 0x2000);
	std::memcpy(sram + sramOffset(kRomPage), romData.data(), 0x2000);
	const uint16_t hook = uint16_t(code[3] | (code[4] << 8));

	rr::RiverGen gen(rom);
	gen.startGame(1, false);
	std::deque<std::array<uint8_t, rr::kRowWidth>> rows;   // drawn rows, newest first
	int line = 0, errors = 0;
	uint8_t ram[0x4000];
	while (line < lines) {
		compExec(comp);
		if (comp->cpu->regPC != hook) continue;
		line++;
		uint8_t ref[rr::kLineBytes];
		gen.nextLine(ref);
		std::array<uint8_t, rr::kRowWidth> row;
		rr::drawScreenLine(rom, gen.s, ref, row.data());
		rows.push_front(row);
		if (rows.size() > 512) rows.pop_back();

		std::vector<std::string> diffs;
		for (int i = 0; i < 0x4000; i++) ram[i] = sram[sramOffset(kAtariRamPage) + i];
		diffs = gen.diffWithRam(ram, true);
		for (int i = 0; i < rr::kLineBytes; i++) {
			const uint8_t z = readZ80(comp, uint16_t(kLineBuf + i));
			if (z != ref[i]) {
				char buf[80];
				std::snprintf(buf, sizeof buf, "line byte %d: z80=%02X c++=%02X", i, z, ref[i]);
				diffs.push_back(buf);
			}
		}
		for (int i = 0; i < 2 * 160; i++) {
			const uint8_t z = readZ80(comp, uint16_t(kRowBuf + i));
			const uint8_t c = row[size_t(2 * kWindowFirst + i)];
			if (z != c) {
				char buf[80];
				std::snprintf(buf, sizeof buf, "row column %d: z80=%02X c++=%02X", i, z, c);
				diffs.push_back(buf);
			}
		}
		if (!diffs.empty()) {
			std::printf("line %d (level %d, line in block %d): %zu differences\n", line, gen.s.level, gen.s.lineInBlock, diffs.size());
			for (size_t i = 0; i < diffs.size() && i < 20; i++) std::printf("  %s\n", diffs[i].c_str());
			if (++errors >= 3) break;
			gen.loadFromRam(ram);   // go on from the Z80's state
		}
	}
	if (errors) {
		std::printf("FAIL: lines differ\n");
		return 1;
	}
	std::printf("%d lines: state, line and row the same\n", line);

	// The frame being drawn ends: its river rows were drawn with the scroll set before line
	// `line - 1` was made, so its top row is line `line - 2` (rows[2]).
	const int swaps = bufSwaps;
	while (bufSwaps == swaps) compExec(comp);
	int bad = 0, firstBadX = -1, firstBadY = -1;
	const int width = comp->vid->vend.x * 2, height = comp->vid->vend.y;
	auto pixel = [&](int x, int y) { return bufimg + y * bytesPerLine + x * 4; };
	for (int y = 0; y < 256; y++) {
		for (int x = 0; x < 320; x++) {
			uint8_t want[3] = {0, 0, 0};
			const int r = y - kRiverTop;
			if (r >= 0 && r < kRiverLines) {
				const uint8_t colour = rows[size_t(r + 2)][size_t(2 * kWindowFirst + x)];
				rrzx::nextRgb(rrzx::nextColour(colour), want);
			}
			for (int h = 0; h < 2; h++) {   // two columns a dot
				const uint8_t *p = pixel(2 * (kL2Left + x) + h, kL2Top + y);
				if (p[0] != want[0] || p[1] != want[1] || p[2] != want[2]) {
					if (!bad++) { firstBadX = x; firstBadY = y; }
				}
			}
		}
	}
	if (argc > 4) {
		FILE *f = std::fopen(argv[4], "wb");
		if (f) {
			std::fprintf(f, "P6\n%d %d\n255\n", width, height);
			for (int y = 0; y < height; y++)
				for (int x = 0; x < width; x++) std::fwrite(pixel(x, y), 1, 3, f);
			std::fclose(f);
		}
	}
	if (bad) {
		std::printf("FAIL: the picture differs in %d pixels, the first at Layer 2 (%d, %d)\n", bad, firstBadX, firstBadY);
		return 1;
	}
	std::printf("picture: the same, pixel for pixel\n");
	return 0;
}
