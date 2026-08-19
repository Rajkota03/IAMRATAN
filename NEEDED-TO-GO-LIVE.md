# What we need before this can take a real customer

Written 18 Aug 2026, while building sign-in and the CRM desk.

Everything here is a thing **only the client or the account owner can supply**.
Nothing on this list is waiting on engineering. Each item says what it blocks and
what happens if it stays open, so the cost of leaving it is visible.

Grouped by whether it stops a sale, stops a feature, or stops a law being
followed.

---

## 1 · Stops money reaching the account

### 1.1 A payment gateway — the single biggest hole on the site
There is **no payment gateway at all**. A customer fills in eight fields and is
then ejected to WhatsApp with a pre-typed message. `orders.payment_method`
defaults to `'prepaid'` and `payment_state` to `'pending'`; both are fictions
today because nothing ever charges anyone.

- **Cost of leaving it:** every sale depends on a human answering WhatsApp and
  arranging payment by hand. Nothing scales, nothing is measurable, and a buyer
  at 1am simply does not buy.
- **Needed:** Razorpay (or PayU/Cashfree) — merchant account, Key ID, Key Secret,
  and the webhook secret. Razorpay is the usual choice here because it does UPI,
  cards and netbanking in one and settles to an Indian current account.
- **Also decide:** is Cash on Delivery offered? It changes the checkout, the
  refund flow, and the fraud exposure.

### 1.2 The bank account the money lands in
Current account in the trading name, so settlement does not bounce.

### 1.3 Shipping — the numbers are literally `[brackets]` on the live site
`shipping.html` currently shows the customer a box that reads *"This page is a
working draft"*, and the policy text contains `[3–7]`, `[free above ₹X / at a
flat ₹Y]` and `[7] days`. The product page carries the same brackets.

- **Cost of leaving it:** the page a hesitant buyer opens before paying tells him
  the shop is not finished. This is the cheapest conversion fix on the whole
  site and it needs no engineering, only answers.
- **Needed:** delivery window in working days · is delivery free, and above what
  order value · flat rate if not · which courier · do you ship outside India.

### 1.4 Returns and exchanges
- **Needed:** how many days · must it be unworn with tags · who pays return
  postage · refund to original payment method or store credit · is exchange for
  a different neck size handled differently.

---

## 2 · Stops sign-in working properly

### 2.1 An email sender — needed before ANY customer signs in
Sign-in works by emailing a six-digit code. Supabase's built-in mailer is a
development convenience: it is rate-limited to a handful of messages an hour and
Supabase say plainly it is not for production. On a launch day it will simply
stop sending, and customers will sit staring at a code that never arrives.

- **Needed:** an SMTP provider connected to the Supabase project — Resend, SES,
  SendGrid or Postmark — plus a verified sending domain (`iamratan.co.in`) with
  SPF, DKIM and DMARC records added to DNS.
- **Until then:** sign-in works for testing and for a handful of people a day. It
  is not safe for a campaign.

### 2.2 An SMS provider — for "send the code to my mobile"
The requirement is sign-in by **email or phone**. Email works as soon as 2.1 is
done. Phone does not work at all until an SMS provider is connected to Supabase,
because Supabase does not send SMS itself.

- **Needed:** Twilio, MSG91 or Gupshup account + credentials, entered in Supabase
  Auth settings. For India also: a DLT-registered sender ID and an approved
  template, which is a TRAI requirement and takes days, not minutes.
- **Until then:** the sign-in page detects this and tells the customer to use
  their email instead, rather than failing silently. But phone sign-in — the one
  an Indian customer will actually expect — is off.

### 2.3 Access to run the database migration
Two new SQL files are ready (`iar-lab/RUN-THIS-FIFTEENTH.sql` and
`RUN-THIS-SIXTEENTH.sql`) and **have not been run**. They create the accounts
table, fix a policy problem that would otherwise stop signed-in customers buying
anything, and add stock decrementing.

- **Needed:** somebody with Supabase dashboard access pastes them into the SQL
  editor, in order — the same way every other `RUN-THIS-*.sql` in this project
  was applied. Or give the build a service-role key / database password so it
  can be automated and, more importantly, **tested**.
- **Cost of leaving it:** none of the sign-in work can be verified against a real
  database. It is written, reviewed and unproven.

---

## 3 · Stops the marketing automation the client asked for

### 3.1 WhatsApp Business API
The requirement is automated customer communication, preferred over email. Today
the shop opens `wa.me` links a human must click, one at a time.

- **Needed:** a Meta Business account, a verified business, a WhatsApp Business
  Account, a phone number dedicated to the API (it can no longer be used in the
  normal WhatsApp app), and **pre-approved message templates** for anything sent
  outside a 24-hour reply window — order confirmation, dispatch, abandoned cart.
- **Note honestly:** approval takes days and templates get rejected for tone.
  Start it early; it is the long pole in the marketing plan.

### 3.2 Meta / Instagram lead capture
- **Needed:** Meta app with `leads_retrieval`, page access token, and the ad
  account id. Also the Pixel ID if conversions are to be attributed — there is
  **no Meta Pixel on the site at all** today.

### 3.3 Consent, before any of it is used
Marketing consent is not currently captured anywhere. Under the DPDP Act,
messaging people because they once bought a shirt is not safe.

- **Needed:** a decision on where consent is asked (a checkbox at checkout is the
  usual answer) and the exact wording. The database is being built to store and
  honour it, including suppression of anyone who opts out.

---

## 4 · Stops the site being lawful

### 4.1 The statutory seller block prints nothing today
Every page is meant to carry the legal name, registered address, GSTIN and a
Grievance Officer. All of it is currently hidden, because a setting called
`facts_are_real` is `false` — deliberately, so the site never prints an invented
GSTIN.

- **Needed:** registered legal name · registered address · GSTIN · Grievance
  Officer name, email and phone (mandatory under the Consumer Protection
  E-Commerce Rules 2020).
- **Then:** one settings flip turns it all on.

### 4.2 Invoices
Invoices already compute GST correctly and can be numbered and printed. They
carry whatever is in 4.1, so they are not safe to issue until it is real.

### 4.3 Privacy, terms, shipping, returns pages
Present as drafts. Must be reviewed by whoever is accountable for them before a
customer relies on them.

---

## 5 · Stops the shop looking trustworthy

### 5.1 The other brand's collar label — CHECKED 18 Aug 2026, not an issue on this site
`PENDING-FROM-CLIENT.md` and `ASSET-BRIEF.md` both warn that nineteen of the
twenty-five shirt photographs show a neck label reading `LEGACY` rather than I Am
Ratan, and describe it as the most commercially dangerous thing on the site. That
warning was written about the **existing WooCommerce store's photography**, and it
was repeated into this document without being checked against what this site
actually serves. That was wrong, and it is worth recording why rather than
quietly deleting it.

Every product photograph in this repository was examined — all 27 cloths, and
every shot type they have between them: `1-hero`, `2-view`, `2-back`, `3-view`,
`3-collar`, `4-cuff`, `5-button`. **Every one is worn on a model.** There is no
flat-lay and no folded shot anywhere in the set, so the inside of a collar is
never in frame, and no label of any brand is legible in any image on this site.

- **Nothing to fix here, and no reshoot to commission for this site.**
- **Still worth confirming with the client:** whether the old store's photographs
  are being retired with it, and whether any of them will be reused in a
  campaign or on a marketplace listing — the risk is real wherever those images
  are still published, it simply is not published here.

### 5.2 Twenty-five product descriptions
All 25 shirts share one boilerplate sentence with the name swapped. Click two
products and it is obvious.

### 5.3 Per-cloth facts
Composition, GSM, weave, mill, care — for each cloth. The product page has no
specification block at all because there is nothing true to put in it.

### 5.4 No reviews anywhere
Nothing on the site says another human has bought and liked a shirt. Deliberate
so far, because inventing them is not an option — but it is a real conversion
cost and worth a plan (a request-a-review message after delivery is the obvious
one, and needs 3.1).

---

## 6 · Decisions, not credentials

### 6.1 Shopify, or this?
The CRM proposal assumes a move to Shopify. What is being built here is a custom
site on Supabase with its own CRM. **Doing both means paying twice and keeping
two sources of truth in sync**, which is where most of these projects come
unstuck. This needs deciding before launch, not after.

### 6.2 Accounting and GST filing
Invoicing, payment tracking and exports are being built. **Statutory GST return
filing is not**, and should not be hand-rolled — the penalties for getting it
wrong land on the client, not on software. Zoho Books, Tally or whatever the CA
already uses should own filing; the shop will export cleanly into it.

### 6.3 The three uncut neck sizes
The house cuts 39, 40, 42, 44, 46. Sizes 41, 43 and 45 do not exist, and the site
currently routes those necks to bespoke instead of refusing them. Confirm that is
wanted, and that the atelier can service the volume it may generate.

### 6.4 A developer's personal email is still an admin
`rajkota.sql@gmail.com` is hardcoded as an administrator in the database, with a
comment saying to remove it at handover. It is still there.

---

## Already answered — kept so nobody asks twice

- **Button engraving** — confirmed 4 Aug 2026: "I AM RATAN" engraved around every
  button rim; cuff carries the house signature embroidered tone on tone.
- **Wardrobe Management counts** — withdrawn by the client 19 Aug 2026. No count
  of shirts and no period is published anywhere; the consultation call handles
  it.
