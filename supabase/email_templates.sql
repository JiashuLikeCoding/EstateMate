-- Email Templates (shared by OpenHouse + CRM)

create table if not exists public.email_templates (
  id uuid primary key default gen_random_uuid(),
  created_by uuid not null default auth.uid(),
  workspace text not null default 'crm', -- crm|openhouse
  name text not null default '',
  subject text not null default '',
  body text not null default '',
  variables jsonb not null default '[]'::jsonb,
  is_archived boolean not null default false,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists email_templates_created_by_idx on public.email_templates(created_by);
create index if not exists email_templates_workspace_idx on public.email_templates(workspace);
create index if not exists email_templates_is_archived_idx on public.email_templates(is_archived);
create index if not exists email_templates_updated_at_idx on public.email_templates(updated_at desc);

-- updated_at trigger (reuses set_updated_at_timestamp if exists)
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
    where tgname = 'email_templates_set_updated_at'
  ) then
    create trigger email_templates_set_updated_at
    before update on public.email_templates
    for each row
    execute function public.set_updated_at_timestamp();
  end if;
end $$;

alter table public.email_templates enable row level security;

-- Policies (idempotent)

do $$
begin
  if not exists (select 1 from pg_policies where schemaname='public' and tablename='email_templates' and policyname='email_templates_select_own') then
    create policy email_templates_select_own
      on public.email_templates
      for select
      using (created_by = auth.uid());
  end if;

  if not exists (select 1 from pg_policies where schemaname='public' and tablename='email_templates' and policyname='email_templates_insert_own') then
    create policy email_templates_insert_own
      on public.email_templates
      for insert
      with check (created_by = auth.uid());
  end if;

  if not exists (select 1 from pg_policies where schemaname='public' and tablename='email_templates' and policyname='email_templates_update_own') then
    create policy email_templates_update_own
      on public.email_templates
      for update
      using (created_by = auth.uid())
      with check (created_by = auth.uid());
  end if;

  if not exists (select 1 from pg_policies where schemaname='public' and tablename='email_templates' and policyname='email_templates_delete_own') then
    create policy email_templates_delete_own
      on public.email_templates
      for delete
      using (created_by = auth.uid());
  end if;
end $$;
