#!/usr/bin/env python3
# Writes build/river_raid.spg: Wild Commander's program file (SPG 1.0, as Xpeccy+'s loader
# reads it) from the pages the SPG build saved: build/spg_page2.bin ($8000-$9FFF, page 2),
# build/spg_page5.bin ($7C00-$7FFF, page 5: the font) and build/spg_page6.bin ($C000-$FFFF,
# page 6). The program starts at `start` (build/spg.sym), 14 MHz, interrupts off, the
# resident at $5B00; the cartridge it reads from the SD card itself.
#
# usage: mkspg.py <build dir> <out.spg>
import struct
import sys
import time


def symbol(path, name):
    for line in open(path):
        if line.startswith(name + ':'):
            return int(line.split('0x')[1].split()[0], 16)
    raise SystemExit('no symbol ' + name)


def main():
    build, out = sys.argv[1], sys.argv[2]
    blocks = [(2, 0x0000, open(build + '/spg_page2.bin', 'rb').read()),
              (5, 0x3C00, open(build + '/spg_page5.bin', 'rb').read()),
              (6, 0x0000, open(build + '/spg_page6.bin', 'rb').read())]
    start = symbol(build + '/spg.sym', 'start')
    sp = symbol(build + '/spg.sym', 'STACK_TOP')
    t = time.gmtime()
    head = bytearray(256)
    head[0:32] = b'River Raid (TS-Conf)'.ljust(32)
    head[0x20:0x2C] = b'SpectrumProg'
    head[0x2C] = 0x10                                  # SPG 1.0
    head[0x2D:0x30] = bytes([t.tm_mday, t.tm_mon, t.tm_year - 2000])
    struct.pack_into('<HH', head, 0x30, start, sp)
    head[0x34] = 6                                     # the page at $C000
    head[0x35] = 0x02                                  # 14 MHz, interrupts off
    # The resident: Wild Commander's loader copies a stub of 16 bytes there (it maps the
    # 48K ROM at $0000, then jumps to the start) and jumps to it from its own code at $0000:
    # it must be RAM out of window 0 that nothing loaded is in. $5B00, as spgbld's examples:
    # page 5, SPANS (made anew after the start).
    struct.pack_into('<H', head, 0x38, 0x5B00)
    struct.pack_into('<H', head, 0x3A, len(blocks))
    head[0x3C:0x3F] = bytes([t.tm_sec, t.tm_min, t.tm_hour])
    head[0x50:0x70] = b'river_raid_zx tsconf/tools/mkspg'.ljust(32)
    table = bytearray(768)
    data = bytearray()
    for i, (page, addr, blk) in enumerate(blocks):
        assert len(blk) % 512 == 0 and 0 < len(blk) <= 0x4000 and addr % 512 == 0
        table[3 * i] = (addr >> 9) | (0x80 if i == len(blocks) - 1 else 0)
        table[3 * i + 1] = len(blk) // 512 - 1          # (bits 7-6: not packed)
        table[3 * i + 2] = page
        data += blk
    open(out, 'wb').write(bytes(head) + bytes(table) + bytes(data))


main()
