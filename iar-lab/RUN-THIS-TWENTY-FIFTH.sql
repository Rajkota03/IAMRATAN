-- I AM RATAN — a cancelled order could still be paid for
--
-- Found by cancelling a test order and then asking the payment endpoint about
-- it: it offered to take ₹11,998 for an order the house had just cancelled and
-- whose stock had already gone back on the rack.
--
-- The sequence that costs real money: a customer reaches the checkout, the
-- house cancels the order at the desk for whatever reason, the customer's tab
-- is still open, they press pay. Money is taken for something nobody is making,
-- and the shirt they paid for is back on the shelf for somebody else to buy.
--
-- payment_intent() already refuses an order that is paid, and one with no
-- amount to collect. It never looked at the status.

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
  if o.status = 'cancelled' then
    raise exception 'payment bridge: order % has been cancelled', p_ref;
  end if;
  if coalesce(o.total, 0) <= 0 then
    raise exception 'payment bridge: order % has no amount to collect', p_ref;
  end if;

  return query select (round(o.total * 100))::bigint, o.name, o.email, o.phone;
end $$;

-- ------------------------------------------------------- if it happens anyway --
-- Blocking the intent stops the ordinary case. It cannot stop a payment already
-- in flight when the house cancels — the Razorpay window is open, the money
-- moves, and the webhook arrives afterwards.
--
-- That payment must STILL be recorded. The money is real and refusing to write
-- it down would leave the house owing a refund it has no record of. So it is
-- settled as normal and the timeline is made to say loudly what happened.
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
  values (o.id,
          o.status,
          case when o.status = 'cancelled'
               then 'PAID AFTER CANCELLATION — refund this. ' || p_payment_id
               else 'Payment received · ' || p_payment_id end);

  return case when o.status = 'cancelled' then 'settled-but-cancelled' else 'settled' end;
end $$;

-- ---------------------------------------------------------------- did it work --
select 'a cancelled order is refused' as checked,
       case when exists (
         select 1 from pg_proc
          where proname = 'payment_intent'
            and prosrc like '%has been cancelled%')
       then 'ok' else 'MISSING' end as result
union all
select 'a late payment is still recorded',
       case when exists (
         select 1 from pg_proc
          where proname = 'payment_settle'
            and prosrc like '%PAID AFTER CANCELLATION%')
       then 'ok' else 'MISSING' end;
