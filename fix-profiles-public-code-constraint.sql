-- Run in Supabase → SQL Editor against the project that backs this app.
-- Aligns profile temporary code fields with the email-only login flow.

alter table public.profiles
  drop constraint if exists profiles_temp_code_format_chk;

alter table public.profiles
  add constraint profiles_temp_code_format_chk
  check (temp_code is null or temp_code ~ '^[0-9]{4}$');

create unique index if not exists profiles_temp_code_key
  on public.profiles(temp_code)
  where temp_code is not null;

-- Existing links still work while not expired, but old one-digit code links should be retired.
drop policy if exists "profiles_anon_select_active_code" on public.profiles;
create policy "profiles_anon_select_active_code"
on public.profiles
for select
to anon
using (temp_code is not null and temp_code_expires_at > now() and is_active = true);
