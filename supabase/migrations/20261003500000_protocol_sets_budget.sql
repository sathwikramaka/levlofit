-- 1. Set log: reps and load per set, so each session can suggest the next step (double progression).
create table public.set_logs (
  id bigint generated always as identity primary key,
  user_id uuid not null default auth.uid() references auth.users (id) on delete cascade,
  performed_on date not null default current_date,
  exercise_id text not null references public.exercises (id) on delete cascade,
  set_no smallint not null check (set_no between 1 and 10),
  reps smallint not null check (reps between 1 and 100),
  kg numeric(5, 1) check (kg between 0 and 500),
  created_at timestamptz not null default now()
);
create index set_logs_user_move on public.set_logs (user_id, exercise_id, performed_on desc);
alter table public.set_logs enable row level security;
revoke all on public.set_logs from anon, authenticated;
grant select, delete on public.set_logs to authenticated;
grant insert (performed_on, exercise_id, set_no, reps, kg) on public.set_logs to authenticated;
create policy "own sets" on public.set_logs for all to authenticated
  using ((select auth.uid()) = user_id) with check ((select auth.uid()) = user_id);

-- 2. Diet budget, from the protocol editor: a tier, or the user's own range in rupees a day.
alter table public.dietary_profiles
  add column budget_tier text not null default 'medium' check (budget_tier in ('low', 'medium', 'high', 'custom')),
  add column budget_min_inr smallint check (budget_min_inr between 0 and 10000),
  add column budget_max_inr smallint check (budget_max_inr between 0 and 10000),
  add constraint budget_range check (budget_min_inr is null or budget_max_inr is null or budget_min_inr <= budget_max_inr);

-- 3. Own daily water target (null = the default from EFSA plus training-day top-up).
alter table public.profiles add column water_target_ml smallint check (water_target_ml between 1000 and 6000);
grant update (water_target_ml) on public.profiles to authenticated;
