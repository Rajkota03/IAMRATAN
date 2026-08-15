-- I AM RATAN — the admin: who may sign in, and the tables the shop still needs.
-- Run once in the Supabase SQL Editor, after supabase-shop.sql.
--
-- HOW LOGIN IS KEPT SAFE WITHOUT ME TOUCHING THE DASHBOARD
-- Anyone may create a Supabase account — that is fine and deliberate, because
-- an account by itself can do nothing at all. Every write policy below asks a
-- second question: is this person's email in the admins table? If it is not,
-- they are signed in to an empty room. So the allowlist, not the signup form,
-- is the door.

create table if not exists public.admins (
  email      text primary key,
  name       text,
  added_at   timestamptz default now()
);

-- Who may sign in. Add or remove people by editing this table — nothing else
-- needs to change. The house's published address, and the person building the
-- site. REMOVE THE
-- SECOND ONE AT HANDOVER — a freelancer's personal address should not keep a
-- key to the client's shop after the work is done.
insert into public.admins (email, name) values
  ('prashanth@iamratan.co.in', 'The house'),
  ('rajkota.sql@gmail.com',    'Rajnikanth — remove at handover')
on conflict (email) do nothing;

alter table public.admins enable row level security;

-- an admin may see who else is an admin; nobody anonymous may see anything
drop policy if exists "admins may read the list" on public.admins;
create policy "admins may read the list"
  on public.admins for select to authenticated
  using (auth.jwt()->>'email' in (select email from public.admins));

-- ---------------------------------------------------------------- orders --

create table if not exists public.orders (
  id           bigint generated always as identity primary key,
  ref          text unique not null,          -- what the customer is told
  name         text not null,
  phone        text not null,
  email        text,
  address      text,
  city         text,
  pincode      text,
  items        jsonb not null default '[]'::jsonb,
  total        integer not null default 0,
  -- new -> making -> shipped -> delivered, or cancelled at any point
  status       text not null default 'new',
  payment_ref  text,                          -- Razorpay's id, when it exists
  note         text,                          -- the house's own note
  placed_at    timestamptz default now(),
  updated_at   timestamptz default now()
);

create index if not exists orders_status_idx on public.orders (status, placed_at desc);

-- ------------------------------------------------------------- enquiries --
-- Bespoke and wardrobe leads. Today the form goes to WhatsApp; once this table
-- exists the same submission can also land here so nothing is lost in a chat.

create table if not exists public.enquiries (
  id         bigint generated always as identity primary key,
  name       text,
  phone      text,
  email      text,
  service    text,                            -- 'Made to Measure' | 'Wardrobe Management'
  message    text,
  handled    boolean not null default false,
  came_at    timestamptz default now()
);

create index if not exists enquiries_open_idx on public.enquiries (handled, came_at desc);

-- ---------------------------------------------------------------- safety --

alter table public.orders    enable row level security;
alter table public.enquiries enable row level security;

-- A customer may place an order and leave an enquiry. They may never read one
-- back — not their own, and certainly not anybody else's. Order lookup, when it
-- is built, will go through a function that checks the reference AND the phone
-- number, never through a plain select.
drop policy if exists "anyone may place an order" on public.orders;
create policy "anyone may place an order"
  on public.orders for insert to anon with check (true);

drop policy if exists "anyone may leave an enquiry" on public.enquiries;
create policy "anyone may leave an enquiry"
  on public.enquiries for insert to anon with check (true);

-- the house, signed in AND on the list, may do everything
do $$
declare t text;
begin
  foreach t in array array['orders','enquiries','products','inventory','settings','events'] loop
    execute format(
      'drop policy if exists "the house may write" on public.%I;', t);
    execute format(
      'drop policy if exists "admins only" on public.%I; '
      'create policy "admins only" on public.%I for all to authenticated '
      'using (auth.jwt()->>''email'' in (select email from public.admins)) '
      'with check (auth.jwt()->>''email'' in (select email from public.admins));',
      t, t);
  end loop;
end $$;

-- keep updated_at honest on orders
drop trigger if exists orders_touch on public.orders;
create trigger orders_touch before update on public.orders
  for each row execute function public.touch();

-- --------------------------------------------------------------- reports --
-- What the house should see first thing in the morning.

create or replace view public.dashboard as
select
  (select count(*) from public.orders where status = 'new')            as orders_new,
  (select count(*) from public.orders
     where placed_at > now() - interval '7 days')                      as orders_week,
  (select coalesce(sum(total),0) from public.orders
     where placed_at > now() - interval '7 days'
       and status <> 'cancelled')                                      as sales_week,
  (select count(*) from public.enquiries where handled = false)        as enquiries_open,
  (select count(*) from public.inventory where qty = 0)                as sizes_out,
  (select count(*) from public.inventory where qty > 0 and qty <= 3)   as sizes_low;

-- Which cloth, in which neck the house does not cut, and how many asked.
-- Already created by supabase-setup.sql; repeated here so this file stands alone.
create or replace view public.bespoke_demand as
select
  detail->>'cloth' as cloth,
  detail->>'size'  as neck,
  count(*)         as asked,
  max(at)          as last_asked
from public.events
where name = 'uncut_size'
group by 1, 2
order by asked desc, last_asked desc;
