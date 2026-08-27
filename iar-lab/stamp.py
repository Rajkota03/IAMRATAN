#!/usr/bin/env python3
"""Re-stamp every ?v= in the site's HTML from the newest asset's mtime.

Every asset link carries ?v=<stamp>. The stamp was written by hand and never
moved, so a returning visitor kept whatever CSS and JS they had cached the last
time, however many times we deployed. Run this after changing anything under
assets/ and before deploying.
"""
import glob, os, re, sys

assets = [p for p in glob.glob('assets/**/*', recursive=True)
          if os.path.isfile(p) and p.rsplit('.', 1)[-1] in ('css', 'js')]
if not assets:
    sys.exit('no assets found; run this from the site root')
stamp = int(max(os.path.getmtime(p) for p in assets))

pat = re.compile(r'(\?v=)(\d+)')
touched = seen = 0
for page in glob.glob('*.html'):
    src = open(page, encoding='utf-8').read()
    new, n = pat.subn(lambda m: m.group(1) + str(stamp), src)
    seen += n
    if new != src:
        open(page, 'w', encoding='utf-8').write(new)
        touched += 1

print(f'stamp {stamp}  ({seen} links across {len(glob.glob("*.html"))} pages, '
      f'{touched} rewritten)')
