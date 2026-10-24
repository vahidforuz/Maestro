begin;
create extension if not exists pgtap with schema extensions;
set local search_path = public, extensions;
select plan(32);

insert into public.student_portal_access(teacher_id, student_id, user_id, enabled)
values
  ('20000000-0000-0000-0000-000000000001',
   '30000000-0000-0000-0000-000000000011',
   '10000000-0000-0000-0000-000000000011', true),
  ('20000000-0000-0000-0000-000000000001',
   '30000000-0000-0000-0000-000000000012',
   '10000000-0000-0000-0000-000000000011', true),
  ('20000000-0000-0000-0000-000000000002',
   '30000000-0000-0000-0000-000000000013',
   '10000000-0000-0000-0000-000000000012', true)
on conflict (teacher_id, student_id) do update
  set user_id = excluded.user_id, enabled = true;

select ok((select relrowsecurity from pg_class
  where oid = 'public.messages'::regclass), 'messages have RLS');
select ok((select relrowsecurity from pg_class
  where oid = 'public.message_attachments'::regclass), 'attachments have RLS');
select ok((select not public from storage.buckets where id = 'maestro-messages'),
  'message bucket is private');
select ok(not has_table_privilege('authenticated', 'public.messages', 'INSERT'),
  'direct API cannot insert or impersonate a sender');
select ok(not has_table_privilege('authenticated', 'public.conversation_reads', 'UPDATE'),
  'direct API cannot alter read state');
select ok(not has_table_privilege('authenticated',
  'public.message_notification_outbox', 'SELECT'), 'outbox is private');

set local role authenticated;
select set_config('request.jwt.claim.sub',
  '10000000-0000-0000-0000-000000000001', true);
select set_config('maestro.test.conv', public.maestro_open_conversation(
  '20000000-0000-0000-0000-000000000001',
  '30000000-0000-0000-0000-000000000011')::text, true);
select is(public.maestro_open_conversation(
  '20000000-0000-0000-0000-000000000001',
  '30000000-0000-0000-0000-000000000011')::text,
  current_setting('maestro.test.conv'), 'opening twice returns one conversation');
select is((select count(*) from public.conversations where id =
  current_setting('maestro.test.conv')::uuid), 1::bigint, 'teacher sees own room');
select set_config('maestro.test.message', (public.maestro_send_message(
  current_setting('maestro.test.conv')::uuid,
  'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', 'text', 'Practice slowly')).id::text, true);
select is((public.maestro_send_message(
  current_setting('maestro.test.conv')::uuid,
  'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', 'text', 'Practice slowly')).id::text,
  current_setting('maestro.test.message'), 'client ID makes retry idempotent');
select is((select coalesce(sum((x->>'unreadCount')::bigint), 0)::bigint
  from public.maestro_conversation_summaries() x), 0::bigint,
  'teacher does not count own sent messages');
select ok(public.maestro_message_storage_allowed(
  current_setting('maestro.test.conv') || '/' || current_setting('maestro.test.message') ||
  '/bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb.m4a', true) = false,
  'text message cannot receive an uploaded file');
select throws_ok($$select public.maestro_open_conversation(
  '20000000-0000-0000-0000-000000000002',
  '30000000-0000-0000-0000-000000000013')$$,
  '42501', 'Messaging access denied', 'teacher cannot open another studio room');

select set_config('request.jwt.claim.sub',
  '10000000-0000-0000-0000-000000000011', true);
select is((select count(*) from public.messages where conversation_id =
  current_setting('maestro.test.conv')::uuid
  and id = current_setting('maestro.test.message')::uuid), 1::bigint,
  'student sees the teacher message in their room');
select ok((public.maestro_send_message(current_setting('maestro.test.conv')::uuid,
  'cccccccc-cccc-cccc-cccc-cccccccccccc', 'text', 'Thank you')).sender_id =
  '10000000-0000-0000-0000-000000000011'::uuid,
  'server derives sender from Auth');
select set_config('maestro.test.second', public.maestro_open_conversation(
  '20000000-0000-0000-0000-000000000001',
  '30000000-0000-0000-0000-000000000012')::text, true);
select public.maestro_send_message(current_setting('maestro.test.second')::uuid,
  'ffffffff-ffff-ffff-ffff-ffffffffffff', 'text', 'Second room');
select set_config('request.jwt.claim.sub',
  '10000000-0000-0000-0000-000000000001', true);
select is((select coalesce(sum((x->>'unreadCount')::bigint), 0)::bigint
  from public.maestro_conversation_summaries() x), 2::bigint,
  'incoming messages in multiple rooms add to total');
select public.maestro_mark_read(current_setting('maestro.test.conv')::uuid,
  (select id from public.messages where conversation_id =
    current_setting('maestro.test.conv')::uuid order by created_at desc limit 1));
select is((select coalesce(sum((x->>'unreadCount')::bigint), 0)::bigint
  from public.maestro_conversation_summaries() x), 1::bigint,
  'opening one room removes only its unread messages');
select is((select (x->>'unreadCount')::bigint
  from public.maestro_conversation_summaries() x
  where x->>'id' = current_setting('maestro.test.second')), 1::bigint,
  'other room keeps its unread count');
select public.maestro_send_message(current_setting('maestro.test.conv')::uuid,
  'abababab-abab-abab-abab-abababababab', 'text', 'Teacher reply');
select is((select coalesce(sum((x->>'unreadCount')::bigint), 0)::bigint
  from public.maestro_conversation_summaries() x), 1::bigint,
  'sending does not increase teacher unread total');
select set_config('request.jwt.claim.sub',
  '10000000-0000-0000-0000-000000000011', true);
select set_config('maestro.test.file', (public.maestro_send_message(
  current_setting('maestro.test.conv')::uuid,
  'edededed-eded-eded-eded-edededededed', 'file', '')).id::text, true);
reset role;
insert into storage.objects(bucket_id, name, owner_id, metadata)
values ('maestro-messages', current_setting('maestro.test.conv') || '/' ||
  current_setting('maestro.test.file') ||
  '/99999999-9999-9999-9999-999999999999.png',
  '10000000-0000-0000-0000-000000000011',
  '{"size":100,"mimetype":"image/png"}'::jsonb);
set local role authenticated;
select set_config('request.jwt.claim.sub',
  '10000000-0000-0000-0000-000000000011', true);
select is((public.maestro_attach_message(
  current_setting('maestro.test.file')::uuid,
  current_setting('maestro.test.conv') || '/' || current_setting('maestro.test.file') ||
  '/99999999-9999-9999-9999-999999999999.png',
  'photo.png', 'image/png', 100)).mime_type, 'image/png',
  'authorized sender can finalize an image attachment');
select ok(public.maestro_message_storage_allowed(
  current_setting('maestro.test.conv') || '/' || current_setting('maestro.test.file') ||
  '/99999999-9999-9999-9999-999999999999.png', false),
  'student can read finalized image path');
select public.maestro_mark_read(current_setting('maestro.test.conv')::uuid,
  current_setting('maestro.test.message')::uuid);
select ok((select last_read_at is not null from public.conversation_reads
  where conversation_id = current_setting('maestro.test.conv')::uuid
    and user_id = '10000000-0000-0000-0000-000000000011'),
  'viewed message updates only own read marker');
select set_config('request.jwt.claim.sub',
  '10000000-0000-0000-0000-000000000001', true);
select ok(public.maestro_message_storage_allowed(
  current_setting('maestro.test.conv') || '/' || current_setting('maestro.test.file') ||
  '/99999999-9999-9999-9999-999999999999.png', false),
  'teacher can read finalized image path');
select set_config('request.jwt.claim.sub',
  '10000000-0000-0000-0000-000000000012', true);
select is((select count(*) from public.messages where conversation_id =
  current_setting('maestro.test.conv')::uuid), 0::bigint,
  'another student cannot select messages');
select throws_ok($$select public.maestro_send_message(
  current_setting('maestro.test.conv')::uuid,
  'dddddddd-dddd-dddd-dddd-dddddddddddd', 'text', 'Intrusion')$$,
  '42501', 'Messaging access denied', 'another student cannot send');
select is((select count(*) from public.message_attachments where message_id =
  current_setting('maestro.test.file')::uuid), 0::bigint,
  'another student cannot select image metadata');

select set_config('request.jwt.claim.sub',
  '10000000-0000-0000-0000-000000000002', true);
select is((select count(*) from public.messages where conversation_id =
  current_setting('maestro.test.conv')::uuid), 0::bigint,
  'another teacher cannot select messages');
select is((select count(*) from public.maestro_conversation_summaries()),
  0::bigint, 'another teacher sees no conversation summaries');
select ok(not public.maestro_message_storage_allowed(
  current_setting('maestro.test.conv') || '/' || current_setting('maestro.test.file') ||
  '/99999999-9999-9999-9999-999999999999.png', false),
  'another teacher cannot read attachment paths');
select is((select count(*) from public.message_attachments where message_id =
  current_setting('maestro.test.file')::uuid), 0::bigint,
  'another teacher cannot select image metadata');

reset role;
update public.student_portal_access set enabled = false
  where teacher_id = '20000000-0000-0000-0000-000000000001'
    and student_id = '30000000-0000-0000-0000-000000000011';
set local role authenticated;
select set_config('request.jwt.claim.sub',
  '10000000-0000-0000-0000-000000000011', true);
select is((select count(*) from public.messages where conversation_id =
  current_setting('maestro.test.conv')::uuid), 0::bigint,
  'revocation hides historical messages');
select throws_ok($$select public.maestro_send_message(
  current_setting('maestro.test.conv')::uuid,
  'eeeeeeee-eeee-eeee-eeee-eeeeeeeeeeee', 'text', 'After revocation')$$,
  '42501', 'Messaging access denied', 'revocation blocks sending');
select ok(not public.maestro_message_storage_allowed(
  current_setting('maestro.test.conv') || '/' || current_setting('maestro.test.file') ||
  '/99999999-9999-9999-9999-999999999999.png', false),
  'revocation blocks future attachment access');

select * from finish();
rollback;
