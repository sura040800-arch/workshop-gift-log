-- Restrict staff_profiles SELECT access to the signed-in user and active admins.
-- Preserve any existing ALL policies' write permissions by splitting them into
-- INSERT / UPDATE / DELETE policies before removing the broad policy.
do $$
declare
  p record;
  v_roles text;
begin
  for p in
    select policyname, cmd, roles, qual, with_check
    from pg_policies
    where schemaname = 'public'
      and tablename = 'staff_profiles'
      and cmd in ('SELECT', 'ALL')
  loop
    if p.cmd = 'ALL' then
      select string_agg(
        case when r = 'public' then 'public' else quote_ident(r) end,
        ', '
      ) into v_roles
      from unnest(p.roles) as r;

      execute format(
        'create policy %I on public.staff_profiles for insert to %s %s',
        left(p.policyname, 48) || '_ins',
        coalesce(v_roles, 'public'),
        case when p.with_check is not null then 'with check (' || p.with_check || ')' else '' end
      );
      execute format(
        'create policy %I on public.staff_profiles for update to %s %s %s',
        left(p.policyname, 48) || '_upd',
        coalesce(v_roles, 'public'),
        case when p.qual is not null then 'using (' || p.qual || ')' else '' end,
        case when p.with_check is not null then 'with check (' || p.with_check || ')' else '' end
      );
      execute format(
        'create policy %I on public.staff_profiles for delete to %s %s',
        left(p.policyname, 48) || '_del',
        coalesce(v_roles, 'public'),
        case when p.qual is not null then 'using (' || p.qual || ')' else '' end
      );
    end if;
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
