-- Run this in Supabase SQL Editor for existing projects.
-- Fixes: "column profiles.temp_code does not exist"

create extension if not exists "uuid-ossp";

alter table public.profiles
  add column if not exists temp_code text;

alter table public.profiles
  add column if not exists temp_code_expires_at timestamptz;

create unique index if not exists profiles_temp_code_key
  on public.profiles(temp_code)
  where temp_code is not null;

alter table public.profiles
  drop constraint if exists profiles_temp_code_format_chk;

alter table public.profiles
  add constraint profiles_temp_code_format_chk
  check (temp_code is null or temp_code ~ '^[0-9]{4}$');
