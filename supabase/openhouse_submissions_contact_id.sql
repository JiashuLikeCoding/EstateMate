-- Link OpenHouse submissions to CRM contacts (optional)

alter table public.openhouse_submissions
  add column if not exists contact_id uuid references public.crm_contacts(id) on delete set null;

create index if not exists openhouse_submissions_contact_id_idx on public.openhouse_submissions(contact_id);
