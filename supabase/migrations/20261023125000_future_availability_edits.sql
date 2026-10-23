-- Split weekly rules at a selected week so edits preserve earlier dates.
create function public.maestro_change_availability_rule(
  p_rule_id uuid,
  p_from_date date,
  p_start_minute integer default null,
  p_end_minute integer default null,
  p_kind text default null,
  p_delete boolean default false
)
returns void language plpgsql security definer set search_path = '' as $$
declare
  v_teacher uuid := public.maestro_current_teacher_id();
  v_rule public.teacher_availability_rules%rowtype;
begin
  if v_teacher is null then
    raise exception 'Teacher authentication required' using errcode = '42501';
  end if;
  select * into v_rule from public.teacher_availability_rules
    where id = p_rule_id and teacher_id = v_teacher for update;
  if v_rule.id is null then
    raise exception 'Availability rule not found' using errcode = '42501';
  end if;
  if p_from_date is null or extract(isodow from p_from_date) <> v_rule.weekday
      or p_from_date < v_rule.effective_from
      or (v_rule.effective_until is not null
          and p_from_date > v_rule.effective_until) then
    raise exception 'Selected date is outside this weekly rule'
      using errcode = '22023';
  end if;
  if not p_delete and (p_start_minute is null or p_end_minute is null
      or p_start_minute < 0 or p_end_minute > 1440
      or p_start_minute >= p_end_minute
      or p_kind is null or p_kind not in ('available', 'unavailable')) then
    raise exception 'Invalid availability period' using errcode = '22023';
  end if;
  if p_from_date = v_rule.effective_from then
    if p_delete then
      delete from public.teacher_availability_rules where id = p_rule_id;
    else
      update public.teacher_availability_rules
        set start_minute = p_start_minute, end_minute = p_end_minute,
          kind = p_kind where id = p_rule_id;
    end if;
  else
    update public.teacher_availability_rules
      set effective_until = p_from_date - 1 where id = p_rule_id;
    if not p_delete then
      insert into public.teacher_availability_rules
        (teacher_id, weekday, start_minute, end_minute, kind,
         effective_from, effective_until)
      values (v_teacher, v_rule.weekday, p_start_minute, p_end_minute,
        p_kind, p_from_date, v_rule.effective_until);
    end if;
  end if;
end;
$$;
revoke all on function public.maestro_change_availability_rule(
  uuid,date,integer,integer,text,boolean) from public;
grant execute on function public.maestro_change_availability_rule(
  uuid,date,integer,integer,text,boolean) to authenticated;
