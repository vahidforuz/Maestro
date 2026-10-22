begin;
create extension if not exists pgtap with schema extensions;
set local search_path = public, extensions;
select plan(4);

insert into auth.users (instance_id, id, aud, role, email, encrypted_password,
  email_confirmed_at, confirmation_token, recovery_token, email_change_token_new,
  email_change, email_change_token_current, reauthentication_token,
  raw_app_meta_data, raw_user_meta_data, created_at, updated_at)
values ('00000000-0000-0000-0000-000000000000'::uuid,
  '90000000-0000-0000-0000-000000000001'::uuid, 'authenticated',
  'authenticated', 'new.teacher@maestro.example',
  extensions.crypt('LocalMaestro123!', extensions.gen_salt('bf')),
  now(), '', '', '', '', '', '', '{"provider":"email","providers":["email"]}'::jsonb,
  '{}'::jsonb, now(), now());

set local role authenticated;
select set_config('request.jwt.claim.sub',
  '90000000-0000-0000-0000-000000000001', true);
select is((public.register_teacher_with_contact('New', 'Teacher', null,
  'contact@maestro.example') ->> 'name'),
  'New Teacher', 'new Auth user can create own teacher profile');
select is((select email from public.teachers where user_id = auth.uid()),
  'contact@maestro.example', 'contact email is saved separately from Auth login');
select is((select role from public.profiles where id = auth.uid()),
  'teacher', 'teacher onboarding updates only its Auth profile');
select throws_ok(
  'select public.register_teacher(''Another'', ''Teacher'', null)',
  '42501', 'Teacher registration is not available for this account',
  'same account cannot register as another teacher');
rollback;
