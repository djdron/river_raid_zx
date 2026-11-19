// POKEY's RANDOM counter as river_raid/port/src/pokey_random.h models it: 17 bits, one step
// per machine cycle; a read returns its top 8 bits. The game logic reads it at A205, on
// scanline 192 at cycle 13 (NTSC; 191 at 24 on PAL, as the C++ port's game takes it), so the
// Next keeps the counter at that point of the frame and moves it one frame on in each VBI: a
// linear map over the 17 bits.
#pragma once

#include <cstdint>

namespace rrzx {

constexpr long kFrameCycles = 262 * 114;                // NTSC
constexpr long kReadCycle = 192 * 114 + 13;              // A205 in its frame
constexpr long kPalFrameCycles = 312 * 114;             // PAL
constexpr long kPalReadCycle = 191 * 114 + 24;

inline uint32_t pokeyStep(uint32_t s) { return (s >> 1) | (((s ^ (s >> 5)) & 1) << 16); }

inline uint32_t pokeyAdvance(uint32_t s, long steps) {
	for (long i = 0; i < steps; i++) s = pokeyStep(s);
	return s;
}

// The counter at the first read: rr::PokeyRandom(seed) one frame on (frame 0 is the attract
// mode's start, frame 1 its first logic, when the frame counter is 0).
inline uint32_t pokeyFirstRead(uint32_t seed, bool pal = false) {
	seed %= 0x1FFFF;
	return pokeyAdvance(seed ? seed : 1, pal ? kPalFrameCycles + kPalReadCycle : kFrameCycles + kReadCycle);
}

}  // namespace rrzx
