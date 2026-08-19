-- Lets a signed-in customer read their OWN orders, and nothing else.
--
-- Until this runs, account.html signs people in correctly and shows an empty
-- order list, because the orders table is admins-only and refuses the read.
-- That is the safe failure: a customer sees nothing rather than someone else's
-- order. Run it in the Supabase SQL editor.
--
-- HOW IT SITS WITH WHAT IS ALREADY THERE
-- orders already carries two policies: "anyone may place an order" (insert, to
-- anon) and "admins only" (all, to authenticated, gated on the admins table).
-- Postgres ORs permissive policies together, so adding a select policy for
-- authenticated does not weaken either: the desk keeps full access through its
-- own policy, anonymous visitors keep insert and nothing else, and a signed-in
-- customer gains select on their own rows only.
--
-- WHY THIS IS SAFE
-- The match is on auth.jwt()->>'email', which Supabase signs. A customer cannot
-- edit it, and asking for another address returns nothing rather than an error.
-- Read only: no insert, update or delete is granted here, so an account cannot
-- change an order, cancel one, or write a row that looks like an order.

alter table public.orders enable row level security;

drop policy if exists "a customer reads their own orders" on public.orders;
create policy "a customer reads their own orders"
  on public.orders for select to authenticated
  using (
    email is not null
    and lower(email) = lower(auth.jwt()->>'email')
  );

-- The same for the order timeline, so "where has it reached" works.
drop policy if exists "a customer reads their own order events" on public.order_events;
create policy "a customer reads their own order events"
  on public.order_events for select to authenticated
  using (
    exists (
      select 1 from public.orders o
      where o.id = order_events.order_id
        and o.email is not null
        and lower(o.email) = lower(auth.jwt()->>'email')
    )
  );

-- Check. Run in the SQL editor there is no signed-in user, so anything using
-- auth.jwt() would return nothing and look like a failure whether it worked or
-- not. Listing the policies is the check that actually means something here:
-- expect the two new ones alongside the existing "admins only".
select tablename, policyname, cmd, roles
from pg_policies
where schemaname = 'public'
  and tablename in ('orders','order_events')
order by tablename, policyname;

-- --------------------------------------------------------------- cleanup
-- Two accounts were created while testing this build. Remove them.
delete from auth.users where email like 'preview.check.%@iamratan.co.in';
