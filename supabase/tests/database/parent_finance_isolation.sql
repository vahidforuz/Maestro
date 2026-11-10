begin;
create extension if not exists pgtap with schema extensions;
set local search_path = public, extensions;
select plan(34);

select ok(not exists (select 1 from public.parent_students
  where parent_user_id = '10000000-0000-0000-0000-000000000021'
    and student_id = '30000000-0000-0000-0000-000000000012' and active),
  'Pat is no longer linked to unrelated Leo in local data');

-- Keep the historical demo relationship inactive and shape Ren into a
-- one-child parent for this transaction. The rollback restores Ren's grant.
update public.parent_access set active = false
  where parent_user_id = '10000000-0000-0000-0000-000000000022'
    and student_id = '30000000-0000-0000-0000-000000000014';
update public.parent_students set active = false
  where parent_user_id = '10000000-0000-0000-0000-000000000022'
    and student_id = '30000000-0000-0000-0000-000000000014';

insert into public.payments(id, app_id, student_id, teacher_id, amount, payment_date)
values ('60000000-0000-0000-0000-000000000012', 99012,
  '30000000-0000-0000-0000-000000000012',
  '20000000-0000-0000-0000-000000000001', 25, current_date)
on conflict (id) do nothing;

select ok((select relrowsecurity from pg_class where oid =
  'public.payments'::regclass), 'payment rows keep RLS enabled');
select ok(not has_table_privilege('authenticated', 'public.payments', 'INSERT'),
  'parents cannot insert payment rows through REST');
select ok(not has_table_privilege('authenticated', 'public.payments', 'UPDATE'),
  'parents cannot update payment rows through REST');
select ok(not has_table_privilege('authenticated', 'public.payments', 'DELETE'),
  'parents cannot delete payment rows through REST');

set local role authenticated;
select set_config('request.jwt.claim.sub',
  '10000000-0000-0000-0000-000000000021', true);
select is((select array_agg(app_id order by app_id) from public.payments),
  array[201::bigint], 'parent A sees only their linked student payment');
select is(jsonb_array_length(public.maestro_parent_portal_data()), 1,
  'parent A selector contains only student A');
select is((select count(*) from public.students where app_id = 12), 0::bigint,
  'parent A cannot read unrelated Leo student record');
select is((select count(*) from public.payments where app_id = 99012), 0::bigint,
  'parent A cannot read unrelated Leo payment by direct row query');
select is((select count(*) from jsonb_array_elements(
  public.maestro_parent_portal_data()) as portal_rows(portal)
  where portal->>'studentId' = '30000000-0000-0000-0000-000000000012'),
  0::bigint, 'parent A portal excludes Leo payment summary');
select is((select count(*) from jsonb_array_elements(
  public.maestro_parent_portal_data()) as portal_rows(portal) where portal->>'studentId' =
  '30000000-0000-0000-0000-000000000013'), 0::bigint,
  'parent A portal excludes parent B student');
select is((select count(*) from public.lessons where student_id =
  '30000000-0000-0000-0000-000000000013'), 0::bigint,
  'parent A cannot read parent B lesson fees directly');
select is((select (portal->>'balance')::numeric from jsonb_array_elements(
  public.maestro_parent_portal_data()) as portal_rows(portal) where portal->>'studentId' =
  '30000000-0000-0000-0000-000000000011'),
  0::numeric, 'parent A balance uses the existing teacher/student arithmetic');
select ok((select jsonb_array_length(portal->'fees') > 0 from
  jsonb_array_elements(public.maestro_parent_portal_data()) as portal_rows(portal)
  where portal->>'studentId' = '30000000-0000-0000-0000-000000000011'),
  'parent A sees authorized lesson fees');
select throws_ok($$select public.get_student_finances(
  '30000000-0000-0000-0000-000000000013')$$,
  '42501', 'Financial access denied',
  'legacy finance RPC rejects parent B student');

select set_config('request.jwt.claim.sub',
  '10000000-0000-0000-0000-000000000022', true);
select is((select count(*) from public.payments), 0::bigint,
  'parent B initially has no finance permission');
select is(jsonb_array_length(public.maestro_parent_portal_data()), 1,
  'parent B selector contains only student B');
select is((select portal->>'balance' from jsonb_array_elements(
  public.maestro_parent_portal_data()) as portal_rows(portal) where portal->>'studentId' =
  '30000000-0000-0000-0000-000000000013'), null::text,
  'parent B balance is hidden without finance permission');
select is((select jsonb_array_length(portal->'fees') from jsonb_array_elements(
  public.maestro_parent_portal_data()) as portal_rows(portal) where portal->>'studentId' =
  '30000000-0000-0000-0000-000000000013'), 0,
  'parent B lesson fees are hidden without finance permission');

reset role;
insert into public.parent_access(teacher_id, student_id, parent_user_id)
values ('20000000-0000-0000-0000-000000000002',
  '30000000-0000-0000-0000-000000000013',
  '10000000-0000-0000-0000-000000000021')
on conflict (teacher_id, student_id, parent_user_id) do update set active = true;
set local role authenticated;
select set_config('request.jwt.claim.sub',
  '10000000-0000-0000-0000-000000000021', true);
select is((select count(*) from public.students where app_id = 13), 0::bigint,
  'an orphan teacher grant cannot expose another student record');
select is((select array_agg(app_id order by app_id) from public.payments),
  array[201::bigint], 'teacher grant alone cannot expose another student');
select is((select count(*) from jsonb_array_elements(
  public.maestro_parent_portal_data()) as portal_rows(portal) where portal->>'studentId' =
  '30000000-0000-0000-0000-000000000013'), 0::bigint,
  'portal also requires an active parent/student link');

reset role;
insert into public.parent_students(parent_user_id, student_id, active,
  can_view_finances) values ('10000000-0000-0000-0000-000000000021',
  '30000000-0000-0000-0000-000000000013', true, true)
on conflict (parent_user_id, student_id) do update set active = true,
  can_view_finances = true;
set local role authenticated;
select set_config('request.jwt.claim.sub',
  '10000000-0000-0000-0000-000000000021', true);
select is((select array_agg(app_id order by app_id) from public.payments),
  array[201::bigint, 202::bigint],
  'parent C sees payments for both explicitly linked students');
select is(jsonb_array_length(public.maestro_parent_portal_data()), 2,
  'parent C selector contains both authorized students');
select is((select sum((portal->>'balance')::numeric) from
  jsonb_array_elements(public.maestro_parent_portal_data())
  as portal_rows(portal)), -30::numeric,
  'parent C aggregate balance includes only authorized students');
select is((select sum((payment->>'amount')::numeric) from
  jsonb_array_elements(public.maestro_parent_portal_data())
  as portal_rows(portal)
  cross join lateral jsonb_array_elements(portal->'payments')
  as payment_rows(payment)), 160::numeric,
  'parent C payment history includes only authorized students');
select is((select count(*) from jsonb_array_elements(
  public.maestro_parent_portal_data()) as portal_rows(portal) where portal->>'studentId' =
  '30000000-0000-0000-0000-000000000013'), 1::bigint,
  'parent C portal includes the newly authorized student');

select set_config('request.jwt.claim.sub',
  '10000000-0000-0000-0000-000000000002', true);
select public.maestro_remove_parent_access(13,
  '10000000-0000-0000-0000-000000000021');
select set_config('request.jwt.claim.sub',
  '10000000-0000-0000-0000-000000000021', true);
select is((select array_agg(app_id order by app_id) from public.payments),
  array[201::bigint], 'revocation immediately hides payment history');
select is((select count(*) from jsonb_array_elements(
  public.maestro_parent_portal_data()) as portal_rows(portal) where portal->>'studentId' =
  '30000000-0000-0000-0000-000000000013'), 0::bigint,
  'revocation immediately hides portal balances and fees');

reset role;
update public.parent_students set can_view_finances = true
  where parent_user_id = '10000000-0000-0000-0000-000000000022'
    and student_id = '30000000-0000-0000-0000-000000000013';
update public.parent_access set can_view_finances = true
  where parent_user_id = '10000000-0000-0000-0000-000000000022'
    and student_id = '30000000-0000-0000-0000-000000000013';
set local role authenticated;
select set_config('request.jwt.claim.sub',
  '10000000-0000-0000-0000-000000000022', true);
select is((select array_agg(app_id order by app_id) from public.payments),
  array[202::bigint], 'parent B sees only parent B student payment');
select is((select count(*) from public.payments where app_id = 201), 0::bigint,
  'parent B cannot read parent A payment by direct row query');

select set_config('request.jwt.claim.sub',
  '10000000-0000-0000-0000-000000000011', true);
select is(public.maestro_parent_portal_data(), '[]'::jsonb,
  'account without parent links has no parent portal records');

select set_config('request.jwt.claim.sub',
  '10000000-0000-0000-0000-000000000001', true);
select ok(exists (select 1 from public.payments where app_id = 201)
  and not exists (select 1 from public.payments where app_id = 202),
  'teacher A keeps their payments without seeing teacher B payments');
select set_config('request.jwt.claim.sub',
  '10000000-0000-0000-0000-000000000002', true);
select ok(exists (select 1 from public.payments where app_id = 202)
  and not exists (select 1 from public.payments where app_id = 201),
  'teacher B keeps their payments without seeing teacher A payments');

select * from finish();
rollback;
