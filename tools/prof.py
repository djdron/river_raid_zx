# Time per routine over one frame: python3 tools/prof.py build/sym.txt build/hist.txt
import bisect, collections, re, sys
syms = []
for l in open(sys.argv[1]):
    m = re.match(r'(\S+): EQU 0x([0-9A-F]+)', l)
    if m and '.' not in m.group(1):
        syms.append((int(m.group(2), 16), m.group(1)))
syms.sort()
keys = [a for a, _ in syms]
agg = collections.Counter()
total = 0
for l in open(sys.argv[2]):
    a, t = l.split()
    a, t = int(a, 16), int(t)
    total += t
    i = bisect.bisect_right(keys, a) - 1
    agg[syms[i][1] if i >= 0 else '?'] += t
print('total', total)
for k, v in agg.most_common(int(sys.argv[3]) if len(sys.argv) > 3 else 20):
    print(f'{k:24s}{v:9d} {100 * v / total:5.1f}%')
