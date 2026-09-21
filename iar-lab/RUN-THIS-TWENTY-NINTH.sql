-- I AM RATAN — twenty-ninth run.
--
-- Two small tidies for the Home page screen at the desk.
--
-- 1. The five content slots seeded on the eighth run (hero_line, hero_note,
--    range_intro, house_intro, bespoke_note) were never read by any page.
--    The slots are now named by the page itself (hero1.line, door1.note,
--    circle.picture, ...) and the desk writes them on first save, so these
--    five rows are dead weight and go.
--
-- 2. The home page has a fourth band, Ratan's Circle, that the bands table
--    never had a row for, so it could not be hidden or moved from the desk.

delete from public.content
 where slot in ('hero_line','hero_note','range_intro','house_intro','bespoke_note');

insert into public.home_sections (key, label, note, sort_order) values
  ('circle', 'Ratan''s Circle',
   'The invitation panel that closes the page. Membership is not open.', 4)
on conflict (key) do nothing;

-- ---------------------------------------------------------------- checks --
select 'content rows' as what, count(*) from public.content
union all
select 'bands', count(*) from public.home_sections;
