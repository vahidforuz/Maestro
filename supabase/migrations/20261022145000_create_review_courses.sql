-- A pending review keeps its original note. Its target lesson is created only
-- when the review is scheduled, so no payment or attendance row is touched.
alter table public.lessons drop constraint lessons_status_check;
alter table public.lessons add constraint lessons_status_check
  check (status in ('NOTHING','SCHEDULED','PRESENT','ABSENT','CANCELED','MOVED'));
alter table public.students drop constraint students_status_check;
alter table public.students add constraint students_status_check
  check (first_course_status in ('NOTHING','SCHEDULED','PRESENT','ABSENT','CANCELED','MOVED'));

create function public.maestro_ensure_review_lesson(
  p_student_id uuid, p_teacher_id uuid, p_source_id uuid, p_weeks integer
)
returns uuid language plpgsql security definer set search_path = ''
as $$
declare
  v_source public.lessons%rowtype;
  v_student public.students%rowtype;
  v_target uuid;
  v_due date;
begin
  if p_weeks is null then return null; end if;
  -- Student commands already hold this lock; it also serializes direct note
  -- writes so two reviews cannot create the same dated course concurrently.
  select * into v_student from public.students where id = p_student_id for update;
  select * into v_source from public.lessons
    where id = p_source_id and student_id = p_student_id
      and teacher_id = p_teacher_id;
  if v_source.id is null or v_source.lesson_date is null then return null; end if;
  v_due := v_source.lesson_date + p_weeks * 7;

  select id into v_target from public.lessons
    where student_id = p_student_id and teacher_id = p_teacher_id
      and lesson_date = v_due and status <> 'CANCELED'
    order by (project_id = v_source.project_id) desc, app_id limit 1;
  if v_target is not null then return v_target; end if;

  -- A canceled or another teacher's course already occupies this date. Use
  -- the next course this teacher owns rather than creating a duplicate date.
  if exists (select 1 from public.lessons
      where student_id = p_student_id and lesson_date = v_due) then
    select id into v_target from public.lessons
      where student_id = p_student_id and teacher_id = p_teacher_id
        and lesson_date > v_due and status <> 'CANCELED'
      order by lesson_date, app_id limit 1;
    return v_target;
  end if;

  insert into public.lessons (student_id, project_id, teacher_id, title, day,
    lesson_date, hour, duration_minutes, price, status, sort_order)
  values (p_student_id, v_source.project_id, p_teacher_id,
    'Course ' || ((select count(*) from public.lessons
      where project_id = v_source.project_id) + 1),
    upper(to_char(v_due, 'FMDay')), v_due,
    coalesce(v_source.hour, v_student.course_hour),
    (select default_lesson_duration from public.teachers where id = p_teacher_id),
    v_source.price, 'SCHEDULED',
    coalesce((select max(sort_order) + 1 from public.lessons
      where project_id = v_source.project_id), 0))
  returning id into v_target;
  return v_target;
end;
$$;

create or replace function public.maestro_date_review_target(
  p_student_id uuid, p_teacher_id uuid, p_lesson_id uuid, p_weeks integer
)
returns uuid language sql stable security definer set search_path = ''
as $$
  select target.id from public.lessons source
  join public.lessons target on target.student_id = source.student_id
    and target.teacher_id = source.teacher_id
  where source.id = p_lesson_id and source.student_id = p_student_id
    and source.teacher_id = p_teacher_id and source.lesson_date is not null
    and p_weeks is not null
    and target.lesson_date >= source.lesson_date + p_weeks * 7
    and target.id <> source.id and target.status <> 'CANCELED'
  order by target.lesson_date,
    (target.project_id = source.project_id) desc, target.app_id limit 1;
$$;

create or replace function public.maestro_set_note_review_target()
returns trigger language plpgsql security definer set search_path = ''
as $$
declare
  v_source_date date;
begin
  if tg_op = 'UPDATE' and new.review_history is distinct from old.review_history then
    return new;
  end if;
  if tg_op = 'UPDATE' and old.target_lesson_id is not null
      and new.target_lesson_id is null
      and new.review_date is not distinct from old.review_date
      and new.review_weeks is not distinct from old.review_weeks
      and new.review_status = 'PENDING' then
    return new;
  end if;
  if tg_op = 'UPDATE' and new.review_history like '%Rescheduled%'
      and new.review_weeks is not distinct from old.review_weeks
      and new.lesson_id = old.lesson_id and new.review_status = 'PENDING' then
    if new.target_lesson_id is null and new.review_date is not null then
      select id into new.target_lesson_id from public.lessons
        where student_id = new.student_id and teacher_id = new.teacher_id
          and id <> new.lesson_id and lesson_date >= new.review_date
          and status <> 'CANCELED'
        order by lesson_date, app_id limit 1;
      if new.target_lesson_id is not null then
        new.review_date := (select lesson_date from public.lessons
          where id = new.target_lesson_id);
      end if;
    end if;
    return new;
  end if;
  if new.review_status = 'PENDING' and new.review_weeks is not null then
    if tg_op = 'INSERT' or new.review_weeks is distinct from old.review_weeks
        or new.review_status is distinct from old.review_status then
      new.target_lesson_id := public.maestro_ensure_review_lesson(
        new.student_id, new.teacher_id, new.lesson_id, new.review_weeks);
    else
      new.target_lesson_id := public.maestro_date_review_target(
        new.student_id, new.teacher_id, new.lesson_id, new.review_weeks);
    end if;
    select lesson_date into v_source_date from public.lessons
      where id = new.lesson_id and student_id = new.student_id
        and teacher_id = new.teacher_id;
    new.review_date := case when new.target_lesson_id is not null
      then (select lesson_date from public.lessons where id = new.target_lesson_id)
      when v_source_date is not null then v_source_date + new.review_weeks * 7
      else null end;
  end if;
  return new;
end;
$$;

-- The same review request can be retried without producing a second source
-- note. The target course shows that source note through target_lesson_id.
create function public.maestro_skip_duplicate_review_note()
returns trigger language plpgsql security definer set search_path = ''
as $$
begin
  if new.review_weeks is null or new.review_status <> 'PENDING' then
    return new;
  end if;
  perform 1 from public.students where id = new.student_id for update;
  if exists (select 1 from public.lesson_notes
      where student_id = new.student_id and teacher_id = new.teacher_id
        and lesson_id = new.lesson_id and piece = new.piece
        and comment = new.comment and review_weeks = new.review_weeks
        and review_status = 'PENDING') then
    return null;
  end if;
  return new;
end;
$$;
create trigger maestro_aa_skip_duplicate_review_note
before insert on public.lesson_notes for each row
execute function public.maestro_skip_duplicate_review_note();

revoke all on function public.maestro_ensure_review_lesson(uuid,uuid,uuid,integer) from public;
revoke all on function public.maestro_skip_duplicate_review_note() from public;
