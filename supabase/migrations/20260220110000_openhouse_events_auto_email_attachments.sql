-- Add per-event auto-reply attachments (stored in Supabase Storage bucket: email_attachments)
-- This moves attachments away from email_templates and into openhouse_events.

alter table public.openhouse_events
add column if not exists auto_email_attachments jsonb not null default '[]'::jsonb;
