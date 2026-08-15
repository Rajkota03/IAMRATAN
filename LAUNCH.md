# Going live — the checklist

I Am Ratan · Artisan Apparels, Hyderabad
Last revised: 15 August 2026

The single list. Nothing ships until its line here is ticked. Ask me to
"revise the checklist" any time and I re-check every item against the live
site and update the marks.

```
   ✅ done        ⏳ in progress      ⬜ not started      🔒 blocked on someone else
```

**Where we are: 21 of 61 done.** (The list has 61 items; the 48 in the first
version was my miscount.)

**Next step is the admin dashboard — section 4.** It is the largest single
remaining build and the client cannot run the shop without it. It needs one
thing from you: the email address that should be the first admin login.

---

## 1 · The law (India)

Not optional, and this is the section most freelancers miss. Non-compliance
with the e-commerce rules can carry penalties and, at the extreme, imprisonment.

| | Item | What it means, plainly |
|---|---|---|
| ✅ | 1.1 Privacy policy page | Live at `/privacy.html` — **draft, needs the house's confirmation** |
| ✅ | 1.2 Terms page | Live at `/terms.html` — **draft** |
| ✅ | 1.3 Shipping & returns page | Live at `/shipping.html` — **draft, has `[bracketed]` gaps** |
| ⬜ | 1.4 Seller's legal name and address on the site | "Artisan Apparels" plus the full registered address. Required. |
| ⬜ | 1.5 **Grievance Officer** named, with email + phone | A real person, named on the site. Complaints acknowledged in 48 hours, resolved in a month. This is a legal appointment, not a form. |
| ⬜ | 1.6 GSTIN displayed | The client's GST number, shown on the site and on every invoice |
| ✅ | 1.7 Price shown inclusive of all taxes | ₹5,999 must be the final number. No surprises at checkout — *the #1 cause of abandoned carts.* |
| ⬜ | 1.8 Country of origin per product | "Made in India" on every cloth |
| ⬜ | 1.9 Return shipping cost stated | Who pays to send it back — must be explicit |
| ⬜ | 1.10 Cancellation window stated | Before dispatch, how long |
| ⬜ | 1.11 DPDP consent wording on the form | One honest line about what happens to their number |

> **What I need from the client:** registered address, GSTIN, the name of the
> Grievance Officer, real delivery timelines, and the real returns terms.
> Everything in `[brackets]` on the live site is waiting for this.

---

## 2 · What a buyer must be told

| | Item | Where |
|---|---|---|
| ✅ | 2.1 Size guide, per cloth | Product page — **numbers are indicative, need the house's block** |
| ✅ | 2.2 Cloth & care | Product page — **needs real composition per cloth** |
| ✅ | 2.3 Delivery & returns summary | Product page accordion |
| ✅ | 2.4 Photography: front, back, detail | All 27 cloths |
| ✅ | 2.5 Stock status per size | "Only 2 left in 42" / "Sold out" |
| ⬜ | 2.6 Real cloth names and prices | Currently scraped from their old WooCommerce store, 28 July. **Unconfirmed.** |
| ⬜ | 2.7 "Twenty-five cloths" says 25, shop has 27 | Copy is stale in ~12 places |

---

## 3 · Taking the money

| | Item | Notes |
|---|---|---|
| 🔒 | 3.1 Razorpay account + KYC | **Client's own name and business.** Not yours. |
| ✅ | 3.2 Checkout — guest by default | No forced sign-in. Forced accounts are the #2 cause of abandonment (26%). |
| ⬜ | 3.3 UPI, cards, netbanking | UPI first — it is how India pays |
| ⬜ | 3.4 COD — decide yes or no | High return rates. The client's call. |
| ⬜ | 3.5 GST invoice generated per order | Legally required, emailed automatically |
| ⬜ | 3.6 Order confirmation — email + WhatsApp | WhatsApp matters more here |
| ⬜ | 3.7 Failed-payment recovery | Payment drops happen; don't lose the order |
| ⬜ | 3.8 Test with a real ₹1 transaction | End to end, then refund it |

---

## 4 · Running the shop

| | Item | Notes |
|---|---|---|
| ✅ | 4.1 Database | Supabase, Mumbai region. **Waiting on the account.** |
| ⬜ | 4.2 Admin — orders | New / making / shipped, in the house's language |
| ⬜ | 4.3 Admin — products | Edit price, stock, photos without me |
| ⬜ | 4.4 Admin — enquiries | Bespoke and wardrobe leads, unanswered first |
| ⬜ | 4.5 **The measurement book** | Neck, chest, sleeve per customer. *This is the repeat-business asset.* |
| ⬜ | 4.6 Staff login | Supabase auth. Never hand-rolled. |
| ⬜ | 4.7 Backups | Automatic, and **tested by restoring one** |
| ⬜ | 4.8 Someone can pack an order at 9pm without calling me | The real test of the admin |

---

## 5 · Knowing what happens

| | Item | Notes |
|---|---|---|
| ✅ | 5.1 Tracking built | `assets/track.js`, all 11 pages, cookie-free |
| ✅ | 5.2 Switched on | Needs the Supabase keys |
| ✅ | 5.3 **Uncut-size capture** | Every tap on a 41/43/45 = a bespoke lead that used to vanish |
| ✅ | 5.4 No cookie banner needed | No cookies, no IDs stored. Deliberate. |
| ⬜ | 5.5 A weekly page the client will actually open | Sales, orders to pack, new leads |

---

## 6 · Being found

| | Item | Notes |
|---|---|---|
| 🔒 | 6.1 Decide the final domain | `iamratan.co.in`? Blocks 6.2–6.5. |
| ⬜ | 6.2 Canonical tags | Must point at the final domain |
| ⬜ | 6.3 sitemap.xml + robots.txt | |
| ⬜ | 6.4 Product structured data | How the shop looks in a Google result |
| ⬜ | 6.5 Google Search Console | |
| ✅ | 6.6 Working links kept out of Google | `noindex` on `iar-*`, host-scoped |
| ⬜ | 6.7 Redirects from the old WordPress URLs | Or every existing Google result 404s |

---

## 7 · The site itself

| | Item | Notes |
|---|---|---|
| ✅ | 7.1 Mobile-first, tested at 375px | |
| ✅ | 7.2 Tap targets ≥ 24px | |
| ✅ | 7.3 Skip link, focus states, alt text | |
| ✅ | 7.4 Spacing on one scale | `python3 iar-lab/space.py` → zero off-scale |
| ✅ | 7.5 Images optimised | WebP where it saved >10% |
| ⬜ | 7.6 Shop/product images to WebP | ~40% left on the table |
| ⬜ | 7.7 Test on a real Android phone | Not just a simulator |
| ⬜ | 7.8 404 and failure states | 404 exists; payment/network failures don't |

---

## 8 · The day itself

| | Item |
|---|---|
| ⬜ | 8.1 Final content pass — no `[brackets]`, no "For the house" notes |
| ⬜ | 8.2 SSL on the real domain |
| ⬜ | 8.3 Email working on the domain |
| ⬜ | 8.4 One real order, start to finish, by someone who didn't build it |
| ⬜ | 8.5 Handover sheet — every account, who owns it, what it costs, when it renews |
| ⬜ | 8.6 Supabase project transferred to the client's org |
| ⬜ | 8.7 Rollback plan written down |

---

## The order to do it in

1. **Client answers section 1** — the legal facts. Six items unblock.
2. **Supabase keys** → tracking on (5.2), database live (4.1)
3. **Real names, prices, sizes** (2.6, 2.7)
4. **Razorpay KYC** — slowest external step, start it early
5. **Build checkout** (section 3)
6. **Build admin** (section 4)
7. **Domain decision** → SEO (section 6)
8. **Launch day** (section 8)

## Sources

- Consumer Protection (E-Commerce) Rules, 2020 — [Dept. of Consumer Affairs](https://consumeraffairs.nic.in/theconsumerprotection/consumer-protection-e-commerce-rules-2020), [Trilegal summary](https://trilegal.com/knowledge_repository/consumer-protection-e-commerce-rules-2020/)
- Legal Metrology (Packaged Commodities) Amendment Rules, 2026 — [SCC Online](https://www.scconline.com/blog/post/2026/02/21/legal-metrology-packaged-commodities-amendment-rules-2026-explained/)
- Checkout abandonment data — [Baymard](https://baymard.com/learn/reduce-cart-abandonment)
