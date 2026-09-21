-- I AM RATAN — thirty-third run. The house chooses what sits under a cloth.
--
-- The "More in Working hours" rail under every product was automatic: four
-- cloths from the built-in catalogue, same collection first. Nothing at the
-- desk controlled it, it showed cloths the house had taken off the shop, and
-- it named the collection the house does not want named.
--
-- 1. Each cloth may carry its own list of companions, chosen at the desk.
--    Empty means "choose for me": other cloths on the shop, in shop order.
-- 2. One switch in Settings turns the rail off everywhere.
-- 3. The shop view carries the list, appended as its last column (the only
--    place create or replace view allows a new one).

alter table public.products add column if not exists related text[];

insert into public.settings (key, value, note) values
  ('show_related', 'true',
   'Show other cloths under each product ("More from the house"). false hides the rail.')
on conflict (key) do nothing;

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
  p.pattern, p.origin, p.care, p.mrp,
  (select coalesce(jsonb_agg(pi.url order by pi.sort_order), '[]'::jsonb)
     from public.product_images pi
    where pi.product_id = p.id) as photos,
  coalesce(p.related, '{}') as related
from public.products p
left join public.inventory i on i.product_id = p.id
where p.visible = true
group by p.id
order by p.sort_order, p.id;

-- ---------------------------------------------------------------- check --
select 'the shop view carries related' as checked,
       case when count(*) = 1 then 'ok' else 'MISSING' end as result
  from information_schema.columns
 where table_name = 'shop' and column_name = 'related'
union all
select 'the switch is in settings',
       coalesce((select value from public.settings where key = 'show_related'), 'MISSING');
