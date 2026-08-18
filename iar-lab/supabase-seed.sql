-- I AM RATAN — seed the shop from the catalogue that shipped with the site.
-- Run AFTER supabase-shop.sql. Safe to re-run: it updates rather than duplicates.
-- Stock is seeded at 5 per size purely so the house has a number to edit;
-- the real counts are theirs to set on day one.

insert into public.products (slug,name,price,hex,collection,body,sort_order) values
  ('cocoa-drift','Cocoa Drift',5999,'#492F24','Working hours','A deep cocoa, woven close and finished soft. The colour reads almost black in a low room and opens to warm brown in daylight, which is why it sits as easily under a jacket at six as it does across a table at nine. Engraved buttons, and the house signature embroidered tone on tone at the cuff.',1)
on conflict (slug) do update set name=excluded.name, price=excluded.price,
  hex=excluded.hex, collection=excluded.collection, body=excluded.body,
  sort_order=excluded.sort_order;
insert into public.products (slug,name,price,hex,collection,body,sort_order) values
  ('slate-harbour','Slate Harbour',5999,'#4D5B6F','Working hours','A grey-blue with weather in it. Quieter than a navy and warmer than a steel, it is the shirt for the days that go long. Cut in the same five sizes, finished by the same hands, with the signature embroidered at the cuff in its own colour.',2)
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
  ('harbour-blue','Harbour Blue',2999,'#2F3E5C','Ratan''s stripes','There’s depth in the detail. A rich navy ground is interrupted by a layered stripe, fine beige and white lines running in quiet rhythm, giving this shirt a complexity that rewards a second look. Tonal buttons and a structured spread collar lend it a formal edge without sacrificing ease. The kind of shirt that anchors a wardrobe and never overstays its welcome.',23)
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
