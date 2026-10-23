begin;
create extension if not exists pgtap with schema extensions;
set local search_path = public, extensions;
select plan(14);
set local role authenticated;
select set_config('request.jwt.claim.sub',
  '10000000-0000-0000-0000-000000000001', true);

insert into public.teacher_availability_rules
  (teacher_id, weekday, start_minute, end_minute, kind, effective_from)
values (public.maestro_current_teacher_id(), 1, 540, 1020,
  'available', '2026-10-26');
with inserted as (insert into public.teacher_time_blocks
  (teacher_id,title,category,start_at,end_at,all_day,repeat,notes)
  values (public.maestro_current_teacher_id(),'Private lunch','breakTime',
    '2026-10-26 12:00','2026-10-26 13:00',false,'daily','Private note')
  returning id)
select set_config('block.id', id::text, true) from inserted;
select set_config('block.token', public.maestro_create_availability_link(
  now() + interval '1 day')->>'token', true);
select ok((select relrowsecurity from pg_class
  where oid = 'public.teacher_time_blocks'::regclass), 'blocks use RLS');
select ok((select relrowsecurity from pg_class
  where oid = 'public.teacher_time_block_exceptions'::regclass),
  'occurrence overrides use RLS');

set local role anon;
select is((select count(*)::integer from public.teacher_time_blocks), 0,
  'anonymous users cannot read private blocks');
select ok(exists (select 1 from jsonb_array_elements(
  public.maestro_shared_availability(current_setting('block.token'),
    '2026-10-26',30)->'slots') slot
  where slot->>'date' = '2026-10-26' and slot->>'startMinute' = '540'),
  'working slot remains available');
select ok(not exists (select 1 from jsonb_array_elements(
  public.maestro_shared_availability(current_setting('block.token'),
    '2026-10-26',30)->'slots') slot
  where slot->>'date' = '2026-10-26' and slot->>'startMinute' = '720'),
  'daily block removes public slot');
select ok(position('Private' in public.maestro_shared_availability(
  current_setting('block.token'), '2026-10-26',30)::text) = 0,
  'shared result hides block titles and notes');

set local role authenticated;
select set_config('request.jwt.claim.sub',
  '10000000-0000-0000-0000-000000000001', true);
insert into public.teacher_time_block_exceptions
  (block_id,teacher_id,occurrence_date,cancelled)
values (current_setting('block.id')::uuid,public.maestro_current_teacher_id(),
  '2026-10-26',true);
set local role anon;
select ok(exists (select 1 from jsonb_array_elements(
  public.maestro_shared_availability(current_setting('block.token'),
    '2026-10-26',30)->'slots') slot
  where slot->>'date' = '2026-10-26' and slot->>'startMinute' = '720'),
  'cancelled occurrence restores only that slot');

set local role authenticated;
select set_config('request.jwt.claim.sub',
  '10000000-0000-0000-0000-000000000001', true);
update public.teacher_time_block_exceptions
  set cancelled = false, start_at = '2026-10-26 14:00',
      end_at = '2026-10-26 15:00'
  where block_id = current_setting('block.id')::uuid
    and occurrence_date = '2026-10-26';
set local role anon;
select ok(not exists (select 1 from jsonb_array_elements(
  public.maestro_shared_availability(current_setting('block.token'),
    '2026-10-26',30)->'slots') slot
  where slot->>'date' = '2026-10-26' and slot->>'startMinute' = '840'),
  'moved occurrence blocks its new time');
select ok(exists (select 1 from jsonb_array_elements(
  public.maestro_shared_availability(current_setting('block.token'),
    '2026-10-26',30)->'slots') slot
  where slot->>'date' = '2026-10-26' and slot->>'startMinute' = '720'),
  'moved occurrence frees its original time');

set local role authenticated;
select set_config('request.jwt.claim.sub',
  '10000000-0000-0000-0000-000000000001', true);
insert into public.teacher_time_blocks
  (teacher_id,title,category,start_at,end_at,all_day,repeat)
values (public.maestro_current_teacher_id(),'Vacation','vacation',
  '2026-10-26 00:00','2026-10-31 00:00',true,'never');
set local role anon;
select ok(not exists (select 1 from jsonb_array_elements(
  public.maestro_shared_availability(current_setting('block.token'),
    '2026-10-26',30)->'slots') slot
  where slot->>'date' = '2026-10-26'),
  'multi-day all-day vacation removes working slots');
select ok(position('Vacation' in public.maestro_shared_availability(
  current_setting('block.token'), '2026-10-26',30)::text) = 0,
  'vacation title remains private');

set local role authenticated;
select set_config('request.jwt.claim.sub',
  '10000000-0000-0000-0000-000000000001', true);
insert into public.teacher_availability_rules
  (teacher_id, weekday, start_minute, end_minute, kind, effective_from)
values (public.maestro_current_teacher_id(), 7, 0, 480,
  'available', '2026-03-02');
insert into public.teacher_time_blocks
  (teacher_id,title,category,start_at,end_at,all_day,repeat)
values (public.maestro_current_teacher_id(),'Sleep','sleep',
  '2026-03-07 23:00','2026-03-08 07:00',false,'daily');
set local role anon;
select ok(not exists (select 1 from jsonb_array_elements(
  public.maestro_shared_availability(current_setting('block.token'),
    '2026-03-02',30)->'slots') slot
  where slot->>'date' = '2026-03-08' and slot->>'startMinute' = '0'),
  'overnight sleep blocks Sunday before the spring DST jump');
select ok(exists (select 1 from jsonb_array_elements(
  public.maestro_shared_availability(current_setting('block.token'),
    '2026-03-02',30)->'slots') slot
  where slot->>'date' = '2026-03-08' and slot->>'startMinute' = '420'),
  'Sunday becomes available after sleep ends');

set local role authenticated;
select set_config('request.jwt.claim.sub',
  '10000000-0000-0000-0000-000000000002', true);
select is((select count(*)::integer from public.teacher_time_blocks), 0,
  'another teacher cannot read private blocks');
rollback;
