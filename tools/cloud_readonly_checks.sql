-- Read-only pre-deploy checks for the Levlofit cloud project (runbook steps 1-4 in docs/PROGRESS.md).
-- One SELECT statement: it reads counts and migration versions only, writes nothing, returns no personal data.
-- Run only after the owner authorises cloud access, for example:
--   supabase db query --project-ref <ref> -f tools/cloud_readonly_checks.sql
select check_name, value from (
  -- Which pending migrations are already applied (if 20261007400000 is listed, its later corrections will not re-run).
  select 'applied: ' || version as check_name, name as value, 1 as ord
    from supabase_migrations.schema_migrations where version >= '20261007100000'
  union all
  -- Must be 0, or the handbook migration's delete aborts.
  select 'goal_catalog rows pointing at a handbook chapter', count(*)::text, 2 from public.goal_catalog where handbook_chapter is not null
  union all
  -- Rows the pilates migration deletes permanently (export them first if not 0).
  select 'user_goals rows for pilates', count(*)::text, 3 from public.user_goals where goal = 'pilates'
  union all
  select 'goal_levels rows for pilates', count(*)::text, 4 from public.goal_levels where goal = 'pilates'
  union all
  -- Rows above the new self-assessment cap of 3 (they stay; users can only lower them afterwards).
  select 'goal_levels rows above level 3', count(*)::text, 5 from public.goal_levels where level > 3
) c
order by ord, check_name;
