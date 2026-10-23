-- pgTAP tests for migration 20261016300000_recipes.sql. Run locally: supabase test db
begin;
create extension if not exists pgtap with schema extensions;
select plan(13);

insert into auth.users (id, email) values
  ('00000000-0000-0000-0000-0000000000f1', 'f1@test.local'),
  ('00000000-0000-0000-0000-0000000000f2', 'f2@test.local');

set local role authenticated;
select set_config('request.jwt.claims', '{"sub":"00000000-0000-0000-0000-0000000000f1","role":"authenticated"}', true);

select lives_ok($$ select public.save_recipe('Dal rice', 2, '[{"food_code":"A013","grams":150},{"food_code":"B001","grams":100}]') $$, 'a recipe saves with its ingredients');
select is((select count(*)::int from public.recipe_items), 2, 'both ingredients are stored');
select is((select user_id::text from public.recipes), '00000000-0000-0000-0000-0000000000f1', 'the recipe belongs to the caller');
select throws_ok($$ select public.save_recipe('Empty', 1, '[]') $$, '22023', null, 'a recipe needs an ingredient');
select throws_ok($$ select public.save_recipe('Bad food', 1, '[{"food_code":"A013","grams":100},{"food_code":"NOPE","grams":100}]') $$, '23503', null, 'an unknown food is refused');
select is((select count(*)::int from public.recipes where name = 'Bad food'), 0, 'a failed save leaves no half recipe');
select throws_ok($$ select public.save_recipe('Too much', 1, '[{"food_code":"A013","grams":2500}]') $$, '23514', null, 'more than 2 kg of one ingredient is refused');
select throws_ok($$ select public.save_recipe('   ', 1, '[{"food_code":"A013","grams":100}]') $$, '23514', null, 'a blank name is refused');
select throws_ok($$ select public.save_recipe('Party', 21, '[{"food_code":"A013","grams":100}]') $$, '23514', null, 'more than 20 servings is refused');
select throws_ok($$ select public.save_recipe('Long', 1, (select jsonb_agg(jsonb_build_object('food_code','A013','grams',10)) from generate_series(1, 31))) $$,
  'P0001', null, 'more than 30 ingredients is refused');

reset role;
select set_config('t.rid', (select id::text from public.recipes limit 1), true);
set local role authenticated;
select set_config('request.jwt.claims', '{"sub":"00000000-0000-0000-0000-0000000000f2","role":"authenticated"}', true);
select is((select count(*)::int from public.recipes) + (select count(*)::int from public.recipe_items), 0, 'another user sees none of them');
select throws_ok($$ insert into public.recipe_items (recipe_id, food_code, grams) values (current_setting('t.rid')::uuid, 'A013', 10) $$,
  '42501', null, 'another user cannot add to the recipe even knowing its id');
reset role;
select is((select count(*)::int from public.recipes where user_id = '00000000-0000-0000-0000-0000000000f1'), 1, 'only the one valid recipe was saved');

select * from finish();
rollback;
