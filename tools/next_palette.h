// The Atari's colours on the Next: each colour code (hue << 4 | luminance) as a 9-bit
// RGB333 colour, from the C++ port's palette model (PAL, Altirra's model: the port's default).
#pragma once

#include <cstdint>

#include "palette.h"

namespace rrzx {

// Global transparency of the Next (nextreg $14): a colour whose top 8 bits are this is not
// drawn, so the palette never makes it.
constexpr uint8_t kTransparent = 0xE3;

inline int to3(uint8_t c) { return (c * 7 + 127) / 255; }

// RRRGGGBBB
inline uint16_t nextColour(uint8_t code) {
	uint8_t rgb[3];
	rr::atariRgb(code, rgb, true, rr::PaletteModel::Altirra);
	int r = to3(rgb[0]), g = to3(rgb[1]), b = to3(rgb[2]);
	uint16_t c = uint16_t((r << 6) | (g << 3) | b);
	if ((c >> 1) == kTransparent) c ^= 2;   // one step of blue off the transparent colour
	return c;
}

// 8-bit RGB of a 9-bit colour, as the Next's video output (and Xpeccy+) makes it
inline void nextRgb(uint16_t c, uint8_t rgb[3]) {
	rgb[0] = uint8_t(((c >> 6) * 255 + 3) / 7);
	rgb[1] = uint8_t((((c >> 3) & 7) * 255 + 3) / 7);
	rgb[2] = uint8_t(((c & 7) * 255 + 3) / 7);
}

}  // namespace rrzx
