/* POST /api/pay/create   { ref }  ->  { key_id, order_id, amount, prefill }
 *
 * Turns an order that already exists in the database into a Razorpay order the
 * checkout modal can open.
 *
 * THE ONE RULE HERE: the amount comes from the database, never from the browser.
 * A customer can edit anything the page sends, so nothing the page sends may
 * decide what they pay. payment_intent() reads orders.total, which the
 * price_the_order() trigger computed from the products table when the order was
 * placed. The browser is asked only which order it means.
 */

import { rpc, razorpay, fail, ok, guard, handler } from './_bridge.mjs';

export default handler(async function (request) {
    const bad = guard(request);
    if (bad) return bad;

    let ref;
    try {
      ({ ref } = await request.json());
    } catch (err) {
      return fail(400, 'Could not read that request.', err);
    }
    if (typeof ref !== 'string' || !/^IAR-\d{6}-[A-Z0-9]{4}$/.test(ref)) {
      return fail(400, 'That order reference does not look right.');
    }

    let intent;
    try {
      /* returns table(...) so PostgREST hands back an array of one */
      const rows = await rpc('payment_intent', { p_ref: ref });
      intent = Array.isArray(rows) ? rows[0] : rows;
    } catch (err) {
      /* Already paid is not an error the customer should see as a failure. */
      if (String(err.message).includes('already paid')) {
        return fail(409, 'This order has already been paid for.', err);
      }
      /* Distinguish the three things that can go wrong here, because from the
         outside they look identical and one of them is a wrong token. */
      const why = /bad token/.test(err.message)      ? 'the payment bridge token does not match the database'
                : /no such order/.test(err.message)  ? 'that order is not in the database'
                : /no amount/.test(err.message)      ? 'that order has no total to charge'
                : 'the database did not answer';
      console.error('[pay] create failed for', ref, '·', why);
      return fail(502, 'We could not prepare the payment just now.', err);
    }
    if (!intent || !intent.amount_paise) {
      return fail(404, 'We could not find that order.');
    }

    let order;
    try {
      order = await razorpay('/orders', {
        amount: Number(intent.amount_paise),
        currency: 'INR',
        /* Razorpay caps the receipt at 40 characters and treats it as an
           idempotency key, so our own reference is exactly right: press Pay
           twice and the same Razorpay order comes back rather than two. */
        receipt: ref,
        notes: { ref }
      });
    } catch (err) {
      return fail(502, 'The payment provider did not answer. Please try again.', err);
    }

    return ok({
      key_id: process.env.RAZORPAY_KEY_ID,
      order_id: order.id,
      amount: order.amount,
      currency: order.currency,
      prefill: {
        name: intent.cust_name || '',
        email: intent.cust_email || '',
        contact: intent.cust_phone || ''
      }
    });
});
