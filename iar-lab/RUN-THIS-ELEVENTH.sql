-- I AM RATAN — what the Analytics and Reports screens read.
-- Run in the SQL Editor after the previous ten.
--
-- ===================== WHAT IS COUNTED AND WHAT IS NOT =====================
-- Everything here is counted from things that happened: orders placed, events
-- recorded, returns opened. Nothing is modelled, estimated or projected.
--
-- Two figures a mockup asks for are deliberately absent, because this shop
-- cannot yet know them and a number that looks like a fact gets planned against:
--
--   PAYMENT METHOD SPLIT — every order is 'prepaid' by default because there is
--   no gateway. A UPI / card / netbanking breakdown today would be an invention.
--   It arrives with Razorpay, honestly, and not before.
--
--   EMAIL OPEN AND CLICK RATES — no mail provider, nothing to measure.
--
-- Sessions become attributable to a channel only from the moment `track.js`
-- starts carrying the utm on each event. Everything recorded before that reads
-- as 'direct', which is the truth about what we know, not a claim about where
-- those people came from.

-- ---------------------------------------------------- the two lines ----------
-- Revenue and orders over a window, each bucket paired with the SAME bucket one
-- window earlier, so the chart can draw "this period" against "previous period".
--
-- Aggregated BEFORE joining, on purpose. Joining the raw orders twice — once for
-- now, once for then — multiplies three current orders by two previous ones and
-- reports six. The same shape of mistake as the correlated subquery in the
-- fourth file: unfold, aggregate, then join.

create or replace function public.analytics_series(period text default '30d')
-- The output names deliberately avoid `orders` and `at`: a SQL function's
-- output parameters are in scope as names inside its own body, and this body
-- queries a table called orders. A collision there resolves as ambiguous and
-- takes the whole script down with it — which is a rollback of eleven other
-- objects for the sake of one word.
returns table (label text, bucket timestamptz,
               revenue numeric, order_count bigint,
               prev_revenue numeric, prev_order_count bigint)
language sql stable as $$
  with spec as (
    select
      case period when 'today' then interval '24 hours'
                  when '7d'    then interval '7 days'
                  when '12m'   then interval '12 months'
                  else              interval '30 days' end as span,
      case period when 'today' then interval '1 hour'
                  when '12m'   then interval '1 month'
                  else              interval '1 day'  end as step,
      case period when 'today' then 'hour'
                  when '12m'   then 'month'
                  else              'day'   end as unit,
      case period when 'today' then 'HH24:MI'
                  when '7d'    then 'Dy'
                  when '12m'   then 'Mon'
                  else              'DD Mon' end as fmt
  ),
  buckets as (
    select generate_series(
      date_trunc((select unit from spec), now() - (select span from spec)),
      date_trunc((select unit from spec), now()),
      (select step from spec)) as b
  ),
  taken as (
    select date_trunc((select unit from spec), placed_at) as b,
           sum(total)::numeric as v, count(*)::bigint as n
    from public.orders
    where status <> 'cancelled'
      and placed_at >= now() - (select span from spec) * 2
    group by 1
  )
  select
    to_char(bk.b, (select fmt from spec)),
    bk.b,
    coalesce(cur.v, 0), coalesce(cur.n, 0),
    coalesce(pre.v, 0), coalesce(pre.n, 0)
  from buckets bk
  left join taken cur on cur.b = bk.b
  left join taken pre on pre.b = bk.b - (select span from spec)
  order by bk.b;
$$;

grant execute on function public.analytics_series(text) to authenticated;

-- ------------------------------------------------- the row of figures --------
-- Thirty days against the thirty before it. Conversion is orders over visitors,
-- which is the only conversion this site can honestly claim: it has no basket
-- step to measure and no sessions table beyond its own events.

create or replace view public.analytics_kpis as
with
  now_o as (
    select coalesce(sum(total),0)::numeric v, count(*)::bigint n
    from public.orders
    where status <> 'cancelled' and placed_at >= now() - interval '30 days'
  ),
  pre_o as (
    select coalesce(sum(total),0)::numeric v, count(*)::bigint n
    from public.orders
    where status <> 'cancelled'
      and placed_at >= now() - interval '60 days'
      and placed_at <  now() - interval '30 days'
  ),
  now_c as (
    select count(distinct phone)::bigint n from public.orders
    where status <> 'cancelled' and placed_at >= now() - interval '30 days'
  ),
  pre_c as (
    select count(distinct phone)::bigint n from public.orders
    where status <> 'cancelled'
      and placed_at >= now() - interval '60 days'
      and placed_at <  now() - interval '30 days'
  ),
  now_v as (
    select count(distinct visit)::bigint n from public.events
    where at >= now() - interval '30 days'
  ),
  pre_v as (
    select count(distinct visit)::bigint n from public.events
    where at >= now() - interval '60 days' and at < now() - interval '30 days'
  ),
  refunds as (
    select count(*)::bigint n from public.returns
    where kind = 'refund' and opened_at >= now() - interval '30 days'
  )
select
  (select v from now_o) as revenue,   (select v from pre_o) as revenue_before,
  (select n from now_o) as orders,    (select n from pre_o) as orders_before,
  (select n from now_c) as customers, (select n from pre_c) as customers_before,
  case when (select n from now_o) = 0 then 0
       else round((select v from now_o) / (select n from now_o)) end as aov,
  case when (select n from pre_o) = 0 then 0
       else round((select v from pre_o) / (select n from pre_o)) end as aov_before,
  (select n from now_v) as visitors,  (select n from pre_v) as visitors_before,
  case when (select n from now_v) = 0 then 0
       else round((select n from now_o)::numeric * 100 / (select n from now_v), 2)
  end as conversion,
  case when (select n from pre_v) = 0 then 0
       else round((select n from pre_o)::numeric * 100 / (select n from pre_v), 2)
  end as conversion_before,
  case when (select n from now_o) = 0 then 0
       else round((select n from refunds)::numeric * 100 / (select n from now_o), 2)
  end as refund_rate;

-- ------------------------------------------------------- the people ----------
-- New means the first order ever fell inside the window. Returning means they
-- had bought before it. Counted by phone, the one thing an Indian customer
-- gives correctly every time.

create or replace view public.customer_insights as
with firsts as (
  select phone, min(placed_at) as first_at, count(*) as orders, sum(total) as lifetime
  from public.orders where status <> 'cancelled'
  group by phone
),
active as (
  select distinct phone from public.orders
  where status <> 'cancelled' and placed_at >= now() - interval '30 days'
)
select
  (count(*) filter (where f.first_at >= now() - interval '30 days'))::bigint as new_customers,
  (count(*) filter (where f.first_at <  now() - interval '30 days'))::bigint as returning_customers,
  coalesce(round(avg(f.lifetime)), 0)                                     as lifetime_value,
  case when count(*) = 0 then 0
       else round((count(*) filter (where f.orders > 1))::numeric * 100 / count(*), 1)
  end                                                                     as repeat_rate
from firsts f
join active a on a.phone = f.phone;

-- Where the shirts are going. Real addresses, nothing inferred from an IP.
create or replace view public.top_locations as
select coalesce(nullif(trim(state), ''), 'Not stated') as place,
       count(*)::bigint as orders,
       coalesce(sum(total), 0)::numeric as revenue
from public.orders
where status <> 'cancelled'
group by 1
order by revenue desc;

-- ------------------------------------------------------ where they came from --
-- Sessions per channel, from the utm the tracker now carries on every event.
-- Orders are matched by the utm on the order itself, so a channel's conversion
-- is its own visits against its own sales.

create or replace view public.traffic_sources as
with sessions as (
  select coalesce(nullif(e.detail ->> 'utm_source', ''), 'direct') as channel,
         count(distinct e.visit)::bigint as sessions
  from public.events e
  where e.at >= now() - interval '30 days'
  group by 1
),
sold as (
  select coalesce(nullif(utm_source, ''), 'direct') as channel,
         count(*)::bigint as orders,
         coalesce(sum(total), 0)::numeric as revenue
  from public.orders
  where status <> 'cancelled' and placed_at >= now() - interval '30 days'
  group by 1
)
select
  coalesce(s.channel, o.channel)      as channel,
  coalesce(s.sessions, 0)             as sessions,
  coalesce(o.orders, 0)               as orders,
  coalesce(o.revenue, 0)              as revenue,
  case when coalesce(s.sessions, 0) = 0 then null
       else round(coalesce(o.orders,0)::numeric * 100 / s.sessions, 2)
  end                                 as conversion
from sessions s
full outer join sold o on o.channel = s.channel
order by revenue desc, sessions desc;

-- Phone or desktop, from the width the browser reported. Two buckets, because
-- the tracker records two — inventing a tablet row would mean guessing.
create or replace view public.device_split as
select coalesce(nullif(viewport, ''), 'unknown') as device,
       count(distinct visit)::bigint            as sessions
from public.events
where at >= now() - interval '30 days'
group by 1
order by sessions desc;

-- What a campaign actually brought, matched on the tag it put in its links.
create or replace view public.campaign_results as
select c.id, c.name, c.channel, c.state,
       (select count(*) from public.campaign_recipients r where r.campaign_id = c.id)::bigint as recipients,
       coalesce(o.orders, 0)  as orders,
       coalesce(o.revenue, 0) as revenue
from public.campaigns c
left join (
  select lower(utm_campaign) as tag,
         count(*)::bigint as orders,
         coalesce(sum(total),0)::numeric as revenue
  from public.orders
  where status <> 'cancelled' and coalesce(utm_campaign,'') <> ''
  group by 1
) o on o.tag = lower(coalesce(c.utm_campaign, c.name))
order by revenue desc, c.made_at desc;

-- --------------------------------------------------------- the lock ----------
-- Same discipline as the ninth file, applied the moment a view is born rather
-- than discovered later: a view does not obey row-level security on its own.

do $$
declare v text;
begin
  foreach v in array array['analytics_kpis','customer_insights','top_locations',
                           'traffic_sources','device_split','campaign_results'] loop
    execute format('alter view public.%I set (security_invoker = on);', v);
    execute format('revoke select on public.%I from anon;', v);
    execute format('grant  select on public.%I to authenticated;', v);
  end loop;
end $$;
