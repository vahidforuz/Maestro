-- New teacher accounts must be linked to a verified Supabase Auth identity.
-- Existing SQLite teacher records need a separate, reviewed invitation/linking
-- process; this function never claims an existing teacher by numeric ID/email.

create function public.create_profile_for_auth_user()
returns trigger language plpgsql security definer set search_path = ''
as $$
begin
  insert into public.profiles (id, display_name)
  values (new.id, coalesce(new.raw_user_meta_data ->> 'display_name', ''))
  on conflict (id) do nothing;
  return new;
end;
$$;

create trigger maestro_auth_user_created
after insert on auth.users
for each row execute function public.create_profile_for_auth_user();

create function public.register_teacher(
  p_first_name text,
  p_last_name text,
  p_telephone text default null
)
returns jsonb language plpgsql security definer set search_path = ''
as $$
declare
  v_user_id uuid := auth.uid();
  v_email text;
  v_teacher public.teachers%rowtype;
  v_name text;
begin
  if v_user_id is null then
    raise exception 'Authentication required' using errcode = '28000';
  end if;
  v_name := trim(coalesce(p_first_name, '') || ' ' || coalesce(p_last_name, ''));
  if v_name = '' then
    raise exception 'Teacher name is required' using errcode = '22023';
  end if;
  if exists (select 1 from public.teachers where user_id = v_user_id) then
    raise exception 'Teacher profile already exists' using errcode = '23505';
  end if;
  select email into v_email from auth.users where id = v_user_id;
  insert into public.profiles (id, display_name, role)
  values (v_user_id, v_name, 'teacher')
  on conflict (id) do update set display_name = excluded.display_name,
    role = 'teacher', updated_at = now();
  insert into public.teachers (user_id, name, first_name, last_name, telephone, email)
  values (v_user_id, v_name, trim(coalesce(p_first_name, '')),
          trim(coalesce(p_last_name, '')), p_telephone, v_email)
  returning * into v_teacher;
  return jsonb_build_object(
    'id', v_teacher.app_id,
    'name', v_teacher.name,
    'firstName', v_teacher.first_name,
    'lastName', v_teacher.last_name,
    'telephone', v_teacher.telephone,
    'email', v_teacher.email,
    'address', v_teacher.address,
    'status', v_teacher.status,
    'studioName', v_teacher.studio_name,
    'city', v_teacher.city,
    'postalCode', v_teacher.postal_code,
    'mainInstrument', v_teacher.main_instrument,
    'otherInstruments', v_teacher.other_instruments,
    'defaultLessonDuration', v_teacher.default_lesson_duration,
    'defaultLessonPrice', v_teacher.default_lesson_price,
    'currency', v_teacher.currency,
    'profileImagePath', v_teacher.profile_image_path
  );
end;
$$;

revoke all on function public.register_teacher(text,text,text) from public;
grant execute on function public.register_teacher(text,text,text) to authenticated;
