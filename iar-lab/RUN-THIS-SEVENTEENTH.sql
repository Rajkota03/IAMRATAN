-- One man, one key.
--
-- The customer page can now show everything the house knows about a person, and
-- for orders it is exact — those carry a profile_id. For the other four things
-- it was guesswork, because a phone number is written down differently every
-- time it is written down:
--
--   the cart      strips it to digits          (checkout.html:257)
--   the order     keeps it exactly as typed    (checkout.html:516)
--   a sitting     is typed by hand at the desk
--   an enquiry    is whatever the visitor put in the box
--
-- So the page was matching with two `ilike` patterns and hoping. That finds most
-- people and quietly loses the rest, which is the worst way to be wrong: a man
-- with three sittings and two enquiries shows up looking like a stranger, and
-- nobody can tell the difference between "he has no history" and "we could not
-- find it". The desk then treats a returning customer as a new one.
--
-- `phone_key()` already exists and already decides this question for profiles —
-- the last ten digits, which is the whole of an Indian mobile number however it
-- was typed in front. This puts the same key on the four tables that were
-- missing it, as a GENERATED column so it can never drift from the phone beside
-- it and no code has to remember to maintain it.

-- ------------------------------------------------------------- the key ------

-- `phone_key` is already immutable (RUN-THIS-FIFTEENTH.sql), which is what lets
-- it be used in a generated column at all.
alter table public.measurements
  add column if not exists phone_key text
  generated always as (public.phone_key(phone)) stored;

alter table public.enquiries
  add column if not exists phone_key text
  generated always as (public.phone_key(phone)) stored;

alter table public.carts
  add column if not exists phone_key text
  generated always as (public.phone_key(phone)) stored;

alter table public.campaign_recipients
  add column if not exists phone_key text
  generated always as (public.phone_key(phone)) stored;

create index if not exists measurements_key_idx        on public.measurements (phone_key);
create index if not exists enquiries_key_idx           on public.enquiries (phone_key);
create index if not exists carts_key_idx               on public.carts (phone_key);
create index if not exists campaign_recipients_key_idx on public.campaign_recipients (phone_key);

-- The orders table keeps its phone exactly as the customer typed it, because
-- that is the record of what he said. It gets a key beside it rather than
-- instead of it.
alter table public.orders
  add column if not exists phone_key text
  generated always as (public.phone_key(phone)) stored;

create index if not exists orders_key_idx on public.orders (phone_key);

-- --------------------------------------------------------- the back-fill ----

-- FIFTEENTH back-filled orders only. A cart and a return belong to a person
-- just as much, and the abandoned-cart chase list is worth more when the desk
-- can see who it is chasing.
update public.carts c
   set profile_id = p.id
  from public.profiles p
 where c.profile_id is null
   and p.phone_key is not null
   and c.phone_key = p.phone_key;

-- A cart with no phone but an email is still somebody.
update public.carts c
   set profile_id = p.id
  from public.profiles p
 where c.profile_id is null
   and c.email is not null
   and lower(c.email) = lower(p.email);

-- A return belongs to whoever placed the order it came from. Going through the
-- order rather than the phone means it is right even when the return was opened
-- by somebody else in the household.
update public.returns r
   set profile_id = o.profile_id
  from public.orders o
 where r.profile_id is null
   and r.order_id = o.id
   and o.profile_id is not null;

update public.returns r
   set profile_id = o.profile_id
  from public.orders o
 where r.profile_id is null
   and r.order_id is null
   and r.order_ref is not null
   and o.ref = r.order_ref
   and o.profile_id is not null;

-- ------------------------------------------------- consent, by account id ---

-- `set_marketing()` resolves a person from a phone or an email, which is right
-- when an anonymous checkout is recording consent because that is all it has.
-- It is wrong for the desk: the desk is already looking at one specific account
-- and should not be re-deriving which one it means. Two profiles that ever
-- shared an email would resolve to whichever came first.
--
-- Opting a man OUT is the operation that must never hit the wrong row, so it
-- gets a version that takes the account itself and cannot be ambiguous.
create or replace function public.set_marketing_for(in_profile bigint, in_on boolean)
returns boolean
language plpgsql security definer set search_path = public as $$
begin
  if not public.is_admin() then
    raise exception 'only the house may change consent from the desk';
  end if;

  update public.profiles set
    marketing       = coalesce(in_on, false),
    marketing_at    = case when in_on then coalesce(marketing_at, now()) else marketing_at end,
    marketing_source= case when in_on then coalesce(marketing_source, 'the desk') else marketing_source end,
    unsubscribed_at = case when in_on then null else coalesce(unsubscribed_at, now()) end
  where id = in_profile;

  return found;
end $$;

revoke all on function public.set_marketing_for(bigint, boolean) from public;
grant execute on function public.set_marketing_for(bigint, boolean) to authenticated;

-- --------------------------------------------------- the way in, in the menu --

-- Sign-in was put in the footer of every page and nowhere else. Raj's answer to
-- that, and he is right: "Customer will not type /account". Nobody scrolls to
-- the bottom of a shop to find their orders.
--
-- Putting it in the header's HTML is not enough on its own and it is worth
-- knowing why, because it looks like it works. `house.js` reads this table on
-- every page load and rewrites the menu to match it whenever the two differ —
-- so five links in the HTML and four rows here means the fifth is silently
-- removed a moment after the page paints. The row below is what actually puts
-- it in the menu; the HTML is the copy that shows before this table is read and
-- if Supabase is ever asleep.
insert into public.nav_items (label, href, place, sort_order, live)
select 'Your orders', 'account.html', 'main', 5, true
where not exists (
  select 1 from public.nav_items where href = 'account.html' and place = 'main'
);

-- ------------------------------------------------------------ one person ----

-- Everything the house knows about one account, found by key rather than by
-- guesswork. Kept as a view so the desk makes one request instead of six and so
-- the matching rule lives in one place — the next screen that needs a person's
-- history should read this rather than reinvent the join.
create or replace view public.person_book as
  select
    p.id as profile_id,
    p.phone_key,
    (select count(*) from public.orders o
      where o.profile_id = p.id and o.status <> 'cancelled')            as orders,
    (select count(*) from public.returns r
      where r.profile_id = p.id)                                       as returns,
    (select count(*) from public.enquiries e
      where p.phone_key is not null and e.phone_key = p.phone_key)     as enquiries,
    (select count(*) from public.carts c
      where c.profile_id = p.id
         or (p.phone_key is not null and c.phone_key = p.phone_key))   as carts,
    (select count(*) from public.measurements m
      where p.phone_key is not null and m.phone_key = p.phone_key)     as sittings,
    (select count(*) from public.campaign_recipients cr
      where p.phone_key is not null and cr.phone_key = p.phone_key)    as campaigns
  from public.profiles p;

-- Both lines, every time. A view without them reads with the owner's rights and
-- would hand one customer's history to anybody holding the public key —
-- RUN-THIS-NINTH.sql exists because that happened once already.
alter view public.person_book set (security_invoker = on);
revoke select on public.person_book from anon;
grant  select on public.person_book to authenticated;
