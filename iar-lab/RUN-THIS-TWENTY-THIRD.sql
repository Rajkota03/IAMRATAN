-- I AM RATAN — clearing up after the security round. Nothing here changes how
-- the shop behaves; it only removes rows the testing left behind.

delete from public.orders
 where payment_state is distinct from 'paid'
   and lower(email) in ('security-test@example.com','t@e.co','c@e.co',
                        'customer@example.com','priya.sharma@example.com');

delete from public.carts where cart_id in ('victim-cart-001','uniq-probe-xyz')
   or cart_id like 'probe-%';

delete from public.order_events
 where note in ('SECURITY PROBE','RECHECK','FINAL RECHECK','SHUT CHECK','stranger');

delete from public.returns
 where reason in ('SECURITY PROBE','RECHECK','FINAL RECHECK','SHUT CHECK');

select 'test orders left'  as checked,
       case when count(*) = 0 then 'ok' else count(*)::text || ' remain' end as result
  from public.orders where lower(email) like '%example.com'
                       and payment_state is distinct from 'paid'
union all
select 'probe carts left',
       case when count(*) = 0 then 'ok' else count(*)::text || ' remain' end
  from public.carts where cart_id in ('victim-cart-001','uniq-probe-xyz')
union all
select 'probe timeline rows left',
       case when count(*) = 0 then 'ok' else count(*)::text || ' remain' end
  from public.order_events
 where note in ('SECURITY PROBE','RECHECK','FINAL RECHECK','SHUT CHECK','stranger');
