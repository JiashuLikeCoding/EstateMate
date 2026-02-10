-- EstateMate: CRM migration v2 (add stage/source/last_contacted_at)
-- Run this in Supabase Dashboard -> SQL Editor.

alter table public.crm_contacts
  add column if not exists stage text not null default '新线索';

alter table public.crm_contacts
  add column if not exists source text not null default '手动';

alter table public.crm_contacts
  add column if not exists last_contacted_at timestamptz null;

-- Optional: simple indexes for list/sort
create index if not exists crm_contacts_updated_at_idx on public.crm_contacts(updated_at desc);
create index if not exists crm_contacts_stage_idx on public.crm_contacts(stage);
