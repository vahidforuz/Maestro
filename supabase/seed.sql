-- Synthetic local-only accounts, all with password LocalMaestro123!.
-- Never replace this file with real Maestro data or deploy it to a hosted project.
with demo_users(id, email, display_name) as (
  values
    ('10000000-0000-0000-0000-000000000001'::uuid, 'ada.teacher@maestro.example', 'Ada Teacher'),
    ('10000000-0000-0000-0000-000000000002'::uuid, 'ben.teacher@maestro.example', 'Ben Teacher'),
    ('10000000-0000-0000-0000-000000000011'::uuid, 'aria.student@maestro.example', 'Aria Student'),
    ('10000000-0000-0000-0000-000000000012'::uuid, 'nora.student@maestro.example', 'Nora Student'),
    ('10000000-0000-0000-0000-000000000021'::uuid, 'pat.parent@maestro.example', 'Pat Parent'),
    ('10000000-0000-0000-0000-000000000022'::uuid, 'ren.parent@maestro.example', 'Ren Parent')
)
insert into auth.users (instance_id, id, aud, role, email, encrypted_password,
  email_confirmed_at, confirmation_token, recovery_token, email_change_token_new,
  email_change, email_change_token_current, reauthentication_token,
  raw_app_meta_data, raw_user_meta_data, created_at, updated_at)
select '00000000-0000-0000-0000-000000000000'::uuid, id, 'authenticated',
  'authenticated', email, extensions.crypt('LocalMaestro123!', extensions.gen_salt('bf')),
  now(), '', '', '', '', '', '', '{"provider":"email","providers":["email"]}'::jsonb,
  jsonb_build_object('display_name', display_name), now(), now()
from demo_users on conflict (id) do nothing;

insert into auth.identities (provider_id, user_id, identity_data, provider, created_at, updated_at)
select id::text, id, jsonb_build_object('sub', id::text, 'email', email,
  'email_verified', true), 'email', now(), now()
from auth.users where id::text like '10000000-0000-0000-0000-0000000000%'
on conflict (provider_id, provider) do nothing;

update public.profiles set role = 'teacher' where id in
  ('10000000-0000-0000-0000-000000000001', '10000000-0000-0000-0000-000000000002');
update public.profiles set role = 'student' where id in
  ('10000000-0000-0000-0000-000000000011', '10000000-0000-0000-0000-000000000012');
update public.profiles set role = 'parent' where id in
  ('10000000-0000-0000-0000-000000000021', '10000000-0000-0000-0000-000000000022');

insert into public.teachers (id, app_id, user_id, name, first_name, last_name, email,
  default_lesson_duration, default_lesson_price) values
  ('20000000-0000-0000-0000-000000000001', 1, '10000000-0000-0000-0000-000000000001',
    'Ada Teacher', 'Ada', 'Teacher', 'ada.teacher@maestro.example', 60, 20),
  ('20000000-0000-0000-0000-000000000002', 2, '10000000-0000-0000-0000-000000000002',
    'Ben Teacher', 'Ben', 'Teacher', 'ben.teacher@maestro.example', 45, 30)
on conflict (id) do nothing;

insert into public.students (id, app_id, user_id, first_name, family_name, name,
  instrument, level, course_day, course_hour, course_price) values
  ('30000000-0000-0000-0000-000000000011', 11, '10000000-0000-0000-0000-000000000011',
    'Aria', 'Student', 'Aria Student', 'Piano', 'Beginner', 'MONDAY', '16:00', 20),
  ('30000000-0000-0000-0000-000000000012', 12, null,
    'Leo', 'Student', 'Leo Student', 'Piano', 'Intermediate', 'TUESDAY', '17:00', 20),
  ('30000000-0000-0000-0000-000000000013', 13, '10000000-0000-0000-0000-000000000012',
    'Nora', 'Student', 'Nora Student', 'Guitar', 'Beginner', 'WEDNESDAY', '16:00', 30),
  ('30000000-0000-0000-0000-000000000014', 14, null,
    'Owen', 'Student', 'Owen Student', 'Guitar', 'Intermediate', 'THURSDAY', '17:00', 30),
  ('30000000-0000-0000-0000-000000000015', 15, null,
    'Sam', 'Shared', 'Sam Shared', 'Voice', 'Beginner', 'FRIDAY', '15:00', 25)
on conflict (id) do nothing;

insert into public.teacher_students (teacher_id, student_id) values
  ('20000000-0000-0000-0000-000000000001', '30000000-0000-0000-0000-000000000011'),
  ('20000000-0000-0000-0000-000000000001', '30000000-0000-0000-0000-000000000012'),
  ('20000000-0000-0000-0000-000000000001', '30000000-0000-0000-0000-000000000015'),
  ('20000000-0000-0000-0000-000000000002', '30000000-0000-0000-0000-000000000013'),
  ('20000000-0000-0000-0000-000000000002', '30000000-0000-0000-0000-000000000014'),
  ('20000000-0000-0000-0000-000000000002', '30000000-0000-0000-0000-000000000015')
on conflict (teacher_id, student_id) do nothing;

insert into public.parent_students (parent_user_id, student_id, can_view_finances) values
  ('10000000-0000-0000-0000-000000000021', '30000000-0000-0000-0000-000000000011', true),
  ('10000000-0000-0000-0000-000000000021', '30000000-0000-0000-0000-000000000012', true),
  ('10000000-0000-0000-0000-000000000022', '30000000-0000-0000-0000-000000000013', false),
  ('10000000-0000-0000-0000-000000000022', '30000000-0000-0000-0000-000000000014', false)
on conflict (parent_user_id, student_id) do nothing;

insert into public.projects (id, app_id, student_id, name, paid_course_count) values
  ('40000000-0000-0000-0000-000000000011', 101, '30000000-0000-0000-0000-000000000011', 'Piano foundations', 5),
  ('40000000-0000-0000-0000-000000000012', 102, '30000000-0000-0000-0000-000000000012', 'Piano repertoire', 0),
  ('40000000-0000-0000-0000-000000000013', 103, '30000000-0000-0000-0000-000000000013', 'Guitar foundations', 2),
  ('40000000-0000-0000-0000-000000000014', 104, '30000000-0000-0000-0000-000000000014', 'Guitar repertoire', 0),
  ('40000000-0000-0000-0000-000000000015', 105, '30000000-0000-0000-0000-000000000015', 'Voice basics', 0)
on conflict (id) do nothing;

insert into public.lessons (id, app_id, student_id, project_id, teacher_id, title,
  lesson_date, hour, duration_minutes, price, status, sort_order)
select ('50000000-0000-0000-0000-' || lpad(n::text, 12, '0'))::uuid,
  1000 + n, '30000000-0000-0000-0000-000000000011',
  '40000000-0000-0000-0000-000000000011', '20000000-0000-0000-0000-000000000001',
  'Piano lesson ' || n, current_date + (n * 7), '16:00', 60, 20, 'NOTHING', n
from generate_series(1, 5) as n on conflict (id) do nothing;

insert into public.lessons (id, app_id, student_id, project_id, teacher_id, title,
  lesson_date, hour, duration_minutes, price, status) values
  ('50000000-0000-0000-0000-000000000013', 1013, '30000000-0000-0000-0000-000000000013',
    '40000000-0000-0000-0000-000000000013', '20000000-0000-0000-0000-000000000002',
    'Guitar lesson', current_date + 7, '16:00', 45, 30, 'PRESENT')
on conflict (id) do nothing;

insert into public.lesson_notes (id, app_id, student_id, lesson_id, teacher_id,
  piece, comment, created_date, review_weeks, review_date, review_status) values
  ('70000000-0000-0000-0000-000000000011', 301, '30000000-0000-0000-0000-000000000011',
    '50000000-0000-0000-0000-000000000001', '20000000-0000-0000-0000-000000000001',
    'C major scale', 'Practice slowly', current_date, 1, current_date + 7, 'PENDING'),
  ('70000000-0000-0000-0000-000000000013', 302, '30000000-0000-0000-0000-000000000013',
    '50000000-0000-0000-0000-000000000013', '20000000-0000-0000-0000-000000000002',
    'Open chords', 'Switch cleanly', current_date, 1, current_date + 7, 'PENDING')
on conflict (id) do nothing;

insert into public.payments (id, app_id, student_id, teacher_id, amount, payment_date, method, note) values
  ('60000000-0000-0000-0000-000000000011', 201, '30000000-0000-0000-0000-000000000011',
    '20000000-0000-0000-0000-000000000001', 100, current_date, 'CASH', 'Five $20 lessons'),
  ('60000000-0000-0000-0000-000000000013', 202, '30000000-0000-0000-0000-000000000013',
    '20000000-0000-0000-0000-000000000002', 60, current_date, 'CARD', 'Two $30 lessons')
on conflict (id) do nothing;

select setval(pg_get_serial_sequence('public.teachers', 'app_id'), 2, true);
select setval(pg_get_serial_sequence('public.students', 'app_id'), 15, true);
select setval(pg_get_serial_sequence('public.projects', 'app_id'), 105, true);
select setval(pg_get_serial_sequence('public.lessons', 'app_id'), 1013, true);
select setval(pg_get_serial_sequence('public.lesson_notes', 'app_id'), 302, true);
select setval(pg_get_serial_sequence('public.payments', 'app_id'), 202, true);
