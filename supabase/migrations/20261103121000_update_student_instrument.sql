-- Only an assigned teacher may change a student's instrument. Keep lessons,
-- schedules, and all other student fields untouched.
create function public.maestro_update_student_instrument(
  p_student_app_id bigint, p_instrument text)
returns void language plpgsql security definer set search_path = '' as $$
declare
  v_teacher uuid := public.maestro_current_teacher_id();
  v_student uuid;
  v_instrument text := nullif(trim(coalesce(p_instrument, '')), '');
begin
  if v_instrument is null then
    raise exception 'Instrument is required' using errcode = '22023';
  end if;
  select id into v_student from public.students where app_id = p_student_app_id;
  if v_teacher is null or v_student is null or not public.is_teacher_for(v_student) then
    raise exception 'Student access denied' using errcode = '42501';
  end if;
  update public.students set instrument = v_instrument, updated_at = now()
    where id = v_student;
end;
$$;

revoke all on function public.maestro_update_student_instrument(bigint,text) from public;
grant execute on function public.maestro_update_student_instrument(bigint,text)
  to authenticated;
