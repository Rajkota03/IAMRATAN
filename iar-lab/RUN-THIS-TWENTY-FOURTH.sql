-- I AM RATAN — stock that actually moves
--
-- Until now nothing reduced inventory when an order was placed. The shop showed
-- a stock figure, disabled a sold-out neck, and had a hide_sold_out setting —
-- all of it decorative, because the number only ever changed when the house
-- edited it by hand. Two people could buy the last shirt, and fifty could be
-- ordered where five existed.
--
-- WHEN IT COMES OFF
--
-- When the order is placed, not when it is paid for. If it waited for payment,
-- two customers could both reach the Razorpay window holding the last shirt and
-- one of them would be disappointed after paying. Taking it at the order means
-- the second customer is turned away before any money moves.
--
-- The cost of that choice is that an unpaid order holds stock. The house
-- releases it by marking the order cancelled, which puts every unit back — so
-- the desk already has the control it needs, using a status it already sets.
--
-- THE RACE
--
-- `select ... for update` locks the inventory row. Two orders for the last
-- shirt arriving in the same instant are made to queue: the first takes it, the
-- second reads the row AFTER that and finds nothing left. Without the lock both
-- would read 1 and both would succeed. This is the whole reason it is a trigger
-- and not something the browser does.
--
-- A NECK THAT IS NOT STOCKED IS NOT THE SAME AS ONE THAT IS FINISHED
--
-- The house cuts 39, 40, 42, 44 and 46. Sizes 41, 43 and 45 have no inventory
-- row at all, and the product page marks them dashed and sells them made to
-- measure. Those pass through untouched — there is no rack quantity to reduce,
-- and refusing them would break the bespoke route on purpose.

create or replace function public.take_stock() returns trigger
language plpgsql security definer set search_path = public as $$
declare
  it     jsonb;
  want   integer;
  p_id   bigint;
  sz     text;
  have   integer;
  p_name text;
begin
  for it in select * from jsonb_array_elements(coalesce(new.items, '[]'::jsonb))
  loop
    sz := it->>'size';

    /* the same clamp the pricing trigger uses, for the same reason: the
       quantity arrives from a browser and cannot be believed */
    want := case when (it->>'qty') ~ '^[0-9]+$'
                 then least(greatest((it->>'qty')::int, 1), 50)
                 else 1 end;

    select id, name into p_id, p_name
      from public.products where slug = it->>'slug';

    if p_id is null then
      continue;                         -- not a real cloth; it is worth nothing
    end if;

    /* Lock the row before reading it. Everything below depends on this. */
    select qty into have
      from public.inventory
     where product_id = p_id and size = sz
     for update;

    if not found then
      continue;                         -- a neck the house does not stock
    end if;

    if have < want then
      raise exception
        'Only % left of % in neck %, and % were asked for.',
        have, p_name, sz, want
        using errcode = 'check_violation';
    end if;

    update public.inventory
       set qty = qty - want
     where product_id = p_id and size = sz;

    insert into public.stock_moves
      (product_id, size, delta, before_qty, after_qty, reason, by_email)
    values
      (p_id, sz, -want, have, have - want, 'sale', new.email);
  end loop;

  return new;
end $$;

drop trigger if exists orders_take_stock on public.orders;
create trigger orders_take_stock after insert on public.orders
  for each row execute function public.take_stock();

-- ------------------------------------------------------- putting it back --
-- A cancelled order returns every unit. Written as its own trigger so the desk
-- needs no new button: cancelling in the admin already sets this status.
create or replace function public.return_stock() returns trigger
language plpgsql security definer set search_path = public as $$
declare it jsonb; back integer; p_id bigint; sz text; have integer;
begin
  if new.status <> 'cancelled' or old.status = 'cancelled' then
    return new;                          -- nothing to do
  end if;

  for it in select * from jsonb_array_elements(coalesce(new.items, '[]'::jsonb))
  loop
    sz := it->>'size';
    back := case when (it->>'qty') ~ '^[0-9]+$'
                 then least(greatest((it->>'qty')::int, 1), 50)
                 else 1 end;

    select id into p_id from public.products where slug = it->>'slug';
    if p_id is null then continue; end if;

    select qty into have from public.inventory
     where product_id = p_id and size = sz for update;
    if not found then continue; end if;

    update public.inventory set qty = qty + back
     where product_id = p_id and size = sz;

    insert into public.stock_moves
      (product_id, size, delta, before_qty, after_qty, reason, by_email)
    values
      (p_id, sz, back, have, have + back, 'return', coalesce(new.email, 'the house'));
  end loop;

  return new;
end $$;

drop trigger if exists orders_return_stock on public.orders;
create trigger orders_return_stock after update on public.orders
  for each row execute function public.return_stock();

-- ---------------------------------------------------------------- did it work --
select 'the sale trigger'   as checked,
       case when count(*) = 1 then 'ok' else 'MISSING' end as result
  from pg_trigger where tgname = 'orders_take_stock'
union all
select 'the cancel trigger',
       case when count(*) = 1 then 'ok' else 'MISSING' end
  from pg_trigger where tgname = 'orders_return_stock'
union all
select 'necks currently tracked',
       count(*)::text from public.inventory
union all
select 'total units on the rack',
       coalesce(sum(qty), 0)::text from public.inventory;
