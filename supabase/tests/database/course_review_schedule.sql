begin;
create extension if not exists pgtap with schema extensions;
set local search_path = public, extensions;
select plan(13);
set local role authenticated;
select set_config('request.jwt.claim.sub', '10000000-0000-0000-0000-000000000001', true);

select set_config('review.student', public.maestro_create_student(
  '{"firstName":"Calendar","familyName":"Review","courseDay":"MONDAY","courseHour":"16:00","coursePrice":30}'::jsonb)::text, true);
select set_config('review.project', (select p.app_id::text from public.projects p
  join public.students s on s.id = p.student_id
  where s.app_id = current_setting('review.student')::bigint), true);
select set_config('review.source', (select l.app_id::text from public.lessons l
  join public.students s on s.id = l.student_id
  where s.app_id = current_setting('review.student')::bigint), true);

select public.maestro_student_command('add_note', current_setting('review.student')::bigint,
  current_setting('review.project')::bigint, current_setting('review.source')::bigint,
  '{"piece":"Scale","comment":"Practice C major","reviewWeeks":2}'::jsonb);
select set_config('review.note', (select n.app_id::text from public.lesson_notes n
  join public.lessons l on l.id = n.lesson_id
  where l.app_id = current_setting('review.source')::bigint), true);
select is((select count(*)::integer from public.lesson_notes n
  join public.lessons l on l.id = n.lesson_id
  where l.app_id = current_setting('review.source')::bigint), 1,
  'review remains one source note');
select ok((select t.lesson_date = s.lesson_date + 14 from public.lesson_notes n
  join public.lessons s on s.id = n.lesson_id
  join public.lessons t on t.id = n.target_lesson_id
  where n.app_id = current_setting('review.note')::bigint),
  'missing course is created two calendar weeks later');
select ok((select t.status = 'SCHEDULED' and t.hour = '16:00'::time
    and t.price = 30 and t.day = 'MONDAY'
  from public.lesson_notes n join public.lessons t on t.id = n.target_lesson_id
  where n.app_id = current_setting('review.note')::bigint),
  'new course has scheduled status and preferred time');
select is((select count(*)::integer from public.lessons l
  join public.students s on s.id = l.student_id
  where s.app_id = current_setting('review.student')::bigint), 2,
  'source and target are the only courses');
select is((select count(*)::integer from public.payments p
  join public.students s on s.id = p.student_id
  where s.app_id = current_setting('review.student')::bigint), 0,
  'scheduling creates no payment');

select public.maestro_student_command('add_note', current_setting('review.student')::bigint,
  current_setting('review.project')::bigint, current_setting('review.source')::bigint,
  '{"piece":"Scale","comment":"Practice C major","reviewWeeks":2}'::jsonb);
select is((select count(*)::integer from public.lesson_notes n
  join public.students s on s.id = n.student_id
  where s.app_id = current_setting('review.student')::bigint), 1,
  'repeating the request does not duplicate the review');
select is((select count(*)::integer from public.lessons l
  join public.students s on s.id = l.student_id
  where s.app_id = current_setting('review.student')::bigint), 2,
  'repeating the request does not duplicate the course');

select public.maestro_student_command('add_note', current_setting('review.student')::bigint,
  current_setting('review.project')::bigint, current_setting('review.source')::bigint,
  '{"piece":"Scale","comment":"Practice G major","reviewWeeks":2}'::jsonb);
select is((select count(distinct target_lesson_id)::integer from public.lesson_notes n
  join public.students s on s.id = n.student_id
  where s.app_id = current_setting('review.student')::bigint), 1,
  'another review for the date reuses the course');

select public.maestro_student_command('add_lesson', current_setting('review.student')::bigint,
  current_setting('review.project')::bigint);
select set_config('review.manual', (select app_id::text from public.lessons
  where student_id = (select id from public.students
    where app_id = current_setting('review.student')::bigint)
  order by lesson_date desc limit 1), true);
select public.maestro_student_command('update_lesson', current_setting('review.student')::bigint,
  current_setting('review.project')::bigint, current_setting('review.manual')::bigint,
  jsonb_build_object('date', (select lesson_date + 7 from public.lessons
    where app_id = current_setting('review.source')::bigint),
    'day','MONDAY','hour','16:00','price',30,'status','NOTHING'));
select public.maestro_student_command('add_note', current_setting('review.student')::bigint,
  current_setting('review.project')::bigint, current_setting('review.source')::bigint,
  '{"piece":"Scale","comment":"Practice F major","reviewWeeks":1}'::jsonb);
select ok((select n.target_lesson_id = l.id from public.lesson_notes n
  join public.lessons l on l.app_id = current_setting('review.manual')::bigint
  where n.comment = 'Practice F major' and n.student_id = l.student_id),
  'review uses an existing target date course');
select is((select count(*)::integer from public.lessons l
  join public.students s on s.id = l.student_id
  where s.app_id = current_setting('review.student')::bigint), 3,
  'existing course is reused without duplication');

select public.maestro_student_command('update_note', current_setting('review.student')::bigint,
  current_setting('review.project')::bigint, current_setting('review.source')::bigint,
  jsonb_build_object('noteId', current_setting('review.note')::bigint,
    'piece','Scale','comment','Practice C major slowly','reviewWeeks',1));
select ok((select n.target_lesson_id = l.id and n.comment = 'Practice C major slowly'
  from public.lesson_notes n
  join public.lessons l on l.app_id = current_setting('review.manual')::bigint
  where n.app_id = current_setting('review.note')::bigint),
  'editing updates note and target');
select public.maestro_student_command('delete_note', current_setting('review.student')::bigint,
  current_setting('review.project')::bigint, current_setting('review.source')::bigint,
  jsonb_build_object('noteId', current_setting('review.note')::bigint));
select is((select count(*)::integer from public.lesson_notes
  where app_id = current_setting('review.note')::bigint), 0,
  'deleting removes the review source');
select is((select count(*)::integer from public.lessons l
  join public.students s on s.id = l.student_id
  where s.app_id = current_setting('review.student')::bigint
    and l.status in ('PRESENT','ABSENT')), 0,
  'review changes do not consume lessons');
rollback;
