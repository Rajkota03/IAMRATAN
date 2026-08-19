# Pending from the client

Everything here is a fact only I Am Ratan can supply. **Nothing here is invented
on the site, with one flagged exception — the Ratan's Circle panel, whose two
sentences we wrote from a single deck line at the client's request (see the
decisions table).** Where a fact is missing, the page is built
without it rather than around a guess. Each item notes what it unblocks, so the
cost of leaving it open is visible.

Last updated 19 Aug 2026.

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

### The shop headline — now removed entirely, and the cloth count is a question
The copy document lists the shop page as a gap: no headline, no intro, no
category descriptions. It read **"Twenty-seven cloths."**, bound to the live
product table, so it rewrote itself whenever a cloth sold out or arrived. We
replaced that with **"Start with the cloth."** — our words — and the client has
since asked for the headline and the *"The range"* eyebrow to come off the page
altogether, so the shop opens straight onto the filters.

- **Done:** both lines are gone from the visible page. The heading is still in
  the document as a hidden `<h1>The range</h1>`, so a screen reader and a Google
  result still get one — a page with no h1 at all is a real SEO cost, and this
  keeps the cost at zero without painting anything.
- **Note:** this means the shop currently carries **no words of its own**. Any
  headline or intro they supply can go straight back above the filters.
- **The count survives** on the *All* filter, where a number is a count of
  results rather than a claim about the house.
- **Still counting elsewhere:** the home hero ("Twenty-seven cloths, cut in five
  sizes…"), the 404 page and the product page all still print the live count.
  Left alone, because the client's instruction was about Wardrobe Management —
  but if the rule is "no numbers anywhere", these three are the rest of it.
- **Needed:** a headline and a short intro for the range, in their words.

### The Wardrobe Management numbers — WITHDRAWN by the client 19 Aug 2026
Their copy document describes the service in specifics: *"we build ten shirts to
your exact specification and hold them against the six months in front of you"*.
The client has since said not to publish any count of shirts or any period — the
consultation call handles it.

- **Done:** every count is off the customer-facing site — the home door kicker
  ("Ten shirts · six months" is now "By enquiry"), both summary lines, the
  contact-page route, and inside Chapter Two the sentences carrying the numbers
  are **dropped**, not reworded, the same way every other elision on that page
  works.
- **Where it leaves a hole:** Chapter Two now says the fit is recorded, that the
  house looks ahead, and that the cycle is paid upfront — but no longer what is
  being committed to.
- **Needed:** replacement copy for Chapter Two that describes the service
  without a count, or a decision that the short version is enough and the detail
  belongs on the call.

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

Both details are now in the product shot set as `4-cuff` and `5-button`, for all 27 cloths, from the close-ups supplied 19 Aug 2026. Each cloth carries its own cuff and its own button, checked by hash: no two cloths share an image.

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
| **Ratan's Circle on the home page — with copy we wrote** | the client asked for it explicitly. But it appears nowhere in their website copy: only a single pitch-deck line — *"invite-only inner circle for our top clients: personalised access, experiences, privileges"*. The two sentences on the home-page panel are OURS, built from that line, using only nouns they used. This is the one place on the whole site carrying words we wrote. Its one hard number (a waitlist figure) is confidential and is kept off the site entirely. | needs their sign-off on the actual wording, and — if it is to do more than state that it exists — what a member gets and how one is invited |

### The two home-page doors are now Ready to Wear and Bespoke
They were Made to Measure and Wardrobe Management, which are the two *services*.
The client corrected this on 19 Aug 2026: the doors are the two ways to buy, so
one goes to the shop and one to the bespoke page. Both services still live on
the bespoke page, which is where their detail belongs.

- **Ours:** the Ready to Wear caption ("The house's own cloths, cut in five
  sizes and finished by the same hands. Choose one and it ships.") is our
  wording. Every noun is theirs; nothing is invented. Needs their sign-off.
- **Placeholder images:** the drawer archive stands in for Ready to Wear and the
  cutting table for Bespoke until the client's own two frames arrive. Swap the
  files in images/hero/, keep the markup.
