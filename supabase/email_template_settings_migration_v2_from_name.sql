-- Migration v2: add from_name to email_template_settings

alter table public.email_template_settings
  add column if not exists from_name text not null default '';
