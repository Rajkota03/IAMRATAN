-- I AM RATAN — what the dashboard graph and the "vs yesterday" arrows read.
-- Run in the SQL Editor after the previous five.

-- ------------------------------------------------------------ the graph --
-- Revenue over time, in whichever window the house has picked. Buckets are
-- generated first and orders joined onto them, so an hour with no sales draws
-- a zero instead of vanishing — a line with holes in it lies about the shape
-- of the day.

create or replace function public.revenue_series(period text default 'today')
returns table (label text, at timestamptz, value numeric)
language sql stable as $$
  with spec as (
    select
      case period
        when 'today' then now() - interval '24 hours'
        when '7d'    then now() - interval '7 days'
        when '30d'   then now() - interval '30 days'
        else              now() - interval '12 months'
      end as since,
      case period
        when 'today' then interval '1 hour'
        when '7d'    then interval '1 day'
        when '30d'   then interval '1 day'
        else              interval '1 month'
      end as step,
      case period
        when 'today' then 'HH24:MI'
        when '7d'    then 'Dy'
        when '30d'   then 'DD Mon'
        else              'Mon'
      end as fmt
  ),
  buckets as (
    select generate_series(
      date_trunc(case period when '12m' then 'month'
                             when 'today' then 'hour' else 'day' end,
                 (select since from spec)),
      date_trunc(case period when '12m' then 'month'
                             when 'today' then 'hour' else 'day' end, now()),
      (select step from spec)
    ) as b
  )
  select
    to_char(b.b, (select fmt from spec))               as label,
    b.b                                                as at,
    coalesce(sum(o.total), 0)::numeric                 as value
  from buckets b
  left join public.orders o
    on o.status <> 'cancelled'
   and date_trunc(case period when '12m' then 'month'
                              when 'today' then 'hour' else 'day' end,
                  o.placed_at) = b.b
  group by b.b
  order by b.b;
$$;

grant execute on function public.revenue_series(text) to authenticated;

-- ------------------------------------------------------ vs yesterday --
-- The arrows on the cards. Yesterday means the same hours of yesterday, not
-- all of yesterday — comparing this morning against a whole finished day makes
-- every morning look like a disaster.

create or replace view public.kpi_deltas as
with
  now_win as (
    select coalesce(sum(total),0) v, count(*) n
    from public.orders
    where placed_at >= date_trunc('day', now()) and status <> 'cancelled'
  ),
  then_win as (
    select coalesce(sum(total),0) v, count(*) n
    from public.orders
    where placed_at >= date_trunc('day', now()) - interval '1 day'
      and placed_at <  now() - interval '1 day'
      and status <> 'cancelled'
  ),
  units_now as (
    select coalesce(sum((i->>'qty')::int),0) n
    from public.orders o, jsonb_array_elements(o.items) i
    where o.placed_at >= date_trunc('day', now()) and o.status <> 'cancelled'
  ),
  units_then as (
    select coalesce(sum((i->>'qty')::int),0) n
    from public.orders o, jsonb_array_elements(o.items) i
    where o.placed_at >= date_trunc('day', now()) - interval '1 day'
      and o.placed_at <  now() - interval '1 day'
      and o.status <> 'cancelled'
  )
select
  (select v from now_win)   as sales_now,    (select v from then_win)   as sales_then,
  (select n from now_win)   as orders_now,   (select n from then_win)   as orders_then,
  (select n from units_now) as units_now,    (select n from units_then) as units_then;

-- ------------------------------------------------- the orders pipeline --
-- One row per stage, in the order work actually moves, so a stage with nothing
-- in it still draws its zero rather than disappearing from the row.

create or replace view public.order_pipeline as
select s.stage, s.rank, coalesce(c.n, 0) as n
from (values ('new',1),('making',2),('packed',3),('shipped',4),('delivered',5))
       as s(stage, rank)
left join (
  select status, count(*) n from public.orders group by status
) c on c.status = s.stage
order by s.rank;

-- -------------------------------------------------- size stock alert --
-- Every cloth against every neck the house cuts, as one row per cloth. This is
-- the table that matters most in a shirt shop: a cloth can hold fifty units and
-- still be unsellable because the necks people actually take are gone.

create or replace view public.neck_stock as
select
  p.slug, p.name,
  coalesce(max(case when i.size = '39' then i.qty end), 0) as n39,
  coalesce(max(case when i.size = '40' then i.qty end), 0) as n40,
  coalesce(max(case when i.size = '42' then i.qty end), 0) as n42,
  coalesce(max(case when i.size = '44' then i.qty end), 0) as n44,
  coalesce(max(case when i.size = '46' then i.qty end), 0) as n46,
  coalesce(sum(i.qty), 0)                                  as total,
  count(*) filter (where i.qty = 0)                        as gone
from public.products p
left join public.inventory i on i.product_id = p.id
where p.visible = true
group by p.id, p.slug, p.name
order by gone desc, total asc;
