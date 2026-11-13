-- Owner request 2026-11-14: Levlofit AI may propose a change to any Protocol setting, not just body goal, pace and
-- days. Same flow as B5 (20261029200000_plan_changes): coach-chat checks each option (the plan engine for settings the
-- plan is built from), stores the proposal, and only a confirm that passes the checks again writes the setting. The
-- app then rebuilds the plan. New: the protein powder kind (whey, plant, yeast, soy, pea, egg), shown on Diet instead of
-- "Whey protein" or "Plant protein powder"; null keeps the old rule (plant when dairy is excluded).
alter table public.plan_changes drop constraint plan_changes_field_check;
alter table public.plan_changes add constraint plan_changes_field_check check (field in (
  'weight_goal', 'diet_pace', 'days_per_week', 'session_minutes', 'equipment', 'daily_activity', 'diet_type', 'training_time',
  'budget_tier', 'cook_time', 'water_target_ml', 'protein_powder', 'supplement_add', 'supplement_remove'
));
-- The older value checks still hold for their fields; every value is a short plain token.
alter table public.plan_changes add constraint plan_changes_value_token check (value ~ '^[a-z0-9_]{1,40}$');

alter table public.dietary_profiles
  add column protein_powder text check (protein_powder in ('whey', 'plant', 'yeast', 'soy', 'pea', 'egg'));
