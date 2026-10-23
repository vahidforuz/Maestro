-- Local wall-clock minutes are interpreted in the teacher's IANA timezone.
-- A half-open interval permits adjacent periods without an overlap.
alter table public.teachers add column timezone text not null default 'America/Toronto';
create function public.maestro_guard_teacher_timezone()
returns trigger language plpgsql set search_path = '' as $$
begin
  if not exists (select 1 from pg_catalog.pg_timezone_names where name = new.timezone) then
    raise exception 'Unknown IANA timezone' using errcode = '22023';
  end if;
  return new;
end;
$$;
create trigger maestro_teacher_timezone_guard before insert or update of timezone
  on public.teachers for each row execute function public.maestro_guard_teacher_timezone();
revoke all on function public.maestro_guard_teacher_timezone() from public;

create table public.teacher_availability_rules (
  id uuid primary key default gen_random_uuid(),
  teacher_id uuid not null references public.teachers(id) on delete cascade,
  weekday smallint not null check (weekday between 1 and 7),
  start_minute smallint not null check (start_minute between 0 and 1439),
  end_minute smallint not null check (end_minute between 1 and 1440),
  kind text not null check (kind in ('available', 'unavailable')),
  effective_from date not null default current_date,
  effective_until date,
  created_at timestamptz not null default now(),
  check (start_minute < end_minute),
  check (effective_until is null or effective_until >= effective_from)
);

create table public.teacher_availability_exceptions (
  id uuid primary key default gen_random_uuid(),
  teacher_id uuid not null references public.teachers(id) on delete cascade,
  on_date date not null,
  start_minute smallint not null check (start_minute between 0 and 1439),
  end_minute smallint not null check (end_minute between 1 and 1440),
  kind text not null check (kind in ('available', 'unavailable')),
  created_at timestamptz not null default now(),
  check (start_minute < end_minute)
);

create index teacher_availability_rules_lookup on public.teacher_availability_rules
  (teacher_id, weekday, effective_from, effective_until);
create index teacher_availability_exceptions_lookup on public.teacher_availability_exceptions
  (teacher_id, on_date);

alter table public.teacher_availability_rules enable row level security;
alter table public.teacher_availability_exceptions enable row level security;
create policy teacher_availability_rules_owner on public.teacher_availability_rules
  for all to authenticated
  using (teacher_id = public.maestro_current_teacher_id())
  with check (teacher_id = public.maestro_current_teacher_id());
create policy teacher_availability_exceptions_owner on public.teacher_availability_exceptions
  for all to authenticated
  using (teacher_id = public.maestro_current_teacher_id())
  with check (teacher_id = public.maestro_current_teacher_id());

-- The existing lesson RPCs write the lessons table. This guard also covers
-- generated lessons and concurrent writes from different students.
create function public.maestro_guard_lesson_time()
returns trigger language plpgsql set search_path = '' as $$
declare
  v_start integer;
  v_end integer;
  v_duration integer;
begin
  if new.lesson_date is null or new.hour is null or new.teacher_id is null
      or new.status = 'CANCELED' then
    return new;
  end if;
  v_duration := coalesce(new.duration_minutes,
    (select default_lesson_duration from public.teachers where id = new.teacher_id));
  v_start := extract(hour from new.hour)::integer * 60 +
    extract(minute from new.hour)::integer;
  v_end := v_start + v_duration;
  if v_duration <= 0 or v_end > 1440 then
    raise exception 'Lesson time range is invalid' using errcode = '22023';
  end if;
  -- Serializes reservations for one teacher, including writes via separate RPCs.
  perform pg_advisory_xact_lock(hashtextextended(new.teacher_id::text, 0));
  if exists (
    select 1 from public.lessons other
    where other.teacher_id = new.teacher_id and other.lesson_date = new.lesson_date
      and other.id <> new.id and other.status <> 'CANCELED' and other.hour is not null
      and (extract(hour from other.hour)::integer * 60 +
           extract(minute from other.hour)::integer) < v_end
      and (extract(hour from other.hour)::integer * 60 +
           extract(minute from other.hour)::integer +
           coalesce(other.duration_minutes,
             (select default_lesson_duration from public.teachers where id = new.teacher_id))) > v_start
  ) then
    raise exception 'Lesson overlaps another scheduled lesson' using errcode = '23P01';
  end if;
  return new;
end;
$$;

create trigger maestro_lesson_time_guard before insert or update of
  lesson_date, hour, duration_minutes, teacher_id, status on public.lessons
  for each row execute function public.maestro_guard_lesson_time();
revoke all on function public.maestro_guard_lesson_time() from public;

create function public.maestro_set_lesson_duration(
  p_lesson_app_id bigint, p_duration integer
)
returns void language plpgsql security definer set search_path = '' as $$
declare
  v_teacher uuid := public.maestro_current_teacher_id();
begin
  if v_teacher is null then
    raise exception 'Teacher authentication required' using errcode = '42501';
  end if;
  if p_duration not in (30, 45, 60) then
    raise exception 'Duration must be 30, 45, or 60 minutes' using errcode = '22023';
  end if;
  update public.lessons set duration_minutes = p_duration, updated_at = now()
    where app_id = p_lesson_app_id and teacher_id = v_teacher;
  if not found then
    raise exception 'Lesson not found or not owned' using errcode = '42501';
  end if;
end;
$$;
revoke all on function public.maestro_set_lesson_duration(bigint,integer) from public;
grant execute on function public.maestro_set_lesson_duration(bigint,integer) to authenticated;

create function public.maestro_copy_availability_day(
  p_source_date date, p_target_weekdays integer[]
)
returns void language plpgsql security definer set search_path = '' as $$
declare
  v_teacher uuid := public.maestro_current_teacher_id();
  v_weekday integer;
  v_target date;
begin
  if v_teacher is null then
    raise exception 'Teacher authentication required' using errcode = '42501';
  end if;
  if p_target_weekdays is null or exists (
    select 1 from unnest(p_target_weekdays) day_number
    where day_number not between 1 and 7 or day_number = extract(isodow from p_source_date)
  ) then
    raise exception 'Invalid target weekday' using errcode = '22023';
  end if;
  perform pg_advisory_xact_lock(hashtextextended(v_teacher::text, 1));
  foreach v_weekday in array p_target_weekdays loop
    v_target := p_source_date + (v_weekday - extract(isodow from p_source_date)::integer);
    delete from public.teacher_availability_rules
      where teacher_id = v_teacher and weekday = v_weekday
        and effective_from >= v_target;
    update public.teacher_availability_rules
      set effective_until = v_target - 1
      where teacher_id = v_teacher and weekday = v_weekday
        and effective_from < v_target
        and (effective_until is null or effective_until >= v_target);
    insert into public.teacher_availability_rules
      (teacher_id, weekday, start_minute, end_minute, kind, effective_from)
    select v_teacher, v_weekday, start_minute, end_minute, kind, v_target
      from public.teacher_availability_rules
      where teacher_id = v_teacher
        and weekday = extract(isodow from p_source_date)
        and effective_from <= p_source_date
        and (effective_until is null or effective_until >= p_source_date);
  end loop;
end;
$$;
revoke all on function public.maestro_copy_availability_day(date,integer[]) from public;
grant execute on function public.maestro_copy_availability_day(date,integer[]) to authenticated;
