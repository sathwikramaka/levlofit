-- pgTAP tests for 20261029200000_plan_changes.sql.
-- Run locally: supabase test db (throwaway stack).
begin;
create extension if not exists pgtap with schema extensions;
select plan(9);

insert into auth.users (id, email) values
  ('00000000-0000-0000-0000-00000000ee01', 'e1@test.local'),
  ('00000000-0000-0000-0000-00000000ee02', 'e2@test.local');
insert into public.plan_changes (user_id, field, value, from_value) values
  ('00000000-0000-0000-0000-00000000ee01', 'diet_pace', 'easy', 'balanced'),
  ('00000000-0000-0000-0000-00000000ee02', 'weight_goal', 'maintain', 'cut');

select throws_ok($$ insert into public.plan_changes (user_id, field, value) values ('00000000-0000-0000-0000-00000000ee01', 'energy_kcal', '1200') $$, '23514', null, 'calorie targets are not a plan change');
select throws_ok($$ insert into public.plan_changes (user_id, field, value) values ('00000000-0000-0000-0000-00000000ee01', 'days_per_week', '9') $$, '23514', null, 'days outside 1 to 7 are refused');
select throws_ok($$ insert into public.plan_changes (user_id, field, value) values ('00000000-0000-0000-0000-00000000ee01', 'weight_goal', 'crash') $$, '23514', null, 'an unknown body goal is refused');
select throws_ok($$ update public.plan_changes set status = 'confirmed' where field = 'diet_pace' $$, '23514', null, 'confirmed needs confirmed_at');

set local role authenticated;
select set_config('request.jwt.claims', '{"sub":"00000000-0000-0000-0000-00000000ee01","role":"authenticated"}', true);

select is((select count(*)::int from public.plan_changes), 1, 'the owner sees only their own proposals');
select throws_ok($$ insert into public.plan_changes (user_id, field, value) values ('00000000-0000-0000-0000-00000000ee01', 'diet_pace', 'hard') $$, '42501', null, 'the app cannot write a proposal');
select throws_ok($$ update public.plan_changes set status = 'confirmed', confirmed_at = now() $$, '42501', null, 'the app cannot confirm a proposal');
select lives_ok($$ delete from public.plan_changes $$, 'the owner can dismiss their proposal');

reset role;
select is((select count(*)::int from public.plan_changes), 1, 'only the owner''s row was deleted');

select * from finish();
rollback;
