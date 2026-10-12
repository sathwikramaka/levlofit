-- In-app feedback. Users can send; only the project owner (service role / dashboard) can read.
-- Tied to the user so it goes with their account on delete.
create table public.app_feedback (
  id bigint generated always as identity primary key,
  user_id uuid not null default auth.uid() references auth.users on delete cascade,
  message text not null check (char_length(message) between 3 and 2000),
  created_at timestamptz not null default now()
);
alter table public.app_feedback enable row level security;
revoke all on public.app_feedback from anon, authenticated;
grant insert (message) on public.app_feedback to authenticated;
create policy "send own feedback" on public.app_feedback for insert to authenticated
  with check (user_id = (select auth.uid()));
create index app_feedback_user on public.app_feedback (user_id);
