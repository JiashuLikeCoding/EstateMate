-- Email template attachments (PDF etc)

alter table public.email_templates
add column if not exists attachments jsonb not null default '[]'::jsonb;

-- Storage bucket for email attachments (private)
insert into storage.buckets (id, name, public)
values ('email_attachments', 'email_attachments', false)
on conflict (id) do update set public = excluded.public;

-- Storage policies: single-user app, allow authenticated users to manage attachments.
-- Note: storage.objects has RLS enabled in Supabase.

do $$
begin
  -- SELECT
  if not exists (
    select 1 from pg_policies where schemaname = 'storage' and tablename = 'objects' and policyname = 'Email attachments: authenticated can read'
  ) then
    create policy "Email attachments: authenticated can read"
      on storage.objects for select
      to authenticated
      using (bucket_id = 'email_attachments');
  end if;

  -- INSERT
  if not exists (
    select 1 from pg_policies where schemaname = 'storage' and tablename = 'objects' and policyname = 'Email attachments: authenticated can upload'
  ) then
    create policy "Email attachments: authenticated can upload"
      on storage.objects for insert
      to authenticated
      with check (bucket_id = 'email_attachments');
  end if;

  -- UPDATE
  if not exists (
    select 1 from pg_policies where schemaname = 'storage' and tablename = 'objects' and policyname = 'Email attachments: authenticated can update'
  ) then
    create policy "Email attachments: authenticated can update"
      on storage.objects for update
      to authenticated
      using (bucket_id = 'email_attachments')
      with check (bucket_id = 'email_attachments');
  end if;

  -- DELETE
  if not exists (
    select 1 from pg_policies where schemaname = 'storage' and tablename = 'objects' and policyname = 'Email attachments: authenticated can delete'
  ) then
    create policy "Email attachments: authenticated can delete"
      on storage.objects for delete
      to authenticated
      using (bucket_id = 'email_attachments');
  end if;
end $$;
