# Pending from the client

Everything here is a fact only I Am Ratan can supply. **None of it is invented or
approximated anywhere on the site** — where a fact is missing, the page is built
without it rather than around a guess. Each item notes what it unblocks, so the
cost of leaving it open is visible.

Last updated 4 Aug 2026.

---

## 1 · Blocking a commercial decision

### Wardrobe Management price
Their own copy states clients *"commit to that cycle upfront, in full, before a
single shirt is cut"* — ten shirts across six months. No figure was supplied.

- **Where it bites:** [bespoke.html](bespoke.html) → Chapter Two. The section
  currently ends on an enquiry CTA with no number, so the offer never closes.
- **Also needed:** what happens if a client wants to change specification
  mid-cycle, and whether the ten shirts can be split across cloths.
- **Workaround in place:** enquiry-only. Honest, but a visitor cannot self-qualify.

### Made to Measure practicals
- Lead time to first fitting
- Minimum order, if any
- Price floor / starting price
- Where consultations happen — Hyderabad atelier only, or video, or travelling?
- How a booking is actually confirmed (right now it opens an email)

---

## 2 · Blocking page content

### The 25 product descriptions
WooCommerce holds **one boilerplate sentence reused for all 25 shirts** with only
the name swapped: *"Discover impeccable craftsmanship with [name], crafted from
premium cotton…"*. Click two products and it is obvious.

- **Options:** they write 25, we write 25 for approval, or the product page is
  restructured so cloth facts carry it instead of prose.
- **Blocked on:** either their copy, or the per-cloth facts below.

### Per-cloth facts
For each of the 25 cloths: **composition, gsm, weave, mill, care**.

- **Where it bites:** the product page has no specification block at all, because
  there is nothing true to put in it. This is the single biggest weakness of the
  product pages as built.

### Legal pages
Privacy, terms, shipping, returns/exchange. **Mandatory before Shopify launch**,
and their absence is noticeable to anyone who checks a footer at a seminar.

### Contact
Is `prashanth@iamratan.co.in` the right public address? Studio address for a
contact page? Opening hours?

---

## 3 · Blocking trust

### The LEGACY labels — commercial risk, not cosmetic
**19 of the 25 product photographs show another brand's name inside the collar.**
A customer paying ₹6,999 who sees a stranger's brand in the neck reasonably reads
counterfeit. This is refund-and-review territory, and it is on screen at full
size in the shop.

- **Fix, cheapest first:** retouch the label out of 19 images / reshoot those 19 /
  full reshoot of all 25.
- **Six cloths are already clean** — the newer worn-on-torso set.

### The three uncut sizes
The house cuts **39, 40, 42, 44, 46 only**. 41, 43 and 45 do not exist, and those
necks are a large share of the market. The site currently shows all eight and
refuses the three, routing them to bespoke — which turns a dead end into a lead.

- **Needs confirming:** is that routing what they actually want to happen, and can
  the atelier service the volume it may generate?

### ~~Button engraving~~ — ANSWERED 4 Aug 2026
The client supplied a photograph of the real cuff and the signature artwork.
Confirmed: **"I AM RATAN" is engraved around the rim of every button**, and the
cuff carries the house signature embroidered **tone on tone**.

This also surfaced a second brand mark we did not have: the **"I AM / Ratan"
script lockup**, distinct from the badger-and-IAR monogram. Extracted from the
supplied PDF to `assets/mark-signature.png` as an alpha mask, so it paints in
currentColor like the others.

Both details are now in the product shot set (`4-cuff`, `5-button`).

---

## 4 · Needed before Shopify

- Does a Shopify store exist yet, or is it still only WooCommerce at
  iamratan.co.in?
- Which account will own it, and on which plan?
- Who migrates the 25 products — us as a separate line item, or them?
- Payment gateway and shipping zones/rates.

---

## Decisions we took so we could keep moving

These were made to avoid stalling. Each is a small edit to reverse.

| Decision | Taken | Reversible by |
|---|---|---|
| Ethos = **Reclaim / Redefine / Resonate**, replacing Legacy / Care / Conviction / Courage | their v2 copy is newer and better written | one edit per page |
| Nav label = **"About us"**, not "The house" | it is their own page title | one sed across four pages |
| **"Premium"**, not "luxury", for the brand | their copy says *premium Indian apparel* | search and replace |
| Home page copy assembled from **their About Us and Bespoke pages** | no home copy was supplied | swap in new copy when written |
| Hero scrim strengthened on [index.html](index.html) | measured 1.27:1 — below AA. Now 8.47:1 | revert one CSS block |
