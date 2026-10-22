-- Private media is scoped to a student and uploader. Object paths are:
--   <student_uuid>/<uploader_auth_uid>/<random_filename>
-- Local and hosted projects use the same policy; no client needs a secret key.
insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values (
  'maestro-private', 'maestro-private', false, 52428800,
  array['image/jpeg', 'image/png', 'video/mp4', 'video/quicktime']::text[]
)
on conflict (id) do nothing;

create function public.media_student_id(p_path text)
returns uuid language sql immutable set search_path = ''
as $$
  select case when split_part(p_path, '/', 1) ~
    '^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$'
    then split_part(p_path, '/', 1)::uuid else null end;
$$;

create function public.can_upload_student_media(p_path text)
returns boolean language sql stable security definer set search_path = ''
as $$
  select auth.uid() is not null
    and split_part(p_path, '/', 2) = auth.uid()::text
    and split_part(p_path, '/', 3) <> ''
    and (
      public.is_teacher_for(public.media_student_id(p_path))
      or exists (
        select 1 from public.students s
        where s.id = public.media_student_id(p_path) and s.user_id = auth.uid()
      )
    );
$$;

revoke all on function public.media_student_id(text) from public;
revoke all on function public.can_upload_student_media(text) from public;
grant execute on function public.media_student_id(text) to authenticated;
grant execute on function public.can_upload_student_media(text) to authenticated;

create policy maestro_private_media_read on storage.objects
for select to authenticated
using (bucket_id = 'maestro-private' and public.can_read_student(public.media_student_id(name)));

create policy maestro_private_media_insert on storage.objects
for insert to authenticated
with check (bucket_id = 'maestro-private' and public.can_upload_student_media(name));

create policy maestro_private_media_update on storage.objects
for update to authenticated
using (bucket_id = 'maestro-private' and owner_id = auth.uid()::text
  and public.can_upload_student_media(name))
with check (bucket_id = 'maestro-private' and owner_id = auth.uid()::text
  and public.can_upload_student_media(name));

create policy maestro_private_media_delete on storage.objects
for delete to authenticated
using (bucket_id = 'maestro-private' and owner_id = auth.uid()::text
  and public.can_upload_student_media(name));

-- Postgres Changes remains subject to table SELECT policies for subscribers.
alter publication supabase_realtime add table public.lessons, public.lesson_notes;
