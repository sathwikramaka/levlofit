-- Coach actions on a whole session (batch 3b on): 'lighter' makes that day's session one set lighter on every move
-- with more reps in reserve; 'move' (batch 3c) moves that day's session to another day of the same week. As with
-- exercise_swaps, Levlofit AI only proposes; coach-chat checks and stores the proposal, and only a confirm request
-- that passes the checks again turns it 'confirmed'. The app can read and delete its own rows but never write them.
create table public.session_changes (
  id bigint generated always as identity primary key,
  user_id uuid not null references auth.users (id) on delete cascade,
  day date not null, -- the session's planned day
  kind text not null check (kind in ('lighter', 'move')),
  to_day date, -- 'move' only: the day it moves to
  status text not null default 'proposed' check (status in ('proposed', 'confirmed')),
  created_at timestamptz not null default now(),
  confirmed_at timestamptz,
  check ((status = 'confirmed') = (confirmed_at is not null)),
  check ((kind = 'move') = (to_day is not null)),
  check (to_day is null or (to_day <> day and to_day between day - 6 and day + 6))
);
create index session_changes_user_day on public.session_changes (user_id, day);
-- At most one confirmed change of each kind per session day.
create unique index session_changes_one_per_day on public.session_changes (user_id, day, kind) where status = 'confirmed';

alter table public.session_changes enable row level security;
revoke all on public.session_changes from anon, authenticated;
grant select, delete on public.session_changes to authenticated;
create policy "own session changes" on public.session_changes for all to authenticated
  using ((select auth.uid()) = user_id) with check ((select auth.uid()) = user_id);
