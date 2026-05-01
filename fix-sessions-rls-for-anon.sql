-- Run in Supabase SQL Editor.
-- Fixes: "new row violates row-level security policy for table sessions"
-- when the app creates sessions with the anon key and performer_id = profiles.id.

-- Remove legacy auth-only session policies (names may vary — ignore errors if missing).
drop policy if exists "sessions_auth_insert_own" on public.sessions;
drop policy if exists "sessions_performer_update_own" on public.sessions;

-- Anon must be able to INSERT sessions (performer flow).
drop policy if exists "sessions_anon_insert" on public.sessions;
create policy "sessions_anon_insert"
on public.sessions
for insert
to anon
with check (true);

-- Anon must be able to UPDATE sessions to mark expired=true (createNewSession / toggle off).
-- Accomplice submit uses a separate restrictive policy; Postgres OR-combines policies.
drop policy if exists "sessions_anon_performer_update" on public.sessions;
create policy "sessions_anon_performer_update"
on public.sessions
for update
to anon
using (true)
with check (true);
