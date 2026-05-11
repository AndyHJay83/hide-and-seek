-- Run in Supabase SQL Editor.
-- Adds face card columns to sessions so the accomplice can optionally transmit the face card.

alter table public.sessions
  add column if not exists face_suit integer,
  add column if not exists face_value integer,
  add column if not exists force_face_card boolean not null default true;

alter table public.sessions drop constraint if exists sessions_face_suit_chk;
alter table public.sessions
  add constraint sessions_face_suit_chk check (face_suit between 0 and 3 or face_suit is null);

alter table public.sessions drop constraint if exists sessions_face_value_chk;
alter table public.sessions
  add constraint sessions_face_value_chk check (face_value between 0 and 12 or face_value is null);
