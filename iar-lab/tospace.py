#!/usr/bin/env python3
"""Snap every spacing declaration onto the scale in iar-house.css.

    python3 iar-lab/tospace.py --dry            # show what would change
    python3 iar-lab/tospace.py index.html       # apply to one file
    python3 iar-lab/tospace.py --all            # apply to every html and css

Each length is replaced by its NEAREST step, so the sweep is a tidy-up rather
than a redesign — nothing moves more than half a step, and two values that were
1px apart end up identical, which is the whole point.

Deliberately left alone:
  em units    those are tied to the type, not to the page rhythm. `.claim{gap:.1em}`
              and `.prose p{margin:0 0 1.15em}` are leading, and snapping them to
              a pixel step would change the typography rather than the spacing.
  calc(...)   replacing a length inside an expression changes the arithmetic
  inset       that is positioning, not rhythm
  negatives   pulling a block up is a specific trick, not a spacing choice
  0, auto, %  not spacing decisions
"""
import glob
import os
import re
import sys

# px value of each step, and the token to write
STEPS = [(4, 'var(--s0)'), (8, 'var(--s1)'), (12, 'var(--s2)'), (16, 'var(--s3)'),
         (24, 'var(--s4)'), (32, 'var(--s5)'), (48, 'var(--s6)')]
# the two fluid steps, at what they grow to. A section padding of 6rem is not a
# 48px decision that someone typed badly — it is a big-screen decision, and the
# only honest home for it is a step that still gives the phone something smaller.
FLUID = [(64, 'var(--sy)'), (96, 'var(--sz)')]
# so a bare length can reach the fluid steps too, not just a clamp()
ALL = STEPS + FLUID

PROP = (r'\b(padding|margin|gap|row-gap|column-gap|padding-block|padding-inline|'
        r'padding-top|padding-bottom|padding-left|padding-right|margin-top|'
        r'margin-bottom|margin-left|margin-right|margin-block|margin-inline)'
        r'(\s*:\s*)([^;}"]+)')
LEN = re.compile(r'(?<![\w.-])(\d*\.?\d+)(rem|px)(?![\w-])')
CLAMP = re.compile(r'clamp\(([^()]*)\)')
FREE = {'0', '0px', 'auto', '100%', '1px'}


def px(n, unit):
    return float(n) * (16.0 if unit == 'rem' else 1.0)


def nearest(p, table=STEPS):
    return min(table, key=lambda s: abs(s[0] - p))[1]


def swap_clamp(m):
    """A clamp() is a section rhythm — pick a step from what it grows to."""
    parts = [x.strip() for x in m.group(1).split(',')]
    if len(parts) != 3:
        return m.group(0)
    hit = LEN.fullmatch(parts[-1])
    if not hit:
        return m.group(0)
    top = px(hit.group(1), hit.group(2))
    return nearest(top, ALL if top < 40 else FLUID)


def swap_len(m):
    return nearest(px(m.group(1), m.group(2)), ALL)


def fix_value(val):
    if 'calc(' in val:
        return val
    out = CLAMP.sub(swap_clamp, val)
    parts = []
    for tok in re.split(r'(\s+)', out):
        t = tok.strip()
        if not t or t in FREE or t.startswith('var(') or t.startswith('-'):
            parts.append(tok)
            continue
        parts.append(LEN.sub(swap_len, tok))
    return ''.join(parts)


def run(path, dry):
    s = open(path).read()
    changes = []

    def rep(m):
        prop, sep, val = m.group(1), m.group(2), m.group(3)
        new = fix_value(val)
        if new != val:
            changes.append((prop, val.strip(), new.strip()))
        return prop + sep + new

    out = re.sub(PROP, rep, s)
    if not dry and changes:
        open(path, 'w').write(out)
    return changes


def main():
    args = [a for a in sys.argv[1:] if not a.startswith('--')]
    dry = '--dry' in sys.argv
    targets = args or (sorted(glob.glob('*.html')) + sorted(glob.glob('assets/*.css')))
    total = 0
    for f in targets:
        if not os.path.exists(f):
            continue
        ch = run(f, dry)
        total += len(ch)
        if ch:
            print('%-32s %3d' % (f, len(ch)))
            if dry:
                for prop, a, b in ch[:3]:
                    print('      %-14s %-34s -> %s' % (prop, a[:34], b[:34]))
    print('\n%s %d declarations across %d files'
          % ('would change' if dry else 'changed', total, len(targets)))
    return 0


if __name__ == '__main__':
    sys.exit(main())
