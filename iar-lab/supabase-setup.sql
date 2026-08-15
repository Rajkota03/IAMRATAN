-- I AM RATAN — the events table, and the rules that keep it safe.
--
-- Run this once in the Supabase dashboard: SQL Editor → New query → Run.
--
-- The site posts events with the ANON key, which is public and sits in
-- assets/track.js in plain sight. That is fine, and safe, but ONLY because of
-- the policies below: the anon role may INSERT and may do nothing else. It
-- cannot read a single row back. So the worst a stranger with the key can do is
-- add noise to the table — never read what the house has learned, and never
-- touch anything else in the database.

create table if not exists public.events (
  id        bigint generated always as identity primary key,
  visit     text not null,          -- random per tab, dies with it. Not a person.
  name      text not null,          -- 'uncut_size', 'cloth_opened', 'whatsapp' …
  path      text,
  detail    jsonb default '{}'::jsonb,
  viewport  text,
  at        timestamptz default now(),
  created_at timestamptz default now()
);

-- the questions actually asked of this table
create index if not exists events_name_at_idx on public.events (name, at desc);
create index if not exists events_at_idx      on public.events (at desc);

alter table public.events enable row level security;

-- anyone may add an event …
drop policy if exists "anon can insert events" on public.events;
create policy "anon can insert events"
  on public.events for insert
  to anon
  with check (true);

-- … and nobody anonymous may read, change or delete one. There is no SELECT
-- policy on purpose. The house reads this table from the Supabase dashboard,
-- signed in, where RLS does not apply to the service role.

-- ---------------------------------------------------------------------------
-- THE ONE REPORT THAT PAYS FOR ALL OF THIS
-- Which cloth, in which neck the house does not cut, and how many people asked.
-- Every row is a bespoke lead that used to disappear.

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

-- What the range is actually judged on, in order.
create or replace view public.cloth_interest as
select
  detail->>'cloth' as cloth,
  count(*) filter (where name = 'cloth_opened')      as opened,
  count(*) filter (where name = 'size_chosen')       as sized,
  count(*) filter (where name = 'add_to_customize')  as added
from public.events
where detail ? 'cloth' and detail->>'cloth' <> ''
group by 1
order by opened desc;

-- How the house is actually being contacted.
create or replace view public.contact_actions as
select name as action, viewport, count(*) as times, max(at) as most_recent
from public.events
where name in ('whatsapp','call','email','instagram','consultation_requested')
group by 1, 2
order by times desc;
