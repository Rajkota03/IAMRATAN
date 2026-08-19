-- I AM RATAN — the stock a sale takes, and the customer the shop has never kept.
-- Run in the SQL Editor after the previous fifteen.
--
-- TWO FOUNDATIONS THAT WERE NEVER LAID.
--
-- THE FIRST IS A HOLE IN THE FLOOR. Nothing in this database has ever reduced
-- the stock when an order arrives. Not a trigger, not a function, not a call
-- from the checkout — nothing. Every number in `inventory` is whatever the
-- house last typed into the Inventory screen, and it stays that number for ever
-- however many shirts leave the building. So `soldOut()` never goes true, the
-- last 42 is sold to four men on the same afternoon, and the first the house
-- hears of it is four apologies later. The shop would oversell on the first day
-- it took two orders for the same neck, and it would keep doing it silently.
-- Everything down to the line marked THE CRM closes that.
--
-- THE SECOND IS QUIETER AND WILL COST MORE. There is a customers *report* — a
-- view grouped by phone — and there has never been anywhere to write down that
-- a man prefers a longer sleeve, that he is a difficult delivery, or that he is
-- worth ringing when the linen lands. A report is not a relationship. Nor is
-- there any record of marketing consent: `profiles.marketing` is a lone boolean
-- that defaults to false, nothing writes it, nothing reads it, and there is no
-- way on earth for a person to get off a list once they are on one. Under the
-- DPDP Act that is not a missing feature, it is a breach waiting for a
-- complaint — consent must be recorded, and withdrawing it must be at least as
-- easy as giving it. Both are built below.
--
-- NOTHING IS BACK-FILLED. Read the last section before you worry about that.

-- =============================================================== THE STOCK ==

-- A movement now knows which order caused it. `stock_moves` was written to
-- answer "where did it go?" and until this column it could only ever answer
-- "out" — a sale and a shrinkage looked identical. It also does the work of a
-- guard: the whole double-refund question below is answered by adding up this
-- order's own movements, with no flag to keep in step.
--
-- on delete set null, not cascade: deleting a test order (RUN-THIS-FOURTEENTH
-- invites exactly that) must not take the ledger with it. Note that deleting an
-- order does NOT put its stock back — the house corrects that by hand from the
-- Inventory screen, which is honest, because a deleted order leaves nothing
-- behind to reverse.
alter table public.stock_moves
  add column if not exists order_id bigint references public.orders(id) on delete set null;
create index if not exists moves_order_idx on public.stock_moves (order_id);

-- ---------------------------------------------------------- taking it out --
-- The join nobody expects. `inventory` is keyed by (product_id, size) and an
-- order line carries a SLUG, not an id — so every line has to come through
-- `products.slug` to find the row it is meant to reduce. Get that wrong and the
-- update matches nothing, silently, for ever.
--
-- IT MUST NEVER REFUSE AN ORDER. A cloth deleted since the customer opened the
-- page, a neck that was never stocked, a qty that arrives as the word "two" —
-- every one of those is caught and stepped over. An order that has landed is
-- money in the house; a stock count that is one out is a five-second correction
-- on the Inventory screen. Refusing the second at the cost of the first would
-- be the most expensive kind of tidiness.
--
-- security definer, and this is the point of the whole file: RUN-THIS-NINTH
-- locked `inventory` writes to is_admin(), and the person placing the order is
-- an anonymous shopper who will never be on that list. Without definer the
-- update matches zero rows and the shop oversells exactly as it does today,
-- only now with a trigger in place to make everyone feel better about it.

create or replace function public.take_the_stock(in_order bigint)
returns void
language plpgsql security definer set search_path = public as $$
declare
  o     public.orders%rowtype;
  line  jsonb;
  pid   bigint;
  sz    text;
  want  integer;
  had   integer;
  left_ integer;
begin
  select * into o from public.orders where id = in_order;
  if not found then return; end if;

  for line in select value from jsonb_array_elements(coalesce(o.items, '[]'::jsonb))
  loop
    begin
      sz   := nullif(trim(line->>'size'), '');
      want := greatest(coalesce(nullif(line->>'qty', '')::int, 1), 0);
      if sz is null or want = 0 then continue; end if;

      select p.id into pid from public.products p where p.slug = line->>'slug';
      if pid is null then continue; end if;      -- a cloth that no longer exists

      /* for update, and it earns the lock. Two men buying the last 42 in the
         same second both read qty = 1 and both write qty = 0, and one shirt has
         been sold twice with the count looking perfectly correct afterwards. */
      select i.qty into had
        from public.inventory i
       where i.product_id = pid and i.size = sz
         for update;
      if had is null then continue; end if;      -- a neck never stocked

      /* Clamped at zero rather than allowed to go negative, and not out of
         squeamishness: `inventory_stats`, `kpis` and `action_required` all count
         out-of-stock as `qty = 0`. A row sitting at minus one would vanish from
         the sold-out count AND from the low-stock count at the same time —
         the one neck the house most needs to see would be the only one no
         screen mentions. The oversell is not swallowed, it is written onto the
         order's own timeline a few lines down, where somebody will read it. */
      left_ := greatest(had - want, 0);

      update public.inventory
         set qty = left_, updated_at = now()
       where product_id = pid and size = sz;

      if left_ <> had then
        insert into public.stock_moves
          (order_id, product_id, size, delta, reason, before_qty, after_qty, by_email)
        values (in_order, pid, sz, left_ - had, 'sale', had, left_,
                coalesce(auth.jwt() ->> 'email', 'the shop'));
      end if;

      if want > had then
        insert into public.order_events (order_id, stage, note)
        values (in_order, 'stock',
          'Sold ' || want || ' in neck ' || sz || ' with only ' || had ||
          ' on the shelf. The shortfall is not in the stock count — cut or correct it.');
      end if;

    exception when others then
      /* One bad line does not cost the house the order. It is written down
         rather than swallowed, and the write is itself wrapped, because a
         failing apology that takes the order with it is worse than no apology. */
      begin
        insert into public.order_events (order_id, stage, note)
        values (in_order, 'stock', 'Stock was not adjusted for one line: ' || sqlerrm);
      exception when others then null;
      end;
    end;
  end loop;
end $$;

-- ------------------------------------------------------- putting it back ---
-- The mirror, and it deliberately does NOT re-read the order's items. It gives
-- back what actually left, which after clamping is not always what was asked
-- for: an order for two when one was on the shelf took one, so cancelling it
-- returns one. Reading the items would hand back a shirt the house never had.
--
-- The double-refund guard is the `having` line and nothing else. Once the stock
-- is back the order's own movements sum to zero, so a second cancellation finds
-- no group to act on. There is no flag to set, nothing to keep in step, and the
-- guard cannot drift out of agreement with the ledger because it IS the ledger.

create or replace function public.give_the_stock_back(in_order bigint)
returns void
language plpgsql security definer set search_path = public as $$
declare r record; had integer; now_q integer;
begin
  for r in
    select m.product_id, m.size, -sum(m.delta) as back
      from public.stock_moves m
     where m.order_id = in_order
       and m.reason in ('sale', 'return')
     group by m.product_id, m.size
    having sum(m.delta) < 0
  loop
    begin
      select i.qty into had
        from public.inventory i
       where i.product_id = r.product_id and i.size = r.size
         for update;
      if had is null then continue; end if;

      now_q := had + r.back;
      update public.inventory
         set qty = now_q, updated_at = now()
       where product_id = r.product_id and size = r.size;

      insert into public.stock_moves
        (order_id, product_id, size, delta, reason, before_qty, after_qty, by_email)
      values (in_order, r.product_id, r.size, r.back, 'return', had, now_q,
              coalesce(auth.jwt() ->> 'email', 'the house'));
    exception when others then null;
    end;
  end loop;
end $$;

-- Neither of these is anybody's to call. Postgres grants EXECUTE on a new
-- function to PUBLIC unless told otherwise, and PostgREST publishes everything
-- in this schema — so without these three lines a stranger with the anon key
-- could POST /rpc/take_the_stock and empty the shelves one order id at a time.
-- The trigger below runs as the owner and needs no grant to reach them.
revoke all on function public.take_the_stock(bigint)      from public, anon, authenticated;
revoke all on function public.give_the_stock_back(bigint)  from public, anon, authenticated;

-- ------------------------------------------------------------ the trigger --
-- Cancelled BOTH ways. Going into cancelled returns the stock; coming back out
-- of it takes the stock again, because an order reinstated on Monday is a shirt
-- leaving the building on Monday and the shelf has to know. An order that
-- arrives already cancelled — which the desk can do — never takes anything.
--
-- The whole body is wrapped once more. Every path inside is already careful,
-- and this is the line that means no future carelessness in here can ever cost
-- the house a sale.

create or replace function public.move_the_stock() returns trigger
language plpgsql security definer set search_path = public as $$
begin
  begin
    if tg_op = 'INSERT' then
      if coalesce(new.status, '') <> 'cancelled' then
        perform public.take_the_stock(new.id);
      end if;
    elsif new.status is distinct from old.status then
      if new.status = 'cancelled' then
        perform public.give_the_stock_back(new.id);
      elsif old.status = 'cancelled' then
        perform public.take_the_stock(new.id);
      end if;
    end if;
  exception when others then null;
  end;
  return null;
end $$;

drop trigger if exists orders_stock on public.orders;
create trigger orders_stock after insert or update of status on public.orders
  for each row execute function public.move_the_stock();

-- ================================================================ THE CRM ==
-- Segmentation the house does with its own hands. The six audience buckets in
-- RUN-THIS-EIGHTH are arithmetic — everyone, twice, lately, quiet, abandoned,
-- asked — and arithmetic cannot know that a man is a wedding party of nine, or
-- that his office takes delivery and his flat does not. That knowledge exists
-- today only in somebody's head and in a WhatsApp thread, which is to say it
-- leaves the house when they do.

-- ------------------------------------------------------------------ notes --
-- Free text against a person, signed and dated. Not one `note` column on the
-- profile: a note that gets overwritten is a note that was never worth writing,
-- and the second thing anyone wants to know about a customer is what he was
-- like LAST time.
create table if not exists public.customer_notes (
  id         bigint generated always as identity primary key,
  profile_id bigint not null references public.profiles(id) on delete cascade,
  note       text not null,
  -- stamped by the database from the signed-in desk, so it cannot be left blank
  -- and cannot be typed as somebody else
  by_email   text default (auth.jwt() ->> 'email'),
  at         timestamptz default now()
);
create index if not exists customer_notes_idx on public.customer_notes (profile_id, at desc);

-- ------------------------------------------------------------------- tags --
-- The list earns its place, and the argument is one word typed three ways.
-- Without it the house has VIP, vip and V.I.P by the end of the first month,
-- three segments where it meant one, and no way to discover the split short of
-- reading every row. With it a tag has to be made before it can be given, and
-- `on update cascade` means renaming "wedding" to "wedding party" renames it on
-- every man who carries it rather than orphaning them.
create table if not exists public.tags (
  tag     text primary key,
  colour  text,                              -- how the desk draws it
  note    text,                              -- what it is for, in plain words
  made_at timestamptz default now()
);

-- Nothing is seeded here on purpose. Guessing the house's vocabulary would
-- repeat precisely the mistake this table exists to correct — six buckets
-- somebody else chose, which is not segmentation either.

create table if not exists public.customer_tags (
  profile_id bigint not null references public.profiles(id) on delete cascade,
  tag        text   not null references public.tags(tag) on update cascade on delete cascade,
  by_email   text default (auth.jwt() ->> 'email'),
  at         timestamptz default now(),
  primary key (profile_id, tag)              -- a tag given twice is given once
);
create index if not exists customer_tags_tag_idx on public.customer_tags (tag, profile_id);

-- The list with its weight on it. A tag carried by one man is a note; a tag
-- carried by ninety is a campaign, and the house cannot tell which is which
-- from a list of words.
create or replace view public.tag_book as
select t.tag, t.colour, t.note, t.made_at,
       (select count(*) from public.customer_tags c where c.tag = t.tag) as people
from public.tags t
order by t.tag;

-- ====================================================== MARKETING CONSENT ==
-- What exists today: a boolean called `marketing`, default false, that nothing
-- writes and nothing reads. What does not exist today: any record of when
-- consent was given or on which form, and any way at all for a person to
-- withdraw it. The DPDP Act asks for all three, and the third is the one that
-- turns an annoyed customer into a complaint.

alter table public.profiles add column if not exists marketing_at     timestamptz;
alter table public.profiles add column if not exists marketing_source text;
alter table public.profiles add column if not exists unsubscribed_at  timestamptz;

-- The unsubscribe link has to work for somebody who is not signed in, reading a
-- message on a phone, possibly years later — so it carries a secret of its own
-- rather than a profile id. An id in a URL invites a stranger to try the next
-- number along and unsubscribe a customer who never asked.
alter table public.profiles
  add column if not exists unsub_token uuid not null default gen_random_uuid();
create unique index if not exists profiles_unsub_token_uidx on public.profiles (unsub_token);

-- Consent recorded where it is given: the checkout tick box, the bespoke form,
-- the account page. Granted to anon because the checkout is anonymous, and that
-- is the honest limit of it — this is exactly as trustworthy as the checkout
-- itself and no more. What makes it defensible is not the boolean but the WHEN
-- and the WHERE stored beside it, which is the whole of what has to be produced
-- if anybody ever asks how the house came to have a number.
create or replace function public.set_marketing(
  in_phone text, in_email text, in_on boolean, in_source text default null)
returns boolean
language plpgsql security definer set search_path = public as $$
declare pid bigint;
begin
  pid := public.account_for(in_phone, in_email);
  if pid is null then return false; end if;

  update public.profiles set
    marketing        = coalesce(in_on, false),
    marketing_at     = case when in_on then coalesce(marketing_at, now()) else marketing_at end,
    marketing_source = case when in_on then coalesce(nullif(in_source, ''), marketing_source)
                            else marketing_source end,
    -- Saying yes clears the suppression; saying no sets it and never moves the
    -- date afterwards, because the day somebody first asked to be left alone is
    -- the date that matters.
    unsubscribed_at  = case when in_on then null else coalesce(unsubscribed_at, now()) end
  where id = pid;

  return true;
end $$;

grant execute on function public.set_marketing(text, text, boolean, text) to anon, authenticated;

-- One click, no sign-in, no form. A token that matches nothing returns false
-- and says nothing else — a guess reveals neither that an account exists nor
-- that it does not.
create or replace function public.unsubscribe(in_token uuid)
returns boolean
language plpgsql security definer set search_path = public as $$
declare n integer;
begin
  update public.profiles
     set marketing = false,
         unsubscribed_at = coalesce(unsubscribed_at, now())
   where unsub_token = in_token;
  get diagnostics n = row_count;
  return n > 0;
end $$;

grant execute on function public.unsubscribe(uuid) to anon, authenticated;

-- --------------------------------------------- the audience, with the door --
-- Rewritten from RUN-THIS-EIGHTH. The list itself is unchanged; what is new is
-- that a person who has asked to be left alone is no longer on it, whichever
-- bucket they would otherwise have fallen into. A suppression list that the
-- campaign builder does not consult is a suppression list in name only.
--
-- Matching is on the phone key and the email both, because somebody may have
-- unsubscribed from an address that never appeared on an order.
--
-- WHAT THIS DELIBERATELY DOES NOT DO is require `marketing = true`. That column
-- defaults to false and nothing has ever written it, so demanding it would
-- empty every audience in the house on the day this file runs, silently, and
-- the first anyone would know is a campaign with no recipients. The switch is
-- below instead: turn `marketing_opt_in_only` on once consent is genuinely
-- being captured at the checkout, and the lists narrow to the people who
-- actually said yes. That is where this should end up. It is not where it can
-- honestly start.
insert into public.settings (key, value, note) values
  ('marketing_opt_in_only', 'false',
   'Only send to people who ticked yes. Leave off until the checkout is asking.')
on conflict (key) do nothing;

create or replace function public.audience(kind text)
returns table (name text, email text, phone text)
language sql stable security definer set search_path = public as $$
  with ok as (select * from public.orders where status <> 'cancelled'),
  picked as (
    select max(o.name) as name, max(o.email) as email, o.phone as phone
      from ok o where kind = 'all' group by o.phone
    union all
    select max(o.name), max(o.email), o.phone
      from ok o where kind = 'repeat' group by o.phone having count(*) >= 2
    union all
    select max(o.name), max(o.email), o.phone
      from ok o where kind = 'quiet' group by o.phone
      having max(o.placed_at) < now() - interval '6 months'
    union all
    select max(o.name), max(o.email), o.phone
      from ok o where kind = 'recent' group by o.phone
      having max(o.placed_at) >= now() - interval '30 days'
    union all
    select c.name, c.email, c.phone from public.abandoned_carts c
      where kind = 'abandoned' and c.recovered is null and c.phone is not null
    union all
    select e.name, e.email, e.phone from public.enquiries e
      where kind = 'enquiries' and e.phone is not null
  ),
  rule as (
    select coalesce((select s.value from public.settings s
                      where s.key = 'marketing_opt_in_only'), 'false') = 'true' as opt_in_only
  )
  select x.name, x.email, x.phone
    from picked x
   where coalesce(x.phone, '') <> ''
     -- SECURITY DEFINER means this reads orders past their row-level security,
     -- so it must check for itself who is asking. Signing up is open to
     -- anybody; being on the house's admin list is not. Without this line any
     -- registered stranger could pull every customer's name and phone number in
     -- one request.
     and public.is_admin()
     and not exists (
       select 1 from public.profiles p, rule r
        where (p.unsubscribed_at is not null or (r.opt_in_only and p.marketing is not true))
          and ( (p.phone_key is not null and p.phone_key = public.phone_key(x.phone))
             or (p.email is not null and coalesce(x.email, '') <> ''
                 and lower(p.email) = lower(x.email)) )
     );
$$;

grant execute on function public.audience(text) to authenticated;

-- Who has asked to be left alone, so the house can see the cost of its own
-- sending rather than discover it as a number that quietly stopped growing.
create or replace view public.suppression_list as
select p.id as profile_id, p.first_name, p.last_name, p.email, p.phone,
       p.marketing, p.marketing_at, p.marketing_source, p.unsubscribed_at
from public.profiles p
where p.unsubscribed_at is not null
order by p.unsubscribed_at desc;

-- ========================================================== THE LIFE OF IT ==
-- A VIEW, and not a generated column, and the reason is not preference.
--
-- A generated column may only read its own row. Every fact that decides this —
-- how many orders, how long since the last one, whether a tape has ever been
-- put round him — lives in other tables. A stored column would therefore have
-- to be written by a trigger, and it would be correct only until the next order
-- landed or, worse, until six months of nothing quietly passed with no write to
-- notice it. A man does not become lapsed because something happened. He
-- becomes lapsed because nothing did, and nothing does not fire a trigger.
--
-- lead -> measured -> first order -> repeat -> lapsed.

create or replace view public.customer_lifecycle as
with mine as (
  select o.profile_id,
         count(*)                  as orders,
         min(o.placed_at)          as first_order,
         max(o.placed_at)          as last_order,
         coalesce(sum(o.total), 0) as lifetime
    from public.orders o
   where o.status <> 'cancelled' and o.profile_id is not null
   group by o.profile_id
),
tape as (
  select p.id as profile_id, max(m.taken_at) as last_measured
    from public.profiles p
    join public.measurements m on public.phone_key(m.phone) = p.phone_key
   group by p.id
),
asked as (
  select p.id as profile_id, max(e.came_at) as last_enquiry
    from public.profiles p
    join public.enquiries e on public.phone_key(e.phone) = p.phone_key
   group by p.id
)
select p.id as profile_id, p.first_name, p.last_name, p.email, p.phone,
       p.marketing, p.unsubscribed_at, p.first_seen, p.claimed_at,
       coalesce(o.orders, 0)   as orders,
       coalesce(o.lifetime, 0) as lifetime,
       o.first_order, o.last_order,
       t.last_measured, a.last_enquiry,
       case
         -- Lapsed is tested before repeat on purpose. A man who bought four
         -- shirts and has not been seen since March is a lapsed customer, and
         -- filing him under "repeat" hides the only fact worth acting on. The
         -- order count sits in the column beside it, so nothing is lost.
         when coalesce(o.orders, 0) = 0 and t.last_measured is null then 'lead'
         when coalesce(o.orders, 0) = 0                             then 'measured'
         when o.last_order < now() - interval '6 months'            then 'lapsed'
         when o.orders >= 2                                         then 'repeat'
         else 'first order'
       end as stage
from public.profiles p
left join mine  o on o.profile_id = p.id
left join tape  t on t.profile_id = p.id
left join asked a on a.profile_id = p.id;

-- Six months matches the "quiet" audience and the `customer_list` view, which
-- matters more than the number does: three screens disagreeing about when a
-- customer has gone cold is worse than any one of them being slightly wrong.
create or replace view public.lifecycle_stages as
select stage,
       count(*)                       as people,
       coalesce(sum(lifetime), 0)     as lifetime,
       count(*) filter (where unsubscribed_at is null) as reachable
from public.customer_lifecycle
group by stage
order by case stage
           when 'lead' then 1 when 'measured' then 2 when 'first order' then 3
           when 'repeat' then 4 when 'lapsed' then 5 else 6 end;

-- ============================================================== THE FUNNEL ==
-- assets/track.js has never sent a checkout_started event, so the largest drop
-- on the site — bag to paid — has been reported as one step with nothing in the
-- middle. It sends one now, and this is the column it lands in.
--
-- Appended at the END, which looks wrong and is not. CREATE OR REPLACE VIEW may
-- only ADD columns after the existing ones; putting it in its natural place
-- between the cart and the order would mean dropping the view, and dropping a
-- view the desk is reading at ten in the morning is how a dashboard breaks.

create or replace view public.funnel as
select
  (select count(distinct visit) from public.events
     where name = 'view' and at >= now() - interval '30 days')             as visitors,
  (select count(distinct visit) from public.events
     where name = 'cloth_opened' and at >= now() - interval '30 days')     as viewed_a_cloth,
  (select count(distinct visit) from public.events
     where name = 'size_chosen' and at >= now() - interval '30 days')      as chose_a_size,
  (select count(distinct visit) from public.events
     where name = 'add_to_customize' and at >= now() - interval '30 days') as added_to_cart,
  (select count(distinct visit) from public.events
     where name = 'order_placed' and at >= now() - interval '30 days')     as ordered,
  (select count(*) from public.events
     where name = 'uncut_size' and at >= now() - interval '30 days')       as asked_uncut,
  (select count(distinct visit) from public.events
     where name = 'checkout_started' and at >= now() - interval '30 days') as started_checkout;

-- ======================================================== WHO MAY DO WHAT ==

alter table public.customer_notes enable row level security;
alter table public.customer_tags  enable row level security;
alter table public.tags           enable row level security;

do $$
declare t text;
begin
  foreach t in array array['customer_notes','customer_tags','tags'] loop
    execute format('drop policy if exists "admins only" on public.%I;', t);
    execute format(
      'create policy "admins only" on public.%I for all to authenticated '
      'using (public.is_admin()) with check (public.is_admin());', t);
  end loop;
end $$;

-- No anon policy on any of the three, and no customer policy either. A man has
-- no business reading what the house has written down about him, and a house
-- that knows he might would stop writing anything useful.

-- Every view added here made to obey the rules of the tables underneath it.
-- RUN-THIS-NINTH exists because this was got wrong once already: a view in
-- Postgres runs as whoever created it, so `funnel` was handing the whole
-- analytics table to anyone holding the anon key — which is printed in the
-- site's own JavaScript. The first line is the fix; the second is the lock for
-- the day somebody adds a view and forgets the first.
do $$
declare v text;
begin
  foreach v in array array[
    'tag_book','suppression_list','customer_lifecycle','lifecycle_stages','funnel'
  ] loop
    if exists (select 1 from pg_views where schemaname = 'public' and viewname = v) then
      execute format('alter view public.%I set (security_invoker = on);', v);
      execute format('revoke select on public.%I from anon;', v);
      execute format('grant  select on public.%I to authenticated;', v);
    end if;
  end loop;
end $$;

-- ====================================================== AND NO BACK-FILL ==
-- No past order has its stock taken here, and that is the correct answer rather
-- than the lazy one. The numbers sitting in `inventory` are what the house
-- counted on the shelf and typed in — they already have every shirt that has
-- ever left the building deducted from them, by hand. Replaying the order
-- history over the top would deduct all of it a second time and put half the
-- range into a sold-out state it was never in.
--
-- From this file forward the deduction is the database's job. Everything before
-- it was the shelf's.
