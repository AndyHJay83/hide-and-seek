-- Short accomplice link tokens (e.g. /a/X7k9mP2aB3 instead of ?s=<uuid>).
-- Run in Supabase SQL Editor after supabase-setup.sql.

alter table public.sessions
  add column if not exists link_token text;

create unique index if not exists sessions_link_token_key
  on public.sessions (link_token)
  where link_token is not null;
