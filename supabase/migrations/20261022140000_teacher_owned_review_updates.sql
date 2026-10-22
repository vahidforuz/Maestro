-- Keep review/note mutations on the current teacher's rows for shared students.
create or replace function public.maestro_student_command(
  p_operation text, p_student_app_id bigint,
  p_project_app_id bigint default null, p_entity_app_id bigint default null,
  p_payload jsonb default '{}'::jsonb
)
returns bigint language plpgsql security definer set search_path = ''
as $$
declare
  v_teacher uuid := public.maestro_current_teacher_id();
  v_student public.students%rowtype;
  v_project public.projects%rowtype;
  v_lesson public.lessons%rowtype;
  v_note public.lesson_notes%rowtype;
  v_piece public.pieces%rowtype;
  v_target public.lessons%rowtype;
  v_weeks integer;
  v_date date;
  v_index integer;
  v_price numeric(12,2);
  v_day text;
  v_hour time;
  v_status text;
begin
  if v_teacher is null then raise exception 'Teacher authentication required' using errcode = '42501'; end if;
  select * into v_student from public.students where app_id = p_student_app_id for update;
  if v_student.id is null or not public.is_teacher_for(v_student.id) then
    raise exception 'Student access denied' using errcode = '42501';
  end if;
  if p_project_app_id is not null then
    select * into v_project from public.projects
      where app_id = p_project_app_id and student_id = v_student.id for update;
    if v_project.id is null then raise exception 'Project not found' using errcode = '22023'; end if;
  end if;

  if p_operation = 'add_project' then
    insert into public.projects (student_id, name, sort_order)
    values (v_student.id, coalesce(nullif(trim(p_payload ->> 'name'), ''), 'Project'),
      coalesce((select max(sort_order) + 1 from public.projects where student_id = v_student.id), 0));
  elsif p_operation = 'update_project' then
    if v_project.id is null then raise exception 'Project required' using errcode = '22023'; end if;
    update public.projects set name = coalesce(nullif(trim(p_payload ->> 'name'), ''), name),
      updated_at = now() where id = v_project.id;
  elsif p_operation = 'delete_project' then
    if v_project.id is null then raise exception 'Project required' using errcode = '22023'; end if;
    if (select count(*) from public.projects where student_id = v_student.id) <= 1 then
      return p_student_app_id;
    end if;
    if exists (select 1 from public.lessons where project_id = v_project.id
      and teacher_id is distinct from v_teacher) then
      raise exception 'Cannot delete a project containing another teacher''s lessons' using errcode = '42501';
    end if;
    if exists (select 1 from public.lesson_notes where lesson_id in
      (select id from public.lessons where project_id = v_project.id)
      and teacher_id is distinct from v_teacher) then
      raise exception 'Cannot delete a project containing another teacher''s notes' using errcode = '42501';
    end if;
    update public.lesson_notes set source_lesson_id = null where source_lesson_id in
      (select id from public.lessons where project_id = v_project.id)
      and teacher_id = v_teacher;
    update public.lesson_notes set target_lesson_id = null where target_lesson_id in
      (select id from public.lessons where project_id = v_project.id)
      and teacher_id = v_teacher;
    update public.lesson_notes set accepted_lesson_id = null where accepted_lesson_id in
      (select id from public.lessons where project_id = v_project.id)
      and teacher_id = v_teacher;
    delete from public.lesson_notes where lesson_id in
      (select id from public.lessons where project_id = v_project.id)
      and teacher_id = v_teacher;
    delete from public.lessons where project_id = v_project.id;
    delete from public.pieces where project_id = v_project.id;
    delete from public.projects where id = v_project.id;
  elsif p_operation in ('add_piece', 'update_piece', 'delete_piece') then
    if v_project.id is null then raise exception 'Project required' using errcode = '22023'; end if;
    if p_operation = 'add_piece' then
      insert into public.pieces (student_id, project_id, title, sort_order)
      values (v_student.id, v_project.id, coalesce(p_payload ->> 'title', ''),
        coalesce((select max(sort_order) + 1 from public.pieces where project_id = v_project.id), 0));
    else
      v_index := (p_payload ->> 'pieceIndex')::integer;
      if v_index is null or v_index < 0 then raise exception 'Piece index invalid' using errcode = '22023'; end if;
      select * into v_piece from public.pieces where project_id = v_project.id
        order by sort_order, app_id offset v_index limit 1;
      if v_piece.id is null then raise exception 'Piece not found' using errcode = '22023'; end if;
      if p_operation = 'update_piece' then
        update public.pieces set title = coalesce(p_payload ->> 'title', '') where id = v_piece.id;
        update public.lesson_notes set piece = coalesce(p_payload ->> 'title', '')
          where student_id = v_student.id and teacher_id = v_teacher
            and piece = v_piece.title and lesson_id in (select id from public.lessons where project_id = v_project.id);
      else
        delete from public.pieces where id = v_piece.id;
        update public.lesson_notes set piece = '' where student_id = v_student.id and teacher_id = v_teacher
          and piece = v_piece.title and lesson_id in
            (select id from public.lessons where project_id = v_project.id);
      end if;
    end if;
  elsif p_operation = 'add_lesson' then
    if v_project.id is null then raise exception 'Project required' using errcode = '22023'; end if;
    insert into public.lessons (student_id, project_id, teacher_id, title, day,
      lesson_date, hour, duration_minutes, price, sort_order)
    values (v_student.id, v_project.id, v_teacher,
      'Course ' || ((select count(*) from public.lessons where project_id = v_project.id) + 1),
      v_student.course_day, public.maestro_next_lesson_date(v_student.id, v_student.course_day),
      v_student.course_hour, (select default_lesson_duration from public.teachers where id = v_teacher),
      v_student.course_price,
      coalesce((select max(sort_order) + 1 from public.lessons where project_id = v_project.id), 0))
    returning * into v_lesson;
    update public.lesson_notes n set target_lesson_id = v_lesson.id,
      review_date = v_lesson.lesson_date, updated_at = now()
    where n.student_id = v_student.id and n.review_status = 'PENDING'
      and n.teacher_id = v_teacher and n.target_lesson_id is null and n.review_weeks is not null
      and n.lesson_id in (select id from public.lessons where project_id = v_project.id)
      and (select count(*) from public.lessons l where l.project_id = v_project.id and l.teacher_id = v_teacher
        and (l.sort_order, l.app_id) >
          (select s.sort_order, s.app_id from public.lessons s where s.id = n.lesson_id)
        and (l.sort_order, l.app_id) <= (v_lesson.sort_order, v_lesson.app_id)) = n.review_weeks;
  elsif p_operation in ('update_lesson', 'delete_lesson', 'add_note', 'update_note', 'delete_note') then
    if v_project.id is null then raise exception 'Project required' using errcode = '22023'; end if;
    select * into v_lesson from public.lessons where app_id = p_entity_app_id
      and student_id = v_student.id and project_id = v_project.id and teacher_id = v_teacher for update;
    if v_lesson.id is null then raise exception 'Lesson not found or not owned' using errcode = '42501'; end if;
    if p_operation = 'update_lesson' then
      v_day := nullif(upper(coalesce(p_payload ->> 'day', '')), '');
      if v_day is not null and public.maestro_day_number(v_day) is null then
        raise exception 'Invalid course day' using errcode = '22023';
      end if;
      v_date := nullif(p_payload ->> 'date', '')::date;
      v_hour := nullif(p_payload ->> 'hour', '')::time;
      v_price := (p_payload ->> 'price')::numeric;
      v_status := coalesce(p_payload ->> 'status', 'NOTHING');
      if v_price is null or v_price < 0 then raise exception 'Invalid course price' using errcode = '22023'; end if;
      update public.lessons set title = coalesce(nullif(p_payload ->> 'title', ''), title),
        day = v_day, lesson_date = v_date, hour = v_hour, price = v_price,
        status = v_status, assignment = coalesce(p_payload ->> 'assignment', ''),
        comment = coalesce(p_payload ->> 'comment', ''),
        homework_next_lesson = coalesce(p_payload ->> 'homeworkNextLesson', ''),
        updated_at = now() where id = v_lesson.id;
      update public.lesson_notes set review_date =
        case when v_date is null then null else v_date + review_weeks * 7 end,
        updated_at = now() where lesson_id = v_lesson.id and target_lesson_id is null
        and teacher_id = v_teacher and review_weeks is not null and review_status = 'PENDING';
      update public.lesson_notes set review_date = v_date, updated_at = now()
        where target_lesson_id = v_lesson.id and teacher_id = v_teacher
          and review_status = 'PENDING';
      if v_lesson.id = (select id from public.lessons where student_id = v_student.id
          order by created_at, app_id limit 1) then
        update public.students set course_day = v_day, course_hour = v_hour,
          course_price = v_price, present = (v_status = 'PRESENT'),
          first_course_status = v_status,
          next_week_assignment = coalesce(p_payload ->> 'assignment', ''),
          this_week_comment = coalesce(p_payload ->> 'comment', ''), updated_at = now()
        where id = v_student.id;
      end if;
    elsif p_operation = 'delete_lesson' then
      if (select count(*) from public.lessons where student_id = v_student.id) <= 1 then
        return p_student_app_id;
      end if;
      update public.lesson_notes set source_lesson_id = null where source_lesson_id = v_lesson.id
        and teacher_id = v_teacher;
      update public.lesson_notes set target_lesson_id = null where target_lesson_id = v_lesson.id
        and teacher_id = v_teacher;
      update public.lesson_notes set accepted_lesson_id = null where accepted_lesson_id = v_lesson.id
        and teacher_id = v_teacher;
      delete from public.lesson_notes where lesson_id = v_lesson.id and teacher_id = v_teacher;
      delete from public.lessons where id = v_lesson.id;
    else
      if p_operation = 'add_note' then
        v_weeks := nullif(p_payload ->> 'reviewWeeks', '')::integer;
        if v_weeks is not null and (v_weeks < 1 or v_weeks > 52) then
          raise exception 'Invalid review interval' using errcode = '22023';
        end if;
        if v_weeks is not null then
          select * into v_target from public.lessons where project_id = v_project.id and teacher_id = v_teacher
            and (sort_order, app_id) > (v_lesson.sort_order, v_lesson.app_id)
            order by sort_order, app_id offset (v_weeks - 1) limit 1;
        end if;
        insert into public.lesson_notes (student_id, lesson_id, teacher_id, piece,
          comment, created_date, review_weeks, review_date, review_status,
          source_lesson_id, target_lesson_id, sort_order)
        values (v_student.id, v_lesson.id, v_teacher,
          coalesce(p_payload ->> 'piece', ''), coalesce(p_payload ->> 'comment', ''),
          current_date, v_weeks,
          case when v_weeks is null then null when v_target.id is not null
            then v_target.lesson_date when v_lesson.lesson_date is not null
            then v_lesson.lesson_date + v_weeks * 7 else null end,
          case when v_weeks is null then null else 'PENDING' end,
          v_lesson.id, v_target.id,
          coalesce((select max(sort_order) + 1 from public.lesson_notes where lesson_id = v_lesson.id), 0));
      else
        select * into v_note from public.lesson_notes where app_id = (p_payload ->> 'noteId')::bigint
          and lesson_id = v_lesson.id and teacher_id = v_teacher for update;
        if v_note.id is null then raise exception 'Note not found or not owned' using errcode = '42501'; end if;
        if p_operation = 'delete_note' then
          delete from public.lesson_notes where id = v_note.id;
        else
          v_weeks := nullif(p_payload ->> 'reviewWeeks', '')::integer;
          if v_weeks is not null and (v_weeks < 1 or v_weeks > 52) then
            raise exception 'Invalid review interval' using errcode = '22023';
          end if;
          if v_weeks is not null then
            select * into v_target from public.lessons where project_id = v_project.id and teacher_id = v_teacher
              and (sort_order, app_id) > (v_lesson.sort_order, v_lesson.app_id)
              order by sort_order, app_id offset (v_weeks - 1) limit 1;
          end if;
          update public.lesson_notes set piece = coalesce(p_payload ->> 'piece', ''),
            comment = coalesce(p_payload ->> 'comment', ''), review_weeks = v_weeks,
            review_date = case when v_weeks is null then null when v_target.id is not null
              then v_target.lesson_date when v_lesson.lesson_date is not null
              then v_lesson.lesson_date + v_weeks * 7 else null end,
            review_status = case when v_weeks is null then null else 'PENDING' end,
            target_lesson_id = v_target.id, source_lesson_id = v_lesson.id,
            updated_at = now() where id = v_note.id;
        end if;
      end if;
    end if;
  elsif p_operation in ('accept_review', 'reschedule_review') then
    select * into v_note from public.lesson_notes where app_id = p_entity_app_id
      and student_id = v_student.id and teacher_id = v_teacher for update;
    select * into v_lesson from public.lessons where app_id = (p_payload ->> 'courseId')::bigint
      and student_id = v_student.id and teacher_id = v_teacher;
    if v_note.id is null or v_lesson.id is null then
      raise exception 'Review or lesson not owned' using errcode = '42501';
    end if;
    if v_note.review_status <> 'PENDING' then
      raise exception 'Review is not pending' using errcode = '22023';
    end if;
    if p_operation = 'accept_review' then
      update public.lesson_notes set review_status = 'ACCEPTED',
        accepted_lesson_id = v_lesson.id, reviewed_date = v_lesson.lesson_date,
        review_history = review_history || case when review_history = '' then '' else E'\n' end
          || 'Course ' || v_lesson.app_id || ' - Reviewed', updated_at = now()
      where id = v_note.id;
    else
      select * into v_target from public.lessons where student_id = v_student.id
        and teacher_id = v_teacher and lesson_date > v_lesson.lesson_date
        order by lesson_date limit 1;
      update public.lesson_notes set review_weeks = 1, review_status = 'PENDING',
        target_lesson_id = v_target.id,
        review_date = case when v_target.id is not null then v_target.lesson_date
          when v_lesson.lesson_date is not null then v_lesson.lesson_date + 7 else null end,
        review_history = review_history || case when review_history = '' then '' else E'\n' end
          || 'Course ' || v_lesson.app_id || ' - Rescheduled', updated_at = now()
      where id = v_note.id;
    end if;
  else
    raise exception 'Unsupported student operation' using errcode = '22023';
  end if;
  return p_student_app_id;
end;
$$;

-- Payment allocations insert lessons through a different RPC. Resolve pending
-- review targets for either insertion path, scoped to the lesson's teacher.
create function public.maestro_resolve_review_on_lesson_insert()
returns trigger language plpgsql security definer set search_path = ''
as $$
begin
  update public.lesson_notes n set target_lesson_id = new.id,
    review_date = new.lesson_date, updated_at = now()
  where n.student_id = new.student_id and n.teacher_id = new.teacher_id
    and n.review_status = 'PENDING' and n.review_weeks is not null
    and n.target_lesson_id is null
    and n.lesson_id in (select id from public.lessons
      where project_id = new.project_id and teacher_id = new.teacher_id)
    and (select count(*) from public.lessons l
      where l.project_id = new.project_id and l.teacher_id = new.teacher_id
        and (l.sort_order, l.app_id) >
          (select s.sort_order, s.app_id from public.lessons s where s.id = n.lesson_id)
        and (l.sort_order, l.app_id) <= (new.sort_order, new.app_id)) = n.review_weeks;
  return new;
end;
$$;

create trigger maestro_lesson_insert_resolves_reviews
after insert on public.lessons for each row
execute function public.maestro_resolve_review_on_lesson_insert();

revoke all on function public.maestro_resolve_review_on_lesson_insert() from public;

