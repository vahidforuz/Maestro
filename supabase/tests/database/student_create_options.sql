begin;
create extension if not exists pgtap with schema extensions;
set local search_path = public, extensions;
select plan(3);

set local role authenticated;
select set_config('request.jwt.claim.sub',
  '10000000-0000-0000-0000-000000000001', true);
select set_config('maestro.test.created_id',
  public.maestro_create_student(jsonb_build_object(
    'firstName', 'New', 'familyName', 'Student', 'instrument', 'Oboe',
    'courseDay', 'MONDAY', 'courseHour', '17:30', 'coursePrice', 0
  ))::text, true);
select is((select instrument from public.students
  where app_id = current_setting('maestro.test.created_id')::bigint),
  'Oboe', 'custom instrument persists on creation');
select is((select course_hour::text from public.students
  where app_id = current_setting('maestro.test.created_id')::bigint),
  '17:30:00', 'picked time persists in the existing SQL time column');

select set_config('request.jwt.claim.sub',
  '10000000-0000-0000-0000-000000000002', true);
select is((select count(*)::integer from public.students
  where app_id = current_setting('maestro.test.created_id')::bigint),
  0, 'another teacher cannot see the new student');

select * from finish();
rollback;
