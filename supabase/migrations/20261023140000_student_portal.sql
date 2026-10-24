-- Student portal access is an explicit, revocable teacher/student relationship.
-- Existing students.user_id values are legacy identity hints, not portal grants.
create table public.student_portal_access (
  teacher_id uuid not null,
  student_id uuid not null,
  user_id uuid references auth.users(id) on delete set null,
  enabled boolean not null default false,
  view_courses boolean not null default true,
  view_notes boolean not null default false,
  view_reviews boolean not null default true,
  view_pieces boolean not null default true,
  view_payments boolean not null default false,
  view_balance boolean not null default false,
  request_changes boolean not null default false,
  updated_at timestamptz not null default now(),
  primary key (teacher_id, student_id),
  foreign key (teacher_id, student_id)
    references public.teacher_students(teacher_id, student_id)
);
create index student_portal_access_user on public.student_portal_access(user_id)
  where enabled;

create table public.student_invitations (
  id uuid primary key default gen_random_uuid(),
  teacher_id uuid not null,
  student_id uuid not null,
  email text not null check (email = lower(trim(email)) and email like '%@%'),
  token_hash text not null unique,
  expires_at timestamptz not null,
  accepted_at timestamptz,
  revoked_at timestamptz,
  created_at timestamptz not null default now(),
  foreign key (teacher_id, student_id)
    references public.teacher_students(teacher_id, student_id)
);
create index student_invitations_relationship on public.student_invitations
  (teacher_id, student_id, created_at desc);
create index student_invitations_pending on public.student_invitations(expires_at)
  where accepted_at is null and revoked_at is null;

alter table public.lesson_notes add column student_shared boolean not null default false;

alter table public.student_portal_access enable row level security;
alter table public.student_invitations enable row level security;
create policy student_portal_access_teacher_read on public.student_portal_access
  for select to authenticated using (
    teacher_id = public.maestro_current_teacher_id() and
    public.is_teacher_for(student_id));
create policy student_portal_access_student_read on public.student_portal_access
  for select to authenticated using (user_id = auth.uid() and enabled and
    exists (select 1 from public.teacher_students ts where ts.teacher_id =
      student_portal_access.teacher_id and ts.student_id =
      student_portal_access.student_id and ts.active));
create policy student_invitations_teacher_read on public.student_invitations
  for select to authenticated using (
    teacher_id = public.maestro_current_teacher_id() and
    public.is_teacher_for(student_id));
revoke all on public.student_portal_access, public.student_invitations
  from anon, authenticated;
grant select on public.student_portal_access, public.student_invitations
  to authenticated;

-- Strip legacy direct student-row grants. Students use the checked portal RPC;
-- teachers and the existing guardian policies retain their table access.
create or replace function public.can_read_student(p_student_id uuid)
returns boolean language sql stable security definer set search_path = '' as $$
  select public.is_teacher_for(p_student_id)
    or exists (select 1 from public.parent_students ps
      where ps.student_id = p_student_id and ps.parent_user_id = auth.uid()
        and ps.active);
$$;
create or replace function public.can_read_finances(p_student_id uuid, p_teacher_id uuid)
returns boolean language sql stable security definer set search_path = '' as $$
  select (public.is_teacher_for(p_student_id) and exists
      (select 1 from public.teachers t where t.id = p_teacher_id
        and t.user_id = auth.uid()))
    or exists (select 1 from public.parent_students ps
      where ps.student_id = p_student_id and ps.parent_user_id = auth.uid()
        and ps.active and ps.can_view_finances);
$$;
create or replace function public.can_read_student_finances(p_student_id uuid)
returns boolean language sql stable security definer set search_path = '' as $$
  select public.is_teacher_for(p_student_id)
    or exists (select 1 from public.parent_students ps
      where ps.student_id = p_student_id and ps.parent_user_id = auth.uid()
        and ps.active and ps.can_view_finances);
$$;
drop policy lessons_read on public.lessons;
create policy lessons_read on public.lessons for select to authenticated using (
  (teacher_id is not null and public.is_teacher_for(student_id) and
    teacher_id = public.maestro_current_teacher_id())
  or exists (select 1 from public.parent_students ps where
    ps.student_id = lessons.student_id and ps.parent_user_id = auth.uid()
    and ps.active));
drop policy lesson_notes_read on public.lesson_notes;
create policy lesson_notes_read on public.lesson_notes for select to authenticated using (
  (teacher_id is not null and public.is_teacher_for(student_id) and
    teacher_id = public.maestro_current_teacher_id())
  or exists (select 1 from public.parent_students ps where
    ps.student_id = lesson_notes.student_id and ps.parent_user_id = auth.uid()
    and ps.active));

-- A token is returned only at creation and is never stored in clear text.
create function public.maestro_invite_student(p_student_app_id bigint, p_email text)
returns jsonb language plpgsql security definer set search_path = '' as $$
declare
  v_teacher uuid := public.maestro_current_teacher_id();
  v_student uuid;
  v_email text := lower(trim(coalesce(p_email, '')));
  v_token text := encode(extensions.gen_random_bytes(32), 'hex');
  v_invitation public.student_invitations%rowtype;
begin
  select id into v_student from public.students where app_id = p_student_app_id;
  if v_teacher is null or v_student is null or not public.is_teacher_for(v_student) then
    raise exception 'Student access denied' using errcode = '42501';
  end if;
  if v_email !~ '^[^ @]+@[^ @]+\.[^ @]+$' then
    raise exception 'Enter a valid email address' using errcode = '22023';
  end if;
  insert into public.student_portal_access(teacher_id, student_id)
    values (v_teacher, v_student) on conflict do nothing;
  update public.student_invitations set revoked_at = now()
    where teacher_id = v_teacher and student_id = v_student
      and accepted_at is null and revoked_at is null;
  insert into public.student_invitations
    (teacher_id, student_id, email, token_hash, expires_at)
    values (v_teacher, v_student, v_email,
      encode(extensions.digest(v_token, 'sha256'), 'hex'), now() + interval '7 days')
    returning * into v_invitation;
  return jsonb_build_object('token', v_token, 'expiresAt', v_invitation.expires_at,
    'invitationId', v_invitation.id);
end;
$$;

create function public.maestro_accept_student_invitation(p_token text)
returns jsonb language plpgsql security definer set search_path = '' as $$
declare
  v_user auth.users%rowtype;
  v_invitation public.student_invitations%rowtype;
begin
  select * into v_user from auth.users where id = auth.uid();
  if v_user.id is null or v_user.email_confirmed_at is null then
    raise exception 'Confirm your email before accepting the invitation'
      using errcode = '42501';
  end if;
  select * into v_invitation from public.student_invitations
    where token_hash = encode(extensions.digest(coalesce(p_token, ''), 'sha256'), 'hex')
    for update;
  if v_invitation.id is null or v_invitation.accepted_at is not null or
      v_invitation.revoked_at is not null or v_invitation.expires_at <= now() then
    raise exception 'Invitation is invalid or expired' using errcode = '42501';
  end if;
  if lower(v_user.email) <> v_invitation.email then
    raise exception 'Sign in with the invited email address' using errcode = '42501';
  end if;
  if not exists (select 1 from public.teacher_students ts where
      ts.teacher_id = v_invitation.teacher_id and
      ts.student_id = v_invitation.student_id and ts.active) then
    raise exception 'Student relationship is inactive' using errcode = '42501';
  end if;
  update public.student_portal_access set user_id = v_user.id,
    enabled = true, updated_at = now()
    where teacher_id = v_invitation.teacher_id and student_id = v_invitation.student_id;
  update public.profiles set role = 'student', updated_at = now()
    where id = v_user.id and role = 'user';
  update public.student_invitations set accepted_at = now()
    where id = v_invitation.id;
  return jsonb_build_object('studentId', v_invitation.student_id,
    'teacherId', v_invitation.teacher_id);
end;
$$;

create function public.maestro_set_student_access(
  p_student_app_id bigint, p_settings jsonb)
returns void language plpgsql security definer set search_path = '' as $$
declare
  v_teacher uuid := public.maestro_current_teacher_id();
  v_student uuid;
begin
  select id into v_student from public.students where app_id = p_student_app_id;
  if v_teacher is null or v_student is null or not public.is_teacher_for(v_student) then
    raise exception 'Student access denied' using errcode = '42501';
  end if;
  insert into public.student_portal_access(teacher_id, student_id)
    values (v_teacher, v_student) on conflict do nothing;
  update public.student_portal_access set
    enabled = coalesce((p_settings ->> 'enabled')::boolean, enabled),
    view_courses = coalesce((p_settings ->> 'viewCourses')::boolean, view_courses),
    view_notes = coalesce((p_settings ->> 'viewNotes')::boolean, view_notes),
    view_reviews = coalesce((p_settings ->> 'viewReviews')::boolean, view_reviews),
    view_pieces = coalesce((p_settings ->> 'viewPieces')::boolean, view_pieces),
    view_payments = coalesce((p_settings ->> 'viewPayments')::boolean, view_payments),
    view_balance = coalesce((p_settings ->> 'viewBalance')::boolean, view_balance),
    request_changes = coalesce((p_settings ->> 'requestChanges')::boolean, request_changes),
    updated_at = now()
    where teacher_id = v_teacher and student_id = v_student;
  if p_settings ->> 'enabled' = 'false' then
    update public.student_invitations set revoked_at = now()
      where teacher_id = v_teacher and student_id = v_student
        and accepted_at is null and revoked_at is null;
  end if;
end;
$$;

create function public.maestro_revoke_student_invitation(p_invitation_id uuid)
returns void language plpgsql security definer set search_path = '' as $$
begin
  update public.student_invitations set revoked_at = now()
    where id = p_invitation_id and teacher_id = public.maestro_current_teacher_id()
      and accepted_at is null and revoked_at is null;
  if not found then raise exception 'Pending invitation not found' using errcode = '42501'; end if;
end;
$$;

create function public.maestro_set_note_shared(p_note_app_id bigint, p_shared boolean)
returns void language plpgsql security definer set search_path = '' as $$
begin
  update public.lesson_notes set student_shared = p_shared, updated_at = now()
    where app_id = p_note_app_id and teacher_id = public.maestro_current_teacher_id()
      and public.is_teacher_for(student_id);
  if not found then raise exception 'Note access denied' using errcode = '42501'; end if;
end;
$$;

-- One checked projection supplies student pages without granting table reads.
-- Values are evaluated per active teacher/student link on every request.
create function public.maestro_student_portal_data()
returns jsonb language sql stable security definer set search_path = '' as $$
  select coalesce(jsonb_agg(jsonb_build_object(
    'teacherId', t.id, 'teacherName', t.name, 'studentId', s.id,
    'studentAppId', s.app_id, 'studentName', s.name,
    'permissions', jsonb_build_object(
      'viewCourses', a.view_courses, 'viewNotes', a.view_notes,
      'viewReviews', a.view_reviews, 'viewPieces', a.view_pieces,
      'viewPayments', a.view_payments, 'viewBalance', a.view_balance,
      'requestChanges', a.request_changes),
    'courses', case when a.view_courses then (
      select coalesce(jsonb_agg(jsonb_build_object(
        'id', l.id, 'appId', l.app_id, 'title', l.title,
        'date', l.lesson_date, 'hour', l.hour,
        'durationMinutes', l.duration_minutes, 'status', l.status,
        'assignment', case when a.view_reviews then l.assignment else null end,
        'homework', case when a.view_reviews then l.homework_next_lesson else null end)
        order by l.lesson_date nulls last, l.app_id), '[]'::jsonb)
      from public.lessons l where l.student_id = s.id and l.teacher_id = t.id)
      else '[]'::jsonb end,
    'notes', case when a.view_notes or a.view_reviews then (
      select coalesce(jsonb_agg(jsonb_build_object(
        'id', n.id, 'appId', n.app_id, 'courseId', n.lesson_id,
        'piece', case when a.view_notes and n.student_shared then n.piece else null end,
        'comment', case when a.view_notes and n.student_shared then n.comment else null end,
        'createdDate', n.created_date,
        'reviewDate', case when a.view_reviews then n.review_date else null end,
        'reviewStatus', case when a.view_reviews then n.review_status else null end,
        'targetCourseId', case when a.view_reviews then n.target_lesson_id else null end)
        order by n.created_date desc nulls last, n.app_id), '[]'::jsonb)
      from public.lesson_notes n where n.student_id = s.id
        and n.teacher_id = t.id
        and ((a.view_notes and n.student_shared and (n.piece <> '' or n.comment <> ''))
          or (a.view_reviews and n.review_date is not null)))
      else '[]'::jsonb end,
    'pieces', case when a.view_pieces then (
      select coalesce(jsonb_agg(jsonb_build_object('title', p.title,
        'project', pr.name) order by pr.sort_order, p.sort_order), '[]'::jsonb)
      from public.pieces p join public.projects pr on pr.id = p.project_id
      where p.student_id = s.id and exists (select 1 from public.lessons l
        where l.project_id = pr.id and l.teacher_id = t.id))
      else '[]'::jsonb end,
    'payments', case when a.view_payments then (
      select coalesce(jsonb_agg(jsonb_build_object('date', p.payment_date,
        'amount', p.amount, 'method', p.method) order by p.payment_date desc), '[]'::jsonb)
      from public.payments p where p.student_id = s.id and p.teacher_id = t.id)
      else '[]'::jsonb end,
    'balance', case when a.view_balance then s.payment_credit_balance else null end,
    'courseCredits', case when a.view_balance then (
      select coalesce(sum(pr.paid_course_count), 0) from public.projects pr
      where pr.student_id = s.id and exists (select 1 from public.lessons l
        where l.project_id = pr.id and l.teacher_id = t.id)) else null end
  ) order by t.name), '[]'::jsonb)
  from public.student_portal_access a
  join public.teacher_students ts on ts.teacher_id = a.teacher_id
    and ts.student_id = a.student_id and ts.active
  join public.teachers t on t.id = a.teacher_id and t.status = 'ACTIVE'
  join public.students s on s.id = a.student_id
  where a.user_id = auth.uid() and a.enabled;
$$;

revoke all on function public.maestro_invite_student(bigint,text),
  public.maestro_accept_student_invitation(text),
  public.maestro_set_student_access(bigint,jsonb),
  public.maestro_revoke_student_invitation(uuid),
  public.maestro_set_note_shared(bigint,boolean),
  public.maestro_student_portal_data() from public;
grant execute on function public.maestro_invite_student(bigint,text),
  public.maestro_accept_student_invitation(text),
  public.maestro_set_student_access(bigint,jsonb),
  public.maestro_revoke_student_invitation(uuid),
  public.maestro_set_note_shared(bigint,boolean),
  public.maestro_student_portal_data() to authenticated;
