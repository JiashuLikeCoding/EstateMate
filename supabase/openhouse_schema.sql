-- EstateMate: OpenHouse Kiosk (MVP)
-- Run this in Supabase Dashboard -> SQL Editor.

create table if not exists public.openhouse_events (
  id uuid primary key default gen_random_uuid(),
  title text not null,
  is_active boolean not null default false,
  created_by uuid not null default auth.uid(),
  created_at timestamptz not null default now()
);

create table if not exists public.openhouse_submissions (
  id uuid primary key default gen_random_uuid(),
  event_id uuid not null references public.openhouse_events(id) on delete cascade,
  full_name text not null,
  phone text not null default '',
  email text not null default '',
  notes text not null default '',
  created_by uuid not null default auth.uid(),
  created_at timestamptz not null default now()
);

alter table public.openhouse_events enable row level security;
alter table public.openhouse_submissions enable row level security;

-- EVENTS: authenticated users can manage their own events
create policy if not exists events_select_own
on public.openhouse_events for select
to authenticated
using (created_by = auth.uid());

create policy if not exists events_insert_own
on public.openhouse_events for insert
to authenticated
with check (created_by = auth.uid());

create policy if not exists events_update_own
on public.openhouse_events for update
to authenticated
using (created_by = auth.uid())
with check (created_by = auth.uid());

-- SUBMISSIONS: kiosk runs under the logged-in user's session
create policy if not exists subs_select_own
on public.openhouse_submissions for select
to authenticated
using (created_by = auth.uid());

create policy if not exists subs_insert_own
on public.openhouse_submissions for insert
to authenticated
with check (created_by = auth.uid());
