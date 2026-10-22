begin;
create extension if not exists pgtap with schema extensions;
set local search_path = public, extensions;
select plan(14);

select ok(c.relrowsecurity, 'RLS enabled on public.' || names.table_name)
from (values
  ('profiles'), ('teachers'), ('students'), ('teacher_students'),
  ('parent_students'), ('projects'), ('lessons'), ('pieces'),
  ('lesson_notes'), ('payments'), ('legacy_id_map')
) as names(table_name)
join pg_class c on c.oid = ('public.' || names.table_name)::regclass;

select is((select b.public from storage.buckets b where b.id = 'maestro-private'),
  false, 'media bucket is private');
select ok(exists (select 1 from pg_publication_tables
  where pubname = 'supabase_realtime' and schemaname = 'public' and tablename = 'lessons'),
  'lessons enabled for Realtime');
select ok(exists (select 1 from pg_publication_tables
  where pubname = 'supabase_realtime' and schemaname = 'public' and tablename = 'lesson_notes'),
  'lesson notes enabled for Realtime');

select * from finish();
rollback;
