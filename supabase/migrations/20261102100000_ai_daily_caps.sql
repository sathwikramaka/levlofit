-- App-wide daily caps on the rate buckets (remediation 2026-11-02, finding "AI cost controls").
-- Per-user limits alone do not bound spend: many accounts can each stay under their own limit. A row in
-- ai_daily_caps caps how many events that bucket may record across all users in the last 24 hours; once reached,
-- check_rate raises 'ai_daily_cap' and the Edge Functions answer 503 (fail closed) and log ai_daily_cap_reached.
-- No rows = no app-wide cap (today's behaviour). The owner sets values in the dashboard SQL editor, without a code
-- change; per_day = 0 stops that bucket at once (a database-side kill switch, next to the AI_DISABLED secret).
-- check_rate below is the 20261027200000 version plus the cap check; per-user limits and grants are unchanged.

create table if not exists public.ai_daily_caps (
  bucket text primary key check (bucket in ('coach_chat_hour', 'coach_chat_day', 'generate_plan_day', 'body_check_day')),
  per_day int not null check (per_day >= 0),
  updated_at timestamptz not null default now()
);
alter table public.ai_daily_caps enable row level security;
revoke all on public.ai_daily_caps from anon, authenticated;

create index if not exists rate_events_bucket_at on public.rate_events (bucket, at desc);

create or replace function public.check_rate(p_bucket text, p_limit int, p_window interval) returns boolean
language plpgsql security definer set search_path = ''
as $$
declare
  uid uuid := (select auth.uid());
  lim int;
  win interval;
  n int;
  cap int;
begin
  if uid is null then
    return false;
  end if;
  select v.lim, v.win into lim, win
    from (values ('coach_chat_hour', 30, interval '1 hour'),
                 ('coach_chat_day', 150, interval '1 day'),
                 ('generate_plan_day', 20, interval '1 day'),
                 ('body_check_day', 3, interval '1 day')) as v (bucket, lim, win)
   where v.bucket = p_bucket;
  if lim is null then
    raise exception 'unknown rate bucket' using errcode = '22023';
  end if;
  -- One check at a time per user and bucket, so parallel requests cannot all pass the same count.
  perform pg_advisory_xact_lock(hashtextextended(uid::text || '|' || p_bucket, 0));
  delete from public.rate_events where user_id = uid and bucket = p_bucket and at < now() - win;
  select count(*) into n from public.rate_events where user_id = uid and bucket = p_bucket and at >= now() - win;
  if n >= lim then
    return false;
  end if;
  select c.per_day into cap from public.ai_daily_caps c where c.bucket = p_bucket;
  if cap is not null then
    -- One app-wide check at a time per capped bucket, so parallel users cannot all pass the same total.
    perform pg_advisory_xact_lock(hashtextextended('all|' || p_bucket, 0));
    if (select count(*) from public.rate_events where bucket = p_bucket and at >= now() - interval '1 day') >= cap then
      raise exception 'ai_daily_cap' using errcode = 'P0001';
    end if;
  end if;
  insert into public.rate_events (user_id, bucket) values (uid, p_bucket);
  return true;
end;
$$;
revoke execute on function public.check_rate(text, int, interval) from public, anon;
grant execute on function public.check_rate(text, int, interval) to authenticated;
