-- I AM RATAN — a shirt could be bought for one rupee. RUN THIS NOW.
--
-- THE HOLE
--
-- price_the_order() priced an order like this:
--
--   coalesce(p.price, nullif(i->>'price','')::numeric, 0) * coalesce((i->>'qty')::int, 1)
--
-- Two mistakes in one line, and together they are a free shop.
--
--   1. The quantity is whatever the browser said, multiplied straight through.
--      Nothing stops it being NEGATIVE, so a line can SUBTRACT from the total.
--
--   2. When the slug is not a real product, p.price is null and it falls back
--      to the price the BROWSER sent for that made-up item.
--
-- So: one real shirt at 5,999, plus an invented line priced 5,998 at quantity
-- minus one, and the order totals 1. Demonstrated against the live site before
-- writing this — the payment endpoint offered to take exactly ₹1 for a ₹5,999
-- shirt. Anybody who can open the developer tools can do it.
--
-- THE FIX
--
--   * an INNER JOIN, so a line that is not a real product is worth nothing and
--     can never contribute a price the browser invented
--   * the quantity is read only if it is a run of digits, so a minus sign, a
--     decimal, a word or an empty string all fall back to 1
--   * it is capped at 50, because a real order is not 99,999 shirts and an
--     accidental one should not look like a 600-million-rupee sale
--
-- The browser's own `price` field is now ignored completely. It is still sent
-- and still stored on the order for the record, but nothing computes from it.

create or replace function public.price_the_order() returns trigger
language plpgsql security definer set search_path = public as $$
declare sub numeric := 0; v record;
begin
  select coalesce(sum(
           p.price *
           case
             when (i->>'qty') ~ '^[0-9]+$'
               then least(greatest((i->>'qty')::int, 1), 50)
             else 1
           end
         ), 0)
    into sub
    from jsonb_array_elements(coalesce(new.items, '[]'::jsonb)) i
    join public.products p on p.slug = i->>'slug';

  new.subtotal := sub;

  if coalesce(new.discount_code, '') <> '' then
    select * into v from public.discount_value(new.discount_code, sub, new.phone);
    if v.ok then
      new.discount_amount := v.amount;
    else
      -- it did not apply. Do not pretend it did.
      new.discount_code := null;
      new.discount_amount := 0;
    end if;
  else
    new.discount_amount := 0;
  end if;

  new.total := greatest(sub - coalesce(new.discount_amount, 0), 0);
  return new;
end $$;

drop trigger if exists orders_pricing on public.orders;
create trigger orders_pricing before insert or update on public.orders
  for each row execute function public.price_the_order();

-- ------------------------------------------------- clear out the test orders --
-- The three the exploit was proved with, and anything else obviously mine.
delete from public.orders
 where payment_state is distinct from 'paid'
   and (lower(email) in ('security-test@example.com','t@e.co','c@e.co','customer@example.com')
        or ref in ('IAR-260830-CTRL','IAR-260830-XPL1','IAR-260830-XPL2'));

-- ------------------------------------------------------------ prove it is shut --
-- Prices three baskets through the real function without writing anything:
-- an honest one, the exploit, and an absurd quantity.
with basket(what, items) as (
  values
    ('one real shirt',
     '[{"slug":"cocoa-drift","qty":1,"price":5999}]'::jsonb),
    ('THE EXPLOIT: a real shirt plus an invented line at quantity minus one',
     '[{"slug":"cocoa-drift","qty":1,"price":5999},
       {"slug":"not-a-real-shirt","qty":-1,"price":5998}]'::jsonb),
    ('99999 of the same shirt',
     '[{"slug":"cocoa-drift","qty":99999,"price":5999}]'::jsonb)
)
select b.what,
       (select coalesce(sum(
          p.price * case when (i->>'qty') ~ '^[0-9]+$'
                         then least(greatest((i->>'qty')::int, 1), 50)
                         else 1 end), 0)
          from jsonb_array_elements(b.items) i
          join public.products p on p.slug = i->>'slug') as "what it now costs"
  from basket b;
