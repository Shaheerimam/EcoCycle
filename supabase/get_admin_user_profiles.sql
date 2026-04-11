-- Grant admins/moderators unrestricted access to user_profiles via a security-definer function.
-- Run this in your Supabase SQL editor if you want admin user management to work even when RLS is enabled.

create or replace function public.get_admin_user_profiles()
returns table (
  id uuid,
  display_name text,
  username text,
  role text,
  total_points int,
  classification_count int
)
language sql
security definer
set search_path = public
as $$
  select
    id,
    display_name,
    username,
    role,
    coalesce(total_points, 0)::int as total_points,
    coalesce(classification_count, 0)::int as classification_count
  from public.user_profiles
  where exists (
    select 1
    from public.user_profiles as profile_user
    where profile_user.id = auth.uid()
      and profile_user.role in ('moderator', 'admin')
  );
$$;
