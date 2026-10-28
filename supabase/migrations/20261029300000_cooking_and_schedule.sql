-- B6 (audit 2026-10-28): real-life constraints for meals and the training week, edited in Protocol.
-- dietary_profiles.kitchen: 'full' (stove and pressure cooker), 'stove_only' (no pressure cooker), 'no_stove'
--   (nothing cooked at home); cook_time: 'plenty' (can soak or ferment ahead) or 'short' (about 30 minutes a meal, no
--   planning ahead). The meal planner leaves out foods the setup cannot make (app/lib/diet_plan.dart cookNeeds).
-- profiles.training_days: weekdays the person can train (1 = Monday); empty = any day. training_time: when they
--   usually can ('early_morning', 'morning', 'midday', 'evening', 'night', 'varies' for shifts). generate-plan copies
--   both into the plan; the week view places sessions on those days (app/lib/week_schedule.dart trainingDaysFor).
-- Additive: defaults keep every existing row, plan and meal plan as it is. dietary_profiles keeps its table-wide
-- grants and own-row policy; profiles writes are column grants, so the two new columns are granted here.
alter table public.dietary_profiles
  add column kitchen text not null default 'full' check (kitchen in ('full', 'stove_only', 'no_stove')),
  add column cook_time text not null default 'plenty' check (cook_time in ('plenty', 'short'));

alter table public.profiles
  add column training_days smallint[] not null default '{}'
    check (training_days <@ array[1, 2, 3, 4, 5, 6, 7]::smallint[]),
  add column training_time text not null default 'varies'
    check (training_time in ('early_morning', 'morning', 'midday', 'evening', 'night', 'varies'));

grant update (training_days, training_time) on public.profiles to authenticated;
