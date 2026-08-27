-- I AM RATAN — taking the money
-- Run this whole file once in the Supabase SQL editor.
--
-- WHY THIS IS A FUNCTION AND NOT A TABLE PERMISSION
--
-- The website carries the anon key, which anybody can read out of the page.
-- So anything the anon key is allowed to do, a stranger is allowed to do. If
-- marking an order paid were a plain UPDATE, a stranger could mark their own
-- order paid without paying for it.
--
-- The usual answer is Supabase's service_role key, which can do anything to
-- anything. This does not use it. These three functions are the only privileged
-- things the payment server can do, they each check a shared token first, and
-- the token lives in a table nobody can read. If it ever leaked, the worst it
-- can do is settle an order — not read the customer list, not drop a table.
--
-- The last step invents the token itself and prints it. Copy that one value
-- into Vercel as PAYMENT_BRIDGE_TOKEN. It belongs nowhere else — not in a
-- message, not in a document, not in the code.

-- ------------------------------------------------- what this file expects --
-- Everything it needs, created if an earlier file never ran. Safe to run twice.
alter table public.orders add column if not exists payment_method text default 'prepaid';
alter table public.orders add column if not exists payment_state  text default 'pending';
alter table public.orders add column if not exists payment_ref    text;

-- --------------------------------------------------------------- the token --
create table if not exists public.payment_bridge (
  id    boolean primary key default true check (id),   -- exactly one row, ever
  token text not null,
  set_at timestamptz default now()
);

alter table public.payment_bridge enable row level security;
-- No policy is created on purpose. With RLS on and no policy, nobody reaches
-- this table — not anon, not a signed-in customer, not the house. Only the
-- security definer functions below, which run as the table's owner.

-- ------------------------------------------------- what the order is worth --
-- Called by /api/pay/create before it asks Razorpay for anything.
--
-- The amount is read from the orders row, which the price_the_order() trigger
-- computed from the products table when the order was placed. The browser's
-- idea of the total never enters this. That is the whole point: a customer can
-- edit anything they send, so nothing they send may decide what they pay.
create or replace function public.payment_intent(p_ref text, p_token text)
returns table (amount_paise bigint, cust_name text, cust_email text, cust_phone text)
language plpgsql security definer set search_path = public as $$
declare o record;
begin
  if p_token is null or p_token <> (select token from public.payment_bridge) then
    raise exception 'payment bridge: bad token';
  end if;

  select * into o from public.orders where ref = p_ref;
  if not found then
    raise exception 'payment bridge: no such order %', p_ref;
  end if;
  if o.payment_state = 'paid' then
    raise exception 'payment bridge: order % is already paid', p_ref;
  end if;
  if coalesce(o.total, 0) <= 0 then
    raise exception 'payment bridge: order % has no amount to collect', p_ref;
  end if;

  -- Razorpay counts in paise, and will not take a fraction of one
  return query select (round(o.total * 100))::bigint, o.name, o.email, o.phone;
end $$;

-- ------------------------------------------------------- the money arrived --
-- Called by /api/pay/verify once the signature checks out, and again by
-- /api/pay/webhook if the customer closed the tab before verify ran. Writing
-- twice is normal and must be harmless, so this is idempotent: if the order is
-- already paid it returns quietly rather than raising or double-stamping.
create or replace function public.payment_settle(
  p_ref text, p_payment_id text, p_token text)
returns text
language plpgsql security definer set search_path = public as $$
declare o record;
begin
  if p_token is null or p_token <> (select token from public.payment_bridge) then
    raise exception 'payment bridge: bad token';
  end if;

  select * into o from public.orders where ref = p_ref;
  if not found then
    raise exception 'payment bridge: no such order %', p_ref;
  end if;

  if o.payment_state = 'paid' then
    return 'already';                     -- the webhook and the browser raced
  end if;

  update public.orders
     set payment_state = 'paid',
         payment_ref   = p_payment_id,
         updated_at    = now()
   where id = o.id;

  insert into public.order_events (order_id, stage, note)
  values (o.id, o.status, 'Payment received · ' || p_payment_id);

  return 'settled';
end $$;

-- ------------------------------------------------------------ it went wrong --
-- Recorded so the house can chase it. The order itself is left alone: a failed
-- payment is not a cancelled order, and the customer may simply try again.
create or replace function public.payment_failed(
  p_ref text, p_reason text, p_token text)
returns text
language plpgsql security definer set search_path = public as $$
declare o record;
begin
  if p_token is null or p_token <> (select token from public.payment_bridge) then
    raise exception 'payment bridge: bad token';
  end if;

  select * into o from public.orders where ref = p_ref;
  if not found then return 'no order'; end if;
  if o.payment_state = 'paid' then return 'already paid'; end if;

  update public.orders
     set payment_state = 'failed', updated_at = now()
   where id = o.id;

  insert into public.order_events (order_id, stage, note)
  values (o.id, o.status, 'Payment did not complete · ' || coalesce(p_reason, 'no reason given'));

  return 'noted';
end $$;

-- Only the server ever calls these, and it holds the token. anon is granted
-- execute because that is the role the server's key carries — the token, not
-- the grant, is what actually guards them.
grant execute on function public.payment_intent(text, text)        to anon, authenticated;
grant execute on function public.payment_settle(text, text, text)  to anon, authenticated;
grant execute on function public.payment_failed(text, text, text)  to anon, authenticated;

-- --------------------------------------------------------------- the token --
-- Postgres invents it, so it is never typed, never pasted into a chat window,
-- and never written down anywhere but here and Vercel. Two UUIDs with the
-- dashes taken out: 64 hex characters, and no extension needed.
--
-- Running this file again REPLACES the token, which breaks payments until
-- Vercel is updated to match. That is deliberate — if you ever think it leaked,
-- re-run this file and paste the new value into Vercel.
insert into public.payment_bridge (id, token)
values (true, replace(gen_random_uuid()::text, '-', '') ||
               replace(gen_random_uuid()::text, '-', ''))
on conflict (id) do update set token = excluded.token, set_at = now();

-- ---------------------------------------------------- did it all work? --
-- Every row should say ok. Anything else and payments will not work properly.
select 'payment columns'  as checked,
       case when count(*) = 3 then 'ok' else 'MISSING — see the top of this file' end as result
  from information_schema.columns
 where table_name = 'orders'
   and column_name in ('payment_state','payment_ref','payment_method')
union all
select 'the three functions',
       case when count(*) = 3 then 'ok' else 'MISSING — re-run this file' end
  from pg_proc where proname in ('payment_intent','payment_settle','payment_failed')
union all
select 'token stored',
       case when length(token) = 64 then 'ok' else 'WRONG LENGTH' end
  from public.payment_bridge
union all
-- The one that actually protects the money: without this trigger the total is
-- whatever the browser said it was, and a stranger can pay one rupee.
select 'server-side pricing',
       case when count(*) > 0 then 'ok'
            else 'MISSING — run RUN-THIS-EIGHTH.sql first, or the price is not safe' end
  from pg_trigger where tgname = 'orders_pricing'
union all
select 'nobody can read the token',
       case when count(*) = 0 then 'ok' else 'A POLICY EXISTS — remove it' end
  from pg_policies where tablename = 'payment_bridge';

-- ------------------------------------------------------------- COPY THIS --
-- LAST on purpose. The Supabase SQL editor shows only the result of the final
-- statement, so anything printed before the checks above would be replaced by
-- them and never seen.
--
-- This one value goes into Vercel as PAYMENT_BRIDGE_TOKEN. Nowhere else — not
-- in a message, not in a document, not in the code.
--
-- Lost it? This is safe to run on its own at any time:
--     select token from public.payment_bridge;
select token as "PAYMENT_BRIDGE_TOKEN — copy this into Vercel"
  from public.payment_bridge;
