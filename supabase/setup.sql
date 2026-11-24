-- Workshop gift log: current schema and private photo storage.
-- The gifts table already exists in the current project. This script is safe to rerun.
create extension if not exists pgcrypto;

create table if not exists public.gifts (
  id uuid primary key default gen_random_uuid(),
  item_name text not null,
  customer_name text,
  received_date date not null default current_date,
  quantity text,
  postal_code text,
  address text,
  phone text,
  received_by text,
  photo_path text,
  thank_you_sent boolean not null default false,
  created_at timestamptz not null default now()
);

alter table public.gifts enable row level security;
drop policy if exists "Authenticated staff can manage gifts" on public.gifts;
create policy "Authenticated staff can manage gifts"
  on public.gifts for all to authenticated
  using (true) with check (true);
grant select, insert, update, delete on public.gifts to authenticated;

insert into storage.buckets (id, name, public, file_size_limit)
values ('gift-photos', 'gift-photos', false, 5242880)
on conflict (id) do update set public = false, file_size_limit = 5242880;

drop policy if exists "Authenticated staff can manage gift photos" on storage.objects;
create policy "Authenticated staff can manage gift photos"
  on storage.objects for all to authenticated
  using (bucket_id = 'gift-photos')
  with check (bucket_id = 'gift-photos');

-- IMPORTANT: Disable public user sign-ups in Supabase Authentication settings.
-- Invite only the staff members who should access customer information.


-- Staff roles: every new invited account starts as a normal staff member.
create table if not exists public.staff_profiles (
  user_id uuid primary key references auth.users(id) on delete cascade,
  email text,
  role text not null default 'staff' check (role in ('admin', 'staff')),
  created_at timestamptz not null default now()
);

alter table public.staff_profiles enable row level security;

create or replace function public.is_gift_admin()
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1 from public.staff_profiles
    where user_id = auth.uid() and role = 'admin'
  );
$$;

grant execute on function public.is_gift_admin() to authenticated;
grant select on public.staff_profiles to authenticated;
grant update (role) on public.staff_profiles to authenticated;

drop policy if exists "Users can read own staff profile" on public.staff_profiles;
create policy "Users can read own staff profile"
  on public.staff_profiles for select to authenticated
  using (user_id = auth.uid() or public.is_gift_admin());

drop policy if exists "Admins can update staff roles" on public.staff_profiles;
create policy "Admins can update staff roles"
  on public.staff_profiles for update to authenticated
  using (public.is_gift_admin())
  with check (public.is_gift_admin());

create or replace function public.create_gift_staff_profile()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  insert into public.staff_profiles (user_id, email, role)
  values (new.id, new.email, 'staff')
  on conflict (user_id) do update set email = excluded.email;
  return new;
end;
$$;

drop trigger if exists on_auth_user_created_gift_profile on auth.users;
create trigger on_auth_user_created_gift_profile
  after insert on auth.users
  for each row execute procedure public.create_gift_staff_profile();

-- Backfill existing accounts as staff; promote the owner to admin separately
-- using their own email in the SQL Editor after this script succeeds.
insert into public.staff_profiles (user_id, email, role)
select id, email, 'staff' from auth.users
on conflict (user_id) do update set email = excluded.email;

-- NOTE: Gift records remain shared among authenticated staff.
-- Only staff-role management is restricted to admins at the database level.
