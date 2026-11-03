-- pgTAP tests for 20261103300000_daily_checkins.sql.
-- Run locally: supabase test db (throwaway stack).
begin;
create extension if not exists pgtap with schema extensions;
select plan(10);

insert into auth.users (id, email) values
  ('00000000-0000-0000-0000-0000000000d1', 'c1@test.local'),
  ('00000000-0000-0000-0000-0000000000d2', 'c2@test.local');

set local role authenticated;
select set_config('request.jwt.claims', '{"sub":"00000000-0000-0000-0000-0000000000d1","role":"authenticated"}', true);

select lives_ok($$ insert into public.daily_checkins (day, energy) values ('2026-11-03', 4) $$, 'a check-in with one answer is saved');
select lives_ok($$ insert into public.daily_checkins (day, workout, food, sleep, soreness, note) values ('2026-11-03', 'done', 'partly', 3, 1, 'ok')
  on conflict (user_id, day) do update set workout = excluded.workout, food = excluded.food, sleep = excluded.sleep,
  soreness = excluded.soreness, note = excluded.note, updated_at = now() $$, 'the same day is edited, not duplicated');
select results_eq($$ select energy::int, workout, food, sleep::int, soreness::int from public.daily_checkins $$,
  $$ values (4, 'done', 'partly', 3, 1) $$, 'edit keeps earlier answers and adds the new ones');
select throws_ok($$ insert into public.daily_checkins (day, energy) values ('2026-11-04', 6) $$, '23514', null, 'energy above 5 is refused');
select throws_ok($$ insert into public.daily_checkins (day, workout) values ('2026-11-04', 'maybe') $$, '23514', null, 'an unknown workout answer is refused');
select throws_ok($$ insert into public.daily_checkins (day, note) values ('2026-11-04', repeat('x', 501)) $$, '23514', null, 'a note over 500 characters is refused');
select throws_ok($$ insert into public.daily_checkins (user_id, day) values ('00000000-0000-0000-0000-0000000000d2', '2026-11-04') $$,
  '42501', null, 'nobody can write a check-in for someone else');

select set_config('request.jwt.claims', '{"sub":"00000000-0000-0000-0000-0000000000d2","role":"authenticated"}', true);
select is((select count(*)::int from public.daily_checkins), 0, 'another person cannot read the check-ins');
delete from public.daily_checkins;

reset role;
select is((select count(*)::int from public.daily_checkins), 1, 'another person''s delete removes nothing');
set local role anon;
select throws_ok($$ select * from public.daily_checkins $$, '42501', null, 'anon has no access');
reset role;

select * from finish();
rollback;
