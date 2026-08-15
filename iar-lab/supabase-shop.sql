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
