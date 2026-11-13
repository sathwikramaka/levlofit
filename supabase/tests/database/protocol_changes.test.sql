-- pgTAP tests for 20261114100000_protocol_changes.sql.
-- Run locally: supabase test db (throwaway stack).
begin;
create extension if not exists pgtap with schema extensions;
select plan(7);

insert into auth.users (id, email) values ('00000000-0000-0000-0000-00000000ef01', 'f1@test.local');
insert into public.dietary_profiles (user_id, diet_type) values ('00000000-0000-0000-0000-00000000ef01', 'vegetarian');

select lives_ok($$ insert into public.plan_changes (user_id, field, value) values ('00000000-0000-0000-0000-00000000ef01', 'protein_powder', 'yeast') $$, 'a protein powder change can be proposed');
select lives_ok($$ insert into public.plan_changes (user_id, field, value) values ('00000000-0000-0000-0000-00000000ef01', 'supplement_add', 'vitamin_d') $$, 'a supplement can be proposed');
select throws_ok($$ insert into public.plan_changes (user_id, field, value) values ('00000000-0000-0000-0000-00000000ef01', 'energy_kcal', '1200') $$, '23514', null, 'calorie targets are still not a change');
select throws_ok($$ insert into public.plan_changes (user_id, field, value) values ('00000000-0000-0000-0000-00000000ef01', 'cook_time', 'Drop Table') $$, '23514', null, 'a value is a short plain token');
select throws_ok($$ insert into public.plan_changes (user_id, field, value) values ('00000000-0000-0000-0000-00000000ef01', 'days_per_week', '9') $$, '23514', null, 'the older value checks still hold');
select lives_ok($$ update public.dietary_profiles set protein_powder = 'yeast' where user_id = '00000000-0000-0000-0000-00000000ef01' $$, 'the powder kind is stored');
select throws_ok($$ update public.dietary_profiles set protein_powder = 'beef' where user_id = '00000000-0000-0000-0000-00000000ef01' $$, '23514', null, 'an unknown powder kind is refused');

select * from finish();
rollback;
