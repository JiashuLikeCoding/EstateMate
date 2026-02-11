-- EstateMate: Forms archive support
-- Run in Supabase Dashboard -> SQL Editor.

alter table public.forms
  add column if not exists is_archived boolean not null default false;

-- Optional index for faster list queries.
create index if not exists forms_owner_archived_created_at_idx
  on public.forms (owner_id, is_archived, created_at desc);

-- NOTE: We intentionally do NOT add DELETE policy; we archive instead.
