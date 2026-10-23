begin;
create extension if not exists pgtap with schema extensions;
set local search_path = public, extensions;
select plan(21);
set local role authenticated;
select set_config('request.jwt.claim.sub',
  '10000000-0000-0000-0000-000000000001', true);

select set_config('maestro.test.student', public.maestro_create_student(
  '{"firstName":"Local","familyName":"Workflow","courseDay":"MONDAY",
    "courseHour":"15:00","coursePrice":20}'::jsonb)::text, true);
select ok(current_setting('maestro.test.student')::bigint > 0,
  'teacher creates student with a first project and lesson');
select is((select count(*)::integer from public.students
  where app_id = current_setting('maestro.test.student')::bigint), 1,
  'new student is visible to its teacher');
select is((select count(*)::integer from public.lessons where student_id =
  (select id from public.students where app_id = current_setting('maestro.test.student')::bigint)),
  1, 'student creation includes first lesson');

select public.maestro_student_command('add_project',
  current_setting('maestro.test.student')::bigint, null, null,
  '{"name":"Second project"}'::jsonb);
select set_config('maestro.test.project', (select app_id::text from public.projects
  where student_id = (select id from public.students
    where app_id = current_setting('maestro.test.student')::bigint)
  and name = 'Second project'), true);
select ok(current_setting('maestro.test.project')::bigint > 0,
  'teacher creates a second project');
select public.maestro_student_command('add_piece',
  current_setting('maestro.test.student')::bigint,
  current_setting('maestro.test.project')::bigint, null,
  '{"title":"Etude"}'::jsonb);
select is((select count(*)::integer from public.pieces where title = 'Etude' and
  student_id = (select id from public.students where app_id =
    current_setting('maestro.test.student')::bigint)), 1,
  'teacher creates a piece');

select set_config('maestro.test.payment', public.maestro_record_payment(
  current_setting('maestro.test.student')::bigint,
  '{"amount":100,"paymentDate":"2026-10-22","method":"CASH"}'::jsonb,
  '11111111-1111-4111-8111-111111111111'::uuid)::text, true);
select is((select count(*)::integer from public.lessons where project_id =
  (select id from public.projects where app_id = current_setting('maestro.test.project')::bigint)),
  5, 'payment creates five lessons in the current empty project');
select is(public.maestro_record_payment(
  current_setting('maestro.test.student')::bigint,
  '{"amount":100}'::jsonb, '11111111-1111-4111-8111-111111111111'::uuid),
  current_setting('maestro.test.payment')::bigint,
  'same request key returns original payment');
select throws_ok(
  'select public.maestro_record_payment(current_setting(''maestro.test.student'')::bigint, ''{"amount":200}''::jsonb, ''11111111-1111-4111-8111-111111111111''::uuid)',
  '22023', 'Payment request key reused with a different amount',
  'request key cannot be reused for a different amount');
select is((select count(*)::integer from public.payments where student_id =
  (select id from public.students where app_id = current_setting('maestro.test.student')::bigint)),
  1, 'idempotent retry does not create another payment');

select set_config('maestro.test.first_lesson', (select app_id::text from public.lessons
  where project_id = (select id from public.projects
    where app_id = current_setting('maestro.test.project')::bigint)
  order by sort_order, app_id limit 1), true);
select set_config('maestro.test.second_lesson', (select app_id::text from public.lessons
  where project_id = (select id from public.projects
    where app_id = current_setting('maestro.test.project')::bigint)
  order by sort_order, app_id offset 1 limit 1), true);
select public.maestro_student_command('add_note',
  current_setting('maestro.test.student')::bigint,
  current_setting('maestro.test.project')::bigint,
  current_setting('maestro.test.first_lesson')::bigint,
  '{"piece":"Etude","comment":"Practice","reviewWeeks":1}'::jsonb);
select set_config('maestro.test.note', (select app_id::text from public.lesson_notes
  where lesson_id = (select id from public.lessons
    where app_id = current_setting('maestro.test.first_lesson')::bigint)
  order by app_id desc limit 1), true);
select ok((select target_lesson_id is not null from public.lesson_notes
  where app_id = current_setting('maestro.test.note')::bigint),
  'note targets the next lesson');
select public.maestro_student_command('update_lesson',
  current_setting('maestro.test.student')::bigint,
  current_setting('maestro.test.project')::bigint,
  current_setting('maestro.test.second_lesson')::bigint,
  jsonb_build_object('title','Course 2','day','TUESDAY',
    'date',(select lesson_date + 1 from public.lessons where app_id =
      current_setting('maestro.test.second_lesson')::bigint),
    'hour','16:00','price',20,'status','PRESENT',
    'assignment','Practice','comment','Attended','homeworkNextLesson','Etude'));
select is((select n.review_date from public.lesson_notes n where n.app_id =
  current_setting('maestro.test.note')::bigint),
  (select l.lesson_date from public.lessons l where l.id =
    (select target_lesson_id from public.lesson_notes where app_id =
      current_setting('maestro.test.note')::bigint)),
  'moving target lesson keeps review date aligned with the eligible target');
select public.maestro_student_command('accept_review',
  current_setting('maestro.test.student')::bigint, null,
  current_setting('maestro.test.note')::bigint,
  jsonb_build_object('courseId', current_setting('maestro.test.second_lesson')::bigint));
select is((select review_status from public.lesson_notes where app_id =
  current_setting('maestro.test.note')::bigint), 'ACCEPTED',
  'review can be marked accepted');
select public.maestro_student_command('add_note',
  current_setting('maestro.test.student')::bigint,
  current_setting('maestro.test.project')::bigint,
  current_setting('maestro.test.first_lesson')::bigint,
  '{"piece":"Etude","comment":"Again","reviewWeeks":1}'::jsonb);
select set_config('maestro.test.pending_note', (select app_id::text from public.lesson_notes
  where lesson_id = (select id from public.lessons where app_id =
    current_setting('maestro.test.first_lesson')::bigint)
  order by app_id desc limit 1), true);
select public.maestro_student_command('reschedule_review',
  current_setting('maestro.test.student')::bigint, null,
  current_setting('maestro.test.pending_note')::bigint,
  jsonb_build_object('courseId', current_setting('maestro.test.first_lesson')::bigint));
select ok((select review_history like '%Rescheduled' from public.lesson_notes
  where app_id = current_setting('maestro.test.pending_note')::bigint),
  'rescheduling records review history');
select public.maestro_student_command('update_piece',
  current_setting('maestro.test.student')::bigint,
  current_setting('maestro.test.project')::bigint, null,
  '{"pieceIndex":0,"title":"New Etude"}'::jsonb);
select is((select piece from public.lesson_notes where app_id =
  current_setting('maestro.test.note')::bigint), 'New Etude',
  'renaming a piece updates linked notes');
select public.maestro_student_command('delete_piece',
  current_setting('maestro.test.student')::bigint,
  current_setting('maestro.test.project')::bigint, null,
  '{"pieceIndex":0}'::jsonb);
select is((select piece from public.lesson_notes where app_id =
  current_setting('maestro.test.note')::bigint), '',
  'deleting a piece clears linked note text');
select public.maestro_student_command('delete_note',
  current_setting('maestro.test.student')::bigint,
  current_setting('maestro.test.project')::bigint,
  current_setting('maestro.test.first_lesson')::bigint,
  jsonb_build_object('noteId', current_setting('maestro.test.note')::bigint));
select is((select count(*)::integer from public.lesson_notes where app_id =
  current_setting('maestro.test.note')::bigint), 0,
  'teacher can delete own note');
select public.maestro_student_command('delete_lesson',
  current_setting('maestro.test.student')::bigint,
  current_setting('maestro.test.project')::bigint,
  (select app_id from public.lessons where project_id =
    (select id from public.projects where app_id =
      current_setting('maestro.test.project')::bigint)
    order by sort_order desc, app_id desc limit 1));
select is((select count(*)::integer from public.lessons where project_id =
  (select id from public.projects where app_id = current_setting('maestro.test.project')::bigint)),
  5, 'teacher can delete own lesson without deleting student or scheduled review course');

select set_config('maestro.test.review_student', public.maestro_create_student(
  '{"firstName":"Payment","familyName":"Review","courseDay":"FRIDAY",
    "courseHour":"15:00","coursePrice":20}'::jsonb)::text, true);
select set_config('maestro.test.review_project', (select app_id::text from public.projects
  where student_id = (select id from public.students where app_id =
    current_setting('maestro.test.review_student')::bigint)), true);
select set_config('maestro.test.review_lesson', (select app_id::text from public.lessons
  where student_id = (select id from public.students where app_id =
    current_setting('maestro.test.review_student')::bigint)), true);
select public.maestro_student_command('add_note',
  current_setting('maestro.test.review_student')::bigint,
  current_setting('maestro.test.review_project')::bigint,
  current_setting('maestro.test.review_lesson')::bigint,
  '{"piece":"Scale","reviewWeeks":1}'::jsonb);
select public.maestro_record_payment(
  current_setting('maestro.test.review_student')::bigint,
  '{"amount":40}'::jsonb, '22222222-2222-4222-8222-222222222222'::uuid);
select ok((select target_lesson_id is not null from public.lesson_notes where lesson_id =
  (select id from public.lessons where app_id =
    current_setting('maestro.test.review_lesson')::bigint)),
  'payment-created lesson resolves pending review target');
update public.teachers set studio_name = 'Local test studio' where user_id =
  '10000000-0000-0000-0000-000000000001'::uuid;
select is((select studio_name from public.teachers where user_id =
  '10000000-0000-0000-0000-000000000001'::uuid), 'Local test studio',
  'teacher settings update own profile under RLS');

select set_config('request.jwt.claim.sub',
  '10000000-0000-0000-0000-000000000002', true);
select is((select count(*)::integer from public.students
  where app_id = current_setting('maestro.test.student')::bigint), 0,
  'second teacher cannot read the new student');
select throws_ok(
  'select public.maestro_student_command(''add_project'', current_setting(''maestro.test.student'')::bigint)',
  '42501', 'Student access denied',
  'second teacher cannot mutate the new student');
rollback;
