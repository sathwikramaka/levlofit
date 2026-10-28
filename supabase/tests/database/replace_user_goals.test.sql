-- pgTAP tests for 20261029400000_replace_user_goals.sql.
-- Run locally: supabase test db (throwaway stack).
begin;
create extension if not exists pgtap with schema extensions;
select plan(8);

insert into auth.users (id, email) values
  ('00000000-0000-0000-0000-0000000000b1', 'g1@test.local'),
  ('00000000-0000-0000-0000-0000000000b2', 'g2@test.local');
insert into public.user_goals (user_id, goal, experience, priority) values
  ('00000000-0000-0000-0000-0000000000b1', 'strength', 'beginner', 1),
  ('00000000-0000-0000-0000-0000000000b1', 'running', 'none', 2),
  ('00000000-0000-0000-0000-0000000000b2', 'yoga', 'advanced', 1);

set local role authenticated;
select set_config('request.jwt.claims', '{"sub":"00000000-0000-0000-0000-0000000000b1","role":"authenticated"}', true);

select lives_ok($$ select public.replace_user_goals('[{"goal":"running","experience":"intermediate"},{"goal":"mobility","experience":"none"}]') $$, 'the owner replaces their goals');
select results_eq($$ select goal, experience, priority::int from public.user_goals order by priority $$,
  $$ values ('running', 'intermediate', 1), ('mobility', 'none', 2) $$, 'new list stored in order, main goal first');

-- A bad list fails as a whole: the goals from before it stay.
select throws_ok($$ select public.replace_user_goals('[{"goal":"strength","experience":"beginner"},{"goal":"not_a_goal","experience":"none"}]') $$, '23503', null, 'an unknown goal is refused');
select is((select string_agg(goal, ',' order by priority) from public.user_goals), 'running,mobility', 'a failed replace leaves the previous goals');
select throws_ok($$ select public.replace_user_goals('[]') $$, '22023', null, 'an empty list is refused, never zero goals');
select throws_ok($$ select public.replace_user_goals('[{"goal":"yoga","experience":"guru"}]') $$, '23514', null, 'a bad experience is refused');

reset role;
select is((select goal from public.user_goals where user_id = '00000000-0000-0000-0000-0000000000b2'), 'yoga', 'another person''s goals are untouched');

set local role anon;
select throws_ok($$ select public.replace_user_goals('[{"goal":"yoga","experience":"none"}]') $$, '42501', null, 'anon cannot call it');

select * from finish();
rollback;
