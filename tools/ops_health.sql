-- Read-only operations check for the Levlofit cloud project: counts only, no personal data, writes nothing.
-- Run after the owner authorises cloud access (CLAUDE.md), for example weekly or before a release:
--   supabase db query --project-ref <ref> -f tools/ops_health.sql
-- Expected: body-check bucket 'yes', orphan photos 0. Anything else is a finding for docs/RELEASE_CHECKLIST.md.
begin transaction read only;
select check_name, value from (
  -- The body check fails closed without this bucket (_shared/rate.ts), so 'no' means every body check is refused.
  select 'check_rate knows body_check_day' as check_name,
         case when pg_get_functiondef('public.check_rate(text, int, interval)'::regprocedure) like '%body_check_day%' then 'yes' else 'no' end as value, 1 as ord
  union all
  -- Progress photos whose owner folder no longer matches an account: account deletion missed them (late upload or a
  -- failed storage call). Remove them through the Storage API, never by deleting storage.objects rows.
  select 'orphan progress photos', count(*)::text, 2 from storage.objects o
   where o.bucket_id = 'progress-photos' and not exists (select 1 from auth.users u where u.id::text = split_part(o.name, '/', 1))
  union all
  select 'progress photos total', count(*)::text, 3 from storage.objects where bucket_id = 'progress-photos'
  union all
  -- App error reports in the last day and week (app_errors): a jump after a release is the signal to look.
  select 'app errors, last 24 h', count(*)::text, 4 from public.app_errors where created_at > now() - interval '1 day'
  union all
  select 'app errors, last 7 days', count(*)::text, 5 from public.app_errors where created_at > now() - interval '7 days'
  union all
  -- Rate-limited calls by bucket in the last day (rate_events keeps only the current window).
  select 'rate events, last 24 h: ' || bucket, count(*)::text, 6 from public.rate_events where at > now() - interval '1 day' group by bucket
  union all
  -- Users at a cap right now: a high count means the limit or the usage needs a look.
  select 'users at the body-check cap now', count(*)::text, 7 from (
    select user_id from public.rate_events where bucket = 'body_check_day' and at > now() - interval '1 day' group by user_id having count(*) >= 3) x
  union all
  -- Funnel, counts only (no analytics script on the website or in the app): accounts -> finished onboarding ->
  -- active in the last 7 days. Downloads are counted by the host (Cloudflare Pages analytics), not here.
  select 'funnel: accounts', count(*)::text, 8 from auth.users
  union all
  select 'funnel: new accounts, last 7 days', count(*)::text, 9 from auth.users where created_at > now() - interval '7 days'
  union all
  select 'funnel: finished onboarding', count(*)::text, 10 from public.profiles where onboarding_complete
  union all
  select 'funnel: active, last 7 days', count(distinct user_id)::text, 11 from (
    select user_id from public.workout_logs where performed_on > current_date - 7
    union all select user_id from public.food_log where day > current_date - 7
    union all select user_id from public.coach_messages where created_at > now() - interval '7 days') a
) c
order by ord, check_name;
rollback;
