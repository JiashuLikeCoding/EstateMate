-- EstateMate: CRM Tasks (MVP)
-- Run this in Supabase Dashboard -> SQL Editor.

create table if not exists public.crm_tasks (
  id uuid primary key default gen_random_uuid(),
  contact_id uuid null references public.crm_contacts(id) on delete set null,
  title text not null default '',
  notes text not null default '',
  due_at timestamptz null,
  is_done boolean not null default false,

  created_by uuid not null default auth.uid(),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

drop trigger if exists trg_crm_tasks_updated_at on public.crm_tasks;
create trigger trg_crm_tasks_updated_at
before update on public.crm_tasks
for each row
execute function public.set_updated_at();

alter table public.crm_tasks enable row level security;

create policy if not exists crm_tasks_select_own
on public.crm_tasks for select
to authenticated
using (created_by = auth.uid());

create policy if not exists crm_tasks_insert_own
on public.crm_tasks for insert
to authenticated
with check (created_by = auth.uid());

create policy if not exists crm_tasks_update_own
on public.crm_tasks for update
to authenticated
using (created_by = auth.uid())
with check (created_by = auth.uid());

create policy if not exists crm_tasks_delete_own
on public.crm_tasks for delete
to authenticated
using (created_by = auth.uid());

create index if not exists crm_tasks_due_at_idx on public.crm_tasks(due_at);
create index if not exists crm_tasks_is_done_idx on public.crm_tasks(is_done);
create index if not exists crm_tasks_contact_id_idx on public.crm_tasks(contact_id);
