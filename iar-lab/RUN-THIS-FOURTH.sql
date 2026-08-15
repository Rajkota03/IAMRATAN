-- I AM RATAN — everything the desk reports on.
-- Run once in the SQL Editor, after the previous three.
--
-- The tables here exist before there is anything to put in them, on purpose:
-- a screen that is waiting is better than a screen that has to be built the
-- morning the first return arrives.
--
-- SIZES ARE NECK SIZES. 39 / 40 / 42 / 44 / 46, and the three the house does
-- not cut are 41 / 43 / 45. Nothing here says S, M or L, because this shop
-- does not sell them and the uncut necks are the whole bespoke argument.

-- ------------------------------------------------------- returns/exchanges --

create table if not exists public.returns (
  id          bigint generated always as identity primary key,
  order_id    bigint references public.orders(id) on delete set null,
  order_ref   text,
  slug        text,
  size        text,
  kind        text not null default 'exchange',   -- 'exchange' | 'refund'
  -- why, in the customer's words, from a fixed list so it can be counted
  reason      text,   -- too_small | too_large | fabric | colour | defect | wrong | other
  want_size   text,                                -- for an exchange
  stage       text not null default 'requested',
  -- requested -> approved -> pickup -> received -> inspected -> done
  note        text,
  opened_at   timestamptz default now(),
  updated_at  timestamptz default now()
);
create index if not exists returns_stage_idx on public.returns (stage, opened_at desc);

-- ------------------------------------------------------- stock movements --
-- Every change to a number, with a reason and who did it. Once two people
-- touch inventory this history is the only way to answer "where did it go?".

create table if not exists public.stock_moves (
  id          bigint generated always as identity primary key,
  product_id  bigint references public.products(id) on delete cascade,
  size        text not null,
  delta       integer not null,                    -- +12 received, -1 sold
  reason      text not null default 'correction',
  -- new_stock | sale | return | correction | damaged | sample
  before_qty  integer,
  after_qty   integer,
  by_email    text,
  at          timestamptz default now()
);
create index if not exists moves_at_idx on public.stock_moves (at desc);
create index if not exists moves_product_idx on public.stock_moves (product_id, at desc);

alter table public.returns     enable row level security;
alter table public.stock_moves enable row level security;

do $$
declare t text;
begin
  foreach t in array array['returns','stock_moves'] loop
    execute format('drop policy if exists "admins only" on public.%I;', t);
    execute format(
      'create policy "admins only" on public.%I for all to authenticated '
      'using (public.is_admin()) with check (public.is_admin());', t);
  end loop;
end $$;

-- a customer may ask for a return without an account
drop policy if exists "anyone may ask" on public.returns;
create policy "anyone may ask"
  on public.returns for insert to anon with check (true);

drop trigger if exists returns_touch on public.returns;
create trigger returns_touch before update on public.returns
  for each row execute function public.touch();

-- ---------------------------------------------------------------- the KPIs --
-- One row, every number the top of the desk shows. Written as one view so the
-- page makes a single call instead of nine.

create or replace view public.kpis as
with
  today as (
    select count(*) n, coalesce(sum(total),0) v
    from public.orders
    where placed_at >= date_trunc('day', now()) and status <> 'cancelled'
  ),
  week as (
    select count(*) n, coalesce(sum(total),0) v
    from public.orders
    where placed_at >= now() - interval '7 days' and status <> 'cancelled'
  ),
  units as (
    select coalesce(sum((i->>'qty')::int),0) n
    from public.orders o, jsonb_array_elements(o.items) i
    where o.placed_at >= date_trunc('day', now()) and o.status <> 'cancelled'
  ),
  visitors as (
    select count(distinct visit) n from public.events
    where at >= now() - interval '7 days' and name = 'view'
  )
select
  (select v from today)                                            as sales_today,
  (select n from today)                                            as orders_today,
  (select n from units)                                            as units_today,
  case when (select n from week) = 0 then 0
       else round((select v from week)::numeric / (select n from week)) end
                                                                   as avg_order,
  (select v from week)                                             as sales_week,
  (select count(*) from public.orders where status in ('new'))     as orders_new,
  (select count(*) from public.orders where status = 'making')     as orders_making,
  (select count(*) from public.orders where status = 'shipped')    as orders_shipped,
  (select count(*) from public.inventory where qty = 0)            as necks_out,
  (select count(*) from public.inventory
     where qty > 0 and qty <= 3)                                   as necks_low,
  (select count(*) from public.returns
     where stage <> 'done')                                        as returns_open,
  (select count(*) from public.enquiries where handled = false)    as enquiries_open,
  (select n from visitors)                                         as visitors_week,
  case when (select n from visitors) = 0 then 0
       else round((select n from week)::numeric * 100
                  / (select n from visitors), 2) end               as conversion_week;

-- ------------------------------------------------------- action required --
-- The to-do list. Each row is something a person can act on this morning,
-- ordered by how much it matters. Empty is a good day.

create or replace view public.action_required as
select * from (
  select 1 as rank, 'red' as urgency,
         (select count(*) from public.orders where status = 'new') as n,
         'orders awaiting confirmation' as what, 'orders' as go
  union all
  select 2, 'red',
         (select count(*) from public.inventory where qty = 0),
         'neck sizes sold out', 'inventory'
  union all
  select 3, 'amber',
         (select count(*) from public.returns where stage = 'requested'),
         'return requests to approve', 'returns'
  union all
  select 4, 'amber',
         (select count(*) from public.inventory where qty > 0 and qty <= 3),
         'neck sizes running low', 'inventory'
  union all
  select 5, 'amber',
         (select count(*) from public.enquiries where handled = false),
         'enquiries unanswered', 'enquiries'
  union all
  select 6, 'green',
         (select count(*) from public.orders where status = 'making'),
         'orders ready to dispatch', 'orders'
) x
where n > 0
order by rank;

-- ---------------------------------------------------------- best sellers --
-- Units and revenue per cloth, with what is left. A cloth selling well with
-- nothing left is the most urgent line on the page.
--
-- Written in stages on purpose. The first attempt grouped by an expression and
-- then reached for that same expression inside a correlated subquery, which
-- Postgres refuses — it cannot know the subquery is asking about the grouped
-- value. Unfold the JSON first, aggregate second, join to stock third, and
-- every step is asking one plain question.

create or replace view public.best_sellers as
with lines as (
  select
    i->>'slug'          as slug,
    i->>'name'          as name,
    (i->>'qty')::int    as qty,
    (i->>'price')::int  as price
  from public.orders o, jsonb_array_elements(o.items) i
  where o.status <> 'cancelled'
),
sold as (
  select slug, max(name) as name,
         sum(qty) as sold, sum(qty * price) as revenue
  from lines group by slug
),
left_in as (
  select p.slug, coalesce(sum(inv.qty), 0) as in_stock
  from public.products p
  left join public.inventory inv on inv.product_id = p.id
  group by p.slug
)
select s.slug, s.name, s.sold, s.revenue,
       coalesce(l.in_stock, 0) as in_stock
from sold s
left join left_in l on l.slug = s.slug
order by s.sold desc;

-- which necks actually sell, so the house cuts more of the right ones
create or replace view public.neck_demand as
with lines as (
  select i->>'size' as neck, (i->>'qty')::int as qty
  from public.orders o, jsonb_array_elements(o.items) i
  where o.status <> 'cancelled'
)
select neck, sum(qty) as sold from lines group by neck order by sold desc;

-- ---------------------------------------------------------------- people --
-- Customers are not a table anyone fills in — they are what the orders say.
-- Grouped by phone, because that is the one thing an Indian customer always
-- gives correctly and never mistypes twice.

create or replace view public.customers as
with ok as (
  select * from public.orders where status <> 'cancelled'
),
totals as (
  select phone, max(name) as name, max(email) as email, max(city) as city,
         count(*) as orders, sum(total) as lifetime,
         round(avg(total)) as avg_order, max(placed_at) as last_order
  from ok group by phone
),
necks as (
  select phone, neck, n,
         row_number() over (partition by phone order by n desc) as rank
  from (
    select o.phone, i->>'size' as neck, count(*) as n
    from ok o, jsonb_array_elements(o.items) i
    group by o.phone, i->>'size'
  ) x
)
select t.*, n.neck as usual_neck
from totals t
left join necks n on n.phone = t.phone and n.rank = 1
order by t.lifetime desc;

-- ---------------------------------------------------------------- funnel --
-- Where the website loses people. Every step comes from events the site
-- already records, so this works before there is a single order.

create or replace view public.funnel as
select
  (select count(distinct visit) from public.events
     where name = 'view' and at >= now() - interval '30 days')          as visitors,
  (select count(distinct visit) from public.events
     where name = 'cloth_opened' and at >= now() - interval '30 days')  as viewed_a_cloth,
  (select count(distinct visit) from public.events
     where name = 'size_chosen' and at >= now() - interval '30 days')   as chose_a_size,
  (select count(distinct visit) from public.events
     where name = 'add_to_customize' and at >= now() - interval '30 days') as added_to_cart,
  (select count(distinct visit) from public.events
     where name = 'order_placed' and at >= now() - interval '30 days')  as ordered,
  (select count(*) from public.events
     where name = 'uncut_size' and at >= now() - interval '30 days')    as asked_uncut;
