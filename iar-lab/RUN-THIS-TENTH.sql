-- I AM RATAN — the shop windows: media, the home page, the menu, the pages.
-- Run in the SQL Editor after the previous nine.
--
-- ===================== THE RULE THIS FILE FOLLOWS ======================
-- THE HTML SHIPS CORRECT AND COMPLETE. THE DATABASE ONLY EVER OVERRIDES.
--
-- Every page of this site is finished, hand-built HTML that renders with no
-- JavaScript and no database. Nothing here changes that. What these tables do
-- is let the house OVERRIDE what is already correct — hide a band, reorder two,
-- retitle one, change a link.
--
-- The alternative — a home page that is empty until a database answers — buys
-- the house nothing it will use twice a year, and costs a blank screen on a
-- slow phone, a worse Google result, and a site that dies when Supabase sleeps.
-- A shop that renders instantly and can also be edited is strictly better than
-- a shop that can only be edited.

-- ================================== MEDIA ==================================
-- Photographs currently live as files in the repository, which means changing
-- one is a deploy, which means changing one is me. That is the single biggest
-- thing standing between the house and running its own shop.

insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values ('house', 'house', true, 10485760,
        array['image/jpeg','image/png','image/webp','image/avif','image/svg+xml','application/pdf'])
on conflict (id) do update
  set public = true,
      file_size_limit = 10485760,
      allowed_mime_types = excluded.allowed_mime_types;

-- Anyone may LOOK at a photograph — they are on the shop front, that is the
-- whole point. Only the house may put one there or take one down.
drop policy if exists "anyone may see the house files" on storage.objects;
create policy "anyone may see the house files"
  on storage.objects for select to anon, authenticated
  using (bucket_id = 'house');

drop policy if exists "the house may upload" on storage.objects;
create policy "the house may upload"
  on storage.objects for insert to authenticated
  with check (bucket_id = 'house' and public.is_admin());

drop policy if exists "the house may replace" on storage.objects;
create policy "the house may replace"
  on storage.objects for update to authenticated
  using (bucket_id = 'house' and public.is_admin())
  with check (bucket_id = 'house' and public.is_admin());

drop policy if exists "the house may remove" on storage.objects;
create policy "the house may remove"
  on storage.objects for delete to authenticated
  using (bucket_id = 'house' and public.is_admin());

-- The catalogue of what has been uploaded. Storage knows the bytes; this knows
-- what the picture is OF, which is the part a person searches by.
create table if not exists public.media (
  id         bigint generated always as identity primary key,
  path       text not null unique,          -- the path inside the bucket
  url        text not null,                 -- the public URL, stored so nothing
                                            -- has to rebuild it in six places
  name       text,
  folder     text default 'Uncategorised',
  kind       text,                          -- the mime type
  bytes      bigint,
  alt        text,                          -- what a blind reader is told
  width      integer,
  height     integer,
  added_at   timestamptz default now()
);
create index if not exists media_folder_idx on public.media (folder, added_at desc);

-- ------------------------------------------------- a cloth's photographs --
-- admin.js has called this table since the desk was built and it was never
-- created, so the photo manager on a cloth has only ever shown an error.

create table if not exists public.product_images (
  id         bigint generated always as identity primary key,
  product_id bigint references public.products(id) on delete cascade,
  url        text not null,
  kind       text default 'front',   -- thumbnail | front | back | collar |
                                     -- buttons | cuff | fabric | lifestyle
  alt        text,
  sort_order integer default 0,
  added_at   timestamptz default now()
);
create index if not exists product_images_idx
  on public.product_images (product_id, sort_order);

-- ============================== THE HOME PAGE ==============================
-- One row per band already built into index.html. The house may hide one or
-- move it; it cannot invent one, because a band that does not exist in the
-- HTML has no design, no photography and no words.

create table if not exists public.home_sections (
  key        text primary key,
  label      text not null,
  note       text,
  live       boolean not null default true,
  sort_order integer not null default 0,
  heading    text,          -- blank = keep whatever the page already says
  subheading text
);

-- THREE ROWS, BECAUSE THE HOME PAGE HAS THREE BANDS. It would have been easy
-- to seed the six a mockup shows — Featured Collections, Best Sellers, Customer
-- Reviews, Instagram Gallery — and every one of them would have been a switch
-- wired to nothing. The page is: look, choose, read on.
insert into public.home_sections (key, label, note, sort_order) values
  ('hero',    'The hero',      'The campaign photograph and the line across it.', 1),
  ('doors',   'Where to begin','The two panels — the shop, and bespoke.',         2),
  ('journal', 'The journal',   'The sideways rail of writing.',                   3)
on conflict (key) do nothing;

-- ================================ THE MENU ================================
-- Four links that change about once a year. They ship in the HTML of every
-- page so the header is right before a single script runs; these rows only
-- override that when the house has actually changed something.

create table if not exists public.nav_items (
  id         bigint generated always as identity primary key,
  label      text not null,
  href       text not null,
  place      text not null default 'main',   -- main | footer
  sort_order integer not null default 0,
  live       boolean not null default true
);

insert into public.nav_items (label, href, place, sort_order)
select * from (values
  ('Home',     'index.html',   'main', 1),
  ('Shop',     'shop.html',    'main', 2),
  ('Bespoke',  'bespoke.html', 'main', 3),
  ('About us', 'house.html',   'main', 4)
) as v(label, href, place, sort_order)
where not exists (select 1 from public.nav_items where place = 'main');

-- ================================= PAGES =================================
-- The real pages, as they really are. A row here does not CREATE a page — the
-- page is a hand-built file — it records one, so the house can see what exists,
-- what is linked, and when it was last touched.

create table if not exists public.pages (
  slug       text primary key,
  title      text not null,
  path       text not null,
  status     text not null default 'published',   -- published | draft
  in_footer  boolean default true,
  updated_at timestamptz default now(),
  updated_by text
);

drop trigger if exists pages_touch on public.pages;
create trigger pages_touch before update on public.pages
  for each row execute function public.touch();

insert into public.pages (slug, title, path) values
  ('home',      'Home',                'index.html'),
  ('shop',      'The shop',            'shop.html'),
  ('bespoke',   'Bespoke',             'bespoke.html'),
  ('house',     'The house',           'house.html'),
  ('range',     'The range',           'range.html'),
  ('journal',   'The journal',         'journal.html'),
  ('loom',      'The loom',            'loom.html'),
  ('directions','Finding the house',   'directions.html'),
  ('contact',   'Contact',             'contact.html'),
  ('shipping',  'Shipping & returns',  'shipping.html'),
  ('privacy',   'Privacy',             'privacy.html'),
  ('terms',     'Terms',               'terms.html')
on conflict (slug) do nothing;

-- ========================== THE ANNOUNCEMENT BAR ==========================
-- The setting has existed since the first file and NOTHING HAS EVER DRAWN IT.
-- The house could type a line into the desk and it went nowhere. These are the
-- rest of the knobs; `assets/house.js` is what finally puts it on the page.

insert into public.settings (key, value, note) values
  ('bar_on',        'false', 'Show the announcement bar at the top of every page.'),
  ('bar_link',      '',      'Where the bar goes when tapped. Blank = not a link.'),
  ('bar_link_text', '',      'The words on the link, if there is one.'),
  ('bar_bg',        '#141210', 'Background of the bar.'),
  ('bar_fg',        '#F5F2EC', 'Text colour of the bar.'),
  ('bar_where',     'all',   'all | home — which pages carry it.')
on conflict (key) do nothing;

-- ============================== COLLECTIONS ==============================
-- Another table admin.js has called since the desk was built and which was
-- never created, so the Collections screen has only ever shown an error. The
-- grouping itself is real and already in use — every cloth carries a
-- `collection` — there was simply nowhere to say what a collection IS.
--
-- Seeded from the cloths themselves rather than invented, so the two that
-- exist on the shop today are the two that appear here: "Working hours" and
-- "Ratan's stripes".

create table if not exists public.collections (
  id         bigint generated always as identity primary key,
  slug       text unique not null,
  name       text not null,
  blurb      text,
  sort_order integer default 0,
  visible    boolean not null default true
);

insert into public.collections (slug, name, sort_order)
select
  regexp_replace(lower(trim(p.collection)), '[^a-z0-9]+', '-', 'g'),
  trim(p.collection),
  row_number() over (order by trim(p.collection))
from (select distinct collection from public.products
       where coalesce(trim(collection), '') <> '') p
on conflict (slug) do nothing;

alter table public.collections enable row level security;

-- ========================== THE MEASUREMENT BOOK ==========================
-- The last of the tables admin.js has called since the desk was built and that
-- were never created. This is the one that matters most commercially: a house
-- that still has a man's numbers three years later does not have to measure him
-- again, and that is the whole argument for buying a second shirt here rather
-- than anywhere else.
--
-- EVERY SITTING IS KEPT. A man's neck at forty is not his neck at fifty, and a
-- measurement overwritten is a measurement lost — the history is the asset, not
-- the latest row. Inches throughout, because that is what the tape says.

create table if not exists public.measurements (
  id           bigint generated always as identity primary key,
  phone        text not null,            -- the one thing he gives every time
  name         text,
  neck         numeric,
  chest        numeric,
  waist        numeric,
  seat         numeric,
  shoulder     numeric,
  sleeve       numeric,
  wrist        numeric,
  shirt_length numeric,
  posture      text,                     -- stooping | erect | normal
  fit          text,                     -- how he likes it worn
  note         text,
  taken_by     text,
  taken_at     timestamptz default now()
);
create index if not exists measurements_phone_idx
  on public.measurements (phone, taken_at desc);

alter table public.measurements enable row level security;

-- The book is one line per customer: his most recent sitting. The history stays
-- in the table underneath and is read a phone number at a time.
create or replace view public.measurement_book as
select distinct on (m.phone)
  m.phone, m.name, m.neck, m.chest, m.waist, m.seat, m.shoulder, m.sleeve,
  m.wrist, m.shirt_length, m.posture, m.fit, m.note, m.taken_by, m.taken_at,
  (select count(*) from public.measurements x where x.phone = m.phone) as sittings
from public.measurements m
order by m.phone, m.taken_at desc;

-- ============================== WHO MAY DO WHAT ==============================

alter table public.media          enable row level security;
alter table public.product_images enable row level security;
alter table public.home_sections  enable row level security;
alter table public.nav_items      enable row level security;
alter table public.pages          enable row level security;

do $$
declare t text;
begin
  foreach t in array array['media','product_images','home_sections','nav_items',
                           'pages','collections'] loop
    execute format('drop policy if exists "admins only" on public.%I;', t);
    execute format(
      'create policy "admins only" on public.%I for all to authenticated '
      'using (public.is_admin()) with check (public.is_admin());', t);
    -- the shop front reads all five to draw itself
    execute format('drop policy if exists "anyone may read" on public.%I;', t);
    execute format(
      'create policy "anyone may read" on public.%I for select to anon using (true);', t);
  end loop;
end $$;

-- A man's measurements are NOT one of the five above and never get the
-- "anyone may read" policy. The shop front has no business knowing anybody's
-- chest, and this is the most personal row in the whole database.
drop policy if exists "admins only" on public.measurements;
create policy "admins only" on public.measurements for all to authenticated
  using (public.is_admin()) with check (public.is_admin());

alter view public.measurement_book set (security_invoker = on);
revoke select on public.measurement_book from anon;
grant  select on public.measurement_book to authenticated;

-- ------------------------------------------------------------ the counts --
-- What the Website screen shows across the top.

create or replace view public.site_stats as
select
  (select count(*) from public.pages where status = 'published')   as pages,
  (select count(*) from public.pages)                              as pages_all,
  (select count(*) from public.collections)                        as collections,
  (select count(*) from public.media)                              as files,
  (select coalesce(sum(bytes),0) from public.media)                as bytes,
  (select count(*) from public.home_sections where live)           as sections_live,
  (select count(*) from public.home_sections)                      as sections_all,
  (select count(*) from public.nav_items where live and place='main') as menu_items;

-- Same discipline as the ninth file: a view does not obey row-level security
-- on its own, so it is told to, and shut to strangers besides.
alter view public.site_stats set (security_invoker = on);
revoke select on public.site_stats from anon;
grant  select on public.site_stats to authenticated;
