-- A financial grant requires both the teacher-scoped authorization and the
-- active parent/student link. Neither table alone grants financial access.
create function public.maestro_parent_finance_grant(
  p_teacher_id uuid, p_student_id uuid)
returns boolean language sql stable security definer set search_path = '' as $$
  select auth.uid() is not null and exists (
    select 1 from public.parent_access a
    join public.parent_students ps on ps.parent_user_id = a.parent_user_id
      and ps.student_id = a.student_id and ps.active and ps.can_view_finances
    join public.teacher_students ts on ts.teacher_id = a.teacher_id
      and ts.student_id = a.student_id and ts.active
    join public.teachers t on t.id = a.teacher_id and t.status = 'ACTIVE'
    where a.parent_user_id = auth.uid() and a.teacher_id = p_teacher_id
      and a.student_id = p_student_id and a.active and a.can_view_finances);
$$;
revoke all on function public.maestro_parent_finance_grant(uuid,uuid) from public;
grant execute on function public.maestro_parent_finance_grant(uuid,uuid)
  to authenticated;

create or replace function public.can_read_finances(
  p_student_id uuid, p_teacher_id uuid)
returns boolean language sql stable security definer set search_path = '' as $$
  select (public.is_teacher_for(p_student_id) and exists (
    select 1 from public.teachers t where t.id = p_teacher_id
      and t.user_id = auth.uid()))
    or public.maestro_parent_finance_grant(p_teacher_id, p_student_id);
$$;

-- The older finance RPCs expose student-global columns. They remain available
-- only when the parent has a finance grant and the student has one teacher.
create or replace function public.can_read_student_finances(p_student_id uuid)
returns boolean language sql stable security definer set search_path = '' as $$
  select public.is_teacher_for(p_student_id) or exists (
    select 1 from public.parent_access a
    where a.student_id = p_student_id and a.parent_user_id = auth.uid()
      and public.maestro_parent_finance_grant(a.teacher_id, a.student_id)
      and (select count(*) from public.teacher_students ts
        where ts.student_id = p_student_id and ts.active) = 1);
$$;

-- Lessons carry fees. A parent without finance permission must not be able
-- to read those fees directly, even when the portal hides them.
drop policy lessons_read on public.lessons;
create policy lessons_read on public.lessons for select to authenticated using (
  (teacher_id is not null and public.is_teacher_for(student_id)
    and teacher_id = public.maestro_current_teacher_id())
  or public.maestro_parent_finance_grant(teacher_id, student_id));

-- The existing payments_read policy calls can_read_finances. Direct client
-- writes remain unavailable; teachers record payments through the checked RPC.
revoke insert, update, delete on public.payments from public, anon, authenticated;

create or replace function public.maestro_parent_portal_data()
returns jsonb language sql stable security definer set search_path = '' as $$
  select coalesce(jsonb_agg(jsonb_build_object(
    'teacherId', t.id, 'teacherName', t.name,
    'studentId', s.id, 'studentName', s.name,
    'currency', t.currency,
    'canViewFinances', public.maestro_parent_finance_grant(t.id, s.id),
    'balance', case when public.maestro_parent_finance_grant(t.id, s.id) then
      public.maestro_teacher_student_balance(t.id, s.id) else null end,
    'fees', case when public.maestro_parent_finance_grant(t.id, s.id) then
      (select coalesce(jsonb_agg(jsonb_build_object(
        'date', l.lesson_date, 'title', l.title, 'amount', l.price,
        'status', l.status) order by l.lesson_date desc nulls last), '[]'::jsonb)
      from public.lessons l where l.teacher_id = t.id and l.student_id = s.id
        and l.status in ('NOTHING', 'PRESENT', 'ABSENT'))
      else '[]'::jsonb end,
    'payments', case when public.maestro_parent_finance_grant(t.id, s.id) then
      (select coalesce(jsonb_agg(jsonb_build_object(
        'date', p.payment_date, 'amount', p.amount, 'method', p.method)
        order by p.payment_date desc nulls last), '[]'::jsonb)
      from public.payments p where p.teacher_id = t.id and p.student_id = s.id)
      else '[]'::jsonb end
    ) order by s.name, t.name), '[]'::jsonb)
  from public.parent_access a
  join public.parent_students ps on ps.parent_user_id = a.parent_user_id
    and ps.student_id = a.student_id and ps.active
  join public.teacher_students ts on ts.teacher_id = a.teacher_id
    and ts.student_id = a.student_id and ts.active
  join public.teachers t on t.id = a.teacher_id and t.status = 'ACTIVE'
  join public.students s on s.id = a.student_id
  where a.parent_user_id = auth.uid() and a.active;
$$;
