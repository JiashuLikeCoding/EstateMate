-- OpenHouse Auto Emails (for dedup + status tracking of server-sent emails)

create table if not exists public.openhouse_auto_emails (
  id uuid primary key default gen_random_uuid(),
  created_by uuid not null default auth.uid(),
  submission_id uuid not null,
  provider text not null default 'gmail',
  status text not null default 'sending', -- sending|sent|failed
  to_email text not null default '',
  from_email text,
  subject text not null default '',
  body_text text not null default '',
  body_html text,
  provider_message_id text,
  error_message text,
  sent_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create unique index if not exists openhouse_auto_emails_dedup_idx
  on public.openhouse_auto_emails(created_by, submission_id);

create index if not exists openhouse_auto_emails_created_by_idx
  on public.openhouse_auto_emails(created_by);

create index if not exists openhouse_auto_emails_submission_id_idx
  on public.openhouse_auto_emails(submission_id);

create index if not exists openhouse_auto_emails_sent_at_idx
  on public.openhouse_auto_emails(sent_at desc);

-- updated_at trigger (reuse existing helper if present)
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
    where tgname = 'openhouse_auto_emails_set_updated_at'
  ) then
    create trigger openhouse_auto_emails_set_updated_at
    before update on public.openhouse_auto_emails
    for each row
    execute function public.set_updated_at_timestamp();
  end if;
end $$;

alter table public.openhouse_auto_emails enable row level security;

-- Policies (idempotent)

do $$
begin
  if not exists (select 1 from pg_policies where schemaname='public' and tablename='openhouse_auto_emails' and policyname='openhouse_auto_emails_select_own') then
    create policy openhouse_auto_emails_select_own
      on public.openhouse_auto_emails
      for select
      using (created_by = auth.uid());
  end if;

  if not exists (select 1 from pg_policies where schemaname='public' and tablename='openhouse_auto_emails' and policyname='openhouse_auto_emails_insert_own') then
    create policy openhouse_auto_emails_insert_own
      on public.openhouse_auto_emails
      for insert
      with check (created_by = auth.uid());
  end if;

  if not exists (select 1 from pg_policies where schemaname='public' and tablename='openhouse_auto_emails' and policyname='openhouse_auto_emails_update_own') then
    create policy openhouse_auto_emails_update_own
      on public.openhouse_auto_emails
      for update
      using (created_by = auth.uid())
      with check (created_by = auth.uid());
  end if;

  if not exists (select 1 from pg_policies where schemaname='public' and tablename='openhouse_auto_emails' and policyname='openhouse_auto_emails_delete_own') then
    create policy openhouse_auto_emails_delete_own
      on public.openhouse_auto_emails
      for delete
      using (created_by = auth.uid());
  end if;
end $$;
