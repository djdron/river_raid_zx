#!/usr/bin/env python3
# The time of nxcheck's histogram (NXHISTALL or NXHISTAPPLY) per label, local ones too
# (display.rows, display.rows_done, ...): where inside a routine the time goes.
#   tools/prof_local.py build/test.sym HIST FRAMES [ROUTINE...]
# Prints ticks per frame for every label (the nearest at or below each address) of the
# routines named (all if none), largest first.
import bisect
import re
import sys

sym, hist, frames = sys.argv[1], sys.argv[2], int(sys.argv[3])
only = sys.argv[4:]
labels = []
for line in open(sym):
    m = re.match(r'(\S+): EQU 0x([0-9A-Fa-f]+)', line)
    if m:
        labels.append((int(m.group(2), 16), m.group(1)))
labels.sort()
keys = [a for a, _ in labels]
total = {}
for line in open(hist):
    a, t = line.split()
    a = int(a, 16)
    i = bisect.bisect_right(keys, a) - 1
    if i < 0:
        continue
    name = labels[i][1]
    if only and name.split('.')[0] not in only:
        continue
    total[name] = total.get(name, 0) + int(t)
for name, t in sorted(total.items(), key=lambda x: -x[1]):
    print(f'{t / frames:10.0f}  {name}')
print(f'{sum(total.values()) / frames:10.0f}  (all)')
