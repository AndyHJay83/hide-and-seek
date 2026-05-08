-- Run in Supabase SQL Editor.
-- Fixes: "column profiles.permanent_code does not exist"

alter table public.profiles
  add column if not exists permanent_code text;

create unique index if not exists profiles_permanent_code_key
  on public.profiles(permanent_code)
  where permanent_code is not null;
