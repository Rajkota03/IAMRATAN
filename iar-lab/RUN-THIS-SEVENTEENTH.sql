-- I AM RATAN — the things the desk could not actually do
-- Run this whole file once in the Supabase SQL editor. Safe to run twice.
--
-- Two jobs.
--
-- ONE. The cloth editor has always shown ten fields — fabric, fit, weave,
-- collar, sleeve, pattern, origin, MRP, care — and nine of them were writing to
-- columns that do not exist. Every one of those saves failed, and because the
-- desk never showed a failure it looked exactly like nothing happening. The
-- columns are created here, and the product page is changed to read them
-- instead of printing "[composition and weave to be confirmed]" at a customer.
--
-- TWO. The journal. Four entries were written as hand-built HTML files and
-- there was no way for the house to publish a fifth without a developer. This
-- makes the journal a table the desk can write into.

-- ------------------------------------------------ one · what a cloth IS --
alter table public.products add column if not exists fabric  text;
alter table public.products add column if not exists fit     text;
alter table public.products add column if not exists weave   text;
alter table public.products add column if not exists collar  text;
alter table public.products add column if not exists sleeve  text;
alter table public.products add column if not exists pattern text;
alter table public.products add column if not exists origin  text;
alter table public.products add column if not exists care    text;
alter table public.products add column if not exists mrp     integer;

-- Sensible starting points, so the shop is not showing empty rows on the day
-- this runs. Only where the house has not already said otherwise.
update public.products set
  origin = coalesce(origin, 'Made in India'),
  care   = coalesce(care, 'Machine wash cold with like colours, or hand wash. '
         || 'Line dry in shade. Warm iron while faintly damp. No bleach, no '
         || 'tumble dryer.'),
  fit    = coalesce(fit, 'Regular')
where origin is null or care is null or fit is null;

-- The shop front reads a VIEW, not the products table, and that view names its
-- columns one by one — so adding a column to products does not put it on the
-- shop. This is why the product page has always printed
-- "[composition and weave to be confirmed]" at customers instead of the facts.
--
-- Appending to the end is the one change CREATE OR REPLACE VIEW allows; the
-- existing columns keep their names, types and order, so nothing that already
-- reads this view can break.
create or replace view public.shop as
select
  p.slug, p.name, p.price, p.hex, p.collection, p.body,
  p.sort_order,
  coalesce(
    jsonb_object_agg(i.size, i.qty) filter (where i.size is not null),
    '{}'::jsonb
  ) as stock,
  coalesce(sum(i.qty), 0) as total_stock,
  p.sku, p.fabric, p.fit, p.weave, p.collar, p.sleeve,
  p.pattern, p.origin, p.care, p.mrp
from public.products p
left join public.inventory i on i.product_id = p.id
where p.visible = true
group by p.id
order by p.sort_order, p.id;

-- The returns window. The product page has been printing "[7] days" at
-- customers, in brackets, because the number lived nowhere the house could set
-- it. delivery_min_days and delivery_max_days already exist and are already
-- used; this is the third number on that panel.
insert into public.settings (key, value, note) values
  ('returns_days', '7',
   'How many days a customer has to send an unworn shirt back. Printed on '
   'every product page and on the shipping page.')
on conflict (key) do nothing;

-- --------------------------------------------------------- two · the journal --
-- path is what makes this work alongside what already exists. The four entries
-- written by hand keep their own files and their own layouts: their row carries
-- the filename and the index links straight to it. A new entry written at the
-- desk has no file, so path is null and it is rendered by journal-entry.html
-- from the body kept here. Nothing already published has to be rebuilt, and the
-- house can still publish tomorrow.
create table if not exists public.journal (
  id           bigint generated always as identity primary key,
  slug         text unique not null,
  title        text not null,
  kicker       text,                      -- 'On the house', 'On detail'
  standfirst   text,                      -- the line under the title
  body         text,                      -- the entry itself, as paragraphs
  hero         text,                      -- images/journal/<name>.webp
  hero_alt     text,                      -- what the photograph shows
  path         text,                      -- set only for the hand-built four
  published    boolean not null default false,
  published_at timestamptz,
  sort_order   integer not null default 0,
  created_at   timestamptz default now(),
  updated_at   timestamptz default now()
);

create index if not exists journal_live_idx
  on public.journal (published, published_at desc);

alter table public.journal enable row level security;

-- The shop front reads what is published. A draft is the house's own business
-- until the day it decides otherwise, so `published` is part of the policy and
-- not merely a filter the page is trusted to apply.
drop policy if exists "anyone may read a published entry" on public.journal;
create policy "anyone may read a published entry"
  on public.journal for select to anon using (published = true);

drop policy if exists "admins only" on public.journal;
create policy "admins only" on public.journal for all to authenticated
  using (public.is_admin()) with check (public.is_admin());

-- Keep updated_at honest without the browser having to remember.
create or replace function public.touch_journal() returns trigger
language plpgsql as $$
begin
  new.updated_at := now();
  /* the moment it first goes live is the date it carries for ever after */
  if new.published and old.published is distinct from true and new.published_at is null then
    new.published_at := now();
  end if;
  return new;
end $$;

drop trigger if exists journal_touch on public.journal;
create trigger journal_touch before update on public.journal
  for each row execute function public.touch_journal();

-- The four that already exist, taken word for word off the index as it stands,
-- so nothing a reader sees today changes. path is set and body is not: these go
-- on rendering from their own hand-built files. ON CONFLICT DO NOTHING so
-- re-running this never overwrites what the house has since edited.
insert into public.journal
  (slug, title, kicker, standfirst, hero, hero_alt, path, published, published_at, sort_order)
values
  ('twenty-years',
   'Twenty years, no name on the box',
   'On the house',
   'For twenty years our work carried other people''s labels. The making was ours.',
   'images/journal/reclaim-card.webp',
   'The house box in navy, RECLAIM foiled across the lid and the I Am Ratan signature beneath',
   'journal-twenty-years.html', true, now() - interval '120 days', 1),

  ('a-shirt-should-disappear',
   'A shirt should disappear',
   'On wearing it',
   'Fashion asks a garment to be noticed. We ask a shirt to belong.',
   'images/journal/disappear-card.webp',
   'A man seated in a leather chair in a plain grey shirt, the shirt asking for no attention',
   'journal-a-shirt-should-disappear.html', true, now() - interval '90 days', 2),

  ('what-a-button-is-for',
   'What a button is for',
   'On detail',
   'Craft is often invisible when it is done well. Nothing on a garment is an accident.',
   'images/journal/button.webp',
   'A button with I AM RATAN engraved around the rim',
   'journal-what-a-button-is-for.html', true, now() - interval '60 days', 3),

  ('the-wardrobe-that-remembers',
   'The wardrobe that remembers',
   'On the future of menswear',
   'Most wardrobes have a memory. The brands do not.',
   'images/journal/wardrobe-card.webp',
   'Folded shirts in a drawer archive, one colour to a tray',
   'journal-the-wardrobe-that-remembers.html', true, now() - interval '30 days', 4)
on conflict (slug) do nothing;

-- ---------------------------------------------------------------- did it work --
select 'cloth fields'    as checked,
       case when count(*) = 9 then 'ok' else 'MISSING — re-run this file' end as result
  from information_schema.columns
 where table_name = 'products'
   and column_name in ('fabric','fit','weave','collar','sleeve','pattern','origin','care','mrp')
union all
select 'the shop view carries them',
       case when count(*) = 9 then 'ok' else 'MISSING — the view was not replaced' end
  from information_schema.columns
 where table_name = 'shop'
   and column_name in ('fabric','fit','weave','collar','sleeve','pattern','origin','care','mrp')
union all
select 'the returns window',
       case when count(*) = 1 then 'ok' else 'MISSING' end
  from public.settings where key = 'returns_days'
union all
select 'journal table',
       case when count(*) = 1 then 'ok' else 'MISSING' end
  from information_schema.tables where table_name = 'journal'
union all
select 'the four entries',
       case when count(*) >= 4 then 'ok' else 'MISSING — check the insert above' end
  from public.journal
union all
select 'a stranger sees only published',
       case when count(*) = 2 then 'ok' else 'CHECK THE POLICIES' end
  from pg_policies where tablename = 'journal';
