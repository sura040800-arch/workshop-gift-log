-- いただき物管理：自由入力欄の追加
alter table public.gifts
  add column if not exists disposition text not null default '',
  add column if not exists notes text not null default '';
