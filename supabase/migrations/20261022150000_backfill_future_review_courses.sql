-- Resolve pending reviews saved before automatic course creation was added.
-- Only future due dates are backfilled; past lessons are not manufactured.
do $$
declare
  v_note record;
  v_target uuid;
begin
  for v_note in
    select n.id, n.student_id, n.teacher_id, n.lesson_id, n.review_weeks
    from public.lesson_notes n
    join public.lessons source on source.id = n.lesson_id
    where n.review_status = 'PENDING' and n.review_weeks is not null
      and n.target_lesson_id is null and n.teacher_id is not null
      and source.lesson_date is not null
      and source.lesson_date + n.review_weeks * 7 >= current_date
    order by n.student_id, source.lesson_date, n.app_id
  loop
    v_target := public.maestro_ensure_review_lesson(
      v_note.student_id, v_note.teacher_id, v_note.lesson_id, v_note.review_weeks);
    if v_target is not null then
      update public.lesson_notes set target_lesson_id = v_target,
        review_date = (select lesson_date from public.lessons where id = v_target),
        updated_at = now()
      where id = v_note.id;
    end if;
  end loop;
end;
$$;
