create table public.availability_share_links (
  id uuid primary key default gen_random_uuid(),
  teacher_id uuid not null references public.teachers(id) on delete cascade,
  token_hash bytea not null unique,
  created_at timestamptz not null default now(),
  expires_at timestamptz,
  range_from date,
  range_until date,
  revoked_at timestamptz,
  check (range_until is null or range_from is null or range_until >= range_from)
);
create index availability_share_links_teacher on public.availability_share_links
  (teacher_id, created_at desc);
alter table public.availability_share_links enable row level security;
create policy availability_share_links_owner on public.availability_share_links
  for select to authenticated
  using (teacher_id = public.maestro_current_teacher_id());
create policy availability_share_links_revoke on public.availability_share_links
  for update to authenticated
  using (teacher_id = public.maestro_current_teacher_id())
  with check (teacher_id = public.maestro_current_teacher_id());

create function public.maestro_create_availability_link(
  p_expires_at timestamptz default null,
  p_range_from date default null,
  p_range_until date default null
)
returns jsonb language plpgsql security definer set search_path = '' as $$
declare
  v_teacher uuid := public.maestro_current_teacher_id();
  v_token text := encode(gen_random_bytes(32), 'hex');
  v_id uuid;
begin
  if v_teacher is null then
    raise exception 'Teacher authentication required' using errcode = '42501';
  end if;
  if p_expires_at is not null and p_expires_at <= now() then
    raise exception 'Expiration must be in the future' using errcode = '22023';
  end if;
  if p_range_from is not null and p_range_until is not null
      and p_range_until < p_range_from then
    raise exception 'Date range is invalid' using errcode = '22023';
  end if;
  insert into public.availability_share_links
    (teacher_id, token_hash, expires_at, range_from, range_until)
  values (v_teacher, sha256(convert_to(v_token, 'UTF8')),
    p_expires_at, p_range_from, p_range_until)
  returning id into v_id;
  return jsonb_build_object('id', v_id, 'token', v_token);
end;
$$;

-- This is the only public read path. It returns free slots and display metadata,
-- never lesson/student rows, exception reasons, or external calendar records.
create function public.maestro_shared_availability(
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
        exists (select 1 from public.teacher_availability_rules r
          where r.teacher_id = v_link.teacher_id and r.kind = 'available'
            and r.weekday = extract(isodow from d.day)
            and r.effective_from <= d.day
            and (r.effective_until is null or r.effective_until >= d.day)
            and r.start_minute <= part.minute
            and r.end_minute >= part.minute + 15)
        or exists (select 1 from public.teacher_availability_exceptions e
          where e.teacher_id = v_link.teacher_id and e.kind = 'available'
            and e.on_date = d.day and e.start_minute <= part.minute
            and e.end_minute >= part.minute + 15)
      )
      or exists (select 1 from public.teacher_availability_rules r
        where r.teacher_id = v_link.teacher_id and r.kind = 'unavailable'
          and r.weekday = extract(isodow from d.day)
          and r.effective_from <= d.day
          and (r.effective_until is null or r.effective_until >= d.day)
          and r.start_minute < part.minute + 15
          and r.end_minute > part.minute)
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

revoke all on function public.maestro_create_availability_link(timestamptz,date,date) from public;
grant execute on function public.maestro_create_availability_link(timestamptz,date,date) to authenticated;
revoke all on function public.maestro_shared_availability(text,date,integer) from public;
grant execute on function public.maestro_shared_availability(text,date,integer) to anon, authenticated;
