begin;
create extension if not exists pgtap with schema extensions;
set local search_path = public, extensions;
select plan(3);

set local role authenticated;
select set_config('request.jwt.claim.sub',
  '10000000-0000-0000-0000-000000000001', true);
select public.maestro_update_student_instrument(12, 'Bassoon');
select is((select instrument from public.students where app_id = 12),
  'Bassoon', 'assigned teacher can save a custom instrument');

select set_config('request.jwt.claim.sub',
  '10000000-0000-0000-0000-000000000002', true);
select throws_ok(
  'select public.maestro_update_student_instrument(12, ''Clarinet'')',
  '42501', 'Student access denied',
  'another teacher cannot edit the student');

select set_config('request.jwt.claim.sub',
  '10000000-0000-0000-0000-000000000011', true);
select throws_ok(
  'select public.maestro_update_student_instrument(12, ''Clarinet'')',
  '42501', 'Student access denied',
  'student account cannot edit the teacher record');

select * from finish();
rollback;
