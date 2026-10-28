-- B2 (audit 2026-10-28): Build my plate's health conditions and protein-shake scoops move from the phone
-- (SharedPreferences) to the account, so the plan engine, the meal planner and Levlofit AI all see the same answers,
-- on every phone and after a reinstall.
-- health_conditions: the conditions the person picked (app/lib/dashboard_menu.dart _conditionNames). generate-plan
--   reads them: kidney disease removes the creatine suggestion; pregnancy applies the plan engine's pregnancy rule.
--   The others only show a see-your-doctor note; Levlofit does not plan diets for them.
-- whey_scoops: protein-shake scoops a day (0 to 3), planned into the evening snack (diet_plan.dart addShake).
-- Additive: defaults keep every existing row as it is. dietary_profiles keeps its table-wide grants and its
-- own-row policy ("own diet"), so the owner can read and write both columns and no one else can.
alter table public.dietary_profiles
  add column health_conditions text[] not null default '{}'
    check (health_conditions <@ array['diabetes', 'pcos', 'thyroid', 'hypertension', 'cholesterol', 'kidney', 'ibs', 'pregnancy']::text[]),
  add column whey_scoops smallint not null default 0 check (whey_scoops between 0 and 3);
