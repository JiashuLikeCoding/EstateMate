-- EstateMate: OpenHouse events bind email templates
-- Run this in Supabase Dashboard -> SQL Editor.

alter table public.openhouse_events
  add column if not exists email_template_id uuid;

do $$
begin
  if not exists (
    select 1
    from pg_constraint
    where conname = 'openhouse_events_email_template_id_fkey'
  ) then
    alter table public.openhouse_events
      add constraint openhouse_events_email_template_id_fkey
      foreign key (email_template_id)
      references public.email_templates(id)
      on delete set null;
  end if;
end $$;

create index if not exists idx_openhouse_events_email_template_id
  on public.openhouse_events(email_template_id);
