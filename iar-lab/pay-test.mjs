/* Exercises the three payment endpoints without touching Razorpay, Supabase,
 * or any money. Razorpay and PostgREST are replaced with a stub that records
 * what was asked of them, so the tests can assert on the ONE thing that matters
 * most: that the amount charged comes from the database and not from the page.
 *
 *     node iar-lab/pay-test.mjs
 */

process.env.SUPABASE_URL = 'https://stub.supabase.co';
process.env.SUPABASE_ANON_KEY = 'stub-anon-key';
process.env.PAYMENT_BRIDGE_TOKEN = 'stub-bridge-token';
process.env.RAZORPAY_KEY_ID = 'rzp_test_stub';
process.env.RAZORPAY_KEY_SECRET = 'stub_secret_value';
process.env.RAZORPAY_WEBHOOK_SECRET = 'stub_webhook_secret';

import crypto from 'node:crypto';

const calls = [];
let orderTotalPaise = 499000;          /* what the DATABASE says: ₹4,990 */
let alreadyPaid = false;

globalThis.fetch = async (url, opts = {}) => {
  const body = opts.body ? JSON.parse(opts.body) : null;
  calls.push({ url: String(url), body });

  if (String(url).includes('/rpc/payment_intent')) {
    if (body.p_token !== process.env.PAYMENT_BRIDGE_TOKEN)
      return new Response('bad token', { status: 400 });
    if (alreadyPaid)
      return new Response('payment bridge: order is already paid', { status: 400 });
    return Response.json([{ amount_paise: orderTotalPaise, cust_name: 'A Buyer',
                            cust_email: 'a@b.co', cust_phone: '9999999999' }]);
  }
  if (String(url).includes('/rpc/payment_settle')) { alreadyPaid = true; return Response.json('settled'); }
  if (String(url).includes('/rpc/payment_failed')) return Response.json('noted');
  if (String(url).includes('api.razorpay.com/v1/orders'))
    return Response.json({ id: 'order_STUB1', amount: body.amount, currency: body.currency });

  return new Response('unexpected ' + url, { status: 500 });
};

const create  = (await import('../api/pay/create.mjs')).default;
const verify  = (await import('../api/pay/verify.mjs')).default;
const webhook = (await import('../api/pay/webhook.mjs')).default;

let pass = 0, failed = 0;
function t(name, cond) {
  if (cond) { pass++; console.log('  ok   ' + name); }
  else { failed++; console.log('  FAIL ' + name); }
}
const post = (body, headers = {}) => new Request('https://x/', {
  method: 'POST', headers: { 'Content-Type': 'application/json', ...headers },
  body: typeof body === 'string' ? body : JSON.stringify(body)
});
const REF = 'IAR-260822-AB12';

console.log('\ncreate — turning an order into a Razorpay order');
{
  calls.length = 0;
  const r = await create.fetch(post({ ref: REF }));
  const j = await r.json();
  t('it answers 200', r.status === 200);
  t('it returns the Razorpay order id', j.order_id === 'order_STUB1');
  const sent = calls.find(c => c.url.includes('razorpay'));
  t('THE AMOUNT COMES FROM THE DATABASE, not the page', sent.body.amount === orderTotalPaise);
  t('it is sent in paise as an integer', Number.isInteger(sent.body.amount));
  t('the reference is the receipt, so a double press is idempotent', sent.body.receipt === REF);
  t('the reference travels in notes for the webhook', sent.body.notes.ref === REF);
  t('the secret key is never returned to the page', !JSON.stringify(j).includes('stub_secret_value'));
}
{
  const r = await create.fetch(post({ ref: 'not-a-reference' }));
  t('a malformed reference is refused', r.status === 400);
  const r2 = await create.fetch(new Request('https://x/', { method: 'GET' }));
  t('GET is refused', r2.status === 405);
  /* the page tries to pay 1 rupee for a 4,990 rupee order */
  calls.length = 0;
  await create.fetch(post({ ref: REF, amount: 100, total: 1 }));
  const sent = calls.find(c => c.url.includes('razorpay'));
  t('an amount injected by the page is ignored', sent.body.amount === orderTotalPaise);
}

console.log('\nverify — deciding whether to believe the browser');
{
  alreadyPaid = false;
  const sig = crypto.createHmac('sha256', process.env.RAZORPAY_KEY_SECRET)
                    .update('order_STUB1|pay_STUB1').digest('hex');
  const good = await verify.fetch(post({ ref: REF, razorpay_order_id: 'order_STUB1',
    razorpay_payment_id: 'pay_STUB1', razorpay_signature: sig }));
  t('a genuine signature settles the order', (await good.json()).ok === true);

  alreadyPaid = false;
  const bad = await verify.fetch(post({ ref: REF, razorpay_order_id: 'order_STUB1',
    razorpay_payment_id: 'pay_FORGED', razorpay_signature: sig }));
  t('a forged payment id is refused', bad.status === 400);

  const none = await verify.fetch(post({ ref: REF }));
  t('a confirmation with no signature is refused', none.status === 400);
}

console.log('\nwebhook — the safety net');
{
  alreadyPaid = false;
  const raw = JSON.stringify({ event: 'payment.captured',
    payload: { payment: { entity: { id: 'pay_HOOK', notes: { ref: REF } } } } });
  const sig = crypto.createHmac('sha256', process.env.RAZORPAY_WEBHOOK_SECRET)
                    .update(raw).digest('hex');

  const r = await webhook.fetch(post(raw, { 'x-razorpay-signature': sig }));
  t('a signed webhook is accepted', r.status === 200);

  const unsigned = await webhook.fetch(post(raw, { 'x-razorpay-signature': 'deadbeef' }));
  t('an unsigned webhook is refused', unsigned.status === 400);

  const again = await webhook.fetch(post(raw, { 'x-razorpay-signature': sig }));
  t('arriving twice is harmless', again.status === 200);

  const failRaw = JSON.stringify({ event: 'payment.failed',
    payload: { payment: { entity: { id: 'pay_X', notes: { ref: REF },
                                    error_description: 'card declined' } } } });
  const failSig = crypto.createHmac('sha256', process.env.RAZORPAY_WEBHOOK_SECRET)
                        .update(failRaw).digest('hex');
  const f = await webhook.fetch(post(failRaw, { 'x-razorpay-signature': failSig }));
  t('a failure is recorded, not ignored', f.status === 200);
}

console.log('\n' + pass + ' passed, ' + failed + ' failed\n');
process.exit(failed ? 1 : 0);
