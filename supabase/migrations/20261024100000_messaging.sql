-- Private teacher/student messaging. Portal grants, not legacy students.user_id,
-- are the authority for both participants. No existing records are changed.
create table public.conversations (
  id uuid primary key default gen_random_uuid(),
  teacher_id uuid not null references public.teachers(id),
  student_id uuid not null references public.students(id),
  created_at timestamptz not null default now(),
  last_message_at timestamptz not null default now(),
  unique (teacher_id, student_id),
  foreign key (teacher_id, student_id)
    references public.teacher_students(teacher_id, student_id)
);
create index conversations_student_recent on public.conversations
  (student_id, last_message_at desc);
create index conversations_teacher_recent on public.conversations
  (teacher_id, last_message_at desc);

create table public.conversation_reads (
  conversation_id uuid not null references public.conversations(id) on delete cascade,
  user_id uuid not null references auth.users(id) on delete cascade,
  last_read_at timestamptz,
  primary key (conversation_id, user_id)
);
create index conversation_reads_user on public.conversation_reads(user_id, conversation_id);

create table public.messages (
  id uuid primary key default gen_random_uuid(),
  conversation_id uuid not null references public.conversations(id) on delete cascade,
  sender_id uuid not null references auth.users(id),
  client_id uuid not null,
  kind text not null default 'text' check (kind in ('text', 'audio', 'file', 'lesson', 'piece')),
  body text not null default '' check (char_length(body) <= 4000),
  reference_id uuid,
  created_at timestamptz not null default clock_timestamp(),
  unique (conversation_id, sender_id, client_id),
  unique (conversation_id, id),
  check ((kind = 'text' and length(trim(body)) > 0 and reference_id is null)
    or (kind in ('audio', 'file') and reference_id is null)
    or (kind in ('lesson', 'piece') and reference_id is not null))
);
create index messages_page on public.messages(conversation_id, created_at desc, id desc);
create index messages_unread on public.messages(conversation_id, sender_id, created_at desc);
create index messages_sender_rate on public.messages(sender_id, created_at desc);

create table public.message_notification_preferences (
  user_id uuid primary key references auth.users(id) on delete cascade,
  enabled boolean not null default true,
  updated_at timestamptz not null default now()
);
create table public.message_notification_outbox (
  message_id uuid primary key references public.messages(id) on delete cascade,
  recipient_user_id uuid not null references auth.users(id) on delete cascade,
  created_at timestamptz not null default now(),
  processed_at timestamptz
);
create index message_notification_pending on public.message_notification_outbox
  (created_at) where processed_at is null;

create table public.message_attachments (
  id uuid primary key default gen_random_uuid(),
  conversation_id uuid not null,
  message_id uuid not null,
  storage_path text not null unique,
  file_name text not null check (char_length(file_name) between 1 and 180),
  mime_type text not null,
  size_bytes bigint not null check (size_bytes between 1 and 20971520),
  duration_ms integer check (duration_ms is null or duration_ms between 1 and 300000),
  created_at timestamptz not null default now(),
  foreign key (conversation_id, message_id)
    references public.messages(conversation_id, id) on delete cascade
);
create unique index message_attachments_one_file on public.message_attachments(message_id);

-- SECURITY DEFINER helpers query only base relationship tables, avoiding RLS
-- recursion and enforcing revocation on every request and Realtime read.
create function public.maestro_can_message(p_conversation_id uuid)
returns boolean language sql stable security definer set search_path = '' as $$
  select exists (
    select 1 from public.conversations c
    join public.teacher_students ts on ts.teacher_id = c.teacher_id
      and ts.student_id = c.student_id and ts.active
    join public.teachers t on t.id = c.teacher_id and t.status = 'ACTIVE'
    join public.student_portal_access a on a.teacher_id = c.teacher_id
      and a.student_id = c.student_id and a.enabled and a.user_id is not null
    where c.id = p_conversation_id and auth.uid() in (t.user_id, a.user_id)
  );
$$;

create function public.maestro_is_current_message_user(p_conversation_id uuid, p_user_id uuid)
returns boolean language sql stable security definer set search_path = '' as $$
  select public.maestro_can_message(p_conversation_id) and exists (
    select 1 from public.conversations c
    join public.teachers t on t.id = c.teacher_id
    join public.student_portal_access a on a.teacher_id = c.teacher_id
      and a.student_id = c.student_id
    where c.id = p_conversation_id and p_user_id in (t.user_id, a.user_id));
$$;

create function public.maestro_open_conversation(p_teacher_id uuid, p_student_id uuid)
returns uuid language plpgsql security definer set search_path = '' as $$
declare v_id uuid;
begin
  if auth.uid() is null or not exists (
    select 1 from public.teacher_students ts
    join public.teachers t on t.id = ts.teacher_id and t.status = 'ACTIVE'
    join public.student_portal_access a on a.teacher_id = ts.teacher_id
      and a.student_id = ts.student_id and a.enabled and a.user_id is not null
    where ts.teacher_id = p_teacher_id and ts.student_id = p_student_id
      and ts.active and auth.uid() in (t.user_id, a.user_id)
  ) then
    raise exception 'Messaging access denied' using errcode = '42501';
  end if;
  insert into public.conversations(teacher_id, student_id)
    values (p_teacher_id, p_student_id)
    on conflict (teacher_id, student_id) do update
      set teacher_id = excluded.teacher_id returning id into v_id;
  return v_id;
end;
$$;

create function public.maestro_message_candidates()
returns setof jsonb language sql stable security definer set search_path = '' as $$
  select jsonb_build_object('teacherId', t.id, 'studentId', s.id,
    'name', case when t.user_id = auth.uid() then s.name else t.name end,
    'instrument', case when t.user_id = auth.uid() then s.instrument
      else t.main_instrument end, 'conversationId', c.id)
  from public.teacher_students ts
  join public.teachers t on t.id = ts.teacher_id and t.status = 'ACTIVE'
  join public.students s on s.id = ts.student_id
  join public.student_portal_access a on a.teacher_id = ts.teacher_id
    and a.student_id = ts.student_id and a.enabled and a.user_id is not null
  left join public.conversations c on c.teacher_id = ts.teacher_id
    and c.student_id = ts.student_id
  where ts.active and auth.uid() in (t.user_id, a.user_id)
  order by s.name, t.name;
$$;

create function public.maestro_conversation_summaries()
returns setof jsonb language sql stable security definer set search_path = '' as $$
  select jsonb_build_object('id', c.id, 'teacherId', c.teacher_id,
    'studentId', c.student_id,
    'name', case when t.user_id = auth.uid() then s.name else t.name end,
    'instrument', case when t.user_id = auth.uid() then s.instrument
      else t.main_instrument end,
    'lastMessage', case when m.kind in ('audio','file') then '[Attachment]'
      when m.kind in ('lesson','piece') then '[' || initcap(m.kind) || '] ' || m.body
      else m.body end,
    'lastMessageAt', m.created_at,
    'unreadCount', (select count(*) from public.messages u
      where u.conversation_id = c.id and u.sender_id <> auth.uid()
        and (r.last_read_at is null or u.created_at > r.last_read_at)))
  from public.conversations c
  join public.teacher_students ts on ts.teacher_id = c.teacher_id
    and ts.student_id = c.student_id and ts.active
  join public.teachers t on t.id = c.teacher_id and t.status = 'ACTIVE'
  join public.students s on s.id = c.student_id
  join public.student_portal_access a on a.teacher_id = c.teacher_id
    and a.student_id = c.student_id and a.enabled and a.user_id is not null
  left join public.conversation_reads r on r.conversation_id = c.id
    and r.user_id = auth.uid()
  left join lateral (select kind, body, created_at from public.messages
    where conversation_id = c.id order by created_at desc, id desc limit 1) m on true
  where auth.uid() in (t.user_id, a.user_id)
  order by c.last_message_at desc, c.id desc
  limit 500;
$$;

create function public.maestro_shareable_references(p_conversation_id uuid, p_kind text)
returns setof jsonb language plpgsql stable security definer set search_path = '' as $$
declare v_teacher uuid; v_student uuid; v_teacher_user uuid; v_access public.student_portal_access%rowtype;
begin
  if not public.maestro_can_message(p_conversation_id) then
    raise exception 'Messaging access denied' using errcode = '42501';
  end if;
  select teacher_id, student_id into v_teacher, v_student from public.conversations
    where id = p_conversation_id;
  select user_id into v_teacher_user from public.teachers where id = v_teacher;
  select * into v_access from public.student_portal_access
    where teacher_id = v_teacher and student_id = v_student;
  if p_kind = 'lesson' and (auth.uid() = v_teacher_user or v_access.view_courses) then
    return query select jsonb_build_object('id', l.id, 'title', l.title,
      'detail', l.lesson_date::text) from public.lessons l
      where l.teacher_id = v_teacher and l.student_id = v_student
      order by l.lesson_date desc nulls last limit 100;
  elsif p_kind = 'piece' and (auth.uid() = v_teacher_user or v_access.view_pieces) then
    return query select jsonb_build_object('id', p.id, 'title', p.title,
      'detail', '') from public.pieces p
      where p.student_id = v_student
        and exists (select 1 from public.lessons l where l.project_id = p.project_id
          and l.teacher_id = v_teacher)
      order by p.created_at desc limit 100;
  end if;
end;
$$;

create function public.maestro_send_message(p_conversation_id uuid,
  p_client_id uuid, p_kind text, p_body text, p_reference_id uuid default null)
returns public.messages language plpgsql security definer set search_path = '' as $$
declare v_row public.messages%rowtype; v_title text; v_teacher uuid; v_student uuid;
  v_recipient uuid; v_new boolean := false;
begin
  if not public.maestro_can_message(p_conversation_id) then
    raise exception 'Messaging access denied' using errcode = '42501';
  end if;
  if p_client_id is null or p_kind not in ('text','audio','file','lesson','piece')
      or char_length(coalesce(p_body,'')) > 4000 then
    raise exception 'Invalid message' using errcode = '22023';
  end if;
  -- A retry with the same client identifier returns the original row.
  select * into v_row from public.messages where conversation_id = p_conversation_id
    and sender_id = auth.uid() and client_id = p_client_id;
  if found then return v_row; end if;
  if (select count(*) from public.messages where sender_id = auth.uid()
      and created_at > now() - interval '1 minute') >= 30 then
    raise exception 'Message rate limit reached' using errcode = '22023';
  end if;
  select teacher_id, student_id into v_teacher, v_student
    from public.conversations where id = p_conversation_id;
  if p_kind = 'lesson' then
    select l.title into v_title from public.lessons l
      join public.student_portal_access a on a.teacher_id = l.teacher_id
        and a.student_id = l.student_id
      where l.id = p_reference_id and l.teacher_id = v_teacher
        and l.student_id = v_student
        and (auth.uid() = (select user_id from public.teachers where id = v_teacher)
          or a.view_courses);
  elsif p_kind = 'piece' then
    select p.title into v_title from public.pieces p
      join public.student_portal_access a on a.teacher_id = v_teacher
        and a.student_id = p.student_id
      where p.id = p_reference_id and p.student_id = v_student
        and exists (select 1 from public.lessons l where l.project_id = p.project_id
          and l.teacher_id = v_teacher)
        and (auth.uid() = (select user_id from public.teachers where id = v_teacher)
          or a.view_pieces);
  end if;
  if p_kind in ('lesson','piece') and v_title is null then
    raise exception 'Reference unavailable' using errcode = '42501';
  end if;
  insert into public.messages(conversation_id, sender_id, client_id, kind, body, reference_id)
    values (p_conversation_id, auth.uid(), p_client_id, p_kind,
      case when p_kind in ('lesson','piece') then v_title else coalesce(p_body,'') end,
      p_reference_id)
    on conflict (conversation_id, sender_id, client_id) do nothing returning * into v_row;
  v_new := v_row.id is not null;
  if v_row.id is null then
    select * into v_row from public.messages where conversation_id = p_conversation_id
      and sender_id = auth.uid() and client_id = p_client_id;
  end if;
  update public.conversations set last_message_at = greatest(last_message_at, v_row.created_at)
    where id = p_conversation_id;
  if v_new then
    select case when t.user_id = auth.uid() then a.user_id else t.user_id end
      into v_recipient from public.teachers t
      join public.student_portal_access a on a.teacher_id = t.id
        and a.student_id = v_student where t.id = v_teacher;
    if v_recipient is not null and v_recipient <> auth.uid()
      and coalesce((select enabled from public.message_notification_preferences
        where user_id = v_recipient), true) then
      insert into public.message_notification_outbox(message_id, recipient_user_id)
        values (v_row.id, v_recipient) on conflict do nothing;
    end if;
  end if;
  return v_row;
end;
$$;

create function public.maestro_mark_read(p_conversation_id uuid, p_message_id uuid)
returns void language plpgsql security definer set search_path = '' as $$
declare v_time timestamptz;
begin
  if not public.maestro_can_message(p_conversation_id) then
    raise exception 'Messaging access denied' using errcode = '42501';
  end if;
  select created_at into v_time from public.messages
    where id = p_message_id and conversation_id = p_conversation_id;
  if v_time is null then raise exception 'Message unavailable' using errcode = '22023'; end if;
  insert into public.conversation_reads(conversation_id, user_id, last_read_at)
    values (p_conversation_id, auth.uid(), v_time)
    on conflict (conversation_id, user_id) do update
      set last_read_at = greatest(public.conversation_reads.last_read_at, excluded.last_read_at);
end;
$$;

create function public.maestro_attach_message(p_message_id uuid, p_path text,
  p_file_name text, p_mime_type text, p_size_bytes bigint, p_duration_ms integer default null)
returns public.message_attachments language plpgsql security definer set search_path = '' as $$
declare v_message public.messages%rowtype; v_row public.message_attachments%rowtype;
  v_size bigint;
begin
  select * into v_message from public.messages where id = p_message_id;
  if v_message.id is null or v_message.sender_id <> auth.uid()
      or v_message.kind not in ('audio','file')
      or not public.maestro_can_message(v_message.conversation_id) then
    raise exception 'Attachment access denied' using errcode = '42501';
  end if;
  if p_path !~ ('^' || v_message.conversation_id::text || '/' || v_message.id::text ||
      '/[0-9a-fA-F-]{36}[.][a-z0-9]{2,5}$')
      or char_length(p_file_name) not between 1 and 180
      or p_size_bytes not between 1 and 20971520
      or (p_duration_ms is not null and p_duration_ms not between 1 and 300000)
      or p_mime_type not in ('application/pdf','image/jpeg','image/png','image/webp',
        'audio/mpeg','audio/mp4','audio/wav','audio/x-wav','audio/aac','audio/ogg','audio/webm')
      or (v_message.kind = 'audio' and (p_mime_type not like 'audio/%' or p_duration_ms is null)) then
    raise exception 'Invalid attachment' using errcode = '22023';
  end if;
  select (metadata->>'size')::bigint into v_size from storage.objects
    where bucket_id = 'maestro-messages' and name = p_path
      and owner_id = auth.uid()::text and metadata->>'mimetype' = p_mime_type;
  if v_size is null or v_size <> p_size_bytes then
    raise exception 'Uploaded file unavailable or size mismatch' using errcode = '22023';
  end if;
  insert into public.message_attachments(conversation_id, message_id, storage_path,
    file_name, mime_type, size_bytes, duration_ms)
    values (v_message.conversation_id, v_message.id, p_path,
      p_file_name, p_mime_type, p_size_bytes, p_duration_ms) returning * into v_row;
  return v_row;
end;
$$;

alter table public.conversations enable row level security;
alter table public.conversation_reads enable row level security;
alter table public.messages enable row level security;
alter table public.message_attachments enable row level security;
alter table public.message_notification_preferences enable row level security;
alter table public.message_notification_outbox enable row level security;
create policy conversations_read on public.conversations for select to authenticated
  using (public.maestro_can_message(id));
create policy reads_member on public.conversation_reads for select to authenticated
  using (public.maestro_can_message(conversation_id)
    and public.maestro_is_current_message_user(conversation_id, user_id));
create policy messages_read on public.messages for select to authenticated
  using (public.maestro_can_message(conversation_id));
create policy attachments_read on public.message_attachments for select to authenticated
  using (public.maestro_can_message(conversation_id));
create policy message_preferences_read on public.message_notification_preferences
  for select to authenticated using (user_id = auth.uid());
create policy message_preferences_insert on public.message_notification_preferences
  for insert to authenticated with check (user_id = auth.uid());
create policy message_preferences_update on public.message_notification_preferences
  for update to authenticated using (user_id = auth.uid())
  with check (user_id = auth.uid());
revoke all on public.conversations, public.conversation_reads, public.messages,
  public.message_attachments from anon, authenticated;
grant select on public.conversations, public.conversation_reads, public.messages,
  public.message_attachments to authenticated;
revoke all on public.message_notification_preferences,
  public.message_notification_outbox from anon, authenticated;
grant select, insert, update on public.message_notification_preferences to authenticated;

insert into storage.buckets(id, name, public, file_size_limit, allowed_mime_types)
values ('maestro-messages', 'maestro-messages', false, 20971520,
  array['application/pdf','image/jpeg','image/png','image/webp','audio/mpeg',
    'audio/mp4','audio/wav','audio/x-wav','audio/aac','audio/ogg','audio/webm']::text[])
on conflict (id) do update set public = false,
  file_size_limit = excluded.file_size_limit,
  allowed_mime_types = excluded.allowed_mime_types;

create function public.maestro_message_storage_allowed(p_path text, p_write boolean)
returns boolean language sql stable security definer set search_path = '' as $$
  select exists (
    select 1 from public.messages m
    where m.conversation_id::text = split_part(p_path,'/',1)
      and m.id::text = split_part(p_path,'/',2)
      and split_part(p_path,'/',3) ~ '^[0-9a-fA-F-]{36}[.][a-z0-9]{2,5}$'
      and split_part(p_path,'/',4) = ''
      and m.kind in ('audio','file')
      and public.maestro_can_message(m.conversation_id)
      and (not p_write or m.sender_id = auth.uid())
      and (p_write or exists (select 1 from public.message_attachments a
        where a.message_id = m.id and a.storage_path = p_path))
  );
$$;
create policy maestro_messages_storage_read on storage.objects for select to authenticated
  using (bucket_id = 'maestro-messages' and
    public.maestro_message_storage_allowed(name, false));
create policy maestro_messages_storage_insert on storage.objects for insert to authenticated
  with check (bucket_id = 'maestro-messages' and
    public.maestro_message_storage_allowed(name, true));
-- No update or delete: immutable attachments keep message history auditable.

revoke all on function public.maestro_can_message(uuid),
  public.maestro_is_current_message_user(uuid,uuid),
  public.maestro_open_conversation(uuid,uuid), public.maestro_message_candidates(),
  public.maestro_conversation_summaries(),
  public.maestro_shareable_references(uuid,text),
  public.maestro_send_message(uuid,uuid,text,text,uuid),
  public.maestro_mark_read(uuid,uuid),
  public.maestro_attach_message(uuid,text,text,text,bigint,integer),
  public.maestro_message_storage_allowed(text,boolean) from public;
grant execute on function public.maestro_can_message(uuid),
  public.maestro_is_current_message_user(uuid,uuid),
  public.maestro_open_conversation(uuid,uuid), public.maestro_message_candidates(),
  public.maestro_conversation_summaries(),
  public.maestro_shareable_references(uuid,text),
  public.maestro_send_message(uuid,uuid,text,text,uuid),
  public.maestro_mark_read(uuid,uuid),
  public.maestro_attach_message(uuid,text,text,text,bigint,integer),
  public.maestro_message_storage_allowed(text,boolean) to authenticated;

alter publication supabase_realtime add table public.messages, public.conversation_reads,
  public.message_attachments;
