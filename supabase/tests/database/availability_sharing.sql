begin;
create extension if not exists pgtap with schema extensions;
set local search_path = public, extensions;
select plan(14);
set local role authenticated;
select set_config('request.jwt.claim.sub',
  '10000000-0000-0000-0000-000000000001', true);

insert into public.teacher_availability_rules
  (teacher_id, weekday, start_minute, end_minute, kind, effective_from)
values (public.maestro_current_teacher_id(), 1, 540, 720,
  'available', '2026-10-26');
insert into public.teacher_availability_exceptions
  (teacher_id, on_date, start_minute, end_minute, kind)
values (public.maestro_current_teacher_id(), '2026-10-26', 600, 660,
  'unavailable');
select set_config('share.student', public.maestro_create_student(
  '{"firstName":"Private","familyName":"Student","courseDay":"MONDAY",
    "courseHour":"09:30","coursePrice":20}'::jsonb)::text, true);
select set_config('share.token', public.maestro_create_availability_link(
  now() + interval '7 days', '2026-10-26', '2026-10-26')->>'token', true);
select is(length(current_setting('share.token')), 64,
  'share token has 256 bits encoded as hex');
select ok((select relrowsecurity from pg_class
  where oid = 'public.availability_share_links'::regclass),
  'share link metadata uses RLS');

set local role anon;
select is((public.maestro_shared_availability(current_setting('share.token'),
  '2026-10-26', 30)->>'timezone'), 'America/Toronto',
  'public view states the teacher timezone');
select ok(exists (select 1 from jsonb_array_elements(
  public.maestro_shared_availability(current_setting('share.token'),
    '2026-10-26', 30)->'slots') slot
  where slot->>'date' = '2026-10-26' and slot->>'startMinute' = '540'),
  'unoccupied working time is shared');
select ok(not exists (select 1 from jsonb_array_elements(
  public.maestro_shared_availability(current_setting('share.token'),
    '2026-10-26', 30)->'slots') slot
  where slot->>'date' = '2026-10-26' and slot->>'startMinute' in ('570','600','630')),
  'lesson and unavailable exception remove public slots');
select ok(position('Private' in public.maestro_shared_availability(
  current_setting('share.token'), '2026-10-26', 30)::text) = 0,
  'public result contains no student name');
select is((select count(*)::integer from public.availability_share_links),
  0, 'anonymous user cannot read raw share link records');

set local role authenticated;
select set_config('request.jwt.claim.sub',
  '10000000-0000-0000-0000-000000000001', true);
insert into public.teacher_availability_rules
  (teacher_id, weekday, start_minute, end_minute, kind, effective_from)
values (public.maestro_current_teacher_id(), 1, 660, 720,
  'unavailable', '2026-10-26');
insert into public.teacher_availability_exceptions
  (teacher_id, on_date, start_minute, end_minute, kind)
values (public.maestro_current_teacher_id(), '2026-10-26', 660, 720,
  'available');
set local role anon;
select ok(exists (select 1 from jsonb_array_elements(
  public.maestro_shared_availability(current_setting('share.token'),
    '2026-10-26', 30)->'slots') slot
  where slot->>'date' = '2026-10-26' and slot->>'startMinute' = '660'),
  'special availability overrides a weekly closure');

set local role authenticated;
select set_config('request.jwt.claim.sub',
  '10000000-0000-0000-0000-000000000001', true);
update public.availability_share_links set revoked_at = now()
  where token_hash = sha256(convert_to(current_setting('share.token'), 'UTF8'));
set local role anon;
select throws_ok(
  'select public.maestro_shared_availability(current_setting(''share.token''), ''2026-10-26'', 30)',
  '22023', 'Availability link is unavailable',
  'revoked token cannot read availability');
select throws_ok(
  'select public.maestro_shared_availability(repeat(''a'', 64), ''2026-10-26'', 30)',
  '22023', 'Availability link is unavailable',
  'unknown token cannot read availability');
set local role authenticated;
select set_config('request.jwt.claim.sub',
  '10000000-0000-0000-0000-000000000001', true);
select set_config('share.expired', public.maestro_create_availability_link(
  now() + interval '1 day')->>'token', true);
update public.availability_share_links set expires_at = now() - interval '1 minute'
  where token_hash = sha256(convert_to(current_setting('share.expired'), 'UTF8'));
set local role anon;
select throws_ok(
  'select public.maestro_shared_availability(current_setting(''share.expired''), ''2026-10-26'', 30)',
  '22023', 'Availability link is unavailable',
  'expired token cannot read availability');
select throws_ok(
  'select public.maestro_shared_availability(current_setting(''share.expired''), ''2026-10-27'', 30)',
  '22023', 'Invalid availability request',
  'public query requires a Monday week start');
set local role authenticated;
select set_config('request.jwt.claim.sub',
  '10000000-0000-0000-0000-000000000001', true);
insert into public.teacher_availability_rules
  (teacher_id, weekday, start_minute, end_minute, kind, effective_from)
values (public.maestro_current_teacher_id(), 7, 60, 240,
  'available', '2026-03-02');
select set_config('share.dst', public.maestro_create_availability_link(
  now() + interval '1 day')->>'token', true);
set local role anon;
select ok(not exists (select 1 from jsonb_array_elements(
  public.maestro_shared_availability(current_setting('share.dst'),
    '2026-03-02', 30)->'slots') slot
  where slot->>'date' = '2026-03-08' and slot->>'startMinute' in ('120','150')),
  'public slots omit nonexistent spring DST times');
select ok(exists (select 1 from jsonb_array_elements(
  public.maestro_shared_availability(current_setting('share.dst'),
    '2026-03-02', 30)->'slots') slot
  where slot->>'date' = '2026-03-08' and slot->>'startMinute' = '180'),
  'public slots resume at valid time after spring DST jump');
rollback;
