-- Teacher-local wall times. UTC conversion happens only at an export boundary.
create table public.teacher_time_blocks (
  id uuid primary key default gen_random_uuid(),
  teacher_id uuid not null references public.teachers(id) on delete cascade,
  title text not null check (length(trim(title)) between 1 and 120),
  category text not null check (category in ('sleep','vacation','breakTime','personal','other')),
  start_at timestamp without time zone not null,
  end_at timestamp without time zone not null,
  all_day boolean not null default false,
  repeat text not null default 'never' check (repeat in ('never','daily','weekly','custom')),
  weekdays integer[] not null default '{}',
  repeat_until date,
  notes text check (length(notes) <= 2000),
  created_at timestamptz not null default now(),
  unique (id, teacher_id),
  check (end_at > start_at and end_at <= start_at + interval '366 days'),
  check (repeat_until is null or repeat_until >= start_at::date),
  check (repeat = 'custom' or cardinality(weekdays) = 0),
  check (repeat <> 'custom' or cardinality(weekdays) between 1 and 7),
  check (weekdays <@ array[1,2,3,4,5,6,7]),
  check (not all_day or (start_at::time = time '00:00' and end_at::time = time '00:00'))
);
create index teacher_time_blocks_lookup on public.teacher_time_blocks (teacher_id, start_at, repeat_until);

create table public.teacher_time_block_exceptions (
  block_id uuid not null,
  teacher_id uuid not null,
  occurrence_date date not null,
  cancelled boolean not null default false,
  start_at timestamp without time zone,
  end_at timestamp without time zone,
  title text check (length(trim(title)) between 1 and 120),
  category text check (category in ('sleep','vacation','breakTime','personal','other')),
  notes text check (length(notes) <= 2000),
  primary key (block_id, occurrence_date),
  foreign key (block_id, teacher_id) references public.teacher_time_blocks(id, teacher_id) on delete cascade,
  check ((start_at is null and end_at is null) or
         (start_at is not null and end_at is not null and end_at > start_at)),
  check (not cancelled or (start_at is null and end_at is null and title is null
         and category is null and notes is null))
);
create index teacher_time_block_exceptions_lookup on public.teacher_time_block_exceptions (teacher_id, occurrence_date);

alter table public.teacher_time_blocks enable row level security;
alter table public.teacher_time_block_exceptions enable row level security;
create policy teacher_time_blocks_owner on public.teacher_time_blocks
  for all to authenticated
  using (teacher_id = public.maestro_current_teacher_id())
  with check (teacher_id = public.maestro_current_teacher_id());
create policy teacher_time_block_exceptions_owner on public.teacher_time_block_exceptions
  for all to authenticated
  using (teacher_id = public.maestro_current_teacher_id())
  with check (teacher_id = public.maestro_current_teacher_id());

-- Checks a local wall-clock range against normal series occurrences and
-- moved occurrences. The caller only receives a boolean, never private text.
create function public.maestro_time_block_busy(
  p_teacher uuid, p_day date, p_start integer, p_end integer
) returns boolean language sql stable set search_path = '' as $$
  select exists (
    select 1 from public.teacher_time_blocks b
    cross join lateral generate_series(
      greatest(b.start_at::date, p_day - (b.end_at::date - b.start_at::date) - 1)::timestamp,
      least(p_day, coalesce(b.repeat_until, p_day))::timestamp,
      interval '1 day') occurrence(day)
    where b.teacher_id = p_teacher
      and occurrence.day::date >= b.start_at::date
      and (b.repeat_until is null or occurrence.day::date <= b.repeat_until)
      and (b.repeat = 'daily'
        or (b.repeat = 'never' and occurrence.day::date = b.start_at::date)
        or (b.repeat = 'weekly' and extract(isodow from occurrence.day) = extract(isodow from b.start_at))
        or (b.repeat = 'custom' and extract(isodow from occurrence.day)::integer = any(b.weekdays)))
      and not exists (select 1 from public.teacher_time_block_exceptions x
        where x.block_id = b.id and x.occurrence_date = occurrence.day::date
          and (x.cancelled or x.start_at is not null))
      and occurrence.day::date + b.start_at::time < p_day::timestamp + make_interval(mins => p_end)
      and occurrence.day::date + b.start_at::time + (b.end_at - b.start_at) >
          p_day::timestamp + make_interval(mins => p_start)
  ) or exists (
    select 1 from public.teacher_time_block_exceptions x
    join public.teacher_time_blocks b on b.id = x.block_id
    where x.teacher_id = p_teacher and not x.cancelled and x.start_at is not null
      and x.start_at < p_day::timestamp + make_interval(mins => p_end)
      and x.end_at > p_day::timestamp + make_interval(mins => p_start)
  );
$$;
revoke all on function public.maestro_time_block_busy(uuid,date,integer,integer) from public;

-- Public slots must exclude blocks without disclosing titles or notes.
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
          coalesce(l.duration_minutes, v_teacher.default_lesson_duration) > m.minute)
    and not public.maestro_time_block_busy(
      v_link.teacher_id, d.day, m.minute, m.minute + p_duration);
  return jsonb_build_object('teacher', v_teacher.name,
    'timezone', v_teacher.timezone, 'weekStart', p_week_start,
    'durationMinutes', p_duration, 'slots', v_slots);
end;
$$;
