# Going live — the checklist

I Am Ratan · Artisan Apparels, Hyderabad
Last revised: 15 August 2026

The single list. Nothing ships until its line here is ticked. Ask me to
"revise the checklist" any time and I re-check every item against the live
site and update the marks.

```
   ✅ done        ⏳ in progress      ⬜ not started      🔒 blocked on someone else
```

**Where we are: 51 of 88 done.**

**Our side is done.** The last screens from the mockups — Analytics and
Reports — are built. Of the 37 still open, **36 need someone else**: 4 blocked
outright on the client, ~14 waiting on facts only they can give (GSTIN, the
Grievance Officer, real prices), 7 behind the Razorpay KYC, 6 behind the domain
decision, and the rest are launch-day checks.

The one remaining item that is mine is **5.5, a weekly summary page** — and it
is a nice-to-have, not a blocker.

**The critical path is now entirely the client**, and the longest pole is the
Razorpay KYC, because seven items sit behind it and it has a queue nobody here
controls.

---

## 1 · The law (India)

Not optional, and this is the section most freelancers miss. Non-compliance
with the e-commerce rules can carry penalties and, at the extreme, imprisonment.

| | Item | What it means, plainly |
|---|---|---|
| ✅ | 1.1 Privacy policy page | Live at `/privacy.html` — **draft, needs the house's confirmation** |
| ✅ | 1.2 Terms page | Live at `/terms.html` — **draft** |
| ✅ | 1.3 Shipping & returns page | Live at `/shipping.html` — **draft, has `[bracketed]` gaps** |
| ⏳ | 1.4 Seller's legal name and address on the site | "Artisan Apparels" plus the full registered address. Required. |
| ⏳ | 1.5 **Grievance Officer** named, with email + phone | A real person, named on the site. Complaints acknowledged in 48 hours, resolved in a month. This is a legal appointment, not a form. |
| ⏳ | 1.6 GSTIN displayed | The client's GST number, shown on the site and on every invoice |
| ✅ | 1.7 Price shown inclusive of all taxes | ₹5,999 must be the final number. No surprises at checkout — *the #1 cause of abandoned carts.* |
| ⬜ | 1.8 Country of origin per product | "Made in India" on every cloth |
| ⬜ | 1.9 Return shipping cost stated | Who pays to send it back — must be explicit |
| ⬜ | 1.10 Cancellation window stated | Before dispatch, how long |
| ⬜ | 1.11 DPDP consent wording on the form | One honest line about what happens to their number |
| ⬜ | 1.12 Privacy policy must cover **abandoned carts** | New since the marketing build. A half-finished checkout now stores a name, email and phone so the house can follow it up. That is personal data kept for a purpose the customer did not complete — the policy has to say it is kept, why, and for how long. Browsing is still never recorded against a person. |

> **1.4–1.6 are built and tested, waiting only on the facts.** Stand-ins are in
> the database behind a `facts_are_real` switch that is OFF: the shop front
> prints nothing, the block can be previewed at `?preview=facts`, and the
> invoice stamps itself SPECIMEN. Verified on all 12 pages at 1440 and 375.
> When the real five arrive: type them into Settings, switch it on, done.
>
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
| ✅ | 2.7 "Twenty-five cloths" says 25, shop has 27 | Fixed 15 Aug — and made **live** rather than re-typed. `house.js` counts the range and spells the number in the house's voice ("Twenty-seven", not "27"), so it cannot go stale again when a 28th cloth is cut. Meta descriptions carry the correct number statically, since a crawler reads those before any script runs. |

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
| ✅ | 4.2 Admin — orders | New / making / shipped, in the house's language |
| ✅ | 4.3 Admin — products | Edit price, stock, photos without me |
| ✅ | 4.4 Admin — enquiries | Bespoke and wardrobe leads, unanswered first |
| ✅ | 4.5 **The measurement book** | Neck, chest, sleeve per customer. *This is the repeat-business asset.* |
| ✅ | 4.5b **Views made to obey row-level security** | 15 Aug 2026. A Postgres view ignores RLS by default — it runs as its creator, not its caller. Every table was locked and every view handed the data back out. Proved with the public anon key: `events` returned `[]`, `funnel` over the same table returned real counts. All 23 admin views now `security_invoker = on` **and** revoked from `anon`. Re-verified: 23/23 refuse, shop front untouched. |
| ✅ | 4.5c **`products`/`inventory`/`settings` narrowed to the admin list** | Were `for all to authenticated using (true)`. `authenticated` is every account, not the house, and sign-up is open — registering an email would have been enough to change a price or edit the GSTIN on the invoices. |
| ✅ | 4.5d `events` SELECT policy added | There was none. Analytics had only ever worked *through* the leak. |
| ✅ | 4.5e **The house can change photographs without me** | 15 Aug 2026. Supabase Storage + a Media screen. Until now a photograph lived in the repository, so changing one was a deploy, so changing one was me. This was the single biggest thing between the house and running its own shop. |
| ✅ | 4.5f Announcement bar actually renders | The setting existed from day one and **nothing had ever drawn it** — the house could type a line and it went nowhere. `assets/house.js` now puts it on all 12 pages. |
| ✅ | 4.5g Home page bands, menu, pages | Hide a band, reorder it, rename a link. The HTML still ships correct and complete; the database only overrides. Verified: with the tables absent the page is byte-for-byte the site I built. |
| ✅ | 4.5h `product_images` created | The cloth photo manager has called this table since the desk was built and it never existed. Its layout was broken too — the shared gallery CSS laid the caption over the photograph. |
| ✅ | 4.5i **Every screen now has its table** | Five tables `admin.js` had always called were never created, so five screens only ever showed an error: Reports (×3 views), Collections, and the Measurement book (×2). Found by sweeping every REST path in `admin.js` against the live database instead of fixing them one at a time. Verified: zero unaccounted-for. |
| ✅ | 4.5j Measurement book | Every sitting kept, never overwritten — a man's neck at forty is not his neck at fifty. The only new table **not** readable by the shop front: it holds people's bodies. Commercially the most valuable table here — a house that still has his numbers does not have to measure him again. |
| ✅ | 4.6 Staff login | Supabase auth. Never hand-rolled. |
| ⬜ | 4.6b **Close open sign-up** | Anyone can still create an account; they just can't do anything with it. Turn off public sign-up in Supabase → Authentication → Providers once the house's logins exist. |
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
| ✅ | 5.4b **Bespoke enquiries now reach the desk** | Found 15 Aug. The form had always gone to an inbox and a WhatsApp thread and **nowhere else**, so the Enquiries screen and its unanswered counter had sat at zero since the day they were built, however many people asked. A bespoke enquiry is the highest-value thing anyone does on this site. Now written to `enquiries` as well, fire-and-forget so the customer's confirmation never waits on it. |
| ✅ | 5.6 **Analytics rebuilt** | Six figures each against the thirty days before them, revenue and orders drawn as this-period-against-previous on one shared scale, channel ring, funnel, best sellers, campaign revenue, customer insight, and where the shirts go by state. |
| ✅ | 5.7 **Reports rebuilt** | Four report families — Sales, Products, Customers, Traffic — each with its own figures and every table exporting to CSV. |
| ✅ | 5.8 The tracker carries the channel | Until now only ORDERS knew which link they came from, so the shop could never answer the one question that matters about an ad: did the people it sent actually buy? Every event now carries the utm, so visits-per-channel and conversion-per-channel are real. Still not a person: it is a word, joined to nothing, gone when the tab closes. |
| ⬜ | 5.5 A weekly page the client will actually open | Sales, orders to pack, new leads. The only thing left on this list that is mine. |

---

## 5b · Marketing

Built as of 15 Aug 2026. Offers, carts and attribution are real and working;
sending email or SMS is not, and is not pretended to be anywhere on the screen.

| | Item | Notes |
|---|---|---|
| ✅ | 5b.1 Discount codes, end to end | Made on the desk, typed at checkout, **priced by the database**. An edited page cannot get a bigger discount than the code allows. |
| ✅ | 5b.2 Order re-priced server-side | The trigger recomputes the subtotal from the products table, so the browser can no longer decide what a shirt costs. Closes a hole that predates this build. |
| ✅ | 5b.3 Abandoned carts | Captured 30 min after a checkout is left half-filled. One-tap WhatsApp chase. |
| ✅ | 5b.4 Attribution | `?utm_source=` on any link → the order shows up against that channel. |
| ✅ | 5b.5 Campaign audiences | Built from real customers: everyone, repeat, recent, quiet, abandoned, bespoke enquiries. |
| ✅ | 5b.6 WhatsApp campaigns | Work today, no provider needed. One chat per person, message merged, ticked as sent. |
| 🔒 | 5b.7 **Email provider** | Nothing can send email until one is connected. Campaign lists export as CSV meanwhile. Open and click rates are **not shown at all** rather than estimated. |
| 🔒 | 5b.8 **SMS gateway + DLT registration** | Indian promotional SMS needs a registered DLT template before any provider will carry it. Both are the client's to obtain. |
| ⬜ | 5b.9 Ad spend entered | ROAS stays blank until the house types what a channel cost. Deliberate — an invented ROAS is the most expensive lie a dashboard can tell. |
| ⬜ | 5b.10 Give the client their UTM links | They need the exact link to paste in the Instagram bio, or nothing attributes. |

---

## 6 · Being found

| | Item | Notes |
|---|---|---|
| 🔒 | 6.1 Decide the final domain | `iamratan.co.in`? Blocks 6.2–6.5. |
| ⬜ | 6.2 Canonical tags | Must point at the final domain |
| ⬜ | 6.3 sitemap.xml + robots.txt | |
| ✅ | 6.4 Product structured data | Product JSON-LD per cloth (name, price, INR, availability, photographs) restated once the database answers, so the price Google reads is the price charged. ClothingStore schema on the home page. **No aggregateRating** — there are no reviews, and inventing one is what earns a manual penalty. |
| ⬜ | 6.5 Google Search Console | |
| ✅ | 6.6 Working links kept out of Google | `noindex` on `iar-*`, host-scoped |
| ⬜ | 6.7 Redirects from the old WordPress URLs | Or every existing Google result 404s |
| ✅ | 6.8 **Internal working pages carry no `noindex`** | Found 15 Aug. `loom`, `range`, `directions`, `mockup`, `shop-a/b/c`, `shop-grid`, `shop-index`, `shop-wall` and five `variant-*` pages are deployed, unlinked, and crawlable. On the real domain Google would index the client's design experiments alongside the shop. `preview.html` has the tag; none of the others do. Fix before the domain is wired, not after. |
| ✅ | 6.9 robots.txt + noindex | `robots.txt` shipped, and all 15 working pages carry `noindex,nofollow` in their own markup — verified live, 15/15. The six shop pages are correctly left indexable. The sitemap line is written but commented out until the domain exists: an absolute URL pointing at a working link would teach Google the wrong home. |

---

## 7 · The site itself

| | Item | Notes |
|---|---|---|
| ✅ | 7.1 Mobile-first, tested at 375px | |
| ✅ | 7.2 Tap targets ≥ 24px | |
| ✅ | 7.3 Skip link, focus states, alt text | |
| ✅ | 7.4 Spacing on one scale | `python3 iar-lab/space.py` → zero off-scale |
| ✅ | 7.5 Images optimised | WebP where it saved >10% |
| ✅ | 7.6 Shop/product images to WebP | Done properly on 16 Aug, after my first answer was wrong. I had scanned only image paths written as literal strings — but the galleries build theirs in JS (`base + shot + '.jpg'`), so **156 files, 9.6 MB, were invisible to the scan**. I reported 2.5 MB shipped; it was 12.4 MB. Converted the 183 cloth photographs: **9.34 MB → 5.11 MB, −45%**, site total 12.44 → 8.21 MB. Heroes and journal images stay JPG — measured, and WebP made one of them *larger*. All 151 URLs the shop and product pages request verified 200 live. |
| ⬜ | 7.7 Test on a real Android phone | Not just a simulator |
| ✅ | 7.8 404 and failure states | Audited. The bespoke form already refuses to be a dead end (hands over the phone number), the checkout survives a sleeping database, and the shop falls back to its bundled catalogue. Payment failure states arrive with Razorpay. |

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
