-- EstateMate: CRM migration v3 (unique keys: email/phone)
-- Run this in Supabase Dashboard -> SQL Editor.
--
-- Assumptions:
-- - email stored normalized (lowercase, trimmed)
-- - phone stored trimmed

-- Avoid empty strings being treated as a real unique value
-- (keeps existing NOT NULL schema; app should store '' when unknown)

create unique index if not exists crm_contacts_unique_email_per_user
on public.crm_contacts (created_by, email)
where email <> '';

create unique index if not exists crm_contacts_unique_phone_per_user
on public.crm_contacts (created_by, phone)
where phone <> '';
