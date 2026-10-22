-- Teacher-only commands preserve the existing Flutter screen contract. Each
-- function is one PostgreSQL transaction and resolves ownership from auth.uid().
create function public.maestro_current_teacher_id()
returns uuid language sql stable security definer set search_path = ''
as $$
  select id from public.teachers where user_id = auth.uid() and status = 'ACTIVE';
$$;

create function public.maestro_day_number(p_day text)
returns integer language sql immutable set search_path = ''
as $$
  select case upper(p_day)
    when 'MONDAY' then 1 when 'TUESDAY' then 2 when 'WEDNESDAY' then 3
    when 'THURSDAY' then 4 when 'FRIDAY' then 5 when 'SATURDAY' then 6
    when 'SUNDAY' then 7 else null end;
$$;

create function public.maestro_next_lesson_date(p_student_id uuid, p_day text)
returns date language plpgsql stable security definer set search_path = ''
as $$
declare
  v_day integer := public.maestro_day_number(p_day);
  v_date date;
begin
  if v_day is null then return null; end if;
  select max(lesson_date) into v_date from public.lessons
    where student_id = p_student_id and extract(isodow from lesson_date) = v_day;
  if v_date is null then
    v_date := current_date + ((v_day - extract(isodow from current_date)::integer + 7) % 7);
  else
    v_date := v_date + 7;
  end if;
  while exists (select 1 from public.lessons where student_id = p_student_id and lesson_date = v_date) loop
    v_date := v_date + 7;
  end loop;
  return v_date;
end;
$$;

create function public.maestro_create_student(p_data jsonb)
returns bigint language plpgsql security definer set search_path = ''
as $$
declare
  v_teacher uuid := public.maestro_current_teacher_id();
  v_student public.students%rowtype;
  v_project uuid;
  v_first text := trim(coalesce(p_data ->> 'firstName', ''));
  v_last text := trim(coalesce(p_data ->> 'familyName', ''));
  v_day text := nullif(upper(trim(coalesce(p_data ->> 'courseDay', ''))), '');
  v_hour time := nullif(p_data ->> 'courseHour', '')::time;
  v_price numeric(12,2) := coalesce((p_data ->> 'coursePrice')::numeric, 0);
begin
  if v_teacher is null then raise exception 'Teacher authentication required' using errcode = '42501'; end if;
  if v_first = '' and v_last = '' then raise exception 'Student name required' using errcode = '22023'; end if;
  if v_day is not null and public.maestro_day_number(v_day) is null then
    raise exception 'Invalid course day' using errcode = '22023';
  end if;
  if v_price < 0 then raise exception 'Course price must be nonnegative' using errcode = '22023'; end if;
  insert into public.students (first_name, family_name, name, email, phone,
    instrument, level, course_day, course_hour, course_price, next_project_id,
    next_course_id)
  values (v_first, v_last, trim(v_first || ' ' || v_last),
    nullif(p_data ->> 'email', ''), nullif(p_data ->> 'phone', ''),
    nullif(p_data ->> 'instrument', ''), nullif(p_data ->> 'level', ''),
    v_day, v_hour, v_price, 2, 2)
  returning * into v_student;
  insert into public.teacher_students (teacher_id, student_id)
    values (v_teacher, v_student.id);
  insert into public.projects (student_id, name, sort_order)
    values (v_student.id, 'Project 1', 0) returning id into v_project;
  insert into public.lessons (student_id, project_id, teacher_id, title, day,
    lesson_date, hour, duration_minutes, price, sort_order)
  values (v_student.id, v_project, v_teacher, 'First course', v_day,
    public.maestro_next_lesson_date(v_student.id, v_day), v_hour,
    (select default_lesson_duration from public.teachers where id = v_teacher),
    v_price, 0);
  return v_student.app_id;
end;
$$;

create function public.maestro_student_command(
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
  v_next date;
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
    update public.lesson_notes set source_lesson_id = null where source_lesson_id in
      (select id from public.lessons where project_id = v_project.id);
    update public.lesson_notes set target_lesson_id = null where target_lesson_id in
      (select id from public.lessons where project_id = v_project.id);
    update public.lesson_notes set accepted_lesson_id = null where accepted_lesson_id in
      (select id from public.lessons where project_id = v_project.id);
    delete from public.lesson_notes where lesson_id in
      (select id from public.lessons where project_id = v_project.id);
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
          where student_id = v_student.id and piece = v_piece.title and
            lesson_id in (select id from public.lessons where project_id = v_project.id);
      else
        delete from public.pieces where id = v_piece.id;
        update public.lesson_notes set piece = '' where student_id = v_student.id
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
      and n.target_lesson_id is null and n.review_weeks is not null
      and n.lesson_id in (select id from public.lessons where project_id = v_project.id)
      and (select count(*) from public.lessons l where l.project_id = v_project.id
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
        and review_weeks is not null and review_status = 'PENDING';
      update public.lesson_notes set review_date = v_date, updated_at = now()
        where target_lesson_id = v_lesson.id and review_status = 'PENDING';
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
      update public.lesson_notes set source_lesson_id = null where source_lesson_id = v_lesson.id;
      update public.lesson_notes set target_lesson_id = null where target_lesson_id = v_lesson.id;
      update public.lesson_notes set accepted_lesson_id = null where accepted_lesson_id = v_lesson.id;
      delete from public.lesson_notes where lesson_id = v_lesson.id;
      delete from public.lessons where id = v_lesson.id;
    else
      if p_operation = 'add_note' then
        v_weeks := nullif(p_payload ->> 'reviewWeeks', '')::integer;
        if v_weeks is not null and (v_weeks < 1 or v_weeks > 52) then
          raise exception 'Invalid review interval' using errcode = '22023';
        end if;
        if v_weeks is not null then
          select * into v_target from public.lessons where project_id = v_project.id
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
            select * into v_target from public.lessons where project_id = v_project.id
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

create function public.maestro_record_payment(
  p_student_app_id bigint, p_data jsonb, p_request_key uuid
)
returns bigint language plpgsql security definer set search_path = ''
as $$
declare
  v_teacher uuid := public.maestro_current_teacher_id();
  v_student public.students%rowtype;
  v_project public.projects%rowtype;
  v_payment public.payments%rowtype;
  v_amount numeric(12,2) := (p_data ->> 'amount')::numeric;
  v_credit numeric(12,2);
  v_covered integer;
  v_unpaid integer;
  v_create integer;
  v_index integer;
  v_date date;
begin
  if v_teacher is null then raise exception 'Teacher authentication required' using errcode = '42501'; end if;
  if p_request_key is null or v_amount is null then
    raise exception 'Payment amount and request key required' using errcode = '22023';
  end if;
  select * into v_student from public.students where app_id = p_student_app_id for update;
  if v_student.id is null or not public.is_teacher_for(v_student.id) then
    raise exception 'Student access denied' using errcode = '42501';
  end if;
  select * into v_payment from public.payments where request_key = p_request_key;
  if v_payment.id is not null then
    if v_payment.student_id <> v_student.id or v_payment.teacher_id <> v_teacher then
      raise exception 'Payment request key already belongs to another transaction' using errcode = '42501';
    end if;
    return v_payment.app_id;
  end if;
  select * into v_project from public.projects where student_id = v_student.id
    order by sort_order desc, app_id desc limit 1 for update;
  if v_project.id is null then raise exception 'Student has no project' using errcode = '22023'; end if;
  insert into public.payments (student_id, teacher_id, amount, currency,
    payment_date, method, note, request_key)
  values (v_student.id, v_teacher, v_amount,
    (select currency from public.teachers where id = v_teacher),
    coalesce(nullif(p_data ->> 'paymentDate', '')::date, current_date),
    nullif(p_data ->> 'method', ''), nullif(p_data ->> 'note', ''), p_request_key)
  returning * into v_payment;
  if v_student.course_price <= 0 then
    update public.students set payment_credit_balance = payment_credit_balance + v_amount,
      updated_at = now() where id = v_student.id;
    return v_payment.app_id;
  end if;
  v_credit := v_student.payment_credit_balance + v_amount;
  v_covered := floor(v_credit / v_student.course_price)::integer;
  v_unpaid := greatest(0, (select count(*) from public.lessons
    where project_id = v_project.id) - v_project.paid_course_count);
  v_create := greatest(0, v_covered - v_unpaid);
  update public.students set payment_credit_balance = round(v_credit -
    v_covered * v_student.course_price, 2), updated_at = now() where id = v_student.id;
  update public.projects set paid_course_count = paid_course_count + greatest(0, v_covered),
    updated_at = now() where id = v_project.id;
  for v_index in 1..v_create loop
    v_date := public.maestro_next_lesson_date(v_student.id, v_student.course_day);
    insert into public.lessons (student_id, project_id, teacher_id, title, day,
      lesson_date, hour, duration_minutes, price, sort_order)
    values (v_student.id, v_project.id, v_teacher,
      'Course ' || ((select count(*) from public.lessons where project_id = v_project.id) + 1),
      v_student.course_day, v_date, v_student.course_hour,
      (select default_lesson_duration from public.teachers where id = v_teacher),
      v_student.course_price,
      coalesce((select max(sort_order) + 1 from public.lessons where project_id = v_project.id), 0));
  end loop;
  return v_payment.app_id;
end;
$$;

revoke all on function public.maestro_current_teacher_id() from public;
revoke all on function public.maestro_day_number(text) from public;
revoke all on function public.maestro_next_lesson_date(uuid,text) from public;
revoke all on function public.maestro_create_student(jsonb) from public;
revoke all on function public.maestro_student_command(text,bigint,bigint,bigint,jsonb) from public;
revoke all on function public.maestro_record_payment(bigint,jsonb,uuid) from public;
grant execute on function public.maestro_current_teacher_id() to authenticated;
grant execute on function public.maestro_create_student(jsonb) to authenticated;
grant execute on function public.maestro_student_command(text,bigint,bigint,bigint,jsonb) to authenticated;
grant execute on function public.maestro_record_payment(bigint,jsonb,uuid) to authenticated;

-- Existing teacher settings form edits only its own teacher record.
grant update (name, first_name, last_name, studio_name, email, telephone,
  address, city, postal_code, main_instrument, other_instruments,
  default_lesson_duration, default_lesson_price, currency, profile_image_path,
  updated_at) on public.teachers to authenticated;
