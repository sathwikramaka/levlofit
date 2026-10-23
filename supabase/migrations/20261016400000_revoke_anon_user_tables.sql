-- Defence in depth: the anon role (signed-out requests) keeps no privileges on per-user tables. Every policy on these
-- tables is already "to authenticated", so anon could read or change nothing; this removes the leftover grants so a
-- future policy mistake cannot expose them. Signed-out reads of public reference data (foods, exercises, handbook,
-- goal catalogue, curriculum levels) are unchanged.
revoke all on public.body_metrics, public.dietary_profiles, public.user_goals, public.workout_logs,
  public.generated_plans, public.profiles from anon;
