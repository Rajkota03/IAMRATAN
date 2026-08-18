-- I AM RATAN — closing a hole, and the three views Reports has always wanted.
-- Run in the SQL Editor after the previous eight. This one matters most.
--
-- ============================ WHAT WAS WRONG =============================
-- A VIEW IN POSTGRES DOES NOT RESPECT ROW-LEVEL SECURITY BY DEFAULT.
-- It runs as whoever created it, not whoever is asking. So every table here was
-- correctly locked — an anonymous reader gets nothing from `orders` or `events`
-- — and then every view built on top of those tables handed the same data
-- straight back out.
--
-- Proved, not assumed. With the public anon key, before this file:
--     GET /rest/v1/events   ->  []            (row-level security working)
--     GET /rest/v1/funnel   ->  {"visitors":29,...}   (the same table, leaking)
--
-- Today it leaks little, because there are no orders yet. The moment there are,
-- `customers` and `customer_list` would hand ANYONE the name, email, phone and
-- lifetime spend of every customer the house has. The anon key is printed in
-- the site's own JavaScript — it is public by design — so "anyone" means anyone.
--
-- Two fixes, belt and braces:
--   1. security_invoker = on  — the view now runs as the person asking, so the
--      table's own rules apply to it. This is the actual fix.
--   2. revoke select from anon — the view is not even addressable. This is the
--      second lock, for the day somebody adds a view and forgets step 1.

-- --------------------------------------------------------------- events --
-- There was never a SELECT policy on this table at all. Nobody noticed, because
-- the Analytics screen was reading it through the leak. Close the leak without
-- this line and Analytics goes blank for the house too.

drop policy if exists "the house reads its own analytics" on public.events;
create policy "the house reads its own analytics"
  on public.events for select to authenticated using (public.is_admin());

-- ------------------------------------------------- the three Reports views --
-- admin.js has called these since the desk was built; they were never created,
-- so Reports has only ever shown "this screen needs a table that does not
-- exist yet". Written as CTEs throughout: an earlier attempt in this project
-- grouped by an expression and then reached for that same expression inside a
-- correlated subquery, which Postgres refuses (42803).

create or replace view public.report_sales as
with months as (
  select generate_series(
    date_trunc('month', now()) - interval '11 months',
    date_trunc('month', now()),
    interval '1 month') as m
)
select to_char(mo.m, 'Mon YY')            as month,
       mo.m                               as at,
       coalesce(sum(o.total), 0)::numeric as revenue,
       count(o.id)                        as orders
from months mo
left join public.orders o
  on date_trunc('month', o.placed_at) = mo.m
 and o.status <> 'cancelled'
group by mo.m
order by mo.m;

create or replace view public.report_products as
with lines as (
  select i->>'slug' as slug,
         (i->>'qty')::int as qty,
         (i->>'price')::numeric as price
  from public.orders o, jsonb_array_elements(o.items) i
  where o.status <> 'cancelled'
),
sold as (
  select slug, sum(qty) as sold, sum(qty * price) as revenue
  from lines group by slug
),
stock as (
  select p.slug, p.name, p.collection, coalesce(sum(inv.qty), 0) as in_stock
  from public.products p
  left join public.inventory inv on inv.product_id = p.id
  group by p.id, p.slug, p.name, p.collection
)
select st.slug, st.name, st.collection,
       coalesce(s.sold, 0)     as sold,
       st.in_stock,
       coalesce(s.revenue, 0)  as revenue,
       -- of everything that ever existed of this cloth, what share has sold
       case when coalesce(s.sold, 0) + st.in_stock = 0 then 0
            else round(coalesce(s.sold, 0) * 100.0
                       / (coalesce(s.sold, 0) + st.in_stock)) end as sell_through
from stock st
left join sold s on s.slug = st.slug
order by revenue desc;

-- A cloth and a neck that comes back often is a CUTTING problem, not a customer
-- problem. Only size exchanges count — a returned-because-I-changed-my-mind
-- says nothing about the pattern.
create or replace view public.size_exchange_rate as
with sold as (
  select i->>'slug' as slug, i->>'size' as size, sum((i->>'qty')::int) as sold
  from public.orders o, jsonb_array_elements(o.items) i
  where o.status <> 'cancelled'
  group by 1, 2
),
back as (
  select slug, size, count(*) as came_back
  from public.returns
  where reason in ('too_small', 'too_large')
  group by 1, 2
)
select s.slug, s.size, s.sold,
       coalesce(b.came_back, 0) as came_back,
       case when s.sold = 0 then 0
            else round(coalesce(b.came_back, 0) * 100.0 / s.sold, 1) end as pct
from sold s
left join back b on b.slug = s.slug and b.size = s.size
order by pct desc, s.sold desc;

-- ================================ THE LOCK ================================
-- Every view the desk reads, made to obey the rules of the tables underneath
-- it. `shop` is deliberately absent: it is the shop front, it is meant to be
-- read by strangers, and products/inventory/settings already allow exactly that.

do $$
declare v text;
begin
  foreach v in array array[
    'kpis','kpi_deltas','action_required','best_sellers','neck_demand',
    'customers','customer_list','funnel','order_pipeline','neck_stock',
    'product_stats','inventory_stats','discount_performance',
    'abandoned_carts','cart_stats','campaign_list','audience_sizes',
    'marketing_overview','marketing_channels','marketing_activity',
    'report_sales','report_products','size_exchange_rate'
  ] loop
    if exists (select 1 from pg_views where schemaname = 'public' and viewname = v) then
      -- the view now asks as the caller, so row-level security applies to it
      execute format('alter view public.%I set (security_invoker = on);', v);
      -- and the second lock: not readable by a stranger even if the first fails
      execute format('revoke select on public.%I from anon;', v);
      execute format('grant  select on public.%I to authenticated;', v);
    end if;
  end loop;
end $$;

-- The shop front stays open, explicitly, so nobody reading this later wonders
-- whether it was missed.
grant select on public.shop to anon, authenticated;

-- =================== THE SAME MISTAKE, ONE FLOOR DOWN ====================
-- products, inventory and settings were opened with
--     for all to authenticated using (true) with check (true)
-- which reads as "the house, signed in, may do anything" and is not what it
-- says. `authenticated` is not the house — it is EVERY account that exists.
-- Signing up is open, so registering an address would have been enough to
-- change a price, zero the stock, or edit the GSTIN printed on the invoices.
--
-- Every other table in this project was already gated on the admins allowlist
-- through is_admin(). These three were the exception, and only because they
-- were written first, before that list existed.

do $$
declare t text;
begin
  foreach t in array array['products','inventory','settings'] loop
    execute format('drop policy if exists "the house may write" on public.%I;', t);
    execute format(
      'create policy "the house may write" on public.%I for all to authenticated '
      'using (public.is_admin()) with check (public.is_admin());', t);
  end loop;
end $$;

-- The shop front is unaffected: it reads these three with the anon key, through
-- the "anyone may read" policies, which are untouched. Only the signed-in side
-- narrows, from anybody with an account to the people on the house's list.
