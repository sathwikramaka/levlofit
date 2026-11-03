-- Roadmap Stage 3 (brief 5.2): an optional daily check-in. One row per person per day, every answer optional and
-- editable (upsert on the primary key; PostgREST upserts set every sent column, day included, hence its update grant). Health-related answers (energy, sleep, soreness) are own-row only, never
-- read by anyone else, not sent to the AI provider and deleted with the account (cascade). No rule reads them yet;
-- any future rule that does must be documented first (brief 7.3).
create table public.daily_checkins (
  user_id uuid not null default auth.uid() references auth.users (id) on delete cascade,
  day date not null check (day >= date '2026-01-01'),
  workout text check (workout in ('done', 'partly', 'skipped', 'rest')),
  food text check (food in ('followed', 'partly', 'not')),
  energy smallint check (energy between 1 and 5),
  sleep smallint check (sleep between 1 and 5),     -- sleep quality, 1 poor to 5 great
  soreness smallint check (soreness between 0 and 3), -- 0 none, 1 a little, 2 sore, 3 very sore
  note text check (char_length(note) <= 500),
  updated_at timestamptz not null default now(),
  primary key (user_id, day)
);

alter table public.daily_checkins enable row level security;
revoke all on public.daily_checkins from anon, authenticated;
grant select, delete on public.daily_checkins to authenticated;
grant insert (day, workout, food, energy, sleep, soreness, note, updated_at),
  update (day, workout, food, energy, sleep, soreness, note, updated_at) on public.daily_checkins to authenticated;
create policy "own check-ins" on public.daily_checkins for all to authenticated
  using ((select auth.uid()) = user_id) with check ((select auth.uid()) = user_id);

-- Rollback: drop table public.daily_checkins; (loses the check-ins stored since; take a backup first).
