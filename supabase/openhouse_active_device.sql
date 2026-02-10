-- OpenHouse: Single-device lock per owner (only one device can use OpenHouse at a time)

create table if not exists public.openhouse_active_device (
  owner_id uuid primary key references auth.users(id) on delete cascade,
  device_id text not null,
  device_name text,
  last_seen timestamptz not null default now()
);

alter table public.openhouse_active_device enable row level security;

-- Only the owner can read their lock
create policy "openhouse_active_device_select_own"
  on public.openhouse_active_device
  for select
  using (auth.uid() = owner_id);

-- Only the owner can insert their lock
create policy "openhouse_active_device_insert_own"
  on public.openhouse_active_device
  for insert
  with check (auth.uid() = owner_id);

-- Only the owner can update their lock
create policy "openhouse_active_device_update_own"
  on public.openhouse_active_device
  for update
  using (auth.uid() = owner_id)
  with check (auth.uid() = owner_id);

-- Only the owner can delete their lock
create policy "openhouse_active_device_delete_own"
  on public.openhouse_active_device
  for delete
  using (auth.uid() = owner_id);

-- RPC: claim/takeover OpenHouse lock
-- Rules:
-- - Same device: refresh last_seen
-- - Different device: allow takeover only if force=true OR stale (last_seen older than stale_seconds)
create or replace function public.claim_openhouse_lock(
  p_device_id text,
  p_device_name text default null,
  p_force boolean default false,
  p_stale_seconds int default 120
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_owner uuid;
  v_existing record;
  v_stale_before timestamptz;
  v_status text;
begin
  v_owner := auth.uid();
  if v_owner is null then
    raise exception 'Not authenticated';
  end if;

  v_stale_before := now() - make_interval(secs => p_stale_seconds);

  select owner_id, device_id as existing_device_id, device_name as existing_device_name, last_seen
    into v_existing
  from public.openhouse_active_device
  where owner_id = v_owner;

  if not found then
    insert into public.openhouse_active_device (owner_id, device_id, device_name, last_seen)
    values (v_owner, p_device_id, p_device_name, now());

    v_status := 'claimed';
  else
    if v_existing.existing_device_id = p_device_id then
      update public.openhouse_active_device
        set device_name = coalesce(p_device_name, device_name),
            last_seen = now()
      where owner_id = v_owner;

      v_status := 'refreshed';
    else
      if p_force = true or v_existing.last_seen < v_stale_before then
        update public.openhouse_active_device
          set device_id = p_device_id,
              device_name = p_device_name,
              last_seen = now()
        where owner_id = v_owner;

        v_status := case when p_force then 'taken_over' else 'taken_over_stale' end;
      else
        v_status := 'in_use';
      end if;
    end if;
  end if;

  return jsonb_build_object(
    'status', v_status,
    'owner_id', v_owner,
    'device_id', p_device_id,
    'device_name', p_device_name,
    'existing_device_id', coalesce(v_existing.existing_device_id, null),
    'existing_device_name', coalesce(v_existing.existing_device_name, null),
    'existing_last_seen', coalesce(v_existing.last_seen, null)
  );
end;
$$;

-- Allow authenticated users to call the function
revoke all on function public.claim_openhouse_lock(text, text, boolean, int) from public;
grant execute on function public.claim_openhouse_lock(text, text, boolean, int) to authenticated;
