begin;
create extension if not exists pgtap with schema extensions;
set local search_path = public, extensions;
select plan(28);
select set_config('maestro.test.initial_student_count',
  (select count(*)::text from public.students), true);

insert into public.student_portal_access(teacher_id, student_id, user_id, enabled)
values ('20000000-0000-0000-0000-000000000001',
  '30000000-0000-0000-0000-000000000011',
  '10000000-0000-0000-0000-000000000011', true)
on conflict (teacher_id, student_id) do update set user_id = excluded.user_id,
  enabled = true;

select ok((select relrowsecurity from pg_class where oid =
  'public.parent_access'::regclass), 'parent grants use RLS');
select ok(not has_table_privilege('authenticated', 'public.parent_access', 'INSERT'),
  'direct API cannot create parent grants');
select ok(not has_table_privilege('authenticated', 'public.parent_invitations', 'INSERT'),
  'direct API cannot forge parent invitations');

set local role authenticated;
select set_config('request.jwt.claim.sub',
  '10000000-0000-0000-0000-000000000001', true);
select set_config('maestro.test.parent_token',
  public.maestro_invite_parent(11, 'ren.parent@maestro.example', 'Ren Parent')->>'token', true);
select ok(public.maestro_check_parent_invitation(
  current_setting('maestro.test.parent_token'), 'ren.parent@maestro.example'),
  'authorized parent email can activate');
select ok(not public.maestro_check_parent_invitation(
  current_setting('maestro.test.parent_token'), 'pat.parent@maestro.example'),
  'another email cannot use the invitation');

select set_config('request.jwt.claim.sub',
  '10000000-0000-0000-0000-000000000022', true);
select is(public.maestro_accept_parent_invitation(
  current_setting('maestro.test.parent_token'))->>'teacherId',
  '20000000-0000-0000-0000-000000000001',
  'existing verified parent account is linked');
select set_config('request.jwt.claim.sub',
  '10000000-0000-0000-0000-000000000001', true);
select is((select count(*) from public.parent_access where student_id =
  '30000000-0000-0000-0000-000000000011' and active), 2::bigint,
  'one student supports two parents');
select set_config('request.jwt.claim.sub',
  '10000000-0000-0000-0000-000000000022', true);
select is((select count(*) from jsonb_array_elements(
  public.maestro_parent_portal_data())), 3::bigint,
  'one parent sees students from more than one teacher');
select is((select count(*) from public.payments where student_id =
  '30000000-0000-0000-0000-000000000011'), 1::bigint,
  'parent sees payment for explicitly linked teacher and student');
select is((select count(*) from public.payments where student_id =
  '30000000-0000-0000-0000-000000000013'), 0::bigint,
  'parent cannot see payments without finance permission');
do $$
declare v_rows integer;
begin
  begin
    update public.payments set amount = 999
      where id = '60000000-0000-0000-0000-000000000011';
    get diagnostics v_rows = row_count;
    perform set_config('maestro.test.parent_payment_write',
      case when v_rows = 0 then 'denied' else 'allowed' end, true);
  exception when insufficient_privilege then
    perform set_config('maestro.test.parent_payment_write', 'denied', true);
  end;
end;
$$;
select is(current_setting('maestro.test.parent_payment_write'), 'denied',
  'parent cannot modify a visible payment');

reset role;
insert into public.parent_access(teacher_id, student_id, parent_user_id)
values ('20000000-0000-0000-0000-000000000001',
  '30000000-0000-0000-0000-000000000015',
  '10000000-0000-0000-0000-000000000021');
insert into public.parent_students(parent_user_id, student_id,
  can_view_finances) values (
  '10000000-0000-0000-0000-000000000021',
  '30000000-0000-0000-0000-000000000015', true)
on conflict (parent_user_id, student_id) do update set active = true,
  can_view_finances = true;
insert into public.payments(id, app_id, student_id, teacher_id, amount, payment_date)
values
  ('60000000-0000-0000-0000-000000000015', 99015,
   '30000000-0000-0000-0000-000000000015',
   '20000000-0000-0000-0000-000000000001', 10, current_date),
  ('60000000-0000-0000-0000-000000000016', 99016,
   '30000000-0000-0000-0000-000000000015',
   '20000000-0000-0000-0000-000000000002', 20, current_date);
set local role authenticated;
select set_config('request.jwt.claim.sub',
  '10000000-0000-0000-0000-000000000021', true);
select is((select coalesce(sum(amount), 0) from public.payments
  where app_id in (99015, 99016)), 10::numeric,
  'shared student payments stay scoped to the authorized teacher');
select throws_ok($$select public.get_student_finances(
  '30000000-0000-0000-0000-000000000015')$$,
  '42501', 'Financial access denied',
  'legacy student-only finance RPC cannot leak shared-teacher amounts');

select set_config('request.jwt.claim.sub',
  '10000000-0000-0000-0000-000000000001', true);
select set_config('maestro.test.private_parent',
  public.maestro_open_parent_conversation(11,
    array['10000000-0000-0000-0000-000000000022'::uuid], false)::text, true);
select set_config('maestro.test.group',
  public.maestro_open_parent_conversation(11,
    array['10000000-0000-0000-0000-000000000021'::uuid,
      '10000000-0000-0000-0000-000000000022'::uuid], true)::text, true);
select is(public.maestro_open_parent_conversation(11,
  array['10000000-0000-0000-0000-000000000022'::uuid,
    '10000000-0000-0000-0000-000000000021'::uuid], true)::text,
  current_setting('maestro.test.group'),
  'group conversation is reused for the same participants');
select public.maestro_send_message(current_setting('maestro.test.private_parent')::uuid,
  'c1111111-1111-1111-1111-111111111111', 'text', 'Parent private');
select public.maestro_send_message(current_setting('maestro.test.group')::uuid,
  'c2222222-2222-2222-2222-222222222222', 'text', 'Group message');
reset role;
select is((select count(*) from public.message_notification_outbox o
  join public.messages m on m.id = o.message_id
  where m.conversation_id = current_setting('maestro.test.group')::uuid),
  3::bigint, 'group message has one notification per other participant');
select is((select count(*) from public.message_notification_outbox o
  join public.messages m on m.id = o.message_id
  where m.conversation_id = current_setting('maestro.test.private_parent')::uuid
    and o.recipient_user_id = '10000000-0000-0000-0000-000000000011'),
  0::bigint, 'student is not notified about private parent message');
set local role authenticated;
select set_config('request.jwt.claim.sub',
  '10000000-0000-0000-0000-000000000001', true);
select set_config('maestro.test.student_private', public.maestro_open_conversation(
  '20000000-0000-0000-0000-000000000001',
  '30000000-0000-0000-0000-000000000011')::text, true);
select public.maestro_send_message(current_setting('maestro.test.student_private')::uuid,
  'c3333333-3333-3333-3333-333333333333', 'text', 'Student private');

select set_config('request.jwt.claim.sub',
  '10000000-0000-0000-0000-000000000011', true);
select ok(not public.maestro_can_message(
  current_setting('maestro.test.private_parent')::uuid),
  'student cannot access teacher-parent private chat');
select ok(public.maestro_can_message(current_setting('maestro.test.group')::uuid),
  'student can access authorized group chat');
select set_config('request.jwt.claim.sub',
  '10000000-0000-0000-0000-000000000022', true);
select ok(not public.maestro_can_message(
  current_setting('maestro.test.student_private')::uuid),
  'parent cannot access teacher-student private chat');
select is((select count(*) from public.messages where conversation_id =
  current_setting('maestro.test.group')::uuid), 1::bigint,
  'parent sees group message through RLS');

select set_config('request.jwt.claim.sub',
  '10000000-0000-0000-0000-000000000001', true);
select public.maestro_remove_parent_access(11,
  '10000000-0000-0000-0000-000000000022');
select set_config('request.jwt.claim.sub',
  '10000000-0000-0000-0000-000000000022', true);
select is((select count(*) from public.messages where conversation_id =
  current_setting('maestro.test.group')::uuid), 0::bigint,
  'removing parent access hides historical group messages');
select is((select count(*) from public.payments where student_id =
  '30000000-0000-0000-0000-000000000011'), 0::bigint,
  'removing parent access hides payment records');
select throws_ok($$select public.maestro_invite_parent(15,
  'intruder@maestro.example', 'Intruder')$$,
  '42501', 'Student access denied',
  'a parent cannot invite themselves to another student');
select throws_ok($$select public.maestro_open_parent_conversation(12,
  array['10000000-0000-0000-0000-000000000022'::uuid], false)$$,
  '42501', 'Student access denied',
  'a parent cannot create a teacher-owned conversation');
select set_config('request.jwt.claim.sub',
  '10000000-0000-0000-0000-000000000021', true);
select ok(public.maestro_can_message(current_setting('maestro.test.group')::uuid),
  'other authorized parent keeps group access');

reset role;
insert into auth.users (instance_id, id, aud, role, email, encrypted_password,
  email_confirmed_at, confirmation_token, recovery_token, email_change_token_new,
  email_change, email_change_token_current, reauthentication_token,
  raw_app_meta_data, raw_user_meta_data, created_at, updated_at)
values ('00000000-0000-0000-0000-000000000000',
  '10000000-0000-0000-0000-000000000031', 'authenticated', 'authenticated',
  'new.parent@maestro.example',
  extensions.crypt('LocalMaestro123!', extensions.gen_salt('bf')),
  now(), '', '', '', '', '', '',
  '{"provider":"email","providers":["email"]}'::jsonb,
  '{}'::jsonb, now(), now());
set local role authenticated;
select set_config('request.jwt.claim.sub',
  '10000000-0000-0000-0000-000000000001', true);
select set_config('maestro.test.new_parent_token',
  public.maestro_invite_parent(12, 'new.parent@maestro.example', 'New Parent')->>'token', true);
select set_config('request.jwt.claim.sub',
  '10000000-0000-0000-0000-000000000031', true);
select is(public.maestro_accept_parent_invitation(
  current_setting('maestro.test.new_parent_token'))->>'studentId',
  '30000000-0000-0000-0000-000000000012',
  'new confirmed Auth account activates the invited parent relationship');
select is((select role from public.profiles where id = auth.uid()), 'parent',
  'new parent receives the parent profile role');
reset role;
select is((select count(*) from public.students),
  current_setting('maestro.test.initial_student_count')::bigint,
  'activation never creates another student record');

select * from finish();
rollback;
