-- Gift log shared workspace setup
-- Run this in Supabase SQL Editor after creating the project.
create extension if not exists pgcrypto;

create table if not exists public.gift_records (
  id uuid primary key default gen_random_uuid(),
  item text not null,
  customer text not null,
  received_date date not null,
  quantity text,
  postal_code text,
  address text,
  phone text,
  received_by text,
  photo_path text,
  thank_you_status text not null default 'pending'
    check (thank_you_status in ('pending', 'done')),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

alter table public.gift_records enable row level security;

drop policy if exists "Signed-in staff can read gift records" on public.gift_records;
create policy "Signed-in staff can read gift records"
  on public.gift_records for select to authenticated using (true);

drop policy if exists "Signed-in staff can add gift records" on public.gift_records;
create policy "Signed-in staff can add gift records"
  on public.gift_records for insert to authenticated with check (true);

drop policy if exists "Signed-in staff can update gift records" on public.gift_records;
create policy "Signed-in staff can update gift records"
  on public.gift_records for update to authenticated using (true) with check (true);

drop policy if exists "Signed-in staff can delete gift records" on public.gift_records;
create policy "Signed-in staff can delete gift records"
  on public.gift_records for delete to authenticated using (true);

grant select, insert, update, delete on public.gift_records to authenticated;

insert into storage.buckets (id, name, public)
values ('gift-photos', 'gift-photos', false)
on conflict (id) do update set public = false;

drop policy if exists "Signed-in staff can view gift photos" on storage.objects;
create policy "Signed-in staff can view gift photos"
  on storage.objects for select to authenticated
  using (bucket_id = 'gift-photos');

drop policy if exists "Signed-in staff can upload gift photos" on storage.objects;
create policy "Signed-in staff can upload gift photos"
  on storage.objects for insert to authenticated
  with check (bucket_id = 'gift-photos');

drop policy if exists "Signed-in staff can update gift photos" on storage.objects;
create policy "Signed-in staff can update gift photos"
  on storage.objects for update to authenticated
  using (bucket_id = 'gift-photos') with check (bucket_id = 'gift-photos');

drop policy if exists "Signed-in staff can delete gift photos" on storage.objects;
create policy "Signed-in staff can delete gift photos"
  on storage.objects for delete to authenticated
  using (bucket_id = 'gift-photos');
