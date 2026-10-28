-- pgTAP tests for 20261029500000_kitchen_equipment_mess.sql.
-- Run locally: supabase test db (throwaway stack).
begin;
create extension if not exists pgtap with schema extensions;
select plan(9);

insert into auth.users (id, email) values
  ('00000000-0000-0000-0000-0000000000c1', 'k1@test.local'),
  ('00000000-0000-0000-0000-0000000000c2', 'k2@test.local');
insert into public.dietary_profiles (user_id, diet_type, kitchen) values
  ('00000000-0000-0000-0000-0000000000c1', 'vegetarian', 'stove_only'),
  ('00000000-0000-0000-0000-0000000000c2', 'vegan', 'full');

select is((select kitchen_equipment from public.dietary_profiles where user_id = '00000000-0000-0000-0000-0000000000c1'), '{}'::text[], 'equipment unanswered by default');
select is((select kitchen from public.dietary_profiles where user_id = '00000000-0000-0000-0000-0000000000c1'), 'stove_only', 'the older kitchen answer is kept');

set local role authenticated;
select set_config('request.jwt.claims', '{"sub":"00000000-0000-0000-0000-0000000000c1","role":"authenticated"}', true);

select lives_ok($$ update public.dietary_profiles set kitchen_equipment = '{kettle,blender,fridge}', mess_meals = '{lunch,dinner}', kitchen_other = 'shared induction on weekends', cook_time = 'minimal' $$,
  'the owner saves equipment, mess meals, notes and a minimal cooking time');
select is((select mess_meals from public.dietary_profiles), '{lunch,dinner}'::text[], 'mess meals are read back');
select throws_ok($$ update public.dietary_profiles set kitchen_equipment = '{air_fryer}' $$, '23514', null, 'unknown equipment is refused (use kitchen_other)');
select throws_ok($$ update public.dietary_profiles set mess_meals = '{brunch}' $$, '23514', null, 'an unknown meal is refused');
select throws_ok($$ update public.dietary_profiles set kitchen_other = repeat('x', 201) $$, '23514', null, 'notes over 200 characters are refused');
select throws_ok($$ update public.dietary_profiles set cook_time = 'never' $$, '23514', null, 'an unknown cooking time is refused');
update public.dietary_profiles set mess_meals = '{breakfast}' where user_id = '00000000-0000-0000-0000-0000000000c2';

reset role;
select is((select mess_meals from public.dietary_profiles where user_id = '00000000-0000-0000-0000-0000000000c2'), '{}'::text[], 'another person''s row is untouched');

select * from finish();
rollback;
