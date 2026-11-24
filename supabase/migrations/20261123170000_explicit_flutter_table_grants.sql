-- RLS decides which rows a caller may see, but PostgreSQL first requires a
-- table/column privilege. Local and hosted projects must not depend on their
-- different default privileges for Flutter's direct PostgREST queries.

-- Role resolution reads the signed-in user's teacher row and profile role.
-- Teacher settings still update only the reviewed columns, now including the
-- timezone field used by the existing Settings form.
revoke select on public.profiles from public, anon, authenticated;
revoke insert, delete, update on public.profiles from public, anon, authenticated;
grant select (id, display_name, role) on public.profiles to authenticated;
grant update (display_name) on public.profiles to authenticated;

revoke select, insert, update, delete on public.teachers
  from public, anon, authenticated;
grant select on public.teachers to authenticated;
grant update (name, first_name, last_name, studio_name, email, telephone,
  address, city, postal_code, main_instrument, other_instruments,
  default_lesson_duration, default_lesson_price, currency, profile_image_path,
  timezone, updated_at) on public.teachers to authenticated;

-- Teacher-owned calendar tables are edited directly by Flutter. Their
-- existing owner RLS policies remain the authorization boundary.
revoke all on public.teacher_availability_rules,
  public.teacher_availability_exceptions, public.teacher_time_blocks,
  public.teacher_time_block_exceptions from public, anon, authenticated;
grant select, insert, update, delete on public.teacher_availability_rules,
  public.teacher_availability_exceptions, public.teacher_time_blocks,
  public.teacher_time_block_exceptions to authenticated;

-- A teacher may read their own sharing links and revoke one, but creation is
-- through the checked RPC. Its token hash is not a direct client column.
revoke select, update on public.availability_share_links
  from public, anon, authenticated;
grant select (id, teacher_id, created_at, expires_at, range_from,
  range_until, revoked_at) on public.availability_share_links to authenticated;
grant update (revoked_at) on public.availability_share_links to authenticated;

-- Existing row policies restrict lessons and notes by teacher relationship;
-- the final lessons policy also requires a parent's finance grant. Pieces are
-- relationship-scoped. Student/project financial columns remain under their
-- earlier column grants and are deliberately untouched here.
-- All student, project, lesson, piece, and note writes use checked RPCs.
revoke insert, update, delete on public.students, public.projects,
  public.lessons, public.pieces, public.lesson_notes
  from public, anon, authenticated;
revoke select on public.lessons, public.pieces, public.lesson_notes
  from public, anon;
grant select on public.lessons, public.pieces, public.lesson_notes
  to authenticated;

-- Payment reads need only the fields used by Flutter and the security tests.
-- Keep payment writes RPC-only and do not expose request keys or corrections.
revoke select on public.payments from public, anon, authenticated;
grant select (id, app_id, student_id, amount, payment_date, method, note)
  on public.payments to authenticated;
