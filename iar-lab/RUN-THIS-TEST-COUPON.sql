-- I AM RATAN — a coupon that leaves ₹1 to pay, for testing a real payment
--
-- ONLY needed for the LIVE test. In Razorpay's test mode no money moves at all,
-- so a normal ₹2,999 order and a test card costs nothing and this is pointless.
-- This exists for the one real order you place with live keys before launch,
-- so that order costs a rupee instead of three thousand.
--
-- ---------------------------------------------------------------------------
-- WHY IT IS BUILT THE WAY IT IS
--
-- discount_value() works from the basket SUBTOTAL only. The applies_to and
-- only_slugs columns exist but nothing reads them yet, so a coupon cannot be
-- tied to one shirt — whatever this gives off, it gives off ANY basket. That
-- makes a careless ₹1 coupon a genuine hole: find the code, buy anything for a
-- rupee.
--
-- So it is fenced four ways:
--
--   min_spend    it does nothing to a basket under one shirt's price, so it
--                cannot be used to make a cheap thing free
--   usage_limit  five uses in total, then it is dead. Five and not one because
--                a failed payment still counts, and a test may need retries
--   ends_at      48 hours, then it is dead regardless
--   the name     random, so it cannot be guessed
--
-- Even so: DELETE IT once the test passes. The last line of this file does it.
-- ---------------------------------------------------------------------------

-- Uses the cheapest shirt on the site, so the discount is as small as it can
-- be while still leaving exactly ₹1. Nothing here is hard-coded to a slug: if
-- prices change, re-run this and it picks the right amount again.
with cheapest as (
  select slug, name, price
    from public.products
   where visible = true and price > 1
   order by price asc, slug asc
   limit 1
),
made as (
  insert into public.discounts
    (code, kind, value, min_spend, usage_limit, per_customer, ends_at, live, note)
  select
    'TEST' || upper(substr(replace(gen_random_uuid()::text, '-', ''), 1, 8)),
    'flat',
    c.price - 1,          -- leaves exactly one rupee on a basket of one shirt
    c.price,              -- and does nothing at all below that
    5,
    null,                 -- null, not 1: the same tester must be able to retry
    now() + interval '48 hours',
    true,
    'Payment test. Delete after use. Made ' || to_char(now(), 'DD Mon YYYY HH24:MI')
  from cheapest c
  returning code, value, min_spend, ends_at
)
select
  m.code                                   as "the code to type at checkout",
  c.name                                   as "order this shirt",
  '₹' || c.price                           as "its price",
  '₹' || (c.price - m.value)               as "what you will actually pay",
  to_char(m.ends_at, 'DD Mon HH24:MI')     as "dies at",
  5                                        as "uses allowed"
from made m, cheapest c;

-- ---------------------------------------------------------------------------
-- WHEN THE TEST IS DONE — run this. Do not leave it to expire on its own.
--
--     delete from public.discounts where code like 'TEST%';
--
-- To see what test coupons exist right now:
--
--     select code, value, uses, usage_limit, ends_at, live
--       from public.discounts where code like 'TEST%';
-- ---------------------------------------------------------------------------
