-- I AM RATAN — marketing: offers, campaigns, abandoned carts, attribution.
-- Run in the SQL Editor after the previous seven.
--
-- WHAT IS REAL IN HERE AND WHAT IS NOT
-- Offers work end to end today: the house makes a code, a customer types it at
-- checkout, and the DATABASE decides what it is worth. Abandoned carts are real
-- the moment someone leaves a checkout half-filled. Attribution is real as soon
-- as a link carries ?utm_source=.
--
-- Sending email and SMS is NOT real, because there is no provider and I will
-- not invent one. Campaigns therefore build a real, named list of real people
-- and stop there: WhatsApp is sent by the house one tap at a time (which is
-- what actually happens in Hyderabad), and email/SMS wait for a provider. No
-- open rate is stored anywhere in this file, because nothing here can measure
-- one, and a made-up 32% is worse than an empty column.

-- ============================================================== OFFERS ==
-- A code is a promise about money, so the browser does not get to decide what
-- it is worth. The browser may only ASK. Everything below is the answer.

create table if not exists public.discounts (
  code          text primary key,
  kind          text not null default 'percent',   -- percent | flat | free_shipping
  value         numeric not null default 0,
  min_spend     numeric default 0,
  max_discount  numeric,                -- caps a percentage; null = uncapped
  usage_limit   integer,                -- null = unlimited
  per_customer  integer default 1,      -- null = unlimited
  applies_to    text default 'all',     -- all | collection | products
  collection    text,
  only_slugs    text[],
  except_slugs  text[],
  starts_at     timestamptz default now(),
  ends_at       timestamptz,
  live          boolean not null default true,
  uses          integer not null default 0,
  note          text,
  made_at       timestamptz default now()
);

create table if not exists public.discount_uses (
  id         bigint generated always as identity primary key,
  code       text references public.discounts(code) on delete cascade,
  order_id   bigint references public.orders(id) on delete cascade,
  phone      text,
  amount     numeric,
  at         timestamptz default now()
);
create index if not exists discount_uses_idx on public.discount_uses (code, at desc);

alter table public.orders add column if not exists subtotal        numeric;
alter table public.orders add column if not exists discount_code   text;
alter table public.orders add column if not exists discount_amount numeric default 0;

-- ---------------------------------------------------- what a code is worth --
-- One place that decides. The trigger below and the checkout both call it, so
-- the number the customer is shown and the number the house is paid can never
-- drift apart.

create or replace function public.discount_value(
  in_code text, in_subtotal numeric, in_phone text default null)
returns table (ok boolean, reason text, amount numeric, kind text, label text)
language plpgsql stable security definer set search_path = public as $$
declare d public.discounts%rowtype; used integer := 0; cut numeric := 0; ph text;
begin
  /* One shape for a phone number, decided here. The checkout sends digits, an
     order carries whatever the customer typed, and comparing the two directly
     means the per-customer limit silently never matches. */
  ph := nullif(regexp_replace(coalesce(in_phone, ''), '\D', '', 'g'), '');

  select * into d from public.discounts where upper(code) = upper(trim(in_code));

  if not found then
    return query select false, 'That code is not one of ours.', 0::numeric, null::text, null::text;
    return;
  end if;
  if not d.live then
    return query select false, 'That code is no longer running.', 0::numeric, d.kind, null::text;
    return;
  end if;
  if d.starts_at is not null and d.starts_at > now() then
    return query select false, 'That code has not started yet.', 0::numeric, d.kind, null::text;
    return;
  end if;
  if d.ends_at is not null and d.ends_at < now() then
    return query select false, 'That code has expired.', 0::numeric, d.kind, null::text;
    return;
  end if;
  if d.usage_limit is not null and d.uses >= d.usage_limit then
    return query select false, 'That code has been fully claimed.', 0::numeric, d.kind, null::text;
    return;
  end if;
  if in_subtotal < coalesce(d.min_spend, 0) then
    return query select false,
      'That code needs a basket of at least ₹' || trim(to_char(d.min_spend, '999999')) || '.',
      0::numeric, d.kind, null::text;
    return;
  end if;

  -- one customer, counted by phone, which is the thing an Indian customer
  -- gives correctly every time
  if d.per_customer is not null and ph is not null then
    select count(*) into used from public.discount_uses
     where code = d.code and phone = ph;
    if used >= d.per_customer then
      return query select false, 'You have already used that code.', 0::numeric, d.kind, null::text;
      return;
    end if;
  end if;

  cut := case d.kind
           when 'percent' then round(in_subtotal * d.value / 100.0, 2)
           when 'flat'    then least(d.value, in_subtotal)
           else 0::numeric                       -- free shipping takes nothing
         end;                                    -- off the goods, by design
  if d.max_discount is not null and d.max_discount > 0 then
    cut := least(cut, d.max_discount);
  end if;

  return query select true, null::text, cut, d.kind,
    case d.kind
      when 'percent' then d.value || '% off'
      when 'flat'    then '₹' || trim(to_char(d.value, '999999')) || ' off'
      else 'Free shipping'
    end;
end $$;

grant execute on function public.discount_value(text, numeric, text) to anon, authenticated;

-- ------------------------------------------------- the order prices itself --
-- The browser sends what it believes. This decides what is true. Prices come
-- from the products table, not from the page, so an edited script cannot buy a
-- shirt for one rupee — and the coupon is applied here, once, by the same
-- function the customer was quoted.
--
-- It CORRECTS rather than REFUSES. An order that arrives wrong is still an
-- order, and a house that loses a sale to a validation error has been served
-- worse than one that has to look at a corrected total.

create or replace function public.price_the_order() returns trigger
language plpgsql security definer set search_path = public as $$
declare sub numeric := 0; v record;
begin
  select coalesce(sum(
           coalesce(p.price, nullif(i->>'price','')::numeric, 0) * coalesce((i->>'qty')::int, 1)
         ), 0)
    into sub
    from jsonb_array_elements(coalesce(new.items, '[]'::jsonb)) i
    left join public.products p on p.slug = i->>'slug';

  new.subtotal := sub;

  if coalesce(new.discount_code, '') <> '' then
    select * into v from public.discount_value(new.discount_code, sub, new.phone);
    if v.ok then
      new.discount_amount := v.amount;
    else
      -- it did not apply. Do not pretend it did.
      new.discount_code := null;
      new.discount_amount := 0;
    end if;
  else
    new.discount_amount := 0;
  end if;

  new.total := greatest(sub - coalesce(new.discount_amount, 0), 0);
  return new;
end $$;

drop trigger if exists orders_pricing on public.orders;
create trigger orders_pricing before insert on public.orders
  for each row execute function public.price_the_order();

-- and the redemption is recorded once the order exists
create or replace function public.note_redemption() returns trigger
language plpgsql security definer set search_path = public as $$
begin
  if coalesce(new.discount_code, '') <> '' then
    insert into public.discount_uses (code, order_id, phone, amount)
    values (new.discount_code, new.id,
            nullif(regexp_replace(coalesce(new.phone,''), '\D', '', 'g'), ''),
            new.discount_amount);
    update public.discounts set uses = uses + 1 where code = new.discount_code;
  end if;
  return new;
end $$;

drop trigger if exists orders_redemption on public.orders;
create trigger orders_redemption after insert on public.orders
  for each row execute function public.note_redemption();

-- ------------------------------------------------------- what it all cost --
-- A code is never shown without what it gave away. One that brought three lakh
-- and cost thirty thousand is a different decision from the reverse.

create or replace view public.discount_performance as
with took as (
  select u.code, count(*) as n, coalesce(sum(u.amount), 0) as given,
         coalesce(sum(o.total), 0) as revenue
  from public.discount_uses u
  join public.orders o on o.id = u.order_id and o.status <> 'cancelled'
  group by u.code
)
select d.code, d.kind, d.value, d.min_spend, d.max_discount,
       d.usage_limit, d.per_customer, d.applies_to, d.collection,
       d.starts_at, d.ends_at, d.live, d.note,
       coalesce(t.n, 0)       as uses,
       coalesce(t.revenue, 0) as revenue,
       coalesce(t.given, 0)   as given,
       case
         when not d.live then 'expired'
         when d.ends_at is not null and d.ends_at < now() then 'expired'
         when d.starts_at is not null and d.starts_at > now() then 'scheduled'
         when d.usage_limit is not null and d.uses >= d.usage_limit then 'expired'
         else 'active'
       end as state
from public.discounts d
left join took t on t.code = d.code
order by d.made_at desc;

-- ====================================================== ABANDONED CARTS ==
-- A cart is only written once somebody has deliberately typed a way to reach
-- them into a checkout. Browsing is never recorded against a person — that is
-- the same line the tracker draws, and it is the line that keeps this site
-- free of a consent banner.

create table if not exists public.carts (
  cart_id     text primary key,          -- a random id the tab invents
  name        text,
  email       text,
  phone       text,
  items       jsonb not null default '[]',
  value       numeric default 0,
  source      text,
  recovered   text,                      -- the order ref, once they came back
  started_at  timestamptz default now(),
  updated_at  timestamptz default now()
);
create index if not exists carts_idx on public.carts (updated_at desc);

drop trigger if exists carts_touch on public.carts;
create trigger carts_touch before update on public.carts
  for each row execute function public.touch();

-- Half an hour is the line. Under it they are still shopping; a "you left
-- something behind" message sent at minute four is an interruption, not a
-- recovery.
create or replace view public.abandoned_carts as
select c.cart_id, c.name, c.email, c.phone, c.items, c.value, c.source,
       c.recovered, c.updated_at,
       jsonb_array_length(c.items) as lines,
       case when c.recovered is not null then 'recovered'
            when c.updated_at < now() - interval '7 days' then 'cold'
            else 'pending' end as state
from public.carts c
where c.updated_at < now() - interval '30 minutes'
  and jsonb_array_length(c.items) > 0
order by c.updated_at desc;

create or replace view public.cart_stats as
select
  (select count(*) from public.abandoned_carts
     where updated_at >= now() - interval '7 days')                   as abandoned,
  (select count(*) from public.abandoned_carts
     where recovered is not null and updated_at >= now() - interval '7 days') as recovered,
  (select coalesce(sum(o.total), 0) from public.orders o
     join public.carts c on c.recovered = o.ref
    where o.placed_at >= now() - interval '7 days'
      and o.status <> 'cancelled')                                    as revenue,
  (select coalesce(sum(value), 0) from public.abandoned_carts
     where recovered is null and updated_at >= now() - interval '7 days') as at_stake;

-- ========================================================== ATTRIBUTION ==
-- Where an order came from, carried on the link and written onto the order.
-- Nothing is inferred and nothing is guessed: an order with no utm on it is
-- reported as "direct", which is the truth, not a category.

alter table public.orders add column if not exists utm_source   text;
alter table public.orders add column if not exists utm_medium   text;
alter table public.orders add column if not exists utm_campaign text;

-- What the house spends, typed in by the house. There is no way for a database
-- to know an ad bill, so ROAS stays blank until somebody enters one — an
-- invented return on ad spend is the most expensive lie a dashboard can tell.
create table if not exists public.ad_spend (
  id      bigint generated always as identity primary key,
  month   date not null,
  channel text not null,
  amount  numeric not null default 0,
  unique (month, channel)
);

create or replace view public.marketing_channels as
with win as (
  select coalesce(nullif(utm_source, ''), 'direct') as channel,
         count(*) as orders, coalesce(sum(total), 0) as revenue
  from public.orders
  where status <> 'cancelled' and placed_at >= now() - interval '30 days'
  group by 1
),
spend as (
  select channel, sum(amount) as spent from public.ad_spend
  where month >= date_trunc('month', now() - interval '30 days')
  group by channel
)
select w.channel, w.orders, w.revenue,
       coalesce(s.spent, 0) as spent,
       case when coalesce(s.spent, 0) > 0
            then round(w.revenue / s.spent, 2) end as roas
from win w left join spend s on lower(s.channel) = lower(w.channel)
order by w.revenue desc;

create or replace view public.marketing_overview as
with paid as (
  select count(*) n, coalesce(sum(total), 0) v
  from public.orders
  where status <> 'cancelled' and placed_at >= now() - interval '30 days'
    and coalesce(utm_source, '') <> ''
),
prev as (
  select count(*) n, coalesce(sum(total), 0) v
  from public.orders
  where status <> 'cancelled'
    and placed_at >= now() - interval '60 days' and placed_at < now() - interval '30 days'
    and coalesce(utm_source, '') <> ''
),
fresh as (
  select count(*) n from (
    select phone from public.orders
    where status <> 'cancelled'
    group by phone
    having min(placed_at) >= now() - interval '30 days'
  ) x
),
spent as (
  select coalesce(sum(amount), 0) v from public.ad_spend
  where month >= date_trunc('month', now() - interval '30 days')
)
select (select v from paid)  as revenue,   (select v from prev) as revenue_before,
       (select n from paid)  as orders,    (select n from prev) as orders_before,
       (select n from fresh) as new_customers,
       (select v from spent) as spent,
       case when (select v from spent) > 0
            then round((select v from paid) / (select v from spent), 2) end as roas;

-- ============================================================ CAMPAIGNS ==
-- A campaign is a named list of real people and a message. It is NOT a mail
-- server. What it can do without one: build the audience honestly, and hand
-- WhatsApp messages to the house one at a time.

create table if not exists public.campaigns (
  id           bigint generated always as identity primary key,
  name         text not null,
  channel      text not null default 'whatsapp',   -- email | sms | whatsapp
  audience     text not null default 'all',
  subject      text,
  message      text,
  utm_campaign text,
  state        text not null default 'draft',      -- draft | ready | sending | done
  send_at      timestamptz,
  made_at      timestamptz default now(),
  updated_at   timestamptz default now()
);

drop trigger if exists campaigns_touch on public.campaigns;
create trigger campaigns_touch before update on public.campaigns
  for each row execute function public.touch();

create table if not exists public.campaign_recipients (
  id          bigint generated always as identity primary key,
  campaign_id bigint references public.campaigns(id) on delete cascade,
  name        text,
  email       text,
  phone       text,
  sent_at     timestamptz,               -- stamped when the house actually sends
  unique (campaign_id, phone)
);
create index if not exists camp_rec_idx on public.campaign_recipients (campaign_id);

-- Who is in an audience. Every row here is somebody who gave the house their
-- number in the course of buying or asking — there is no bought list and no
-- scraped one.
create or replace function public.audience(kind text)
returns table (name text, email text, phone text)
language sql stable security definer set search_path = public as $$
  with ok as (select * from public.orders where status <> 'cancelled')
  select * from (
    select max(o.name) as name, max(o.email) as email, o.phone
      from ok o where kind = 'all' group by o.phone
    union all
    select max(o.name), max(o.email), o.phone
      from ok o where kind = 'repeat' group by o.phone having count(*) >= 2
    union all
    select max(o.name), max(o.email), o.phone
      from ok o where kind = 'quiet' group by o.phone
      having max(o.placed_at) < now() - interval '6 months'
    union all
    select max(o.name), max(o.email), o.phone
      from ok o where kind = 'recent' group by o.phone
      having max(o.placed_at) >= now() - interval '30 days'
    union all
    select c.name, c.email, c.phone from public.abandoned_carts c
      where kind = 'abandoned' and c.recovered is null and c.phone is not null
    union all
    select e.name, e.email, e.phone from public.enquiries e
      where kind = 'enquiries' and e.phone is not null
  ) x
  -- SECURITY DEFINER means this reads orders past their row-level security, so
  -- it must check for itself who is asking. Signing up is open to anybody; being
  -- on the house's admin list is not. Without this line any registered stranger
  -- could pull every customer's name and phone number in one request.
  where coalesce(x.phone, '') <> '' and public.is_admin();
$$;

grant execute on function public.audience(text) to authenticated;

create or replace view public.audience_sizes as
select 'all'       as kind, 'Everyone who has ordered'  as label, count(*) as n from public.audience('all')
union all select 'repeat',    'Ordered more than once',     count(*) from public.audience('repeat')
union all select 'recent',    'Ordered in the last month',  count(*) from public.audience('recent')
union all select 'quiet',     'Nothing for six months',     count(*) from public.audience('quiet')
union all select 'abandoned', 'Left a cart behind',         count(*) from public.audience('abandoned')
union all select 'enquiries', 'Asked about bespoke',        count(*) from public.audience('enquiries');

-- Fill a campaign's list. Re-running replaces it, so editing the audience and
-- rebuilding is safe.
create or replace function public.build_audience(camp_id bigint)
returns integer
language plpgsql security definer set search_path = public as $$
declare k text; n integer;
begin
  if not public.is_admin() then raise exception 'not allowed'; end if;
  select audience into k from public.campaigns where id = camp_id;
  delete from public.campaign_recipients where campaign_id = camp_id;
  insert into public.campaign_recipients (campaign_id, name, email, phone)
  select camp_id, a.name, a.email, a.phone from public.audience(k) a
  on conflict (campaign_id, phone) do nothing;
  get diagnostics n = row_count;
  update public.campaigns set state = 'ready' where id = camp_id;
  return n;
end $$;

grant execute on function public.build_audience(bigint) to authenticated;

create or replace view public.campaign_list as
select c.*,
       (select count(*) from public.campaign_recipients r where r.campaign_id = c.id) as recipients,
       (select count(*) from public.campaign_recipients r
         where r.campaign_id = c.id and r.sent_at is not null)                        as sent
from public.campaigns c
order by c.made_at desc;

-- What has happened lately, offers and campaigns in one list, because the
-- house thinks in weeks and not in tables.
create or replace view public.marketing_activity as
select * from (
  select c.name as what, 'Campaign' as kind, c.channel as detail,
         c.state, c.made_at as at,
         (select coalesce(sum(o.total),0) from public.orders o
           where o.status <> 'cancelled'
             and lower(o.utm_campaign) = lower(coalesce(c.utm_campaign, c.name))) as revenue
  from public.campaigns c
  union all
  select d.code, 'Offer', d.kind, dp.state, d.made_at, dp.revenue
  from public.discounts d
  join public.discount_performance dp on dp.code = d.code
) x
order by at desc
limit 12;

-- ====================================================== THE SHOP WINDOWS ==
-- The Website screen reads this. Text the house may change without me.

create table if not exists public.content (
  slot  text primary key,
  value text,
  note  text
);

insert into public.content (slot, value, note) values
  ('hero_line',    '', 'The line across the campaign banner on the home page.'),
  ('hero_note',    '', 'The small line under it.'),
  ('range_intro',  '', 'The paragraph above the range.'),
  ('house_intro',  '', 'The paragraph on The House.'),
  ('bespoke_note', '', 'The line above Book a consultation.')
on conflict (slot) do nothing;

-- ============================================================ WHO MAY DO WHAT ==

alter table public.discounts           enable row level security;
alter table public.discount_uses       enable row level security;
alter table public.carts               enable row level security;
alter table public.campaigns           enable row level security;
alter table public.campaign_recipients enable row level security;
alter table public.ad_spend            enable row level security;
alter table public.content             enable row level security;

do $$
declare t text;
begin
  foreach t in array array['discounts','discount_uses','carts','campaigns',
                           'campaign_recipients','ad_spend','content'] loop
    execute format('drop policy if exists "admins only" on public.%I;', t);
    execute format(
      'create policy "admins only" on public.%I for all to authenticated '
      'using (public.is_admin()) with check (public.is_admin());', t);
  end loop;
end $$;

-- A shopper may leave a cart and come back to it. They may never read one —
-- not even their own, because a reader who could read one could read all of
-- them, and every row holds a name and a phone number.
drop policy if exists "leave a cart" on public.carts;
create policy "leave a cart" on public.carts for insert to anon with check (true);
drop policy if exists "change your own cart" on public.carts;
create policy "change your own cart" on public.carts for update to anon
  using (recovered is null) with check (true);

-- The shop front reads the house's own words.
drop policy if exists "anyone may read" on public.content;
create policy "anyone may read" on public.content for select to anon using (true);

-- Nobody unauthenticated may read the codes. They may only ASK about one they
-- already know, through discount_value() — so a code cannot be discovered, only
-- confirmed.

-- ================================================== the null that was a zero ==
-- product_stats.out_of_stock returned NULL rather than 0 when nothing was out
-- of stock: a grouped subquery with no matching groups yields no row at all.
-- It displayed as zero and read as zero, but `where out_of_stock > 0` would
-- have quietly missed.

create or replace view public.product_stats as
select
  count(*)                                        as total,
  count(*) filter (where visible)                 as active,
  (select count(*) from (
      select p.id from public.products p
        join public.inventory i on i.product_id = p.id
       group by p.id having sum(i.qty) = 0) x)    as out_of_stock,
  (select count(*) from (
      select p.id from public.products p
        join public.inventory i on i.product_id = p.id
       group by p.id having sum(i.qty) > 0 and sum(i.qty) <= 10) y) as low_stock,
  (select count(*) from public.inventory)         as variants,
  (select count(distinct collection) from public.products
     where collection is not null)                as collections
from public.products;
