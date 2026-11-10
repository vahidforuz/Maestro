-- Practice videos are independent of lessons, payments, and message media.
create table public.practice_video_settings (
  teacher_id uuid primary key references public.teachers(id),
  enabled boolean not null default false,
  price_cents bigint not null default 0 check (price_cents >= 0),
  currency text not null default 'CAD' check (currency ~ '^[A-Z]{3}$'),
  updated_at timestamptz not null default now()
);

create table public.practice_video_submissions (
  id uuid primary key default gen_random_uuid(),
  teacher_id uuid not null,
  student_id uuid not null,
  created_by uuid not null references auth.users(id),
  storage_path text not null unique,
  mime_type text not null check (mime_type in ('video/mp4', 'video/quicktime', 'video/webm')),
  size_bytes bigint not null check (size_bytes > 0 and size_bytes <= 104857600),
  note text not null default '' check (char_length(note) <= 2000),
  status text not null default 'draft' check (status in ('draft', 'submitted', 'reviewed')),
  created_at timestamptz not null default now(),
  submitted_at timestamptz,
  foreign key (teacher_id, student_id)
    references public.teacher_students(teacher_id, student_id)
);
create index practice_video_submissions_teacher_date
  on public.practice_video_submissions(teacher_id, submitted_at desc);
create index practice_video_submissions_student_date
  on public.practice_video_submissions(student_id, submitted_at desc);

create table public.practice_video_reviews (
  id uuid primary key default gen_random_uuid(),
  submission_id uuid not null unique references public.practice_video_submissions(id),
  teacher_id uuid not null references public.teachers(id),
  feedback text not null check (char_length(trim(feedback)) between 1 and 10000),
  completed_at timestamptz not null default now()
);

create table public.practice_video_charges (
  id uuid primary key default gen_random_uuid(),
  review_id uuid not null unique references public.practice_video_reviews(id),
  teacher_id uuid not null references public.teachers(id),
  student_id uuid not null references public.students(id),
  amount_cents bigint not null check (amount_cents >= 0),
  currency text not null check (currency ~ '^[A-Z]{3}$'),
  completed_at timestamptz not null,
  payment_status text not null default 'unpaid'
    check (payment_status in ('unpaid', 'paid')),
  paid_at timestamptz,
  check ((payment_status = 'paid') = (paid_at is not null))
);
create index practice_video_charges_teacher_date
  on public.practice_video_charges(teacher_id, completed_at desc, student_id);

-- These helpers inspect existing relationships without changing their rules.
create function public.practice_video_teacher_access(p_teacher uuid, p_student uuid)
returns boolean language sql stable security definer set search_path = '' as $$
  select auth.uid() is not null and exists (
    select 1 from public.teachers t
    join public.teacher_students ts on ts.teacher_id = t.id
    where t.id = p_teacher and t.user_id = auth.uid()
      and ts.student_id = p_student and ts.active
  );
$$;

create function public.practice_video_student_access(p_teacher uuid, p_student uuid)
returns boolean language sql stable security definer set search_path = '' as $$
  select auth.uid() is not null and exists (
    select 1 from public.student_portal_access a
    join public.teacher_students ts
      on ts.teacher_id = a.teacher_id and ts.student_id = a.student_id
    where a.teacher_id = p_teacher and a.student_id = p_student
      and a.user_id = auth.uid() and a.enabled and ts.active
  );
$$;

alter table public.practice_video_settings enable row level security;
alter table public.practice_video_submissions enable row level security;
alter table public.practice_video_reviews enable row level security;
alter table public.practice_video_charges enable row level security;

create policy practice_video_settings_read on public.practice_video_settings
  for select to authenticated using (
    exists (select 1 from public.teachers t
      where t.id = teacher_id and t.user_id = auth.uid())
    or exists (select 1 from public.student_portal_access a
      join public.teacher_students ts
        on ts.teacher_id = a.teacher_id and ts.student_id = a.student_id
      where a.teacher_id = practice_video_settings.teacher_id
        and a.user_id = auth.uid() and a.enabled and ts.active)
  );
create policy practice_video_settings_insert on public.practice_video_settings
  for insert to authenticated with check (
    exists (select 1 from public.teachers t
      where t.id = teacher_id and t.user_id = auth.uid())
  );
create policy practice_video_settings_update on public.practice_video_settings
  for update to authenticated using (
    exists (select 1 from public.teachers t
      where t.id = teacher_id and t.user_id = auth.uid())
  ) with check (
    exists (select 1 from public.teachers t
      where t.id = teacher_id and t.user_id = auth.uid())
  );

create policy practice_video_submissions_read on public.practice_video_submissions
  for select to authenticated using (
    public.practice_video_teacher_access(teacher_id, student_id)
    or (created_by = auth.uid() and
      public.practice_video_student_access(teacher_id, student_id))
  );
create policy practice_video_reviews_read on public.practice_video_reviews
  for select to authenticated using (exists (
    select 1 from public.practice_video_submissions s
    where s.id = submission_id and s.teacher_id = teacher_id
      and (public.practice_video_teacher_access(s.teacher_id, s.student_id)
        or (s.created_by = auth.uid() and
          public.practice_video_student_access(s.teacher_id, s.student_id)))
  ));
create policy practice_video_charges_teacher_read on public.practice_video_charges
  for select to authenticated using (
    public.practice_video_teacher_access(teacher_id, student_id)
  );

revoke all on public.practice_video_settings, public.practice_video_submissions,
  public.practice_video_reviews, public.practice_video_charges from anon, authenticated;
grant select, insert on public.practice_video_settings to authenticated;
grant update(enabled, price_cents, currency, updated_at)
  on public.practice_video_settings to authenticated;
grant select on public.practice_video_submissions, public.practice_video_reviews,
  public.practice_video_charges to authenticated;

create function public.practice_video_start_submission(
  p_teacher uuid, p_student uuid, p_extension text, p_size_bytes bigint,
  p_note text default '')
returns jsonb language plpgsql security definer set search_path = '' as $$
declare
  v_id uuid := gen_random_uuid();
  v_mime text;
  v_path text;
begin
  if not public.practice_video_student_access(p_teacher, p_student)
      or not exists (select 1 from public.practice_video_settings
        where teacher_id = p_teacher and enabled) then
    raise exception 'Practice video submission is unavailable' using errcode = '42501';
  end if;
  v_mime := case lower(p_extension)
    when 'mp4' then 'video/mp4'
    when 'mov' then 'video/quicktime'
    when 'webm' then 'video/webm'
    else null end;
  if v_mime is null or p_size_bytes is null or p_size_bytes < 1
      or p_size_bytes > 104857600 or char_length(coalesce(p_note, '')) > 2000 then
    raise exception 'Invalid practice video' using errcode = '22023';
  end if;
  v_path := p_teacher::text || '/' || p_student::text || '/' ||
    v_id::text || '/video.' || lower(p_extension);
  insert into public.practice_video_submissions
    (id, teacher_id, student_id, created_by, storage_path, mime_type,
      size_bytes, note)
    values (v_id, p_teacher, p_student, auth.uid(), v_path, v_mime,
      p_size_bytes, coalesce(p_note, ''));
  return jsonb_build_object('id', v_id, 'path', v_path, 'mimeType', v_mime);
end;
$$;

create function public.practice_video_submit(p_submission uuid)
returns void language plpgsql security definer set search_path = '' as $$
declare v_submission public.practice_video_submissions%rowtype;
begin
  select * into v_submission from public.practice_video_submissions
    where id = p_submission for update;
  if not found or v_submission.status <> 'draft'
      or v_submission.created_by <> auth.uid()
      or not public.practice_video_student_access(
        v_submission.teacher_id, v_submission.student_id)
      or not exists (select 1 from storage.objects
        where bucket_id = 'practice-videos'
          and name = v_submission.storage_path) then
    raise exception 'Practice video cannot be submitted' using errcode = '42501';
  end if;
  update public.practice_video_submissions
    set status = 'submitted', submitted_at = now() where id = p_submission;
end;
$$;

create function public.practice_video_cancel_draft(p_submission uuid)
returns void language plpgsql security definer set search_path = '' as $$
declare v_submission public.practice_video_submissions%rowtype;
begin
  select * into v_submission from public.practice_video_submissions
    where id = p_submission for update;
  if not found or v_submission.status <> 'draft'
      or v_submission.created_by <> auth.uid()
      or exists (select 1 from storage.objects
        where bucket_id = 'practice-videos'
          and name = v_submission.storage_path) then
    raise exception 'Draft cannot be cancelled' using errcode = '42501';
  end if;
  delete from public.practice_video_submissions where id = p_submission;
end;
$$;

create function public.practice_video_complete_review(p_submission uuid, p_feedback text)
returns uuid language plpgsql security definer set search_path = '' as $$
declare
  v_submission public.practice_video_submissions%rowtype;
  v_settings public.practice_video_settings%rowtype;
  v_review uuid;
  v_completed timestamptz := now();
begin
  select * into v_submission from public.practice_video_submissions
    where id = p_submission for update;
  if not found or v_submission.status <> 'submitted'
      or not public.practice_video_teacher_access(
        v_submission.teacher_id, v_submission.student_id)
      or char_length(trim(coalesce(p_feedback, ''))) not between 1 and 10000 then
    raise exception 'Review cannot be completed' using errcode = '42501';
  end if;
  select * into v_settings from public.practice_video_settings
    where teacher_id = v_submission.teacher_id;
  if not found then
    raise exception 'Review price is unavailable' using errcode = '22023';
  end if;
  insert into public.practice_video_reviews
    (submission_id, teacher_id, feedback, completed_at)
    values (p_submission, v_submission.teacher_id, trim(p_feedback), v_completed)
    returning id into v_review;
  insert into public.practice_video_charges
    (review_id, teacher_id, student_id, amount_cents, currency, completed_at)
    values (v_review, v_submission.teacher_id, v_submission.student_id,
      v_settings.price_cents, v_settings.currency, v_completed);
  update public.practice_video_submissions set status = 'reviewed'
    where id = p_submission;
  return v_review;
end;
$$;

create function public.practice_video_set_paid(p_charge uuid, p_paid boolean)
returns void language plpgsql security definer set search_path = '' as $$
begin
  update public.practice_video_charges
    set payment_status = case when p_paid then 'paid' else 'unpaid' end,
      paid_at = case when p_paid then now() else null end
    where id = p_charge and exists (
      select 1 from public.teachers t
      where t.id = practice_video_charges.teacher_id and t.user_id = auth.uid());
  if not found then
    raise exception 'Practice video charge not found' using errcode = '42501';
  end if;
end;
$$;

create function public.practice_video_billing_summary(p_from date, p_through date)
returns jsonb language sql stable security definer set search_path = '' as $$
  select coalesce(jsonb_agg(to_jsonb(x) order by x.review_date, x.student_id),
    '[]'::jsonb) from (
    select c.student_id, s.name as student_name,
      c.completed_at::date as review_date, c.currency,
      count(*)::integer as review_count,
      sum(c.amount_cents)::bigint as total_cents,
      sum(c.amount_cents) filter (where c.payment_status = 'unpaid')::bigint
        as unpaid_cents
    from public.practice_video_charges c
    join public.students s on s.id = c.student_id
    join public.teachers t on t.id = c.teacher_id
    where t.user_id = auth.uid() and c.completed_at::date between p_from and p_through
    group by c.student_id, s.name, c.completed_at::date, c.currency
  ) x;
$$;

revoke all on function public.practice_video_teacher_access(uuid,uuid),
  public.practice_video_student_access(uuid,uuid),
  public.practice_video_start_submission(uuid,uuid,text,bigint,text),
  public.practice_video_submit(uuid), public.practice_video_cancel_draft(uuid),
  public.practice_video_complete_review(uuid,text),
  public.practice_video_set_paid(uuid,boolean),
  public.practice_video_billing_summary(date,date) from public;
grant execute on function public.practice_video_teacher_access(uuid,uuid),
  public.practice_video_student_access(uuid,uuid),
  public.practice_video_start_submission(uuid,uuid,text,bigint,text),
  public.practice_video_submit(uuid), public.practice_video_cancel_draft(uuid),
  public.practice_video_complete_review(uuid,text),
  public.practice_video_set_paid(uuid,boolean),
  public.practice_video_billing_summary(date,date) to authenticated;

insert into storage.buckets(id, name, public, file_size_limit, allowed_mime_types)
values ('practice-videos', 'practice-videos', false, 104857600,
  array['video/mp4', 'video/quicktime', 'video/webm']::text[])
on conflict (id) do nothing;

create function public.practice_video_storage_allowed(p_path text, p_write boolean)
returns boolean language sql stable security definer set search_path = '' as $$
  select exists (
    select 1 from public.practice_video_submissions s
    where s.storage_path = p_path
      and (case when p_write then
        s.status = 'draft' and s.created_by = auth.uid()
          and public.practice_video_student_access(s.teacher_id, s.student_id)
      else
        public.practice_video_teacher_access(s.teacher_id, s.student_id)
          or (s.created_by = auth.uid() and
            public.practice_video_student_access(s.teacher_id, s.student_id))
      end)
  );
$$;
revoke all on function public.practice_video_storage_allowed(text,boolean) from public;
grant execute on function public.practice_video_storage_allowed(text,boolean)
  to authenticated;

create policy practice_video_storage_read on storage.objects
  for select to authenticated using (bucket_id = 'practice-videos'
    and public.practice_video_storage_allowed(name, false));
create policy practice_video_storage_insert on storage.objects
  for insert to authenticated with check (bucket_id = 'practice-videos'
    and public.practice_video_storage_allowed(name, true));
create policy practice_video_storage_delete_draft on storage.objects
  for delete to authenticated using (bucket_id = 'practice-videos'
    and owner_id = auth.uid()::text
    and public.practice_video_storage_allowed(name, true));
