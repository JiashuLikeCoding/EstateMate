-- EstateMate: CRM (MVP)
-- Run this in Supabase Dashboard -> SQL Editor.

create table if not exists public.crm_contacts (
  id uuid primary key default gen_random_uuid(),
  full_name text not null default '',
  phone text not null default '',
  email text not null default '',
  notes text not null default '',
  tags text[] null,

  created_by uuid not null default auth.uid(),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create or replace function public.set_updated_at()
returns trigger
language plpgsql
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

drop trigger if exists trg_crm_contacts_updated_at on public.crm_contacts;
create trigger trg_crm_contacts_updated_at
before update on public.crm_contacts
for each row
execute function public.set_updated_at();

alter table public.crm_contacts enable row level security;

-- CONTACTS: authenticated users can manage their own contacts
create policy if not exists crm_contacts_select_own
on public.crm_contacts for select
to authenticated
using (created_by = auth.uid());

create policy if not exists crm_contacts_insert_own
on public.crm_contacts for insert
to authenticated
with check (created_by = auth.uid());

create policy if not exists crm_contacts_update_own
on public.crm_contacts for update
to authenticated
using (created_by = auth.uid())
with check (created_by = auth.uid());

create policy if not exists crm_contacts_delete_own
on public.crm_contacts for delete
to authenticated
using (created_by = auth.uid());
