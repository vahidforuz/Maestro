begin;
create extension if not exists pgtap with schema extensions;
set local search_path = public, extensions;
select plan(6);

select ok((select relrowsecurity from pg_class
  where oid = 'public.student_portal_access'::regclass),
  'portal grants have RLS');
select ok((select relrowsecurity from pg_class
  where oid = 'public.teacher_piece_progress'::regclass),
  'piece progress has RLS');
select ok(not has_table_privilege('authenticated',
  'public.teacher_piece_progress', 'UPDATE'),
  'students cannot directly update piece progress');
select is((select pg_get_expr(d.adbin, d.adrelid) from pg_attrdef d
  join pg_attribute a on a.attrelid = d.adrelid and a.attnum = d.adnum
  where d.adrelid = 'public.student_portal_access'::regclass
    and a.attname = 'view_payments'),
  'false', 'payment permission defaults off');

set local role authenticated;
select set_config('request.jwt.claim.sub',
  '10000000-0000-0000-0000-000000000001', true);
select public.maestro_unlink_student_access(12);
select set_config('maestro.test.invitation',
  (public.maestro_invite_student(12, 'aria.student@maestro.example')->>'token'), true);
select set_config('request.jwt.claim.sub',
  '10000000-0000-0000-0000-000000000011', true);
select public.maestro_accept_student_invitation(current_setting('maestro.test.invitation'));
select throws_ok(
  'select public.maestro_accept_student_invitation(current_setting(''maestro.test.invitation''))',
  '42501', 'Invitation is invalid or expired', 'accepted token cannot be reused');

select set_config('request.jwt.claim.sub',
  '10000000-0000-0000-0000-000000000001', true);
select set_config('maestro.test.expired',
  (public.maestro_invite_student(12, 'aria.student@maestro.example')->>'token'), true);
reset role;
update public.student_invitations set expires_at = now() - interval '1 second'
  where token_hash = encode(extensions.digest(
    current_setting('maestro.test.expired'), 'sha256'), 'hex');
set local role authenticated;
select set_config('request.jwt.claim.sub',
  '10000000-0000-0000-0000-000000000011', true);
select throws_ok(
  'select public.maestro_accept_student_invitation(current_setting(''maestro.test.expired''))',
  '42501', 'Invitation is invalid or expired', 'expired token cannot be accepted');

select * from finish();
rollback;
