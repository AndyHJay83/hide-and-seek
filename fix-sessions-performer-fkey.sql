-- Run in Supabase SQL Editor.
-- Fixes: insert or update on table "sessions" violates foreign key constraint "sessions_performer_id_fkey"
--
-- This app logs in by email and sets performer_id = public.profiles.id.
-- If sessions.performer_id was created to reference auth.users(id) instead, inserts fail
-- whenever profiles.id is not the same row as an auth user (common for email-only / anon flows).
--
-- This migration repoints the FK to public.profiles(id), matching supabase-setup.sql.

alter table public.sessions drop constraint if exists sessions_performer_id_fkey;

-- Drop rows that no longer match any profile (stale ids after schema changes).
delete from public.sessions s
where not exists (select 1 from public.profiles p where p.id = s.performer_id);

alter table public.sessions
  add constraint sessions_performer_id_fkey
  foreign key (performer_id) references public.profiles(id) on delete cascade;
