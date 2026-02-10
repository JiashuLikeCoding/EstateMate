-- Email Template Settings (per user + workspace)

create table if not exists public.email_template_settings (
  id uuid primary key default gen_random_uuid(),
  created_by uuid not null default auth.uid(),
  workspace text not null default 'crm', -- crm|openhouse

  from_name text not null default '',

  footer_html text not null default '',
  footer_text text not null default '',

  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),

  constraint email_template_settings_unique unique (created_by, workspace)
);

create index if not exists email_template_settings_created_by_idx on public.email_template_settings(created_by);
create index if not exists email_template_settings_workspace_idx on public.email_template_settings(workspace);

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
    select 1 from pg_trigger where tgname = 'email_template_settings_set_updated_at'
  ) then
    create trigger email_template_settings_set_updated_at
    before update on public.email_template_settings
    for each row
    execute function public.set_updated_at_timestamp();
  end if;
end $$;

alter table public.email_template_settings enable row level security;

do $$
begin
  if not exists (select 1 from pg_policies where schemaname='public' and tablename='email_template_settings' and policyname='email_template_settings_select_own') then
    create policy email_template_settings_select_own
      on public.email_template_settings
      for select
      using (created_by = auth.uid());
  end if;

  if not exists (select 1 from pg_policies where schemaname='public' and tablename='email_template_settings' and policyname='email_template_settings_insert_own') then
    create policy email_template_settings_insert_own
      on public.email_template_settings
      for insert
      with check (created_by = auth.uid());
  end if;

  if not exists (select 1 from pg_policies where schemaname='public' and tablename='email_template_settings' and policyname='email_template_settings_update_own') then
    create policy email_template_settings_update_own
      on public.email_template_settings
      for update
      using (created_by = auth.uid())
      with check (created_by = auth.uid());
  end if;

  if not exists (select 1 from pg_policies where schemaname='public' and tablename='email_template_settings' and policyname='email_template_settings_delete_own') then
    create policy email_template_settings_delete_own
      on public.email_template_settings
      for delete
      using (created_by = auth.uid());
  end if;
end $$;
