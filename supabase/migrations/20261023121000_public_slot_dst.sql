-- Keep the public result's exact privacy boundary while filtering nonexistent
-- or duration-distorted wall-clock slots at daylight-saving transitions.
alter function public.maestro_shared_availability(text,date,integer)
  rename to maestro_shared_availability_raw;
revoke all on function public.maestro_shared_availability_raw(text,date,integer)
  from anon, authenticated, public;

create function public.maestro_valid_wall_slot(
  p_date date, p_start integer, p_end integer, p_timezone text
)
returns boolean language sql stable set search_path = '' as $$
  select
    ((p_date::timestamp + make_interval(mins => p_start))
      at time zone p_timezone) at time zone p_timezone =
      p_date::timestamp + make_interval(mins => p_start)
    and ((p_date::timestamp + make_interval(mins => p_end))
      at time zone p_timezone) at time zone p_timezone =
      p_date::timestamp + make_interval(mins => p_end)
    and (((p_date::timestamp + make_interval(mins => p_end))
      at time zone p_timezone) -
      ((p_date::timestamp + make_interval(mins => p_start))
      at time zone p_timezone)) = make_interval(mins => p_end - p_start);
$$;
revoke all on function public.maestro_valid_wall_slot(date,integer,integer,text)
  from public;

create function public.maestro_shared_availability(
  p_token text, p_week_start date, p_duration integer default 60
)
returns jsonb language plpgsql stable security definer set search_path = '' as $$
declare
  v_result jsonb;
  v_slots jsonb;
begin
  v_result := public.maestro_shared_availability_raw(
    p_token, p_week_start, p_duration);
  select coalesce(jsonb_agg(slot.value), '[]'::jsonb) into v_slots
    from jsonb_array_elements(v_result->'slots') slot(value)
    where public.maestro_valid_wall_slot(
      (slot.value->>'date')::date,
      (slot.value->>'startMinute')::integer,
      (slot.value->>'endMinute')::integer,
      v_result->>'timezone');
  return jsonb_set(v_result, '{slots}', v_slots);
end;
$$;
revoke all on function public.maestro_shared_availability(text,date,integer)
  from public;
grant execute on function public.maestro_shared_availability(text,date,integer)
  to anon, authenticated;
