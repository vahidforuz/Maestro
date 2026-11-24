begin;
create extension if not exists pgtap with schema extensions;
set local search_path = public, extensions;
select plan(55);

select ok((select relrowsecurity from pg_class where oid =
  'public.teachers'::regclass), 'teacher RLS remains enabled');
select ok((select relrowsecurity from pg_class where oid =
  'public.profiles'::regclass), 'profile RLS remains enabled');
select ok((select relrowsecurity from pg_class where oid =
  'public.lessons'::regclass), 'lesson RLS remains enabled');
select ok((select relrowsecurity from pg_class where oid =
  'public.payments'::regclass), 'payment RLS remains enabled');

-- These checks catch a hosted project that lacks the implicit table grants
-- present in some local Supabase configurations.
select ok(has_table_privilege('authenticated', 'public.teachers', 'SELECT'),
  'role resolution can read the own-teacher table');
select ok(not has_table_privilege('authenticated', 'public.teachers', 'INSERT'),
  'teacher creation remains RPC-only');
select ok(not has_table_privilege('authenticated', 'public.teachers', 'DELETE'),
  'teachers cannot delete a teacher row');
select ok(has_column_privilege('authenticated', 'public.teachers', 'timezone', 'UPDATE'),
  'settings can update timezone');
select ok(not has_column_privilege('authenticated', 'public.teachers', 'id', 'UPDATE'),
  'teacher identity cannot be changed');
select ok(not has_column_privilege('authenticated', 'public.teachers', 'user_id', 'UPDATE'),
  'teacher Auth ownership cannot be changed');

select ok(has_column_privilege('authenticated', 'public.profiles', 'role', 'SELECT'),
  'role resolution can read profile role');
select ok(has_column_privilege('authenticated', 'public.profiles', 'display_name', 'UPDATE'),
  'parent can edit own display name');
select ok(not has_column_privilege('authenticated', 'public.profiles', 'role', 'UPDATE'),
  'profile role cannot be edited');
select ok(not has_table_privilege('authenticated', 'public.profiles', 'INSERT'),
  'Auth trigger owns profile creation');

select ok(not has_column_privilege('authenticated', 'public.students', 'course_price', 'SELECT'),
  'generic student query cannot read course price');
select ok(not has_column_privilege('authenticated', 'public.students', 'payment_credit_balance', 'SELECT'),
  'generic student query cannot read payment credit');
select ok(not has_column_privilege('authenticated', 'public.projects', 'paid_course_count', 'SELECT'),
  'generic project query cannot read paid course count');
select ok(not has_table_privilege('authenticated', 'public.students', 'UPDATE'),
  'student writes remain checked RPCs');
select ok(not has_table_privilege('authenticated', 'public.projects', 'UPDATE'),
  'project writes remain checked RPCs');

select ok(has_column_privilege('authenticated', 'public.payments', 'amount', 'SELECT'),
  'authorized payment rows expose amount');
select ok(not has_column_privilege('authenticated', 'public.payments', 'request_key', 'SELECT'),
  'payment retry keys stay private');
select ok(not has_column_privilege('authenticated', 'public.payments', 'correction_of', 'SELECT'),
  'payment correction links stay private');
select ok(not has_table_privilege('authenticated', 'public.payments', 'INSERT'),
  'payments are inserted through the checked RPC');
select ok(not has_table_privilege('authenticated', 'public.payments', 'UPDATE'),
  'payments cannot be edited directly');
select ok(not has_table_privilege('authenticated', 'public.payments', 'DELETE'),
  'payments cannot be deleted directly');

select ok(has_table_privilege('authenticated', 'public.lessons', 'SELECT'),
  'calendar can read RLS-scoped lessons');
select ok(has_table_privilege('authenticated', 'public.pieces', 'SELECT'),
  'student profile can read RLS-scoped pieces');
select ok(has_table_privilege('authenticated', 'public.lesson_notes', 'SELECT'),
  'student profile can read RLS-scoped notes');
select ok(not has_table_privilege('authenticated', 'public.lessons', 'UPDATE'),
  'lesson writes remain checked RPCs');

select ok(has_table_privilege('authenticated', 'public.teacher_availability_rules', 'SELECT'),
  'teacher can read availability rules');
select ok(has_table_privilege('authenticated', 'public.teacher_availability_rules', 'INSERT'),
  'teacher can create an availability rule');
select ok(has_table_privilege('authenticated', 'public.teacher_availability_rules', 'UPDATE'),
  'teacher can edit an availability rule');
select ok(has_table_privilege('authenticated', 'public.teacher_availability_rules', 'DELETE'),
  'teacher can remove an availability rule');
select ok(has_table_privilege('authenticated', 'public.teacher_availability_exceptions', 'SELECT'),
  'teacher can read availability exceptions');
select ok(has_table_privilege('authenticated', 'public.teacher_time_blocks', 'SELECT'),
  'teacher can read time blocks');
select ok(has_table_privilege('authenticated', 'public.teacher_time_blocks', 'INSERT'),
  'teacher can create a time block');
select ok(has_table_privilege('authenticated', 'public.teacher_time_block_exceptions', 'SELECT'),
  'teacher can read time block exceptions');
select ok(has_column_privilege('authenticated', 'public.availability_share_links', 'id', 'SELECT'),
  'teacher can read own availability links');
select ok(not has_column_privilege('authenticated', 'public.availability_share_links', 'token_hash', 'SELECT'),
  'teacher cannot read availability token hashes');
select ok(has_column_privilege('authenticated', 'public.availability_share_links', 'revoked_at', 'UPDATE'),
  'teacher can revoke an availability link');
select ok(not has_column_privilege('authenticated', 'public.availability_share_links', 'token_hash', 'UPDATE'),
  'teacher cannot alter an availability token hash');

select ok(not has_table_privilege('anon', 'public.teachers', 'SELECT'),
  'anonymous callers cannot read teacher rows');
select ok(not has_column_privilege('anon', 'public.payments', 'amount', 'SELECT'),
  'anonymous callers cannot read payments');
select ok(not has_table_privilege('anon', 'public.lessons', 'SELECT'),
  'anonymous callers cannot read lessons');

-- Permission and RLS are both required: the grants must not cross studios.
set local role authenticated;
select set_config('request.jwt.claim.sub',
  '10000000-0000-0000-0000-000000000001', true);
select is((select count(*) from public.teachers), 1::bigint,
  'Ada sees exactly her own teacher row');
select is((select count(*) from public.teachers where user_id =
  '10000000-0000-0000-0000-000000000002'), 0::bigint,
  'Ada cannot read Ben teacher row');
select is((select count(*) from public.payments where app_id = 202), 0::bigint,
  'Ada cannot read Ben payment');
select is((select count(*) from public.students where app_id = 13), 0::bigint,
  'Ada cannot read Ben-only student');

select set_config('request.jwt.claim.sub',
  '10000000-0000-0000-0000-000000000002', true);
select is((select count(*) from public.teachers), 1::bigint,
  'Ben sees exactly his own teacher row');
select is((select count(*) from public.teachers where user_id =
  '10000000-0000-0000-0000-000000000001'), 0::bigint,
  'Ben cannot read Ada teacher row');
select is((select count(*) from public.payments where app_id = 201), 0::bigint,
  'Ben cannot read Ada payment');
select is((select count(*) from public.students where app_id = 11), 0::bigint,
  'Ben cannot read Ada-only student');

select set_config('request.jwt.claim.sub',
  '10000000-0000-0000-0000-000000000022', true);
select is((select count(*) from public.teachers), 0::bigint,
  'a parent cannot read teacher rows directly');
select is((select count(*) from public.payments), 0::bigint,
  'a parent without a finance grant cannot read payments');
select is((select count(*) from public.lessons), 0::bigint,
  'a parent without a finance grant cannot read lesson fees');
select * from finish();
rollback;
