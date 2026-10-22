-- A signed-in student or parent must not be able to turn their profile into a
-- teacher through the public registration RPC. New Auth users start as 'user'.
create or replace function public.register_teacher(
  p_first_name text,
  p_last_name text,
  p_telephone text default null
)
returns jsonb language plpgsql security definer set search_path = ''
as $$
declare
  v_user_id uuid := auth.uid();
  v_email text;
  v_role text;
  v_teacher public.teachers%rowtype;
  v_name text;
begin
  if v_user_id is null then
    raise exception 'Authentication required' using errcode = '28000';
  end if;
  select role into v_role from public.profiles where id = v_user_id for update;
  if v_role is distinct from 'user' then
    raise exception 'Teacher registration is not available for this account'
      using errcode = '42501';
  end if;
  v_name := trim(coalesce(p_first_name, '') || ' ' || coalesce(p_last_name, ''));
  if v_name = '' then
    raise exception 'Teacher name is required' using errcode = '22023';
  end if;
  if exists (select 1 from public.teachers where user_id = v_user_id) then
    raise exception 'Teacher profile already exists' using errcode = '23505';
  end if;
  select email into v_email from auth.users where id = v_user_id;
  update public.profiles set display_name = v_name, role = 'teacher',
    updated_at = now() where id = v_user_id;
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
