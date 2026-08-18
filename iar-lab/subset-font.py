#!/usr/bin/env python3
"""Cut a display font down to the glyphs one line of type actually uses.

    python3 iar-lab/subset-font.py ~/Downloads/Avapore.otf assets/avapore.woff2

The ethos triad on house.html is three words — Reclaim, Redefine, Resonate —
which between them use thirteen distinct letters. Shipping a full font for that
is 60-100 KB of network for 23 characters of type, on a page whose entire
stylesheet is 40 KB. A subset is 3-5 KB and identical on screen.

Subsetting is a delivery optimisation, not a redraw: the outlines that ship are
the designer's, unchanged. Some licences still speak to modification, so it is
worth a look at the licence before this runs. Nothing here alters a glyph.
"""
import sys, os
from fontTools import subset
from fontTools.ttLib import TTFont

# every character in the three words, plus the space they never actually need
TEXT = "Reclaim Redefine Resonate"

def main():
    if len(sys.argv) != 3:
        sys.exit(__doc__)
    src, dst = sys.argv[1], sys.argv[2]
    if not os.path.exists(src):
        sys.exit("no font at %s — download it from Envato first" % src)

    before = os.path.getsize(src)
    chars = sorted(set(TEXT.replace(" ", "")))

    opts = subset.Options()
    opts.flavor = "woff2"          # the only format worth serving in 2026
    opts.desubroutinize = True
    opts.layout_features = ["kern", "liga"]   # keep the spacing the designer drew
    opts.notdef_outline = True
    opts.recalc_bounds = True

    font = subset.load_font(src, opts)
    subsetter = subset.Subsetter(options=opts)
    subsetter.populate(text="".join(chars))
    subsetter.subset(font)
    subset.save_font(font, dst, opts)

    after = os.path.getsize(dst)
    name = TTFont(dst)["name"].getDebugName(1) or "?"
    print("family     %s" % name)
    print("glyphs     %d  (%s)" % (len(chars), "".join(chars)))
    print("%-10s %7.1f KB" % ("before", before / 1024))
    print("%-10s %7.1f KB   %.0f%% smaller" %
          ("after", after / 1024, 100 - after / before * 100))

if __name__ == "__main__":
    main()
