/* POST /api/pay/webhook   — Razorpay calls this, not the browser.
 *
 * THE SAFETY NET. /api/pay/verify only runs if the customer's browser is still
 * open when the payment finishes. Phones lock, tabs get closed, trains go into
 * tunnels. Razorpay tells this endpoint regardless, so an order cannot be paid
 * for and left sitting in the house's list as unpaid.
 *
 * Two things this must get right:
 *
 *   RAW BODY. The signature is computed over the exact bytes Razorpay sent.
 *   request.text() returns them untouched. Parse the JSON first and re-serialise
 *   it and the key order alone will break every signature.
 *
 *   IDEMPOTENCE. Razorpay retries until it gets a 2xx, and verify may well have
 *   settled the same payment a second earlier. payment_settle() returns
 *   'already' rather than raising, so arriving twice is uneventful.
 *
 * Always answer 200 once the signature is good, even if the write failed —
 * otherwise Razorpay retries for hours against a database that is still down.
 * A rejected signature gets 400, which is the one case worth retrying against.
 */

import { rpc, signatureMatches, env, fail, handler } from './_bridge.mjs';

export default handler(async function (request) {
    if (request.method !== 'POST') return fail(405, 'Use POST.');

    const raw = await request.text();
    const signature = request.headers.get('x-razorpay-signature');

    if (!signatureMatches(raw, signature, env('RAZORPAY_WEBHOOK_SECRET'))) {
      console.error('[pay] webhook signature rejected');
      return fail(400, 'bad signature');
    }

    let event;
    try {
      event = JSON.parse(raw);
    } catch (err) {
      console.error('[pay] webhook body was not JSON', err?.message);
      return Response.json({ ok: true, ignored: 'unreadable' });
    }

    const kind = event?.event;
    const payment = event?.payload?.payment?.entity;

    /* The reference travels in notes, which we set when the order was created,
       and Razorpay hands back on the payment. receipt is the fallback. */
    const ref = payment?.notes?.ref || event?.payload?.order?.entity?.receipt;

    if (!ref) {
      console.error('[pay] webhook', kind, 'carried no reference');
      return Response.json({ ok: true, ignored: 'no reference' });
    }

    try {
      if (kind === 'payment.captured') {
        const state = await rpc('payment_settle', { p_ref: ref, p_payment_id: payment.id });
        console.log('[pay] webhook settled', ref, state);
      } else if (kind === 'payment.failed') {
        const why = payment?.error_description || 'declined';
        await rpc('payment_failed', { p_ref: ref, p_reason: why });
        console.log('[pay] webhook recorded a failure', ref, why);
      }
      /* Anything else — authorized, refunds, settlements — is acknowledged and
         ignored. Subscribe to only what is handled and this stays quiet. */
    } catch (err) {
      console.error('[pay] webhook could not write', kind, ref, '·', err?.message);
      /* Deliberately still a 200. See the note at the top. */
    }

    return Response.json({ ok: true });
});
