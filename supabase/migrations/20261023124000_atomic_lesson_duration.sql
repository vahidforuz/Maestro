-- Existing lesson editing and duration changes commit or fail together.
create function public.maestro_update_lesson_with_duration(
  p_student_app_id bigint,
  p_project_app_id bigint,
  p_lesson_app_id bigint,
  p_payload jsonb
)
returns bigint language plpgsql security definer set search_path = '' as $$
declare
  v_teacher uuid := public.maestro_current_teacher_id();
  v_old_duration integer;
  v_new_duration integer;
begin
  if v_teacher is null then
    raise exception 'Teacher authentication required' using errcode = '42501';
  end if;
  select coalesce(l.duration_minutes, t.default_lesson_duration)
    into v_old_duration from public.lessons l
    join public.teachers t on t.id = l.teacher_id
    where l.app_id = p_lesson_app_id and l.teacher_id = v_teacher;
  if v_old_duration is null then
    raise exception 'Lesson not found or not owned' using errcode = '42501';
  end if;
  if p_payload ? 'durationMinutes' then
    v_new_duration := (p_payload->>'durationMinutes')::integer;
    if v_new_duration is null or v_new_duration not in (30, 45, 60) then
      raise exception 'Duration must be 30, 45, or 60 minutes'
        using errcode = '22023';
    end if;
    if v_new_duration < v_old_duration then
      perform public.maestro_set_lesson_duration(p_lesson_app_id, v_new_duration);
    end if;
  end if;
  perform public.maestro_student_command('update_lesson', p_student_app_id,
    p_project_app_id, p_lesson_app_id, p_payload);
  if v_new_duration is not null and v_new_duration >= v_old_duration then
    perform public.maestro_set_lesson_duration(p_lesson_app_id, v_new_duration);
  end if;
  return p_student_app_id;
end;
$$;
revoke all on function public.maestro_update_lesson_with_duration(
  bigint,bigint,bigint,jsonb) from public;
grant execute on function public.maestro_update_lesson_with_duration(
  bigint,bigint,bigint,jsonb) to authenticated;
