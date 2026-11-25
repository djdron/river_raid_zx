// tscheck: runs the TS-Conf viewer (the test build) on Xpeccy+'s TSConf core, with no window,
// and compares it frame by frame with the C++ port (rr::Game::frame, the attract mode, the same
// POKEY counter):
//   - after every frame: the river generator's state (RiverGen::diffWithRam), the game's
//     state (the fields of game_ram.cpp but the scrolling line's), the panel's characters,
//     screen memory, the bank's colour of each river line (its dots' entry against Game::lineBank);
//   - at the end, the picture of the last frame, pixel by pixel: the river and its objects
//     and players as the C++ port's Game::drawRiver draws them,
//     in the TS-Conf's colours, black above and below it;
//   - the machine's picture of every frame against the C++ port's of the frame it shows (the
//     one whose apply came in the machine's frame before it).
//
// usage: tscheck <River_Raid.rom> <build dir> <frames> [frame.ppm] [-seed N] [-start N | -bot N | -stress]
//   -start N: START pressed in frame N; -bot N: nxcheck's made-up player plays (its choices
//   from N), -stress: at full speed, always firing (the bot of seed 1 if no -bot)
//   TSBRIDGE=n: every game starts at bridge n; TSGHOST=1: the plane cannot crash, the fuel
//   stays full; NXGAME=n (the made-up player's): game n, started at once; TSSPEED=n: the CPU
//   at 3.5 (0), 7 (1) or 14 MHz (2, as the program sets it); TSMSHOT=k: the machine's frames
//   from frame k (32, /tmp/tsm_N.ppm); TSBORDER=1: T's colours on the
//   border (TSFULL=1: the picture written with it)
//        tscheck -sna <river_raid.sna> <frames> <frame.ppm>: the snapshot, run for so many frames
//        tscheck -spg <river_raid.spg> <frames> <frame.ppm> [-sd folder]: the SPG (the folder as
//                the SD card, a FAT32 volume)
//   TSFULL=1: the picture written is the core's whole buffer (blanking too)
//   TSCRAM=1 (-sna, -spg): CRAM not black at the start (as a shell may leave it)
//   TSGS: the General Sound (its firmware started first): gs (the original card, gs105b.rom, the
//   default), neo (a NeoGS, neogs111.rom) or 0 (none: the AY's tones checked instead); with a
//   card, the registers it got from apply are checked against the C++ port's POKEY;
//   TSWAV=file: the samples the card made, TSWAVCPP=file: the C++ port's PokeySound at that
//   rate (16-bit WAVs to listen to)
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
#include "sound/gs.h"

#include "game.h"
#include "os_font.h"
#include "status_bar.h"
#include "pokey_counter.h"
#include "pokey_random.h"
#include "pokey_sound.h"
#include "ts_palette.h"

extern "C" void tslUpdatePal(Computer *comp);

namespace {

// The program's memory (src/river_raid.asm)
constexpr int kAtariPage = 1, kCodePage = 2, kHighPage = 6;
constexpr int kVidPage = 32;
constexpr int kWindowFirst = 20;   // first colour clock shown
constexpr int kRiverLines = 160;
constexpr int kPictureLines = 216;   // the river and the panel: the C++ port's rows 20-235
constexpr int kRiverFirstLine = 28;
constexpr int kRiverTop = 24;      // the screen's row of the river's top line (of 240)
constexpr int kRowLine = 55;       // VSINT for screen row r: kRowLine + r

uint16_t symbol(const std::string &dir, const char *name, const char *file = "test.sym") {
	FILE *f = std::fopen((dir + "/" + file).c_str(), "r");
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

// A made-up player. In the attract mode (or after a game) it waits a while, sometimes selects
// another game, then presses START. Flying, it steers towards the middle of the water some
// lines ahead of the plane, with spells of random steering and speed; it fires half the time;
// now and then it pauses the game for a while.
class Bot {
public:
	explicit Bot(uint32_t seed) : s_(seed ? seed : 1) {}
	bool stress = false;              // -stress: full speed, always firing, no pauses
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
		if (!stress && rnd() % 4000 == 0) {
			pause_ = 62 + int(rnd() % 100);
			in.key = true;
			return in;
		}
		uint8_t stick = 0x0F;
		if (!stress && randomFor_ > 0) {  // random steering for a while
			randomFor_--;
			stick = randomStick_;
		} else {
			if (!stress && rnd() % 400 == 0) {
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
			if (stress) speed_ = 1;
			if (speed_ == 1) stick &= ~0x01;
			else if (speed_ == 2) stick &= ~0x02;
		}
		in.stick[0] = in.stick[1] = stick;
		const bool fire = stress || (!depot_ && rnd() % 4 != 0);
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

// The General Sound (TSGS, see above): its ROM read, the card on, its firmware run for 6 s (as
// long after the power as a program starts: past its start). False: none, or its ROM not there.
bool setupGs(Computer *comp) {
	const char *e = std::getenv("TSGS");
	const std::string mode = e ? e : "gs";
	if (mode == "0") return false;
	const bool neo = mode == "neo";
	const std::string path = std::string("../deps/xpeccy-plus/config/roms/") + (neo ? "neogs111.rom" : "gs105b.rom");
	std::vector<uint8_t> rom;
	if (!readFile(path, rom)) { std::printf("no General Sound: cannot read %s\n", path.c_str()); return false; }
	std::memcpy(neo ? comp->gs->romNGS : comp->gs->romGS, rom.data(), std::min(rom.size(), size_t(neo ? NGS_ROM_SIZE : GS_ROM_SIZE)));
	comp->gs->enable = 1;
	gs_set_model(comp->gs, neo ? GS_NEOGS : GS_ORIGINAL);
	for (int i = 0; i < 60; i++) gsSync(comp->gs, 100000000);   // (its 2M checked: ~5 s)
	gsFlush(comp->gs);
	return true;
}
uint8_t readGs(Computer *comp, uint16_t addr) { return uint8_t(mem_rd_fast(comp->gs->mem, addr)); }

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
		comp->ts->type = TS_NEDOPC;
		chip_set_type(comp->ts->chipB, SND_AY);
		setupGs(comp);
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
		if (std::getenv("TSCRAM")) { for (int i = 0; i < 512; i++) comp->vid->tsconf.cram[i] = 0x5A; tslUpdatePal(comp); }   // (a palette not black: what shows during the start)
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
		std::printf("PC %04X, border %02X", comp->cpu->regPC, comp->vid->brdcol);
		if (comp->gs->enable) std::printf("; the General Sound's PC %04X, page %02X", comp->gs->cpu->regPC, comp->gs->rp0);
		std::printf("\n");
		return 0;
	}
	uint32_t seed = 12345;
	int startAt = -1;   // -start N: START pressed in frame N (a game: the plane flies straight on)
	uint32_t botSeed = 0;   // -bot N: a made-up player (nxcheck's) plays, its choices from N
	bool stressBot = false;
	const char *ppm = nullptr;
	for (int i = 4; i < argc; i++) {
		if (!std::strcmp(argv[i], "-seed") && i + 1 < argc) seed = uint32_t(std::strtoul(argv[++i], nullptr, 0));
		else if (!std::strcmp(argv[i], "-start") && i + 1 < argc) startAt = std::atoi(argv[++i]);
		else if (!std::strcmp(argv[i], "-bot") && i + 1 < argc) botSeed = uint32_t(std::strtoul(argv[++i], nullptr, 0));
		else if (!std::strcmp(argv[i], "-stress")) stressBot = true;
		else ppm = argv[i];
	}
	if (stressBot && !botSeed) botSeed = 1;   // -stress alone: the bot of seed 1 (as nxcheck's)
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
	if (const char *sp = std::getenv("TSSPEED")) {   // the CPU: 0 3.5, 1 7, 2 14 MHz (start's SYSCONFIG $06)
		int n = 0;
		for (size_t i = 0; i + 5 < 0x2000; i++)
			if (code[i] == 0x01 && code[i + 1] == 0xAF && code[i + 2] == 0x20 && code[i + 3] == 0x3E && code[i + 4] == 0x06) {
				code[i + 4] = uint8_t(4 | (std::atoi(sp) & 3));
				n++;
			}
		if (n != 1) { std::printf("TSSPEED: %d SYSCONFIG writes found, not 1\n", n); return 2; }
	}

	Computer *comp = compCreate();
	comp->vid->drawAll = 1;
	if (!compSetHardware(comp, "TSConf")) { std::fprintf(stderr, "no TSConf core\n"); return 1; }
	compSetBaseFrq(comp, 3.5);
	memSetSize(comp->mem, MEM_4M, -1);   // the board's 4 MB (the core starts with 128K)
	comp->ts->type = TS_NEDOPC;          // and its TurboSound: two AYs
	chip_set_type(comp->ts->chipB, SND_AY);
	compReset(comp, RES_DEFAULT);
	const bool gsOn = setupGs(comp);
	bytesPerLine = comp->vid->full.x * 8;
	bufSize = bytesPerLine * comp->vid->full.y;
	uint8_t *ram = comp->mem->ramData;
	std::memset(ram, 0, MEM_4M);
	std::memcpy(ram + kCodePage * 0x4000, code.data(), 0x4000);
	std::memcpy(ram + kHighPage * 0x4000, high.data(), 0x4000);
	{   // the work page's font ($7C00-$7FFF)
		std::vector<uint8_t> work;
		if (!readFile(dir + "/ts_page5.bin", work) || work.size() != 0x400) { std::fprintf(stderr, "cannot read %s/ts_page5.bin\n", dir.c_str()); return 2; }
		std::memcpy(ram + 5 * 0x4000 + 0x3C00, work.data(), 0x400);
		std::vector<uint8_t> init;   // and the start's work (page 3)
		if (!readFile(dir + "/ts_page3.bin", init) || init.size() != 0x4000) { std::fprintf(stderr, "cannot read %s/ts_page3.bin\n", dir.c_str()); return 2; }
		std::memcpy(ram + 3 * 0x4000, init.data(), 0x4000);
	}
	memSetBank(comp->mem, 0x80, MEM_RAM, kCodePage, MEM_16K, NULL, NULL, NULL);
	memSetBank(comp->mem, 0xC0, MEM_RAM, kHighPage, MEM_16K, NULL, NULL, NULL);
	comp->cpu->regPC = 0x8000;

	rr::Game game(rom);
	// TSBRIDGE=n: every game starts at bridge n (as river_raid -bridge): the C++ port's starts
	// (RiverGen::setRiver), the program's from the ROM's tables ($B494 checkpoints, $B4A4
	// levels, $B4A8 bridges, BCD) and start_bridges_hi (the hundreds, test builds)
	if (const char *sb = std::getenv("TSBRIDGE")) {
		const int startBridge = std::atoi(sb);
		game.gen.setRiver(0, startBridge);
		uint8_t *romCopy = ram + kCodePage * 0x4000 + 0x2000;
		const int b = startBridge % 10000;
		for (int n = 0; n < 4; n++) {
			const rr::RiverGen::Start &st = game.gen.start(n);
			for (int i = 0; i < 4; i++) romCopy[0xB494 + 4 * i + n - 0xA000] = st.checkpoint[i];
			romCopy[0xB4A4 + n - 0xA000] = st.level;
			romCopy[0xB4A8 + n - 0xA000] = uint8_t((b / 10 % 10) << 4 | b % 10);
		}
		const uint16_t hi = symbol(dir, "start_bridges_hi");
		ram[kCodePage * 0x4000 + (hi - 0x8000)] = uint8_t((b / 1000) << 4 | b / 100 % 10);
	}
	// TSGHOST=1: after the display the plane's crashes are dropped and the fuel is full, on
	// both sides (the program's test_ghost), so a game goes on for long (with TSBRIDGE)
	const bool ghost = std::getenv("TSGHOST") != nullptr;
	if (ghost) ram[kCodePage * 0x4000 + (symbol(dir, "test_ghost_on") - 0x8000)] = 1;
	rr::PokeyRandom random(seed, rr::tvSystem(true));
	game.startAttract(true);
	random.nextFrame();
	std::vector<uint8_t> rows(size_t(kPictureLines) * 320);   // the last frame's picture (Atari colours)
	uint8_t osFont[rr::kOsFontBytes];
	rr::builtinOsFont(osFont);
	const rr::Charsets charsets = rr::buildCharsets(rom, osFont);
	static uint8_t picture[rr::kScreenHeight][rr::kScreenWidth];
	auto riverPicture = [&] {   // after the display: the river and its sprites
		std::memset(picture, 0, sizeof picture);
		game.drawRiver(picture);
	};
	auto takePicture = [&] {   // after the frame: the panel (as the C++ port's game shows the frame)
		const rr::GameState &g = game.g;
		rr::drawStatusBar(rom, charsets, g.panel, g.fuel, g.scroller, g.logoShown, picture, true);
		for (int k = 0; k < kPictureLines; k++)
			std::memcpy(&rows[size_t(k) * 320], &picture[rr::kRiverTop + k][2 * kWindowFirst], 320);
	};
	game.afterDisplay = [&] {   // the river as the display sees it (before the new lines)
		riverPicture();
		if (ghost) {
			game.g.hit.planeHitBank = game.g.hit.planeHitObject = game.g.hit.planeHitShell = game.g.hit.missileHitPlane = 0xFF;
			game.g.fuel = 0xFF;
		}
	};
	// TSHISTALL=file: the time spent at each instruction over all the frames (the work, the
	// INTs, apply and the wait for the frame: wait_frame); ../tools/prof.py sums it per routine
	static long long histAll[0x10000];
	static long volHist[64];
	static int levelMax = 0, dacMax = 0;
	const char *histAllPath = std::getenv("TSHISTALL");
	// TSHISTMIN=n (with TSHISTALL): only the frames whose work is n ticks or more (the heavy
	// ones; their number printed), each instruction's time from one frame_done to the next
	const long long histMin = std::getenv("TSHISTMIN") ? std::atoll(std::getenv("TSHISTMIN")) : -1;
	static long long histFrame[0x10000];
	std::vector<uint16_t> histTouched;
	long histFrames = 0;
	// TSMSHOT=k: each machine's frame from frame k on (32 of them), to /tmp/tsm_N.ppm (a late
	// frame's second one too, which TSSHOT does not see)
	static int mshotFrom = std::getenv("TSMSHOT") ? std::atoi(std::getenv("TSMSHOT")) : -1, mshotN = 0, curFrame = 0;
	auto runTo = [&](uint16_t hook) {
		for (long n = 0; n < 50000000L; n++) {
			const uint16_t pc = comp->cpu->regPC;
			const long long t = comp->tickTotal;
			const int sw = bufSwaps;
			compExec(comp);
			if (bufSwaps != sw && mshotFrom > 0 && curFrame >= mshotFrom && mshotN < 32) {
				char fn[64];
				std::snprintf(fn, sizeof fn, "/tmp/tsm_%d.ppm", mshotN++);
				if (FILE *o = std::fopen(fn, "wb")) {
					std::fprintf(o, "P6\n320 240\n255\n");
					for (int y = 0; y < 240; y++)
						for (int x = 0; x < 320; x++)
							std::fwrite(bufimg + (comp->vid->tsconf.yPos + y) * bytesPerLine + (comp->vid->tsconf.xPos * 2 + 2 * x) * 4, 1, 3, o);
					std::fclose(o);
				}
			}
			if (histAllPath) {
				if (histMin < 0) histAll[pc] += comp->tickTotal - t;
				else {
					if (!histFrame[pc]) histTouched.push_back(pc);
					histFrame[pc] += comp->tickTotal - t;
				}
			}
			if (comp->cpu->regPC == hook) return true;
		}
		return false;
	};
	const uint16_t scrollAt = symbol(dir, "scroll"), bankColsAt = symbol(dir, "bank_cols"), bankNAt = symbol(dir, "bank_n");
	// the General Sound: the program's state (build/gs.sym), the samples (TSWAV, TSWAVCPP)
	const uint16_t gsOnAt = symbol(dir, "gs_on"), gsAudf = symbol(dir, "pokey_audf", "gs.sym"),
		gsAudc = symbol(dir, "pokey_audc", "gs.sym"), gsW = symbol(dir, "snd_w", "gs.sym");
	const char *wavPath = std::getenv("TSWAV"), *wavCppPath = std::getenv("TSWAVCPP");
	constexpr int kGsRate = 37500 * 108 / 256;   // the card's INT takes a sample 108 / 256 of them
	std::vector<int16_t> wavGs, wavCpp;
	rr::PokeySound cppPokey(kGsRate, rr::kPal.clock);
	long gsSamples = 0;
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
				if (r >= 0 && r < kPictureLines) rrts::cramRgb(rrts::cramWord(want[size_t(r) * 320 + size_t(x)]), rgb);
				const uint8_t *p = bufimg + (y0 + y) * bytesPerLine + (x0 + 2 * x) * 4;
				if (std::memcmp(p, rgb, 3)) return y * 1000 + x + 1;
			}
		return 0;
	};
	static uint8_t ref[0x4000], mine[0x4000];
	int errors = 0;
	long evBad = 0;
	Bot bot(botSeed);
	bot.stress = stressBot;
	long games = 0, crashes = 0, gameOvers = 0, maxBridge = 0;
	uint8_t lastState = 0xFF;
	const int swaps0 = bufSwaps;
	int swapsFirst = 0, lateShown = 0;
	const long long tick0 = comp->tickTotal;
	long long workSum = 0, workMax = 0, applyTick = -1;
	int workMaxFrame = 0;
	for (int f = 1; f <= frames; f++) {
		curFrame = f;
		rr::Input input;
		if (botSeed) input = bot.next(game);
		else input.start = f == startAt;
		putInput(ram + kCodePage * 0x4000 + 12, input);   // in_stick, in_trig, in_console, in_key
		if (f == 2 && std::getenv("TSBORDER"))   // T's border on (TSFULL: the picture with the border)
			ram[kHighPage * 0x4000 + (symbol(dir, "tm_show") - 0xC000)] = 1;
		if (!runTo(frameHook)) { std::printf("frame %d: the program never got to frame_done (PC %04X)\n", f, comp->cpu->regPC); return 1; }
		if (f == 1) swapsFirst = bufSwaps;   // (the start's frames before it: not counted)
		if (applyTick >= 0) {   // the frame's work, from the apply before it
			const long long w = comp->tickTotal - applyTick;
			workSum += w;
			if (w > workMax) { workMax = w; workMaxFrame = f; }
			if (histMin >= 0 && w >= histMin) {
				for (uint16_t a : histTouched) histAll[a] += histFrame[a];
				histFrames++;
			}
		}
		if (histMin >= 0) {
			for (uint16_t a : histTouched) histFrame[a] = 0;
			histTouched.clear();
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
						if (r >= 0 && r < kPictureLines) rrts::cramRgb(rrts::cramWord(want[size_t(r) * 320 + size_t(x)]), rgb);
						std::fwrite(rgb, 1, 3, o);
					}
				}
				std::fclose(o);
			}
			if (at && picBad <= 3) std::printf("frame %d: the picture of frame %d differs from (%d, %d) on\n", f, shown + 1, (at - 1) % 1000, (at - 1) / 1000);
		}
		{   // TSSHOT=k: the machine's frames from frame k on, to /tmp/tsshot_N.ppm (8 of them; TSFULL:
		    // with the border)
			static const int shotFrom = std::getenv("TSSHOT") ? std::atoi(std::getenv("TSSHOT")) : -1;
			if (shotFrom > 0 && f >= shotFrom && f < shotFrom + 8) {
				char fn[64];
				std::snprintf(fn, sizeof fn, "/tmp/tsshot_%d.ppm", f - shotFrom);
				FILE *o = std::fopen(fn, "wb");
				if (std::getenv("TSFULL")) {   // (TSFULL: all of it, the border too)
					std::fprintf(o, "P6\n%d %d\n255\n", comp->vid->full.x * 2, comp->vid->full.y);
					for (int y = 0; y < comp->vid->full.y; y++)
						for (int x = 0; x < comp->vid->full.x * 2; x++)
							std::fwrite(bufimg + y * bytesPerLine + x * 4, 1, 3, o);
				} else {
					std::fprintf(o, "P6\n320 240\n255\n");
					for (int y = 0; y < 240; y++)
						for (int x = 0; x < 320; x++)
							std::fwrite(bufimg + (comp->vid->tsconf.yPos + y) * bytesPerLine + (comp->vid->tsconf.xPos * 2 + 2 * x) * 4, 1, 3, o);
				}
				std::fclose(o);
			}
		}
		if (getenv("TSBUSY") && game.busy()) std::printf("frame %d: busy\n", f);
		int reads = 0;
		if (input.start && !game.busy()) games++;
		game.frame(input, [&] { return reads++ ? random.read(249, 13) : random.read(191, 24); });
		{
			const rr::GameState &g = game.g;
			if (g.planeState == 0xFE && lastState != 0xFE) crashes++;
			if (g.planeState == 0xFF && lastState != 0xFF && !(g.attractFlags & 0x80)) gameOvers++;
			lastState = g.planeState;
			if (!(g.attractFlags & 0x80)) {
				const long br = (g.bridges[0] >> 4) * 1000 + (g.bridges[0] & 15) * 100 + (g.bridges[1] >> 4) * 10 + (g.bridges[1] & 15);
				if (br > maxBridge) maxBridge = br;
			}
		}
		random.nextFrame();
		takePicture();
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
		{   // the bank's colour by line: each river line's bank dots in its colour's entry of the
			// river's palette (render.asm: bank_cols, entry 1 then 9..), against the C++ port's
			// lineBank (drawRiver's colour; lines without bank dots not compared)
			const uint16_t sc = uint16_t(readZ80(comp, scrollAt) | readZ80(comp, uint16_t(scrollAt + 1)) << 8);
			const int n = readZ80(comp, bankNAt);
			for (int k = 0; bankColsAt && k < kRiverLines && size_t(k) < game.lineBank.size() && size_t(k) < game.screen.size(); k++) {
				const int line = (sc + kRiverTop + k) & 511;
				const uint8_t *v = ram + kVidPage * 0x4000 + line * 256;
				int e = -1;
				for (int x = 0; x < 160 && e < 0; x++) {
					const int c = v[x] & 15;
					if (c == 1 || c >= 9) e = c;
				}
				if (e < 0) continue;
				const int i = e == 1 ? 0 : e - 8;
				const int colour = i < n ? readZ80(comp, uint16_t(bankColsAt + i)) : -1;
				if (colour != game.lineBank[size_t(k)]) {
					evBad++;
					std::snprintf(b, sizeof b, "bank colour, river line %d: %02X (entry %d), c++ %02X", k, colour, e, game.lineBank[size_t(k)]);
					diffs.push_back(b);
					break;
				}
			}
		}
		if (!gsOn) {   // the pure tones on the AY (sound_ay.asm): the registers the apply before this
			// frame put out, against the C++ port's POKEY of the frame before
			static uint8_t prevAudf[4], prevAudc[4];
			static bool havePrev = false;
			static const int vol[16] = {0, 8, 10, 12, 13, 13, 14, 14, 15, 15, 15, 15, 15, 15, 15, 15};
			// each POKEY channel's AY channel: 1 the second chip's A, 2 its B, 3 the first's B, 4 its
			// C (the first: selected by #FF, Xpeccy+'s chipB; the second by #FE, its chipA)
			aymChip *chips[4] = {comp->ts->chipA, comp->ts->chipA, comp->ts->chipB, comp->ts->chipB};
			const int slot[4] = {0, 1, 1, 2};
			for (int c = 0; havePrev && c < 4; c++) {
				int n = 0, v = 0;
				const bool tone = ((prevAudc[c] & 0xF0) == 0xA0 || (prevAudc[c] & 0xF0) == 0xE0) && (prevAudc[c] & 15);
				if (tone) {
					const int a = prevAudf[c] + 1;
					n = a == 256 ? 884 : 3 * a + ((a * 116 + 128) >> 8);
					v = vol[prevAudc[c] & 15];
				}
				aymChip *ay = chips[c];
				const int k = slot[c];
				const int zn = ay->reg[2 * k] | ((ay->reg[2 * k + 1] & 15) << 8), zv = ay->reg[8 + k] & 15;
				const bool toneOn = !(ay->reg[7] & (1 << k));
				if (zv != v || (v && (zn != n || !toneOn))) {
					std::snprintf(b, sizeof b, "ay %d: period %d volume %d, expected %d %d", c + 1, zn, zv, n, v);
					diffs.push_back(b);
				}
			}
			for (int c = 0; c < 4; c++) { prevAudf[c] = game.g.pokey.audf[c]; prevAudc[c] = game.g.pokey.audc[c]; }
			havePrev = true;
		}
		if (gsOn) {   // the General Sound (sound_gs.asm): the registers the apply before this frame
			// sent it, against the C++ port's POKEY of the frame before; the samples it has made
			// (a noise's pitch from RANDOM, read at another moment: not compared, as nxcheck; nor
			// while nothing writes it again: a pause, the start beep)
			static uint8_t prevAudf[4], prevAudc[4];
			static bool havePrev = false, prevNoise[4];
			static uint16_t lastW = 0;
			gsFlush(comp->gs);
			if (!readZ80(comp, gsOnAt)) {
				diffs.push_back("the General Sound does not play (gs_on 0)");
			} else if (havePrev) {
				for (int c = 0; c < 4; c++) {
					const uint8_t zf = readGs(comp, uint16_t(gsAudf + c)), zc = readGs(comp, uint16_t(gsAudc + c));
					if ((zf != prevAudf[c] && !prevNoise[c]) || zc != prevAudc[c]) {
						std::snprintf(b, sizeof b, "gs %d: AUDF %02X AUDC %02X, expected %02X %02X", c + 1, zf, zc, prevAudf[c], prevAudc[c]);
						diffs.push_back(b);
					}
				}
			}
			const uint16_t w = uint16_t(readGs(comp, gsW) | readGs(comp, uint16_t(gsW + 1)) << 8);
			if (havePrev)
				for (uint16_t a = lastW; a != w; a = uint16_t(0x8000 | ((a + 1) & 0x3FF))) {
					{ const int lv = readGs(comp, a); levelMax = std::max(levelMax, lv); wavGs.push_back(int16_t((lv - 30) * 256)); }
					gsSamples++;
				}
			lastW = w;
			if (wavCppPath) {
				for (int c = 0; c < 4; c++) {
					cppPokey.write(2 * c, prevAudf[c]);
					cppPokey.write(2 * c + 1, prevAudc[c]);
				}
				cppPokey.run(312L * 114, wavCpp);
			}
			for (int c = 0; c < 4; c++) {
				const rr::PokeyRegs &p = game.g.pokey;
				prevNoise[c] = (c == 1 && (p.audc[1] & 0xF0) == 0x80) || (c == 3 && p.audc[3] == 0x8C)
					|| (prevNoise[c] && p.audf[c] == prevAudf[c]);
				prevAudf[c] = p.audf[c];
				prevAudc[c] = p.audc[c];
			}
			{   // the volumes' sum the card's levels get (all four channels on its DAC)
				int sum = 0;
				int dac = 0;   // (and those the Next's DAC gets: not the pure tones its AYs play)
				for (int c = 0; c < 4; c++) {
					sum += prevAudc[c] & 15;
					const int k = prevAudc[c] >> 5;
					if (!((k == 5 || k == 7) && !(prevAudc[c] & 16))) dac += prevAudc[c] & 15;
				}
				volHist[sum]++;
				dacMax = std::max(dacMax, dac);
			}
			havePrev = true;
		}
		if (!diffs.empty()) {
			std::printf("frame %d (level %d): %zu differences\n", f, game.gen.s.level, diffs.size());
			for (size_t i = 0; i < diffs.size() && i < 24; i++) std::printf("  %s\n", diffs[i].c_str());
			if (++errors >= 2) return 1;
			game.loadFromRam(mine);   // go on from the Z80's state
		}
		const long long beforeApply = comp->tickTotal;
		if (!runTo(applyHook)) { std::printf("frame %d: the program never got to apply_done\n", f); return 1; }
		if (std::getenv("TSTIME") && std::abs(f - std::atoi(std::getenv("TSTIME"))) <= 2)
			std::printf("frame %d: work %lld, then to apply_done %lld\n", f, applyTick >= 0 ? beforeApply - applyTick : 0, comp->tickTotal - beforeApply);
		applyTick = comp->tickTotal;
		applySwaps.push_back(bufSwaps);   // (one machine's frame a frame: else late)
		if (applySwaps.size() > 1 && applySwaps.back() - applySwaps[applySwaps.size() - 2] > 1 && lateShown++ < 5)
			std::printf("frame %d: late (its apply %d of the machine's frames after the last)\n", f, applySwaps.back() - applySwaps[applySwaps.size() - 2]);
	}
	std::printf("%d frames: %d late (an apply more than one machine's frame after the one before); the start took %d of the machine's\n",
		frames, lateShown, swapsFirst - swaps0);
	std::printf("a frame's work: %lld ticks on average, %lld at most (frame %d), of %lld a frame\n",
		frames > 1 ? workSum / (frames - 1) : 0, workMax, workMaxFrame, (comp->tickTotal - tick0) / std::max(1, bufSwaps - swaps0));
	if (histMin >= 0) std::printf("TSHISTALL: the %ld frames with work of %lld ticks or more\n", histFrames, histMin);
	if (histAllPath) {
		FILE *hf = std::fopen(histAllPath, "w");
		for (int a = 0; a < 0x10000; a++)
			if (histAll[a]) std::fprintf(hf, "%04X %lld\n", a, histAll[a]);
		std::fclose(hf);
	}
	if (std::getenv("TSVOL")) { std::printf("the volumes' sum: "); for (int v = 0; v < 61; v++) if (volHist[v]) std::printf("%d:%ld ", v, volHist[v]); std::printf("\nthe card's highest level: %d (of 255); the Next's DAC channels' sum at most %d (31 its limit)\n", levelMax, dacMax); }
	std::printf("%d frames compared: %s\n", frames, errors ? "with differences" : "the same");
	if (gsOn) {
		const uint16_t fr = symbol(dir, "snd_frames", "gs.sym"), pa = symbol(dir, "snd_passed", "gs.sym");
		std::printf("General Sound: %d frames played, %d after the INT had passed the samples; %ld samples\n",
			readGs(comp, fr) | readGs(comp, uint16_t(fr + 1)) << 8, readGs(comp, pa) | readGs(comp, uint16_t(pa + 1)) << 8, gsSamples);
		{   // its 17-bit counter's bits (made by the card from their recurrence) against tools/mkpoly's
			std::vector<uint8_t> q(131071);
			uint32_t r = 0x1FFFF;
			for (size_t k = 0; k < q.size(); k++) { q[k] = uint8_t(r & 1); r = ((r << 1) | (((r >> 16) ^ (r >> 11)) & 1)) & 0x1FFFF; }
			int polyBad = 0;
			for (int i = 0; i < 0x4000; i++) {
				uint8_t want = 0;
				for (int k = 0; k < 8; k++) want |= uint8_t(q[(28 * size_t(8 * i + k)) % q.size()] << k);
				if (readGs(comp, uint16_t(0xC000 + i)) != want) polyBad++;
			}
			if (polyBad) { std::printf("FAIL: the card's 17-bit counter differs in %d bytes\n", polyBad); errors++; }
			const uint16_t g4b = symbol(dir, "g4c_bad", "gs.sym"), g4n = symbol(dir, "g4c_n", "gs.sym");
			if (g4b) std::printf("G4CHECK: %d of %d wrong\n", readGs(comp, g4b) | readGs(comp, uint16_t(g4b + 1)) << 8, readGs(comp, g4n) | readGs(comp, uint16_t(g4n + 1)) << 8);
		}
		auto writeWav = [&](const char *path, const std::vector<int16_t> &v) {
			FILE *wf = std::fopen(path, "wb");
			if (!wf) return;
			auto u32 = [&](uint32_t x) { std::fwrite(&x, 4, 1, wf); };
			auto u16 = [&](uint16_t x) { std::fwrite(&x, 2, 1, wf); };
			std::fwrite("RIFF", 1, 4, wf); u32(uint32_t(36 + 2 * v.size())); std::fwrite("WAVEfmt ", 1, 8, wf);
			u32(16); u16(1); u16(1); u32(kGsRate); u32(kGsRate * 2); u16(2); u16(16);
			std::fwrite("data", 1, 4, wf); u32(uint32_t(2 * v.size()));
			std::fwrite(v.data(), 2, v.size(), wf);
			std::fclose(wf);
		};
		if (wavPath) writeWav(wavPath, wavGs);
		if (wavCppPath) writeWav(wavCppPath, wavCpp);
	}
	if (botSeed) std::printf("played: %ld games started, %ld crashes, %ld games over, up to bridge %ld\n", games, crashes, gameOvers, maxBridge);

	// The last frame went live at the apply just run; the frame after shows it. The program
	// stops when its panel is drawn (JR $ at panel_done).
	const uint16_t panelDone = symbol(dir, "panel_done");   // (after the panel's characters)
	runTo(panelDone);
	ram[kCodePage * 0x4000 + (panelDone - 0x8000)] = 0x18;
	ram[kCodePage * 0x4000 + (panelDone - 0x8000) + 1] = 0xFE;
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
			if (r >= 0 && r < kPictureLines) rrts::cramRgb(rrts::cramWord(rows[size_t(r) * 320 + size_t(x)]), want);
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
					if (r >= 0 && r < kPictureLines) rrts::cramRgb(rrts::cramWord(rows[size_t(r) * 320 + size_t(x)]), rgb);
					std::fwrite(rgb, 1, 3, o);
				}
			std::fclose(o);
		}
	}
	std::printf("pictures: %ld frames compared, %ld differ\n", picCompared, picBad);
	if (evBad) std::printf("the bank's colour by line differed in %ld frames\n", evBad);
	if (bad) {
		std::printf("FAIL: the picture differs in %d pixels, the first at (%d, %d)\n", bad, firstBadX, firstBadY);
		return 1;
	}
	std::printf("picture: the same, pixel for pixel\n");
	return errors ? 1 : 0;
}
