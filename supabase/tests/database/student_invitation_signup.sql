begin;
create extension if not exists pgtap with schema extensions;
set local search_path = public, extensions;
select plan(5);

set local role authenticated;
select set_config('request.jwt.claim.sub',
  '10000000-0000-0000-0000-000000000001', true);
select set_config('maestro.test.signup_token',
  (public.maestro_invite_student(12, 'aria.student@maestro.example')->>'token'), true);

select ok(public.maestro_check_student_invitation(
  current_setting('maestro.test.signup_token'), 'aria.student@maestro.example'),
  'invited email can sign up with a current token');
select ok(not public.maestro_check_student_invitation(
  current_setting('maestro.test.signup_token'), 'other@maestro.example'),
  'another email cannot use the token');
select ok(not public.maestro_check_student_invitation(
  'incorrect', 'aria.student@maestro.example'),
  'unknown token is rejected');

reset role;
update public.student_invitations set expires_at = now() - interval '1 second'
  where token_hash = encode(extensions.digest(
    current_setting('maestro.test.signup_token'), 'sha256'), 'hex');
set local role authenticated;
select ok(not public.maestro_check_student_invitation(
  current_setting('maestro.test.signup_token'), 'aria.student@maestro.example'),
  'expired token is rejected');

select set_config('request.jwt.claim.sub',
  '10000000-0000-0000-0000-000000000011', true);
select throws_ok(
  'select public.maestro_accept_student_invitation(current_setting(''maestro.test.signup_token''))',
  '42501', 'Invitation is invalid or expired',
  'expired token cannot link an account');

select * from finish();
rollback;
