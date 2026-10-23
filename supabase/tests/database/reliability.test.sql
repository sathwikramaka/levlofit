-- pgTAP tests for migration 20261013100000_reliability_and_limits.sql.
-- Run locally: supabase start && supabase db reset && supabase test db
-- Run locally 2026-10-13 (Docker): all pass.
begin;
create extension if not exists pgtap with schema extensions;
select plan(17);

-- Two users in auth.users (the local stack allows inserting test users directly).
insert into auth.users (id, email) values
  ('00000000-0000-0000-0000-00000000aaaa', 'a@test.local'),
  ('00000000-0000-0000-0000-00000000bbbb', 'b@test.local');

-- Act as user A.
set local role authenticated;
select set_config('request.jwt.claims', '{"sub":"00000000-0000-0000-0000-00000000aaaa","role":"authenticated"}', true);

-- Level lock
select lives_ok($$ insert into public.goal_levels (goal, level) values ('strength', 3) $$, 'a self-assessed level up to 3 can be saved');
select throws_ok($$ update public.goal_levels set level = 4 where goal = 'strength' $$, '42501', null, 'a client cannot set level 4');
select throws_ok($$ insert into public.goal_levels (goal, level) values ('running', 5) $$, '42501', null, 'a client cannot insert level 5');

-- One transactional turn
select is((select count(*)::int from public.coach_commit_turn(null, 'First', null, '11111111-1111-1111-1111-111111111111', 'hi', 'hello')), 1,
  'a first message opens a thread and stores the pair');
select is((select count(*)::int from public.coach_messages), 2, 'two messages stored');
select is((select duplicate from public.coach_commit_turn(null, 'First', null, '11111111-1111-1111-1111-111111111111', 'hi', 'second draft')), true,
  'the same client id is reported as a duplicate');
select is((select count(*)::int from public.coach_messages), 2, 'a duplicate stores nothing');

-- Rate limits: the database owns the limits (generate_plan_day: 20 a day); the caller's limit and window are ignored.
select is((select count(*)::int from generate_series(1, 20) where public.check_rate('generate_plan_day', 20, interval '1 day')), 20,
  'twenty plan rebuilds a day are allowed');
select is(public.check_rate('generate_plan_day', 20, interval '1 day'), false, 'the 21st is over the limit');
select is(public.check_rate('generate_plan_day', 100000, interval '1 day'), false, 'a caller-chosen higher limit is ignored');
-- 30 chat messages in the last hour, sent earlier (seeded as the table owner: users cannot write events, and inside
-- one test transaction now() never moves, so the old events must be backdated to test the window).
reset role;
insert into public.rate_events (user_id, bucket, at)
  select '00000000-0000-0000-0000-00000000aaaa', 'coach_chat_hour', now() - interval '10 minutes' from generate_series(1, 30);
set local role authenticated;
select is(public.check_rate('coach_chat_hour', 30, interval '1 second'), false, 'a caller-chosen short window cannot reset the limit');
select throws_ok($$ select public.check_rate('made_up_bucket', 1, interval '1 hour') $$, '22023', null, 'an unknown bucket is refused');
select throws_ok($$ select * from public.rate_events $$, '42501', null, 'rate events are not readable by users');

-- Another user cannot write into A's thread (A's thread id is captured before switching, since B cannot see it).
select set_config('test.thread_a', (select id::text from public.coach_threads limit 1), true);
select set_config('request.jwt.claims', '{"sub":"00000000-0000-0000-0000-00000000bbbb","role":"authenticated"}', true);
select throws_ok(
  format($$ select * from public.coach_commit_turn(%L, 't', null, null, 'x', 'y') $$, current_setting('test.thread_a')),
  'P0002', null, 'a thread that is not yours is not found');

-- Contact form (anonymous): 3 messages a day per address.
reset role;
set local role anon;
select lives_ok($$ insert into public.contact_messages (email, message) values ('v@test.local', 'hello there one'), ('v@test.local', 'hello there two'), ('V@test.local', 'hello there three') $$,
  'an anonymous visitor can send up to 3 messages a day');
select throws_ok($$ insert into public.contact_messages (email, message) values ('v@test.local', 'hello there four') $$, 'P0001', null,
  'a fourth message from the same address is refused');
select lives_ok($$ insert into public.contact_messages (email, message) values ('w@test.local', 'another visitor') $$, 'another address is not affected');

select * from finish();
rollback;
