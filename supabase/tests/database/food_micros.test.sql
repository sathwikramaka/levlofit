-- Micronutrient columns on foods (IFCT 2017): readable by app roles, never writable, no negative values,
-- and a source 0 is stored as null (no value), not as zero.
begin;
select plan(5);

select is((select calcium_mg from public.foods where code = 'A013'), 10.93::numeric, 'brown rice calcium per 100 g as in IFCT 2017');
select is((select count(*) from public.foods where source = 'ifct2017' and (folate_ug = 0 or vitamin_c_mg = 0 or iron_mg = 0))::int, 0, 'no stored IFCT zeros: an IFCT 0 means no value and is null (a USDA 0 is a measured value and stays)');
select throws_ok($$update public.foods set iron_mg = -1 where code = 'A013'$$, '23514', null, 'negative values rejected');

set local role authenticated;
select lives_ok($$select iron_mg, folate_ug from public.foods limit 1$$, 'authenticated can read micronutrients');
select throws_ok($$update public.foods set iron_mg = 1 where code = 'A013'$$, '42501', null, 'authenticated cannot change food values');

select * from finish();
rollback;
