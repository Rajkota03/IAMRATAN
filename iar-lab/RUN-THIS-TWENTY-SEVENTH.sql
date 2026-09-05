-- I AM RATAN — back to the catalogue of twenty-seven
--
-- The nine-style range loaded on 4 September is rolled back at the house's
-- word. Nothing was deleted when it went in — the eighteen were hidden, not
-- removed — so this is a restoration and not a rebuild.
--
-- The prices come from assets/catalogue.js, which was checked cloth by cloth
-- against what the database actually held before the change and agreed on
-- every one. It is a record, not a guess.
--
-- WORTH SAYING PLAINLY: these are the ORIGINAL PLACEHOLDER prices — 4,399 and
-- 6,999 and so on — invented when the site was built, not given by the house.
-- Restoring them puts made-up numbers back on a shop that takes real money
-- through a live Razorpay account. That is what rolling back means here, and
-- it is the house's call, but it should be a knowing one.

-- ------------------------------------------------------- all twenty-seven --
update public.products set visible = true;

-- and the name goes back too
update public.products set name = 'Ratan''s Blue' where slug = 'ratans-blue';

-- --------------------------------------------------------- their prices --
update public.products p
   set price = v.price
  from (values
  ('cocoa-drift', 5999),
  ('slate-harbour', 5999),
  ('indigo-oak', 4999),
  ('cobalt-charm', 4399),
  ('ratans-blue', 5999),
  ('blanc-celestia-2', 6999),
  ('obsidian', 4999),
  ('midnight-speckle', 4599),
  ('moonlight-speckle', 4599),
  ('aegean-haze', 3999),
  ('blanc-canvas', 3999),
  ('cognac-drift', 3999),
  ('dune-sand', 3999),
  ('marina-stripe-3', 3999),
  ('midnight-navy', 3999),
  ('pebble-mist', 3999),
  ('storm-grey', 3999),
  ('azure-pearls', 3599),
  ('blanc-dewdrop', 3599),
  ('azure-thread', 2999),
  ('claret-hound', 2999),
  ('forest-weave', 2999),
  ('harbour-blue', 2999),
  ('ivory-grid', 2999),
  ('onyx-hound', 2999),
  ('marina-stripe', 2999),
  ('warm-dune', 2999)
  ) as v(slug, price)
 where p.slug = v.slug;

-- ------------------------------------------------------------- the rack --
-- Five of every neck, which is what stood before the house's counts were
-- loaded. Every cloth, every size the house cuts.
insert into public.inventory (product_id, size, qty)
select p.id, z.size, 5
  from public.products p
  cross join (values ('39'),('40'),('42'),('44'),('46')) as z(size)
on conflict (product_id, size) do update set qty = 5;

-- ---------------------------------------------------------------- did it work --
select 'cloths on the shop' as checked,
       case when count(*) = 27 then 'ok — 27' else 'WRONG — ' || count(*)::text end as result
  from public.products where visible = true
union all
select 'shirts on the rack',
       case when sum(i.qty) = 675 then 'ok — 675' else 'WRONG — ' || sum(i.qty)::text end
  from public.inventory i join public.products p on p.id = i.product_id
 where p.visible = true
union all
select 'prices match the catalogue file',
       case when count(*) = 0 then 'ok'
            else count(*)::text || ' cloth(s) still off' end
  from public.products p
  join (values
  ('cocoa-drift', 5999),
  ('slate-harbour', 5999),
  ('indigo-oak', 4999),
  ('cobalt-charm', 4399),
  ('ratans-blue', 5999),
  ('blanc-celestia-2', 6999),
  ('obsidian', 4999),
  ('midnight-speckle', 4599),
  ('moonlight-speckle', 4599),
  ('aegean-haze', 3999),
  ('blanc-canvas', 3999),
  ('cognac-drift', 3999),
  ('dune-sand', 3999),
  ('marina-stripe-3', 3999),
  ('midnight-navy', 3999),
  ('pebble-mist', 3999),
  ('storm-grey', 3999),
  ('azure-pearls', 3599),
  ('blanc-dewdrop', 3599),
  ('azure-thread', 2999),
  ('claret-hound', 2999),
  ('forest-weave', 2999),
  ('harbour-blue', 2999),
  ('ivory-grid', 2999),
  ('onyx-hound', 2999),
  ('marina-stripe', 2999),
  ('warm-dune', 2999)
  ) as v(slug, price) on v.slug = p.slug
 where p.price <> v.price
union all
select 'the name is back',
       case when exists (select 1 from public.products
                          where slug = 'ratans-blue' and name = 'Ratan''s Blue')
       then 'ok' else 'still says Ratan Blue' end;
