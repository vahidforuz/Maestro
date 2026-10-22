begin;
create extension if not exists pgtap with schema extensions;
set local search_path = public, extensions;
select plan(3);
select ok(has_column_privilege('authenticated', 'public.teachers',
  'studio_name', 'UPDATE'), 'teacher can edit own studio setting');
select ok(not has_column_privilege('authenticated', 'public.teachers',
  'app_id', 'UPDATE'), 'teacher cannot change app identity');
select ok(not has_column_privilege('authenticated', 'public.teachers',
  'user_id', 'UPDATE'), 'teacher cannot change Auth ownership');
rollback;
