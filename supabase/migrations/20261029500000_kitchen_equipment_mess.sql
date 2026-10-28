-- Kitchen equipment, mess meals and a minimal cooking-time option (owner request 2026-10-29), edited in onboarding
-- and Protocol. The meal planner (app/lib/diet_plan.dart) plans each meal the person makes only from foods their
-- equipment can make, and the meals they eat from a hostel or PG mess from the foods a mess kitchen serves.
-- kitchen_equipment: what they have; empty = not answered yet, so the older kitchen column still decides (full ->
--   stove and pressure cooker, stove_only -> stove, no_stove -> nothing). 'none' = no personal cooking equipment.
-- kitchen_other: equipment or limits in their own words (up to 200 characters); shown to Levlofit AI with food
--   questions, not parsed by the planner.
-- mess_meals: meals that usually come from a mess (empty = none).
-- cook_time gains 'minimal' (under about 10 minutes, nothing made ahead).
-- Additive: defaults keep every existing row and meal plan as it is. dietary_profiles keeps its table-wide grants and
-- own-row policy.
alter table public.dietary_profiles
  add column kitchen_equipment text[] not null default '{}'
    check (kitchen_equipment <@ array['none', 'stove', 'induction', 'pressure_cooker', 'kettle', 'multi_kettle', 'blender', 'microwave', 'fridge']::text[]),
  add column kitchen_other text check (kitchen_other is null or char_length(kitchen_other) <= 200),
  add column mess_meals text[] not null default '{}'
    check (mess_meals <@ array['breakfast', 'lunch', 'snack', 'dinner']::text[]);

alter table public.dietary_profiles drop constraint if exists dietary_profiles_cook_time_check;
alter table public.dietary_profiles add constraint dietary_profiles_cook_time_check check (cook_time in ('plenty', 'short', 'minimal'));
