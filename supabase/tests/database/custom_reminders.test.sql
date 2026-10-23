-- pgTAP tests for migration 20261014100000_custom_reminders.sql. Run locally: supabase test db
begin;
create extension if not exists pgtap with schema extensions;
select plan(9);

insert into auth.users (id, email) values
  ('00000000-0000-0000-0000-00000000cccc', 'c@test.local'),
  ('00000000-0000-0000-0000-00000000dddd', 'd@test.local');

set local role authenticated;
select set_config('request.jwt.claims', '{"sub":"00000000-0000-0000-0000-00000000cccc","role":"authenticated"}', true);

select lives_ok($$ insert into public.custom_reminders (name, remind_at, weekdays) values ('Creatine', '08:00', '{1,3,5}') $$, 'a reminder can be created');
select is((select user_id::text from public.custom_reminders), '00000000-0000-0000-0000-00000000cccc', 'it belongs to the caller');
select throws_ok($$ insert into public.custom_reminders (name, remind_at) values ('   ', '08:00') $$, '23514', null, 'a blank name is refused');
select throws_ok($$ insert into public.custom_reminders (name, remind_at, weekdays) values ('x', '08:00', '{0}') $$, '23514', null, 'weekday 0 is refused');
select throws_ok($$ insert into public.custom_reminders (user_id, name, remind_at) values ('00000000-0000-0000-0000-00000000dddd', 'x', '08:00') $$, '42501', null,
  'a reminder cannot be created for someone else');
select lives_ok($$ insert into public.custom_reminders (name, remind_at) select 'r' || g, '09:00' from generate_series(1, 19) g $$, 'up to 20 in total');
select throws_ok($$ insert into public.custom_reminders (name, remind_at) values ('one too many', '09:00') $$, 'P0001', null, 'the 21st is refused');

select set_config('request.jwt.claims', '{"sub":"00000000-0000-0000-0000-00000000dddd","role":"authenticated"}', true);
select is((select count(*)::int from public.custom_reminders), 0, 'another user sees none of them');
update public.custom_reminders set enabled = false;
reset role;
select is((select count(*)::int from public.custom_reminders where not enabled), 0, 'another user cannot switch them off');

select * from finish();
rollback;
