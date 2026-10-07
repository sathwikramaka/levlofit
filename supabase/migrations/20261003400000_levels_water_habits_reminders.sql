-- 1. Assessed level per goal. Kept apart from user_goals so editing goals never loses an assessment.
--    generate-plan reads it; the engine trains from this level instead of the self-reported experience.
create table public.goal_levels (
  user_id uuid not null default auth.uid() references auth.users (id) on delete cascade,
  goal text not null references public.goal_catalog (id) on delete cascade,
  level smallint not null check (level between 0 and 5),
  assessed_at timestamptz not null default now(),
  primary key (user_id, goal)
);

-- 2. Water, one row per drink.
create table public.water_intake (
  id bigint generated always as identity primary key,
  user_id uuid not null default auth.uid() references auth.users (id) on delete cascade,
  taken_at timestamptz not null default now(),
  ml smallint not null check (ml between 50 and 2000)
);
create index water_intake_user_time on public.water_intake (user_id, taken_at desc);

-- 3. Daily habits ticked by hand (training and water are counted from their own tables).
create table public.habit_logs (
  user_id uuid not null default auth.uid() references auth.users (id) on delete cascade,
  day date not null,
  habit text not null check (habit in ('protein', 'sleep', 'steps', 'mobility', 'no_junk')),
  primary key (user_id, day, habit)
);

-- 4. Reminder settings, so a reinstall or a second phone gets the same reminders.
create table public.reminder_prefs (
  user_id uuid primary key default auth.uid() references auth.users (id) on delete cascade,
  enabled boolean not null default true,
  workout_at time,                                                    -- training reminder on planned days
  water_every_h smallint check (water_every_h between 1 and 6),       -- between 09:00 and 21:00
  weigh_in_weekday smallint check (weigh_in_weekday between 1 and 7), -- at 08:00
  updated_at timestamptz not null default now()
);

alter table public.goal_levels enable row level security;
alter table public.water_intake enable row level security;
alter table public.habit_logs enable row level security;
alter table public.reminder_prefs enable row level security;

revoke all on public.goal_levels, public.water_intake, public.habit_logs, public.reminder_prefs from anon, authenticated;
grant select, delete on public.goal_levels, public.water_intake, public.habit_logs, public.reminder_prefs to authenticated;
grant insert (goal, level, assessed_at), update (level, assessed_at) on public.goal_levels to authenticated;
grant insert (taken_at, ml) on public.water_intake to authenticated;
grant insert (day, habit) on public.habit_logs to authenticated;
grant insert (enabled, workout_at, water_every_h, weigh_in_weekday, updated_at),
  update (enabled, workout_at, water_every_h, weigh_in_weekday, updated_at) on public.reminder_prefs to authenticated;

create policy "own levels" on public.goal_levels for all to authenticated
  using ((select auth.uid()) = user_id) with check ((select auth.uid()) = user_id);
create policy "own water" on public.water_intake for all to authenticated
  using ((select auth.uid()) = user_id) with check ((select auth.uid()) = user_id);
create policy "own habits" on public.habit_logs for all to authenticated
  using ((select auth.uid()) = user_id) with check ((select auth.uid()) = user_id);
create policy "own reminders" on public.reminder_prefs for all to authenticated
  using ((select auth.uid()) = user_id) with check ((select auth.uid()) = user_id);

-- Upserts send the key column too; PostgREST updates every sent column on conflict.
grant update (goal) on public.goal_levels to authenticated;
