-- Retention and meaningful-use metrics (roadmap brief section 10), from tables the app already writes. Read-only,
-- counts and percentages only, no personal data; nothing is tracked on the website or in the app for this.
-- Needs migration 20261103300000_daily_checkins. Run only after the owner authorises cloud access (CLAUDE.md):
--   supabase db query --project-ref <ref> -f tools/retention_metrics.sql
--
-- Definitions (dates are UTC calendar days):
--   meaningful action  a workout logged (workout_logs), a food entry (food_log), a daily check-in (daily_checkins) or a
--                      message to the coach (coach_messages, role user). Opening the app does not count.
--   activation         an account with at least one generated plan (finished onboarding and got a plan).
--   Dn retention       share of a signup-week cohort with a meaningful action exactly n days after signup. A cohort is
--                      shown for Dn only once every account in it is at least n days old.
--   sessions per week  last full week: distinct workout days per user, among users with at least one.
--   workout adherence  last full week (Mon-Sun): sum over users of min(sessions, planned days) / sum of planned days,
--                      for users with a plan; planned days from their latest plan's trainingDaysPerWeek.
-- Small cohorts swing a lot: treat anything under 20 accounts as anecdote, not a rate.
begin transaction read only;

-- 1. Signup-week cohorts: size, activation, D1 / D7 / D30.
with actions as (
  select user_id, performed_on as day from public.workout_logs
  union select user_id, day from public.food_log
  union select user_id, day from public.daily_checkins
  union select user_id, (created_at at time zone 'utc')::date from public.coach_messages where role = 'user')
select to_char(date_trunc('week', u.created_at at time zone 'utc'), 'YYYY-MM-DD') as cohort_week,
       count(*) as accounts,
       round(100.0 * count(*) filter (where exists (select 1 from public.generated_plans g where g.user_id = u.id)) / count(*), 1) as activation_pct,
       case when max(u.created_at) <= now() - interval '1 day' then round(100.0 * count(*) filter (where exists (
         select 1 from actions a where a.user_id = u.id and a.day = (u.created_at at time zone 'utc')::date + 1)) / count(*), 1) end as d1_pct,
       case when max(u.created_at) <= now() - interval '7 days' then round(100.0 * count(*) filter (where exists (
         select 1 from actions a where a.user_id = u.id and a.day = (u.created_at at time zone 'utc')::date + 7)) / count(*), 1) end as d7_pct,
       case when max(u.created_at) <= now() - interval '30 days' then round(100.0 * count(*) filter (where exists (
         select 1 from actions a where a.user_id = u.id and a.day = (u.created_at at time zone 'utc')::date + 30)) / count(*), 1) end as d30_pct
  from auth.users u
 group by 1
 order by 1 desc
 limit 12;

-- 2. Last 7 days and last full week, all accounts.
with actions as (
  select user_id, performed_on as day from public.workout_logs
  union select user_id, day from public.food_log
  union select user_id, day from public.daily_checkins
  union select user_id, (created_at at time zone 'utc')::date from public.coach_messages where role = 'user'),
     wau as (select distinct user_id from actions where day > current_date - 7),
     week as (select date_trunc('week', current_date)::date - 7 as mon),
     planned as (
       select distinct on (g.user_id) g.user_id, least(greatest(coalesce((g.plan ->> 'trainingDaysPerWeek')::int, 0), 0), 7) as days
         from public.generated_plans g order by g.user_id, g.created_at desc),
     done as (
       select w.user_id, count(distinct w.performed_on) as n from public.workout_logs w, week
        where w.performed_on >= week.mon and w.performed_on < week.mon + 7 group by w.user_id)
select metric, value from (
  select 1 as ord, 'weekly active users (meaningful action, 7 days)' as metric, count(*)::text as value from wau
  union all
  select 2, 'of those, logged food (%)', coalesce(round(100.0 * count(*) filter (where exists (
    select 1 from public.food_log f where f.user_id = wau.user_id and f.day > current_date - 7)) / nullif(count(*), 0), 1)::text, 'n/a') from wau
  union all
  select 3, 'of those, did a daily check-in (%)', coalesce(round(100.0 * count(*) filter (where exists (
    select 1 from public.daily_checkins c where c.user_id = wau.user_id and c.day > current_date - 7)) / nullif(count(*), 0), 1)::text, 'n/a') from wau
  union all
  select 4, 'workout adherence, last full week (%)', coalesce(round(100.0 * sum(least(coalesce(d.n, 0), p.days)) / nullif(sum(p.days), 0), 1)::text, 'n/a')
    from planned p left join done d using (user_id) where p.days > 0
  union all
  select 5, 'sessions per week, users who trained last full week', coalesce(round(avg(d.n), 2)::text, 'n/a') from done d
  union all
  select 6, 'users who trained on 3+ days last full week', count(*) filter (where d.n >= 3)::text from done d
) m order by ord;

rollback;
