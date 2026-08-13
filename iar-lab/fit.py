#!/usr/bin/env python3
"""Will this picture survive the slot it is going into?

    python3 iar-lab/fit.py hero-wide ~/Desktop/new-shot.jpg
    python3 iar-lab/fit.py                       # list the slots

Every slot on the site crops with CSS object-fit:cover, so the browser throws
away whatever does not fit the shape of the box — and it does it differently on
a phone than on a laptop. This reproduces those boxes exactly and reports what
each one keeps, so the answer arrives before the picture is on the site rather
than after somebody spots a cut-off head.

It also writes a preview alongside the file: the picture with the crop at each
real screen shape drawn on it, plus the band where the headline lands.

See IMAGE-SPEC.md for the slots and the reasoning behind the rules.
"""
import os
import sys

from PIL import Image, ImageDraw

#  shape          the aspect the file itself should be
#  floor          smallest width x height worth shipping
#  boxes          the real boxes the CSS produces, as (label, w, h)
#  copy           where type lands, as (x0, x1, y0, y1) fractions, or None
SLOTS = {
    'hero-wide': dict(shape=16 / 9,  floor=(1600, 900),
                      boxes=[('laptop 1440x800', 1440, 800),
                             ('desktop 1920x1080', 1920, 1080),
                             ('short 1512x700', 1512, 700)],
                      copy=(.58, .93, .45, .92), crop_from='top'),
    'hero-tall': dict(shape=4 / 5,   floor=(1080, 1350),
                      boxes=[('iPhone SE 375x422', 375, 422),
                             ('iPhone Pro Max 430x393', 430, 393)],
                      copy=None, crop_from='top'),
    'door-wide': dict(shape=5 / 4,   floor=(1200, 960),
                      boxes=[('laptop panel 719x624', 719, 624)],
                      copy=(.05, .60, .55, .95), crop_from='center'),
    'door-tall': dict(shape=3 / 4,   floor=(1080, 1440),
                      boxes=[('phone panel 375x552', 375, 552)],
                      copy=(.05, .95, .55, .95), crop_from='center'),
    # A plate is cover-cropped hard on a wide screen either way, so its exact
    # aspect is not the binding constraint — where the baked lettering sits is.
    # Anything from 3:2 to 16:9 survives; the tolerance says so instead of
    # failing a 3:2 frame that in fact works.
    'plate':     dict(shape=16 / 9,  floor=(1920, 1080), tol=20,
                      boxes=[('laptop 1440x592', 1440, 592),
                             ('desktop 1920x790', 1920, 790),
                             ('phone, shown whole', None, None)],
                      copy=None, crop_from='center'),
    'journal':   dict(shape=4 / 5,   floor=(660, 825),
                      boxes=[('rail card, laptop 320x400', 320, 400),
                             ('rail card, phone 224x280', 224, 280)],
                      copy=None, crop_from='center'),
    'square':    dict(shape=1.0,     floor=(1200, 1200),
                      boxes=[('beside the copy 700x700', 700, 700)],
                      copy=None, crop_from='center'),
}


def cover(iw, ih, bw, bh, crop_from):
    """What object-fit:cover keeps, as fractions of the original."""
    scale = max(bw / iw, bh / ih)
    kw, kh = bw / scale / iw, bh / scale / ih          # kept, as a fraction
    if crop_from == 'top':
        top = 0.0
    else:
        top = (1 - kh) / 2
    left = (1 - kw) / 2
    return left, left + kw, top, top + kh


def main():
    if len(sys.argv) < 3:
        print(__doc__)
        print('slots: ' + ', '.join(SLOTS))
        return 1

    name, path = sys.argv[1], sys.argv[2]
    if name not in SLOTS:
        print('no such slot: %s\nslots: %s' % (name, ', '.join(SLOTS)))
        return 1
    s = SLOTS[name]

    im = Image.open(path).convert('RGB')
    w, h = im.size
    ar = w / h
    off = (ar - s['shape']) / s['shape'] * 100

    print('\n%s   %d x %d   aspect %.3f' % (os.path.basename(path), w, h, ar))
    print('slot %-10s wants %.3f  (%s)' % (name, s['shape'], 'x'.join(map(str, s['floor']))))

    tol = s.get('tol', 1.5)
    bad = []
    if abs(off) <= tol:
        print('  shape    ok, within %g%% of the slot' % tol)
    else:
        which = 'wide' if off > 0 else 'tall'
        print('  shape    OFF by %.1f%% — the file is too %s' % (abs(off), which))
        if off > 0:
            print('           crop to %d x %d, or %d x %d'
                  % (round(h * s['shape']), h, w, round(w / s['shape'])))
        else:
            print('           crop to %d x %d, or %d x %d'
                  % (w, round(w / s['shape']), round(h * s['shape']), h))
        bad.append('shape')

    fw, fh = s['floor']
    if w >= fw and h >= fh:
        print('  size     ok (%dx%d, floor is %dx%d)' % (w, h, fw, fh))
    else:
        print('  size     TOO SMALL — %dx%d against a floor of %dx%d' % (w, h, fw, fh))
        bad.append('size')

    print('  what each screen keeps:')
    for label, bw, bh in s['boxes']:
        if bw is None:
            print('    %-26s the whole picture, nothing cut' % label)
            continue
        x0, x1, y0, y1 = cover(w, h, bw, bh, s['crop_from'])
        lost = []
        if x1 - x0 < .995:
            lost.append('%.0f%% off the sides' % ((1 - (x1 - x0)) * 100))
        if y1 - y0 < .995:
            edge = 'foot' if s['crop_from'] == 'top' else 'top and foot'
            lost.append('%.0f%% off the %s' % ((1 - (y1 - y0)) * 100, edge))
        print('    %-26s %s' % (label, ', '.join(lost) if lost else 'nothing cut'))

    if s['copy']:
        cx0, cx1, cy0, cy1 = s['copy']
        print('  the type lands at %.0f–%.0f%% across, %.0f–%.0f%% down.'
              % (cx0 * 100, cx1 * 100, cy0 * 100, cy1 * 100))
        print('  Nobody\'s face should be in that band.')

    prev = draw(im, s, name)
    out = os.path.splitext(path)[0] + '-fit.jpg'
    prev.save(out, quality=90)
    print('\n  preview: %s' % out)
    print('  %s\n' % ('PASSES' if not bad else 'FIX: ' + ', '.join(bad)))
    return 0 if not bad else 1


def draw(im, s, name):
    W = 1100
    p = im.resize((W, round(im.height * W / im.width)))
    d = ImageDraw.Draw(p, 'RGBA')
    H = p.height

    for i, (label, bw, bh) in enumerate(s['boxes']):
        if bw is None:
            continue
        x0, x1, y0, y1 = cover(im.width, im.height, bw, bh, s['crop_from'])
        col = [(255, 90, 60), (90, 200, 255), (255, 210, 60)][i % 3]
        d.rectangle([x0 * W, y0 * H, x1 * W - 1, y1 * H - 1], outline=col, width=3)
        d.text((x0 * W + 8, y0 * H + 8), label, fill=col)

    if s['copy']:
        cx0, cx1, cy0, cy1 = s['copy']
        d.rectangle([cx0 * W, cy0 * H, cx1 * W, cy1 * H], fill=(0, 0, 0, 90),
                    outline=(255, 255, 255, 200), width=2)
        d.text((cx0 * W + 10, cy0 * H + 10), 'the type goes here', fill=(255, 255, 255))

    d.line([(0, .10 * H), (W, .10 * H)], fill=(120, 255, 120), width=2)
    d.text((10, .10 * H + 6), 'keep the head below this line', fill=(120, 255, 120))
    return p


if __name__ == '__main__':
    sys.exit(main())
