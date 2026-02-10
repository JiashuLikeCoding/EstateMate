-- EstateMate: CRM migration v4 (address)
-- Run this in Supabase Dashboard -> SQL Editor.

alter table public.crm_contacts
add column if not exists address text not null default '';
