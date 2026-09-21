#!/usr/bin/env python3
"""Regenerate sitemap.xml: the public pages, plus a product URL for every cloth
the live shop view carries. Run after adding or retiring a cloth, then deploy."""
import datetime, json, pathlib, subprocess

S = 'https://www.iamratan.co.in'
U = 'https://hckbqcphijihqbysibos.supabase.co/rest/v1/shop?select=slug&order=sort_order.asc'
K = ('eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Imhja2JxY3BoaWppaHFieXNpYm9zIiwicm9sZSI6'
     'ImFub24iLCJpYXQiOjE3ODY3MDY1ODQsImV4cCI6MjEwMjI4MjU4NH0.wg5IdL1ArScKk4dWWTtX8xyi8s4Z-1B9gKQQJBvX9V8')
PAGES = [('', '1.0', 'weekly'), ('shop.html', '0.9', 'weekly'), ('bespoke.html', '0.8', 'monthly'),
         ('house.html', '0.7', 'monthly'), ('journal.html', '0.6', 'weekly'), ('contact.html', '0.5', 'monthly'),
         ('shipping.html', '0.3', 'yearly'), ('privacy.html', '0.2', 'yearly'), ('terms.html', '0.2', 'yearly'),
         ('journal-twenty-years.html', '0.5', 'yearly'), ('journal-a-shirt-should-disappear.html', '0.5', 'yearly'),
         ('journal-what-a-button-is-for.html', '0.5', 'yearly'), ('journal-the-wardrobe-that-remembers.html', '0.5', 'yearly')]

# curl rather than urllib: the framework Python on this Mac ships without
# certificates and cannot open an https connection
raw = subprocess.run(['curl', '-sf', U, '-H', 'apikey: ' + K, '-H', 'Authorization: Bearer ' + K],
                     capture_output=True, text=True, check=True).stdout
slugs = [r['slug'] for r in json.loads(raw)]
today = datetime.date.today().isoformat()
rows = ['<?xml version="1.0" encoding="UTF-8"?>',
        '<!-- The pages a search engine should know about. Product pages are listed by',
        '     the slugs the shop carries today. Regenerate with iar-lab/sitemap.py. -->',
        '<urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">']
def url(loc, pri, freq):
    rows.append('  <url><loc>%s</loc><lastmod>%s</lastmod><changefreq>%s</changefreq>'
                '<priority>%s</priority></url>' % (loc, today, freq, pri))
for p, pri, f in PAGES: url(S + '/' + p, pri, f)
for s in slugs: url(S + '/product.html?p=' + s, '0.8', 'weekly')
rows.append('</urlset>')
pathlib.Path('sitemap.xml').write_text('\n'.join(rows) + '\n', encoding='utf-8')
print('sitemap.xml: %d pages, %d cloths' % (len(PAGES), len(slugs)))
