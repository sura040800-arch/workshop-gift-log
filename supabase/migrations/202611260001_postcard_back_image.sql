-- Admin-managed postcard back image
insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values ('postcard-back', 'postcard-back', false, 10485760, array['image/jpeg','image/png','image/webp'])
on conflict (id) do update set public = false, file_size_limit = 10485760,
  allowed_mime_types = array['image/jpeg','image/png','image/webp'];

drop policy if exists "postcard_back_read_active_staff" on storage.objects;
create policy "postcard_back_read_active_staff"
on storage.objects for select to authenticated
using (
  bucket_id = 'postcard-back'
  and exists (
    select 1 from public.staff_profiles p
    where p.user_id = auth.uid() and p.is_active = true
  )
);

drop policy if exists "postcard_back_insert_admin" on storage.objects;
create policy "postcard_back_insert_admin"
on storage.objects for insert to authenticated
with check (
  bucket_id = 'postcard-back'
  and (storage.foldername(name))[1] = 'current'
  and exists (
    select 1 from public.staff_profiles p
    where p.user_id = auth.uid() and p.is_active = true and p.role = 'admin'
  )
);

drop policy if exists "postcard_back_update_admin" on storage.objects;
create policy "postcard_back_update_admin"
on storage.objects for update to authenticated
using (
  bucket_id = 'postcard-back'
  and (storage.foldername(name))[1] = 'current'
  and exists (
    select 1 from public.staff_profiles p
    where p.user_id = auth.uid() and p.is_active = true and p.role = 'admin'
  )
)
with check (
  bucket_id = 'postcard-back'
  and (storage.foldername(name))[1] = 'current'
  and exists (
    select 1 from public.staff_profiles p
    where p.user_id = auth.uid() and p.is_active = true and p.role = 'admin'
  )
);

drop policy if exists "postcard_back_delete_admin" on storage.objects;
create policy "postcard_back_delete_admin"
on storage.objects for delete to authenticated
using (
  bucket_id = 'postcard-back'
  and exists (
    select 1 from public.staff_profiles p
    where p.user_id = auth.uid() and p.is_active = true and p.role = 'admin'
  )
);
