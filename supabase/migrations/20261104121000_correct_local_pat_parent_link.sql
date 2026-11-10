-- Parent student reads must require the same active two-table relationship as
-- the portal RPC. An orphan teacher grant must not expose student records.
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

-- Earlier local demo data linked Pat to Leo, although Pat is the one-child
-- privacy fixture. Revoke only that exact synthetic link. Keep both rows for
-- audit and leave every real account and other parent relationship untouched.
update public.parent_access a set active = false
where a.parent_user_id = '10000000-0000-0000-0000-000000000021'
  and a.student_id = '30000000-0000-0000-0000-000000000012'
  and a.teacher_id = '20000000-0000-0000-0000-000000000001'
  and exists (select 1 from auth.users u where u.id = a.parent_user_id
    and u.email = 'pat.parent@maestro.example')
  and exists (select 1 from public.students s where s.id = a.student_id
    and s.name = 'Leo Student');

update public.parent_students ps set active = false
where ps.parent_user_id = '10000000-0000-0000-0000-000000000021'
  and ps.student_id = '30000000-0000-0000-0000-000000000012'
  and exists (select 1 from auth.users u where u.id = ps.parent_user_id
    and u.email = 'pat.parent@maestro.example')
  and exists (select 1 from public.students s where s.id = ps.student_id
    and s.name = 'Leo Student');
