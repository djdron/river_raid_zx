// The Atari's colours on the Next: each colour code (hue << 4 | luminance) as the 8-bit
// colour nextreg $41 takes (RRRGGGBB; the Next makes the 9th bit, blue's lowest, from the
// other two), from the C++ port's palette model (PAL, Altirra's model: the port's default).
// The Copper sets colours this way, one register write each.
#pragma once

#include <cstdint>

#include "palette.h"

namespace rrzx {

// Global transparency of the Next (nextreg $14): Layer 2 does not draw this colour, so the
// palette never makes it.
constexpr uint8_t kTransparent = 0xE3;

inline int to3(uint8_t c) { return (c * 7 + 127) / 255; }

// RRRGGGBB as nextreg $41 takes it
inline uint8_t nextColour8(uint8_t code) {
	uint8_t rgb[3];
	rr::atariRgb(code, rgb, true, rr::PaletteModel::Altirra);
	const int r = to3(rgb[0]), g = to3(rgb[1]), b = to3(rgb[2]);
	uint8_t c = uint8_t((r << 5) | (g << 2) | (b >> 1));
	if (c == kTransparent) c ^= 1;   // one step of blue off the transparent colour
	return c;
}

// The 9-bit colour (RRRGGGBBB) the Next shows for it
inline uint16_t nextColour(uint8_t code) {
	const uint8_t c = nextColour8(code);
	return uint16_t((c << 1) | (((c >> 1) | c) & 1));
}

// 8-bit RGB of a 9-bit colour, as the Next's video output (and Xpeccy+) makes it
inline void nextRgb(uint16_t c, uint8_t rgb[3]) {
	rgb[0] = uint8_t(((c >> 6) * 255 + 3) / 7);
	rgb[1] = uint8_t((((c >> 3) & 7) * 255 + 3) / 7);
	rgb[2] = uint8_t(((c & 7) * 255 + 3) / 7);
}

}  // namespace rrzx
