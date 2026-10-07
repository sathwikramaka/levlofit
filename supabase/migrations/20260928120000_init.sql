-- Levlo initial schema. Allowed values mirror supabase/functions/_shared/plan-engine.ts.
-- Every user-owned row cascades from auth.users, so deleting the auth user deletes all data.

create table public.profiles (
  id uuid primary key references auth.users (id) on delete cascade,
  display_name text check (char_length(display_name) <= 60),
  birth_year int check (birth_year between 1920 and 2020), -- adult-age gate lives in the plan engine
  sex text check (sex in ('male', 'female')),
  height_cm numeric(5, 1) check (height_cm between 120 and 230),
  weight_kg numeric(5, 1) check (weight_kg between 30 and 250),
  weight_goal text check (weight_goal in ('lose', 'maintain', 'gain')),
  equipment text check (equipment in ('none', 'home', 'gym')),
  onboarding_complete boolean not null default false,
  created_at timestamptz not null default now()
);

create table public.user_goals (
  user_id uuid not null references auth.users (id) on delete cascade,
  goal text not null check (goal in ('strength', 'bodybuilding', 'aesthetic', 'calisthenics', 'running', 'hyrox', 'boxing', 'general', 'mobility')),
  experience text not null check (experience in ('none', 'beginner', 'intermediate', 'advanced')),
  priority smallint not null check (priority between 1 and 4),
  primary key (user_id, goal),
  unique (user_id, priority)
);

create table public.dietary_profiles (
  user_id uuid primary key references auth.users (id) on delete cascade,
  diet_type text not null check (diet_type in ('vegetarian', 'eggitarian', 'vegan', 'non_vegetarian')),
  restrictions text[] not null default '{}'
    check (restrictions <@ array['lactose', 'gluten', 'peanut', 'tree_nut', 'soy', 'egg', 'fish', 'shellfish']::text[])
);

-- Immutable snapshots: plans are reproducible and never silently regenerated.
create table public.generated_plans (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users (id) on delete cascade,
  engine_version text not null,
  input jsonb not null,
  plan jsonb not null,
  created_at timestamptz not null default now()
);
create index generated_plans_user_created_idx on public.generated_plans (user_id, created_at desc);

create table public.body_metrics (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users (id) on delete cascade,
  measured_on date not null default current_date,
  weight_kg numeric(5, 1) check (weight_kg between 30 and 250),
  waist_cm numeric(5, 1) check (waist_cm between 40 and 200),
  unique (user_id, measured_on)
);

create table public.workout_logs (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users (id) on delete cascade,
  performed_on date not null default current_date,
  goal text not null,
  duration_min smallint check (duration_min between 1 and 600),
  rpe smallint check (rpe between 1 and 10),
  notes text check (char_length(notes) <= 2000),
  created_at timestamptz not null default now()
);
create index workout_logs_user_date_idx on public.workout_logs (user_id, performed_on desc);

-- Handbook: public read, written only by migrations/service role.
create table public.handbook_chapters (
  id smallint primary key,
  part text not null,
  title text not null,
  body_md text not null,
  sources text[] not null default '{}',
  search tsvector generated always as (
    setweight(to_tsvector('english', title), 'A') || setweight(to_tsvector('english', body_md), 'B')
  ) stored
);
create index handbook_chapters_search_idx on public.handbook_chapters using gin (search);

-- Row level security. (select auth.uid()) is evaluated once per statement, not per row.
alter table public.profiles enable row level security;
alter table public.user_goals enable row level security;
alter table public.dietary_profiles enable row level security;
alter table public.generated_plans enable row level security;
alter table public.body_metrics enable row level security;
alter table public.workout_logs enable row level security;
alter table public.handbook_chapters enable row level security;

-- Profiles: the trigger creates the row, the auth-user cascade deletes it.
create policy "read own profile" on public.profiles for select to authenticated
  using ((select auth.uid()) = id);
create policy "update own profile" on public.profiles for update to authenticated
  using ((select auth.uid()) = id) with check ((select auth.uid()) = id);
create policy "own goals" on public.user_goals for all to authenticated
  using ((select auth.uid()) = user_id) with check ((select auth.uid()) = user_id);
create policy "own diet" on public.dietary_profiles for all to authenticated
  using ((select auth.uid()) = user_id) with check ((select auth.uid()) = user_id);
-- Plans are written only by the generate-plan function; users read their own.
create policy "read own plans" on public.generated_plans for select to authenticated
  using ((select auth.uid()) = user_id);
create policy "own metrics" on public.body_metrics for all to authenticated
  using ((select auth.uid()) = user_id) with check ((select auth.uid()) = user_id);
create policy "own logs" on public.workout_logs for all to authenticated
  using ((select auth.uid()) = user_id) with check ((select auth.uid()) = user_id);
create policy "handbook is public" on public.handbook_chapters for select to anon, authenticated
  using (true);

-- The dashboard gate must not be client-writable: only generate-plan (service role) flips it.
-- Supabase grants table-wide privileges by default, so narrow them to editable columns.
revoke insert, update, delete on public.profiles from anon, authenticated;
grant update (display_name, birth_year, sex, height_cm, weight_kg, weight_goal, equipment)
  on public.profiles to authenticated;
revoke insert, update, delete on public.generated_plans, public.handbook_chapters from anon, authenticated;

-- Create the profile row on sign-up.
create function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  insert into public.profiles (id) values (new.id);
  return new;
end;
$$;

-- Trigger-only: not callable through the Data API.
revoke execute on function public.handle_new_user() from public, anon, authenticated;

create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function public.handle_new_user();
