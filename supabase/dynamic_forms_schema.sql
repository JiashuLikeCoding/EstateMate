-- EstateMate: Dynamic Forms (text/phone/email/select)
-- Run in Supabase Dashboard -> SQL Editor.
-- This replaces the fixed-column submissions approach with JSON schema/data.

-- 1) Forms: user-defined schemas
create table if not exists public.forms (
  id uuid primary key default gen_random_uuid(),
  owner_id uuid not null default auth.uid(),
  name text not null,
  schema jsonb not null,
  created_at timestamptz not null default now()
);

-- 2) OpenHouse events: each event selects one form
create table if not exists public.openhouse_events (
  id uuid primary key default gen_random_uuid(),
  owner_id uuid not null default auth.uid(),
  title text not null,
  form_id uuid not null references public.forms(id) on delete restrict,
  is_active boolean not null default false,
  created_at timestamptz not null default now()
);

-- 3) Submissions: JSON payload per submission
create table if not exists public.openhouse_submissions (
  id uuid primary key default gen_random_uuid(),
  event_id uuid not null references public.openhouse_events(id) on delete cascade,
  owner_id uuid not null,
  data jsonb not null,
  created_at timestamptz not null default now(),
  constraint openhouse_submissions_owner_fk
    foreign key (owner_id) references auth.users(id) on delete cascade
);

alter table public.forms enable row level security;
alter table public.openhouse_events enable row level security;
alter table public.openhouse_submissions enable row level security;

-- FORMS: authenticated user can manage their own
create policy if not exists forms_select_own
on public.forms for select
to authenticated
using (owner_id = auth.uid());

create policy if not exists forms_insert_own
on public.forms for insert
to authenticated
with check (owner_id = auth.uid());

create policy if not exists forms_update_own
on public.forms for update
to authenticated
using (owner_id = auth.uid())
with check (owner_id = auth.uid());

-- EVENTS: authenticated user can manage their own
create policy if not exists events_select_own_v2
on public.openhouse_events for select
to authenticated
using (owner_id = auth.uid());

create policy if not exists events_insert_own_v2
on public.openhouse_events for insert
to authenticated
with check (owner_id = auth.uid());

create policy if not exists events_update_own_v2
on public.openhouse_events for update
to authenticated
using (owner_id = auth.uid())
with check (owner_id = auth.uid());

-- SUBMISSIONS: kiosk runs under logged-in user; enforce owner_id = auth.uid()
create policy if not exists subs_select_own_v2
on public.openhouse_submissions for select
to authenticated
using (owner_id = auth.uid());

create policy if not exists subs_insert_own_v2
on public.openhouse_submissions for insert
to authenticated
with check (owner_id = auth.uid());

-- Optional: keep owner_id in sync with event.owner_id
create or replace function public.set_submission_owner_id()
returns trigger
language plpgsql
security definer
as $$
begin
  select owner_id into new.owner_id from public.openhouse_events where id = new.event_id;
  if new.owner_id is null then
    raise exception 'Invalid event_id';
  end if;
  return new;
end;
$$;

drop trigger if exists trg_set_submission_owner_id on public.openhouse_submissions;
create trigger trg_set_submission_owner_id
before insert on public.openhouse_submissions
for each row
execute function public.set_submission_owner_id();
