-- Extend conversations while retaining the existing private teacher/student row.
alter table public.conversations
  add column kind text not null default 'teacher_student'
    check (kind in ('teacher_student', 'teacher_parent', 'group')),
  add column participant_key text not null default '';
alter table public.conversations drop constraint conversations_teacher_id_student_id_key;
create unique index conversations_student_private on public.conversations(teacher_id, student_id)
  where kind = 'teacher_student';
create unique index conversations_parent_context on public.conversations
  (teacher_id, student_id, kind, participant_key)
  where kind <> 'teacher_student';

create table public.conversation_parents (
  conversation_id uuid not null references public.conversations(id) on delete cascade,
  parent_user_id uuid not null references public.profiles(id),
  primary key (conversation_id, parent_user_id)
);
create index conversation_parents_user on public.conversation_parents(parent_user_id);
alter table public.conversation_parents enable row level security;
create policy conversation_parents_member_read on public.conversation_parents
  for select to authenticated using (public.maestro_can_message(conversation_id));
revoke all on public.conversation_parents from anon, authenticated;
grant select on public.conversation_parents to authenticated;

create or replace function public.maestro_can_message(p_conversation_id uuid)
returns boolean language sql stable security definer set search_path = '' as $$
  select exists (
    select 1 from public.conversations c
    join public.teacher_students ts on ts.teacher_id = c.teacher_id
      and ts.student_id = c.student_id and ts.active
    join public.teachers t on t.id = c.teacher_id and t.status = 'ACTIVE'
    left join public.student_portal_access a on a.teacher_id = c.teacher_id
      and a.student_id = c.student_id and a.enabled and a.user_id is not null
    where c.id = p_conversation_id and (
      (c.kind = 'teacher_student' and auth.uid() in (t.user_id, a.user_id))
      or (c.kind = 'teacher_parent' and (auth.uid() = t.user_id or exists (
        select 1 from public.conversation_parents cp
        join public.parent_access pa on pa.teacher_id = c.teacher_id
          and pa.student_id = c.student_id and pa.parent_user_id = cp.parent_user_id
          and pa.active
        where cp.conversation_id = c.id and cp.parent_user_id = auth.uid())))
      or (c.kind = 'group' and (auth.uid() = t.user_id
        or auth.uid() = a.user_id
        or exists (select 1 from public.conversation_parents cp
          join public.parent_access pa on pa.teacher_id = c.teacher_id
            and pa.student_id = c.student_id and pa.parent_user_id = cp.parent_user_id
            and pa.active
          where cp.conversation_id = c.id and cp.parent_user_id = auth.uid())))));
$$;

create or replace function public.maestro_is_current_message_user(
  p_conversation_id uuid, p_user_id uuid)
returns boolean language sql stable security definer set search_path = '' as $$
  select public.maestro_can_message(p_conversation_id) and exists (
    select 1 from public.conversations c join public.teachers t on t.id = c.teacher_id
    left join public.student_portal_access a on a.teacher_id = c.teacher_id
      and a.student_id = c.student_id and a.enabled
    where c.id = p_conversation_id and
      (p_user_id = t.user_id or
        (c.kind in ('teacher_student','group') and p_user_id = a.user_id) or
        (c.kind in ('teacher_parent','group') and exists (
          select 1 from public.conversation_parents cp
          join public.parent_access pa on pa.teacher_id = c.teacher_id
            and pa.student_id = c.student_id and pa.parent_user_id = cp.parent_user_id
            and pa.active
          where cp.conversation_id = c.id and cp.parent_user_id = p_user_id))));
$$;

create or replace function public.maestro_open_conversation(p_teacher_id uuid, p_student_id uuid)
returns uuid language plpgsql security definer set search_path = '' as $$
declare v_id uuid;
begin
  if auth.uid() is null or not exists (
    select 1 from public.teacher_students ts
    join public.teachers t on t.id = ts.teacher_id and t.status = 'ACTIVE'
    join public.student_portal_access a on a.teacher_id = ts.teacher_id
      and a.student_id = ts.student_id and a.enabled and a.user_id is not null
    where ts.teacher_id = p_teacher_id and ts.student_id = p_student_id
      and ts.active and auth.uid() in (t.user_id, a.user_id)) then
    raise exception 'Messaging access denied' using errcode = '42501';
  end if;
  insert into public.conversations(teacher_id, student_id)
    values (p_teacher_id, p_student_id)
    on conflict (teacher_id, student_id) where kind = 'teacher_student'
    do update set teacher_id = excluded.teacher_id returning id into v_id;
  return v_id;
end;
$$;

create or replace function public.maestro_message_candidates()
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
    and c.student_id = ts.student_id and c.kind = 'teacher_student'
  where ts.active and auth.uid() in (t.user_id, a.user_id)
  order by s.name, t.name;
$$;

create function public.maestro_open_parent_conversation(
  p_student_app_id bigint, p_parent_user_ids uuid[], p_group boolean)
returns uuid language plpgsql security definer set search_path = '' as $$
declare
  v_teacher uuid := public.maestro_current_teacher_id();
  v_student uuid;
  v_parents uuid[];
  v_key text;
  v_id uuid;
begin
  select id into v_student from public.students where app_id = p_student_app_id;
  if v_teacher is null or v_student is null or not public.is_teacher_for(v_student) then
    raise exception 'Student access denied' using errcode = '42501';
  end if;
  select array_agg(id order by id) into v_parents
    from (select distinct unnest(p_parent_user_ids) as id) x;
  if p_group is null or v_parents is null or cardinality(v_parents) = 0 or
      (not p_group and cardinality(v_parents) <> 1) or
      (select count(*) from public.parent_access a
        where a.teacher_id = v_teacher and a.student_id = v_student
          and a.parent_user_id = any(v_parents) and a.active)
        <> cardinality(v_parents) or
      (p_group and not exists (select 1 from public.student_portal_access a
        where a.teacher_id = v_teacher and a.student_id = v_student
          and a.enabled and a.user_id is not null)) then
    raise exception 'Participants are not authorized' using errcode = '42501';
  end if;
  v_key := array_to_string(v_parents, ',');
  insert into public.conversations(teacher_id, student_id, kind, participant_key)
    values (v_teacher, v_student,
      case when p_group then 'group' else 'teacher_parent' end, v_key)
    on conflict (teacher_id, student_id, kind, participant_key)
      where kind <> 'teacher_student'
    do update set teacher_id = excluded.teacher_id returning id into v_id;
  insert into public.conversation_parents(conversation_id, parent_user_id)
    select v_id, unnest(v_parents) on conflict do nothing;
  return v_id;
end;
$$;

create or replace function public.maestro_conversation_summaries()
returns setof jsonb language sql stable security definer set search_path = '' as $$
  select jsonb_build_object('id', c.id, 'teacherId', c.teacher_id,
    'studentId', c.student_id, 'kind', c.kind,
    'name', case when c.kind = 'teacher_student' then
      case when t.user_id = auth.uid() then s.name else t.name end
      when c.kind = 'teacher_parent' then
        case when t.user_id = auth.uid() then
          coalesce((select string_agg(p.display_name, ', ') from public.conversation_parents cp
            join public.profiles p on p.id = cp.parent_user_id
            where cp.conversation_id = c.id), 'Parent') || ' · ' || s.name
        else t.name || ' · ' || s.name end
      else t.name || ' · ' || s.name || ' · Group' end,
    'instrument', case when c.kind = 'teacher_student' and t.user_id = auth.uid()
      then s.instrument when c.kind = 'teacher_student' then t.main_instrument
      else c.kind end,
    'lastMessage', case when m.kind in ('audio','file') then '[Attachment]'
      when m.kind in ('lesson','piece') then '[' || initcap(m.kind) || '] ' || m.body
      else m.body end,
    'lastMessageAt', m.created_at,
    'unreadCount', (select count(*) from public.messages u
      where u.conversation_id = c.id and u.sender_id <> auth.uid()
        and (r.last_read_at is null or u.created_at > r.last_read_at)))
  from public.conversations c
  join public.teachers t on t.id = c.teacher_id
  join public.students s on s.id = c.student_id
  left join public.conversation_reads r on r.conversation_id = c.id
    and r.user_id = auth.uid()
  left join lateral (select kind, body, created_at from public.messages
    where conversation_id = c.id order by created_at desc, id desc limit 1) m on true
  where public.maestro_can_message(c.id)
  order by c.last_message_at desc, c.id desc limit 500;
$$;

create function public.maestro_conversation_participants(p_conversation_id uuid)
returns setof jsonb language plpgsql stable security definer set search_path = '' as $$
declare v_conversation public.conversations%rowtype;
begin
  if not public.maestro_can_message(p_conversation_id) then
    raise exception 'Messaging access denied' using errcode = '42501';
  end if;
  select * into v_conversation from public.conversations where id = p_conversation_id;
  return query select jsonb_build_object('id', t.user_id, 'name', t.name,
    'role', 'Teacher') from public.teachers t where t.id = v_conversation.teacher_id;
  if v_conversation.kind in ('teacher_student', 'group') then
    return query select jsonb_build_object('id', a.user_id, 'name', s.name,
      'role', 'Student') from public.student_portal_access a
      join public.students s on s.id = a.student_id
      where a.teacher_id = v_conversation.teacher_id
        and a.student_id = v_conversation.student_id
        and a.enabled and a.user_id is not null;
  end if;
  if v_conversation.kind in ('teacher_parent', 'group') then
    return query select jsonb_build_object('id', cp.parent_user_id,
      'name', p.display_name, 'role', 'Parent')
      from public.conversation_parents cp
      join public.profiles p on p.id = cp.parent_user_id
      where cp.conversation_id = p_conversation_id;
  end if;
end;
$$;

-- An outbox entry now belongs to a message/recipient pair. Existing pending
-- entries retain their recipient and processing state.
alter table public.message_notification_outbox
  drop constraint message_notification_outbox_pkey;
alter table public.message_notification_outbox
  add primary key (message_id, recipient_user_id);

create function public.maestro_message_notify_participants()
returns trigger language plpgsql security definer set search_path = '' as $$
begin
  insert into public.message_notification_outbox(message_id, recipient_user_id)
  select new.id, recipients.user_id from (
    select t.user_id from public.conversations c
      join public.teachers t on t.id = c.teacher_id and t.status = 'ACTIVE'
      where c.id = new.conversation_id
    union
    select a.user_id from public.conversations c
      join public.student_portal_access a on a.teacher_id = c.teacher_id
        and a.student_id = c.student_id and a.enabled
      where c.id = new.conversation_id and c.kind in ('teacher_student','group')
        and a.user_id is not null
    union
    select cp.parent_user_id from public.conversations c
      join public.conversation_parents cp on cp.conversation_id = c.id
      join public.parent_access pa on pa.teacher_id = c.teacher_id
        and pa.student_id = c.student_id and pa.parent_user_id = cp.parent_user_id
        and pa.active
      where c.id = new.conversation_id and c.kind in ('teacher_parent','group')
  ) recipients
  where recipients.user_id <> new.sender_id and coalesce(
    (select enabled from public.message_notification_preferences p
      where p.user_id = recipients.user_id), true)
  on conflict do nothing;
  return new;
end;
$$;
create trigger maestro_notify_message_participants
after insert on public.messages for each row
execute function public.maestro_message_notify_participants();

-- Preserve sending, rate limits, idempotent retries, and reference validation.
-- Recipient fan-out is handled by the trigger above.
create or replace function public.maestro_send_message(p_conversation_id uuid,
  p_client_id uuid, p_kind text, p_body text, p_reference_id uuid default null)
returns public.messages language plpgsql security definer set search_path = '' as $$
declare v_row public.messages%rowtype; v_title text; v_teacher uuid; v_student uuid;
begin
  if not public.maestro_can_message(p_conversation_id) then
    raise exception 'Messaging access denied' using errcode = '42501';
  end if;
  if p_client_id is null or p_kind not in ('text','audio','file','lesson','piece')
      or char_length(coalesce(p_body,'')) > 4000 then
    raise exception 'Invalid message' using errcode = '22023';
  end if;
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
  if v_row.id is null then
    select * into v_row from public.messages where conversation_id = p_conversation_id
      and sender_id = auth.uid() and client_id = p_client_id;
  end if;
  update public.conversations set last_message_at = greatest(last_message_at, v_row.created_at)
    where id = p_conversation_id;
  return v_row;
end;
$$;

revoke all on function public.maestro_open_parent_conversation(bigint,uuid[],boolean),
  public.maestro_conversation_participants(uuid) from public;
grant execute on function public.maestro_open_parent_conversation(bigint,uuid[],boolean),
  public.maestro_conversation_participants(uuid) to authenticated;
