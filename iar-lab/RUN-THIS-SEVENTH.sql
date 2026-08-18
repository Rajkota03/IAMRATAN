-- I AM RATAN — what the Orders, Products and Inventory screens still need.
-- Run in the SQL Editor after the previous six.

-- ------------------------------------------------------------------ SKUs --
-- A code the warehouse can say out loud. Generated from the slug so the house
-- never has to invent one, but editable, because a house that has been trading
-- for twenty years may already have its own.

alter table public.products add column if not exists sku text;

update public.products
   set sku = 'IAR-' || upper(left(regexp_replace(slug, '[^a-z]', '', 'g'), 3))
             || '-' || lpad(sort_order::text, 3, '0')
 where sku is null;

-- ------------------------------------------------------- order timeline --
-- Every stage an order passed through, and when. The mockup shows this as a
-- vertical list on the order — it cannot be reconstructed from a status column,
-- because a status column only ever knows the present tense.

create table if not exists public.order_events (
  id        bigint generated always as identity primary key,
  order_id  bigint not null references public.orders(id) on delete cascade,
  stage     text not null,
  note      text,
  by_email  text,
  at        timestamptz default now()
);
create index if not exists order_events_idx on public.order_events (order_id, at);

alter table public.order_events enable row level security;
drop policy if exists "admins only" on public.order_events;
create policy "admins only" on public.order_events for all to authenticated
  using (public.is_admin()) with check (public.is_admin());
-- the first line of the timeline is written when the order is placed
drop policy if exists "anyone may open a timeline" on public.order_events;
create policy "anyone may open a timeline"
  on public.order_events for insert to anon with check (true);

-- Writing the timeline is the database's job, not the browser's. A stage change
-- made from anywhere — the desk, a script, SQL — lands in the history, and no
-- caller can forget to record it.
create or replace function public.note_stage() returns trigger
language plpgsql security definer set search_path = public as $$
begin
  if tg_op = 'INSERT' then
    insert into public.order_events (order_id, stage, note)
    values (new.id, new.status, 'Order placed');
  elsif new.status is distinct from old.status then
    insert into public.order_events (order_id, stage, by_email)
    values (new.id, new.status, coalesce(auth.jwt() ->> 'email', 'the house'));
  end if;
  return new;
end $$;

drop trigger if exists orders_timeline on public.orders;
create trigger orders_timeline after insert or update on public.orders
  for each row execute function public.note_stage();

-- backfill a first line for orders placed before this existed
insert into public.order_events (order_id, stage, note, at)
select o.id, o.status, 'Order placed', o.placed_at
from public.orders o
where not exists (select 1 from public.order_events e where e.order_id = o.id);

-- --------------------------------------------------- payment and courier --
alter table public.orders add column if not exists payment_method text default 'prepaid';
alter table public.orders add column if not exists payment_state  text default 'pending';

-- ------------------------------------------------------ the KPI strips --
-- The row of figures above each list in the mockups.

create or replace view public.product_stats as
select
  count(*)                                              as total,
  count(*) filter (where visible)                       as active,
  (select count(distinct p.id) from public.products p
     join public.inventory i on i.product_id = p.id
    group by p.id having sum(i.qty) = 0)                as out_of_stock,
  (select count(*) from (
      select p.id from public.products p
        join public.inventory i on i.product_id = p.id
       group by p.id having sum(i.qty) > 0 and sum(i.qty) <= 10) x) as low_stock,
  (select count(*) from public.inventory)               as variants,
  (select count(distinct collection) from public.products
     where collection is not null)                      as collections
from public.products;

create or replace view public.inventory_stats as
select
  (select coalesce(sum(qty),0) from public.inventory)              as total_stock,
  (select count(*) from public.inventory where qty > 0 and qty <= 3) as low,
  (select count(*) from public.inventory where qty = 0)            as out,
  (select coalesce(sum(delta),0) from public.stock_moves
     where reason = 'new_stock' and at >= now() - interval '30 days') as incoming,
  (select coalesce(-sum(delta),0) from public.stock_moves
     where reason = 'damaged')                                     as damaged;

-- ---------------------------------------------------- customers, fuller --
-- The mockup wants status and average order beside lifetime spend. Inactive
-- means nothing bought in six months, which for a shirt is not long enough to
-- write somebody off — so it says "quiet", not "inactive".

create or replace view public.customer_list as
with ok as (select * from public.orders where status <> 'cancelled'),
totals as (
  select phone, max(name) as name, max(email) as email, max(city) as city,
         count(*) as orders, sum(total) as lifetime,
         round(avg(total)) as aov, max(placed_at) as last_order
  from ok group by phone
),
necks as (
  select phone, neck from (
    select o.phone, i->>'size' as neck, count(*) n,
           row_number() over (partition by o.phone order by count(*) desc) rk
    from ok o, jsonb_array_elements(o.items) i
    group by o.phone, i->>'size'
  ) x where rk = 1
)
select t.*, n.neck as usual_neck,
       case when t.last_order > now() - interval '6 months' then 'active'
            else 'quiet' end as state
from totals t left join necks n on n.phone = t.phone
order by t.lifetime desc;
