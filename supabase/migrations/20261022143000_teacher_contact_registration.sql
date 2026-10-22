-- Keep the teacher creation form's separate contact email. The Auth email
-- remains the login identity; this is contact metadata only.
create function public.register_teacher_with_contact(
  p_first_name text, p_last_name text, p_telephone text,
  p_contact_email text
)
returns jsonb language plpgsql security definer set search_path = ''
as $$
declare
  v_teacher jsonb;
  v_contact text := nullif(trim(coalesce(p_contact_email, '')), '');
begin
  v_teacher := public.register_teacher(p_first_name, p_last_name, p_telephone);
  if v_contact is not null then
    update public.teachers set email = v_contact, updated_at = now()
      where user_id = auth.uid();
    v_teacher := jsonb_set(v_teacher, '{email}', to_jsonb(v_contact));
  end if;
  return v_teacher;
end;
$$;

revoke all on function public.register_teacher_with_contact(text,text,text,text) from public;
grant execute on function public.register_teacher_with_contact(text,text,text,text) to authenticated;
