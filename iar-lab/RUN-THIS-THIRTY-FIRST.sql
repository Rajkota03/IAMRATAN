-- I AM RATAN — thirty-first run. The dashboard counted cloths nobody can buy.
--
-- 1. "Necks sold out" and "running low", on the dashboard and in Needs you
--    today, counted the stock of all 28 cloths in the table, including the 18
--    hidden old mockups. The Neck stock alert table beside them counted only
--    the live ones, so the two disagreed. Both now count cloths on the shop.
--
-- 2. Needs you today called orders IN THE MAKING "ready to dispatch". The
--    ones ready to go out are the PACKED ones.
--
-- Only expressions change; every column keeps its name and place.

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
  (select count(*) from public.inventory i join public.products p on p.id = i.product_id where p.visible and i.qty = 0) as necks_out,
  (select count(*) from public.inventory i join public.products p on p.id = i.product_id where p.visible and i.qty > 0 and i.qty <= 3) as necks_low,
  (select count(*) from public.returns
     where stage <> 'done')                                        as returns_open,
  (select count(*) from public.enquiries where handled = false)    as enquiries_open,
  (select n from visitors)                                         as visitors_week,
  case when (select n from visitors) = 0 then 0
       else round((select n from week)::numeric * 100
                  / (select n from visitors), 2) end               as conversion_week;

create or replace view public.action_required as
select * from (
  select 1 as rank, 'red' as urgency,
         (select count(*) from public.orders where status = 'new') as n,
         'orders awaiting confirmation' as what, 'orders' as go
  union all
  select 2, 'red',
         (select count(*) from public.inventory i
            join public.products p on p.id = i.product_id
           where p.visible and i.qty = 0),
         'neck sizes sold out', 'inventory'
  union all
  select 3, 'amber',
         (select count(*) from public.returns where stage = 'requested'),
         'return requests to approve', 'returns'
  union all
  select 4, 'amber',
         (select count(*) from public.inventory i
            join public.products p on p.id = i.product_id
           where p.visible and i.qty > 0 and i.qty <= 3),
         'neck sizes running low', 'inventory'
  union all
  select 5, 'amber',
         (select count(*) from public.enquiries where handled = false),
         'enquiries unanswered', 'enquiries'
  union all
  select 6, 'green',
         (select count(*) from public.orders where status = 'packed'),
         'orders packed and ready to dispatch', 'orders'
) x
where n > 0
order by rank;

-- ---------------------------------------------------------------- check --
select necks_out, necks_low from public.kpis;
