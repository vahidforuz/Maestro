-- Supabase installs pgcrypto in extensions, outside pg_catalog.
alter function public.maestro_create_availability_link(timestamptz,date,date)
  set search_path = pg_catalog, extensions;
