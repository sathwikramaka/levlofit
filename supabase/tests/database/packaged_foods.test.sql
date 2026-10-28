-- pgTAP tests for 20261029700000_packaged_foods.sql. Run locally: supabase test db (throwaway stack).
begin;
create extension if not exists pgtap with schema extensions;
select plan(9);

insert into auth.users (id, email) values
  ('00000000-0000-0000-0000-0000000000a1', 'a1@test.local'),
  ('00000000-0000-0000-0000-0000000000b2', 'b2@test.local');

set local role authenticated;
select set_config('request.jwt.claims', '{"sub":"00000000-0000-0000-0000-0000000000a1","role":"authenticated"}', true);

select lives_ok($$ insert into public.packaged_foods (barcode, name, brand, kcal, protein_g, fat_g, carb_g, source, source_date)
  values ('8901058000290', 'Masala oats', 'Test', 380, 12, 7, 65, 'open_food_facts', '2026-10-29') $$, 'a person saves a product');
select set_config('test.pkg', (select id::text from public.packaged_foods where barcode = '8901058000290'), true);
select throws_ok($$ insert into public.packaged_foods (barcode, name, kcal, protein_g, fat_g, carb_g, source)
  values ('12ab', 'Bad code', 100, 1, 1, 1, 'label') $$, '23514', null, 'a barcode must be 8 to 14 digits');
select throws_ok($$ insert into public.packaged_foods (name, kcal, protein_g, fat_g, carb_g, source) values ('No protein', 100, null, 1, 1, 'manual') $$,
  '23502', null, 'energy, protein, fat and carbs are required');
select lives_ok($$ insert into public.food_log (day, meal, packaged_food_id, grams) values (current_date, 'breakfast', current_setting('test.pkg')::uuid, 40) $$,
  'the product can be logged');
select throws_ok($$ insert into public.food_log (day, meal, grams) values (current_date, 'breakfast', 40) $$, '23514', null, 'an entry needs a food');

select set_config('request.jwt.claims', '{"sub":"00000000-0000-0000-0000-0000000000b2","role":"authenticated"}', true);
select is((select count(*)::int from public.packaged_foods), 0, 'another person cannot see the product');
select throws_ok($$ insert into public.food_log (day, meal, packaged_food_id, grams) values (current_date, 'lunch', current_setting('test.pkg')::uuid, 40) $$,
  '23503', null, 'another person cannot log the product');

reset role;
set local role anon;
select throws_ok($$ select 1 from public.packaged_foods $$, '42501', null, 'signed out: no access');

reset role;
delete from auth.users where id = '00000000-0000-0000-0000-0000000000a1';
select is((select count(*)::int from public.packaged_foods where user_id = '00000000-0000-0000-0000-0000000000a1'), 0, 'account deletion removes products and their diary rows');

select * from finish();
rollback;
