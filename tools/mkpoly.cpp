// Writes POKEY's noise for the sound (sound.asm): the output bits of its polynomial counters at
// the 64 kHz clock's ticks, which come every 28 machine cycles. The counters advance every
// cycle, so tick k sees bit 28k of each sequence (the C++ port's PokeySound, polySequence).
//   <out.bin>: the 17-bit counter, 131071 bits, bit k at byte k / 8, bit k % 8, then one more
//              (bit 0 again) to fill 16384 bytes;
//   <out.inc>: the 5-bit (31) and 4-bit (15) ones, a byte (0 or 1) each, 64 bytes apart.
//
// usage: mkpoly <out.bin> <out.inc>
#include <cstdint>
#include <cstdio>
#include <vector>

static std::vector<uint8_t> polySequence(uint32_t start, uint32_t mask, int tap1, int tap2) {
	std::vector<uint8_t> bits;
	uint32_t p = start;
	do {
		bits.push_back(uint8_t(p & 1));
		p = ((p << 1) | (((p >> tap1) ^ (p >> tap2)) & 1)) & mask;
	} while (p != start);
	return bits;
}

static std::vector<uint8_t> atTicks(const std::vector<uint8_t> &s) {
	std::vector<uint8_t> q(s.size());
	for (size_t k = 0; k < s.size(); k++) q[k] = s[(28 * k) % s.size()];
	return q;
}

int main(int argc, char **argv) {
	if (argc < 3) {
		std::fprintf(stderr, "usage: %s <out.bin> <out.inc>\n", argv[0]);
		return 2;
	}
	const auto q17 = atTicks(polySequence(0x1FFFF, 0x1FFFF, 16, 11));
	const auto q5 = atTicks(polySequence(0x1F, 0x1F, 4, 2));
	const auto q4 = atTicks(polySequence(0x0F, 0x0F, 3, 2));
	if (q17.size() != 131071 || q5.size() != 31 || q4.size() != 15) {
		std::fprintf(stderr, "unexpected sequence lengths\n");
		return 1;
	}
	std::vector<uint8_t> bin(16384, 0);
	for (size_t k = 0; k <= q17.size(); k++)
		if (q17[k % q17.size()]) bin[k / 8] |= uint8_t(1 << (k % 8));
	FILE *f = std::fopen(argv[1], "wb");
	if (!f || std::fwrite(bin.data(), 1, bin.size(), f) != bin.size()) {
		std::fprintf(stderr, "cannot write %s\n", argv[1]);
		return 1;
	}
	std::fclose(f);
	f = std::fopen(argv[2], "w");
	if (!f) {
		std::fprintf(stderr, "cannot write %s\n", argv[2]);
		return 1;
	}
	std::fprintf(f, "; POKEY's 4-bit and 5-bit polynomial counters at the 64 kHz ticks (tick k: bit 28k),\n"
		"; a byte each, 64 bytes apart. Made by tools/mkpoly.\n");
	auto put = [&](const char *name, const std::vector<uint8_t> &q) {
		std::fprintf(f, "%s\n\tdb ", name);
		for (size_t k = 0; k < q.size(); k++) std::fprintf(f, "%s%d", k ? "," : "", q[k]);
		std::fprintf(f, "\n");
	};
	put("poly5:", q5);
	std::fprintf(f, "\tds 64 - 31\n");
	put("poly4:", q4);
	std::fprintf(f, "\tds 64 - 15\n");
	std::fclose(f);
	return 0;
}
