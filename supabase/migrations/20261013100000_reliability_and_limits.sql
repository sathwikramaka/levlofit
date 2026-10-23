-- Reliability, duplicate-request protection, rate limits and a server-side level lock.
-- Additive except for the goal_levels policy swap. NOT YET APPLIED OR TESTED AGAINST A DATABASE: Docker was not
-- running when this was written; run `supabase db reset` and `supabase test db` (supabase/tests/database) locally
-- before applying it anywhere. The Edge Functions keep working without it (they fall back when these functions are
-- missing), so the deploy order is: apply this migration, then deploy the functions.

-- 1. Duplicate requests: the app sends a client id with each chat message; one id saves at most one turn per user.
alter table public.coach_messages add column if not exists client_msg_id uuid;
create unique index if not exists coach_messages_client_msg
  on public.coach_messages (user_id, client_msg_id) where client_msg_id is not null;
grant insert (client_msg_id) on public.coach_messages to authenticated;

-- 2. One chat turn saved in a single transaction: open or touch the thread, store the user message and the reply,
--    and only then remove the replaced tail of an edited thread. Runs as the caller, so row level security applies.
create or replace function public.coach_commit_turn(
  p_thread_id uuid,
  p_title text,
  p_edit_from bigint,
  p_client_msg_id uuid,
  p_user_content text,
  p_assistant_content text
) returns table (thread_id uuid, user_message_id bigint, assistant_message_id bigint, duplicate boolean)
language plpgsql security invoker set search_path = ''
as $$
declare
  t uuid := p_thread_id;
  u bigint;
  a bigint;
begin
  if p_client_msg_id is not null then
    select m.thread_id, m.id into t, u from public.coach_messages m
      where m.client_msg_id = p_client_msg_id and m.role = 'user' and m.user_id = (select auth.uid());
    if found then
      select m.id into a from public.coach_messages m
        where m.thread_id = t and m.role = 'assistant' and m.id > u order by m.id limit 1;
      return query select t, u, a, true;
      return;
    end if;
    t := p_thread_id;
  end if;
  if t is null then
    insert into public.coach_threads (title) values (left(coalesce(nullif(p_title, ''), 'New chat'), 80)) returning id into t;
  else
    update public.coach_threads set updated_at = now() where id = t;
    if not found then
      raise exception 'thread not found' using errcode = 'P0002';
    end if;
  end if;
  insert into public.coach_messages (thread_id, role, content, client_msg_id)
    values (t, 'user', p_user_content, p_client_msg_id) returning id into u;
  insert into public.coach_messages (thread_id, role, content)
    values (t, 'assistant', p_assistant_content) returning id into a;
  if p_edit_from is not null then
    delete from public.coach_messages m where m.thread_id = t and m.id >= p_edit_from and m.id < u;
  end if;
  return query select t, u, a, false;
end;
$$;
revoke execute on function public.coach_commit_turn(uuid, text, bigint, uuid, text, text) from public, anon;
grant execute on function public.coach_commit_turn(uuid, text, bigint, uuid, text, text) to authenticated;

-- 3. Rate limits per user and bucket. The table is reachable only through check_rate (security definer).
create table if not exists public.rate_events (
  user_id uuid not null references auth.users (id) on delete cascade,
  bucket text not null check (char_length(bucket) between 1 and 40),
  at timestamptz not null default now()
);
create index if not exists rate_events_lookup on public.rate_events (user_id, bucket, at desc);
alter table public.rate_events enable row level security;
revoke all on public.rate_events from anon, authenticated;

-- True and records the event when the caller is under the bucket's limit; false when over the limit.
-- The limits live here, not in the caller: check_rate is reachable through the API, so a caller-chosen window or limit
-- would let anyone reset their own limit. p_limit and p_window stay in the signature for the Edge Functions
-- (supabase/functions/_shared/rate.ts, which must list the same values) and are ignored. Unknown buckets are refused,
-- so the table cannot be filled with made-up buckets. Values are provisional, set by the owner.
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
                 ('generate_plan_day', 20, interval '1 day')) as v (bucket, lim, win)
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

-- 4. In-app feedback: at most 5 messages per user per day.
create or replace function public.limit_app_feedback() returns trigger
language plpgsql security definer set search_path = ''
as $$
begin
  if (select count(*) from public.app_feedback f where f.user_id = new.user_id and f.created_at > now() - interval '1 day') >= 5 then
    raise exception 'too many feedback messages today' using errcode = 'P0001';
  end if;
  return new;
end;
$$;
revoke execute on function public.limit_app_feedback() from public, anon, authenticated;
drop trigger if exists app_feedback_limit on public.app_feedback;
create trigger app_feedback_limit before insert on public.app_feedback for each row execute function public.limit_app_feedback();

-- 5. Level lock: the app may record self-assessed levels 0 to 3 only. Levels 4 and 5 need a tested pass, which has
--    no server path yet, so no client write can set them.
drop policy if exists "own levels" on public.goal_levels;
drop policy if exists "read own levels" on public.goal_levels;
create policy "read own levels" on public.goal_levels for select to authenticated using ((select auth.uid()) = user_id);
drop policy if exists "delete own levels" on public.goal_levels;
create policy "delete own levels" on public.goal_levels for delete to authenticated using ((select auth.uid()) = user_id);
drop policy if exists "add own self-assessed levels" on public.goal_levels;
create policy "add own self-assessed levels" on public.goal_levels for insert to authenticated
  with check ((select auth.uid()) = user_id and level between 0 and 3);
drop policy if exists "change own self-assessed levels" on public.goal_levels;
create policy "change own self-assessed levels" on public.goal_levels for update to authenticated
  using ((select auth.uid()) = user_id) with check ((select auth.uid()) = user_id and level between 0 and 3);

-- 6. Website contact form (anonymous): the form has a honeypot, but the table took unlimited inserts. Cap repeats from one
--    address (3 a day) and the total (200 a day) so a flood cannot fill the table. The total cap can block real visitors
--    during an attack; raise it if real traffic needs more.
create or replace function public.limit_contact_messages() returns trigger
language plpgsql security definer set search_path = ''
as $$
begin
  if (select count(*) from public.contact_messages c
      where lower(c.email) = lower(new.email) and c.created_at > now() - interval '1 day') >= 3 then
    raise exception 'too many messages from this address today' using errcode = 'P0001';
  end if;
  if (select count(*) from public.contact_messages c where c.created_at > now() - interval '1 day') >= 200 then
    raise exception 'contact form is busy, try again tomorrow' using errcode = 'P0001';
  end if;
  return new;
end;
$$;
revoke execute on function public.limit_contact_messages() from public, anon, authenticated;
drop trigger if exists contact_messages_limit on public.contact_messages;
create trigger contact_messages_limit before insert on public.contact_messages for each row execute function public.limit_contact_messages();
create index if not exists contact_messages_created_at on public.contact_messages (created_at);
