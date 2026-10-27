-- pgTAP tests for 20261027100000_diet_pace_region.sql and 20261027200000_body_check_rate.sql.
-- Run locally: supabase test db (throwaway stack).
begin;
create extension if not exists pgtap with schema extensions;
select plan(8);

insert into auth.users (id, email) values ('00000000-0000-0000-0000-00000000cccc', 'c@test.local');
insert into public.dietary_profiles (user_id, diet_type) values ('00000000-0000-0000-0000-00000000cccc', 'vegetarian');

select is((select diet_pace from public.dietary_profiles where user_id = '00000000-0000-0000-0000-00000000cccc'), 'balanced', 'pace defaults to balanced');
select is((select cuisine_region from public.dietary_profiles where user_id = '00000000-0000-0000-0000-00000000cccc'), 'any', 'region defaults to any');

set local role authenticated;
select set_config('request.jwt.claims', '{"sub":"00000000-0000-0000-0000-00000000cccc","role":"authenticated"}', true);

select lives_ok($$ update public.dietary_profiles set diet_pace = 'hard', cuisine_region = 'south' $$, 'the owner can set pace and region');
select throws_ok($$ update public.dietary_profiles set diet_pace = 'extreme' $$, '23514', null, 'an unknown pace is refused');
select throws_ok($$ update public.dietary_profiles set cuisine_region = 'mars' $$, '23514', null, 'an unknown region is refused');

-- Body check: 3 a day, owned by the database.
select is((select count(*)::int from generate_series(1, 3) where public.check_rate('body_check_day', 3, interval '1 day')), 3, 'three body checks pass');
select is(public.check_rate('body_check_day', 100, interval '1 day'), false, 'the fourth is refused, whatever limit the caller sends');
select ok(public.check_rate('generate_plan_day', 20, interval '1 day'), 'existing buckets still work');

select * from finish();
rollback;
