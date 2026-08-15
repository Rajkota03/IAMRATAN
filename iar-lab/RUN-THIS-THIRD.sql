-- I AM RATAN — fix: the allowlist policies referred to themselves.
-- Run this once in the SQL Editor. It replaces the policies from the previous
-- file; nothing is lost and no data is touched.
--
-- WHAT WAS WRONG
-- Every policy asked "is this email in public.admins?" by selecting from
-- public.admins. But that table has row-level security too, so reading it ran
-- the same policy again, which read the table again. Postgres sees the loop
-- and refuses the query outright — so the check never returned true and every
-- allowlisted person was told they were not on the list.
--
-- THE FIX
-- One function, marked SECURITY DEFINER, which runs as its owner and therefore
-- reads the table without triggering row-level security. Every policy calls the
-- function instead of writing the subquery itself. The lookup happens once, in
-- one place, and cannot recurse.

create or replace function public.is_admin()
returns boolean
language sql
security definer
stable
set search_path = public
as $$
  select exists (
    select 1 from public.admins
    where lower(email) = lower(coalesce(auth.jwt() ->> 'email', ''))
  );
$$;

revoke all on function public.is_admin() from public;
grant execute on function public.is_admin() to authenticated, anon;

-- the allowlist itself: an admin may see who else is one
drop policy if exists "admins may read the list" on public.admins;
create policy "admins may read the list"
  on public.admins for select to authenticated
  using (public.is_admin());

-- an admin may add or remove other admins from the desk later
drop policy if exists "admins may edit the list" on public.admins;
create policy "admins may edit the list"
  on public.admins for all to authenticated
  using (public.is_admin()) with check (public.is_admin());

-- and every other table asks the same question the same way
do $$
declare t text;
begin
  foreach t in array array['orders','enquiries','products','inventory','settings','events'] loop
    execute format('drop policy if exists "admins only" on public.%I;', t);
    execute format(
      'create policy "admins only" on public.%I for all to authenticated '
      'using (public.is_admin()) with check (public.is_admin());', t);
  end loop;
end $$;

-- ---------------------------------------------------------------------------
-- Check it worked. Signed in as an allowlisted person this returns true;
-- signed out, or as anyone else, it returns false.
select public.is_admin() as am_i_admin;

-- And confirm who is on the list.
select email, name from public.admins order by email;
