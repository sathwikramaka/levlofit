-- pgTAP tests for 20261029100000_plate_conditions_account.sql.
-- Run locally: supabase test db (throwaway stack).
begin;
create extension if not exists pgtap with schema extensions;
select plan(9);

insert into auth.users (id, email) values
  ('00000000-0000-0000-0000-00000000dd01', 'd1@test.local'),
  ('00000000-0000-0000-0000-00000000dd02', 'd2@test.local');
insert into public.dietary_profiles (user_id, diet_type) values
  ('00000000-0000-0000-0000-00000000dd01', 'vegetarian'),
  ('00000000-0000-0000-0000-00000000dd02', 'vegan');

select is((select health_conditions from public.dietary_profiles where user_id = '00000000-0000-0000-0000-00000000dd01'), '{}'::text[], 'conditions default to none');
select is((select whey_scoops::int from public.dietary_profiles where user_id = '00000000-0000-0000-0000-00000000dd01'), 0, 'scoops default to 0');

set local role authenticated;
select set_config('request.jwt.claims', '{"sub":"00000000-0000-0000-0000-00000000dd01","role":"authenticated"}', true);

select lives_ok($$ update public.dietary_profiles set health_conditions = '{kidney,pregnancy}', whey_scoops = 2 $$, 'the owner can save conditions and scoops');
select is((select whey_scoops::int from public.dietary_profiles), 2, 'the owner reads them back');
select throws_ok($$ update public.dietary_profiles set health_conditions = '{cancer}' $$, '23514', null, 'an unknown condition is refused');
select throws_ok($$ update public.dietary_profiles set whey_scoops = 4 $$, '23514', null, 'more than 3 scoops is refused');
select is((select count(*)::int from public.dietary_profiles), 1, 'another person''s row is not visible');
update public.dietary_profiles set whey_scoops = 3 where user_id = '00000000-0000-0000-0000-00000000dd02';

reset role;
select is((select whey_scoops::int from public.dietary_profiles where user_id = '00000000-0000-0000-0000-00000000dd02'), 0, 'another person''s row cannot be changed');

set local role anon;
select throws_ok($$ select health_conditions from public.dietary_profiles $$, '42501', null, 'anon cannot read conditions');

select * from finish();
rollback;
