create extension if not exists "uuid-ossp";

create table if not exists public.purchase_codes (
  code text primary key,
  redeemed boolean not null default false,
  redeemed_by uuid references auth.users(id),
  redeemed_at timestamptz
);

create table if not exists public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  email text unique not null,
  public_code text unique not null,
  is_active boolean not null default true,
  created_at timestamptz not null default now()
);

alter table public.profiles add column if not exists public_code text;
alter table public.profiles add column if not exists is_active boolean not null default true;
create unique index if not exists profiles_public_code_key on public.profiles(public_code);
alter table public.profiles drop constraint if exists profiles_public_code_format_chk;
alter table public.profiles
  add constraint profiles_public_code_format_chk
  check (public_code is null or public_code ~ '^[A-Z0-9]{6}$');

create table if not exists public.sessions (
  id uuid primary key default uuid_generate_v4(),
  performer_id uuid not null references auth.users(id) on delete cascade,
  created_at timestamptz not null default now(),
  seeker_suit integer,
  seeker_value integer,
  hider_suit integer,
  hider_value integer,
  submitted_at timestamptz,
  expired boolean not null default false,
  constraint sessions_seeker_suit_chk check (seeker_suit between 0 and 3 or seeker_suit is null),
  constraint sessions_hider_suit_chk check (hider_suit between 0 and 3 or hider_suit is null),
  constraint sessions_seeker_value_chk check (seeker_value between 0 and 12 or seeker_value is null),
  constraint sessions_hider_value_chk check (hider_value between 0 and 12 or hider_value is null)
);

alter table public.purchase_codes enable row level security;
alter table public.profiles enable row level security;
alter table public.sessions enable row level security;

drop policy if exists "purchase_codes_anon_select" on public.purchase_codes;
create policy "purchase_codes_anon_select"
on public.purchase_codes
for select
to anon, authenticated
using (true);

drop policy if exists "purchase_codes_auth_redeem_update" on public.purchase_codes;
create policy "purchase_codes_auth_redeem_update"
on public.purchase_codes
for update
to authenticated
using (redeemed = false)
with check (
  redeemed = true
  and redeemed_by = auth.uid()
  and redeemed_at is not null
);

drop policy if exists "profiles_auth_select_own" on public.profiles;
create policy "profiles_auth_select_own"
on public.profiles
for select
to authenticated
using (id = auth.uid());

drop policy if exists "profiles_auth_insert_own" on public.profiles;
create policy "profiles_auth_insert_own"
on public.profiles
for insert
to authenticated
with check (
  id = auth.uid()
  and public_code = upper(public_code)
  and public_code ~ '^[A-Z0-9]{6}$'
);

drop policy if exists "profiles_auth_update_own" on public.profiles;
create policy "profiles_auth_update_own"
on public.profiles
for update
to authenticated
using (id = auth.uid())
with check (id = auth.uid());

drop policy if exists "profiles_anon_select_active_code" on public.profiles;
create policy "profiles_anon_select_active_code"
on public.profiles
for select
to anon
using (public_code is not null and is_active = true);

drop policy if exists "sessions_any_select" on public.sessions;
create policy "sessions_any_select"
on public.sessions
for select
to anon, authenticated
using (true);

drop policy if exists "sessions_auth_insert_own" on public.sessions;
create policy "sessions_auth_insert_own"
on public.sessions
for insert
to authenticated
with check (performer_id = auth.uid());

drop policy if exists "sessions_performer_update_own" on public.sessions;
create policy "sessions_performer_update_own"
on public.sessions
for update
to authenticated
using (performer_id = auth.uid())
with check (performer_id = auth.uid());

drop policy if exists "sessions_anon_update_active_unsubmitted_30m" on public.sessions;
create policy "sessions_anon_update_active_unsubmitted_30m"
on public.sessions
for update
to anon
using (
  expired = false
  and submitted_at is null
  and created_at > (now() - interval '30 minutes')
  and exists (
    select 1
    from public.profiles p
    where p.id = performer_id
      and p.is_active = true
  )
)
with check (
  expired = false
  and submitted_at is not null
  and created_at > (now() - interval '30 minutes')
  and exists (
    select 1
    from public.profiles p
    where p.id = performer_id
      and p.is_active = true
  )
);

do $$
begin
  if not exists (
    select 1
    from pg_publication_tables
    where pubname = 'supabase_realtime'
      and schemaname = 'public'
      and tablename = 'sessions'
  ) then
    alter publication supabase_realtime add table public.sessions;
  end if;
end
$$;

-- Seed examples (optional):
-- insert into public.purchase_codes (code) values
-- ('HAS-ABCD-1234'),
-- ('HAS-EFGH-0002'),
-- ('HAS-IJKL-0003');
