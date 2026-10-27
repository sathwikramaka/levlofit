-- pgTAP tests for 20261027300000_app_errors.sql. Run locally: supabase test db (throwaway stack).
begin;
create extension if not exists pgtap with schema extensions;
select plan(7);

insert into auth.users (id, email) values
  ('00000000-0000-0000-0000-0000000000e1', 'e1@test.local'),
  ('00000000-0000-0000-0000-0000000000e2', 'e2@test.local');

set local role authenticated;
select set_config('request.jwt.claims', '{"sub":"00000000-0000-0000-0000-0000000000e1","role":"authenticated"}', true);

select lives_ok($$ insert into public.app_errors (app_version, platform, message) values ('1.0.0', 'android', 'boom') $$, 'a user can report an error');
select throws_ok($$ select * from public.app_errors $$, '42501', null, 'users cannot read the log');
select throws_ok($$ insert into public.app_errors (user_id, app_version, platform, message) values ('00000000-0000-0000-0000-0000000000e2', '1.0.0', 'android', 'x') $$,
  '42501', null, 'a user cannot report for someone else');
select throws_ok($$ insert into public.app_errors (app_version, platform, message) values ('1.0.0', 'windows', 'x') $$, '23514', null, 'unknown platform refused');
select lives_ok($$ insert into public.app_errors (app_version, platform, message) select '1.0.0', 'android', 'x' from generate_series(1, 40) $$, 'a burst is accepted without error');

reset role;
select is((select count(*)::int from public.app_errors where user_id = '00000000-0000-0000-0000-0000000000e1'), 30, 'but capped at 30 a day');
set local role anon;
select throws_ok($$ insert into public.app_errors (app_version, platform, message) values ('1.0.0', 'android', 'x') $$, '42501', null, 'signed-out callers cannot write');

select * from finish();
rollback;
