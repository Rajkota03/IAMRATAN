-- I AM RATAN — the shop's own tables.
-- Run once: Supabase dashboard → SQL Editor → New query → Run.
--
-- THE PRINCIPLE BEHIND EVERY TABLE HERE
-- If it is a business decision, it lives in this database and the house changes
-- it. If it is a design decision, it lives in the code and I change it.
--
-- So: stock is a number the house edits. Whether "only 2 left" appears at all
-- is a switch the house flips. The number it appears BELOW is a setting the
-- house sets. Prices, names, what is visible, what is sold out, when the shop
-- takes orders — all theirs. None of it needs me, and none of it needs a deploy.

-- ---------------------------------------------------------------- products --

create table if not exists public.products (
  id          bigint generated always as identity primary key,
  slug        text unique not null,
  name        text not null,
  price       integer not null,              -- whole rupees, tax included
  hex         text,                          -- the cloth's own colour
  collection  text,                          -- 'Working hours', "Ratan's stripes"
  body        text,
  -- the house's controls
  visible     boolean not null default true,  -- hide without deleting
  sort_order  integer not null default 0,     -- the order of the range
  updated_at  timestamptz default now()
);

-- ---------------------------------------------------------------- inventory --
-- One row per cloth per neck. Nothing is "in stock" as a general fact — a shirt
-- is in stock in a 42 and gone in a 44, and the site must be able to say so.

create table if not exists public.inventory (
  product_id  bigint not null references public.products(id) on delete cascade,
  size        text not null,                 -- '39' '40' '42' '44' '46'
  qty         integer not null default 0,
  updated_at  timestamptz default now(),
  primary key (product_id, size)
);

-- ----------------------------------------------------------------- settings --
-- The switches the house owns. Key/value so a new one never needs a migration.

create table if not exists public.settings (
  key    text primary key,
  value  text,
  note   text                                 -- shown beside it in the admin
);

insert into public.settings (key, value, note) values
  ('show_stock_counts', 'true',
   'Show "only 2 left" on the site? Turn off to keep stock private.'),
  ('low_stock_at', '3',
   'Show the warning when stock falls to this number or below.'),
  ('hide_sold_out', 'false',
   'Hide a cloth from the shop entirely when every size is gone.'),
  ('shop_open', 'true',
   'Turn the whole shop off — the range still shows, ordering stops.'),
  ('delivery_min_days', '3',  'Fastest honest delivery, in working days.'),
  ('delivery_max_days', '7',  'Slowest honest delivery, in working days.'),
  ('announcement', '',
   'A line across the top of every page. Leave blank for none.')
on conflict (key) do nothing;

-- ------------------------------------------------------------------ safety --
-- The site reads with the ANON key, which is public and sits in the JavaScript.
-- That is safe ONLY because of what follows: anon may read, and may never write.
-- Writing is for a signed-in member of the house, through the admin.

alter table public.products  enable row level security;
alter table public.inventory enable row level security;
alter table public.settings  enable row level security;

drop policy if exists "anyone may read visible products" on public.products;
create policy "anyone may read visible products"
  on public.products for select to anon using (visible = true);

drop policy if exists "anyone may read stock" on public.inventory;
create policy "anyone may read stock"
  on public.inventory for select to anon using (true);

drop policy if exists "anyone may read settings" on public.settings;
create policy "anyone may read settings"
  on public.settings for select to anon using (true);

-- the house, signed in, may do anything to all three
do $$
declare t text;
begin
  foreach t in array array['products','inventory','settings'] loop
    execute format(
      'drop policy if exists "the house may write" on public.%I; '
      'create policy "the house may write" on public.%I '
      'for all to authenticated using (true) with check (true);', t, t);
  end loop;
end $$;

-- --------------------------------------------------------------- the view --
-- One call gets the shop: every visible cloth with its stock folded in, so the
-- site never has to join anything in the browser.

create or replace view public.shop as
select
  p.slug, p.name, p.price, p.hex, p.collection, p.body,
  p.sort_order,
  coalesce(
    jsonb_object_agg(i.size, i.qty) filter (where i.size is not null),
    '{}'::jsonb
  ) as stock,
  coalesce(sum(i.qty), 0) as total_stock
from public.products p
left join public.inventory i on i.product_id = p.id
where p.visible = true
group by p.id
order by p.sort_order, p.id;

-- keep updated_at honest
create or replace function public.touch() returns trigger as $$
begin new.updated_at = now(); return new; end $$ language plpgsql;

drop trigger if exists products_touch on public.products;
create trigger products_touch before update on public.products
  for each row execute function public.touch();

drop trigger if exists inventory_touch on public.inventory;
create trigger inventory_touch before update on public.inventory
  for each row execute function public.touch();
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
-- I AM RATAN — seed the shop from the catalogue that shipped with the site.
-- Run AFTER supabase-shop.sql. Safe to re-run: it updates rather than duplicates.
-- Stock is seeded at 5 per size purely so the house has a number to edit;
-- the real counts are theirs to set on day one.

insert into public.products (slug,name,price,hex,collection,body,sort_order) values
  ('cocoa-drift','Cocoa Drift',5999,'#492F24','Working hours','A deep cocoa, woven close and finished soft. The colour reads almost black in a low room and opens to warm brown in daylight — the reason it sits as easily under a jacket at six as it does across a table at nine. Engraved buttons, and the house signature embroidered tone on tone at the cuff.',1)
on conflict (slug) do update set name=excluded.name, price=excluded.price,
  hex=excluded.hex, collection=excluded.collection, body=excluded.body,
  sort_order=excluded.sort_order;
insert into public.products (slug,name,price,hex,collection,body,sort_order) values
  ('slate-harbour','Slate Harbour',5999,'#4D5B6F','Working hours','A grey-blue with weather in it. Quieter than a navy and warmer than a steel, it is the shirt for the days that go long — cut in the same five sizes, finished by the same hands, with the signature embroidered at the cuff in its own colour.',2)
on conflict (slug) do update set name=excluded.name, price=excluded.price,
  hex=excluded.hex, collection=excluded.collection, body=excluded.body,
  sort_order=excluded.sort_order;
insert into public.products (slug,name,price,hex,collection,body,sort_order) values
  ('indigo-oak','Indigo Oak',4999,'#4A5570','Working hours','The Indigo Oak is a testament to exquisite craftsmanship, made from supersoft, premium cotton for ultimate comfort. The intricate herringbone weave showcases attention to detail, while the rich, refined brown and blues adds a touch of timeless sophistication.',3)
on conflict (slug) do update set name=excluded.name, price=excluded.price,
  hex=excluded.hex, collection=excluded.collection, body=excluded.body,
  sort_order=excluded.sort_order;
insert into public.products (slug,name,price,hex,collection,body,sort_order) values
  ('cobalt-charm','Cobalt Charm',4399,'#3E5A8C','Working hours','Discover impeccable craftsmanship with Cobalt Charm, crafted from premium cotton for exceptional comfort and durability. The intricate stitching and refined details reflect true artisanal mastery and exudes timeless elegance. Perfect for making a sophisticated statement in any',4)
on conflict (slug) do update set name=excluded.name, price=excluded.price,
  hex=excluded.hex, collection=excluded.collection, body=excluded.body,
  sort_order=excluded.sort_order;
insert into public.products (slug,name,price,hex,collection,body,sort_order) values
  ('ratans-blue','Ratan''s Blue',5999,'#B7CAEE','Working hours','Discover impeccable craftsmanship with Ratan’s Blue, crafted from premium cotton for exceptional comfort and durability. The intricate stitching and refined details reflect true artisanal mastery and exudes timeless elegance. Perfect for making a sophisticated statement in any setting.',5)
on conflict (slug) do update set name=excluded.name, price=excluded.price,
  hex=excluded.hex, collection=excluded.collection, body=excluded.body,
  sort_order=excluded.sort_order;
insert into public.products (slug,name,price,hex,collection,body,sort_order) values
  ('blanc-celestia-2','Blanc Celestia',6999,'#F2F2F0','Working hours','Discover impeccable craftsmanship with Blanc Celestia, crafted from premium cotton for exceptional comfort and durability. The intricate stitching and refined details reflect true artisanal mastery and exudes timeless elegance. Perfect for making a sophisticated statement in any setting',6)
on conflict (slug) do update set name=excluded.name, price=excluded.price,
  hex=excluded.hex, collection=excluded.collection, body=excluded.body,
  sort_order=excluded.sort_order;
insert into public.products (slug,name,price,hex,collection,body,sort_order) values
  ('obsidian','Obsidian',4999,'#16171A','Working hours','Discover impeccable craftsmanship with Obsidian, crafted from premium cotton for exceptional comfort and durability. The intricate stitching and refined details reflect true artisanal mastery and exudes timeless elegance. Perfect for making a sophisticated statement in any setting.',7)
on conflict (slug) do update set name=excluded.name, price=excluded.price,
  hex=excluded.hex, collection=excluded.collection, body=excluded.body,
  sort_order=excluded.sort_order;
insert into public.products (slug,name,price,hex,collection,body,sort_order) values
  ('midnight-speckle','Midnight Speckle',4599,'#22252D','Working hours','Crafted from premium cotton, Midnight speckle features an intricate jacquard weave that adds subtle texture and depth. The tailored fit ensures a sharp, modern silhouette, while the breathable fabric offers all-day comfort.',8)
on conflict (slug) do update set name=excluded.name, price=excluded.price,
  hex=excluded.hex, collection=excluded.collection, body=excluded.body,
  sort_order=excluded.sort_order;
insert into public.products (slug,name,price,hex,collection,body,sort_order) values
  ('moonlight-speckle','Moonlight Speckle',4599,'#E6E4DE','Working hours','Crafted from premium cotton, Moonlight speckle features an intricate jacquard weave that adds subtle texture and depth. The tailored fit ensures a sharp, modern silhouette, while the breathable fabric offers all-day comfort.',9)
on conflict (slug) do update set name=excluded.name, price=excluded.price,
  hex=excluded.hex, collection=excluded.collection, body=excluded.body,
  sort_order=excluded.sort_order;
insert into public.products (slug,name,price,hex,collection,body,sort_order) values
  ('aegean-haze','Aegean Haze',3999,'#8FA0AD',null,'',10)
on conflict (slug) do update set name=excluded.name, price=excluded.price,
  hex=excluded.hex, collection=excluded.collection, body=excluded.body,
  sort_order=excluded.sort_order;
insert into public.products (slug,name,price,hex,collection,body,sort_order) values
  ('blanc-canvas','Blanc Canvas',3999,'#F4F4F2',null,'',11)
on conflict (slug) do update set name=excluded.name, price=excluded.price,
  hex=excluded.hex, collection=excluded.collection, body=excluded.body,
  sort_order=excluded.sort_order;
insert into public.products (slug,name,price,hex,collection,body,sort_order) values
  ('cognac-drift','Cognac Drift',3999,'#8A6244',null,'',12)
on conflict (slug) do update set name=excluded.name, price=excluded.price,
  hex=excluded.hex, collection=excluded.collection, body=excluded.body,
  sort_order=excluded.sort_order;
insert into public.products (slug,name,price,hex,collection,body,sort_order) values
  ('dune-sand','Dune Sand',3999,'#BFAE96',null,'',13)
on conflict (slug) do update set name=excluded.name, price=excluded.price,
  hex=excluded.hex, collection=excluded.collection, body=excluded.body,
  sort_order=excluded.sort_order;
insert into public.products (slug,name,price,hex,collection,body,sort_order) values
  ('marina-stripe-3','Marina Stripe',3999,'#7FA3CC','Ratan''s stripes','',14)
on conflict (slug) do update set name=excluded.name, price=excluded.price,
  hex=excluded.hex, collection=excluded.collection, body=excluded.body,
  sort_order=excluded.sort_order;
insert into public.products (slug,name,price,hex,collection,body,sort_order) values
  ('midnight-navy','Midnight Navy',3999,'#232C4A',null,'',15)
on conflict (slug) do update set name=excluded.name, price=excluded.price,
  hex=excluded.hex, collection=excluded.collection, body=excluded.body,
  sort_order=excluded.sort_order;
insert into public.products (slug,name,price,hex,collection,body,sort_order) values
  ('pebble-mist','Pebble Mist',3999,'#C4C6C6',null,'',16)
on conflict (slug) do update set name=excluded.name, price=excluded.price,
  hex=excluded.hex, collection=excluded.collection, body=excluded.body,
  sort_order=excluded.sort_order;
insert into public.products (slug,name,price,hex,collection,body,sort_order) values
  ('storm-grey','Storm Grey',3999,'#5C6066',null,'',17)
on conflict (slug) do update set name=excluded.name, price=excluded.price,
  hex=excluded.hex, collection=excluded.collection, body=excluded.body,
  sort_order=excluded.sort_order;
insert into public.products (slug,name,price,hex,collection,body,sort_order) values
  ('azure-pearls','Azure Pearls',3599,'#9FB6D9','Working hours','pattern for a touch of texture. The tailored fit offers a sleek, flattering shape, while the premium fabric ensures comfort. Completed with mother-of-pearl buttons and expert craftsmanship, this shirt is both versatile and elegant',18)
on conflict (slug) do update set name=excluded.name, price=excluded.price,
  hex=excluded.hex, collection=excluded.collection, body=excluded.body,
  sort_order=excluded.sort_order;
insert into public.products (slug,name,price,hex,collection,body,sort_order) values
  ('blanc-dewdrop','Blanc Dewdrop',3599,'#F0F0EC','Working hours','dotted pattern for a touch of texture. The tailored fit offers a sleek, flattering shape, while the premium fabric ensures comfort. Completed with mother-of-pearl buttons and expert craftsmanship, this shirt is both versatile and elegant.',19)
on conflict (slug) do update set name=excluded.name, price=excluded.price,
  hex=excluded.hex, collection=excluded.collection, body=excluded.body,
  sort_order=excluded.sort_order;
insert into public.products (slug,name,price,hex,collection,body,sort_order) values
  ('azure-thread','Azure Thread',2999,'#6E93C4','Ratan''s stripes','Refinement at its most effortless. The Azure Thread is built on a clear, mid-blue base with fine white pinstripes drawn at just enough of a distance to breathe. Smooth to the touch and clean in form, this shirt pairs with everything from charcoal suits to white chinos. A Legacy essential that lives in the space between formal and free.',20)
on conflict (slug) do update set name=excluded.name, price=excluded.price,
  hex=excluded.hex, collection=excluded.collection, body=excluded.body,
  sort_order=excluded.sort_order;
insert into public.products (slug,name,price,hex,collection,body,sort_order) values
  ('claret-hound','Claret Hound',2999,'#6B2F3A','Ratan''s stripes','',21)
on conflict (slug) do update set name=excluded.name, price=excluded.price,
  hex=excluded.hex, collection=excluded.collection, body=excluded.body,
  sort_order=excluded.sort_order;
insert into public.products (slug,name,price,hex,collection,body,sort_order) values
  ('forest-weave','Forest Weave',2999,'#5E6449','Ratan''s stripes','',22)
on conflict (slug) do update set name=excluded.name, price=excluded.price,
  hex=excluded.hex, collection=excluded.collection, body=excluded.body,
  sort_order=excluded.sort_order;
insert into public.products (slug,name,price,hex,collection,body,sort_order) values
  ('harbour-blue','Harbour Blue',2999,'#2F3E5C','Ratan''s stripes','There’s depth in the detail. A rich navy ground is interrupted by a layered stripe — fine beige and white lines running in quiet rhythm — giving this shirt a complexity that rewards a second look. Tonal buttons and a structured spread collar lend it a formal edge without sacrificing ease. The kind of shirt that anchors a wardrobe and never overstays its welcome.',23)
on conflict (slug) do update set name=excluded.name, price=excluded.price,
  hex=excluded.hex, collection=excluded.collection, body=excluded.body,
  sort_order=excluded.sort_order;
insert into public.products (slug,name,price,hex,collection,body,sort_order) values
  ('ivory-grid','Ivory Grid',2999,'#E8E3D6','Ratan''s stripes','',24)
on conflict (slug) do update set name=excluded.name, price=excluded.price,
  hex=excluded.hex, collection=excluded.collection, body=excluded.body,
  sort_order=excluded.sort_order;
insert into public.products (slug,name,price,hex,collection,body,sort_order) values
  ('onyx-hound','Onyx Hound',2999,'#2E3033','Ratan''s stripes','',25)
on conflict (slug) do update set name=excluded.name, price=excluded.price,
  hex=excluded.hex, collection=excluded.collection, body=excluded.body,
  sort_order=excluded.sort_order;
insert into public.products (slug,name,price,hex,collection,body,sort_order) values
  ('marina-stripe','Phantom Stripe',2999,'#2B2A2E','Ratan''s stripes','',26)
on conflict (slug) do update set name=excluded.name, price=excluded.price,
  hex=excluded.hex, collection=excluded.collection, body=excluded.body,
  sort_order=excluded.sort_order;
insert into public.products (slug,name,price,hex,collection,body,sort_order) values
  ('warm-dune','Warm Dune',2999,'#C2A882','Ratan''s stripes','',27)
on conflict (slug) do update set name=excluded.name, price=excluded.price,
  hex=excluded.hex, collection=excluded.collection, body=excluded.body,
  sort_order=excluded.sort_order;

-- one inventory row per cloth per neck the house cuts
insert into public.inventory (product_id,size,qty)
select p.id, s.size, 5
from public.products p cross join (values ('39'),('40'),('42'),('44'),('46')) as s(size)
on conflict (product_id,size) do nothing;
