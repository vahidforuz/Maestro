-- A fresh invitation must not silently transfer an existing portal grant to
-- another Auth account. Teachers must explicitly unlink the old account first.
create or replace function public.maestro_accept_student_invitation(p_token text)
returns jsonb language plpgsql security definer set search_path = '' as $$
declare
  v_user auth.users%rowtype;
  v_invitation public.student_invitations%rowtype;
  v_linked_user uuid;
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
  select user_id into v_linked_user from public.student_portal_access
    where teacher_id = v_invitation.teacher_id and student_id = v_invitation.student_id
    for update;
  if v_linked_user is not null and v_linked_user <> v_user.id then
    raise exception 'Another account is linked. Ask the teacher to revoke it first'
      using errcode = '42501';
  end if;
  update public.student_portal_access set user_id = v_user.id,
    enabled = true, updated_at = now()
    where teacher_id = v_invitation.teacher_id and student_id = v_invitation.student_id;
  if not found then
    raise exception 'Student portal access is unavailable' using errcode = '42501';
  end if;
  update public.profiles set role = 'student', updated_at = now()
    where id = v_user.id and role = 'user';
  update public.student_invitations set accepted_at = now()
    where id = v_invitation.id;
  return jsonb_build_object('studentId', v_invitation.student_id,
    'teacherId', v_invitation.teacher_id);
end;
$$;

create function public.maestro_unlink_student_access(p_student_app_id bigint)
returns void language plpgsql security definer set search_path = '' as $$
declare
  v_teacher uuid := public.maestro_current_teacher_id();
  v_student uuid;
begin
  select id into v_student from public.students where app_id = p_student_app_id;
  if v_teacher is null or v_student is null or not public.is_teacher_for(v_student) then
    raise exception 'Student access denied' using errcode = '42501';
  end if;
  update public.student_portal_access set user_id = null, enabled = false,
    updated_at = now() where teacher_id = v_teacher and student_id = v_student;
  update public.student_invitations set revoked_at = now()
    where teacher_id = v_teacher and student_id = v_student
      and accepted_at is null and revoked_at is null;
end;
$$;

revoke all on function public.maestro_unlink_student_access(bigint) from public;
grant execute on function public.maestro_unlink_student_access(bigint) to authenticated;
