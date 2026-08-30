# The two things in Supabase that only the dashboard can change

Everything else in the account flow is fixed and deployed. These two are
settings inside Supabase, and no amount of code in this repo can reach them.

---

## 1 · Where the email links come back to

**Supabase → Authentication → URL Configuration**

| field | value |
|---|---|
| Site URL | `https://www.iamratan.co.in/account.html` |
| Redirect URLs | `https://www.iamratan.co.in/**` |

The code now sends its own `redirect_to` on every signup and every password
reset, so the link lands on `account.html` regardless. **Redirect URLs is what
makes Supabase honour it** — an address not on that list is ignored and the
customer is sent to the Site URL instead. If Site URL is still a `vercel.app`
address or `localhost`, that is the error page they were landing on.

The `**` matters. `https://www.iamratan.co.in` alone matches the bare domain and
nothing under it.

---

## 2 · The emails themselves

**Supabase → Authentication → Emails**

Two templates. Open each, replace the whole message body, set the subject:

| template | file to paste | subject line |
|---|---|---|
| Confirm signup | `01-confirm-signup.html` | Confirm your account at I Am Ratan |
| Reset password | `02-reset-password.html` | Choose a new password at I Am Ratan |

Both keep `{{ .ConfirmationURL }}`, which is what Supabase swaps for the real
link. **Do not edit that token** — everything else is yours to change.

They are table-based with inline styles, and set in Georgia rather than the
house's Cormorant. That is deliberate: Gmail strips `<style>` blocks, Outlook
ignores modern layout, and no mail client can be relied on to fetch a webfont.
A serif that is present beats a serif that is asked for.

---

## 3 · The sender address — worth doing before launch

Out of the box these are sent by Supabase's own mail service. Two consequences:

- They arrive from a `supabase.io` address, not from the house.
- **The rate limit is a handful of messages per hour, project-wide.** This is
  almost certainly what made signup look broken while it was being tested: a few
  attempts in a row and every one after that fails.

Fix both by pointing Supabase at a real mail service:

**Authentication → Emails → SMTP Settings → Enable custom SMTP**

Any of Resend, Postmark, Brevo or Amazon SES will do; all have a free tier that
covers a shop this size. Sender: `no-reply@iamratan.co.in`, sender name
`I Am Ratan`. The domain needs its SPF and DKIM records added at the registrar,
which the provider gives you as two lines to paste.

Until that is done, signup works but is rate limited, and the email comes from
an address that is not the house.
