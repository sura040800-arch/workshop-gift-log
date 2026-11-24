create or replace function public.get_gift_storage_usage()
returns jsonb
language plpgsql
security definer
set search_path = public, storage, pg_temp
as $$
declare
  v_role text;
  v_active boolean;
  v_storage_bytes bigint;
  v_db_bytes bigint;
begin
  select role, is_active into v_role, v_active
  from public.staff_profiles
  where user_id = auth.uid();

  if v_role is distinct from 'admin' or v_active is distinct from true then
    raise exception '管理者のみ実行できます';
  end if;

  select coalesce(sum((metadata->>'size')::bigint), 0)
    into v_storage_bytes
  from storage.objects
  where bucket_id = 'gift-photos';

  select pg_database_size(current_database()) into v_db_bytes;

  return jsonb_build_object(
    'storage_used_bytes', v_storage_bytes,
    'storage_limit_bytes', 1073741824,
    'database_used_bytes', v_db_bytes,
    'database_limit_bytes', 524288000,
    'measured_at', now()
  );
end;
$$;

revoke all on function public.get_gift_storage_usage() from public;
grant execute on function public.get_gift_storage_usage() to authenticated;
