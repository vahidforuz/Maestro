-- Public teacher onboarding becomes active only after Supabase verifies the
-- Auth email. Existing teacher records and identities are left untouched.
create or replace function public.register_teacher(
  p_first_name text, p_last_name text, p_telephone text default null
)
returns jsonb language plpgsql security definer set search_path = '' as $$
declare
  v_user_id uuid := auth.uid();
  v_email text;
  v_role text;
  v_teacher public.teachers%rowtype;
  v_name text;
begin
  if v_user_id is null then
    raise exception 'Authentication required' using errcode = '28000';
  end if;
  select role into v_role from public.profiles where id = v_user_id for update;
  if v_role is distinct from 'user' then
    raise exception 'Teacher registration is not available for this account'
      using errcode = '42501';
  end if;
  select email into v_email from auth.users
    where id = v_user_id and email_confirmed_at is not null;
  if v_email is null then
    raise exception 'Confirm your email before registering as a teacher'
      using errcode = '42501';
  end if;
  v_name := trim(coalesce(p_first_name, '') || ' ' || coalesce(p_last_name, ''));
  if v_name = '' then
    raise exception 'Teacher name is required' using errcode = '22023';
  end if;
  if exists (select 1 from public.teachers where user_id = v_user_id) then
    raise exception 'Teacher profile already exists' using errcode = '23505';
  end if;
  update public.profiles set display_name = v_name, role = 'teacher',
    updated_at = now() where id = v_user_id;
  insert into public.teachers (user_id, name, first_name, last_name, telephone, email)
  values (v_user_id, v_name, trim(coalesce(p_first_name, '')),
          trim(coalesce(p_last_name, '')), p_telephone, v_email)
  returning * into v_teacher;
  return jsonb_build_object(
    'id', v_teacher.app_id, 'name', v_teacher.name,
    'firstName', v_teacher.first_name, 'lastName', v_teacher.last_name,
    'telephone', v_teacher.telephone, 'email', v_teacher.email,
    'address', v_teacher.address, 'status', v_teacher.status,
    'studioName', v_teacher.studio_name, 'city', v_teacher.city,
    'postalCode', v_teacher.postal_code,
    'mainInstrument', v_teacher.main_instrument,
    'otherInstruments', v_teacher.other_instruments,
    'defaultLessonDuration', v_teacher.default_lesson_duration,
    'defaultLessonPrice', v_teacher.default_lesson_price,
    'currency', v_teacher.currency,
    'profileImagePath', v_teacher.profile_image_path
  );
end;
$$;

-- Supabase Auth calls this before inserting an identity. The metadata is
-- untrusted; only a valid teacher intent or a live invitation permits signup.
create function public.maestro_before_user_created(event jsonb)
returns jsonb language plpgsql set search_path = '' as $$
declare
  v_kind text := event -> 'user' -> 'user_metadata' ->> 'maestro_signup_kind';
  v_email text := event -> 'user' ->> 'email';
  v_token text := event -> 'user' -> 'user_metadata' ->> 'maestro_invitation_token';
begin
  if v_kind = 'teacher' then
    return '{}'::jsonb;
  end if;
  if v_kind = 'student' and
      public.maestro_check_student_invitation(v_token, v_email) then
    return '{}'::jsonb;
  end if;
  if v_kind = 'parent' and
      public.maestro_check_parent_invitation(v_token, v_email) then
    return '{}'::jsonb;
  end if;
  return jsonb_build_object('error', jsonb_build_object(
    'http_code', 403, 'message', 'A valid Maestro invitation is required.'));
end;
$$;
revoke all on function public.maestro_before_user_created(jsonb) from public;
grant usage on schema public to supabase_auth_admin;
grant execute on function public.maestro_before_user_created(jsonb),
  public.maestro_check_student_invitation(text,text),
  public.maestro_check_parent_invitation(text,text)
  to supabase_auth_admin;

alter table public.parent_invitations
  add column relationship text not null default 'Other'
  check (relationship in ('Mother', 'Father', 'Guardian', 'Other'));

create function public.maestro_invite_parent(
  p_student_app_id bigint, p_email text, p_name text, p_relationship text
)
returns jsonb language plpgsql security definer set search_path = '' as $$
declare v_result jsonb;
begin
  if p_relationship not in ('Mother', 'Father', 'Guardian', 'Other') then
    raise exception 'Invalid relationship' using errcode = '22023';
  end if;
  v_result := public.maestro_invite_parent(p_student_app_id, p_email, p_name);
  update public.parent_invitations set relationship = p_relationship
    where id = (v_result ->> 'invitationId')::uuid;
  return v_result;
end;
$$;
revoke all on function public.maestro_invite_parent(bigint,text,text,text)
  from public;
grant execute on function public.maestro_invite_parent(bigint,text,text,text)
  to authenticated;

-- Relationship writes are reserved for checked security-definer RPCs.
revoke all on public.teacher_students, public.parent_students
  from public, anon, authenticated;
grant select on public.teacher_students, public.parent_students
  to authenticated;

create or replace function public.maestro_parent_management(p_student_app_id bigint)
returns jsonb language plpgsql stable security definer set search_path = '' as $$
declare v_teacher uuid := public.maestro_current_teacher_id(); v_student uuid;
begin
  select id into v_student from public.students where app_id = p_student_app_id;
  if v_student is null or not public.is_teacher_for(v_student) then
    raise exception 'Student access denied' using errcode = '42501';
  end if;
  return jsonb_build_object(
    'teacherId', v_teacher, 'studentId', v_student,
    'studentReady', exists (select 1 from public.student_portal_access a
      where a.teacher_id = v_teacher and a.student_id = v_student
        and a.enabled and a.user_id is not null),
    'parents', (select coalesce(jsonb_agg(jsonb_build_object(
      'userId', a.parent_user_id, 'name', p.display_name, 'email', u.email)
      order by p.display_name), '[]'::jsonb)
      from public.parent_access a join public.profiles p on p.id = a.parent_user_id
      join auth.users u on u.id = a.parent_user_id
      where a.teacher_id = v_teacher and a.student_id = v_student and a.active),
    'invitations', (select coalesce(jsonb_agg(jsonb_build_object(
      'id', i.id, 'name', i.parent_name, 'email', i.email,
      'relationship', i.relationship, 'expiresAt', i.expires_at,
      'acceptedAt', i.accepted_at, 'revokedAt', i.revoked_at)
      order by i.created_at desc), '[]'::jsonb)
      from public.parent_invitations i
      where i.teacher_id = v_teacher and i.student_id = v_student));
end;
$$;

-- Student data continues through the checked portal projection, which hides
-- finance columns unless permitted. Parent row reads require both grants.
create or replace function public.can_read_student(p_student_id uuid)
returns boolean language sql stable security definer set search_path = '' as $$
  select public.is_teacher_for(p_student_id)
    or exists (select 1 from public.parent_access a
      join public.parent_students ps on ps.parent_user_id = a.parent_user_id
        and ps.student_id = a.student_id and ps.active
      join public.teacher_students ts on ts.teacher_id = a.teacher_id
        and ts.student_id = a.student_id and ts.active
      where a.student_id = p_student_id and a.parent_user_id = auth.uid()
        and a.active);
$$;
