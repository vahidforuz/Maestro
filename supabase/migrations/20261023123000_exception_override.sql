-- Date-specific available exceptions can open time blocked by a weekly rule.
-- Date-specific unavailable exceptions remain authoritative.
create or replace function public.maestro_shared_availability_raw(
  p_token text, p_week_start date, p_duration integer default 60
)
returns jsonb language plpgsql stable security definer set search_path = '' as $$
declare
  v_link public.availability_share_links%rowtype;
  v_teacher public.teachers%rowtype;
  v_slots jsonb;
begin
  if p_token is null or p_token !~ '^[0-9a-f]{64}$'
      or p_week_start is null or extract(isodow from p_week_start) <> 1
      or p_duration not in (30, 45, 60) then
    raise exception 'Invalid availability request' using errcode = '22023';
  end if;
  select * into v_link from public.availability_share_links
    where token_hash = sha256(convert_to(p_token, 'UTF8'))
      and revoked_at is null and (expires_at is null or expires_at > now());
  if v_link.id is null then
    raise exception 'Availability link is unavailable' using errcode = '22023';
  end if;
  select * into v_teacher from public.teachers where id = v_link.teacher_id;
  select coalesce(jsonb_agg(jsonb_build_object(
    'date', d.day, 'startMinute', m.minute,
    'endMinute', m.minute + p_duration) order by d.day, m.minute), '[]'::jsonb)
    into v_slots
  from (select generate_series(p_week_start, p_week_start + 6,
    interval '1 day')::date as day) d
  cross join lateral generate_series(0, 1440 - p_duration, 15) m(minute)
  where (v_link.range_from is null or d.day >= v_link.range_from)
    and (v_link.range_until is null or d.day <= v_link.range_until)
    and not exists (
      select 1 from generate_series(m.minute,
        m.minute + p_duration - 15, 15) part(minute)
      where not (
        exists (select 1 from public.teacher_availability_exceptions e
          where e.teacher_id = v_link.teacher_id and e.kind = 'available'
            and e.on_date = d.day and e.start_minute <= part.minute
            and e.end_minute >= part.minute + 15)
        or (
          exists (select 1 from public.teacher_availability_rules r
            where r.teacher_id = v_link.teacher_id and r.kind = 'available'
              and r.weekday = extract(isodow from d.day)
              and r.effective_from <= d.day
              and (r.effective_until is null or r.effective_until >= d.day)
              and r.start_minute <= part.minute
              and r.end_minute >= part.minute + 15)
          and not exists (select 1 from public.teacher_availability_rules r
            where r.teacher_id = v_link.teacher_id and r.kind = 'unavailable'
              and r.weekday = extract(isodow from d.day)
              and r.effective_from <= d.day
              and (r.effective_until is null or r.effective_until >= d.day)
              and r.start_minute < part.minute + 15
              and r.end_minute > part.minute)
        )
      )
      or exists (select 1 from public.teacher_availability_exceptions e
        where e.teacher_id = v_link.teacher_id and e.kind = 'unavailable'
          and e.on_date = d.day and e.start_minute < part.minute + 15
          and e.end_minute > part.minute)
    )
    and not exists (select 1 from public.lessons l
      where l.teacher_id = v_link.teacher_id and l.lesson_date = d.day
        and l.hour is not null and l.status <> 'CANCELED'
        and extract(hour from l.hour)::integer * 60 +
          extract(minute from l.hour)::integer < m.minute + p_duration
        and extract(hour from l.hour)::integer * 60 +
          extract(minute from l.hour)::integer +
          coalesce(l.duration_minutes, v_teacher.default_lesson_duration) > m.minute);
  return jsonb_build_object('teacher', v_teacher.name,
    'timezone', v_teacher.timezone, 'weekStart', p_week_start,
    'durationMinutes', p_duration, 'slots', v_slots);
end;
$$;
revoke all on function public.maestro_shared_availability_raw(text,date,integer)
  from anon, authenticated, public;
