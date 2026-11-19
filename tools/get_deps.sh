#!/bin/sh
# Fetches and builds what the build and the checks need, into deps/:
#   sjasmplus     the assembler
#   river_raid    the C++ port: the reference the checks compare with, and the palette model
#   xpeccy-plus   the emulator whose ZX Spectrum Next core runs the checks (no window, no Qt)
# Each at the commit it was tried with. Needs git, a C/C++ compiler, make, cmake and zlib.
set -e
cd "$(dirname "$0")/.."
mkdir -p deps

fetch() {   # name url commit
	if [ ! -d "deps/$1/.git" ]; then
		git init -q "deps/$1"
		git -C "deps/$1" remote add origin "$2"
	fi
	if [ "$(git -C "deps/$1" rev-parse -q --verify HEAD 2>/dev/null)" != "$3" ]; then
		git -C "deps/$1" fetch -q --depth 1 origin "$3"
		git -C "deps/$1" checkout -q FETCH_HEAD
		git -C "deps/$1" submodule -q update --init --depth 1 --recursive
	fi
}

fetch sjasmplus https://github.com/z00m128/sjasmplus 5c44beafc76d541091e59ced98048c2367d32935
fetch river_raid https://github.com/djdron/river_raid 85bd254953bc15b1313d87310a0d19ec496afc66   # branch dli_removed
fetch xpeccy-plus https://github.com/dotkoval/xpeccy-plus 0ec06e33d891a0598cf68b061d20ba2d440d1fcf

if [ ! -x deps/sjasmplus/sjasmplus ]; then
	make -C deps/sjasmplus -j4 >/dev/null
fi
echo "deps ready"
