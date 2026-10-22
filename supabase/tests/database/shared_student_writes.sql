begin;
create extension if not exists pgtap with schema extensions;
set local search_path = public, extensions;
select plan(3);
set local role authenticated;
select set_config('request.jwt.claim.sub',
  '10000000-0000-0000-0000-000000000001', true);
select public.maestro_student_command('add_piece', 15, 105, null,
  '{"title":"Shared test piece"}'::jsonb);
select set_config('maestro.test.piece_index', (select (count(*) - 1)::text from
  public.pieces where project_id = (select id from public.projects where app_id = 105)), true);
select public.maestro_student_command('add_lesson', 15, 105);
select set_config('maestro.test.ada_lesson', (select max(app_id)::text from
  public.lessons where teacher_id = (select id from public.teachers where user_id =
    '10000000-0000-0000-0000-000000000001'::uuid)
  and student_id = (select id from public.students where app_id = 15)), true);
select public.maestro_student_command('add_note', 15, 105,
  current_setting('maestro.test.ada_lesson')::bigint,
  '{"piece":"Shared test piece","comment":"Ada private"}'::jsonb);
select set_config('maestro.test.ada_note', (select max(app_id)::text from
  public.lesson_notes where lesson_id = (select id from public.lessons where
    app_id = current_setting('maestro.test.ada_lesson')::bigint)), true);

select set_config('request.jwt.claim.sub',
  '10000000-0000-0000-0000-000000000002', true);
select public.maestro_student_command('add_lesson', 15, 105);
select set_config('maestro.test.ben_lesson', (select max(app_id)::text from
  public.lessons where teacher_id = (select id from public.teachers where user_id =
    '10000000-0000-0000-0000-000000000002'::uuid)
  and student_id = (select id from public.students where app_id = 15)), true);
select public.maestro_student_command('add_note', 15, 105,
  current_setting('maestro.test.ben_lesson')::bigint,
  '{"piece":"Shared test piece","comment":"Ben private"}'::jsonb);
select set_config('maestro.test.ben_note', (select max(app_id)::text from
  public.lesson_notes where lesson_id = (select id from public.lessons where
    app_id = current_setting('maestro.test.ben_lesson')::bigint)), true);

select set_config('request.jwt.claim.sub',
  '10000000-0000-0000-0000-000000000001', true);
select public.maestro_student_command('update_piece', 15, 105, null,
  jsonb_build_object('pieceIndex', current_setting('maestro.test.piece_index')::integer,
    'title', 'Ada renamed piece'));
select is((select piece from public.lesson_notes where app_id =
  current_setting('maestro.test.ada_note')::bigint), 'Ada renamed piece',
  'piece rename updates own note');
select throws_ok(
  'select public.maestro_student_command(''update_lesson'', 15, 105, current_setting(''maestro.test.ben_lesson'')::bigint, ''{}''::jsonb)',
  '42501', 'Lesson not found or not owned',
  'teacher cannot update the other teacher lesson');
select set_config('request.jwt.claim.sub',
  '10000000-0000-0000-0000-000000000002', true);
select is((select piece from public.lesson_notes where app_id =
  current_setting('maestro.test.ben_note')::bigint), 'Shared test piece',
  'piece rename does not change the other teacher private note');
rollback;
