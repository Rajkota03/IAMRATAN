-- I AM RATAN — shut the two write holes, by finding them rather than guessing
--
-- The previous file used `drop policy if exists "anyone may open a timeline"`.
-- That is a guess at the policy's NAME, taken from the file that created it,
-- and `if exists` means a wrong guess does nothing at all and says nothing.
-- The policies are still there: a stranger could still write a timeline row and
-- still file a return, tested against the live site after that file was run.
--
-- Two ways the name can differ from the file: it was recreated by hand at some
-- point, or it was created without TO anon, which makes it belong to PUBLIC
-- instead — and PUBLIC includes anon while not matching a search for it.
--
-- So this does not name anything. It finds every policy on those two tables
-- that lets an unauthenticated caller INSERT, whatever it happens to be called
-- and whichever role it was granted to, and drops it.

do $$
declare p record;
begin
  for p in
    select policyname, tablename, roles, cmd
      from pg_policies
     where schemaname = 'public'
       and tablename in ('order_events', 'returns')
       and cmd in ('INSERT', 'ALL')
       and (roles && array['anon','public']::name[])
  loop
    execute format('drop policy %I on public.%I', p.policyname, p.tablename);
    raise notice 'dropped "%" on % (was granted to %, cmd %)',
      p.policyname, p.tablename, p.roles, p.cmd;
  end loop;
end $$;

-- The rows the testing wrote.
delete from public.order_events where note in ('SECURITY PROBE', 'RECHECK');
delete from public.returns where reason in ('SECURITY PROBE', 'RECHECK');
delete from public.orders
 where payment_state is distinct from 'paid'
   and lower(email) in ('security-test@example.com','t@e.co','c@e.co',
                        'customer@example.com','priya.sharma@example.com');

-- ------------------------------------------------------------ did it work? --
-- Counts anything that still lets an unauthenticated caller write, by the same
-- test used to find them — so this cannot pass on a name that never matched.
select 'a stranger can write a timeline row' as checked,
       case when count(*) = 0 then 'ok — shut' else 'STILL OPEN' end as result
  from pg_policies
 where schemaname = 'public' and tablename = 'order_events'
   and cmd in ('INSERT','ALL') and (roles && array['anon','public']::name[])
union all
select 'a stranger can file a return',
       case when count(*) = 0 then 'ok — shut' else 'STILL OPEN' end
  from pg_policies
 where schemaname = 'public' and tablename = 'returns'
   and cmd in ('INSERT','ALL') and (roles && array['anon','public']::name[])
union all
select 'the shop can still take an order',
       case when count(*) >= 1 then 'ok' else 'BROKEN — checkout will fail' end
  from pg_policies
 where schemaname = 'public' and tablename = 'orders'
   and cmd in ('INSERT','ALL') and (roles && array['anon','public']::name[])
union all
select 'the house can still stamp a stage',
       case when count(*) >= 1 then 'ok' else 'BROKEN — the desk cannot advance an order' end
  from pg_policies
 where schemaname = 'public' and tablename = 'order_events'
   and 'authenticated' = any(roles)
union all
select 'the timeline trigger is still there',
       case when count(*) = 1 then 'ok' else 'MISSING' end
  from pg_trigger where tgname = 'orders_timeline'
union all
select 'probe rows cleared',
       case when count(*) = 0 then 'ok' else 'SOME LEFT' end
  from public.order_events where note in ('SECURITY PROBE','RECHECK');
