-- pgTAP tests for migration 20261016100000_food_diary.sql. Run locally: supabase test db
begin;
create extension if not exists pgtap with schema extensions;
select plan(16);

insert into auth.users (id, email) values
  ('00000000-0000-0000-0000-0000000000e1', 'e1@test.local'),
  ('00000000-0000-0000-0000-0000000000e2', 'e2@test.local');

set local role authenticated;
select set_config('request.jwt.claims', '{"sub":"00000000-0000-0000-0000-0000000000e1","role":"authenticated"}', true);

select lives_ok($$ insert into public.food_log (day, meal, food_code, grams) values (current_date - 1, 'lunch', 'A013', 150) $$, 'a diary entry can be added');
select is((select user_id::text from public.food_log), '00000000-0000-0000-0000-0000000000e1', 'it belongs to the caller');
select throws_ok($$ insert into public.food_log (day, meal, food_code, grams) values (current_date - 1, 'brunch', 'A013', 100) $$, '23514', null, 'an unknown meal is refused');
select throws_ok($$ insert into public.food_log (day, meal, food_code, grams) values (current_date - 1, 'lunch', 'A013', 0) $$, '23514', null, 'zero grams is refused');
select throws_ok($$ insert into public.food_log (day, meal, food_code, grams) values (current_date - 1, 'lunch', 'A013', 2500) $$, '23514', null, 'more than 2 kg is refused');
select throws_ok($$ insert into public.food_log (day, meal, food_code, grams) values (current_date - 1, 'lunch', 'NOPE', 100) $$, '23503', null, 'a food not in the table is refused');
select throws_ok($$ insert into public.food_log (user_id, day, meal, food_code, grams) values ('00000000-0000-0000-0000-0000000000e2', current_date - 1, 'lunch', 'A013', 100) $$,
  '42501', null, 'an entry cannot be written for someone else');
select lives_ok($$ insert into public.food_log (day, meal, food_code, grams) select current_date, 'snack', 'A013', 10 from generate_series(1, 60) $$, 'up to 60 entries in a day');
select throws_ok($$ insert into public.food_log (day, meal, food_code, grams) values (current_date, 'snack', 'A013', 10) $$, 'P0001', null, 'the 61st entry that day is refused');

select throws_ok($$ insert into public.food_log (day, meal, food_code, grams) values (current_date + 3, 'lunch', 'A013', 100) $$, '22008', null, 'a future day is refused');
select throws_ok($$ insert into public.food_log (day, meal, food_code, grams) select current_date - 1000 - g, 'snack', 'A013', 10 from generate_series(1, 5) g $$, '22008', null,
  'made-up old days cannot spread entries past the daily cap');
select lives_ok($$ update public.food_log set grams = 175, meal = 'dinner' where day = current_date - 1 $$, 'weight and meal can be corrected');
select throws_ok($$ update public.food_log set food_code = 'B001' where day = current_date - 1 $$, '42501', null, 'the food itself cannot be changed (delete and re-add)');
select throws_ok($$ update public.food_log set grams = 0 where day = current_date - 1 $$, '23514', null, 'a corrected weight keeps the same bounds');
select set_config('request.jwt.claims', '{"sub":"00000000-0000-0000-0000-0000000000e2","role":"authenticated"}', true);
select is((select count(*)::int from public.food_log), 0, 'another user sees none of the entries');
delete from public.food_log;
reset role;
select is((select count(*)::int from public.food_log where user_id = '00000000-0000-0000-0000-0000000000e1'), 61, 'another user cannot delete them');

select * from finish();
rollback;
