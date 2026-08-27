/* I AM RATAN — the bits all three payment endpoints share.
 *
 * No dependencies. Node has crypto and fetch built in and Razorpay's API is
 * plain HTTP with basic auth, so a library here would be a node_modules tree to
 * save about nine lines.
 *
 * These are Web Standard handlers — export default { fetch(request) } — rather
 * than Node's (req, res). Two reasons, and the second one is the real one:
 *
 *   1. Nothing to configure. No helpers, no package.json, no runtime flag.
 *   2. request.text() hands back the bytes that arrived, untouched. Vercel
 *      parses JSON bodies for (req, res) handlers, and Razorpay signs the raw
 *      body — parse it and re-serialise it and the key order alone will break
 *      every webhook signature you ever check. Sidestepping that is worth more
 *      than the convenience of res.json().
 *
 * A file in /api whose name begins with _ is a utility, not a route, so this
 * one is bundled into the three endpoints and is not reachable on its own.
 */

import crypto from 'node:crypto';

/* Read a secret, or fail loudly now. A missing variable should break the first
   request with a clear line in the log, not halfway through someone's payment. */
export function env(name) {
  const v = process.env[name];
  if (!v) throw new Error('missing environment variable: ' + name);
  return v;
}

/* Calls one of the three security definer functions from RUN-THIS-SIXTEENTH.
   The token is what makes them privileged; the anon key only opens the door. */
export async function rpc(name, args) {
  const base = env('SUPABASE_URL').replace(/\/+$/, '');
  const key = env('SUPABASE_ANON_KEY');
  const res = await fetch(base + '/rest/v1/rpc/' + name, {
    method: 'POST',
    headers: {
      apikey: key,
      Authorization: 'Bearer ' + key,
      'Content-Type': 'application/json'
    },
    body: JSON.stringify({ p_token: env('PAYMENT_BRIDGE_TOKEN'), ...args })
  });
  const text = await res.text();
  if (!res.ok) {
    throw new Error('supabase ' + name + ' ' + res.status + ': ' + text.slice(0, 300));
  }
  try { return text ? JSON.parse(text) : null; } catch { return text; }
}

/* Razorpay's REST API: basic auth, key id as the user, secret as the password. */
export async function razorpay(path, body) {
  const auth = Buffer
    .from(env('RAZORPAY_KEY_ID') + ':' + env('RAZORPAY_KEY_SECRET'))
    .toString('base64');
  const res = await fetch('https://api.razorpay.com/v1' + path, {
    method: body ? 'POST' : 'GET',
    headers: { Authorization: 'Basic ' + auth, 'Content-Type': 'application/json' },
    body: body ? JSON.stringify(body) : undefined
  });
  const text = await res.text();
  let json = null;
  try { json = JSON.parse(text); } catch { /* leave it null and use the text */ }
  if (!res.ok) {
    const why = json?.error?.description || text.slice(0, 300);
    if (res.status === 401) {
      /* "Authentication failed" is the least useful message Razorpay returns —
         it is the same for a wrong secret, a mismatched pair, a live id with a
         test secret, and a stray newline picked up on copy. So say what CAN be
         said safely: the id is not a secret (it is handed to every browser),
         and whitespace is a yes or no. Never the secret itself. */
      const id  = process.env.RAZORPAY_KEY_ID  || '';
      const sec = process.env.RAZORPAY_KEY_SECRET || '';
      const mode = id.startsWith('rzp_test_') ? 'TEST'
                 : id.startsWith('rzp_live_') ? 'LIVE'
                 : 'UNRECOGNISED — a Razorpay key id starts rzp_test_ or rzp_live_';
      console.error(
        '[pay] Razorpay refused the credentials. What can be checked from here:' +
        '\n        key id mode      : ' + mode +
        '\n        key id length    : ' + id.length +
        '\n        secret length    : ' + sec.length +
        '\n        key id whitespace: ' + (id !== id.trim() ? 'YES — this alone breaks it' : 'no') +
        '\n        secret whitespace: ' + (sec !== sec.trim() ? 'YES — this alone breaks it' : 'no') +
        '\n        Both halves must come from the SAME key, generated together.'
      );
    }
    throw new Error('razorpay ' + path + ' ' + res.status + ': ' + why);
  }
  return json;
}

/* HMAC SHA256, hex, compared in constant time.
   Razorpay's own SDK compares with ===. This uses timingSafeEqual instead: a
   signature check that leaks how many leading characters were right is a
   signature check worth attacking. */
export function signatureMatches(payload, given, secret) {
  if (typeof given !== 'string' || given.length === 0) return false;
  const expected = crypto.createHmac('sha256', secret).update(payload).digest('hex');
  const a = Buffer.from(expected, 'utf8');
  const b = Buffer.from(given, 'utf8');
  if (a.length !== b.length) return false;   // timingSafeEqual throws on a length mismatch
  return crypto.timingSafeEqual(a, b);
}

/* The customer never sees a stack trace; the log is never without one. */
export function fail(status, publicMessage, err) {
  if (err) console.error('[pay]', publicMessage, '·', err?.message ?? err);
  return Response.json({ ok: false, error: publicMessage }, { status });
}

export function ok(payload) {
  return Response.json({ ok: true, ...payload });
}

/* Only POST, and only from our own pages. */
export function guard(request) {
  if (request.method !== 'POST') return fail(405, 'Use POST.');
  return null;
}

/* Wraps a handler so nothing can escape as an HTML error page. A customer must
   never see a stack trace, and Razorpay must never see an ambiguous 500 when
   the real answer is "this endpoint is not configured yet". */
export function handler(fn) {
  return {
    async fetch(request) {
      try {
        return await fn(request);
      } catch (err) {
        const m = /missing environment variable: (\w+)/.exec(err?.message || '');
        if (m) {
          /* Name the one that is missing. Six variables across two projects and
             three environments is a lot of places for one of them to be absent,
             and "not configured" sends whoever is setting it up hunting through
             all six. */
          console.error('[pay] NOT CONFIGURED — ' + m[1] + ' is not set on this project/environment');
          return fail(503, 'Card payment is not switched on yet.', null);
        }
        return fail(500, 'Something went wrong taking that payment.', err);
      }
    }
  };
}
