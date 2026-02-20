-- Form custom background images (Storage)

-- Storage bucket for OpenHouse form backgrounds (public)
insert into storage.buckets (id, name, public)
values ('openhouse_form_backgrounds', 'openhouse_form_backgrounds', true)
on conflict (id) do update set public = excluded.public;

-- Storage policies
-- - uploads happen from authenticated app session
-- - reads are public (bucket is public), but we also allow select for both anon/auth to be safe

do $$
begin
  -- SELECT (anon)
  if not exists (
    select 1 from pg_policies where schemaname = 'storage' and tablename = 'objects' and policyname = 'Form backgrounds: anon can read'
  ) then
    create policy "Form backgrounds: anon can read"
      on storage.objects for select
      to anon
      using (bucket_id = 'openhouse_form_backgrounds');
  end if;

  -- SELECT (authenticated)
  if not exists (
    select 1 from pg_policies where schemaname = 'storage' and tablename = 'objects' and policyname = 'Form backgrounds: authenticated can read'
  ) then
    create policy "Form backgrounds: authenticated can read"
      on storage.objects for select
      to authenticated
      using (bucket_id = 'openhouse_form_backgrounds');
  end if;

  -- INSERT
  if not exists (
    select 1 from pg_policies where schemaname = 'storage' and tablename = 'objects' and policyname = 'Form backgrounds: authenticated can upload'
  ) then
    create policy "Form backgrounds: authenticated can upload"
      on storage.objects for insert
      to authenticated
      with check (bucket_id = 'openhouse_form_backgrounds');
  end if;

  -- UPDATE
  if not exists (
    select 1 from pg_policies where schemaname = 'storage' and tablename = 'objects' and policyname = 'Form backgrounds: authenticated can update'
  ) then
    create policy "Form backgrounds: authenticated can update"
      on storage.objects for update
      to authenticated
      using (bucket_id = 'openhouse_form_backgrounds')
      with check (bucket_id = 'openhouse_form_backgrounds');
  end if;

  -- DELETE
  if not exists (
    select 1 from pg_policies where schemaname = 'storage' and tablename = 'objects' and policyname = 'Form backgrounds: authenticated can delete'
  ) then
    create policy "Form backgrounds: authenticated can delete"
      on storage.objects for delete
      to authenticated
      using (bucket_id = 'openhouse_form_backgrounds');
  end if;
end $$;
