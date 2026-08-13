#!/usr/bin/env python3
"""Lay the house signature onto a rendered cuff as tone-on-tone embroidery.

The generator can place a mark that reads right at page size but never draws
their actual artwork, and its proportions drift. So the generated mark is lifted
off and the real one — assets/mark-signature.png, the client's own file — is
composited in its place, at the measured size and angle:

    width  ~40% of the cuff's width
    tilt   +16 deg clockwise off the cuff's topstitched border
    place  upper-middle of the cuff face, above the buttonhole

Placement is defined in the cuff's own plane, so it follows the perspective of
whatever frame it is given rather than being pasted on flat.
"""

import sys

from PIL import Image, ImageChops, ImageDraw, ImageFilter

MARK = "assets/mark-signature.png"

# The cuff face as a quad in the source frame, corners clockwise from top-left.
# Read off a gridded preview; one entry per accepted cuff render.
QUADS = {
    "images/_gen/indigo-cuff-v4.png": [(484, 754), (1271, 906), (1215, 1345), (295, 1300)],
}

WIDTH_FRAC = 0.40   # of the cuff's width
TILT_DEG = 16.0     # clockwise off the cuff's border
CENTRE = (0.44, 0.25)   # in cuff-width units from the face's top-left


def coeffs(dst, src):
    """Perspective coefficients mapping output points back to input points."""
    import numpy as np

    m = []
    for (dx, dy), (sx, sy) in zip(dst, src):
        m.append([dx, dy, 1, 0, 0, 0, -sx * dx, -sx * dy])
        m.append([0, 0, 0, dx, dy, 1, -sy * dx, -sy * dy])
    a = np.array(m, dtype=float)
    b = np.array(src, dtype=float).reshape(8)
    return np.linalg.solve(a, b)


def place(quad):
    """Corners of the signature, mapped into the cuff plane."""
    import math

    tl, tr, br, bl = quad
    wid = math.hypot(tr[0] - tl[0], tr[1] - tl[1])
    hgt = math.hypot(bl[0] - tl[0], bl[1] - tl[1])
    hnorm = hgt / wid              # cuff height in cuff-width units

    m = Image.open(MARK)
    aspect = m.size[0] / m.size[1]
    w = WIDTH_FRAC
    h = w / aspect

    th = math.radians(TILT_DEG)
    out = []
    for dx, dy in ((-w / 2, -h / 2), (w / 2, -h / 2), (w / 2, h / 2), (-w / 2, h / 2)):
        rx = dx * math.cos(th) - dy * math.sin(th) + CENTRE[0]
        ry = dx * math.sin(th) + dy * math.cos(th) + CENTRE[1]
        u, v = rx, ry / hnorm       # back to normalised quad coords
        x = (1 - u) * (1 - v) * tl[0] + u * (1 - v) * tr[0] + u * v * br[0] + (1 - u) * v * bl[0]
        y = (1 - u) * (1 - v) * tl[1] + u * (1 - v) * tr[1] + u * v * br[1] + (1 - u) * v * bl[1]
        out.append((x, y))
    return out


def clear_old(im, corners, pad=70):
    """Lift the generated mark off the cloth.

    Only the strokes are replaced, never the whole patch. A grey dilation was
    tried first and bleached the entire region — MaxFilter takes the LIGHTEST
    pixel in its neighbourhood, which on dark charcoal lifts the cloth as much
    as it removes the mark, leaving a pale smear with the old mark ghosting
    through it.

    Instead the region is split into a low-frequency background (the cuff's own
    gradient, which must survive) and a high-frequency residual (weave plus
    embroidery). The embroidery is the part of the residual that is markedly
    DARKER than the cloth, so only those pixels are pushed back to the
    background, and the weave everywhere else is left untouched.
    """
    import numpy as np

    xs = [p[0] for p in corners]
    ys = [p[1] for p in corners]
    box = (int(min(xs)) - pad, int(min(ys)) - pad, int(max(xs)) + pad, int(max(ys)) + pad)
    box = (max(0, box[0]), max(0, box[1]), min(im.width, box[2]), min(im.height, box[3]))

    patch = im.crop(box)
    bg = patch.filter(ImageFilter.GaussianBlur(22))          # the cuff's gradient
    p = np.asarray(patch, float)
    b = np.asarray(bg, float)

    resid = p.mean(axis=2) - b.mean(axis=2)
    dark = resid < -2.5                                       # the stitched strokes
    strength = np.clip(-resid / 9.0, 0, 1)[..., None] * dark[..., None]

    out = p * (1 - strength) + b * strength
    healed = Image.fromarray(out.astype("uint8"))

    mask = Image.new("L", patch.size, 0)
    ImageDraw.Draw(mask).polygon([(x - box[0], y - box[1]) for x, y in corners], fill=255)
    mask = mask.filter(ImageFilter.MaxFilter(9)).filter(ImageFilter.GaussianBlur(14))

    patch.paste(healed, (0, 0), mask)
    im.paste(patch, box)
    return im


def emboss(im, corners, depth=1.0):
    """Composite the mark as stitch relief rather than as ink.

    Tone-on-tone embroidery is the same colour as the cloth — it reads only
    because the raised stitching catches light on one side and shades on the
    other. With the key from the left, the upper-left of each stroke lifts and
    the lower-right drops. Painting it as a dark shape would look printed.
    """
    m = Image.open(MARK)
    alpha = m.split()[3] if m.mode == "RGBA" else m.convert("L")

    src = [(0, 0), (alpha.width, 0), (alpha.width, alpha.height), (0, alpha.height)]
    a = alpha.transform(im.size, Image.PERSPECTIVE, coeffs(corners, src), Image.BICUBIC)
    # Barely softened. A wider blur turns the offset-difference bands into a
    # halo, which is what made the first pass read as a smudge rather than
    # thread.
    a = a.filter(ImageFilter.GaussianBlur(0.7))

    off = max(1, int(im.width / 1100))
    hi = ImageChops.subtract(ImageChops.offset(a, -off, -off), a)
    lo = ImageChops.subtract(ImageChops.offset(a, off, off), a)

    px = im.convert("RGB")
    white = Image.new("RGB", im.size, (255, 255, 255))
    black = Image.new("RGB", im.size, (0, 0, 0))

    # Tone on tone: the lift and the drop stay close together in value, so the
    # mark is legible in raking light and nearly gone in flat light — the way
    # real self-coloured embroidery behaves.
    px = Image.composite(Image.blend(px, white, 0.16 * depth), px, hi)
    px = Image.composite(Image.blend(px, black, 0.20 * depth), px, lo)
    px = Image.composite(Image.blend(px, black, 0.05 * depth), px, a.point(lambda v: int(v * 0.5)))
    return px


if __name__ == "__main__":
    src = sys.argv[1] if len(sys.argv) > 1 else "images/_gen/indigo-cuff-v4.png"
    out = sys.argv[2] if len(sys.argv) > 2 else "images/_gen/indigo-cuff-v5.png"
    if src not in QUADS:
        sys.exit("No cuff quad recorded for %s — add its four corners to QUADS." % src)

    im = Image.open(src).convert("RGB")
    corners = place(QUADS[src])
    im = clear_old(im, corners)
    im = emboss(im, corners)
    im.save(out)
    print("wrote %s" % out)
    print("mark at %s" % " ".join("(%.0f,%.0f)" % c for c in corners))
