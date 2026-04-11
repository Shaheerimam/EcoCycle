-- Pending Disputes Table for Moderator Review
-- Run in Supabase SQL editor.

create table if not exists public.pending_disputes (
  id uuid default gen_random_uuid() primary key,
  user_id uuid references auth.users(id) on delete cascade not null,
  item_name text not null,
  category_label text not null,
  confidence float not null,
  image_url text, -- URL to the uploaded image
  image_data text, -- Base64 encoded image data
  status text default 'pending' check (status in ('pending', 'approved', 'rejected')),
  moderator_id uuid references auth.users(id) on delete set null,
  moderator_notes text,
  reviewed_at timestamp with time zone,
  created_at timestamp with time zone default now() not null,
  updated_at timestamp with time zone default now() not null
);

-- Enable RLS
alter table public.pending_disputes enable row level security;

-- Policies for pending_disputes
-- Users can insert their own pending disputes
create policy "Users can insert their own pending disputes" on public.pending_disputes
  for insert with check (auth.uid() = user_id);

-- Users can view their own pending disputes
create policy "Users can view their own pending disputes" on public.pending_disputes
  for select using (auth.uid() = user_id);

-- Moderators and admins can view all pending disputes
create policy "Moderators can view all pending disputes" on public.pending_disputes
  for select using (
    exists (
      select 1 from public.user_profiles
      where id = auth.uid() and role in ('moderator', 'admin')
    )
  );

-- Moderators and admins can update pending disputes
create policy "Moderators can update pending disputes" on public.pending_disputes
  for update using (
    exists (
      select 1 from public.user_profiles
      where id = auth.uid() and role in ('moderator', 'admin')
    )
  );

-- Function to get pending disputes count
create or replace function public.get_pending_disputes_count()
returns int
language sql
security definer
set search_path = public
as $$
  select count(*)::int
  from public.pending_disputes
  where status = 'pending';
$$;

-- Function to approve dispute
create or replace function public.approve_dispute(
  p_dispute_id uuid,
  p_moderator_notes text default null
)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_user_id uuid;
  v_item_name text;
  v_category_label text;
  v_confidence float;
begin
  -- Get dispute details
  select user_id, item_name, category_label, confidence
  into v_user_id, v_item_name, v_category_label, v_confidence
  from public.pending_disputes
  where id = p_dispute_id and status = 'pending';

  if not found then
    raise exception 'Dispute not found or already processed';
  end if;

  -- Update dispute status
  update public.pending_disputes
  set status = 'approved',
      moderator_id = auth.uid(),
      moderator_notes = p_moderator_notes,
      reviewed_at = now(),
      updated_at = now()
  where id = p_dispute_id;

  -- Award points to user
  update public.user_profiles
  set total_points = total_points + 10,
      classification_count = classification_count + 1,
      carbon_saved_kg = carbon_saved_kg + 0.3
  where id = v_user_id;

  -- Insert into user_scans as confirmed
  insert into public.user_scans (
    user_id, item_name, category_label, confidence, points_awarded, confirmed
  ) values (
    v_user_id, v_item_name, v_category_label, v_confidence, 10, true
  );

  -- Update user activity
  insert into public.user_activity_days (user_id, activity_date, activities_count, last_activity_at)
  values (v_user_id, current_date, 1, now())
  on conflict (user_id, activity_date)
  do update set
    activities_count = user_activity_days.activities_count + 1,
    last_activity_at = now();

  -- Refresh streak
  perform public.refresh_user_streak(v_user_id);
end;
$$;

-- Function to reject dispute
create or replace function public.reject_dispute(
  p_dispute_id uuid,
  p_moderator_notes text default null
)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  -- Update dispute status
  update public.pending_disputes
  set status = 'rejected',
      moderator_id = auth.uid(),
      moderator_notes = p_moderator_notes,
      reviewed_at = now(),
      updated_at = now()
  where id = p_dispute_id and status = 'pending';

  if not found then
    raise exception 'Dispute not found or already processed';
  end if;
end;
$$;