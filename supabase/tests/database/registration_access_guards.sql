begin;
create extension if not exists pgtap with schema extensions;
set local search_path = public, extensions;
select plan(12);

insert into auth.users (instance_id, id, aud, role, email, encrypted_password,
  email_confirmed_at, confirmation_token, recovery_token, email_change_token_new,
  email_change, email_change_token_current, reauthentication_token,
  raw_app_meta_data, raw_user_meta_data, created_at, updated_at)
values ('00000000-0000-0000-0000-000000000000'::uuid,
  '90000000-0000-0000-0000-000000000010'::uuid, 'authenticated',
  'authenticated', 'unverified.teacher@maestro.example',
  extensions.crypt('LocalMaestro123!', extensions.gen_salt('bf')),
  null, '', '', '', '', '', '',
  '{"provider":"email","providers":["email"]}'::jsonb,
  '{}'::jsonb, now(), now());

select ok((select relrowsecurity from pg_class where oid =
  'public.payments'::regclass), 'payments use RLS');
select ok(not has_table_privilege('authenticated', 'public.parent_students', 'INSERT'),
  'an authenticated user cannot insert a parent relationship');
select ok(not has_table_privilege('authenticated', 'public.teacher_students', 'INSERT'),
  'an authenticated user cannot insert a teacher relationship');
select ok(not has_column_privilege('authenticated', 'public.profiles', 'role', 'UPDATE'),
  'role cannot be changed through the Data API');

select ok(public.maestro_before_user_created(jsonb_build_object('user',
  jsonb_build_object('email', 'new@maestro.example',
    'user_metadata', jsonb_build_object('maestro_signup_kind', 'teacher'))))
  -> 'error' is null, 'public teacher intent is accepted');
select ok(public.maestro_before_user_created(jsonb_build_object('user',
  jsonb_build_object('email', 'new@maestro.example',
    'user_metadata', '{}'::jsonb))) -> 'error' is not null,
  'direct signup without registration intent is rejected');
select ok(public.maestro_before_user_created(jsonb_build_object('user',
  jsonb_build_object('email', 'new@maestro.example',
    'user_metadata', jsonb_build_object('maestro_signup_kind', 'student',
      'maestro_invitation_token', 'invalid')))) -> 'error' is not null,
  'direct student signup with an invalid token is rejected');

set local role authenticated;
select set_config('request.jwt.claim.sub',
  '10000000-0000-0000-0000-000000000001', true);
select set_config('maestro.test.student_invite',
  public.maestro_invite_student(12, 'new.student@maestro.example')->>'token', true);
select set_config('maestro.test.parent_invite',
  public.maestro_invite_parent(12, 'new.parent@maestro.example', 'New Parent')->>'token', true);
reset role;
select ok(public.maestro_before_user_created(jsonb_build_object('user',
  jsonb_build_object('email', 'new.student@maestro.example',
    'user_metadata', jsonb_build_object('maestro_signup_kind', 'student',
      'maestro_invitation_token', current_setting('maestro.test.student_invite')))))
  -> 'error' is null, 'valid student invitation permits Auth signup');
select ok(public.maestro_before_user_created(jsonb_build_object('user',
  jsonb_build_object('email', 'new.parent@maestro.example',
    'user_metadata', jsonb_build_object('maestro_signup_kind', 'parent',
      'maestro_invitation_token', current_setting('maestro.test.parent_invite')))))
  -> 'error' is null, 'valid parent invitation permits Auth signup');

set local role authenticated;
select set_config('request.jwt.claim.sub',
  '90000000-0000-0000-0000-000000000010', true);
select throws_ok($$select public.register_teacher('Unverified','Teacher',null)$$,
  '42501', 'Confirm your email before registering as a teacher',
  'unverified user cannot create teacher profile');
select is((select role from public.profiles where id = auth.uid()), 'user',
  'failed registration does not assign teacher role');
select is((select count(*) from public.teachers where user_id = auth.uid()),
  0::bigint, 'failed registration does not create teacher');
select * from finish();
rollback;
