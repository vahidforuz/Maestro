-- Check a bearer invitation before creating an Auth account. The token itself
-- remains hashed in the database and the lookup reveals no student details.
create function public.maestro_check_student_invitation(p_token text, p_email text)
returns boolean language sql stable security definer set search_path = '' as $$
  select exists (
    select 1
    from public.student_invitations i
    join public.teacher_students ts on ts.teacher_id = i.teacher_id
      and ts.student_id = i.student_id and ts.active
    left join public.student_portal_access a on a.teacher_id = i.teacher_id
      and a.student_id = i.student_id
    where i.token_hash = encode(extensions.digest(coalesce(p_token, ''), 'sha256'), 'hex')
      and i.email = lower(trim(coalesce(p_email, '')))
      and i.accepted_at is null and i.revoked_at is null
      and i.expires_at > now() and a.user_id is null
  );
$$;

revoke all on function public.maestro_check_student_invitation(text,text) from public;
grant execute on function public.maestro_check_student_invitation(text,text)
  to anon, authenticated;
