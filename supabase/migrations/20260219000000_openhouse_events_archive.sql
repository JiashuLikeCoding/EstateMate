-- Add soft-archive for openhouse events
alter table public.openhouse_events
add column if not exists is_archived boolean not null default false;

create index if not exists openhouse_events_owner_archived_idx
on public.openhouse_events (owner_id, is_archived, created_at desc);
