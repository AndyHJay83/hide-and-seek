-- Run in Supabase SQL Editor.
-- Migrates existing profiles from 'stebbins' to 'mnemonica' stack type.

UPDATE public.profiles SET stack_type = 'mnemonica' WHERE stack_type = 'stebbins';

ALTER TABLE public.profiles ALTER COLUMN stack_type SET DEFAULT 'mnemonica';

ALTER TABLE public.profiles DROP CONSTRAINT IF EXISTS profiles_stack_type_chk;
ALTER TABLE public.profiles
  ADD CONSTRAINT profiles_stack_type_chk
  CHECK (stack_type IN ('mnemonica', 'custom'));
