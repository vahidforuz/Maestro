-- Resolve reviews by calendar weeks, including notes created before a future
-- lesson exists. The original note remains on its source lesson.
create or replace function public.maestro_date_review_target(
  p_student_id uuid, p_teacher_id uuid, p_lesson_id uuid, p_weeks integer
)
returns uuid language sql stable security definer set search_path = ''
as $$
  select target.id from public.lessons source
  join public.lessons target on target.project_id = source.project_id
    and target.student_id = source.student_id
    and target.teacher_id = source.teacher_id
  where source.id = p_lesson_id and source.student_id = p_student_id
    and source.teacher_id = p_teacher_id and source.lesson_date is not null
    and p_weeks is not null
    and target.lesson_date >= source.lesson_date + p_weeks * 7
    and target.lesson_date > source.lesson_date
    and target.status <> 'CANCELED'
    and target.id <> source.id
  order by target.lesson_date, target.app_id limit 1;
$$;

create function public.maestro_set_note_review_target()
returns trigger language plpgsql security definer set search_path = ''
as $$
declare
  v_source_date date;
begin
  -- Rescheduling deliberately starts from the course just reviewed. The
  -- existing command records that in review_history and supplies its target.
  if tg_op = 'UPDATE' and new.review_history is distinct from old.review_history then
    return new;
  end if;
  -- The existing delete-course command clears the target before deleting the
  -- lesson. Retarget only after the lesson is gone.
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
    select lesson_date into v_source_date from public.lessons
      where id = new.lesson_id and student_id = new.student_id
        and teacher_id = new.teacher_id;
    new.target_lesson_id := public.maestro_date_review_target(
      new.student_id, new.teacher_id, new.lesson_id, new.review_weeks);
    new.review_date := case when new.target_lesson_id is not null
      then (select lesson_date from public.lessons where id = new.target_lesson_id)
      when v_source_date is not null then v_source_date + new.review_weeks * 7
      else null end;
  end if;
  return new;
end;
$$;

create trigger maestro_note_calendar_review
before insert or update on public.lesson_notes for each row
execute function public.maestro_set_note_review_target();

-- The existing insertion trigger uses course position. Replace it so lessons
-- created after a note is saved also resolve reviews by their actual dates.
drop trigger maestro_lesson_insert_resolves_reviews on public.lessons;
create or replace function public.maestro_resolve_review_on_lesson_insert()
returns trigger language plpgsql security definer set search_path = ''
as $$
begin
  update public.lesson_notes n set review_date = n.review_date, updated_at = now()
  where n.student_id = new.student_id and n.teacher_id = new.teacher_id
    and n.review_status = 'PENDING' and n.review_weeks is not null
    and n.lesson_id in (select id from public.lessons
      where project_id = new.project_id and teacher_id = new.teacher_id);
  return new;
end;
$$;
create trigger maestro_lesson_insert_resolves_reviews
after insert on public.lessons for each row
execute function public.maestro_resolve_review_on_lesson_insert();

create function public.maestro_refresh_reviews_on_lesson_change()
returns trigger language plpgsql security definer set search_path = ''
as $$
begin
  if tg_op = 'UPDATE' then
    if old.lesson_date is not distinct from new.lesson_date then
      return new;
    end if;
  end if;
  update public.lesson_notes n set review_date = n.review_date, updated_at = now()
  where n.student_id = old.student_id and n.teacher_id = old.teacher_id
    and n.review_status = 'PENDING' and n.review_weeks is not null
    and (n.lesson_id = old.id or n.target_lesson_id = old.id
      or (tg_op = 'DELETE' and n.target_lesson_id is null
        and n.lesson_id in (select id from public.lessons
          where project_id = old.project_id and teacher_id = old.teacher_id)));
  if tg_op = 'DELETE' then return old; end if;
  return new;
end;
$$;
create trigger maestro_lesson_date_refreshes_reviews
after update of lesson_date or delete on public.lessons for each row
execute function public.maestro_refresh_reviews_on_lesson_change();

-- Repair pending reviews saved by the former course-position calculation.
update public.lesson_notes set review_date = review_date
where review_status = 'PENDING' and review_weeks is not null;

alter table public.lesson_notes add column copied_from_note_id uuid;
create unique index lesson_notes_one_future_copy
  on public.lesson_notes (student_id, lesson_id, copied_from_note_id)
  where copied_from_note_id is not null;

create function public.maestro_apply_notes_to_future_lessons(
  p_student_app_id bigint, p_course_app_id bigint
)
returns integer language plpgsql security definer set search_path = ''
as $$
declare
  v_teacher uuid := public.maestro_current_teacher_id();
  v_student uuid;
  v_source public.lessons%rowtype;
  v_count integer;
begin
  if v_teacher is null then
    raise exception 'Teacher authentication required' using errcode = '42501';
  end if;
  select id into v_student from public.students where app_id = p_student_app_id for update;
  if v_student is null or not public.is_teacher_for(v_student) then
    raise exception 'Student access denied' using errcode = '42501';
  end if;
  select * into v_source from public.lessons
    where app_id = p_course_app_id and student_id = v_student
      and teacher_id = v_teacher;
  if v_source.id is null or v_source.lesson_date is null then
    raise exception 'Dated course not found or not owned' using errcode = '42501';
  end if;
  insert into public.lesson_notes (
    student_id, lesson_id, teacher_id, piece, comment, created_date,
    source_lesson_id, sort_order, copied_from_note_id
  )
  select v_student, target.id, v_teacher, source_note.piece,
    source_note.comment, source_note.created_date, v_source.id,
    coalesce((select max(existing.sort_order) + 1 from public.lesson_notes existing
      where existing.lesson_id = target.id), 0)
      + row_number() over (partition by target.id order by source_note.sort_order, source_note.app_id) - 1,
    source_note.id
  from public.lesson_notes source_note
  cross join public.lessons target
  where source_note.lesson_id = v_source.id and source_note.student_id = v_student
    and source_note.teacher_id = v_teacher and source_note.copied_from_note_id is null
    and source_note.id = (select first_note.id from public.lesson_notes first_note
      where first_note.lesson_id = v_source.id and first_note.teacher_id = v_teacher
        and first_note.piece = source_note.piece and first_note.comment = source_note.comment
        and first_note.copied_from_note_id is null
      order by first_note.sort_order, first_note.app_id limit 1)
    and target.student_id = v_student and target.teacher_id = v_teacher
    and target.lesson_date > v_source.lesson_date and target.lesson_date > current_date
    and not exists (select 1 from public.lesson_notes existing
      where existing.student_id = v_student and existing.lesson_id = target.id
        and (existing.copied_from_note_id = source_note.id
          or (existing.piece = source_note.piece and existing.comment = source_note.comment)))
  on conflict (student_id, lesson_id, copied_from_note_id)
    where copied_from_note_id is not null do nothing;
  get diagnostics v_count = row_count;
  return v_count;
end;
$$;

revoke all on function public.maestro_date_review_target(uuid,uuid,uuid,integer) from public;
revoke all on function public.maestro_set_note_review_target() from public;
revoke all on function public.maestro_refresh_reviews_on_lesson_change() from public;
revoke all on function public.maestro_apply_notes_to_future_lessons(bigint,bigint) from public;
grant execute on function public.maestro_apply_notes_to_future_lessons(bigint,bigint) to authenticated;
