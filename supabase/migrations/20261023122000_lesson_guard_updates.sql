-- Grandfather existing overlapping lessons when only attendance/status changes.
-- Recheck every new or genuinely rescheduled active lesson.
drop trigger maestro_lesson_time_guard on public.lessons;
create trigger maestro_lesson_time_guard_insert
  before insert on public.lessons for each row
  execute function public.maestro_guard_lesson_time();
create trigger maestro_lesson_time_guard_update
  before update of lesson_date, hour, duration_minutes, teacher_id, status
  on public.lessons for each row
  when (
    old.lesson_date is distinct from new.lesson_date
    or old.hour is distinct from new.hour
    or old.duration_minutes is distinct from new.duration_minutes
    or old.teacher_id is distinct from new.teacher_id
    or (old.status = 'CANCELED' and new.status <> 'CANCELED')
  ) execute function public.maestro_guard_lesson_time();
