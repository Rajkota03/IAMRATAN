-- Accounts, without ever asking anyone to make one.
--
-- The house rule has not changed: nobody is forced to sign in to buy. What
-- changes is that an order now leaves an account behind it. The customer never
-- fills in a password — there isn't one. They gave us a phone number and an
-- email at checkout; that IS the account. When they later want to see their
-- orders they ask for a code, and the account that was already waiting becomes
-- theirs.
--
-- Three things had to be true for that to work, and one of them was broken in a
-- way that would have taken the shop down:
--
--   1. THE ANON TRAP. Every write policy in this database is granted `to anon`.
--      A signed-in customer is not `anon` — they are `authenticated`, and the
--      only `authenticated` policy is "admins only". So the moment sign-in
--      shipped, every signed-in customer would have been unable to place an
--      order, leave a cart, or ask for a return, with a 403 and no explanation.
--      Every one of those policies is widened below.
--
--   2. IDENTITY IS THE PHONE. This shop has always keyed a customer by phone
--      (see the `customers` view and the measurement book) because it is the one
--      thing an Indian customer gives correctly every time. Emails get typos and
--      get shared. So matching is on the last ten digits, normalised, and email
--      is a secondary key.
--
--   3. VIEWS LEAK. RUN-THIS-NINTH.sql fixed a real leak where views bypassed
--      RLS. Every view added here is `security_invoker = on` and revoked from
--      anon, or it would hand one customer another customer's orders.

-- ---------------------------------------------------------------- profiles --

-- The account. It exists from the moment an order is placed, with no auth user
-- attached — `user_id` stays null until the person actually signs in and claims
-- it. That is the whole trick: the account is created by buying, not by
-- registering.
create table if not exists public.profiles (
  id          bigint generated always as identity primary key,
  user_id     uuid unique references auth.users(id) on delete set null,
  first_name  text,
  last_name   text,
  email       text,
  phone       text,                       -- as given, for display
  phone_key   text,                       -- last 10 digits, for matching
  marketing   boolean not null default false,   -- consent, off unless asked for
  first_seen  timestamptz default now(),
  claimed_at  timestamptz,                -- when they first signed in
  updated_at  timestamptz default now()
);

-- Ten digits is the whole of an Indian mobile number. +91, 0091, leading 0 and
-- spaces are all the same person, and they will type it differently every time.
create or replace function public.phone_key(p text)
returns text language sql immutable as $$
  select nullif(right(regexp_replace(coalesce(p, ''), '\D', '', 'g'), 10), '');
$$;

create unique index if not exists profiles_phone_key_uidx
  on public.profiles (phone_key) where phone_key is not null;
create unique index if not exists profiles_email_uidx
  on public.profiles (lower(email)) where email is not null;

drop trigger if exists profiles_touch on public.profiles;
create trigger profiles_touch before update on public.profiles
  for each row execute function public.touch();

-- Orders point at the account. Nullable, because an order placed before this
-- migration has no profile and must not break.
alter table public.orders   add column if not exists profile_id bigint references public.profiles(id) on delete set null;
alter table public.carts    add column if not exists profile_id bigint references public.profiles(id) on delete set null;
alter table public.returns  add column if not exists profile_id bigint references public.profiles(id) on delete set null;

create index if not exists orders_profile_idx on public.orders (profile_id, placed_at desc);

-- ------------------------------------------------- the account-making bit --

-- Find the account for a phone/email, or make one. Runs as definer because an
-- anonymous shopper must be able to cause a row here without being able to read
-- anybody else's.
create or replace function public.account_for(
  in_phone text, in_email text, in_first text default null, in_last text default null
) returns bigint
language plpgsql security definer set search_path = public as $$
declare
  k text := public.phone_key(in_phone);
  e text := nullif(lower(trim(coalesce(in_email, ''))), '');
  found bigint;
begin
  if k is null and e is null then return null; end if;

  select id into found from public.profiles
   where (k is not null and phone_key = k)
      or (e is not null and lower(email) = e)
   order by (phone_key = k) desc nulls last
   limit 1;

  if found is null then
    insert into public.profiles (first_name, last_name, email, phone, phone_key)
    values (nullif(in_first,''), nullif(in_last,''), in_email, in_phone, k)
    returning id into found;
  else
    -- Never overwrite a name they have already given us with a blank, and never
    -- silently move an account onto a different phone.
    update public.profiles set
      first_name = coalesce(nullif(in_first,''), first_name),
      last_name  = coalesce(nullif(in_last,''),  last_name),
      email      = coalesce(email, in_email),
      phone      = coalesce(phone, in_phone),
      phone_key  = coalesce(phone_key, k)
    where id = found;
  end if;

  return found;
end $$;

grant execute on function public.account_for(text, text, text, text) to anon, authenticated;

-- An order arriving with no profile makes one from the details on the order
-- itself. This is what "the account is created when they place an order" means
-- in practice, and doing it in a trigger means it cannot be skipped by any
-- client that forgets to call it.
create or replace function public.attach_account()
returns trigger language plpgsql security definer set search_path = public as $$
declare
  first_part text := split_part(coalesce(new.name, ''), ' ', 1);
  rest_part  text := nullif(trim(substr(coalesce(new.name, ''), length(split_part(coalesce(new.name,''),' ',1)) + 1)), '');
begin
  if new.profile_id is null then
    new.profile_id := public.account_for(new.phone, new.email, first_part, rest_part);
  end if;
  return new;
end $$;

drop trigger if exists orders_account on public.orders;
create trigger orders_account before insert on public.orders
  for each row execute function public.attach_account();

-- ------------------------------------------------------ claiming it later --

-- Called once, straight after a customer verifies their code. Ties the auth
-- user to the account that has been sitting there since their first order, and
-- back-fills every past order they placed as a guest.
create or replace function public.claim_account(in_first text default null, in_last text default null)
returns public.profiles
language plpgsql security definer set search_path = public as $$
declare
  uid uuid := auth.uid();
  em  text := nullif(lower(auth.jwt() ->> 'email'), '');
  ph  text := public.phone_key(auth.jwt() ->> 'phone');
  p   public.profiles;
begin
  if uid is null then raise exception 'not signed in'; end if;

  -- Already claimed by this user?
  select * into p from public.profiles where user_id = uid;

  if p.id is null then
    -- The account made by their earlier order, if there was one.
    select * into p from public.profiles
     where user_id is null
       and ((ph is not null and phone_key = ph) or (em is not null and lower(email) = em))
     order by (phone_key = ph) desc nulls last
     limit 1;
  end if;

  if p.id is null then
    insert into public.profiles (user_id, email, phone, phone_key, first_name, last_name, claimed_at)
    values (uid, em, auth.jwt() ->> 'phone', ph, nullif(in_first,''), nullif(in_last,''), now())
    returning * into p;
  else
    update public.profiles set
      user_id    = uid,
      claimed_at = coalesce(claimed_at, now()),
      email      = coalesce(email, em),
      phone_key  = coalesce(phone_key, ph),
      first_name = coalesce(nullif(in_first,''), first_name),
      last_name  = coalesce(nullif(in_last,''),  last_name)
    where id = p.id
    returning * into p;
  end if;

  -- Everything they bought before they ever signed in is theirs.
  update public.orders o set profile_id = p.id
   where o.profile_id is distinct from p.id
     and ( (p.phone_key is not null and public.phone_key(o.phone) = p.phone_key)
        or (p.email is not null and lower(o.email) = lower(p.email)) );

  return p;
end $$;

grant execute on function public.claim_account(text, text) to authenticated;

-- Their own name, set after the first code. Kept separate from claim_account so
-- the app can ask for it at leisure without re-running the back-fill.
create or replace function public.set_my_name(in_first text, in_last text)
returns public.profiles
language plpgsql security definer set search_path = public as $$
declare p public.profiles;
begin
  if auth.uid() is null then raise exception 'not signed in'; end if;
  update public.profiles
     set first_name = nullif(trim(in_first), ''),
         last_name  = nullif(trim(in_last), '')
   where user_id = auth.uid()
   returning * into p;
  if p.id is null then raise exception 'no account to name'; end if;
  return p;
end $$;

grant execute on function public.set_my_name(text, text) to authenticated;

-- ------------------------------------------------------------------- RLS ---

alter table public.profiles enable row level security;

-- A customer sees exactly one profile: their own.
drop policy if exists "your own account" on public.profiles;
create policy "your own account" on public.profiles for select to authenticated
  using (user_id = auth.uid());

drop policy if exists "change your own account" on public.profiles;
create policy "change your own account" on public.profiles for update to authenticated
  using (user_id = auth.uid()) with check (user_id = auth.uid());

drop policy if exists "admins only" on public.profiles;
create policy "admins only" on public.profiles for all to authenticated
  using (public.is_admin()) with check (public.is_admin());

-- No anon policy at all: an anonymous shopper never reads or writes this table
-- directly. account_for() is security definer and does it for them.

-- ---- THE ANON TRAP, closed -------------------------------------------------
-- Every one of these existed as `to anon` only. Without the matching
-- `authenticated` policy, signing in would have taken the shop away from the
-- customer who signed in.

drop policy if exists "signed-in may place an order" on public.orders;
create policy "signed-in may place an order"
  on public.orders for insert to authenticated with check (true);

-- ...and may read back their own, which is the entire point of having an
-- account. Never anybody else's: the check is on the profile, not the phone
-- typed into a box.
drop policy if exists "your own orders" on public.orders;
create policy "your own orders" on public.orders for select to authenticated
  using (profile_id in (select id from public.profiles where user_id = auth.uid()));

drop policy if exists "signed-in may leave a cart" on public.carts;
create policy "signed-in may leave a cart"
  on public.carts for insert to authenticated with check (true);

drop policy if exists "signed-in may change their cart" on public.carts;
create policy "signed-in may change their cart"
  on public.carts for update to authenticated
  using (recovered is null) with check (true);

drop policy if exists "signed-in may ask for a return" on public.returns;
create policy "signed-in may ask for a return"
  on public.returns for insert to authenticated with check (true);

drop policy if exists "your own returns" on public.returns;
create policy "your own returns" on public.returns for select to authenticated
  using (profile_id in (select id from public.profiles where user_id = auth.uid()));

drop policy if exists "signed-in may be counted" on public.events;
create policy "signed-in may be counted"
  on public.events for insert to authenticated with check (true);

drop policy if exists "signed-in may open a timeline" on public.order_events;
create policy "signed-in may open a timeline"
  on public.order_events for insert to authenticated with check (true);

-- A customer may follow their own order through the house.
drop policy if exists "your own timeline" on public.order_events;
create policy "your own timeline" on public.order_events for select to authenticated
  using (order_id in (
    select o.id from public.orders o
     join public.profiles p on p.id = o.profile_id
    where p.user_id = auth.uid()));

-- --------------------------------------------------------- what they see ---

-- One row per order, only ever their own, with the house's internal note and
-- the customer's own address stripped back to what is useful to them.
create or replace view public.my_orders as
  select o.ref, o.status, o.payment_state, o.items, o.subtotal, o.discount_amount,
         o.total, o.courier, o.tracking, o.placed_at, o.updated_at
    from public.orders o
    join public.profiles p on p.id = o.profile_id
   where p.user_id = auth.uid();

-- Both lines matter. security_invoker makes the view obey the caller's RLS
-- instead of the owner's; the revoke stops an anonymous visitor reading it at
-- all. RUN-THIS-NINTH.sql exists because this was got wrong once already.
alter view public.my_orders set (security_invoker = on);
revoke select on public.my_orders from anon;
grant  select on public.my_orders to authenticated;

-- The house's own view of an account: who they are, what they have spent, and
-- whether they ever signed in. Admin only.
create or replace view public.account_book as
  select p.id, p.first_name, p.last_name, p.email, p.phone, p.marketing,
         p.first_seen, p.claimed_at,
         (p.user_id is not null) as signed_in,
         count(o.id) filter (where o.status <> 'cancelled')            as orders,
         coalesce(sum(o.total) filter (where o.status <> 'cancelled'), 0) as lifetime,
         max(o.placed_at)                                              as last_order
    from public.profiles p
    left join public.orders o on o.profile_id = p.id
   group by p.id;

alter view public.account_book set (security_invoker = on);
revoke select on public.account_book from anon;
grant  select on public.account_book to authenticated;

-- ------------------------------------------------------------ back-fill ----

-- Every order ever placed becomes an account, so the CRM is not empty on the
-- day this ships and so a returning customer's history is already waiting when
-- they first sign in.
do $$
declare r record; pid bigint;
begin
  for r in select id, name, phone, email from public.orders
            where profile_id is null and (phone is not null or email is not null)
            order by placed_at
  loop
    pid := public.account_for(
      r.phone, r.email,
      split_part(coalesce(r.name,''), ' ', 1),
      nullif(trim(substr(coalesce(r.name,''), length(split_part(coalesce(r.name,''),' ',1)) + 1)), '')
    );
    if pid is not null then
      update public.orders set profile_id = pid where id = r.id;
    end if;
  end loop;
end $$;
