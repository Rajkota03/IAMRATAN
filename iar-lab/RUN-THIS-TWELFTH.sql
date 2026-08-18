-- I AM RATAN — stand-in facts, so the legal block can be built and tested
-- before the client has sent a single real one.
-- Run in the SQL Editor after the previous eleven.
--
-- ======================== WHY THIS NEEDS A SWITCH ========================
-- The GSTIN, the registered address and the Grievance Officer are not decorative
-- strings. They are statutory: an Indian shop must publish them, and a customer
-- with a complaint is legally entitled to reach the named officer within 48
-- hours. Publishing invented ones on a reachable site is not a placeholder, it
-- is false information with a phone number attached that nobody answers.
--
-- So every value below is a stand-in AND the shop front is told so. Nothing here
-- reaches a customer. `facts_are_real` stays false until the client's own facts
-- replace these, and while it is false:
--
--   the shop front  prints NOTHING, exactly as it did when the fields were empty
--   the preview     renders them for me, behind ?preview=facts, so the block can
--                   be built and checked on all twelve pages
--   the desk        says loudly that the site is publishing nothing yet, and why
--   the invoice     stamps itself a specimen
--
-- Every stand-in is also chosen so it CANNOT mislead if it ever escapes:
--   example.com   is reserved by RFC 2606 and can never be a real mailbox
--   00000 00000   is not a dialable Indian number
--   the address   says PLACEHOLDER in it, in capitals
--
-- Turning this on is one line, at the very bottom, and it is the last thing
-- done before handover — not the first.

insert into public.settings (key, value, note) values
  ('facts_are_real', 'false',
   'FALSE while the seller details are stand-ins. The shop front prints nothing '
   'until this is true. Set it the day the client''s real GSTIN, address and '
   'Grievance Officer are entered — and not before.')
on conflict (key) do nothing;

-- The stand-ins. Written only where the field is still empty, so this can never
-- overwrite something real the house has already typed in.
update public.settings s set value = v.value
from (values
  ('registered_address',
   'PLACEHOLDER — not the real address. 1 Example Road, Banjara Hills, Hyderabad, Telangana 500034'),
  ('gstin',              '36AAAAA0000A1Z5'),
  ('grievance_officer',  'PLACEHOLDER — not a real person'),
  ('grievance_email',    'grievance@example.com'),
  ('grievance_phone',    '+91 00000 00000'),
  ('courier_name',       'PLACEHOLDER Couriers')
) as v(key, value)
where s.key = v.key and coalesce(trim(s.value), '') = '';

-- ------------------------------------------------- the specimen invoice ------
-- An invoice carrying a made-up GSTIN is the one document here that could cause
-- real trouble if it left the building, so while the facts are stand-ins it
-- says what it is on its face.

create or replace function public.facts_are_real() returns boolean
language sql stable as $$
  select coalesce(
    (select lower(value) = 'true' from public.settings where key = 'facts_are_real'),
    false);
$$;

grant execute on function public.facts_are_real() to anon, authenticated;

-- ---------------------------------------------------------- what is missing --
-- The desk reads this to tell the house exactly which facts are still stand-ins,
-- in the order they should be asked for.

create or replace view public.facts_status as
select
  s.key,
  case s.key
    when 'legal_name'         then 'Registered business name'
    when 'registered_address' then 'Full registered address'
    when 'gstin'              then 'GSTIN'
    when 'grievance_officer'  then 'Grievance Officer, by name'
    when 'grievance_email'    then 'Grievance email'
    when 'grievance_phone'    then 'Grievance phone'
    when 'courier_name'       then 'Who carries the parcels'
    else s.key
  end                                                    as label,
  s.value,
  -- a stand-in announces itself: reserved domains, undialable numbers, the word
  (s.value is null or trim(s.value) = ''
   or s.value ilike '%placeholder%'
   or s.value ilike '%example.com%'
   or s.value like '%00000 00000%'
   or s.value = '36AAAAA0000A1Z5')                       as is_placeholder,
  s.key in ('registered_address','gstin','grievance_officer',
            'grievance_email','grievance_phone')         as required_by_law
from public.settings s
where s.key in ('legal_name','registered_address','gstin','grievance_officer',
                'grievance_email','grievance_phone','courier_name')
order by array_position(
  array['legal_name','registered_address','gstin','grievance_officer',
        'grievance_email','grievance_phone','courier_name'], s.key);

alter view public.facts_status set (security_invoker = on);
revoke select on public.facts_status from anon;
grant  select on public.facts_status to authenticated;

-- =============================== ON HANDOVER ===============================
-- When the client sends the real five, type them into Settings on the desk and
-- then run this ONE line. Nothing else changes; the block appears on all twelve
-- pages by itself.
--
--   update public.settings set value = 'true' where key = 'facts_are_real';
--
-- Do not run it now. While it is false the site publishes nothing, which is the
-- correct thing for a shop that does not yet know its own GST number.
