-- OpenHouse tags preset library

create table if not exists public.openhouse_tags (
  id uuid primary key default gen_random_uuid(),
  owner_id uuid not null default auth.uid(),
  name text not null,
  created_at timestamptz not null default now(),
  unique(owner_id, name)
);

alter table public.openhouse_tags enable row level security;

-- Policies
-- Read own tags
DO $$
BEGIN
  IF EXISTS (
    SELECT 1 FROM pg_policies
    WHERE schemaname='public' AND tablename='openhouse_tags' AND policyname='openhouse_tags_select_own'
  ) THEN
    EXECUTE 'drop policy "openhouse_tags_select_own" on public.openhouse_tags';
  END IF;
END $$;

create policy "openhouse_tags_select_own" on public.openhouse_tags
for select to authenticated
using (owner_id = auth.uid());

-- Insert own tags
DO $$
BEGIN
  IF EXISTS (
    SELECT 1 FROM pg_policies
    WHERE schemaname='public' AND tablename='openhouse_tags' AND policyname='openhouse_tags_insert_own'
  ) THEN
    EXECUTE 'drop policy "openhouse_tags_insert_own" on public.openhouse_tags';
  END IF;
END $$;

create policy "openhouse_tags_insert_own" on public.openhouse_tags
for insert to authenticated
with check (owner_id = auth.uid());

-- Delete own tags (optional)
DO $$
BEGIN
  IF EXISTS (
    SELECT 1 FROM pg_policies
    WHERE schemaname='public' AND tablename='openhouse_tags' AND policyname='openhouse_tags_delete_own'
  ) THEN
    EXECUTE 'drop policy "openhouse_tags_delete_own" on public.openhouse_tags';
  END IF;
END $$;

create policy "openhouse_tags_delete_own" on public.openhouse_tags
for delete to authenticated
using (owner_id = auth.uid());
