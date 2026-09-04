-- I AM RATAN — the real range, from the house's own sheet
--
-- The site was built on a placeholder catalogue of 27 cloths at invented
-- prices. The house has now given the real one: NINE styles, three price
-- points, and a stock count per neck. This makes the database say that.
--
-- WHAT HAPPENS TO THE OTHER EIGHTEEN
--
-- They are HIDDEN, not deleted. Hiding takes them off the shop immediately —
-- the grid drops anything the shop view does not carry — while keeping their
-- photographs, their copy and their history. If the house ever cuts one of
-- them again it is one tick in the admin, not a rebuild. Deleting would also
-- take their order history with them.
--
-- ONE NAME CHANGES
--
-- The database calls it "Ratan's Blue"; the house's sheet says "Ratan Blue".
-- The displayed name follows the sheet. The SLUG stays `ratans-blue`, because
-- that is the web address and the folder its 22 photographs live in — changing
-- it would break both for no gain.
--
-- ABOUT THE STOCK FIGURES
--
-- Taken cell by cell from the sheet. Every row total there is correct and they
-- sum to 303, which matches the stated total. The COLUMN total for neck 46 says
-- 42; the nine cells in it add to 39. The cells are trusted over the column,
-- since they reconcile with everything else. Worth the house checking.

-- ------------------------------------------------------------- the nine --
update public.products set price = 3999, visible = true where slug = 'cobalt-charm';
update public.products set price = 3999, visible = true, name = 'Ratan Blue'
                                                        where slug = 'ratans-blue';
update public.products set price = 5999, visible = true where slug = 'blanc-celestia-2';
update public.products set price = 3999, visible = true where slug = 'obsidian';
update public.products set price = 2999, visible = true where slug = 'indigo-oak';
update public.products set price = 3999, visible = true where slug = 'moonlight-speckle';
update public.products set price = 3999, visible = true where slug = 'midnight-speckle';
update public.products set price = 2999, visible = true where slug = 'blanc-dewdrop';
update public.products set price = 2999, visible = true where slug = 'azure-pearls';

-- ------------------------------------------------- everything else, off --
update public.products set visible = false
 where slug not in ('cobalt-charm','ratans-blue','blanc-celestia-2','obsidian',
                    'indigo-oak','moonlight-speckle','midnight-speckle',
                    'blanc-dewdrop','azure-pearls');

-- ----------------------------------------------------------- the rack --
-- One row per cloth per neck. Written as an upsert on (product_id, size) so a
-- neck that has no row yet gets one, and re-running this simply sets the same
-- numbers again rather than adding to them.
insert into public.inventory (product_id, size, qty)
select p.id, v.size, v.qty
  from (values
    ('cobalt-charm',      '39',  8), ('cobalt-charm',      '40',  8),
    ('cobalt-charm',      '42', 10), ('cobalt-charm',      '44', 11),
    ('cobalt-charm',      '46',  5),

    ('ratans-blue',       '39',  6), ('ratans-blue',       '40',  2),
    ('ratans-blue',       '42', 14), ('ratans-blue',       '44',  9),
    ('ratans-blue',       '46',  3),

    ('blanc-celestia-2',  '39', 10), ('blanc-celestia-2',  '40', 10),
    ('blanc-celestia-2',  '42', 10), ('blanc-celestia-2',  '44', 10),
    ('blanc-celestia-2',  '46', 10),

    ('obsidian',          '39',  3), ('obsidian',          '40',  6),
    ('obsidian',          '42', 14), ('obsidian',          '44',  4),
    ('obsidian',          '46',  5),

    ('indigo-oak',        '39',  3), ('indigo-oak',        '40',  5),
    ('indigo-oak',        '42', 13), ('indigo-oak',        '44',  3),
    ('indigo-oak',        '46',  2),

    ('moonlight-speckle', '39',  1), ('moonlight-speckle', '40',  4),
    ('moonlight-speckle', '42', 10), ('moonlight-speckle', '44',  8),
    ('moonlight-speckle', '46',  2),

    ('midnight-speckle',  '39',  3), ('midnight-speckle',  '40',  7),
    ('midnight-speckle',  '42',  7), ('midnight-speckle',  '44',  6),
    ('midnight-speckle',  '46',  2),

    ('blanc-dewdrop',     '39',  5), ('blanc-dewdrop',     '40',  5),
    ('blanc-dewdrop',     '42', 14), ('blanc-dewdrop',     '44',  8),
    ('blanc-dewdrop',     '46',  5),

    ('azure-pearls',      '39',  5), ('azure-pearls',      '40', 10),
    ('azure-pearls',      '42',  8), ('azure-pearls',      '44',  4),
    ('azure-pearls',      '46',  5)
  ) as v(slug, size, qty)
  join public.products p on p.slug = v.slug
on conflict (product_id, size) do update set qty = excluded.qty;

-- The hidden eighteen keep their rows but hold nothing, so nothing can be sold
-- from them by accident if one is ever switched back on without a count.
update public.inventory set qty = 0
 where product_id in (select id from public.products where visible = false);

-- ---------------------------------------------------------------- did it work --
select 'cloths on the shop' as checked,
       case when count(*) = 9 then 'ok — 9'
            else 'WRONG — ' || count(*)::text end as result
  from public.products where visible = true
union all
select 'at ₹2,999',
       case when count(*) = 3 then 'ok — 3' else 'WRONG — ' || count(*)::text end
  from public.products where visible = true and price = 2999
union all
select 'at ₹3,999',
       case when count(*) = 5 then 'ok — 5' else 'WRONG — ' || count(*)::text end
  from public.products where visible = true and price = 3999
union all
select 'at ₹5,999',
       case when count(*) = 1 then 'ok — 1' else 'WRONG — ' || count(*)::text end
  from public.products where visible = true and price = 5999
union all
select 'shirts on the rack',
       case when sum(i.qty) = 303 then 'ok — 303'
            else 'WRONG — ' || sum(i.qty)::text end
  from public.inventory i
  join public.products p on p.id = i.product_id
 where p.visible = true
union all
select 'the hidden ones hold nothing',
       case when coalesce(sum(i.qty), 0) = 0 then 'ok'
            else 'WRONG — ' || sum(i.qty)::text || ' units still on hidden cloths' end
  from public.inventory i
  join public.products p on p.id = i.product_id
 where p.visible = false;
