-- I AM RATAN — shut it at the grant, not at the policy
--
-- Two attempts at dropping the policy have now failed, and the writes still go
-- through. I have been guessing at the wrong layer.
--
-- PostgREST checks the table GRANT first and only then consults RLS. So if anon
-- holds INSERT on the table, RLS is the only thing standing in the way — and if
-- a policy permits it, or if RLS is not enforced on that table, the write
-- lands. Dropping a policy by name cannot help when the name is wrong, and
-- cannot help at all if the grant is what is really carrying it.
--
-- Nothing on the shop front writes either table. Checked: no page and no script
-- outside admin.js mentions them. The order timeline is written by note_stage(),
-- a SECURITY DEFINER trigger that runs as the table's owner and does not need
-- anon to hold anything. The desk writes them as an authenticated admin.
--
-- So the grant simply should not exist.

revoke insert, update, delete on public.order_events from anon;
revoke insert, update, delete on public.returns       from anon;

-- The desk must keep working. It signs in, so it is `authenticated`, not anon.
grant select, insert, update, delete on public.order_events to authenticated;
grant select, insert, update, delete on public.returns       to authenticated;

-- the rows the testing wrote
delete from public.order_events where note in ('SECURITY PROBE','RECHECK','FINAL RECHECK');
delete from public.returns where reason in ('SECURITY PROBE','RECHECK','FINAL RECHECK');
delete from public.orders
 where payment_state is distinct from 'paid'
   and lower(email) in ('security-test@example.com','t@e.co','c@e.co',
                        'customer@example.com','priya.sharma@example.com');

-- ---------------------------------------------------------------- the truth --
-- Two questions at once: what anon is actually GRANTED, and what policies
-- exist. I have been reading the second and the first is what decides.
select 'GRANT' as kind,
       table_name  as on_what,
       grantee     as who,
       privilege_type as what,
       '' as extra
  from information_schema.role_table_grants
 where table_schema = 'public'
   and table_name in ('order_events','returns','orders')
   and grantee in ('anon','authenticated','public')
   and privilege_type in ('INSERT','UPDATE','DELETE')

union all

select 'POLICY',
       tablename,
       array_to_string(roles, ','),
       cmd,
       policyname
  from pg_policies
 where schemaname = 'public'
   and tablename in ('order_events','returns','orders')

order by 1, 2, 3;
