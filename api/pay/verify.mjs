/* POST /api/pay/verify
 *   { ref, razorpay_order_id, razorpay_payment_id, razorpay_signature }
 *   -> { ok: true, state: 'settled' | 'already' }
 *
 * The browser says the payment worked. This decides whether to believe it.
 *
 * Razorpay signs order_id|payment_id with the account's secret key, which only
 * this server holds. Recompute it and compare: if it matches, the payment is
 * real and Razorpay said so. If the check is skipped, anyone can call this
 * endpoint with an invented payment id and be marked paid — which is the whole
 * reason verification exists and the reason it cannot live in the page.
 */

import { rpc, signatureMatches, env, fail, ok, guard, handler } from './_bridge.mjs';

export default handler(async function (request) {
    const bad = guard(request);
    if (bad) return bad;

    let body;
    try {
      body = await request.json();
    } catch (err) {
      return fail(400, 'Could not read that request.', err);
    }

    const { ref, razorpay_order_id, razorpay_payment_id, razorpay_signature } = body || {};
    if (!ref || !razorpay_order_id || !razorpay_payment_id || !razorpay_signature) {
      return fail(400, 'That payment confirmation was incomplete.');
    }

    const good = signatureMatches(
      razorpay_order_id + '|' + razorpay_payment_id,
      razorpay_signature,
      env('RAZORPAY_KEY_SECRET')
    );

    if (!good) {
      /* Record the attempt and refuse. Worth a look in the log if it ever
         happens: a genuine customer cannot produce a bad signature. */
      console.error('[pay] signature rejected for', ref, razorpay_payment_id);
      try {
        await rpc('payment_failed', { p_ref: ref, p_reason: 'signature did not verify' });
      } catch (err) {
        console.error('[pay] could not record the rejection', err?.message);
      }
      return fail(400, 'We could not confirm that payment.');
    }

    try {
      const state = await rpc('payment_settle', {
        p_ref: ref,
        p_payment_id: razorpay_payment_id
      });
      return ok({ state });
    } catch (err) {
      /* The money is taken and we cannot write it down. The customer must not
         be told the payment failed — it did not. The webhook will settle this
         within seconds, and the log carries the reference to chase by hand. */
      console.error('[pay] SETTLED AT RAZORPAY BUT NOT RECORDED ·', ref,
                    razorpay_payment_id, '·', err?.message);
      return ok({ state: 'pending-record' });
    }
});
