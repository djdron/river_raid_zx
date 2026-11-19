// The TS-Conf's colours: an Atari colour code's CRAM word (mkpalette_ts) and what the board
// shows for a CRAM word (tscheck), at the VDAC's levels (0-24 a channel, bit 15 clear).
#pragma once

#include <cmath>
#include <cstdint>

#include "palette.h"

namespace rrts {

inline int level(uint8_t c) { return int(std::lround(c * 24.0 / 255.0)); }

inline uint16_t cramWord(uint8_t atari) {
	uint8_t rgb[3];
	rr::atariRgb(atari, rgb, true);
	return uint16_t(level(rgb[0]) << 10 | level(rgb[1]) << 5 | level(rgb[2]));
}

// the levels as Xpeccy's TSConf core shows them (tslCoLevs)
inline uint8_t shown(int v) {
	static const uint8_t lev[32] = {0, 11, 21, 32, 42, 53, 64, 74, 85, 95, 106, 117, 127, 138, 148, 159,
		170, 180, 191, 201, 212, 223, 233, 244, 255, 255, 255, 255, 255, 255, 255, 255};
	return lev[v & 31];
}

inline void cramRgb(uint16_t w, uint8_t rgb[3]) {
	rgb[0] = shown(w >> 10);
	rgb[1] = shown(w >> 5);
	rgb[2] = shown(w);
}

}  // namespace rrts
