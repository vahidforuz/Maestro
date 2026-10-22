-- RLS protects rows, not individual columns. These grants hide financial
-- columns from generic student/project reads, including linked guardians who
-- lack finance permission. Authorized callers use narrow checked functions.
revoke select on public.students from anon, authenticated;
grant select (
  id, app_id, user_id, first_name, family_name, name, email, phone, birthday,
  status, instrument, level, course_day, course_hour, present,
  first_course_status, next_week_assignment, this_week_comment,
  next_project_id, next_course_id, created_at, updated_at
) on public.students to authenticated;

revoke select on public.projects from anon, authenticated;
grant select (id, app_id, student_id, name, sort_order, created_at, updated_at)
  on public.projects to authenticated;

create function public.can_read_student_finances(p_student_id uuid)
returns boolean language sql stable security definer set search_path = ''
as $$
  select public.is_teacher_for(p_student_id)
    or exists (select 1 from public.students s
      where s.id = p_student_id and s.user_id = auth.uid())
    or exists (select 1 from public.parent_students ps
      where ps.student_id = p_student_id and ps.parent_user_id = auth.uid()
        and ps.active and ps.can_view_finances);
$$;

create function public.get_student_finances(p_student_id uuid)
returns jsonb language plpgsql stable security definer set search_path = ''
as $$
declare v_student public.students%rowtype;
begin
  if auth.uid() is null or not public.can_read_student_finances(p_student_id) then
    raise exception 'Financial access denied' using errcode = '42501';
  end if;
  select * into v_student from public.students where id = p_student_id;
  return jsonb_build_object(
    'coursePrice', v_student.course_price,
    'paymentCreditBalance', v_student.payment_credit_balance
  );
end;
$$;

create function public.get_project_finances(p_project_id uuid)
returns jsonb language plpgsql stable security definer set search_path = ''
as $$
declare v_project public.projects%rowtype;
begin
  select * into v_project from public.projects where id = p_project_id;
  if auth.uid() is null or v_project.id is null or
      not public.can_read_student_finances(v_project.student_id) then
    raise exception 'Financial access denied' using errcode = '42501';
  end if;
  return jsonb_build_object('paidCourseCount', v_project.paid_course_count);
end;
$$;

revoke all on function public.can_read_student_finances(uuid) from public;
revoke all on function public.get_student_finances(uuid) from public;
revoke all on function public.get_project_finances(uuid) from public;
grant execute on function public.can_read_student_finances(uuid) to authenticated;
grant execute on function public.get_student_finances(uuid) to authenticated;
grant execute on function public.get_project_finances(uuid) to authenticated;
