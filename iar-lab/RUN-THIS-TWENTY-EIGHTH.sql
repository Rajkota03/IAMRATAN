-- I AM RATAN — the shop view carries the photographs
--
-- The admin's cloth editor writes product photographs into product_images, and
-- until now NO public page read that table — the client could "add" photos
-- that never appeared anywhere. The shop view now carries each cloth's
-- photographs as an ordered list of URLs, so the shop grid and the product
-- page can draw them without an extra request.
--
-- Appending a column at the end is the one change CREATE OR REPLACE VIEW
-- allows; every existing column keeps its name, type and position, so nothing
-- that already reads the view can break.

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
    where pi.product_id = p.id) as photos
from public.products p
left join public.inventory i on i.product_id = p.id
where p.visible = true
group by p.id
order by p.sort_order, p.id;

-- ---------------------------------------------------------------- did it work --
select 'the view carries photos' as checked,
       case when count(*) = 1 then 'ok' else 'MISSING — the view was not replaced' end as result
  from information_schema.columns
 where table_name = 'shop' and column_name = 'photos'
union all
select 'still 27 cloths on it',
       case when count(*) = 27 then 'ok — 27' else count(*)::text end
  from public.shop
union all
select 'photographs already catalogued',
       count(*)::text || ' row(s) in product_images'
  from public.product_images;
