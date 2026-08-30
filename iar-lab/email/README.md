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

## 2 · SMTP FIRST — the templates are locked until it is done

**Supabase will not let you edit the email templates until custom SMTP is set
up.** The Subject and Body fields are read-only and the screen says so: "Set up
custom SMTP to edit their subject and body." There is no way round it and no
code change that helps. So this is step one, not step three.

It also fixes the other half of the problem. Supabase's built-in mail service
sends from `noreply@mail.app.supabase.io` and is capped at a handful of messages
an hour, project-wide. That cap is almost certainly what made signup look
broken while it was being tested.

### 2a · A mail provider

Resend is the least trouble: free to 3,000 messages a month, which is far more
than this shop will send. Brevo and Amazon SES also work and are cheaper at
volume; none of that matters yet.

1. Sign up at <https://resend.com>.
2. **Domains → Add Domain →** `iamratan.co.in`.
3. Resend prints two or three DNS records (SPF and DKIM, sometimes DMARC).
   Leave that page open.

### 2b · The DNS records, at the registrar

The domain is at Hostinger: **hPanel → Domains → DNS Zone Editor**. Add each
record Resend gave you, exactly — type, name and value. Then press Verify back
in Resend. It is usually minutes; it can be an hour.

Until this verifies, mail from the domain will be marked as spam or refused
outright. It is not optional.

### 2c · The key

Resend → **API Keys → Create API Key**. Copy it once; it is not shown again.
That string is the SMTP password.

### 2d · Back in Supabase

**Authentication → Emails → Set up SMTP.** Resend shows the exact values on its
own SMTP page — use those rather than these if they differ:

| field | value |
|---|---|
| Host | `smtp.resend.com` |
| Port | `465` |
| Username | `resend` |
| Password | the API key from 2c |
| Sender email | `no-reply@iamratan.co.in` |
| Sender name | `I Am Ratan` |

---

## 3 · Then the templates unlock

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

## 4 · Test it

Register once with a real address. You should get a letter from
`no-reply@iamratan.co.in`, in the house's colours, and following its link should
land on the account page reading "You are in".
