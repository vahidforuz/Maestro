-- A piece is a shared business record; progress/instructions belong to one
-- teacher's relationship with that student.
create table public.teacher_piece_progress (
  teacher_id uuid not null references public.teachers(id),
  piece_id uuid not null references public.pieces(id) on delete cascade,
  status text not null default 'IN_PROGRESS' check (status in
    ('NOT_STARTED', 'IN_PROGRESS', 'PRACTICING', 'READY', 'COMPLETE')),
  instructions text not null default '',
  instructions_shared boolean not null default false,
  updated_at timestamptz not null default now(),
  primary key (teacher_id, piece_id)
);
create index teacher_piece_progress_piece on public.teacher_piece_progress(piece_id);
alter table public.teacher_piece_progress enable row level security;
revoke all on public.teacher_piece_progress from anon, authenticated;

create function public.maestro_teacher_piece_progress(p_student_app_id bigint)
returns jsonb language plpgsql stable security definer set search_path = '' as $$
declare
  v_teacher uuid := public.maestro_current_teacher_id();
  v_student uuid;
  v_result jsonb;
begin
  select id into v_student from public.students where app_id = p_student_app_id;
  if v_teacher is null or v_student is null or not public.is_teacher_for(v_student) then
    raise exception 'Student access denied' using errcode = '42501';
  end if;
  select coalesce(jsonb_agg(jsonb_build_object(
    'appId', p.app_id, 'title', p.title, 'project', pr.name,
    'status', coalesce(progress.status, 'IN_PROGRESS'),
    'instructions', coalesce(progress.instructions, ''),
    'instructionsShared', coalesce(progress.instructions_shared, false))
    order by pr.sort_order, p.sort_order), '[]'::jsonb)
  into v_result from public.pieces p
  join public.projects pr on pr.id = p.project_id
  left join public.teacher_piece_progress progress
    on progress.piece_id = p.id and progress.teacher_id = v_teacher
  where p.student_id = v_student and exists (select 1 from public.lessons l
    where l.project_id = pr.id and l.teacher_id = v_teacher);
  return v_result;
end;
$$;

create function public.maestro_set_piece_progress(
  p_piece_app_id bigint, p_status text, p_instructions text,
  p_instructions_shared boolean)
returns void language plpgsql security definer set search_path = '' as $$
declare
  v_teacher uuid := public.maestro_current_teacher_id();
  v_piece public.pieces%rowtype;
begin
  select * into v_piece from public.pieces where app_id = p_piece_app_id;
  if v_teacher is null or v_piece.id is null or
      not public.is_teacher_for(v_piece.student_id) or
      not exists (select 1 from public.lessons l where l.project_id = v_piece.project_id
        and l.teacher_id = v_teacher) then
    raise exception 'Piece access denied' using errcode = '42501';
  end if;
  insert into public.teacher_piece_progress
    (teacher_id, piece_id, status, instructions, instructions_shared)
  values (v_teacher, v_piece.id, p_status, coalesce(p_instructions, ''),
    coalesce(p_instructions_shared, false))
  on conflict (teacher_id, piece_id) do update set
    status = excluded.status, instructions = excluded.instructions,
    instructions_shared = excluded.instructions_shared, updated_at = now();
end;
$$;

-- The projection computes finance values per teacher. The historical
-- students.payment_credit_balance is global, so it cannot be used for a
-- student with multiple teachers.
create or replace function public.maestro_student_portal_data()
returns jsonb language sql stable security definer set search_path = '' as $$
  select coalesce(jsonb_agg(jsonb_build_object(
    'teacherId', t.id, 'teacherName', t.name, 'studentId', s.id,
    'studentAppId', s.app_id, 'studentName', s.name,
    'permissions', jsonb_build_object(
      'viewCourses', a.view_courses, 'viewNotes', a.view_notes,
      'viewReviews', a.view_reviews, 'viewPieces', a.view_pieces,
      'viewPayments', a.view_payments, 'viewBalance', a.view_balance,
      'requestChanges', a.request_changes),
    'courses', case when a.view_courses then (
      select coalesce(jsonb_agg(jsonb_build_object(
        'id', l.id, 'appId', l.app_id, 'title', l.title,
        'date', l.lesson_date, 'hour', l.hour,
        'durationMinutes', l.duration_minutes, 'status', l.status,
        'assignment', case when a.view_reviews then l.assignment else null end,
        'homework', case when a.view_reviews then l.homework_next_lesson else null end)
        order by l.lesson_date nulls last, l.app_id), '[]'::jsonb)
      from public.lessons l where l.student_id = s.id and l.teacher_id = t.id)
      else '[]'::jsonb end,
    'notes', case when a.view_notes or a.view_reviews then (
      select coalesce(jsonb_agg(jsonb_build_object(
        'id', n.id, 'appId', n.app_id, 'courseId', n.lesson_id,
        'courseTitle', (select l.title from public.lessons l
          where l.id = n.lesson_id and l.teacher_id = t.id),
        'piece', case when a.view_notes and n.student_shared then n.piece else null end,
        'comment', case when a.view_notes and n.student_shared then n.comment else null end,
        'createdDate', n.created_date,
        'reviewDate', case when a.view_reviews then n.review_date else null end,
        'reviewStatus', case when a.view_reviews then n.review_status else null end,
        'targetCourseId', case when a.view_reviews then n.target_lesson_id else null end)
        order by n.created_date desc nulls last, n.app_id), '[]'::jsonb)
      from public.lesson_notes n where n.student_id = s.id and n.teacher_id = t.id
        and ((a.view_notes and n.student_shared and (n.piece <> '' or n.comment <> ''))
          or (a.view_reviews and n.review_date is not null)))
      else '[]'::jsonb end,
    'pieces', case when a.view_pieces then (
      select coalesce(jsonb_agg(jsonb_build_object('title', p.title,
        'project', pr.name, 'status', coalesce(progress.status, 'IN_PROGRESS'),
        'instructions', case when progress.instructions_shared then
          progress.instructions else null end)
        order by pr.sort_order, p.sort_order), '[]'::jsonb)
      from public.pieces p join public.projects pr on pr.id = p.project_id
      left join public.teacher_piece_progress progress on progress.piece_id = p.id
        and progress.teacher_id = t.id
      where p.student_id = s.id and exists (select 1 from public.lessons l
        where l.project_id = pr.id and l.teacher_id = t.id))
      else '[]'::jsonb end,
    'payments', case when a.view_payments then (
      select coalesce(jsonb_agg(jsonb_build_object('date', p.payment_date,
        'amount', p.amount, 'method', p.method) order by p.payment_date desc), '[]'::jsonb)
      from public.payments p where p.student_id = s.id and p.teacher_id = t.id)
      else '[]'::jsonb end,
    'balance', case when a.view_balance then
      (select coalesce(sum(p.amount), 0) from public.payments p
        where p.student_id = s.id and p.teacher_id = t.id)
      - (select coalesce(sum(l.price), 0) from public.lessons l
        where l.student_id = s.id and l.teacher_id = t.id
          and l.status in ('PRESENT', 'ABSENT')) else null end,
    'courseCredits', case when a.view_balance and
      (select count(*) from public.teacher_students ts2 where
        ts2.student_id = s.id and ts2.active) = 1 then (
      select coalesce(sum(pr.paid_course_count), 0) from public.projects pr
      where pr.student_id = s.id) else null end
  ) order by t.name), '[]'::jsonb)
  from public.student_portal_access a
  join public.teacher_students ts on ts.teacher_id = a.teacher_id
    and ts.student_id = a.student_id and ts.active
  join public.teachers t on t.id = a.teacher_id and t.status = 'ACTIVE'
  join public.students s on s.id = a.student_id
  where a.user_id = auth.uid() and a.enabled;
$$;

revoke all on function public.maestro_teacher_piece_progress(bigint),
  public.maestro_set_piece_progress(bigint,text,text,boolean) from public;
grant execute on function public.maestro_teacher_piece_progress(bigint),
  public.maestro_set_piece_progress(bigint,text,text,boolean) to authenticated;
