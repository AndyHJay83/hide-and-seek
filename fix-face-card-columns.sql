-- Run in Supabase SQL Editor.
-- Removes face card columns from sessions (no longer used).

alter table public.sessions drop constraint if exists sessions_face_suit_chk;
alter table public.sessions drop constraint if exists sessions_face_value_chk;
alter table public.sessions drop column if exists face_suit;
alter table public.sessions drop column if exists face_value;
alter table public.sessions drop column if exists force_face_card;
