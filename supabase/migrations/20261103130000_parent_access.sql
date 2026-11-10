-- Parent grants are scoped to a teacher/student pair. Keep legacy links and
-- records intact; backfill their existing access before tightening finance RLS.
create table public.parent_access (
  teacher_id uuid not null,
  student_id uuid not null,
  parent_user_id uuid not null references public.profiles(id),
  active boolean not null default true,
  can_view_finances boolean not null default true,
  created_at timestamptz not null default now(),
  primary key (teacher_id, student_id, parent_user_id),
  foreign key (teacher_id, student_id)
    references public.teacher_students(teacher_id, student_id)
);
create index parent_access_user on public.parent_access(parent_user_id, active);
insert into public.parent_access(teacher_id, student_id, parent_user_id,
  active, can_view_finances)
select ts.teacher_id, ps.student_id, ps.parent_user_id,
  ps.active, ps.can_view_finances
from public.parent_students ps join public.teacher_students ts
  on ts.student_id = ps.student_id
on conflict do nothing;

create table public.parent_invitations (
  id uuid primary key default gen_random_uuid(),
  teacher_id uuid not null,
  student_id uuid not null,
  parent_name text not null,
  email text not null check (email = lower(trim(email)) and email like '%@%'),
  token_hash text not null unique,
  expires_at timestamptz not null,
  accepted_at timestamptz,
  revoked_at timestamptz,
  created_at timestamptz not null default now(),
  foreign key (teacher_id, student_id)
    references public.teacher_students(teacher_id, student_id)
);
create index parent_invitations_relationship on public.parent_invitations
  (teacher_id, student_id, created_at desc);

alter table public.parent_access enable row level security;
alter table public.parent_invitations enable row level security;
create policy parent_access_self_read on public.parent_access
  for select to authenticated using (parent_user_id = auth.uid() and active);
create policy parent_access_teacher_read on public.parent_access
  for select to authenticated using (teacher_id = public.maestro_current_teacher_id()
    and public.is_teacher_for(student_id));
create policy parent_invitations_teacher_read on public.parent_invitations
  for select to authenticated using (teacher_id = public.maestro_current_teacher_id()
    and public.is_teacher_for(student_id));
revoke all on public.parent_access, public.parent_invitations from anon, authenticated;
grant select on public.parent_access, public.parent_invitations to authenticated;
drop policy parent_students_read on public.parent_students;
create policy parent_students_read on public.parent_students for select to authenticated
  using (parent_user_id = auth.uid() and active and exists (
    select 1 from public.parent_access a
    join public.teacher_students ts on ts.teacher_id = a.teacher_id
      and ts.student_id = a.student_id and ts.active
    where a.student_id = parent_students.student_id
      and a.parent_user_id = auth.uid() and a.active));

create function public.maestro_invite_parent(
  p_student_app_id bigint, p_email text, p_name text)
returns jsonb language plpgsql security definer set search_path = '' as $$
declare
  v_teacher uuid := public.maestro_current_teacher_id();
  v_student uuid;
  v_email text := lower(trim(coalesce(p_email, '')));
  v_name text := trim(coalesce(p_name, ''));
  v_token text := encode(extensions.gen_random_bytes(32), 'hex');
  v_invitation public.parent_invitations%rowtype;
begin
  select id into v_student from public.students where app_id = p_student_app_id;
  if v_teacher is null or v_student is null or not exists (
    select 1 from public.teacher_students where teacher_id = v_teacher
      and student_id = v_student and active) then
    raise exception 'Student access denied' using errcode = '42501';
  end if;
  if v_email !~ '^[^ @]+@[^ @]+\.[^ @]+$' or v_name = '' then
    raise exception 'Enter a parent name and valid email' using errcode = '22023';
  end if;
  update public.parent_invitations set revoked_at = now()
    where teacher_id = v_teacher and student_id = v_student
      and email = v_email and accepted_at is null and revoked_at is null;
  insert into public.parent_invitations
    (teacher_id, student_id, parent_name, email, token_hash, expires_at)
    values (v_teacher, v_student, v_name, v_email,
      encode(extensions.digest(v_token, 'sha256'), 'hex'),
      now() + interval '7 days') returning * into v_invitation;
  return jsonb_build_object('token', v_token, 'invitationId', v_invitation.id,
    'expiresAt', v_invitation.expires_at);
end;
$$;

create function public.maestro_check_parent_invitation(p_token text, p_email text)
returns boolean language sql stable security definer set search_path = '' as $$
  select exists (select 1 from public.parent_invitations i
    join public.teacher_students ts on ts.teacher_id = i.teacher_id
      and ts.student_id = i.student_id and ts.active
    where i.token_hash = encode(extensions.digest(coalesce(p_token,''), 'sha256'), 'hex')
      and i.email = lower(trim(coalesce(p_email,'')))
      and i.accepted_at is null and i.revoked_at is null and i.expires_at > now());
$$;

create function public.maestro_accept_parent_invitation(p_token text)
returns jsonb language plpgsql security definer set search_path = '' as $$
declare
  v_user auth.users%rowtype;
  v_invitation public.parent_invitations%rowtype;
begin
  select * into v_user from auth.users where id = auth.uid();
  if v_user.id is null or v_user.email_confirmed_at is null then
    raise exception 'Confirm your email before accepting the invitation' using errcode = '42501';
  end if;
  select * into v_invitation from public.parent_invitations
    where token_hash = encode(extensions.digest(coalesce(p_token,''), 'sha256'), 'hex')
    for update;
  if v_invitation.id is null or v_invitation.accepted_at is not null or
      v_invitation.revoked_at is not null or v_invitation.expires_at <= now() or
      lower(v_user.email) <> v_invitation.email then
    raise exception 'Invitation is invalid or for another email' using errcode = '42501';
  end if;
  if not exists (select 1 from public.teacher_students ts
      where ts.teacher_id = v_invitation.teacher_id
        and ts.student_id = v_invitation.student_id and ts.active) then
    raise exception 'Student relationship is inactive' using errcode = '42501';
  end if;
  insert into public.profiles(id, display_name, role)
    values (v_user.id, v_invitation.parent_name, 'parent')
    on conflict (id) do update set
      display_name = case when public.profiles.display_name = ''
        then excluded.display_name else public.profiles.display_name end,
      role = case when public.profiles.role = 'user' then 'parent'
        else public.profiles.role end, updated_at = now();
  insert into public.parent_students(parent_user_id, student_id, active,
    can_view_finances) values (v_user.id, v_invitation.student_id, true, true)
    on conflict (parent_user_id, student_id) do update
      set active = true, can_view_finances = true;
  insert into public.parent_access(teacher_id, student_id, parent_user_id)
    values (v_invitation.teacher_id, v_invitation.student_id, v_user.id)
    on conflict (teacher_id, student_id, parent_user_id) do update set active = true;
  update public.parent_invitations set accepted_at = now()
    where id = v_invitation.id;
  return jsonb_build_object('studentId', v_invitation.student_id,
    'teacherId', v_invitation.teacher_id);
end;
$$;

create function public.maestro_parent_management(p_student_app_id bigint)
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
      'expiresAt', i.expires_at, 'acceptedAt', i.accepted_at,
      'revokedAt', i.revoked_at) order by i.created_at desc), '[]'::jsonb)
      from public.parent_invitations i
      where i.teacher_id = v_teacher and i.student_id = v_student));
end;
$$;

create function public.maestro_remove_parent_access(p_student_app_id bigint, p_parent_user_id uuid)
returns void language plpgsql security definer set search_path = '' as $$
declare v_teacher uuid := public.maestro_current_teacher_id(); v_student uuid;
begin
  select id into v_student from public.students where app_id = p_student_app_id;
  if v_student is null or not public.is_teacher_for(v_student) then
    raise exception 'Student access denied' using errcode = '42501';
  end if;
  update public.parent_access set active = false
    where teacher_id = v_teacher and student_id = v_student
      and parent_user_id = p_parent_user_id and active;
  if not found then raise exception 'Parent access not found' using errcode = '42501'; end if;
  if not exists (select 1 from public.parent_access
      where student_id = v_student and parent_user_id = p_parent_user_id and active) then
    update public.parent_students set active = false
      where student_id = v_student and parent_user_id = p_parent_user_id;
  end if;
end;
$$;

create function public.maestro_revoke_parent_invitation(p_invitation_id uuid)
returns void language plpgsql security definer set search_path = '' as $$
begin
  update public.parent_invitations set revoked_at = now()
    where id = p_invitation_id and teacher_id = public.maestro_current_teacher_id()
      and accepted_at is null and revoked_at is null;
  if not found then raise exception 'Pending invitation not found' using errcode = '42501'; end if;
end;
$$;

-- Parent finance visibility is checked against the exact teacher on the row.
create or replace function public.can_read_student(p_student_id uuid)
returns boolean language sql stable security definer set search_path = '' as $$
  select public.is_teacher_for(p_student_id)
    or exists (select 1 from public.parent_access a
      join public.teacher_students ts on ts.teacher_id = a.teacher_id
        and ts.student_id = a.student_id and ts.active
      where a.student_id = p_student_id and a.parent_user_id = auth.uid()
        and a.active);
$$;
create or replace function public.can_read_finances(p_student_id uuid, p_teacher_id uuid)
returns boolean language sql stable security definer set search_path = '' as $$
  select (public.is_teacher_for(p_student_id) and exists
      (select 1 from public.teachers t where t.id = p_teacher_id
        and t.user_id = auth.uid()))
    or exists (select 1 from public.parent_access a
      join public.teacher_students ts on ts.teacher_id = a.teacher_id
        and ts.student_id = a.student_id and ts.active
      where a.student_id = p_student_id and a.teacher_id = p_teacher_id
        and a.parent_user_id = auth.uid() and a.active and a.can_view_finances);
$$;
create or replace function public.can_read_student_finances(p_student_id uuid)
returns boolean language sql stable security definer set search_path = '' as $$
  select public.is_teacher_for(p_student_id)
    or exists (select 1 from public.parent_access a
      join public.teacher_students ts on ts.teacher_id = a.teacher_id
        and ts.student_id = a.student_id and ts.active
      where a.student_id = p_student_id and a.parent_user_id = auth.uid()
        and a.active and a.can_view_finances
        -- Legacy finance RPCs take only a student ID and expose global fields.
        -- For shared students, use the teacher-scoped parent projection instead.
        and (select count(*) from public.teacher_students all_ts
          where all_ts.student_id = p_student_id and all_ts.active) = 1);
$$;

-- Revoke teacher-specific lesson reads when a parent grant is removed.
drop policy lessons_read on public.lessons;
create policy lessons_read on public.lessons for select to authenticated using (
  (teacher_id is not null and public.is_teacher_for(student_id) and
    teacher_id = public.maestro_current_teacher_id())
  or exists (select 1 from public.parent_access a where
    a.teacher_id = lessons.teacher_id and a.student_id = lessons.student_id
    and a.parent_user_id = auth.uid() and a.active
    and exists (select 1 from public.teacher_students ts
      where ts.teacher_id = a.teacher_id and ts.student_id = a.student_id
        and ts.active)));
drop policy lesson_notes_read on public.lesson_notes;
create policy lesson_notes_read on public.lesson_notes for select to authenticated using (
  (teacher_id is not null and public.is_teacher_for(student_id) and
    teacher_id = public.maestro_current_teacher_id())
  or exists (select 1 from public.parent_access a where
    a.teacher_id = lesson_notes.teacher_id and a.student_id = lesson_notes.student_id
    and a.parent_user_id = auth.uid() and a.active
    and exists (select 1 from public.teacher_students ts
      where ts.teacher_id = a.teacher_id and ts.student_id = a.student_id
        and ts.active)));

-- Same fee/balance arithmetic used by the student payment projection.
create function public.maestro_teacher_student_balance(p_teacher_id uuid, p_student_id uuid)
returns numeric language sql stable security definer set search_path = '' as $$
  select (select coalesce(sum(l.price), 0) from public.lessons l
    where l.student_id = p_student_id and l.teacher_id = p_teacher_id
      and l.status in ('NOTHING', 'PRESENT', 'ABSENT'))
    - (select coalesce(sum(p.amount), 0) from public.payments p
      where p.student_id = p_student_id and p.teacher_id = p_teacher_id);
$$;
revoke all on function public.maestro_teacher_student_balance(uuid,uuid) from public, anon, authenticated;

-- Point the existing student projection at the same arithmetic without
-- changing its permissions or other fields.
create or replace function public.maestro_student_portal_data()
returns jsonb language sql stable security definer set search_path = '' as $$
  select coalesce(jsonb_agg(portal || jsonb_build_object(
    'balance', case when portal #>> '{permissions,viewBalance}' = 'true' then
      public.maestro_teacher_student_balance(
        (portal ->> 'teacherId')::uuid, (portal ->> 'studentId')::uuid)
      else null end,
    'courseCredits', case when portal #>> '{permissions,viewBalance}' = 'true'
      and (select count(*) from public.teacher_students ts
        where ts.student_id = (portal ->> 'studentId')::uuid) = 1
      then greatest(0,
        (select coalesce(sum(pr.paid_course_count), 0) from public.projects pr
          where pr.student_id = (portal ->> 'studentId')::uuid)
        - (select count(*) from public.lessons l
          where l.student_id = (portal ->> 'studentId')::uuid
            and l.teacher_id = (portal ->> 'teacherId')::uuid
            and l.status in ('PRESENT', 'ABSENT')))
      else null end
  ) order by portal ->> 'teacherName'), '[]'::jsonb)
  from jsonb_array_elements(public.maestro_student_portal_data_unadjusted()) as rows(portal);
$$;

create function public.maestro_parent_portal_data()
returns jsonb language sql stable security definer set search_path = '' as $$
  select coalesce(jsonb_agg(jsonb_build_object(
    'teacherId', t.id, 'teacherName', t.name,
    'studentId', s.id, 'studentName', s.name,
    'currency', t.currency,
    'canViewFinances', a.can_view_finances,
    'balance', case when a.can_view_finances then
      public.maestro_teacher_student_balance(t.id, s.id) else null end,
    'fees', case when a.can_view_finances then (select coalesce(jsonb_agg(jsonb_build_object(
      'date', l.lesson_date, 'title', l.title, 'amount', l.price,
      'status', l.status) order by l.lesson_date desc nulls last), '[]'::jsonb)
      from public.lessons l where l.teacher_id = t.id and l.student_id = s.id
        and l.status in ('NOTHING', 'PRESENT', 'ABSENT')) else '[]'::jsonb end,
    'payments', case when a.can_view_finances then (select coalesce(jsonb_agg(jsonb_build_object(
      'date', p.payment_date, 'amount', p.amount, 'method', p.method)
      order by p.payment_date desc nulls last), '[]'::jsonb)
      from public.payments p where p.teacher_id = t.id and p.student_id = s.id)
      else '[]'::jsonb end
    ) order by s.name, t.name), '[]'::jsonb)
  from public.parent_access a
  join public.teacher_students ts on ts.teacher_id = a.teacher_id
    and ts.student_id = a.student_id and ts.active
  join public.teachers t on t.id = a.teacher_id and t.status = 'ACTIVE'
  join public.students s on s.id = a.student_id
  where a.parent_user_id = auth.uid() and a.active;
$$;

create policy profiles_self_update on public.profiles for update to authenticated
  using (id = auth.uid()) with check (id = auth.uid());
revoke update on public.profiles from public, anon, authenticated;
grant update(display_name) on public.profiles to authenticated;

revoke all on function public.maestro_invite_parent(bigint,text,text),
  public.maestro_check_parent_invitation(text,text),
  public.maestro_accept_parent_invitation(text),
  public.maestro_parent_management(bigint),
  public.maestro_remove_parent_access(bigint,uuid),
  public.maestro_revoke_parent_invitation(uuid),
  public.maestro_parent_portal_data() from public;
grant execute on function public.maestro_check_parent_invitation(text,text) to anon, authenticated;
grant execute on function public.maestro_invite_parent(bigint,text,text),
  public.maestro_accept_parent_invitation(text),
  public.maestro_parent_management(bigint),
  public.maestro_remove_parent_access(bigint,uuid),
  public.maestro_revoke_parent_invitation(uuid),
  public.maestro_parent_portal_data() to authenticated;
