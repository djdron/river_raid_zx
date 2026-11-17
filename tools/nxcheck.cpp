// Runs the test build on Xpeccy+'s ZX Spectrum Next core, with no window, and compares it
// frame by frame with the C++ port (rr::Game::frame, with the same POKEY counter and the same
// controls). The controls come from a player made up here (Bot): it waits in the attract
// mode, sometimes selects another game, presses START, flies along the river, fires, pauses
// now and then; it crashes often enough to lose its planes and start again.
//   - after every frame: the river generator's state (RiverGen::diffWithRam), the game's
//     state (the fields of game_ram.cpp but the scrolling line's), the high scores and the
//     panel's characters, player-missile memory, screen memory, and what the DLI left per
//     river line (player 3 and the bank colour, Game::scan);
//   - at the end, the picture of the last frame, pixel by pixel: Game::drawRiver in the
//     Next's colours, black around the river.
// It also reports whether every frame was ready in time on the Next.
//
// usage: nxcheck <River_Raid.rom> <build dir> <frames> [frame.ppm] [-seed N] [-bot N] [-attract] [-pal | -ntsc]
//   -pal (the default) or -ntsc: the standard, the Next at 50 or 60 Hz
//   -seed: POKEY's counter at power-on; -bot: the made-up player's choices; -attract: no
//   player, the attract mode only
#include <array>
#include <new>
#include <cmath>
#include <cstdio>
#include <cstdlib>
#include <cstring>
#include <deque>
#include <map>
#include <string>
#include <vector>

#include "spectrum.h"
#include "cpu/Z80/z80.h"

#include "game.h"
#include "os_font.h"
#include "status_bar.h"
#include "next_palette.h"
#include "pokey_counter.h"
#include "pokey_random.h"
#include "pokey_sound.h"

namespace {

// The program's memory (src/river_raid.asm)
constexpr int kAtariRamPage = 30;
constexpr int kCodePages[3] = {4, 6, 7};
constexpr int kRomPage = 5;
constexpr uint16_t kScan = 0x6000; // scan_p3, scan_x, scan_size, scan_col, scan_bank: 256 each, by scanline
constexpr int kWindowFirst = 20;   // first colour clock shown
constexpr int kRiverLines = 160;
constexpr int kPictureLines = 216;   // Layer 2 rows 40-255 (NTSC: the panel ends at 239)
constexpr int kSpritesMax = 60;     // SPRITES_MAX (sprites.asm)   // the river, the panel, the scrolling line
constexpr int kRiverFirstLine = 28;
constexpr int kRiverTop = 40;      // Layer 2 row of the river's top line
// Where Layer 2 (320x256) is in the core's picture (360 dots x 303 lines, 2 columns a dot)
constexpr int kL2Left = 8;
constexpr int kL2Top = 24;     // (at 50 Hz; at 60 Hz the picture starts with Layer 2 row 0)

int sramOffset(int page) { return 0x40000 + page * 0x2000; }

// An address from the test build's symbols (build/test.sym, sjasmplus "name: EQU 0x...")
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

void writeZ80(Computer *comp, uint16_t addr, uint8_t v) {
	const int page = comp->next->mmu[addr >> 13];
	comp->mem->ramData[sramOffset(page) + (addr & 0x1FFF)] = v;
}

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

// A made-up player. In the attract mode (or after a game) it waits a while, sometimes selects
// another game, then presses START. Flying, it steers towards the middle of the water some
// lines ahead of the plane, with spells of random steering and speed; it fires half the time;
// now and then it pauses the game for a while.
class Bot {
public:
	explicit Bot(uint32_t seed) : s_(seed ? seed : 1) {}
	rr::Input next(const rr::Game &game) {
		rr::Input in;
		const rr::GameState &g = game.g;
		if (pause_ > 0) {                 // key down, up for a while, down, up
			pause_--;
			in.key = pause_ == 60 || pause_ == 1;
			return in;
		}
		if (g.planeState == 0xFF || game.busy()) {
			// NXGAME=n: game n (7: from bridge 50), selected and started at once
			if (const char *want = getenv("NXGAME")) {
				if (game.busy()) return in;
				if ((g.gameNumber & 7) + 1 != std::atoi(want)) { in.select = true; return in; }
				in.start = true;
				return in;
			}
			// no plane: wait, maybe select another game, start
			if (wait_ < 0) wait_ = 30 + int(rnd() % 400);
			if (wait_ > 0) {
				wait_--;
				if (selecting_ > 0) {
					selecting_--;
					in.select = true;
				} else if (wait_ == 20 && rnd() % 3 == 0) {
					selecting_ = 1 + int(rnd() % 80);
				}
				return in;
			}
			wait_ = -1;
			in.start = true;
			return in;
		}
		wait_ = -1;
		if (rnd() % 4000 == 0) {
			pause_ = 62 + int(rnd() % 100);
			in.key = true;
			return in;
		}
		uint8_t stick = 0x0F;
		if (randomFor_ > 0) {             // random steering for a while
			randomFor_--;
			stick = randomStick_;
		} else {
			if (rnd() % 400 == 0) {
				randomFor_ = 5 + int(rnd() % 40);
				randomStick_ = uint8_t(0x0F & ~(1u << (rnd() % 4)) & ~((rnd() % 3 == 0) ? 1u << (rnd() % 4) : 0));
			}
			const int at = g.planeX - 28;     // the plane's middle in the line's pixels
			const int ahead = 100 + int(rnd() % 40);
			if (size_t(ahead) < game.screen.size()) {
				const auto &line = game.screen[size_t(ahead)];
				auto water = [&](int p) {
					return p >= 0 && p < rr::kLineBytes * 4 && ((line[size_t(p >> 2)] >> (6 - 2 * (p & 3))) & 3) == 3;
				};
				// the run of water nearest to the plane
				int best = -1, bestDist = 1 << 30;
				for (int p = 0; p < rr::kLineBytes * 4;) {
					if (!water(p)) { p++; continue; }
					int e = p;
					while (water(e)) e++;
					const int mid = (p + e) / 2;
					const int d = std::abs(mid - at) - (e - p) / 4;
					if (d < bestDist) { bestDist = d; best = mid; }
					p = e;
				}
				if (best >= 0) {
					if (best < at - 2) stick &= ~0x04;
					else if (best > at + 2) stick &= ~0x08;
				}
			}
			// an enemy straight ahead: out of its way
			for (const rr::Slot &o : game.gen.s.slot)
				if (o.kind >= rr::object::kJet && o.kind < rr::object::kBridge && o.y >= 0x80 && o.y < 0xF0) {
					const int w = o.size == 1 ? 16 : 8, plane = g.planeX + 4;
					if (plane > o.x - 6 && plane < o.x + w + 6) {
						stick = uint8_t((stick | 0x0C) & ~(plane < o.x + w / 2 ? 0x04 : 0x08));
						break;
					}
				}
			// low on fuel: towards a depot ahead (and not shooting it)
			depot_ = false;
			if (g.fuel < 0xA0) {
				for (const rr::Slot &o : game.gen.s.slot)
					if (o.kind == rr::object::kFuel && o.y >= 0x98 && o.y < 0xF0) {
						const int to = o.x + 4, plane = g.planeX + 4;
						stick = 0x0F;
						if (to < plane - 1) stick &= ~0x04;
						else if (to > plane + 1) stick &= ~0x08;
						depot_ = true;
						break;
					}
			}
			if (speedFor_ > 0) speedFor_--;
			else {
				speedFor_ = 20 + int(rnd() % 120);
				speed_ = uint8_t(rnd() % 3);
			}
			if (speed_ == 1) stick &= ~0x01;
			else if (speed_ == 2) stick &= ~0x02;
		}
		in.stick[0] = in.stick[1] = stick;
		const bool fire = !depot_ && rnd() % 4 != 0;
		in.trigger[0] = in.trigger[1] = fire;
		return in;
	}

private:
	uint32_t s_;
	int wait_ = -1, selecting_ = 0, pause_ = 0, randomFor_ = 0, speedFor_ = 0;
	uint8_t randomStick_ = 0x0F, speed_ = 0;
	bool depot_ = false;
	uint32_t rnd() {
		s_ ^= s_ << 13;
		s_ ^= s_ >> 17;
		s_ ^= s_ << 5;
		return s_;
	}
};

// The controls as play.asm keeps them (in_stick, in_trig, in_console, in_key)
uint8_t *inputInHeader(uint8_t *hdr) { return hdr + 12; }

void putInput(uint8_t *at, const rr::Input &in) {
	at[0] = in.stick[0];
	at[1] = in.stick[1];
	at[2] = uint8_t((in.trigger[0] ? 1 : 0) | (in.trigger[1] ? 2 : 0));
	at[3] = uint8_t((in.start ? 1 : 0) | (in.select ? 2 : 0) | (in.option ? 4 : 0));
	at[4] = in.key ? 1 : 0;
}

}  // namespace

int main(int argc, char **argv) {
	if (argc < 4) {
		std::fprintf(stderr, "usage: %s <River_Raid.rom> <build dir> <frames> [frame.ppm] [-seed N] [-bot N] [-attract]\n", argv[0]);
		return 2;
	}
	uint32_t seed = 12345, botSeed = 1;
	bool attractOnly = false, pal = true;
	int switchAt = -1;
	const char *oracleDir = nullptr;   // -oracle DIR: against the original (rr_oracle's output)
	long ramBase = 0;   // -switch N: CAPS + 1 before frame N, the other standard from the start
	const char *ppm = nullptr;
	const char *wavPath = nullptr, *wavCppPath = nullptr;   // -wav, -wavcpp: the sound (see below)
	for (int i = 4; i < argc; i++) {
		if (!std::strcmp(argv[i], "-seed") && i + 1 < argc) seed = uint32_t(std::strtoul(argv[++i], nullptr, 0));
		else if (!std::strcmp(argv[i], "-bot") && i + 1 < argc) botSeed = uint32_t(std::strtoul(argv[++i], nullptr, 0));
		else if (!std::strcmp(argv[i], "-attract")) attractOnly = true;
		else if (!std::strcmp(argv[i], "-ntsc")) pal = false;
		else if (!std::strcmp(argv[i], "-pal")) pal = true;
		else if (!std::strcmp(argv[i], "-switch") && i + 1 < argc) switchAt = std::atoi(argv[++i]);
		else if (!std::strcmp(argv[i], "-oracle") && i + 1 < argc) oracleDir = argv[++i];
		else if (!std::strcmp(argv[i], "-ram-base") && i + 1 < argc) ramBase = std::atol(argv[++i]);
		else if (!std::strcmp(argv[i], "-wav") && i + 1 < argc) wavPath = argv[++i];
		else if (!std::strcmp(argv[i], "-wavcpp") && i + 1 < argc) wavCppPath = argv[++i];
		else ppm = argv[i];
	}
	std::vector<uint8_t> romData, code[3];
	rr::Rom rom;
	if (!rom.load(argv[1]) || !readFile(argv[1], romData)) { std::fprintf(stderr, "cannot read %s\n", argv[1]); return 2; }
	for (int i = 0; i < 3; i++) {
		const std::string path = std::string(argv[2]) + "/test_page" + std::to_string(kCodePages[i]) + ".bin";
		if (!readFile(path, code[i]) || code[i].size() != 0x2000) { std::fprintf(stderr, "cannot read %s\n", path.c_str()); return 2; }
	}
	std::vector<uint8_t> poly;   // POKEY's 17-bit counter for the sound, pages 14-15
	if (!readFile(std::string(argv[2]) + "/test_poly.bin", poly) || poly.size() != 0x4000) { std::fprintf(stderr, "cannot read test_poly.bin\n"); return 2; }
	const int frames = std::atoi(argv[3]);
	const uint16_t sbCount = symbol(argv[2], "sb_count");
	const uint16_t tvToggle = symbol(argv[2], "tv_toggle"), rndState = symbol(argv[2], "rnd_state");
	auto word = [&](int at) { return uint16_t(code[0][size_t(at)] | (code[0][size_t(at + 1)] << 8)); };
	const uint16_t frameHook = word(5), applyHook = word(7);
	const uint32_t first = rrzx::pokeyFirstRead(seed, pal);   // POKEY's counter at the first read
	code[0][17] = pal ? 1 : 0;                                  // tv_init
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
	for (int i = 0; i < 3; i++) std::memcpy(sram + sramOffset(kCodePages[i]), code[i].data(), 0x2000);
	std::memcpy(sram + sramOffset(kRomPage), romData.data(), 0x2000);
	std::memcpy(sram + sramOffset(14), poly.data(), 0x4000);

	// The C++ port, from the attract mode's start
	rr::Game game(rom);
	rr::PokeyRandom random(seed, rr::tvSystem(pal));
	game.startAttract(pal);
	random.nextFrame();
	static uint8_t picture[rr::kScreenHeight][rr::kScreenWidth];
	std::vector<uint8_t> rows(size_t(kPictureLines) * 320);   // the last frame's river and panel
	uint8_t osFont[rr::kOsFontBytes];
	rr::builtinOsFont(osFont);
	const rr::Charsets charsets = rr::buildCharsets(rom, osFont);
	auto afterDisplay = [&] {
		std::memset(picture, 0, sizeof picture);
		game.drawRiver(picture);
	};
	game.afterDisplay = afterDisplay;
	auto takePicture = [&] {   // as the C++ port's game shows the frame
		const rr::GameState &g = game.g;
		rr::drawStatusBar(rom, charsets, g.panel, g.fuel, g.scroller, g.logoShown, picture, pal);
		for (int k = 0; k < kPictureLines; k++)
			std::memcpy(&rows[size_t(k) * 320], &picture[rr::kRiverTop + k][2 * kWindowFirst], 320);
	};
	Bot bot(botSeed);
	rr::Input input = attractOnly ? rr::Input() : bot.next(game);
	uint8_t *inputAt = sram + sramOffset(kCodePages[0]) + 12;
	putInput(inputAt, input);
	int gameNumbers = 0, maxSprites = 0;
	long games = 0, crashes = 0, gameOvers = 0, pausedFrames = 0, busyFrames = 0, maxBridge = 0;
	uint8_t lastState = 0xFF;

	// NXHISTALL=file: the time spent at each instruction in all frames' work (with -bot, the
	// frames of a game); tools/prof.py sums it per routine
	static long long histAll[0x10000];
	const char *histAllPath = getenv("NXHISTALL");
	auto runTo = [&](uint16_t hook) {
		if (histAllPath && hook == frameHook) {
			long long t = comp->tickTotal;
			for (;;) {
				const uint16_t pc = comp->cpu->regPC;
				compExec(comp);
				histAll[pc] += comp->tickTotal - t;
				t = comp->tickTotal;
				if (comp->cpu->regPC == hook) return;
			}
		}
		for (;;) {
			compExec(comp);
			if (comp->cpu->regPC == hook) return;
		}
	};
	static uint8_t ram[0x4000], ref[0x4000];
	if (oracleDir) {
		// Against the original: rr_oracle's run (ram.bin, random.log, frames.csv in DIR), from
		// the attract mode's start (frame 38, 25 on PAL) as game_check -attract does. The
		// program gets the original's input and the value its game logic read from RANDOM
		// (A205; the VBI's reads are the sound's); after every frame its RAM is compared with
		// the original's as the C++ port's Game reads it (Game::diffWithRam).
		const std::string dir = oracleDir;
		FILE *ramf = std::fopen((dir + "/ram.bin").c_str(), "rb");
		FILE *rndf = std::fopen((dir + "/random.log").c_str(), "r");
		FILE *csv = std::fopen((dir + "/frames.csv").c_str(), "r");
		if (!ramf || !rndf || !csv) { std::fprintf(stderr, "cannot read %s/{ram.bin,random.log,frames.csv}\n", oracleDir); return 2; }
		std::map<long, std::deque<uint8_t>> logicReads;
		std::map<long, int> readCount;
		char lb[512];
		while (std::fgets(lb, sizeof lb, rndf)) {
			long fr; int sc, xp; unsigned v;
			if (lb[0] != '#' && std::sscanf(lb, "%ld %d %d %x", &fr, &sc, &xp, &v) == 4 && sc < 240) {
				logicReads[fr].push_back(uint8_t(v));
				readCount[fr]++;
			}
		}
		std::map<long, rr::Input> inputs;
		std::map<long, unsigned> pcs;
		if (!std::fgets(lb, sizeof lb, csv)) lb[0] = 0;
		while (std::fgets(lb, sizeof lb, csv)) {
			long fr; int joy, fire, start;
			if (std::sscanf(lb, "%ld,%d,%d,%d", &fr, &joy, &fire, &start) != 4) continue;
			rr::Input in;
			in.stick[0] = uint8_t(~joy & 0x0F);
			in.trigger[0] = fire != 0;
			in.start = start != 0;
			int col = 0, extra[5] = {}, n = 0;
			for (char *c = lb; *c; c++)
				if (*c == ',' && ++col >= 22 && n < 5) extra[n++] = std::atoi(c + 1);
			in.select = extra[0] != 0;
			in.option = extra[1] != 0;
			in.stick[1] = uint8_t(~extra[2] & 0x0F);
			in.trigger[1] = extra[3] != 0;
			in.key = extra[4] != 0;
			inputs[fr] = in;
			unsigned pc = 0;
			if (std::sscanf(lb, "%*d,%*d,%*d,%*d,%x", &pc) == 1) pcs[fr] = pc;
		}
		const long first = pal ? 25 : 38;
		uint8_t *hdr = sram + sramOffset(kCodePages[0]);
		hdr[18] = 1;   // rnd_feed_on
		std::vector<uint8_t> orig(0x4000);
		const uint16_t busyAt = symbol(argv[2], "busy");
		long compared = 0, bad = 0, busyFrames = 0, mid = 0, readsBad = 0, shown = 0;
		std::map<std::string, long> diffCount;
		for (long f = first + 1; f <= first + frames; f++) {
			putInput(inputInHeader(hdr), inputs.count(f) ? inputs[f] : rr::Input());
			hdr[19] = logicReads[f].empty() ? 0 : logicReads[f].front();
			hdr[20] = 0;
			runTo(frameHook);
			if (hdr[20] != (readCount.count(f) ? readCount[f] : 0)) {
				readsBad++;
				if (shown < 10) { shown++; std::printf("frame %ld: RANDOM read %d times, the original %d\n", f, hdr[20], readCount[f]); }
			}
			std::fseek(ramf, (f - ramBase) * 0x4000L, SEEK_SET);
			if (std::fread(orig.data(), 1, 0x4000, ramf) != 0x4000) { std::printf("the trace ends at frame %ld\n", f); break; }
			if (readZ80(comp, busyAt)) busyFrames++;
			else {
				for (int a = 0; a < 0x4000; a++) ram[a] = readZ80(comp, uint16_t(a));
				// the program keeps no display list (only the top line's address, $3F04): the
				// river's 160 lines as the original's lists them, a screen address at the top
				// and where screen memory goes on in the other block
				{
					uint16_t addr = uint16_t(ram[0x3F04] | (ram[0x3F05] << 8));
					int pc = 0x3F03;
					for (int k = 0; k < 160; k++) {
						const bool lms = k == 0 || (addr & 0x0FFF) == 0;
						ram[pc++] = lms ? 0x4E : 0x0E;
						if (lms) {
							ram[pc++] = uint8_t(addr);
							ram[pc++] = uint8_t(addr >> 8);
						}
						addr = uint16_t(addr + 48);
						if ((addr >> 8) == 0x2F) addr = uint16_t(addr + 0x0100);
						else if ((addr >> 8) == 0x3F) addr = uint16_t(addr - 0x1F00);
					}
					ram[pc] = 0x41;   // (the end)
				}
				game.loadFromRam(ram);
				const std::vector<std::string> diffs = game.diffWithRam(orig.data());
				const bool waiting = !pcs.count(f) || pcs[f] == 0xAE99 || pcs[f] == 0xAE9C || pcs[f] == 0xAE9E;
				if (!diffs.empty() && !waiting) mid++;
				else {
					compared++;
					if (!diffs.empty()) {
						bad++;
						for (auto &d : diffs) diffCount[d.substr(0, d.find(':'))]++;
						if (shown < 10) {
							shown++;
							std::printf("frame %ld:", f);
							for (size_t i = 0; i < diffs.size() && i < 10; i++) std::printf("  %s", diffs[i].c_str());
							std::printf("%s\n", diffs.size() > 10 ? "  ..." : "");
						}
						// on from the original's state (as game_check does from RAM): its RAM into
						// the program's
						for (int a = 0; a < 0x4000; a++) writeZ80(comp, uint16_t(a), orig[size_t(a)]);
					}
				}
			}
			runTo(applyHook);
		}
		std::printf("against the original (%s, %s): %ld frames compared, %ld with differences; %ld during resets and %ld "
			"half-done snapshots not compared; %ld with a different number of RANDOM reads (the state taken from the original's RAM after each difference)\n", oracleDir, pal ? "PAL" : "NTSC",
			compared, bad, busyFrames, mid, readsBad);
		for (auto &d : diffCount) std::printf("  %s: %ld frames\n", d.first.c_str(), d.second);
		return bad || readsBad ? 1 : 0;
	}
	// The sound: POKEY's registers as the sound driver set them, compared with the C++ port's;
	// -wav FILE: the samples the program made for the DAC, -wavcpp FILE: the C++ port's POKEY
	// (PokeySound) at the same rate from its registers (16-bit WAVs to listen to)
	const uint16_t pokeyAudf = symbol(argv[2], "pokey_audf"), pokeyAudc = symbol(argv[2], "pokey_audc");
	const uint16_t sndW = symbol(argv[2], "snd_w");
	constexpr int kSampleRate = 875000 / 55;
	std::vector<int16_t> wavZ80, wavCpp;
	rr::PokeySound cppPokey(kSampleRate, pal ? rr::kPal.clock : rr::kNtsc.clock);
	uint16_t lastW = 0;
	long sndSamples = 0, sndFrames = 0;
	long long sndSum = 0, sndMax = 0;
	int sndMaxFrame = 0;
	long long lastSnd = 0;
	const uint16_t pokeyFrame = symbol(argv[2], "pokey_frame");
	int errors = 0;
	bool soloMode = false;
	long long lastApply = -1, longestFrame = 0, applyTick = -1, workMax = 0, workSum = 0;
	int lateFrames = 0, workMaxFrame = 0, worked = 0;
	for (int f = 1; f <= frames; f++) {
		if (f == switchAt) {
			// CAPS + 1: the program starts again with the other standard; so does the C++ port,
			// a new machine (POKEY's counter from another seed for both)
			pal = !pal;
			writeZ80(comp, tvToggle, 1);
			const uint32_t first = rrzx::pokeyFirstRead(seed + 1, pal);
			writeZ80(comp, rndState, uint8_t(first));
			writeZ80(comp, uint16_t(rndState + 1), uint8_t(first >> 8));
			writeZ80(comp, uint16_t(rndState + 2), uint8_t(first >> 16));
			game.~Game();
			new (&game) rr::Game(rom);
			game.afterDisplay = afterDisplay;
			game.startAttract(pal);
			random = rr::PokeyRandom(seed + 1, rr::tvSystem(pal));
			random.nextFrame();
		}
		if (!getenv("NXHISTALL")) {   // pokey_frame's time: the samples made
			runTo(pokeyFrame);
			const long long t0 = comp->tickTotal;
			runTo(frameHook);
			const long long t = comp->tickTotal - t0;
			lastSnd = t;
			if (getenv("NXSNDT") && f >= atoi(getenv("NXSNDT")) && f < atoi(getenv("NXSNDT")) + 15)
				std::printf("frame %d: pokey_frame %lld ticks, %d samples, work so far %lld\n", f, t,
					readZ80(comp, symbol(argv[2], "snd_n")) | (readZ80(comp, uint16_t(symbol(argv[2], "snd_n") + 1)) << 8), comp->tickTotal - applyTick);
			if (applyTick >= 0) {
				sndSum += t;
				if (t > sndMax) { sndMax = t; sndMaxFrame = f; }
			}
		} else
			runTo(frameHook);
		if (applyTick >= 0) {   // the frame's work, from the apply before it
			const long long w = comp->tickTotal - applyTick;
			if (getenv("NXSLOW") && w > std::atol(getenv("NXSLOW"))) {
				std::printf("frame %d: work %lld, pokey_frame %lld (lines left %d, %d samples); regs", f, w, lastSnd,
					readZ80(comp, symbol(argv[2], "pk_left")), readZ80(comp, symbol(argv[2], "snd_n")) | (readZ80(comp, uint16_t(symbol(argv[2], "snd_n") + 1)) << 8));
				for (int c = 0; c < 4; c++) std::printf(" %02X/%02X", readZ80(comp, uint16_t(pokeyAudf + c)), readZ80(comp, uint16_t(pokeyAudc + c)));
				std::printf("\n");
			}
			workSum += w;
			worked++;
			if (w > workMax) { workMax = w; workMaxFrame = f; }
		}
		int reads = 0;
		if (input.start && !game.busy()) {
			games++;
			gameNumbers |= 1 << (game.g.gameNumber & 7);
		}
		if (game.busy()) busyFrames++;
		if (game.g.pauseState) pausedFrames++;
		game.frame(input, [&] { return reads++ ? random.read(249, 13) : pal ? random.read(191, 24) : random.read(192, 13); });
		random.nextFrame();
		takePicture();
		{
			const uint8_t count = readZ80(comp, sbCount);
			if (count > maxSprites) maxSprites = count;
		}
		{
			const rr::GameState &g = game.g;
			if (g.planeState == 0xFE && lastState != 0xFE) {
				crashes++;
				if (getenv("NXBOT"))
					std::printf("crash frame %d: fuel %02X obj %02X bank %02X shell %02X missile %02X level %d planeX %02X kind %02X type %02X y %02X x %02X\n", f, g.fuel,
						g.hit.planeHitObject, g.hit.planeHitBank, g.hit.planeHitShell, g.hit.missileHitPlane, game.gen.s.level, g.planeX, game.gen.s.slot[g.hit.planeHitObject & 15].kind, game.gen.s.slot[g.hit.planeHitObject & 15].type, game.gen.s.slot[g.hit.planeHitObject & 15].y, game.gen.s.slot[g.hit.planeHitObject & 15].x);
			}
			if (g.planeState == 0xFF && lastState != 0xFF && !(g.attractFlags & 0x80)) gameOvers++;
			lastState = g.planeState;
			if (!(g.attractFlags & 0x80)) {
				const long b = (g.bridges[0] >> 4) * 1000 + (g.bridges[0] & 15) * 100 + (g.bridges[1] >> 4) * 10 + (g.bridges[1] & 15);
				if (b > maxBridge) maxBridge = b;
			}
		}

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
		for (const auto &ar : kGameArrays)
			for (int i = 0; i < ar.size; i++)
				if (ram[ar.addr + i] != ref[ar.addr + i]) {
					std::snprintf(b, sizeof b, "%s[%d] $%04X: z80=%02X c++=%02X", ar.name, i, ar.addr + i, ram[ar.addr + i], ref[ar.addr + i]);
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
				if (i >= 1 && i <= 3 && !want[0]) continue;   // player 3's position, size, colour: where it is
				const uint8_t z = readZ80(comp, uint16_t(kScan + 0x100 * i + kRiverFirstLine + k));
				if (z != want[i]) {
					std::snprintf(b, sizeof b, "scan line %d %s: z80=%02X c++=%02X", k, names[i], z, want[i]);
					diffs.push_back(b);
				}
			}
		}
		{
			const rr::PokeyRegs &p = game.g.pokey;
			for (int c = 0; c < 4; c++) {
				const uint8_t zc = readZ80(comp, uint16_t(pokeyAudc + c)), zf = readZ80(comp, uint16_t(pokeyAudf + c));
				// a noise's pitch from RANDOM: read at another moment, not compared
				// (and kept while nothing writes it again: a pause, the start beep)
				static bool stale[4];
				static uint8_t prevAudf[4];
				const bool noise = (c == 1 && (p.audc[1] & 0xF0) == 0x80) || (c == 3 && p.audc[3] == 0x8C)
					|| (stale[c] && p.audf[c] == prevAudf[c]);
				stale[c] = noise;
				prevAudf[c] = p.audf[c];
				if (zc != p.audc[c] || (!noise && zf != p.audf[c])) {
					std::snprintf(b, sizeof b, "pokey %d: z80 audf %02X audc %02X, c++ %02X %02X", c + 1, zf, zc, p.audf[c], p.audc[c]);
					diffs.push_back(b);
				}
			}
			{   // the pure tones on the first AY: the registers as they were 2 frames ago
				static uint8_t hist[3][8];   // [frames ago][audf 0-3, audc 0-3]
				std::memmove(hist[1], hist[0], 2 * 8);
				for (int c = 0; c < 4; c++) { hist[0][c] = p.audf[c]; hist[0][4 + c] = p.audc[c]; }
				static const int vol[16] = {0, 6, 8, 10, 11, 11, 12, 12, 13, 13, 13, 14, 14, 14, 15, 15};
				const uint8_t *h = hist[2];
				const int chans[3] = {0, 2, 3};
				aymChip *ay = comp->ts->chipA;
				for (int k = 0; k < 3; k++) {
					const int c = chans[k];
					int n = 0, v = 0;
					if (f > 2 && ((h[4 + c] & 0xF0) == 0xA0 || (h[4 + c] & 0xF0) == 0xE0) && (h[4 + c] & 15)) {
						const int a = h[c] + 1;
						n = a == 256 ? (pal ? 884 : 876) : 3 * a + ((a * (pal ? 116 : 108) + 128) >> 8);
						v = vol[h[4 + c] & 15];
					}
					const int zn = ay->reg[2 * k] | ((ay->reg[2 * k + 1] & 15) << 8), zv = ay->reg[8 + k] & 15;
					if (zv != v || (v && zn != n)) {
						std::snprintf(b, sizeof b, "ay %c: period %d volume %d, expected %d %d", 'A' + k, zn, zv, n, v);
						diffs.push_back(b);
					}
				}
			}
			const uint16_t w = uint16_t(readZ80(comp, sndW) | (readZ80(comp, uint16_t(sndW + 1)) << 8));
			if (f > 1) {
				for (uint16_t a = lastW; a != w; a = uint16_t(0x7C00 | ((a + 1) & 0x3FF))) {
					if (wavPath) wavZ80.push_back(int16_t((int(readZ80(comp, a)) - 60) * 128));
					sndSamples++;
				}
				sndFrames++;
				if (getenv("NXSNDCHK")) {   // a sample above what the channels can add up to
					static int prevMax = 0;
					int mx = 0;
					for (int c = 0; c < 4; c++) mx += (p.audc[c] & 15) * 4;
					const int lim = std::max(mx, prevMax);
					prevMax = mx;
					int worst = -1;
					for (uint16_t a = lastW; a != w; a = uint16_t(0x7C00 | ((a + 1) & 0x3FF)))
						worst = std::max(worst, int(readZ80(comp, a)));
					if (worst > lim) {
						std::printf("frame %d: sample %d above %d; regs", f, worst, lim);
						for (int c = 0; c < 4; c++) std::printf(" %02X/%02X", p.audf[c], p.audc[c]);
						std::printf("\n");
					}
				}
				if (getenv("NXSND") && (f % 50 == 0 || (f >= atoi(getenv("NXSND")) && f < atoi(getenv("NXSND")) + 12))) {
					std::printf("frame %d regs", f);
					for (int c = 0; c < 4; c++) std::printf(" %02X/%02X", p.audf[c], p.audc[c]);
					std::printf(" ch1:");
					for (int k = 0; k < 8; k++) std::printf(" %02X", readZ80(comp, uint16_t(symbol(argv[2], "snd_ch") + k)));
					std::printf(" poly@0 %02X", comp->mem->ramData[sramOffset(14)]);
					std::printf(" samples:");
					int k = 0;
					for (uint16_t a = uint16_t(0x7C00 | ((w - 40) & 0x3FF)); a != w && k < 40; a = uint16_t(0x7C00 | ((a + 1) & 0x3FF)), k++) std::printf(" %d", readZ80(comp, a));
					std::printf("\n");
				}
			}
			lastW = w;
			if (wavCppPath) {
				for (int c = 0; c < 4; c++) {
					cppPokey.write(2 * c, p.audf[c]);
					cppPokey.write(2 * c + 1, p.audc[c]);
				}
				cppPokey.run(pal ? 312L * 114 : 262L * 114, wavCpp);
			}
		}
		if (soloMode) diffs.clear();
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
		if (getenv("NXSLOW")) {   // the wait for the raster line, then apply
			runTo(uint16_t(frameHook + 3));
			const long long t0 = comp->tickTotal;
			const int line = readZ80(comp, 0) * 0;   // (unused)
			(void)line;
			runTo(applyHook);
			const long long a = comp->tickTotal - t0;
			if (a > 60000) std::printf("frame %d: apply %lld\n", f, a);
		} else
			runTo(applyHook);
		input = attractOnly ? rr::Input() : bot.next(game);   // the next frame's controls
		// NXSOLO=1 (for the time only): once a game has started, the program's plane cannot
		// crash (crash: RET), the made-up player flies it by its state, nothing is compared
		static bool solo = false;
		if (getenv("NXSOLO") && !solo && game.g.planeState == 0 && !game.busy() && !(game.g.attractFlags & 0x80)) {
			solo = true;
			sram[sramOffset(kCodePages[0]) + (symbol(argv[2], "crash") - 0x8000)] = 0xC9;
		}
		if (solo) {   // the made-up player flies by the program's state
			soloMode = true;
			std::memcpy(ram, sram + sramOffset(kAtariRamPage), sizeof ram);
			game.loadFromRam(ram);
			input = bot.next(game);
			input.start = input.select = input.key = false;
		}
		putInput(inputAt, input);
		// late: more than one Next frame (567 262 ticks at 50 Hz, 481 546 at 60) since the last
		// apply (counted in ticks: an apply ends near the vertical sync, so its count can be off)
		{
			const long long frameTicks = pal ? 567262 : 481546;
			const long long period = applyTick >= 0 ? comp->tickTotal - applyTick : frameTicks;
			const long long n = (period + frameTicks / 2) / frameTicks;
			if (applyTick >= 0 && n > 1) {
				lateFrames++;
				if (getenv("NXSLOW")) std::printf("frame %d late: %lld Next frames since the last apply\n", f, n);
			}
			if (n > longestFrame) longestFrame = n;
		}
		applyTick = comp->tickTotal;
		(void)lastApply;
	}
	if (errors) {
		std::printf("FAIL: frames differ\n");
		return 1;
	}
	if (histAllPath) {
		FILE *hf = std::fopen(histAllPath, "w");
		for (int a = 0; a < 0x10000; a++)
			if (histAll[a]) std::fprintf(hf, "%04X %lld\n", a, histAll[a]);
		std::fclose(hf);
	}
	std::printf("%d frames: state, screen and the DLI's lines the same\n", frames);
	std::string numbers;
	for (int n = 0; n < 8; n++)
		if (gameNumbers >> n & 1) numbers += (numbers.empty() ? "" : ",") + std::to_string(n + 1);
	std::printf("played: %ld games started (games %s), %ld crashes, %ld games over, up to bridge %ld; %ld frames paused, %ld of resets\n",
		games, numbers.empty() ? "-" : numbers.c_str(), crashes, gameOvers, maxBridge, pausedFrames, busyFrames);
	std::printf("sprites: up to %d of the %d a frame can have\n", maxSprites, kSpritesMax);
	if (getenv("NXOBJCHECK")) {   // (a build with -DOBJCHECK: the objects' sprites against the scanlines)
		const uint16_t bad = symbol(argv[2], "oc_bad"), frames = symbol(argv[2], "oc_frames");
		std::printf("objects' sprites: %d scanlines differ in %d frames checked\n",
			readZ80(comp, bad) | readZ80(comp, uint16_t(bad + 1)) << 8, readZ80(comp, frames) | readZ80(comp, uint16_t(frames + 1)) << 8);
		const uint16_t pc = symbol(argv[2], "pc_bad");
		if (pc) std::printf("other sprites: %d rows outside their boxes\n", readZ80(comp, pc) | readZ80(comp, uint16_t(pc + 1)) << 8);
	}
	std::printf("sound: %.1f samples a frame on average; making them (pokey_frame) %lld ticks on average, %lld at most (frame %d)\n",
		sndFrames ? double(sndSamples) / double(sndFrames) : 0.0, worked ? sndSum / worked : 0, sndMax, sndMaxFrame);
	auto writeWav = [&](const char *path, const std::vector<int16_t> &v) {
		FILE *wf = std::fopen(path, "wb");
		if (!wf) return;
		auto u32 = [&](uint32_t x) { std::fwrite(&x, 4, 1, wf); };
		auto u16 = [&](uint16_t x) { std::fwrite(&x, 2, 1, wf); };
		std::fwrite("RIFF", 1, 4, wf); u32(uint32_t(36 + 2 * v.size())); std::fwrite("WAVEfmt ", 1, 8, wf);
		u32(16); u16(1); u16(1); u32(kSampleRate); u32(kSampleRate * 2); u16(2); u16(16);
		std::fwrite("data", 1, 4, wf); u32(uint32_t(2 * v.size()));
		std::fwrite(v.data(), 2, v.size(), wf);
		std::fclose(wf);
	};
	if (wavPath) writeWav(wavPath, wavZ80);
	if (wavCppPath) writeWav(wavCppPath, wavCpp);
	std::printf("timing: %d frames late (the longest took %lld Next frames); a frame's work: %lld on average, "
		"%lld at most (frame %d), in the core's ticks\n", lateFrames, longestFrame, worked ? workSum / worked : 0, workMax, workMaxFrame);

	// The last frame went live at the apply just run; the Next frame after this one shows it.
	// The program stops there (JR $ at apply_done), so the next frame's apply cannot come first.
	sram[sramOffset(kCodePages[0]) + (applyHook - 0x8000)] = 0x18;
	sram[sramOffset(kCodePages[0]) + (applyHook - 0x8000) + 1] = 0xFE;
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
			if (r >= 0 && r < kPictureLines) rrzx::nextRgb(rrzx::nextColour(rows[size_t(r) * 320 + size_t(x)]), want);
			for (int h = 0; h < 2; h++) {
				const uint8_t *p = pixel(2 * (kL2Left + x) + h, (pal ? kL2Top : 0) + y);
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
			std::fprintf(f, "P6\n320 %d\n255\n", kPictureLines);
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
