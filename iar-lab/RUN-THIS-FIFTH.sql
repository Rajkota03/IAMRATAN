-- I AM RATAN — the facts the law asks for, as settings the house types in once.
-- Run in the SQL Editor after the previous four.
--
-- WHY THESE ARE SETTINGS AND NOT CODE
-- The GSTIN, the registered address and the Grievance Officer are legally
-- required on an Indian shop, and they are the client's facts, not mine. Put
-- them here and the site, the invoice and the legal pages all read the same
-- value from one place — and filling them in becomes typing, not a deploy.
--
-- Leave one blank and the site simply does not print that line. Nothing shows
-- a placeholder to a customer.

insert into public.settings (key, value, note) values
  ('legal_name', 'Artisan Apparels',
   'The registered business name, as on the GST certificate.'),
  ('registered_address', '',
   'Full registered address. Required on the site by the e-commerce rules.'),
  ('gstin', '',
   'GST number. Shown on the site and on every invoice.'),
  ('grievance_officer', '',
   'Name of the Grievance Officer. A legal appointment — complaints answered in 48 hours.'),
  ('grievance_email', '', 'Email for complaints. Required.'),
  ('grievance_phone', '', 'Phone for complaints. Required.'),
  ('state_code', '36',
   'Telangana is 36. Decides CGST+SGST (same state) vs IGST (elsewhere).'),
  ('state_name', 'Telangana', 'Where the house is registered.'),
  ('gst_rate', '12',
   'Per cent. Indian ready-made garments: 5 below ₹1,000, 12 above.'),
  ('hsn_code', '6205', 'HSN for men''s shirts. Printed on the invoice.'),
  ('invoice_prefix', 'IAR/26-27/',
   'Invoice numbers run in a single unbroken series per financial year.'),
  ('courier_name', '', 'Who carries the parcels. Printed on the label.'),
  ('return_ships_free', 'true',
   'Does the house pay return postage? Must be stated on the site either way.'),
  ('cancel_hours', '24',
   'Hours a customer may cancel before dispatch. Must be stated.')
on conflict (key) do nothing;

-- ------------------------------------------------------------- invoicing --
-- One unbroken series per financial year, which is what the GST rules ask for.
-- A sequence, not max(id)+1: two orders placed in the same second must never
-- be handed the same invoice number.

create sequence if not exists public.invoice_seq start 1;

alter table public.orders add column if not exists invoice_no text;
alter table public.orders add column if not exists invoiced_at timestamptz;
alter table public.orders add column if not exists courier text;
alter table public.orders add column if not exists tracking text;

-- The delivery state decides the tax split, so the order has to carry it.
alter table public.orders add column if not exists state text;

-- Prices on this shop INCLUDE tax, so the taxable value is worked backwards
-- from the total. Getting this the wrong way round overstates the sale and
-- underpays the tax, which is the expensive direction to be wrong in.
--
-- Same state as the house  -> CGST + SGST, half each.
-- Any other state          -> IGST, the whole amount.
-- Getting THAT wrong is worse than getting it late: the money goes to the
-- wrong government and has to be unwound.
create or replace function public.invoice_for(order_id bigint)
returns table (
  taxable numeric, cgst numeric, sgst numeric, igst numeric,
  total numeric, same_state boolean
)
language sql stable as $$
  with s as (
    select
      (select value::numeric from public.settings where key = 'gst_rate') as rate,
      (select lower(value) from public.settings where key = 'state_name') as home
  ),
  o as (select * from public.orders where id = order_id),
  calc as (
    select
      o.total::numeric as gross,
      round(o.total / (1 + s.rate/100), 2) as taxable,
      /* the state on the order if it was given; otherwise fall back to the PIN
         code, where 500-509 is Telangana. The fallback is a guess and is only
         there so an old order still prints — new ones carry the state. */
      coalesce(
        nullif(lower(coalesce(o.state, '')), '') = s.home,
        substring(coalesce(o.pincode,'') from 1 for 3) between '500' and '509'
      ) as same_state
    from o, s
  )
  select
    taxable,
    case when same_state then round((gross - taxable) / 2, 2) else 0 end,
    case when same_state then round((gross - taxable) / 2, 2) else 0 end,
    case when same_state then 0 else round(gross - taxable, 2) end,
    gross,
    same_state
  from calc;
$$;

-- Stamp an invoice number the first time one is asked for, and never again.
-- An invoice number that changes is a serious problem at audit.
create or replace function public.stamp_invoice(order_id bigint)
returns text
language plpgsql
security definer
set search_path = public
as $$
declare n text; pre text;
begin
  if not public.is_admin() then
    raise exception 'not allowed';
  end if;
  select invoice_no into n from public.orders where id = order_id;
  if n is not null then return n; end if;
  select value into pre from public.settings where key = 'invoice_prefix';
  n := coalesce(pre,'IAR/') || lpad(nextval('public.invoice_seq')::text, 4, '0');
  update public.orders
     set invoice_no = n, invoiced_at = now()
   where id = order_id;
  return n;
end $$;

revoke all on function public.stamp_invoice(bigint) from public;
grant execute on function public.stamp_invoice(bigint) to authenticated;
