// tscheck: runs the TS-Conf viewer (the test build) on Xpeccy+'s TSConf core, with no window,
// and compares it frame by frame with the C++ port (rr::Game::frame, the attract mode, the same
// POKEY counter):
//   - after every frame: the river generator's state (RiverGen::diffWithRam), the game's
//     state (the fields of game_ram.cpp but the scrolling line's), the panel's characters,
//     screen memory, the bank colour's changes by line (the INT's list against Game::scan);
//   - at the end, the picture of the last frame, pixel by pixel: the river and its objects
//     and players as the C++ port's Game::drawRiver draws them,
//     in the TS-Conf's colours, black above and below it;
//   - the machine's picture of every frame against the C++ port's of the frame it shows (the
//     one whose apply came in the machine's frame before it).
//
// usage: tscheck <River_Raid.rom> <build dir> <frames> [frame.ppm] [-seed N]
//        tscheck -sna <river_raid.sna> <frames> <frame.ppm>: the snapshot, run for so many frames
//        tscheck -spg <river_raid.spg> <frames> <frame.ppm> [-sd folder]: the SPG (the folder as
//                the SD card, a FAT32 volume)
//   TSFULL=1: the picture written is the core's whole buffer (blanking too)
#include <algorithm>
#include <filesystem>
#include <functional>
#include <cstdio>
#include <cstdlib>
#include <cstring>
#include <string>
#include <vector>

#include "spectrum.h"
#include "filetypes/filetypes.h"
#include "sdcard.h"
#include "vfat.h"
#include "cpu/Z80/z80.h"

#include "game.h"
#include "pokey_counter.h"
#include "pokey_random.h"
#include "ts_palette.h"

namespace {

// The program's memory (src/river_raid.asm)
constexpr int kAtariPage = 1, kCodePage = 2, kHighPage = 6;
constexpr int kVidPage = 32;
constexpr int kWindowFirst = 20;   // first colour clock shown
constexpr int kRiverLines = 160;
constexpr int kRiverFirstLine = 28;
constexpr int kRiverTop = 24;      // the screen's row of the river's top line (of 240)
constexpr int kRowLine = 55;       // VSINT for screen row r: kRowLine + r

uint16_t symbol(const std::string &dir, const char *name) {
	FILE *f = std::fopen((dir + "/test.sym").c_str(), "r");
	if (!f) return 0;
	char line[256];
	uint16_t at = 0;
	const size_t n = std::strlen(name);
	while (std::fgets(line, sizeof line, f))
		if (!std::strncmp(line, name, n) && line[n] == ':') {
			const char *x = std::strstr(line, "0x");
			if (x) at = uint16_t(std::strtoul(x, nullptr, 16));
			break;
		}
	std::fclose(f);
	return at;
}

uint8_t *at(Computer *comp, uint16_t addr) {
	const MemPage &pg = comp->mem->map[addr >> 8];
	return comp->mem->ramData + ((size_t(pg.num) << 8) & (MEM_4M - 1)) + (addr & 0xFF);
}
uint8_t readZ80(Computer *comp, uint16_t addr) { return *at(comp, addr); }

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

// The game's state (river_raid/port/src/game_ram.cpp)
const struct { const char *name; uint16_t addr; } kGameFields[] = {
	{"frameCount", 0x18}, {"attractFlags", 0x29}, {"attractTimer", 0x2A}, {"planeState", 0x76},
	{"idleTime", 0x78}, {"speed", 0x59}, {"scrollFrac", 0x30}, {"shellFrame", 0x3B}, {"shellX", 0x3C},
	{"shellXFrac", 0x3D}, {"missileStep", 0xC0}, {"planeX", 0x57}, {"planeFrame", 0x5E},
	{"soundExplosion", 0x7C}, {"soundMissile", 0x7F}, {"bridgeFlash", 0x31}, {"fuel", 0x5B},
	{"joystick", 0x19}, {"joystickPrev", 0xB9}, {"startBeep", 0xC6}, {"pauseState", 0x24},
	{"selectDelay", 0x25}, {"gameNumber", 0x09}, {"player", 0x77}, {"fuelFrac", 0x5C},
	{"eventSound", 0x7A}, {"eventSoundTime", 0x7B}, {"soundFire", 0x7D}, {"soundBonus", 0x7E},
	{"crashPitch", 0x052C}, {"hit.bulletHitBank", 0x1A}, {"hit.planeHitBank", 0x1B},
	{"hit.bulletHitObject", 0x1C}, {"hit.planeHitObject", 0x1D}, {"hit.planeHitShell", 0x1E},
	{"hit.shellHitObject", 0x1F}, {"hit.tankAtEdge", 0x20}, {"hit.missileHitPlane", 0x21},
	{"hit.missileHitBank", 0x22}, {"planeXFrac", 0x58}, {"planeAccel", 0x2B}, {"bulletY", 0x56},
	{"bridges0", 0x61}, {"bridges1", 0x62}, {"score0", 0x63}, {"score1", 0x64}, {"score2", 0x65},
	{"lives", 0x6A}, {"other.level", 0x6B}, {"other.bridges0", 0x6C}, {"other.bridges1", 0x6D},
	{"other.score0", 0x6E}, {"other.score1", 0x6F}, {"other.score2", 0x70},
	{"other.checkpoint0", 0x71}, {"other.checkpoint1", 0x72}, {"other.checkpoint2", 0x73},
	{"other.checkpoint3", 0x74}, {"other.lives", 0x75}, {"respawned", 0x79}, {"powerOnDone", 0x28},
	{"screenOn", 0xC7}, {"screenTop.lo", 0x3F04}, {"screenTop.hi", 0x3F05},
	{"scroller.textLo", 0x3FB3}, {"scroller.fineScroll", 0x26}, {"scroller.logoX", 0x27},
};
const struct { const char *name; uint16_t addr; int size; } kGameArrays[] = {
	{"highScore", 0x80, 16}, {"highScoreCheck", 0x90, 16}, {"panel", 0x1000, 60},
};

}  // namespace

int main(int argc, char **argv) {
	if (argc < 4) {
		std::fprintf(stderr, "usage: %s <River_Raid.rom> <build dir> <frames> [frame.ppm] [-seed N]\n", argv[0]);
		return 2;
	}
	if (!std::strcmp(argv[1], "-sna") || !std::strcmp(argv[1], "-spg")) {   // the file run (see usage)
		Computer *comp = compCreate();
		comp->vid->drawAll = 1;
		if (!compSetHardware(comp, "TSConf")) return 1;
		compSetBaseFrq(comp, 3.5);
		memSetSize(comp->mem, MEM_4M, -1);
		compReset(comp, RES_DEFAULT);
		bytesPerLine = comp->vid->full.x * 8;
		bufSize = bytesPerLine * comp->vid->full.y;
		if (argc > 6 && !std::strcmp(argv[5], "-sd")) {   // a host folder as the SD card (FAT32)
			vFat *vf = vfat_create();
			vfat_set_root(vf, argv[6], nullptr);
			vfat_add(vf, -1, "", 0, 0, 1);
			std::function<void(const std::filesystem::path &, int)> scan = [&](const std::filesystem::path &dir, int parent) {
				for (const auto &e : std::filesystem::directory_iterator(dir)) {
					const std::string name = e.path().filename().string();
					if (e.is_directory()) scan(e.path(), vfat_add(vf, parent, name.c_str(), 0, 0, 1));
					else vfat_add(vf, parent, name.c_str(), unsigned(e.file_size()), 0, 0);
				}
			};
			scan(argv[6], 0);
			if (!vfat_build(vf, 0)) { std::fprintf(stderr, "the SD folder: no volume\n"); return 2; }
			sdcSetFolder(comp->sdc, argv[6], vf);
		}
		if (argc > 6 && !std::strcmp(argv[5], "-img")) sdcSetImage(comp->sdc, argv[6]);   // an SD card's image
		const bool spg = !std::strcmp(argv[1], "-spg");
		if ((spg ? loadSPG(comp, argv[2], 0) : loadSNA(comp, argv[2], 0)) != 0) { std::fprintf(stderr, "cannot load %s\n", argv[2]); return 2; }
		for (int i = std::atoi(argv[3]); i > 0; i--) {
			const int swaps = bufSwaps;
			while (bufSwaps == swaps) compExec(comp);
		}
		FILE *o = std::fopen(argv[4], "wb");
		if (!o) return 2;
		std::fprintf(o, "P6\n320 240\n255\n");
		for (int y = 0; y < 240; y++)
			for (int x = 0; x < 320; x++)
				std::fwrite(bufimg + (comp->vid->tsconf.yPos + y) * bytesPerLine + (comp->vid->tsconf.xPos * 2 + 2 * x) * 4, 1, 3, o);
		std::fclose(o);
		std::printf("PC %04X, border %02X\n", comp->cpu->regPC, comp->vid->brdcol);
		return 0;
	}
	uint32_t seed = 12345;
	int startAt = -1;   // -start N: START pressed in frame N (a game: the plane flies straight on)
	const char *ppm = nullptr;
	for (int i = 4; i < argc; i++) {
		if (!std::strcmp(argv[i], "-seed") && i + 1 < argc) seed = uint32_t(std::strtoul(argv[++i], nullptr, 0));
		else if (!std::strcmp(argv[i], "-start") && i + 1 < argc) startAt = std::atoi(argv[++i]);
		else ppm = argv[i];
	}
	const std::string dir = argv[2];
	std::vector<uint8_t> romData, code, high;
	rr::Rom rom;
	if (!rom.load(argv[1]) || !readFile(argv[1], romData) || romData.size() < 0x2000) { std::fprintf(stderr, "cannot read %s\n", argv[1]); return 2; }
	if (!readFile(dir + "/ts_page2.bin", code) || code.size() != 0x4000 || !readFile(dir + "/ts_page6.bin", high) || high.size() != 0x4000) {
		std::fprintf(stderr, "cannot read %s/ts_page2.bin, ts_page6.bin\n", dir.c_str());
		return 2;
	}
	const int frames = std::atoi(argv[3]);
	const uint16_t frameHook = uint16_t(code[5] | code[6] << 8), applyHook = uint16_t(code[7] | code[8] << 8);
	const uint32_t first = rrzx::pokeyFirstRead(seed, true);   // POKEY's counter at the first read
	code[9] = uint8_t(first);
	code[10] = uint8_t(first >> 8);
	code[11] = uint8_t(first >> 16);
	std::memcpy(code.data() + 0x2000, romData.data(), 0x2000);   // the cartridge at $A000

	Computer *comp = compCreate();
	comp->vid->drawAll = 1;
	if (!compSetHardware(comp, "TSConf")) { std::fprintf(stderr, "no TSConf core\n"); return 1; }
	compSetBaseFrq(comp, 3.5);
	memSetSize(comp->mem, MEM_4M, -1);   // the board's 4 MB (the core starts with 128K)
	compReset(comp, RES_DEFAULT);
	bytesPerLine = comp->vid->full.x * 8;
	bufSize = bytesPerLine * comp->vid->full.y;
	uint8_t *ram = comp->mem->ramData;
	std::memset(ram, 0, MEM_4M);
	std::memcpy(ram + kCodePage * 0x4000, code.data(), 0x4000);
	std::memcpy(ram + kHighPage * 0x4000, high.data(), 0x4000);
	memSetBank(comp->mem, 0x80, MEM_RAM, kCodePage, MEM_16K, NULL, NULL, NULL);
	memSetBank(comp->mem, 0xC0, MEM_RAM, kHighPage, MEM_16K, NULL, NULL, NULL);
	comp->cpu->regPC = 0x8000;

	rr::Game game(rom);
	rr::PokeyRandom random(seed, rr::tvSystem(true));
	game.startAttract(true);
	random.nextFrame();
	std::vector<uint8_t> rows(size_t(kRiverLines) * 320);   // the last frame's river (Atari colours)
	static uint8_t picture[rr::kScreenHeight][rr::kScreenWidth];
	auto takePicture = [&] {   // as the C++ port's game shows the frame: the river and its sprites
		std::memset(picture, 0, sizeof picture);
		game.drawRiver(picture);
		for (int k = 0; k < kRiverLines; k++)
			std::memcpy(&rows[size_t(k) * 320], &picture[rr::kRiverTop + k][2 * kWindowFirst], 320);
	};
	game.afterDisplay = takePicture;   // the river as the display sees it (before the new lines)
	auto runTo = [&](uint16_t hook) {
		for (long n = 0; n < 50000000L; n++) {
			compExec(comp);
			if (comp->cpu->regPC == hook) return true;
		}
		return false;
	};
	const uint16_t evShow = symbol(dir, "ev_built");
	std::vector<std::vector<uint8_t>> history;   // the C++ port's river of the frames before
	std::vector<int> applySwaps;   // per frame: the machine's frames done at its apply
	long picBad = 0, picCompared = 0;
	int picFirstBad = 0;
	auto shownBad = [&](const std::vector<uint8_t> &want) {   // the machine's last frame against it
		const int x0 = comp->vid->tsconf.xPos * 2, y0 = comp->vid->tsconf.yPos;
		for (int y = 0; y < 240; y++)
			for (int x = 0; x < 320; x++) {
				uint8_t rgb[3] = {0, 0, 0};
				const int r = y - kRiverTop;
				if (r >= 0 && r < kRiverLines) rrts::cramRgb(rrts::cramWord(want[size_t(r) * 320 + size_t(x)]), rgb);
				const uint8_t *p = bufimg + (y0 + y) * bytesPerLine + (x0 + 2 * x) * 4;
				if (std::memcmp(p, rgb, 3)) return y * 1000 + x + 1;
			}
		return 0;
	};
	static uint8_t ref[0x4000], mine[0x4000];
	int errors = 0;
	long evBad = 0;
	const int swaps0 = bufSwaps;
	const long long tick0 = comp->tickTotal;
	long long workSum = 0, workMax = 0, applyTick = -1;
	int workMaxFrame = 0;
	for (int f = 1; f <= frames; f++) {
		ram[kCodePage * 0x4000 + 15] = f == startAt ? 1 : 0;   // in_console: START
		if (!runTo(frameHook)) { std::printf("frame %d: the program never got to frame_done (PC %04X)\n", f, comp->cpu->regPC); return 1; }
		if (applyTick >= 0) {   // the frame's work, from the apply before it
			const long long w = comp->tickTotal - applyTick;
			workSum += w;
			if (w > workMax) { workMax = w; workMaxFrame = f; }
		}
		// the machine's last whole frame (bufSwaps of them) shows the apply of the frame whose
		// apply came 2 frames before its end: the one with applySwaps = bufSwaps - 2
		int shown = -1;
		for (size_t i = 0; i < applySwaps.size(); i++)
			if (applySwaps[i] == bufSwaps - 2) shown = int(i);
		if (shown >= 0 && size_t(shown) < history.size() && !history[size_t(shown)].empty()) {
			picCompared++;
			const int at = shownBad(history[size_t(shown)]);
			if (at && !picBad++) picFirstBad = f;
			if (at && std::getenv("TSDIFF") && std::atoi(std::getenv("TSDIFF")) == f) {   // both pictures
				FILE *o = std::fopen("/tmp/tsdiff.ppm", "wb");
				std::fprintf(o, "P6\n640 240\n255\n");
				const std::vector<uint8_t> &want = history[size_t(shown)];
				for (int y = 0; y < 240; y++) {
					for (int x = 0; x < 320; x++)
						std::fwrite(bufimg + (comp->vid->tsconf.yPos + y) * bytesPerLine + (comp->vid->tsconf.xPos * 2 + 2 * x) * 4, 1, 3, o);
					for (int x = 0; x < 320; x++) {
						uint8_t rgb[3] = {0, 0, 0};
						const int r = y - kRiverTop;
						if (r >= 0 && r < kRiverLines) rrts::cramRgb(rrts::cramWord(want[size_t(r) * 320 + size_t(x)]), rgb);
						std::fwrite(rgb, 1, 3, o);
					}
				}
				std::fclose(o);
			}
			if (at && picBad <= 3) std::printf("frame %d: the picture of frame %d differs from (%d, %d) on\n", f, shown + 1, (at - 1) % 1000, (at - 1) / 1000);
		}
		rr::Input input;
		input.start = f == startAt;
		{   // TSSHOT=k: the machine's frames from frame k on, to /tmp/tsshot_N.ppm (8 of them)
			static const int shotFrom = std::getenv("TSSHOT") ? std::atoi(std::getenv("TSSHOT")) : -1;
			if (shotFrom > 0 && f >= shotFrom && f < shotFrom + 8) {
				char fn[64];
				std::snprintf(fn, sizeof fn, "/tmp/tsshot_%d.ppm", f - shotFrom);
				FILE *o = std::fopen(fn, "wb");
				std::fprintf(o, "P6\n320 240\n255\n");
				for (int y = 0; y < 240; y++)
					for (int x = 0; x < 320; x++)
						std::fwrite(bufimg + (comp->vid->tsconf.yPos + y) * bytesPerLine + (comp->vid->tsconf.xPos * 2 + 2 * x) * 4, 1, 3, o);
				std::fclose(o);
			}
		}
		if (getenv("TSBUSY") && game.busy()) std::printf("frame %d: busy\n", f);
		int reads = 0;
		game.frame(input, [&] { return reads++ ? random.read(249, 13) : random.read(191, 24); });
		random.nextFrame();
		history.push_back(rows);   // (by frame, from frame 1)
		if (history.size() > 6) history[history.size() - 7].clear();
		for (int a = 0; a < 0x4000; a++) mine[a] = readZ80(comp, uint16_t(a));
		std::memset(ref, 0, sizeof ref);
		game.saveToRam(ref);
		std::vector<std::string> diffs = game.gen.diffWithRam(mine, true);
		char b[120];
		for (const auto &fd : kGameFields)
			if (mine[fd.addr] != ref[fd.addr]) {
				std::snprintf(b, sizeof b, "%s $%02X: z80=%02X c++=%02X", fd.name, fd.addr, mine[fd.addr], ref[fd.addr]);
				diffs.push_back(b);
			}
		for (const auto &ar : kGameArrays)
			for (int i = 0; i < ar.size; i++)
				if (mine[ar.addr + i] != ref[ar.addr + i]) {
					std::snprintf(b, sizeof b, "%s[%d] $%04X: z80=%02X c++=%02X", ar.name, i, ar.addr + i, mine[ar.addr + i], ref[ar.addr + i]);
					diffs.push_back(b);
				}
		uint16_t addr = uint16_t(mine[0x3F04] | (mine[0x3F05] << 8));
		for (size_t k = 0; k < game.screen.size() && k < size_t(kRiverLines); k++) {
			if (std::memcmp(mine + addr, game.screen[k].data(), rr::kLineBytes)) {
				std::snprintf(b, sizeof b, "screen line %zu (at $%04X)", k, addr);
				diffs.push_back(b);
				break;
			}
			addr = uint16_t(addr + rr::kLineBytes);
			if ((addr >> 8) == 0x2F) addr = 0x3000;
			if ((addr >> 8) == 0x3F) addr = 0x2000;
		}
		{   // the bank's colour by line, as the INTs will set it: the top's, then the changes
			const uint16_t list = uint16_t(readZ80(comp, evShow) | readZ80(comp, uint16_t(evShow + 1)) << 8);
			uint16_t p = list;
			uint16_t w = uint16_t(readZ80(comp, p) | readZ80(comp, uint16_t(p + 1)) << 8);
			p = uint16_t(p + 2);
			int next = readZ80(comp, p);
			for (int k = 0; k < kRiverLines; k++) {
				while (next && next - kRowLine <= kRiverTop + k) {
					w = uint16_t(readZ80(comp, uint16_t(p + 1)) | readZ80(comp, uint16_t(p + 2)) << 8);
					p = uint16_t(p + 3);
					next = readZ80(comp, p);
				}
				const uint8_t want = game.scan[size_t(kRiverFirstLine + k)].bankColour;
				if (w != rrts::cramWord(want)) {
					evBad++;
					std::snprintf(b, sizeof b, "bank colour, river line %d: CRAM %04X, c++ colour %02X (%04X)", k, w, want, rrts::cramWord(want));
					diffs.push_back(b);
					break;
				}
			}
		}
		if (!diffs.empty()) {
			std::printf("frame %d (level %d): %zu differences\n", f, game.gen.s.level, diffs.size());
			for (size_t i = 0; i < diffs.size() && i < 24; i++) std::printf("  %s\n", diffs[i].c_str());
			if (++errors >= 2) return 1;
			game.loadFromRam(mine);   // go on from the Z80's state
		}
		if (!runTo(applyHook)) { std::printf("frame %d: the program never got to apply_done\n", f); return 1; }
		applyTick = comp->tickTotal;
		applySwaps.push_back(bufSwaps);
	}
	std::printf("%d frames took %d of the machine's (%s)\n", frames, bufSwaps - swaps0, bufSwaps - swaps0 > frames + 16 ? "late" : "in time; the start takes a few");
	std::printf("a frame's work: %lld ticks on average, %lld at most (frame %d), of %lld a frame\n",
		frames > 1 ? workSum / (frames - 1) : 0, workMax, workMaxFrame, (comp->tickTotal - tick0) / std::max(1, bufSwaps - swaps0));
	std::printf("%d frames compared: %s\n", frames, errors ? "with differences" : "the same");

	// The last frame went live at the apply just run; the frame after shows it. The program
	// stops there (JR $ at apply_done).
	ram[kCodePage * 0x4000 + (applyHook - 0x8000)] = 0x18;
	ram[kCodePage * 0x4000 + (applyHook - 0x8000) + 1] = 0xFE;
	for (int i = 0; i < 2; i++) {
		const int swaps = bufSwaps;
		while (bufSwaps == swaps) compExec(comp);
	}
	if (std::getenv("TSDEBUG")) {   // which picture line the screen's rows show
		const int yo = comp->vid->tsconf.yOffset;
		for (int y = 22; y < 28; y++) {
			std::printf("row %d:", y);
			for (int d = -2; d <= 2; d++) {
				const int line = (y + yo + d) & 511;
				const uint8_t *v = ram + kVidPage * 0x4000 + line * 512;
				int same = 0;
				for (int x = 0; x < 320; x++) {
					const uint8_t *p = bufimg + (comp->vid->tsconf.yPos + y) * bytesPerLine + (comp->vid->tsconf.xPos * 2 + 2 * x) * 4;
					uint8_t rgb[3];
					const uint16_t w = uint16_t(comp->vid->tsconf.cram[2 * v[x]] | comp->vid->tsconf.cram[2 * v[x] + 1] << 8);
					rrts::cramRgb(w, rgb);
					same += !std::memcmp(p, rgb, 3);
				}
				std::printf(" %+d:%d", d, same);
			}
			std::printf("  (GYOFFS %d)\n", yo);
		}
	}
	const bool full = std::getenv("TSFULL") != nullptr;
	const int x0 = comp->vid->tsconf.xPos * 2, y0 = comp->vid->tsconf.yPos;
	auto pixel = [&](int x, int y) { return bufimg + (y0 + y) * bytesPerLine + (x0 + 2 * x) * 4; };
	int bad = 0, firstBadX = -1, firstBadY = -1;
	for (int y = 0; y < 240; y++)
		for (int x = 0; x < 320; x++) {
			uint8_t want[3] = {0, 0, 0};
			const int r = y - kRiverTop;
			if (r >= 0 && r < kRiverLines) rrts::cramRgb(rrts::cramWord(rows[size_t(r) * 320 + size_t(x)]), want);
			for (int h = 0; h < 2; h++) {
				const uint8_t *p = pixel(x, y) + 4 * h;
				if (p[0] != want[0] || p[1] != want[1] || p[2] != want[2])
					if (!bad++) { firstBadX = x; firstBadY = y; }
			}
		}
	if (ppm) {
		FILE *o = std::fopen(ppm, "wb");
		if (o) {
			const int width = full ? comp->vid->full.x * 2 : 320, height = full ? comp->vid->full.y : 240;
			std::fprintf(o, "P6\n%d %d\n255\n", width, height);
			for (int y = 0; y < height; y++)
				for (int x = 0; x < width; x++)
					std::fwrite(full ? bufimg + y * bytesPerLine + x * 4 : pixel(x, y), 1, 3, o);
			std::fclose(o);
		}
		const std::string refPath = std::string(ppm) + ".ref.ppm";   // and the C++ port's
		o = std::fopen(refPath.c_str(), "wb");
		if (o) {
			std::fprintf(o, "P6\n320 240\n255\n");
			for (int y = 0; y < 240; y++)
				for (int x = 0; x < 320; x++) {
					uint8_t rgb[3] = {0, 0, 0};
					const int r = y - kRiverTop;
					if (r >= 0 && r < kRiverLines) rrts::cramRgb(rrts::cramWord(rows[size_t(r) * 320 + size_t(x)]), rgb);
					std::fwrite(rgb, 1, 3, o);
				}
			std::fclose(o);
		}
	}
	std::printf("pictures: %ld frames compared, %ld differ\n", picCompared, picBad);
	if (evBad) std::printf("the bank colour's list differed in %ld frames\n", evBad);
	if (bad) {
		std::printf("FAIL: the picture differs in %d pixels, the first at (%d, %d)\n", bad, firstBadX, firstBadY);
		return 1;
	}
	std::printf("picture: the same, pixel for pixel\n");
	return errors ? 1 : 0;
}
