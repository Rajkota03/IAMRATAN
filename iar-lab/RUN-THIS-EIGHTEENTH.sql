-- I AM RATAN — the last of the brackets
-- Run this whole file once in the Supabase SQL editor. Safe to run twice.
--
-- Three legal pages were carrying a bordered box reading "This page is a
-- working draft" and values printed in [square brackets] — on a live shop
-- taking real money. The delivery and returns numbers already existed as
-- settings and simply were not being read. What was missing is what postage
-- costs, so that is added here and the pages now read all three.

insert into public.settings (key, value, note) values
  ('shipping_note', 'Postage is free',
   'What delivery costs, said in the house''s own words. Printed on the '
   'shipping page. It is printed as its own sentence, so write it as one: '
   '"Postage is free", "Free above 4,999, a flat 199 below", "A flat 149".')
on conflict (key) do nothing;

insert into public.settings (key, value, note) values
  ('mtm_lead', 'two to four weeks from the measure',
   'How long a made-to-measure garment takes, said as a phrase rather than a '
   'number so the house can write "three weeks" or "four to six weeks in the '
   'season" as it likes. Printed on the shipping page.')
on conflict (key) do nothing;

-- ---------------------------------------------------------------- did it work --
select 'the three numbers the shipping page needs' as checked,
       case when count(*) = 5 then 'ok'
            else 'MISSING — expected delivery_min_days, delivery_max_days, '
                 'returns_days, shipping_note and mtm_lead' end as result
  from public.settings
 where key in ('delivery_min_days','delivery_max_days','returns_days',
               'shipping_note','mtm_lead');
