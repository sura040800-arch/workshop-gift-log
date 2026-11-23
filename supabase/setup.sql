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
