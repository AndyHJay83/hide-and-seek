create extension if not exists "uuid-ossp";

create table if not exists public.profiles (
  id uuid primary key default uuid_generate_v4(),
  email text unique not null,
  temp_code text,
  temp_code_expires_at timestamptz,
  is_active boolean not null default true,
  short_deal boolean not null default false,
  static_stack boolean not null default false,
  stack_type text not null default 'stebbins',
  stebbins_start_suit integer not null default 2,
  stebbins_start_value integer not null default 0,
  custom_stack_json jsonb,
  created_at timestamptz not null default now()
);

alter table public.profiles add column if not exists temp_code text;
alter table public.profiles add column if not exists temp_code_expires_at timestamptz;
alter table public.profiles add column if not exists is_active boolean not null default true;
alter table public.profiles add column if not exists short_deal boolean not null default false;
alter table public.profiles add column if not exists static_stack boolean not null default false;
alter table public.profiles add column if not exists stack_type text not null default 'stebbins';
alter table public.profiles add column if not exists stebbins_start_suit integer not null default 2;
alter table public.profiles add column if not exists stebbins_start_value integer not null default 0;
alter table public.profiles add column if not exists custom_stack_json jsonb;
create unique index if not exists profiles_temp_code_key on public.profiles(temp_code) where temp_code is not null;
alter table public.profiles drop constraint if exists profiles_temp_code_format_chk;
alter table public.profiles
  add constraint profiles_temp_code_format_chk
  check (temp_code is null or temp_code ~ '^[0-9]{4}$');
alter table public.profiles drop constraint if exists profiles_stack_type_chk;
alter table public.profiles
  add constraint profiles_stack_type_chk
  check (stack_type in ('stebbins', 'ndo', 'eight_kings', 'mnemonica', 'aronson', 'redford', 'custom'));
alter table public.profiles drop constraint if exists profiles_stebbins_suit_chk;
alter table public.profiles
  add constraint profiles_stebbins_suit_chk
  check (stebbins_start_suit between 0 and 3);
alter table public.profiles drop constraint if exists profiles_stebbins_value_chk;
alter table public.profiles
  add constraint profiles_stebbins_value_chk
  check (stebbins_start_value between 0 and 12);

create table if not exists public.sessions (
  id uuid primary key default uuid_generate_v4(),
  performer_id uuid not null references public.profiles(id) on delete cascade,
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

alter table public.profiles enable row level security;
alter table public.sessions enable row level security;

drop policy if exists "profiles_anon_select" on public.profiles;
create policy "profiles_anon_select"
on public.profiles
for select
to anon
using (true);

drop policy if exists "profiles_anon_insert" on public.profiles;
create policy "profiles_anon_insert"
on public.profiles
for insert
to anon
with check (email is not null);

drop policy if exists "profiles_anon_update" on public.profiles;
create policy "profiles_anon_update"
on public.profiles
for update
to anon
using (true)
with check (true);

drop policy if exists "sessions_any_select" on public.sessions;
create policy "sessions_any_select"
on public.sessions
for select
to anon, authenticated
using (true);

drop policy if exists "sessions_anon_insert" on public.sessions;
create policy "sessions_anon_insert"
on public.sessions
for insert
to anon
with check (true);

-- Performer app (anon) expires old sessions before inserting a new one.
drop policy if exists "sessions_anon_performer_update" on public.sessions;
create policy "sessions_anon_performer_update"
on public.sessions
for update
to anon
using (true)
with check (true);

drop policy if exists "sessions_anon_update_active_unsubmitted_60m" on public.sessions;
create policy "sessions_anon_update_active_unsubmitted_60m"
on public.sessions
for update
to anon
using (
  expired = false
  and created_at > (now() - interval '60 minutes')
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
  and created_at > (now() - interval '60 minutes')
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
