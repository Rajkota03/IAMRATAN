-- I AM RATAN — two grants nobody ever used, and a stranger could
--
-- Found by asking a different question than before: not "what can a stranger
-- READ" but "what can a stranger WRITE". Everything is properly shut except
-- three tables the shop genuinely needs — orders, enquiries, carts — and two
-- more that no page has ever written to.
--
-- A THIRD thing was found after this file was first written, and is fixed in
-- the code rather than here: /api/pay/create was returning the customer's name,
-- email and phone to anyone who posted an order reference at it. A reference is
-- not a secret — it is quoted in emails, read out on the telephone, and since
-- the confirmation screen was made refreshable it sits in the address bar. The
-- endpoint now returns only what Razorpay needs to open its window, and the
-- page prefills the customer's details from the form they have just filled in.
--
-- ONE · order_events. A stranger could POST a timeline row onto ANY order by
-- guessing its id, which is a small integer. Confirmed against the live
-- database: ids 3, 5 and 8 all accepted a row reading "SECURITY PROBE".
--
-- Those rows are shown to the customer on their account page. So this is not
-- graffiti in a table nobody reads, it is text a stranger can put in front of
-- somebody else's customer — "delivered" on an order still being cut, or a
-- telephone number to ring about a payment that never failed.
--
-- The policy was written believing the browser records the first line of the
-- timeline. It does not, and the comment three lines below it in
-- RUN-THIS-SEVENTH.sql says so outright: "Writing the timeline is the
-- database's job, not the browser's." note_stage() is a SECURITY DEFINER
-- trigger, so it runs as the owner and never needed this grant.
--
-- TWO · returns. Same shape, lower stakes. A stranger can file return requests,
-- including against order references that do not exist, and they land on the
-- desk looking like real ones. No customer-facing page files a return — the
-- feature is admin-only today — so this grant has no caller either.
--
-- Neither change can break anything, because in both cases nothing was calling
-- them. The triggers and the desk keep working exactly as before.

drop policy if exists "anyone may open a timeline" on public.order_events;
drop policy if exists "anyone may ask" on public.returns;

-- --------------------------------------------------------------- tidying up --
-- The rows this test wrote, and the orders it made proving the pricing fix.
delete from public.order_events where note = 'SECURITY PROBE';
delete from public.returns where note = 'SECURITY PROBE';
delete from public.orders
 where payment_state is distinct from 'paid'
   and lower(email) in ('security-test@example.com','t@e.co','c@e.co',
                        'customer@example.com','priya.sharma@example.com');

-- ------------------------------------------------------------ did it work? --
select 'a stranger can write a timeline row' as checked,
       case when count(*) = 0 then 'ok — shut'
            else 'STILL OPEN' end as result
  from pg_policies
 where tablename = 'order_events' and 'anon' = any(roles) and cmd = 'INSERT'
union all
select 'a stranger can file a return',
       case when count(*) = 0 then 'ok — shut' else 'STILL OPEN' end
  from pg_policies
 where tablename = 'returns' and 'anon' = any(roles) and cmd = 'INSERT'
union all
select 'the shop can still take an order',
       case when count(*) = 1 then 'ok' else 'BROKEN — checkout will fail' end
  from pg_policies
 where tablename = 'orders' and 'anon' = any(roles) and cmd = 'INSERT'
union all
select 'the timeline trigger is still there',
       case when count(*) = 1 then 'ok' else 'MISSING' end
  from pg_trigger where tgname = 'orders_timeline'
union all
select 'probe rows cleared',
       case when count(*) = 0 then 'ok' else 'SOME LEFT' end
  from public.order_events where note = 'SECURITY PROBE';
