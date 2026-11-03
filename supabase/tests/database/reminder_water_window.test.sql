-- pgTAP tests for 20261103400000_reminder_water_window.sql.
-- Run locally: supabase test db (throwaway stack).
begin;
create extension if not exists pgtap with schema extensions;
select plan(5);

insert into auth.users (id, email) values ('00000000-0000-0000-0000-0000000000f1', 'r1@test.local');
set local role authenticated;
select set_config('request.jwt.claims', '{"sub":"00000000-0000-0000-0000-0000000000f1","role":"authenticated"}', true);

select lives_ok($$ insert into public.reminder_prefs (enabled, water_every_h, water_from, water_to) values (true, 2, 7, 22) $$, 'the owner saves a water window');
select lives_ok($$ update public.reminder_prefs set water_from = null, water_to = null $$, 'clearing both returns to the default window');
select throws_ok($$ update public.reminder_prefs set water_from = 3, water_to = 22 $$, '23514', null, 'a window starting at night is refused');
select throws_ok($$ update public.reminder_prefs set water_from = 8, water_to = null $$, '23514', null, 'half a window is refused');
select is((select water_from from public.reminder_prefs), null::smallint, 'the refused changes left nothing behind');
reset role;

select * from finish();
rollback;
