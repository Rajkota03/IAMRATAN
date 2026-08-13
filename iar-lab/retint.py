#!/usr/bin/env python3
"""Retint the wall behind the figure to a tonal version of the garment.

Tests the alternative to one neutral room: give each cloth a wall in its own
hue, desaturated and lifted, so the frame is tonal rather than neutral.

The wall is selected by colour, not by position. It is a warm, LOW-SATURATION
field; skin sits at roughly the same hue but far higher saturation, so a
saturation gate separates them cleanly — measured on these frames the wall runs
about 12% and skin about 32%.

    tonal_wall('#2B3B59') -> the garment's hue, held at low saturation and
                             high value, so it always clears the garment on
                             luminance while staying in the same family.
"""

import colorsys
import sys

import numpy as np
from PIL import Image

WALL_SAT_MAX = 0.22     # above this it is skin, not wall
TONAL_SAT = 0.13        # how much colour the retinted wall carries
TONAL_VAL = 0.87        # how light it sits


def tonal_wall(garment_hex, sat=TONAL_SAT, val=TONAL_VAL):
    """The garment's own hue, desaturated and lifted, as a wall colour."""
    c = [int(garment_hex[i:i + 2], 16) / 255 for i in (1, 3, 5)]
    h, _, _ = colorsys.rgb_to_hsv(*c)
    r, g, b = colorsys.hsv_to_rgb(h, sat, val)
    return "#%02X%02X%02X" % (int(r * 255), int(g * 255), int(b * 255))


def wall_mask(a, wall_rgb):
    """Select the wall: near the wall's chromaticity AND low saturation."""
    s = a.sum(axis=-1, keepdims=True)
    ch = a / np.maximum(s, 1e-6)
    wch = wall_rgb / max(wall_rgb.sum(), 1e-6)
    d = np.linalg.norm(ch - wch[None, None, :], axis=-1)

    mx = a.max(axis=2)
    mn = a.min(axis=2)
    sat = np.where(mx > 0, (mx - mn) / np.maximum(mx, 1e-6), 0)

    near = np.clip((0.030 - d) / 0.018, 0, 1)
    calm = np.clip((WALL_SAT_MAX - sat) / 0.07, 0, 1)
    w = near * calm
    return (w * w * (3 - 2 * w))[..., None]


def retint(src, dst, wall_box, target_hex):
    a = np.asarray(Image.open(src).convert("RGB"), float) / 255.0
    H, W, _ = a.shape
    x0, y0, x1, y1 = wall_box
    have = np.median(
        a[int(y0 * H):int(y1 * H), int(x0 * W):int(x1 * W)].reshape(-1, 3), axis=0
    )
    tgt = np.array([int(target_hex[i:i + 2], 16) for i in (1, 3, 5)], float) / 255.0
    gain = tgt / np.maximum(have, 1e-3)

    w = wall_mask(a, have)
    out = a * (gain[None, None, :] * w + 1.0 * (1 - w))
    Image.fromarray((np.clip(out, 0, 1) * 255).astype("uint8")).save(dst)
    return have * 255, w.mean()


if __name__ == "__main__":
    print(tonal_wall(sys.argv[1] if len(sys.argv) > 1 else "#2B3B59"))
