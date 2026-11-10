begin;
create extension if not exists pgtap with schema extensions;
set local search_path = public, extensions;
select plan(29);

-- Leo belongs to Ada but is not Pat's child. A real payment row makes direct
-- RLS checks meaningful; the surrounding transaction rolls it back.
update public.parent_access set active = false where parent_user_id in
  ('10000000-0000-0000-0000-000000000021',
   '10000000-0000-0000-0000-000000000022');
update public.parent_students set active = false where parent_user_id in
  ('10000000-0000-0000-0000-000000000021',
   '10000000-0000-0000-0000-000000000022');
insert into public.parent_access(teacher_id, student_id, parent_user_id,
  active, can_view_finances) values
  ('20000000-0000-0000-0000-000000000001',
   '30000000-0000-0000-0000-000000000011',
   '10000000-0000-0000-0000-000000000021', true, true),
  ('20000000-0000-0000-0000-000000000002',
   '30000000-0000-0000-0000-000000000013',
   '10000000-0000-0000-0000-000000000022', true, false),
  ('20000000-0000-0000-0000-000000000002',
   '30000000-0000-0000-0000-000000000014',
   '10000000-0000-0000-0000-000000000022', true, false)
on conflict (teacher_id, student_id, parent_user_id) do update
  set active = excluded.active, can_view_finances = excluded.can_view_finances;
insert into public.parent_students(parent_user_id, student_id, active,
  can_view_finances) values
  ('10000000-0000-0000-0000-000000000021',
   '30000000-0000-0000-0000-000000000011', true, true),
  ('10000000-0000-0000-0000-000000000022',
   '30000000-0000-0000-0000-000000000013', true, false),
  ('10000000-0000-0000-0000-000000000022',
   '30000000-0000-0000-0000-000000000014', true, false)
on conflict (parent_user_id, student_id) do update
  set active = excluded.active, can_view_finances = excluded.can_view_finances;
with inserted as (insert into public.payments(student_id, teacher_id, amount,
  payment_date) values ('30000000-0000-0000-0000-000000000012',
  '20000000-0000-0000-0000-000000000001', 25, current_date)
  returning id)
select set_config('maestro.test.leo_payment_id', id::text, true) from inserted;
select set_config('maestro.test.expected_payments',
  (select coalesce(sum(amount), 0)::text from public.payments where
    (student_id = '30000000-0000-0000-0000-000000000011'
      and teacher_id = '20000000-0000-0000-0000-000000000001')
    or (student_id = '30000000-0000-0000-0000-000000000013'
      and teacher_id = '20000000-0000-0000-0000-000000000002')), true);
select set_config('maestro.test.expected_balance',
  (public.maestro_teacher_student_balance(
    '20000000-0000-0000-0000-000000000001',
    '30000000-0000-0000-0000-000000000011')
  + public.maestro_teacher_student_balance(
    '20000000-0000-0000-0000-000000000002',
    '30000000-0000-0000-0000-000000000013'))::text, true);

set local role authenticated;
select set_config('request.jwt.claim.sub',
  '10000000-0000-0000-0000-000000000002', true);
select set_config('maestro.test.pat_nora_token',
  public.maestro_invite_parent(13, 'pat.parent@maestro.example',
    'Pat Parent')->>'token', true);
select ok(length(current_setting('maestro.test.pat_nora_token')) = 64,
  'Ben can invite an existing parent to Nora');
select ok(public.maestro_check_parent_invitation(
  current_setting('maestro.test.pat_nora_token'), 'pat.parent@maestro.example'),
  'invitation is bound to Pat email');
select ok(not public.maestro_check_parent_invitation(
  current_setting('maestro.test.pat_nora_token'), 'ren.parent@maestro.example'),
  'another parent email cannot claim the invitation');

select set_config('request.jwt.claim.sub',
  '10000000-0000-0000-0000-000000000022', true);
select throws_ok($$select public.maestro_accept_parent_invitation(
  current_setting('maestro.test.pat_nora_token'))$$,
  '42501', 'Invitation is invalid or for another email',
  'another signed-in parent cannot accept the invitation');
select set_config('request.jwt.claim.sub',
  '10000000-0000-0000-0000-000000000021', true);
select is(public.maestro_accept_parent_invitation(
  current_setting('maestro.test.pat_nora_token'))->>'teacherId',
  '20000000-0000-0000-0000-000000000002',
  'Pat accepts Ben invitation using the existing Auth account');

reset role;
select is((select count(*) from auth.users where
  email = 'pat.parent@maestro.example'), 1::bigint,
  'existing parent invitation creates no duplicate Auth account');
select is((select count(*) from public.profiles p join auth.users u
  on u.id = p.id where u.email = 'pat.parent@maestro.example'), 1::bigint,
  'existing parent invitation creates no duplicate profile');
select is((select count(*) from public.parent_students where
  parent_user_id = '10000000-0000-0000-0000-000000000021' and active),
  2::bigint, 'Pat has two active child links');
select is((select count(*) from public.parent_access where
  parent_user_id = '10000000-0000-0000-0000-000000000021' and active),
  2::bigint, 'Pat has one teacher grant per child');

set local role authenticated;
select set_config('request.jwt.claim.sub',
  '10000000-0000-0000-0000-000000000021', true);
select is(jsonb_array_length(public.maestro_parent_portal_data()), 2,
  'parent portal lists exactly two authorized children');
select ok(exists (select 1 from jsonb_array_elements(
  public.maestro_parent_portal_data()) as rows(portal)
  where portal->>'studentId' = '30000000-0000-0000-0000-000000000011')
  and exists (select 1 from jsonb_array_elements(
  public.maestro_parent_portal_data()) as rows(portal)
  where portal->>'studentId' = '30000000-0000-0000-0000-000000000013'),
  'portal includes Aria and Nora');
select is((select count(distinct portal->>'teacherId') from
  jsonb_array_elements(public.maestro_parent_portal_data()) as rows(portal)),
  2::bigint, 'children may have different teachers');
select ok(exists (select 1 from public.payments where app_id = 201)
  and exists (select 1 from public.payments where app_id = 202)
  and not exists (select 1 from public.payments where id =
    current_setting('maestro.test.leo_payment_id')::uuid),
  'direct payment RLS permits only Pat authorized children');
select is((select sum((payment->>'amount')::numeric) from
  jsonb_array_elements(public.maestro_parent_portal_data()) as rows(portal)
  cross join lateral jsonb_array_elements(portal->'payments')
    as payments(payment)),
  current_setting('maestro.test.expected_payments')::numeric,
  'combined payment summary includes only authorized children');
select is((select sum((portal->>'balance')::numeric) from
  jsonb_array_elements(public.maestro_parent_portal_data()) as rows(portal)),
  current_setting('maestro.test.expected_balance')::numeric,
  'combined balance retains teacher-specific calculations');
select ok((public.get_student_finances(
  '30000000-0000-0000-0000-000000000013')->>'coursePrice')::numeric >= 0,
  'Pat can read Nora finances after accepting Ben invitation');
select is((select count(*) from public.payments where id =
  current_setting('maestro.test.leo_payment_id')::uuid),
  0::bigint, 'Pat cannot read unrelated Leo payment directly');
select is((select count(*) from public.students where app_id = 12),
  0::bigint, 'Pat cannot read unrelated Leo student directly');
select throws_ok($$select public.get_student_finances(
  '30000000-0000-0000-0000-000000000012')$$,
  '42501', 'Financial access denied',
  'Pat cannot retrieve unrelated Leo financial fields by RPC');

select set_config('request.jwt.claim.sub',
  '10000000-0000-0000-0000-000000000001', true);
select set_config('maestro.test.ren_aria_token',
  public.maestro_invite_parent(11, 'ren.parent@maestro.example',
    'Ren Parent')->>'token', true);
select set_config('request.jwt.claim.sub',
  '10000000-0000-0000-0000-000000000022', true);
select is(public.maestro_accept_parent_invitation(
  current_setting('maestro.test.ren_aria_token'))->>'studentId',
  '30000000-0000-0000-0000-000000000011',
  'Ren accepts access to Aria alongside Pat');
select is(jsonb_array_length(public.maestro_parent_portal_data()), 3,
  'Ren retains two Ben children plus Aria from Ada');

reset role;
select is((select count(*) from public.parent_access where student_id =
  '30000000-0000-0000-0000-000000000011' and active
  and parent_user_id in ('10000000-0000-0000-0000-000000000021',
    '10000000-0000-0000-0000-000000000022')), 2::bigint,
  'one child can have two active authorized parents');

set local role authenticated;
select set_config('request.jwt.claim.sub',
  '10000000-0000-0000-0000-000000000001', true);
select public.maestro_remove_parent_access(11,
  '10000000-0000-0000-0000-000000000022');
select set_config('request.jwt.claim.sub',
  '10000000-0000-0000-0000-000000000022', true);
select is(jsonb_array_length(public.maestro_parent_portal_data()), 2,
  'revoking Ren from Aria preserves Ren access to Nora and Owen');
select set_config('request.jwt.claim.sub',
  '10000000-0000-0000-0000-000000000021', true);
select is(jsonb_array_length(public.maestro_parent_portal_data()), 2,
  'revoking Ren does not affect Pat access');

select set_config('request.jwt.claim.sub',
  '10000000-0000-0000-0000-000000000002', true);
select public.maestro_remove_parent_access(13,
  '10000000-0000-0000-0000-000000000021');
select set_config('request.jwt.claim.sub',
  '10000000-0000-0000-0000-000000000021', true);
select is(jsonb_array_length(public.maestro_parent_portal_data()), 1,
  'revoking Nora preserves Pat access to Aria');
select ok(exists (select 1 from public.payments where app_id = 201)
  and not exists (select 1 from public.payments where app_id = 202),
  'Nora payment is hidden immediately after revocation');
select throws_ok($$select public.get_student_finances(
  '30000000-0000-0000-0000-000000000013')$$,
  '42501', 'Financial access denied',
  'revoked parent cannot call Nora finance RPC');
select is((select count(*) from public.students where app_id = 13),
  0::bigint, 'revoked parent cannot read Nora student directly');
select set_config('request.jwt.claim.sub',
  '10000000-0000-0000-0000-000000000022', true);
select is(jsonb_array_length(public.maestro_parent_portal_data()), 2,
  'Ren remains linked to Nora and Owen after Pat is removed');

select * from finish();
rollback;
