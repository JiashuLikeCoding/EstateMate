-- Add archived timestamp for forms.
-- This supports displaying archive time in the app.

alter table public.forms
add column if not exists archived_at timestamptz;

-- Best-effort backfill: existing archived rows get a placeholder archive time.
update public.forms
set archived_at = coalesce(archived_at, now())
where is_archived = true;

create index if not exists forms_archived_at_idx on public.forms (archived_at);
