-- pgTAP tests for 20261029300000_cooking_and_schedule.sql.
-- Run locally: supabase test db (throwaway stack).
begin;
create extension if not exists pgtap with schema extensions;
select plan(11);

insert into auth.users (id, email) values
  ('00000000-0000-0000-0000-00000000ff01', 'f1@test.local'),
  ('00000000-0000-0000-0000-00000000ff02', 'f2@test.local');
insert into public.dietary_profiles (user_id, diet_type) values
  ('00000000-0000-0000-0000-00000000ff01', 'vegetarian'), ('00000000-0000-0000-0000-00000000ff02', 'vegan');

select is((select kitchen || '/' || cook_time from public.dietary_profiles where user_id = '00000000-0000-0000-0000-00000000ff01'), 'full/plenty', 'kitchen and cook time default to today''s planner');
select is((select training_time from public.profiles where id = '00000000-0000-0000-0000-00000000ff01'), 'varies', 'training time defaults to varies');
select is((select training_days from public.profiles where id = '00000000-0000-0000-0000-00000000ff01'), '{}'::smallint[], 'no preferred days by default');

set local role authenticated;
select set_config('request.jwt.claims', '{"sub":"00000000-0000-0000-0000-00000000ff01","role":"authenticated"}', true);

select lives_ok($$ update public.dietary_profiles set kitchen = 'no_stove', cook_time = 'short' $$, 'the owner can save a kitchen and cook time');
select lives_ok($$ update public.profiles set training_days = '{1,3,5}', training_time = 'evening' where id = '00000000-0000-0000-0000-00000000ff01' $$, 'the owner can save training days and time');
select is((select training_days from public.profiles where id = '00000000-0000-0000-0000-00000000ff01'), '{1,3,5}'::smallint[], 'days are read back');
select throws_ok($$ update public.dietary_profiles set kitchen = 'campfire' $$, '23514', null, 'an unknown kitchen is refused');
select throws_ok($$ update public.profiles set training_days = '{0,8}' where id = '00000000-0000-0000-0000-00000000ff01' $$, '23514', null, 'weekdays outside 1 to 7 are refused');
select throws_ok($$ update public.profiles set training_time = 'whenever' where id = '00000000-0000-0000-0000-00000000ff01' $$, '23514', null, 'an unknown time is refused');
update public.profiles set training_time = 'night' where id = '00000000-0000-0000-0000-00000000ff02';

reset role;
select is((select training_time from public.profiles where id = '00000000-0000-0000-0000-00000000ff02'), 'varies', 'another person''s profile cannot be changed');
select is((select kitchen from public.dietary_profiles where user_id = '00000000-0000-0000-0000-00000000ff02'), 'full', 'another person''s kitchen is unchanged');

select * from finish();
rollback;
