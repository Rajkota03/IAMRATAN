#!/usr/bin/env python3
"""Bring a frame into the house colour, without touching anything else.

Frames arrive at slightly different saturation and density depending on which
generation produced them. Left alone, five frames of one shirt disagree with
each other and with the swatch on the shop page.

The correction is deliberately narrow: saturation and value only, weighted by
luminance. Hue is never moved, and nothing structural is touched.

A flat global desaturation cannot do this job. Sized to fix the cloth it takes
skin down with it — measured on the first frame, the cloth needed S x0.57 while
the skin only needed x0.85, and applying x0.57 everywhere left the hand grey.
So the dark band and the light band are corrected separately and blended across
a soft luminance ramp, which keeps the mid-tones from banding.

    ./iar-lab/grade.py in.png out.png [--dark-sat 0.57] [--dark-val 1.20]
                                      [--light-sat 0.85]
"""

import colorsys
import sys

import numpy as np
from PIL import Image

# Where the cloth ends and skin/ground begin, in HSV value. The ramp between
# them is what stops the correction showing as an edge.
CLOTH_TOP = 0.25
GROUND_BOTTOM = 0.45


def grade(src, dst, dark_sat=0.57, dark_val=1.20, light_sat=0.85):
    im = Image.open(src).convert("RGB")
    a = np.asarray(im, float) / 255.0

    r, g, b = a[..., 0], a[..., 1], a[..., 2]
    mx, mn = a.max(axis=2), a.min(axis=2)
    v = mx
    d = mx - mn
    s = np.where(mx > 0, d / np.maximum(mx, 1e-6), 0)

    # hue, kept exactly as found
    h = np.zeros_like(v)
    nz = d > 1e-6
    rm = nz & (mx == r)
    gm = nz & (mx == g) & ~rm
    bm = nz & (mx == b) & ~rm & ~gm
    h[rm] = ((g - b)[rm] / d[rm]) % 6
    h[gm] = ((b - r)[gm] / d[gm]) + 2
    h[bm] = ((r - g)[bm] / d[bm]) + 4
    h = h / 6.0

    # smooth ramp: 1 across the cloth, 0 across skin and ground
    t = np.clip((v - CLOTH_TOP) / (GROUND_BOTTOM - CLOTH_TOP), 0, 1)
    w = 1 - (t * t * (3 - 2 * t))          # smoothstep

    s = s * (dark_sat * w + light_sat * (1 - w))
    v = np.clip(v * (dark_val * w + 1.0 * (1 - w)), 0, 1)

    i = np.floor(h * 6).astype(int) % 6
    f = h * 6 - np.floor(h * 6)
    p, q, tt = v * (1 - s), v * (1 - f * s), v * (1 - (1 - f) * s)
    # conditions carry a trailing axis so they broadcast against the RGB stacks
    out = np.select(
        [(i == k)[..., None] for k in range(6)],
        [np.stack([v, tt, p], -1), np.stack([q, v, p], -1), np.stack([p, v, tt], -1),
         np.stack([p, q, v], -1), np.stack([tt, p, v], -1), np.stack([v, p, q], -1)],
    )
    Image.fromarray((np.clip(out, 0, 1) * 255).astype("uint8")).save(dst)
    return dst


def report(path, boxes):
    a = np.asarray(Image.open(path).convert("RGB"), float)
    H, W, _ = a.shape
    for lbl, (x0, y0, x1, y1) in boxes.items():
        c = np.median(a[int(y0 * H):int(y1 * H), int(x0 * W):int(x1 * W)].reshape(-1, 3), axis=0)
        hh, ss, vv = colorsys.rgb_to_hsv(*[x / 255 for x in c])
        print("  %-16s #%02X%02X%02X   H%6.1f  S%5.1f  V%5.1f"
              % (lbl, int(c[0]), int(c[1]), int(c[2]), hh * 360, ss * 100, vv * 100))


def median_rgb(path, box):
    a = np.asarray(Image.open(path).convert("RGB"), float)
    H, W, _ = a.shape
    x0, y0, x1, y1 = box
    r = a[int(y0 * H):int(y1 * H), int(x0 * W):int(x1 * W)].reshape(-1, 3)
    return np.median(r, axis=0)


def chroma(a):
    """Colour without brightness — r,g as fractions of total."""
    s = a.sum(axis=-1, keepdims=True)
    return a / np.maximum(s, 1e-6)


def protect_mask(shape, ellipses, feather=0.02):
    """Regions the grade must never touch, as normalised ellipses.

    Colour alone cannot protect the face. A near-neutral cloth like charcoal
    sits close to neutral in chromaticity — and so do the bright, desaturated
    highlights on a forehead and a nose bridge. Classifying against a skin
    sample does not help either: those highlight pixels really are closer to
    charcoal than to average skin, so the test never fires. Grading charcoal
    put grey blotches across the model's face twice before this was accepted.

    What does work is geometry. Every frame in the range derives from the same
    master photograph, so his head sits in the same place in all of them, and a
    region defined once is correct for all twenty-five.
    """
    H, W = shape
    ys, xs = np.mgrid[0:H, 0:W]
    x = xs / W
    y = ys / H
    keep = np.ones((H, W), float)
    for cx, cy, rx, ry in ellipses:
        d = np.sqrt(((x - cx) / rx) ** 2 + ((y - cy) / ry) ** 2)
        keep = np.minimum(keep, np.clip((d - 1.0) / (feather / min(rx, ry)), 0, 1))
    return keep[..., None]


def cloth_mask(a, cloth, tol=0.055, soft=0.030):
    """Select the garment by COLOUR, not by brightness.

    An earlier version keyed off luminance with a fixed dark/light split. That
    worked on charcoal and failed silently on everything else: mid-tone Cobalt
    and pale Ratan's Blue both fell outside the 'dark' band, the correction
    weight came out zero, and the grade wrote the file unchanged. A no-op that
    reports success is worse than a crash.

    Chromaticity is the right key. It ignores how brightly a patch is lit, so a
    shirt's highlights and its shadows read as the same cloth, while the warm
    wall and warm skin stay clearly apart from a blue or neutral garment. It
    also generalises to the warm cloths in the range, which luminance never
    could.
    """
    d = np.linalg.norm(chroma(a) - chroma(cloth[None, None, :]), axis=-1)
    t = np.clip((d - tol) / soft, 0, 1)
    return (1 - (t * t * (3 - 2 * t)))[..., None]


def to_cloth(src, dst, box, target_hex, light_sat=1.0, tol=0.055, protect=None):
    """Land the cloth on an exact hex, leaving skin and ground alone.

    Per-channel rather than HSV, because the target differs from the render in
    hue as well as in saturation and value, and a single HSV gain cannot correct
    all three at once.

    Pass `protect` on any frame containing the model — a list of normalised
    (cx, cy, rx, ry) ellipses covering his head and hands.
    """
    tgt = np.array([int(target_hex[i:i + 2], 16) for i in (1, 3, 5)], float)
    have = median_rgb(src, box)
    gain = tgt / np.maximum(have, 1.0)

    a = np.asarray(Image.open(src).convert("RGB"), float) / 255.0
    w = cloth_mask(a, have / 255.0, tol=tol)
    if protect:
        w = w * protect_mask(a.shape[:2], protect)

    out = a * (gain[None, None, :] * w + 1.0 * (1 - w))

    if light_sat != 1.0:
        mx = out.max(axis=2, keepdims=True)
        out = np.where(w < 0.5, mx + (out - mx) * light_sat, out)

    Image.fromarray((np.clip(out, 0, 1) * 255).astype("uint8")).save(dst)
    return have, gain, float(w.mean())


if __name__ == "__main__":
    if len(sys.argv) < 3:
        sys.exit(__doc__)
    kw = {}
    args = sys.argv[3:]
    for i in range(0, len(args) - 1, 2):
        kw[args[i].lstrip("-").replace("-", "_")] = float(args[i + 1])
    grade(sys.argv[1], sys.argv[2], **{k: v for k, v in kw.items()})
    print("wrote %s" % sys.argv[2])
