-- Limit staff_profiles email visibility to the signed-in user and active admins.
-- Remove existing permissive SELECT/ALL policies first; otherwise PostgreSQL ORs them together.
do $$
declare
  p record;
begin
  for p in
    select policyname
    from pg_policies
    where schemaname = 'public'
      and tablename = 'staff_profiles'
      and cmd in ('SELECT', 'ALL')
  loop
    execute format('drop policy if exists %I on public.staff_profiles', p.policyname);
  end loop;
end;
$$;

create or replace function public.is_active_gift_admin()
returns boolean
language sql
stable
security definer
set search_path = public, pg_temp
as $$
  select exists (
    select 1
    from public.staff_profiles
    where user_id = auth.uid()
      and role = 'admin'
      and is_active = true
  );
$$;

revoke all on function public.is_active_gift_admin() from public;
grant execute on function public.is_active_gift_admin() to authenticated;

create policy "staff_profiles_select_self_or_admin"
on public.staff_profiles
for select
to authenticated
using (
  user_id = auth.uid()
  or public.is_active_gift_admin()
);
