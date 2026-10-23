-- Coach action "swap today's exercise" (batch 3a). Levlofit AI may PROPOSE replacing one move of today's session;
-- coach-chat checks the proposal against the exercise catalogue, the person's equipment and their injuries, and
-- stores it as 'proposed'. Only a confirm request that passes the same checks again turns it 'confirmed', and only
-- confirmed swaps change the session the app shows. Rows are written by the server only (service role): the app can
-- read and delete its own rows (Not now, undo) but never insert or update them, so no client request can skip the
-- checks or the confirmation.
create table public.exercise_swaps (
  id bigint generated always as identity primary key,
  user_id uuid not null references auth.users (id) on delete cascade,
  day date not null,
  from_exercise text not null references public.exercises (id) on delete cascade,
  to_exercise text not null references public.exercises (id) on delete cascade,
  status text not null default 'proposed' check (status in ('proposed', 'confirmed')),
  created_at timestamptz not null default now(),
  confirmed_at timestamptz,
  check (from_exercise <> to_exercise),
  check ((status = 'confirmed') = (confirmed_at is not null))
);
create index exercise_swaps_user_day on public.exercise_swaps (user_id, day);
-- At most one confirmed swap per move and day.
create unique index exercise_swaps_one_per_move on public.exercise_swaps (user_id, day, from_exercise) where status = 'confirmed';

alter table public.exercise_swaps enable row level security;
revoke all on public.exercise_swaps from anon, authenticated;
grant select, delete on public.exercise_swaps to authenticated;
create policy "own swaps" on public.exercise_swaps for all to authenticated
  using ((select auth.uid()) = user_id) with check ((select auth.uid()) = user_id);
