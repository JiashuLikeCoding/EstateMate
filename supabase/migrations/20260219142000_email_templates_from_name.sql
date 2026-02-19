-- Add per-template sender display name (From name)
-- This is optional; when empty, we fall back to email_template_settings.from_name and then env/default.

alter table public.email_templates
add column if not exists from_name text;
