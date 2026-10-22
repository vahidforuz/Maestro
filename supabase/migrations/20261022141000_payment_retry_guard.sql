-- An idempotency key must not silently return a payment for another amount.
create or replace function public.maestro_record_payment(
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
    if v_payment.amount <> v_amount then
      raise exception 'Payment request key reused with a different amount' using errcode = '22023';
    end if;
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

