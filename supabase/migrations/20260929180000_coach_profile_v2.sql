-- Coach profile v2 (user request 2026-09-29): richer, still minimal, intake for the coach review.
-- Every new field is read by the plan engine (supabase/functions/_shared/plan-engine.ts, 2.0.0).

-- 1. Strongman removed from the catalog (no user_goals referenced it).
delete from public.goal_catalog where id = 'strongman';

-- 2. Body-weight goal becomes a training phase.
alter table public.profiles drop constraint profiles_weight_goal_check;
update public.profiles set weight_goal = case weight_goal when 'lose' then 'cut' when 'gain' then 'bulk' else weight_goal end;
alter table public.profiles add constraint profiles_weight_goal_check
  check (weight_goal in ('cut', 'bulk', 'recomp', 'maintain', 'general'));

-- 3. Equipment: a custom option with a picked list of items.
alter table public.profiles drop constraint profiles_equipment_check;
alter table public.profiles add constraint profiles_equipment_check check (equipment in ('none', 'home', 'gym', 'custom'));
alter table public.profiles add column equipment_items text[] not null default '{}'
  check (cardinality(equipment_items) <= 20);

-- 4. Body composition, schedule, recovery and safety screen.
alter table public.profiles
  add column body_type text check (body_type in ('lean', 'average', 'extra_fat', 'muscular', 'slim_soft')),
  add column waist_cm numeric(5, 1) check (waist_cm between 40 and 200),
  add column days_per_week smallint check (days_per_week between 1 and 7),
  add column session_minutes smallint check (session_minutes in (20, 30, 45, 60, 75, 90)),
  add column daily_activity text check (daily_activity in ('sedentary', 'light', 'active', 'very_active')),
  add column sleep_hours numeric(3, 1) check (sleep_hours between 3 and 12),
  add column health_flags text[] not null default '{}'
    check (health_flags <@ array['heart_condition', 'chest_pain', 'dizziness', 'pregnancy', 'other_medical']::text[]),
  add column injuries text check (char_length(injuries) <= 300);

grant update (equipment_items, body_type, waist_cm, days_per_week, session_minutes, daily_activity, sleep_hours, health_flags, injuries)
  on public.profiles to authenticated;

-- 5. Supplements the user is willing to use (none = empty array).
alter table public.dietary_profiles add column supplements text[] not null default '{}'
  check (supplements <@ array['protein_powder', 'creatine']::text[]);
