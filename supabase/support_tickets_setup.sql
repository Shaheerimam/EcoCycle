-- Support Tickets Table for Admin Ticket Management
-- Run in Supabase SQL editor.

create table if not exists public.support_tickets (
  id uuid default gen_random_uuid() primary key,
  user_id uuid references auth.users(id) on delete cascade not null,
  subject text not null,
  description text not null,
  status text not null default 'open' check (status in ('open', 'in_progress', 'resolved')),
  priority text not null default 'medium' check (priority in ('low', 'medium', 'high')),
  created_at timestamp with time zone default now() not null,
  updated_at timestamp with time zone default now() not null,
  resolved_at timestamp with time zone
);

alter table public.support_tickets enable row level security;

create policy "Users can insert their own tickets" on public.support_tickets
  for insert with check (auth.uid() = user_id);

create policy "Users can view their own tickets" on public.support_tickets
  for select using (auth.uid() = user_id);

create policy "Admins and moderators can view all tickets" on public.support_tickets
  for select using (
    exists (
      select 1 from public.user_profiles
      where id = auth.uid() and role in ('moderator', 'admin')
    )
  );

create policy "Admins and moderators can update tickets" on public.support_tickets
  for update using (
    exists (
      select 1 from public.user_profiles
      where id = auth.uid() and role in ('moderator', 'admin')
    )
  );
