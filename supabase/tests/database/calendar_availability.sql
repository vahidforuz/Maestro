begin;
create extension if not exists pgtap with schema extensions;
set local search_path = public, extensions;
select plan(19);
set local role authenticated;
select set_config('request.jwt.claim.sub',
  '10000000-0000-0000-0000-000000000001', true);

select ok((select relrowsecurity from pg_class
  where oid = 'public.teacher_availability_rules'::regclass),
  'weekly rules use RLS');
select ok((select relrowsecurity from pg_class
  where oid = 'public.teacher_availability_exceptions'::regclass),
  'date exceptions use RLS');
select is((select timezone from public.teachers where user_id = auth.uid()),
  'America/Toronto', 'teacher has an IANA timezone');

insert into public.teacher_availability_rules
  (teacher_id, weekday, start_minute, end_minute, kind, effective_from)
values (public.maestro_current_teacher_id(), 1, 540, 1020,
  'available', '2026-10-26');
insert into public.teacher_availability_exceptions
  (teacher_id, on_date, start_minute, end_minute, kind)
values (public.maestro_current_teacher_id(), '2026-10-26', 0, 1440,
  'unavailable');
select is((select count(*)::integer from public.teacher_availability_rules),
  1, 'teacher can create and read a recurring rule');
select is((select count(*)::integer from public.teacher_availability_exceptions),
  1, 'teacher can block a whole date');

select public.maestro_copy_availability_day('2026-10-26', array[2,3]);
select is((select count(*)::integer from public.teacher_availability_rules
  where weekday in (2,3)), 2, 'copy writes two target weekdays');
select public.maestro_copy_availability_day('2026-10-26', array[2]);
select is((select count(*)::integer from public.teacher_availability_rules
  where weekday = 2 and effective_until is null), 1,
  'copy replaces future target hours without duplicates');
select set_config('calendar.rule', (select id::text
  from public.teacher_availability_rules where weekday = 1), true);
select public.maestro_change_availability_rule(
  current_setting('calendar.rule')::uuid, '2026-11-02',
  600, 900, 'available', false);
select is((select effective_until from public.teacher_availability_rules
  where id = current_setting('calendar.rule')::uuid),
  '2026-11-01'::date, 'weekly edit preserves past hours');
select is((select start_minute::integer from public.teacher_availability_rules
  where weekday = 1 and effective_from = '2026-11-02'),
  600, 'weekly edit starts new hours on selected future date');
select public.maestro_change_availability_rule(
  (select id from public.teacher_availability_rules
    where weekday = 1 and effective_from = '2026-11-02'),
  '2026-11-09', null, null, null, true);
select is((select effective_until from public.teacher_availability_rules
  where weekday = 1 and effective_from = '2026-11-02'),
  '2026-11-08'::date, 'future delete preserves earlier weeks');

select throws_ok(
  'select public.maestro_set_lesson_duration(1001, 20)',
  '22023', 'Duration must be 30, 45, or 60 minutes',
  'unsupported lesson duration is rejected');
select public.maestro_set_lesson_duration(1001, 30);
select is((select duration_minutes from public.lessons where app_id = 1001),
  30, 'teacher can set a supported lesson duration');
select public.maestro_update_lesson_with_duration(11, 101, 1001,
  jsonb_build_object('title', 'Piano lesson 1', 'day', 'MONDAY',
    'date', (select lesson_date from public.lessons where app_id = 1001),
    'hour', '16:00', 'price', 20, 'status', 'NOTHING',
    'durationMinutes', 45));
select is((select duration_minutes from public.lessons where app_id = 1001),
  45, 'lesson editor applies a supported duration with the existing workflow');
select is(public.maestro_convert_calendar_ranges(
  '[{"date":"2026-03-08","startMinute":60,"endMinute":90}]'::jsonb)
    ->0->>'startAt', '2026-03-08T06:00:00+00:00',
  'valid spring wall time converts with Toronto offset');
select throws_ok(
  'select public.maestro_convert_calendar_ranges(''[{"date":"2026-03-08","startMinute":120,"endMinute":150}]''::jsonb)',
  '22023', 'Calendar range crosses an invalid local time',
  'nonexistent spring DST time is rejected');
select ok((public.maestro_convert_calendar_ranges(
  '[{"date":"2026-11-01","startMinute":60,"endMinute":90}]'::jsonb)
    ->0->>'startAt') is not null,
  'autumn repeated local time resolves to one UTC instant');
select public.maestro_create_student(
  '{"firstName":"Overlap","familyName":"One","courseDay":"SUNDAY",
    "courseHour":"12:00","coursePrice":20}'::jsonb);
select throws_ok(
  'select public.maestro_create_student(''{"firstName":"Overlap","familyName":"Two","courseDay":"SUNDAY","courseHour":"12:30","coursePrice":20}''::jsonb)',
  '23P01', 'Lesson overlaps another scheduled lesson',
  'overlapping lessons are rejected across students');

select set_config('request.jwt.claim.sub',
  '10000000-0000-0000-0000-000000000002', true);
select is((select count(*)::integer from public.teacher_availability_rules),
  0, 'other teacher cannot read weekly rules');
select is((select count(*)::integer from public.teacher_availability_exceptions),
  0, 'other teacher cannot read exceptions');
rollback;
