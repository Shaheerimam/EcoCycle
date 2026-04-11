-- Weekly leaderboard setup for Eco Cycle
-- Run in Supabase SQL editor.

create or replace function public.get_weekly_leaderboard(
  p_limit int default 50
)
returns table (
  user_id uuid,
  display_name text,
  full_name text,
  username text,
  avatar_initial text,
  weekly_points int,
  weekly_scans int,
  total_points int,
  is_private_profile boolean
)
language sql
security definer
set search_path = public
as $$
  with weekly as (
    select
      s.user_id,
      coalesce(sum(s.points_awarded), 0)::int as weekly_points,
      count(*)::int as weekly_scans
    from public.user_scans s
    where s.created_at >= (now() at time zone 'utc') - interval '7 days'
    group by s.user_id
  )
  select
    p.id as user_id,
    p.display_name,
    p.full_name,
    p.username,
    p.avatar_initial,
    coalesce(w.weekly_points, 0) as weekly_points,
    coalesce(w.weekly_scans, 0) as weekly_scans,
    coalesce(p.total_points, 0) as total_points,
    coalesce(p.is_private_profile, false) as is_private_profile
  from public.user_profiles p
  left join weekly w on w.user_id = p.id
  where coalesce(p.is_private_profile, false) = false
  order by
    coalesce(w.weekly_points, 0) desc,
    coalesce(p.total_points, 0) desc,
    coalesce(w.weekly_scans, 0) desc
  limit greatest(coalesce(p_limit, 50), 1);
$$;

revoke all on function public.get_weekly_leaderboard(int) from public;
grant execute on function public.get_weekly_leaderboard(int) to anon, authenticated;

comment on function public.get_weekly_leaderboard(int) is
  'Returns public weekly leaderboard rows for last 7 days with private profiles excluded.';
