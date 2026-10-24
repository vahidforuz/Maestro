-- The previous projection counted prepaid scheduled lessons as cash credit.
-- Keep its checked relationship and permission filtering, then replace only
-- finance fields with teacher-scoped values. Preserve its security-definer
-- implementation under a non-client-facing name.
alter function public.maestro_student_portal_data()
  rename to maestro_student_portal_data_unadjusted;
revoke all on function public.maestro_student_portal_data_unadjusted()
  from public, authenticated;

create function public.maestro_student_portal_data()
returns jsonb language sql stable security definer set search_path = '' as $$
  select coalesce(jsonb_agg(portal || jsonb_build_object(
    'balance', case when portal #>> '{permissions,viewBalance}' = 'true' then
      (select coalesce(sum(l.price), 0) from public.lessons l
        where l.student_id = (portal ->> 'studentId')::uuid
          and l.teacher_id = (portal ->> 'teacherId')::uuid
          and l.status in ('NOTHING', 'PRESENT', 'ABSENT'))
      - (select coalesce(sum(p.amount), 0) from public.payments p
        where p.student_id = (portal ->> 'studentId')::uuid
          and p.teacher_id = (portal ->> 'teacherId')::uuid)
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

revoke all on function public.maestro_student_portal_data() from public;
grant execute on function public.maestro_student_portal_data() to authenticated;
