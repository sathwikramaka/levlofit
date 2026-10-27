-- Optional body-photo check (functions/body-check): at most 3 checks per user per day. Same function as in
-- 20261013100000_reliability_and_limits.sql with one bucket added; _shared/rate.ts lists the same values.
create or replace function public.check_rate(p_bucket text, p_limit int, p_window interval) returns boolean
language plpgsql security definer set search_path = ''
as $$
declare
  uid uuid := (select auth.uid());
  lim int;
  win interval;
  n int;
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
  insert into public.rate_events (user_id, bucket) values (uid, p_bucket);
  return true;
end;
$$;
revoke execute on function public.check_rate(text, int, interval) from public, anon;
grant execute on function public.check_rate(text, int, interval) to authenticated;
