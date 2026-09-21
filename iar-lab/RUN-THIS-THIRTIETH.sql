-- I AM RATAN — thirtieth run.
--
-- The range list at the desk showed "Cobalt Charm" and "Ratan's Blue" twice:
-- once for the live cloth, once for an old hidden mockup that had kept the
-- same name. Only the tick told them apart. The hidden ones are renamed so
-- the house can see at a glance which is which, and can delete them from
-- the desk when it wants to (a hidden cloth can be deleted from its page).

update public.products
   set name = name || ' (old mockup)'
 where visible = false
   and name in (select name from public.products where visible = true)
   and name not like '% (old mockup)';

-- ---------------------------------------------------------------- check --
select slug, name, visible from public.products
 where name like '%Cobalt Charm%' or name like '%Ratan''s Blue%'
 order by visible desc, slug;
