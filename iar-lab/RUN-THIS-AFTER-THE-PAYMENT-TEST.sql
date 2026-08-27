-- I AM RATAN — clearing up after the payment test
-- Run this whole file once in the Supabase SQL editor, when the ₹1 test order
-- has gone through and you are happy the four checks passed.
--
-- It does three things, in this order:
--   1. deletes the orders left behind by testing
--   2. deletes the ₹1 coupon
--   3. prints whatever unpaid orders remain, so you can look at them yourself
--
-- NOTHING PAID IS EVER TOUCHED. Every delete below carries
-- `payment_state is distinct from 'paid'`, so a real sale cannot be lost to
-- this file however carelessly it is run. order_events cascades, so the
-- timeline goes with the order and nothing is left orphaned.

-- 1 -------------------------------------------------------- the test orders --
-- Two ways in, because the testing was done from two sides: the throwaway
-- addresses used while wiring this up, and the specific references from the
-- days it was being debugged.
delete from public.orders
 where payment_state is distinct from 'paid'
   and (
     lower(email) in ('c@e.co', 'test@test.com')
     or ref in (
       'IAR-260822-T736',
       'IAR-260827-F590',
       'IAR-260827-P916',
       'IAR-260827-WQO5',
       'IAR-260827-89TZ'
     )
   );

-- 2 ------------------------------------------------------------ the coupon --
-- It expires on its own in 48 hours and is capped at five uses, but leaving a
-- code that reduces any basket to ₹1 lying about is not something to be relaxed
-- over. Delete it the moment the test passes.
delete from public.discounts where code like 'TEST%';

-- 3 ------------------------------------------------------------ what is left --
-- LAST on purpose: the Supabase editor shows only the final statement's result.
--
-- Every unpaid order still in the table. Some of these are real customers who
-- did not finish paying, and those are leads worth chasing, not rubbish. Look
-- before you delete anything else, and delete by ref:
--
--     delete from public.orders where ref in ('IAR-…','IAR-…');
select ref, name, email, phone, total, payment_state, status, placed_at
  from public.orders
 where payment_state is distinct from 'paid'
 order by placed_at desc;
