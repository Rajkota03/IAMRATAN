-- I AM RATAN — the measurement book, the shop windows, and the offers.
-- Run once in the SQL Editor, after the previous five.
--
-- SIZES ARE NECK SIZES. 39 / 40 / 42 / 44 / 46, and the three the house does
-- not cut are 41 / 43 / 45. Nothing here says S, M or L.
--
-- The measurement book is first in this file because it is the most valuable
-- thing in it. A shirtmaker who knows a returning customer's neck, sleeve and
-- yoke does not need him to choose a size — and a customer whose measurements
-- are already on file does not shop anywhere else. Everything below it is
-- ordinary shop machinery by comparison.

-- --------------------------------------------------------- the measurement book --
-- One row per person per sitting. Kept as a history rather than a single
-- current row, because a man's collar changes and the old numbers explain
-- why a shirt cut in March no longer fits in November.

create table if not exists public.measurements (
  id           bigint generated always as identity primary key,
  phone        text not null,                 -- how a customer is recognised here
  email        text,
  name         text,
  -- in inches, as the tailor takes them
  neck         numeric(4,1),
  chest        numeric(4,1),
  waist        numeric(4,1),
  seat         numeric(4,1),
  shoulder     numeric(4,1),
  sleeve       numeric(4,1),
  wrist        numeric(4,1),
  shirt_length numeric(4,1),
  -- the things that are not numbers but decide the fit
  fit          text,        -- close | regular | easy
  posture      text,        -- notes: stooping, erect, one shoulder lower
  cuff         text,        -- single | double
  collar       text,        -- the house's collar names
  note         text,
  taken_by     text,
  taken_at     timestamptz default now()
);
create index if not exists meas_phone_idx on public.measurements (phone, taken_at desc);

-- The current sheet for each customer: the most recent sitting, nothing older.
create or replace view public.measurement_book as
select distinct on (phone)
  phone, name, email, neck, chest, waist, seat, shoulder, sleeve, wrist,
  shirt_length, fit, posture, cuff, collar, note, taken_by, taken_at
from public.measurements
order by phone, taken_at desc;

-- ------------------------------------------------------------------ collections --
-- The shop's own groupings. `products.collection` is already free text; this
-- gives those names an order, a description and a switch, without a migration.

create table if not exists public.collections (
  id          bigint generated always as identity primary key,
  slug        text unique not null,
  name        text not null,
  blurb       text,
  sort_order  integer default 0,
  visible     boolean default true,
  updated_at  timestamptz default now()
);

-- ------------------------------------------------------- the garment's details --
-- Facts a shirt buyer asks for and a marketplace listing requires. Added to
-- products rather than a side table because they are one-to-one with the cloth
-- and every one of them belongs on the product page.

alter table public.products add column if not exists sku          text;
alter table public.products add column if not exists mrp          integer;
alter table public.products add column if not exists fabric       text;
alter table public.products add column if not exists fit          text;
alter table public.products add column if not exists weave        text;
alter table public.products add column if not exists collar       text;
alter table public.products add column if not exists sleeve       text;
alter table public.products add column if not exists pattern      text;
alter table public.products add column if not exists care         text;
alter table public.products add column if not exists origin       text default 'Made in India';

-- ---------------------------------------------------------------- photography --
-- Ordered, and named by what the photograph shows. The order is the order the
-- product page runs them in, so dragging one to the front here changes the
-- shop. `kind` exists so the page can ask for the cuff shot by name.

create table if not exists public.product_images (
  id          bigint generated always as identity primary key,
  product_id  bigint references public.products(id) on delete cascade,
  url         text not null,
  kind        text default 'lifestyle',
  -- thumbnail | front | back | collar | buttons | cuff | fabric | lifestyle
  alt         text,
  sort_order  integer default 0,
  added_at    timestamptz default now()
);
create index if not exists pimg_idx on public.product_images (product_id, sort_order);

-- ------------------------------------------------------------------- the offers --

create table if not exists public.discounts (
  id           bigint generated always as identity primary key,
  code         text unique not null,
  kind         text not null default 'percent',   -- percent | flat | free_shipping
  value        integer not null default 0,        -- 10 = 10% or ₹10, by kind
  min_spend    integer default 0,
  collection   text,                              -- limit to one collection
  first_order  boolean default false,
  usage_limit  integer,                           -- null = unlimited
  used         integer not null default 0,
  starts_at    timestamptz,
  ends_at      timestamptz,
  live         boolean default true,
  note         text,
  made_at      timestamptz default now()
);

-- What each code actually did. Uses are counted from orders rather than a
-- counter that can drift, so the revenue figure is the real one.
create table if not exists public.discount_uses (
  id          bigint generated always as identity primary key,
  code        text not null,
  order_id    bigint references public.orders(id) on delete set null,
  order_total integer,
  discount    integer,
  at          timestamptz default now()
);
create index if not exists duse_code_idx on public.discount_uses (code, at desc);

create or replace view public.discount_performance as
select
  d.code, d.kind, d.value, d.live, d.usage_limit, d.ends_at,
  count(u.id)                            as uses,
  coalesce(sum(u.order_total), 0)        as revenue,
  coalesce(sum(u.discount), 0)           as given
from public.discounts d
left join public.discount_uses u on u.code = d.code
group by d.code, d.kind, d.value, d.live, d.usage_limit, d.ends_at
order by count(u.id) desc;

-- ----------------------------------------------------------- the shop windows --
-- Editable pieces of the storefront. A block is one named slot; the site reads
-- it and the desk writes it, so the house can change the hero without me.

create table if not exists public.content (
  slot        text primary key,     -- hero_image | hero_mobile | headline | cta …
  value       text,
  note        text,                 -- what this slot is, in plain words
  updated_at  timestamptz default now()
);

insert into public.content (slot, value, note) values
  ('hero_image',      '', 'The wide photograph at the top of the home page'),
  ('hero_mobile',     '', 'The tall crop of it, for a phone'),
  ('headline',        '', 'The line over the hero'),
  ('cta_label',       '', 'What the button under it says'),
  ('cta_href',        '', 'Where that button goes'),
  ('featured_slugs',  '', 'Cloths on the home page, comma separated'),
  ('journal_teaser',  '', 'The line that pulls people into the journal')
on conflict (slot) do nothing;

-- ------------------------------------------------------------------- reporting --

-- Which cloth and neck comes back, and how often. The point of this view is
-- one sentence the house can act on: "Slate Harbour at 44 comes back one time
-- in seven." That is a cutting problem, not a customer problem.
create or replace view public.size_exchange_rate as
with sold as (
  select i->>'slug' slug, i->>'size' size, sum((i->>'qty')::int) n
  from public.orders o, jsonb_array_elements(o.items) i
  where o.status <> 'cancelled'
  group by 1, 2
),
back as (
  select slug, size, count(*) n
  from public.returns
  where reason in ('too_small','too_large')
  group by 1, 2
)
select
  s.slug, s.size, s.n as sold, coalesce(b.n, 0) as came_back,
  case when s.n > 0
       then round(100.0 * coalesce(b.n, 0) / s.n, 1)
       else 0 end as pct
from sold s
left join back b on b.slug = s.slug and b.size = s.size
where s.n > 0
order by pct desc, s.n desc;

-- Revenue by month, for the twelve-month graph.
create or replace view public.report_sales as
select
  to_char(date_trunc('month', placed_at), 'YYYY-MM')      as month,
  count(*)                                                as orders,
  coalesce(sum(total), 0)                                 as revenue,
  coalesce(round(avg(total)), 0)                          as avg_order
from public.orders
where status <> 'cancelled'
  and placed_at >= now() - interval '12 months'
group by 1
order by 1;

-- Sell-through per cloth: what was cut, what went, what is left.
create or replace view public.report_products as
with sold as (
  select i->>'slug' slug, sum((i->>'qty')::int) n,
         sum((i->>'qty')::int * (i->>'price')::int) v
  from public.orders o, jsonb_array_elements(o.items) i
  where o.status <> 'cancelled'
  group by 1
)
select
  p.slug, p.name, p.collection,
  coalesce(s.n, 0)                                as sold,
  coalesce(s.v, 0)                                as revenue,
  coalesce(sum(inv.qty), 0)                       as in_stock,
  case when coalesce(s.n,0) + coalesce(sum(inv.qty),0) > 0
       then round(100.0 * coalesce(s.n,0)
                  / (coalesce(s.n,0) + coalesce(sum(inv.qty),0)), 1)
       else 0 end                                 as sell_through
from public.products p
left join sold s on s.slug = p.slug
left join public.inventory inv on inv.product_id = p.id
group by p.slug, p.name, p.collection, s.n, s.v
order by coalesce(s.v, 0) desc;

-- ------------------------------------------------------------------- who may --
-- Same rule as everywhere else: the admins table decides. A stranger with an
-- account sees an empty room. `content` and `collections` are also readable by
-- anyone, because the shop itself has to read them without signing in.

alter table public.measurements   enable row level security;
alter table public.collections    enable row level security;
alter table public.product_images enable row level security;
alter table public.discounts      enable row level security;
alter table public.discount_uses  enable row level security;
alter table public.content        enable row level security;

do $$
declare t text;
begin
  foreach t in array array['measurements','collections','product_images',
                           'discounts','discount_uses','content'] loop
    execute format('drop policy if exists "admins only" on public.%I;', t);
    execute format(
      'create policy "admins only" on public.%I for all to authenticated '
      'using (public.is_admin()) with check (public.is_admin());', t);
  end loop;

  -- the storefront reads these while signed out
  foreach t in array array['collections','product_images','content'] loop
    execute format('drop policy if exists "the shop may read" on public.%I;', t);
    execute format(
      'create policy "the shop may read" on public.%I for select to anon '
      'using (true);', t);
  end loop;
end $$;

-- A live code has to be checkable by a shopper who is not signed in — but a
-- row policy grants the whole row, and `used`, `note` and the usage limit are
-- nobody's business at the checkout. So anon gets no policy on the table at
-- all, and reads a view that carries only the terms instead.
create or replace view public.live_discounts
  with (security_invoker = off) as
select code, kind, value, min_spend, collection, first_order
from public.discounts
where live = true
  and (starts_at is null or starts_at <= now())
  and (ends_at   is null or ends_at   >= now());

grant select on public.live_discounts to anon, authenticated;

drop trigger if exists collections_touch on public.collections;
create trigger collections_touch before update on public.collections
  for each row execute function public.touch();

drop trigger if exists content_touch on public.content;
create trigger content_touch before update on public.content
  for each row execute function public.touch();

-- Seed the collections that already exist as free text on the products, so the
-- screen is not empty on the first visit.
insert into public.collections (slug, name, sort_order)
select
  lower(regexp_replace(collection, '[^a-zA-Z0-9]+', '-', 'g')),
  collection,
  row_number() over (order by collection)
from (select distinct collection from public.products
      where collection is not null and collection <> '') c
on conflict (slug) do nothing;
