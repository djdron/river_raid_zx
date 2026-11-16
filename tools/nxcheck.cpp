// Runs the viewer's test build on Xpeccy+'s ZX Spectrum Next core, with no window, and
// compares it frame by frame with the C++ port's attract mode (rr::Game, as the C++ river
// viewer runs it, with the same POKEY counter):
//   - after every frame: the river generator's state (RiverGen::diffWithRam), the game's
//     state the attract mode changes, player-missile memory, screen memory, and what the
//     DLI left per river line (player 3 and the bank colour, Game::scan);
//   - at the end, the picture of the last frame, pixel by pixel: Game::drawRiver in the
//     Next's colours, black around the river.
// It also reports whether every frame was ready in time on the Next.
//
// usage: nxcheck <River_Raid.rom> <build dir> <frames> [frame.ppm] [-seed N]
#include <array>
#include <cstdio>
#include <cstdlib>
#include <cstring>
#include <deque>
#include <string>
#include <vector>

#include "spectrum.h"
#include "cpu/Z80/z80.h"

#include "game.h"
#include "next_palette.h"
#include "pokey_counter.h"
#include "pokey_random.h"

namespace {

// The viewer's memory (src/viewer.asm)
constexpr int kAtariRamPage = 30;
constexpr int kCodePages[2] = {4, 6};
constexpr int kRomPage = 5;
constexpr uint16_t kScan = 0x6000; // scan_p3, scan_x, scan_size, scan_col, scan_bank: 256 each, by scanline
constexpr int kWindowFirst = 20;   // first colour clock shown
constexpr int kRiverLines = 160;
constexpr int kRiverFirstLine = 28;
constexpr int kRiverTop = 40;      // Layer 2 row of the river's top line
// Where Layer 2 (320x256) is in the core's picture (360 dots x 303 lines, 2 columns a dot)
constexpr int kL2Left = 8;
constexpr int kL2Top = 24;

int sramOffset(int page) { return 0x40000 + page * 0x2000; }

uint8_t readZ80(Computer *comp, uint16_t addr) {
	const int page = comp->next->mmu[addr >> 13];
	return comp->mem->ramData[sramOffset(page) + (addr & 0x1FFF)];
}

bool readFile(const std::string &path, std::vector<uint8_t> &data) {
	FILE *f = std::fopen(path.c_str(), "rb");
	if (!f) return false;
	std::fseek(f, 0, SEEK_END);
	data.resize(size_t(std::ftell(f)));
	std::fseek(f, 0, SEEK_SET);
	const bool ok = std::fread(data.data(), 1, data.size(), f) == data.size();
	std::fclose(f);
	return ok;
}

// The game's state the attract mode changes (river_raid/port/src/game_ram.cpp)
const struct { const char *name; uint16_t addr; } kGameFields[] = {
	{"frameCount", 0x18}, {"attractFlags", 0x29}, {"attractTimer", 0x2A}, {"planeState", 0x76},
	{"speed", 0x59}, {"scrollFrac", 0x30}, {"shellFrame", 0x3B}, {"shellX", 0x3C}, {"shellXFrac", 0x3D},
	{"missileStep", 0xC0}, {"soundExplosion", 0x7C}, {"soundMissile", 0x7F}, {"joystick", 0x19},
	{"joystickPrev", 0xB9}, {"planeX", 0x57}, {"planeFrame", 0x5E}, {"idleTime", 0x78},
	{"hit.bulletHitBank", 0x1A}, {"hit.planeHitBank", 0x1B}, {"hit.bulletHitObject", 0x1C},
	{"hit.planeHitObject", 0x1D}, {"hit.planeHitShell", 0x1E}, {"hit.shellHitObject", 0x1F},
	{"hit.tankAtEdge", 0x20}, {"hit.missileHitPlane", 0x21}, {"hit.missileHitBank", 0x22},
	{"screenTop.lo", 0x3F04}, {"screenTop.hi", 0x3F05},
};

}  // namespace

int main(int argc, char **argv) {
	if (argc < 4) {
		std::fprintf(stderr, "usage: %s <River_Raid.rom> <build dir> <frames> [frame.ppm] [-seed N]\n", argv[0]);
		return 2;
	}
	uint32_t seed = 12345;
	const char *ppm = nullptr;
	for (int i = 4; i < argc; i++) {
		if (!std::strcmp(argv[i], "-seed") && i + 1 < argc) seed = uint32_t(std::strtoul(argv[++i], nullptr, 0));
		else ppm = argv[i];
	}
	std::vector<uint8_t> romData, code[2];
	rr::Rom rom;
	if (!rom.load(argv[1]) || !readFile(argv[1], romData)) { std::fprintf(stderr, "cannot read %s\n", argv[1]); return 2; }
	for (int i = 0; i < 2; i++) {
		const std::string path = std::string(argv[2]) + "/test_page" + std::to_string(kCodePages[i]) + ".bin";
		if (!readFile(path, code[i]) || code[i].size() != 0x2000) { std::fprintf(stderr, "cannot read %s\n", path.c_str()); return 2; }
	}
	const int frames = std::atoi(argv[3]);
	auto word = [&](int at) { return uint16_t(code[0][size_t(at)] | (code[0][size_t(at + 1)] << 8)); };
	const uint16_t frameHook = word(5), applyHook = word(7);
	const uint32_t first = rrzx::pokeyFirstRead(seed);   // POKEY's counter at the first read
	code[0][9] = uint8_t(first);
	code[0][10] = uint8_t(first >> 8);
	code[0][11] = uint8_t(first >> 16);

	// The machine as the core's own simulation runs it: a program in place of the firmware
	// (a jump to $8000), the SRAM loaded with the program and the cartridge
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
	for (int i = 0; i < 2; i++) std::memcpy(sram + sramOffset(kCodePages[i]), code[i].data(), 0x2000);
	std::memcpy(sram + sramOffset(kRomPage), romData.data(), 0x2000);

	// The C++ port's attract mode, as its river viewer runs it
	rr::Game game(rom);
	rr::PokeyRandom random(seed);
	game.startAttract(false);
	random.nextFrame();
	static uint8_t picture[240][rr::kRowWidth];
	std::vector<uint8_t> rows(size_t(kRiverLines) * 320);   // the last frame's river

	auto runTo = [&](uint16_t hook) {
		for (;;) {
			compExec(comp);
			if (comp->cpu->regPC == hook) return;
		}
	};
	int errors = 0;
	static uint8_t ram[0x4000], ref[0x4000];
	long long lastApply = -1, longestFrame = 0, applyTick = -1, workMax = 0, workSum = 0;
	int lateFrames = 0, workMaxFrame = 0, worked = 0;
	for (int f = 1; f <= frames; f++) {
		runTo(frameHook);
		if (applyTick >= 0) {   // the frame's work, from the apply before it
			const long long w = comp->tickTotal - applyTick;
			workSum += w;
			worked++;
			if (w > workMax) { workMax = w; workMaxFrame = f; }
		}
		game.prepare();
		game.display();
		game.drawRiver(picture);
		for (int k = 0; k < kRiverLines; k++)
			std::memcpy(&rows[size_t(k) * 320], &picture[kRiverFirstLine - 8 + k][2 * kWindowFirst], 320);
		game.g.idleTime = 0;
		game.logic(rr::Input(), [&] { return random.read(192, 13); });
		game.vbi([&] { return random.read(248, 30); });
		random.nextFrame();

		std::memcpy(ram, sram + sramOffset(kAtariRamPage), sizeof ram);
		std::memset(ref, 0, sizeof ref);
		game.saveToRam(ref);
		std::vector<std::string> diffs = game.gen.diffWithRam(ram, true);
		char b[120];
		for (const auto &fd : kGameFields)
			if (ram[fd.addr] != ref[fd.addr]) {
				std::snprintf(b, sizeof b, "%s $%02X: z80=%02X c++=%02X", fd.name, fd.addr, ram[fd.addr], ref[fd.addr]);
				diffs.push_back(b);
			}
		for (int a = 0x0B00; a < 0x1000; a++)
			if (ram[a] != ref[a]) {
				std::snprintf(b, sizeof b, "pm $%04X: z80=%02X c++=%02X", a, ram[a], ref[a]);
				diffs.push_back(b);
			}
		uint16_t addr = uint16_t(ram[0x3F04] | (ram[0x3F05] << 8));
		for (size_t k = 0; k < game.screen.size() && k < size_t(kRiverLines); k++) {
			if (std::memcmp(ram + addr, game.screen[k].data(), rr::kLineBytes)) {
				std::snprintf(b, sizeof b, "screen line %zu (at $%04X)", k, addr);
				diffs.push_back(b);
				break;
			}
			addr = uint16_t(addr + rr::kLineBytes);
			if ((addr >> 8) == 0x2F) addr = 0x3000;
			if ((addr >> 8) == 0x3F) addr = 0x2000;
		}
		for (int k = 0; k < kRiverLines; k++) {
			const rr::Game::Scanline &sc = game.scan[size_t(kRiverFirstLine + k)];
			const uint8_t want[5] = {sc.p3, sc.p3x, sc.p3size, sc.p3colour, sc.bankColour};
			static const char *names[5] = {"p3", "p3x", "p3size", "p3colour", "bankColour"};
			for (int i = 0; i < 5; i++) {
				const uint8_t z = readZ80(comp, uint16_t(kScan + 0x100 * i + kRiverFirstLine + k));
				if (z != want[i]) {
					std::snprintf(b, sizeof b, "scan line %d %s: z80=%02X c++=%02X", k, names[i], z, want[i]);
					diffs.push_back(b);
				}
			}
		}
		if (!diffs.empty()) {
			std::printf("frame %d (level %d): %zu differences\n", f, game.gen.s.level, diffs.size());
			for (size_t i = 0; i < diffs.size() && i < 24; i++) std::printf("  %s\n", diffs[i].c_str());
			if (++errors >= 2) break;
			game.loadFromRam(ram);   // go on from the Z80's state
		}
		// in time: one Atari frame per Next frame
		if (getenv("NXHIST") && f == frames) {
			// NXHIST=file: the time spent at each instruction over one frame's work
			runTo(applyHook);
			static long long hist[0x10000];
			long long t = comp->tickTotal;
			for (;;) {
				const uint16_t pc = comp->cpu->regPC;
				compExec(comp);
				hist[pc] += comp->tickTotal - t;
				t = comp->tickTotal;
				if (comp->cpu->regPC == frameHook) break;
			}
			FILE *hf = std::fopen(getenv("NXHIST"), "w");
			for (int a = 0; a < 0x10000; a++)
				if (hist[a]) std::fprintf(hf, "%04X %lld\n", a, hist[a]);
			std::fclose(hf);
			break;
		}
		if (getenv("NXPROF") && f == frames) {
			// NXPROF=addr,addr,...: the time from frame_done to each of them in turn (next frame)
			runTo(applyHook);
			long long t0 = comp->tickTotal;
			const long long v0 = comp->next->vsyncCount;
			std::string list = getenv("NXPROF");
			size_t at = 0;
			while (at < list.size()) {
				const size_t comma = list.find(',', at);
				const std::string a = list.substr(at, comma == std::string::npos ? std::string::npos : comma - at);
				runTo(uint16_t(std::strtoul(a.c_str(), nullptr, 16)));
				std::printf("  %s: %lld\n", a.c_str(), comp->tickTotal - t0);
				t0 = comp->tickTotal;
				if (comma == std::string::npos) break;
				at = comma + 1;
			}
			const long long v1 = comp->next->vsyncCount;
			std::printf("  (%lld Next frames)\n", v1 - v0);
			const long long t1 = comp->tickTotal;
			while (comp->next->vsyncCount == v1) compExec(comp);
			const long long t2 = comp->tickTotal;
			while (comp->next->vsyncCount == v1 + 1) compExec(comp);
			std::printf("  a Next frame: %lld\n", comp->tickTotal - t2);
			(void)t1;
			break;
		}
		runTo(applyHook);
		applyTick = comp->tickTotal;
		const long long v = comp->next->vsyncCount;
		if (lastApply >= 0 && v - lastApply != 1) lateFrames++;
		if (lastApply >= 0 && v - lastApply > longestFrame) longestFrame = v - lastApply;
		lastApply = v;
	}
	if (errors) {
		std::printf("FAIL: frames differ\n");
		return 1;
	}
	std::printf("%d frames: state, screen and the DLI's lines the same\n", frames);
	std::printf("timing: %d frames late (the longest took %lld Next frames); a frame's work: %lld on average, "
		"%lld at most (frame %d), in the core's ticks\n", lateFrames, longestFrame, worked ? workSum / worked : 0, workMax, workMaxFrame);

	// The last frame went live at the apply just run; the Next frame after this one shows it
	for (int i = 0; i < 2; i++) {
		const int swaps = bufSwaps;
		while (bufSwaps == swaps) compExec(comp);
	}
	int bad = 0, firstBadX = -1, firstBadY = -1;
	const int width = comp->vid->vend.x * 2, height = comp->vid->vend.y;
	auto pixel = [&](int x, int y) { return bufimg + y * bytesPerLine + x * 4; };
	for (int y = 0; y < 256; y++) {
		for (int x = 0; x < 320; x++) {
			uint8_t want[3] = {0, 0, 0};
			const int r = y - kRiverTop;
			if (r >= 0 && r < kRiverLines) rrzx::nextRgb(rrzx::nextColour(rows[size_t(r) * 320 + size_t(x)]), want);
			for (int h = 0; h < 2; h++) {
				const uint8_t *p = pixel(2 * (kL2Left + x) + h, kL2Top + y);
				if (p[0] != want[0] || p[1] != want[1] || p[2] != want[2])
					if (!bad++) { firstBadX = x; firstBadY = y; }
			}
		}
	}
	if (ppm) {
		FILE *f = std::fopen(ppm, "wb");
		if (f) {
			std::fprintf(f, "P6\n%d %d\n255\n", width, height);
			for (int y = 0; y < height; y++)
				for (int x = 0; x < width; x++) std::fwrite(pixel(x, y), 1, 3, f);
			std::fclose(f);
		}
		const std::string refPath = std::string(ppm) + ".ref.ppm";   // and the C++ port's
		f = std::fopen(refPath.c_str(), "wb");
		if (f) {
			std::fprintf(f, "P6\n320 %d\n255\n", kRiverLines);
			for (size_t i = 0; i < rows.size(); i++) {
				uint8_t rgb[3];
				rrzx::nextRgb(rrzx::nextColour(rows[i]), rgb);
				std::fwrite(rgb, 1, 3, f);
			}
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
