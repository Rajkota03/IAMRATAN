"""Drop the RECLAIM box photograph into journal essay 01.

Run it with no arguments once the file is in new-hero/. It finds the picture by
name, cuts the two crops the journal uses, points the essay and the index at
them, and says what it did. Safe to run twice.

Why a script and not a note-to-self: the sizes, the quality, the crop bias and
the two files that must both be updated are easy to get half-right by hand a
week later, and a half-right version looks fine until someone opens it on a
phone.
"""
import glob, os, re, sys
from PIL import Image

CANDIDATES = 'reclaim', 'box'
HERO, CARD = 'images/journal/reclaim.webp', 'images/journal/reclaim-card.webp'
ESSAY, INDEX = 'journal-twenty-years.html', 'journal.html'
ALT = ('The house box in navy, RECLAIM foiled across it and the I Am Ratan '
       'signature below, on blue cloth')

def find():
    for p in sorted(glob.glob('new-hero/*')):
        stem = os.path.basename(p).lower()
        if stem.endswith(('.png', '.jpg', '.jpeg', '.webp', '.heic')) \
           and any(c in stem for c in CANDIDATES):
            return p
    return None

def cut(im, tw, th, ybias=0.5):
    """cover-crop to the target ratio, then resize"""
    w, h = im.size
    tr = tw / th
    if w / h > tr:
        nw = round(h * tr)
        im = im.crop(((w - nw) // 2, 0, (w - nw) // 2 + nw, h))
    else:
        nh = round(w / tr)
        y = max(0, min(h - nh, round(h * ybias) - nh // 2))
        im = im.crop((0, y, w, y + nh))
    return im.resize((tw, th), Image.LANCZOS)

def main():
    src = find()
    if not src:
        print('No RECLAIM image found in new-hero/.')
        print('Drop it in with "reclaim" or "box" in the filename, then run this again.')
        return 1
    im = Image.open(src).convert('RGB')
    print('source  %s  %sx%s' % (src, *im.size))
    cut(im, 1600, 900).save(HERO, 'WEBP', quality=82, method=6)
    cut(im, 1200, 800).save(CARD, 'WEBP', quality=82, method=6)
    for f in (HERO, CARD):
        print('  wrote %-34s %s  %.0f KB'
              % (f, Image.open(f).size, os.path.getsize(f) / 1024))

    # the essay hero
    s = open(ESSAY, encoding='utf-8').read()
    s2 = re.sub(r'<img src="images/journal/[a-z-]+\.(?:webp|jpg)" alt="[^"]*"'
                r' fetchpriority="high"',
                '<img src="%s" alt="%s" fetchpriority="high"' % (HERO, ALT), s, count=1)
    if s2 == s:
        print('  ! essay hero not matched, left alone'); 
    else:
        open(ESSAY, 'w', encoding='utf-8').write(s2); print('  essay hero updated')

    # the card on the index and on every read-next rail
    for f in [INDEX] + glob.glob('journal-*.html'):
        t = open(f, encoding='utf-8').read()
        t2 = t.replace('images/journal/lobby.webp', CARD)
        if t2 != t:
            open(f, 'w', encoding='utf-8').write(t2)
            print('  card swapped in %s' % f)
    print('\nDone. Check it, then deploy.')
    return 0

if __name__ == '__main__':
    sys.exit(main())
