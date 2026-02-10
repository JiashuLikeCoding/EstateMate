-- CRM Email Logs
-- Adds a simple manual email interaction log for contacts.

create table if not exists public.crm_email_logs (
  id uuid primary key default gen_random_uuid(),
  created_by uuid not null default auth.uid(),
  contact_id uuid not null references public.crm_contacts(id) on delete cascade,
  direction text not null default 'outbound', -- outbound|inbound
  subject text not null default '',
  body text not null default '',
  sent_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists crm_email_logs_created_by_idx on public.crm_email_logs(created_by);
create index if not exists crm_email_logs_contact_id_idx on public.crm_email_logs(contact_id);
create index if not exists crm_email_logs_sent_at_idx on public.crm_email_logs(sent_at desc);

-- updated_at trigger
create or replace function public.set_updated_at_timestamp()
returns trigger as $$
begin
  new.updated_at = now();
  return new;
end;
$$ language plpgsql;

do $$
begin
  if not exists (
    select 1
    from pg_trigger
    where tgname = 'crm_email_logs_set_updated_at'
  ) then
    create trigger crm_email_logs_set_updated_at
    before update on public.crm_email_logs
    for each row
    execute function public.set_updated_at_timestamp();
  end if;
end $$;

alter table public.crm_email_logs enable row level security;

-- Policies (idempotent)

do $$
begin
  if not exists (select 1 from pg_policies where schemaname='public' and tablename='crm_email_logs' and policyname='email_logs_select_own') then
    create policy email_logs_select_own
      on public.crm_email_logs
      for select
      using (created_by = auth.uid());
  end if;

  if not exists (select 1 from pg_policies where schemaname='public' and tablename='crm_email_logs' and policyname='email_logs_insert_own') then
    create policy email_logs_insert_own
      on public.crm_email_logs
      for insert
      with check (created_by = auth.uid());
  end if;

  if not exists (select 1 from pg_policies where schemaname='public' and tablename='crm_email_logs' and policyname='email_logs_update_own') then
    create policy email_logs_update_own
      on public.crm_email_logs
      for update
      using (created_by = auth.uid())
      with check (created_by = auth.uid());
  end if;

  if not exists (select 1 from pg_policies where schemaname='public' and tablename='crm_email_logs' and policyname='email_logs_delete_own') then
    create policy email_logs_delete_own
      on public.crm_email_logs
      for delete
      using (created_by = auth.uid());
  end if;
end $$;
