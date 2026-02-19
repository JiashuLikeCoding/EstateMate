-- Update: shared OpenHouse template should use {{firstname}}/{{lastname}} (no underscore)

update public.email_templates
set
  subject = replace(replace(subject, '{{first_name}}', '{{firstname}}'), '{{last_name}}', '{{lastname}}'),
  body = replace(replace(body, '{{first_name}}', '{{firstname}}'), '{{last_name}}', '{{lastname}}'),
  updated_at = now()
where workspace = 'openhouse'
  and name = 'Open House模版'
  and is_archived = false;
