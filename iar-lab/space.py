#!/usr/bin/env python3
"""What spacing is the site actually using, and how much of it is off the scale?

    python3 iar-lab/space.py                 # audit everything
    python3 iar-lab/space.py bespoke-2.html  # audit one file

The site had 144 distinct padding/margin/gap values, 84 of them one-off clamp()
expressions written at the point of use. That is the reason spacing never felt
settled: fixing one block could not make the next one agree, because there was
nothing for them to agree ON.

iar-house.css now defines nine steps (--s0..--s6, --sy, --sz). This reports
every declaration that does not use one, worst file first, so the sweep can be
done in the order that buys the most.
"""
import collections
import glob
import os
import re
import sys

PROP = (r'\b(padding|margin|gap|row-gap|column-gap|padding-block|padding-inline|'
        r'padding-top|padding-bottom|padding-left|padding-right|'
        r'margin-top|margin-bottom|margin-left|margin-right|margin-block|'
        r'margin-inline|inset)\s*:\s*([^;}"]+)')
TOKEN = re.compile(r'clamp\([^)]*\)|-?[\d.]+rem|-?[\d.]+px|-?[\d.]+em')
ON_SCALE = re.compile(r'var\(--s[0-6yz]\)|var\(--gut\)|var\(--bar\)|var\(--clear\)')
# 0, 1px hairlines and 100%/auto are not spacing decisions
DELIBERATE = re.compile(r'\d*\.?\d+em\b')   # leading, tied to the type
FREE = {'0', '0px', '1px', 'auto', '100%'}


def audit(path):
    """Returns (on-scale, off-scale, deliberate).

    Deliberate is not a smaller kind of failure — an em is leading and belongs to
    the type, and an inset is where a box sits rather than how much air it has.
    Snapping either onto the spacing scale would be the bug. Counting them apart
    is what lets the off-scale number honestly reach zero."""
    s = open(path).read()
    off, ok, meant = [], 0, 0
    for prop, val in re.findall(PROP, s):
        if ON_SCALE.search(val):
            ok += 1
            continue
        toks = [t for t in TOKEN.findall(val) if t not in FREE]
        if not toks:
            ok += 1
            continue
        if prop == 'inset' or DELIBERATE.search(val):
            meant += 1
            continue
        off.append((prop, val.strip()[:56]))
    return ok, off, meant


def main():
    targets = sys.argv[1:] or (sorted(glob.glob('*.html')) +
                               sorted(glob.glob('assets/*.css')))
    rows, every = [], collections.Counter()
    for f in targets:
        if not os.path.exists(f):
            print('no such file:', f)
            continue
        ok, off, meant = audit(f)
        rows.append((len(off), ok, meant, f))
        for prop, val in off:
            every[val] += 1

    rows.sort(reverse=True)
    print('\n%-34s %6s %6s %10s' % ('file', 'off', 'on', 'deliberate'))
    print('-' * 60)
    total_off = total_ok = total_meant = 0
    for off, ok, meant, f in rows:
        total_off += off
        total_ok += ok
        total_meant += meant
        if off or len(targets) == 1:
            print('%-34s %6d %6d %10d' % (f[:34], off, ok, meant))
    share = 100 * total_ok / max(total_ok + total_off, 1)
    print('-' * 60)
    print('%-34s %6d %6d %10d   %.0f%% on the scale'
          % ('TOTAL', total_off, total_ok, total_meant, share))

    if len(targets) == 1 and total_off:
        print('\nwhat is off, in this file:')
        _, off, _ = audit(targets[0])
        for prop, val in off:
            print('  %-16s %s' % (prop, val))
    elif every:
        print('\nthe ten most repeated off-scale values:')
        for v, n in every.most_common(10):
            print('  %-46s %3d' % (v[:46], n))
    return 0


if __name__ == '__main__':
    sys.exit(main())
