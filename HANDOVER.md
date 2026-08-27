# I Am Ratan — the handover sheet

Everything needed to own, run and repair this website without the person who
built it. Written for someone technical who has never seen it before.

Last updated 27 Aug 2026.

---

## 1 · What this site is

Plain HTML, CSS and JavaScript. No React, no build step, no framework. What is
in the folder is what is on the internet. Open any `.html` file in a browser and
it works.

Two things are not static:

- **Supabase** holds the products, the orders, the discount codes and the
  customer accounts.
- **Four small server functions** in `/api/pay/` take card payments. They are
  the only server-side code in the project.

The reason for the flat structure is that it stays repairable. Anybody who can
read HTML can change a price, a photograph or a paragraph, and nobody needs to
install anything to do it.

---

## 2 · The accounts, and who must own them

**These must all be in the client's name before the site is theirs.** An account
in an agency's name is a hostage, not a handover.

| what | where | why it matters | who should own it |
|---|---|---|---|
| The code | this folder + GitHub | the site itself | the client |
| Hosting | Vercel, project `iar-next` | serves the domain | the client |
| Database | Supabase, project `hckbqcphijihqbysibos` | orders, products, accounts | the client |
| Domain | wherever `iamratan.co.in` is registered | the address itself | the client |
| Payments | Razorpay dashboard | the money | **the client, and only the client** |
| Email | the address orders are sent to | order notifications | the client |

**Transfer checklist:** for each row, add the client's own email as an owner,
have them accept, then remove the agency account. Do it in that order. Verify by
signing in as them, not by being told it worked.

---

## 3 · How to change the site

### Something on a page — a word, a price, a photograph

Edit the `.html` file, then deploy. That is the whole process.

**After changing anything in `assets/`, run this first:**

```bash
python3 iar-lab/stamp.py
```

Every asset is loaded as `style.css?v=1787325973`. Browsers cache by URL, so
without a new stamp a returning visitor keeps the old file however many times
you deploy. This script re-stamps all of them from the newest file's timestamp.
**Skipping it is the single most common way to deploy a change nobody can see.**

### Deploying

```bash
npx vercel --prod --yes
```

Run from this folder. Takes about ten seconds. Vercel keeps every previous
deployment, so a bad one is undone from the dashboard by promoting the last good
one — no need to find and revert the code first.

### Checking your spacing hasn't drifted

```bash
python3 iar-lab/space.py
```

All spacing uses a nine-step scale defined in `assets/iar-house.css`. This
reports anything that has wandered off it. Target is zero.

---

## 4 · Taking payments

### How the money actually flows

```
customer fills the checkout form
   ↓
the order is written to Supabase          ← the price is recomputed here,
   ↓                                        from the products table
/api/pay/create  asks Razorpay for an order
   ↓
the Razorpay window opens, they pay
   ↓
/api/pay/verify  checks Razorpay's signature, marks the order paid
   ↓
/api/pay/webhook settles it anyway if their browser closed first
```

**Two things are deliberate and should not be "simplified" later:**

1. **The amount is never taken from the browser.** `payment_intent()` reads it
   from the order row, which a database trigger priced from the products table.
   A customer can edit anything the page sends. If the page ever decides the
   amount, anyone can pay ₹1 for a ₹5,000 shirt.

2. **Every failure still ends at WhatsApp.** If the gateway is down, the keys
   are missing, or the customer's card is declined, the order is already saved
   and they are handed to WhatsApp. An order that arrives by chat is worth more
   than one lost to a timeout.

### Switching it on

Nothing below is reversible-by-accident: until all five variables exist, the
site quietly behaves as it always did and hands orders to WhatsApp.

**Step 1 — the database.** Open the Supabase SQL editor and run
`iar-lab/RUN-THIS-SIXTEENTH.sql` once, all of it.

The file invents its own token and prints it as the **last** result — that is
the value needed in step 2. Copy it straight into Vercel.

Supabase's SQL editor shows only the last statement's output, so if you scroll
away or lose it, this is safe to run on its own at any time:

```sql
select token from public.payment_bridge;
```

The statements before it check the work. Every row should read `ok`. The one to
watch is **server-side pricing** — without that trigger the order total is
whatever the browser claimed, and someone can pay ₹1 for a shirt.

**Step 2 — the variables.** In Vercel → project `iar-next` → Settings →
Environment Variables, add five, for Production **and** Preview:

| name | where it comes from |
|---|---|
| `RAZORPAY_KEY_ID` | Razorpay dashboard → Account & Settings → API Keys |
| `RAZORPAY_KEY_SECRET` | shown **once** when the key is generated |
| `RAZORPAY_WEBHOOK_SECRET` | **you invent this one** — see below |
| `SUPABASE_URL` | `https://hckbqcphijihqbysibos.supabase.co` |
| `SUPABASE_ANON_KEY` | Supabase → Settings → API → anon public |
| `PAYMENT_BRIDGE_TOKEN` | the string from step 1 |

`SUPABASE_ANON_KEY` is the *anon* key, the one already public in the page. The
**service_role** key is not used anywhere in this project and must never be put
into Vercel, the pages, or a chat window. If someone tells you the payment code
needs it, they are describing a different design than this one.

**`RAZORPAY_WEBHOOK_SECRET` is not issued by Razorpay.** It is the one value on
this list you make up yourself, and it goes in two places: here, and the Secret
field when you create the webhook in step 3. Razorpay signs every webhook with
it so the server can tell a real one from somebody POSTing "this order is paid"
at the endpoint. Make one with:

```bash
openssl rand -hex 32
```

If the two copies do not match, every webhook is rejected. That fails safe but
quietly: payments still work, but any payment where the customer closed the tab
before the page finished never gets marked paid. If you see that symptom, this
is the first thing to check.

**Step 3 — the webhook.** Razorpay dashboard → Settings → Webhooks → Add:

- URL: `https://www.iamratan.co.in/api/pay/webhook`
- Secret: invent a long random string; put the same value in
  `RAZORPAY_WEBHOOK_SECRET`
- Events: tick **`payment.captured`** and **`payment.failed`** only

**Step 4 — deploy**, so the new variables are picked up:

```bash
npx vercel --prod --yes
```

### Testing it without spending money

Razorpay has a test mode with its own key pair. Put the **test** keys in first,
place a real order on the site, and pay with the card numbers on
<https://razorpay.com/docs/payments/payments/test-card-details/>.

Then check all four of these, in order:

1. The Razorpay dashboard (in test mode) shows the payment as captured.
2. In Supabase → Table editor → `orders`, that order's `payment_state` says
   `paid` and `payment_ref` holds the `pay_…` id.
3. In `order_events`, there is a line reading "Payment received".
4. The site showed the customer a confirmation, not the WhatsApp handoff.

Then repeat with a **failing** test card and confirm the order still exists,
`payment_state` says `failed`, and the customer was offered WhatsApp.

Only when all of that passes, swap the test keys for the live ones and redeploy.
**Place one small real order and refund it** before announcing anything.

### When a payment goes wrong

| what you see | what it means | what to do |
|---|---|---|
| Order exists, `payment_state` still `pending` | they never finished paying | it is a live lead — chase it |
| Money taken, order says `pending` | verify and the webhook both failed | Vercel → Logs, search the order ref; the log line says `SETTLED AT RAZORPAY BUT NOT RECORDED` with the payment id |
| Customer sent to WhatsApp unexpectedly | the gateway did not answer | Vercel → Logs; look for `[pay]` |
| **Every** customer sent to WhatsApp, and `/api/pay/create` shows no invocations at all | something threw in the page before the gateway was ever asked | open the browser console on checkout and look for `[checkout] could not reach the gateway` — the reason is printed there |
| Every payment refused | wrong or expired keys | check the five variables, then redeploy |

Vercel → your project → **Logs** is the first place to look, always. Everything
this code prints is prefixed `[pay]`.

---

## 4b · Publishing a journal entry

The desk → **Shop front → Journal**. Write an entry, save it as a draft, and it
appears nowhere. Tick it live and it is on the site straight away.

The four essays that were written before this existed keep their own hand-built
pages, because each was laid out around its own photographs and pouring them
into a template would lose the thing that makes them worth reading. Their rows
carry a `path` and the journal index links to that file. Open one at the desk
and you can change its title, its kicker and its card, but not its words: those
live in the file.

Anything written at the desk has no file. It is laid out in the house style by
`journal-entry.html`, which reads the entry by its address. One paragraph to a
line with a blank line between them is the whole of the formatting, on purpose.

**A photograph has to exist before it can be named.** The Photograph field takes
a path like `images/journal/button.webp`; put the file in that folder and deploy
it first. Use **Shop front → Media** to see what is already there.

One limitation worth knowing: an entry written at the desk is drawn by the
browser, so a search engine that does not run JavaScript sees an empty page.
The four flagship essays are real HTML and do not have this problem. If a new
entry matters for search, it is worth turning into its own file.

---

## 5 · Running the shop day to day

- **Orders, products, discounts:** `admin.html` on the site, signed in with a
  Supabase account that is on the allow-list.
- **Raw data, if the desk cannot do it:** Supabase → Table editor.
- **Changing a price:** the `products` table. Nothing is hard-coded in a page;
  the site reads prices from there, and so does the payment code.
- **Adding a cloth:** Catalogue → The range → **Add a cloth**. It arrives hidden.
  Give it its photographs and its facts, then tick it onto the shop.
- **A cloth's fabric, weave, fit, collar, care:** click its name in The range.
  These print on the product page, and any one left empty simply does not
  appear there rather than showing as a blank row.

---

## 6 · What is deliberately *not* deployed

`.vercelignore` keeps working files off the live site: the earlier About page
versions, the design studies, the image masters, and every `.md` file including
this one. Those exclusions were added because all of it *was* being served.

**If you add a new working page, add it to `.vercelignore` in the same commit.**
Otherwise it is public the moment you deploy, at a URL anyone can guess.

---

## 7 · Still outstanding

Tracked in full in `LAUNCH.md` and `PENDING-FROM-CLIENT.md`. The ones that block
a real launch:

- Razorpay live keys, and the four-step test above
- GSTIN and the Grievance Officer name for the legal pages
- Real prices for every cloth
- The 19 legacy collar labels
- `sitemap.xml`
- An Android device test on a real handset

---

## 8 · If you are handed this and something is broken

1. **Vercel → Logs.** Nearly everything shows up here first.
2. **Was the last deploy the cause?** Vercel → Deployments → promote the
   previous one. Ten seconds, and it undoes anything.
3. **Is the database up?** <https://status.supabase.com>
4. **Is a change not showing?** You did not run `python3 iar-lab/stamp.py`.
   It is nearly always this.

### One trap that has already cost a day

Supabase answers an insert sent with `Prefer: return=minimal` with **201 and an
empty body** — not 204. Calling `.json()` on an empty body throws, and because
that throw happens inside a promise chain it does not look like an error, it
looks like the next step simply never ran.

Both places that talk to Supabase now read the body as text and parse it only if
there is any. **If you add a third, do the same.** Guarding against 204 alone is
not enough, because 204 is what a PATCH returns and 201 is what an insert
returns.

It hid for months in checkout, because the old code sent both success and
failure to WhatsApp and so the two were indistinguishable. It surfaced the day
payments were added, as "every order goes to WhatsApp".
