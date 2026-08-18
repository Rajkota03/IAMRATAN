-- Removes the em dashes from the three product descriptions that carry them.
-- The other twenty-four are already clean.
--
-- Why this is a separate step: product copy is served from Supabase, not from
-- assets/catalogue.js. That file is the local fallback and has already been
-- updated, but nothing a visitor reads changes until this runs.
--
-- Paste into the Supabase SQL editor and run. Safe to run twice.

update products set body =
'A deep cocoa, woven close and finished soft. The colour reads almost black in a low room and opens to warm brown in daylight, which is why it sits as easily under a jacket at six as it does across a table at nine. Engraved buttons, and the house signature embroidered tone on tone at the cuff.'
where slug = 'cocoa-drift';

update products set body =
'A grey-blue with weather in it. Quieter than a navy and warmer than a steel, it is the shirt for the days that go long. Cut in the same five sizes, finished by the same hands, with the signature embroidered at the cuff in its own colour.'
where slug = 'slate-harbour';

update products set body =
'There’s depth in the detail. A rich navy ground is interrupted by a layered stripe, fine beige and white lines running in quiet rhythm, giving this shirt a complexity that rewards a second look. Tonal buttons and a structured spread collar lend it a formal edge without sacrificing ease. The kind of shirt that anchors a wardrobe and never overstays its welcome.'
where slug = 'harbour-blue';

-- Check: expect zero rows.
select slug from products where body like '%—%' or body like '%–%';
