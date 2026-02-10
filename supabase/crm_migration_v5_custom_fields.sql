-- v5: CRM custom fields table for OpenHouse submissions

begin;

create extension if not exists pgcrypto;

create table if not exists public.crm_contact_custom_fields (
  id uuid primary key default gen_random_uuid(),
  created_by uuid not null default auth.uid(),
  contact_id uuid not null references public.crm_contacts(id) on delete cascade,
  event_id uuid null references public.openhouse_events(id) on delete set null,
  submission_id uuid null references public.openhouse_submissions(id) on delete cascade,

  event_title text not null default '',
  event_location text not null default '',
  submitted_at timestamptz null,

  field_key text not null,
  field_label text not null default '',
  value_text text not null default '',

  created_at timestamptz not null default now()
);

create unique index if not exists crm_contact_custom_fields_unique
  on public.crm_contact_custom_fields (contact_id, submission_id, field_key);

alter table public.crm_contact_custom_fields enable row level security;

drop policy if exists "crm_contact_custom_fields_select_own" on public.crm_contact_custom_fields;
create policy "crm_contact_custom_fields_select_own"
  on public.crm_contact_custom_fields
  for select
  using (auth.uid() = created_by);

drop policy if exists "crm_contact_custom_fields_insert_own" on public.crm_contact_custom_fields;
create policy "crm_contact_custom_fields_insert_own"
  on public.crm_contact_custom_fields
  for insert
  with check (auth.uid() = created_by);

drop policy if exists "crm_contact_custom_fields_update_own" on public.crm_contact_custom_fields;
create policy "crm_contact_custom_fields_update_own"
  on public.crm_contact_custom_fields
  for update
  using (auth.uid() = created_by)
  with check (auth.uid() = created_by);

drop policy if exists "crm_contact_custom_fields_delete_own" on public.crm_contact_custom_fields;
create policy "crm_contact_custom_fields_delete_own"
  on public.crm_contact_custom_fields
  for delete
  using (auth.uid() = created_by);

commit;
