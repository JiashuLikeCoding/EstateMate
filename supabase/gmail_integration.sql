-- Gmail Integration (tokens stored server-side; clients only see connected status)
--
-- Apply this migration in Supabase SQL editor.

create table if not exists public.gmail_connections (
  user_id uuid primary key references auth.users(id) on delete cascade,
  email text,
  refresh_token text not null,
  scope text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

-- Keep updated_at fresh
create or replace function public.set_updated_at() returns trigger as $$
begin
  new.updated_at = now();
  return new;
end;
$$ language plpgsql;

drop trigger if exists gmail_connections_set_updated_at on public.gmail_connections;
create trigger gmail_connections_set_updated_at
before update on public.gmail_connections
for each row execute function public.set_updated_at();

alter table public.gmail_connections enable row level security;

-- No client policies on purpose.
-- Access is only via Edge Functions using the service role key.
