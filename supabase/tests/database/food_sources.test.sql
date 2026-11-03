-- Food licence gate: app roles see only foods whose source is release_allowed; sources are read-only; every food
-- names a known source. Independent of the local seed: each case sets the flag itself, inside this transaction.
begin;
select plan(15);

select is((select count(*) from public.foods where source is null)::int, 0, 'every food names its source');
select is((select release_allowed from public.food_sources where source = 'usda_fdc'), true, 'FoodData Central (CC0) is allowed');
select is((select source || ':' || source_ref from public.foods where code = 'X001'), 'usda_fdc:174275', 'soya chunks keep their FDC provenance, so they stay visible');
select ok((select licence from public.food_sources where source = 'ifct2017') ~ 'No licence grant', 'IFCT records the missing licence grant');

select is((select count(*) from public.foods where source = 'usda_fdc' and code like 'FDC%')::int, 34, 'the 34 USDA planner foods are loaded (28, then 6 breakfast foods on 2026-11-03)');
select is((select string_agg(name, ', ' order by code) from public.foods where code in ('FDC173904', 'FDC174648', 'FDC169076', 'FDC170688', 'FDC168933', 'FDC174288')),
  'Rava (semolina), Muesli, Daliya (broken wheat), Rolled oats, Besan (gram flour), Corn flakes', 'oats, corn flakes, muesli, daliya, rava and besan come from USDA');
select is((select count(*) from public.foods where code in ('FDC174648', 'FDC169076', 'FDC170688', 'FDC174288') and source_note is null)::int, 0, 'every close match carries its disclosure');
select is((select carb_g from public.foods where code = 'X001'), 16.42::numeric, 'soya chunks corrected to available carbohydrate, as their FDC row');
select is((select count(*) from public.foods where source = 'usda_fdc' and (kcal < 0 or protein_g < 0 or fat_g < 0 or carb_g < 0 or fiber_g < 0))::int, 0, 'no negative USDA values');

update public.food_sources set release_allowed = false where source = 'ifct2017';
set local role authenticated;
select is((select count(*) from public.foods where source = 'ifct2017')::int, 0, 'IFCT rows are hidden from signed-in people while not allowed');
select is((select count(*) from public.foods where source = 'usda_fdc')::int, 35, 'the USDA rows (34 planner foods and soya chunks X001) stay visible');
select throws_ok($$update public.food_sources set release_allowed = true where source = 'ifct2017'$$, '42501', null, 'app roles cannot open a source');
reset role;
set local role anon;
select is((select count(*) from public.foods where source = 'ifct2017')::int, 0, 'and from signed-out visitors');
reset role;

update public.food_sources set release_allowed = true where source = 'ifct2017';
set local role authenticated;
select ok((select count(*) from public.foods where source = 'ifct2017') > 500, 'with permission recorded, the rows show again');
reset role;

select throws_ok($$insert into public.foods (code, name, food_group, source) values ('ZZ1', 'x', 'x', 'nowhere')$$, '23503', null, 'a food needs a known source');

select * from finish();
rollback;
