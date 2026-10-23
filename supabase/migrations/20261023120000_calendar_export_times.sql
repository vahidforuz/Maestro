-- Converts teacher-local wall-clock ranges to UTC for portable ICS exports.
-- Reject nonexistent local times during spring DST transitions.
create function public.maestro_convert_calendar_ranges(p_ranges jsonb)
returns jsonb language plpgsql stable security definer set search_path = '' as $$
declare
  v_teacher public.teachers%rowtype;
  v_range jsonb;
  v_date date;
  v_start integer;
  v_end integer;
  v_local_start timestamp;
  v_local_end timestamp;
  v_utc_start timestamptz;
  v_utc_end timestamptz;
  v_result jsonb := '[]'::jsonb;
begin
  select * into v_teacher from public.teachers
    where id = public.maestro_current_teacher_id();
  if v_teacher.id is null then
    raise exception 'Teacher authentication required' using errcode = '42501';
  end if;
  if jsonb_typeof(p_ranges) <> 'array'
      or jsonb_array_length(p_ranges) > 1000 then
    raise exception 'Invalid calendar ranges' using errcode = '22023';
  end if;
  for v_range in select value from jsonb_array_elements(p_ranges) loop
    v_date := (v_range->>'date')::date;
    v_start := (v_range->>'startMinute')::integer;
    v_end := (v_range->>'endMinute')::integer;
    if v_date is null or v_start is null or v_end is null
        or v_start < 0 or v_end > 1440 or v_start >= v_end then
      raise exception 'Invalid calendar range' using errcode = '22023';
    end if;
    v_local_start := v_date::timestamp + make_interval(mins => v_start);
    v_local_end := v_date::timestamp + make_interval(mins => v_end);
    v_utc_start := v_local_start at time zone v_teacher.timezone;
    v_utc_end := v_local_end at time zone v_teacher.timezone;
    if v_utc_start at time zone v_teacher.timezone <> v_local_start
        or v_utc_end at time zone v_teacher.timezone <> v_local_end
        or v_utc_end <= v_utc_start then
      raise exception 'Calendar range crosses an invalid local time'
        using errcode = '22023';
    end if;
    v_result := v_result || jsonb_build_array(jsonb_build_object(
      'startAt', v_utc_start, 'endAt', v_utc_end));
  end loop;
  return v_result;
end;
$$;
revoke all on function public.maestro_convert_calendar_ranges(jsonb) from public;
grant execute on function public.maestro_convert_calendar_ranges(jsonb) to authenticated;
