-- Clear the development traffic so the numbers start from real customers.
--
-- WHY THERE IS ANYTHING TO CLEAR
-- assets/track.js had no host check until 19 Aug 2026, so every page load while
-- the site was being built wrote to this same production project: local runs on
-- localhost:8080, preview deploys, and the verification passes. None of it is a
-- customer. track.js now counts only www.iamratan.co.in, so this is a one-off.
--
-- Run in the Supabase SQL editor. Read section 3 before running it.

-- 1 ---------------------------------------------------------------- look first
-- What is actually in there, before anything is removed.
select 'events' as tbl, count(*) as rows,
       min(created_at) as first, max(created_at) as last
from public.events;

select name, count(*) as n
from public.events
group by name
order by n desc;

-- 2 ------------------------------------------------------------- clear events
-- Safe to run in full: every row predates the host check, so all of it is ours.
-- The table keeps its shape, its policies and its grants; only rows go.
delete from public.events;

-- 3 -------------------------------------------------------------- orders: LOOK
-- NOT deleted automatically. An order is a person and money, and a real one
-- placed during the launch window would be indistinguishable from a test at a
-- glance. Run this, read the list, and delete by ref only if you recognise the
-- row as your own testing.
select id, ref, name, email, phone, total, status, placed_at
from public.orders
order by placed_at desc;

-- Then, for each one you are sure is a test, uncomment and set the ref.
-- The line items are a jsonb column on the order itself, so they go with it;
-- order_events is a real table but cascades on delete, so one statement is
-- enough and there is nothing left orphaned.
-- delete from public.orders where ref in ('REF-ONE','REF-TWO');

-- 4 ------------------------------------------------------------------- confirm
select 'events after' as tbl, count(*) from public.events;
