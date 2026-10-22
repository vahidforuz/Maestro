-- Supabase's public-table defaults grant table-level UPDATE. Column grants
-- do not narrow that privilege until the table-level grant is revoked.
revoke update on public.teachers from anon, authenticated;
grant update (name, first_name, last_name, studio_name, email, telephone,
  address, city, postal_code, main_instrument, other_instruments,
  default_lesson_duration, default_lesson_price, currency, profile_image_path,
  updated_at) on public.teachers to authenticated;
