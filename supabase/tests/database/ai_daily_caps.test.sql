-- pgTAP tests for 20261102100000_ai_daily_caps.sql. Run locally: supabase test db (throwaway stack).
begin;
create extension if not exists pgtap with schema extensions;
select plan(9);

insert into auth.users (id, email) values
  ('00000000-0000-0000-0000-00000000ca01', 'cap1@test.local'),
  ('00000000-0000-0000-0000-00000000ca02', 'cap2@test.local');
insert into public.ai_daily_caps (bucket, per_day) values ('body_check_day', 4), ('generate_plan_day', 0);

select throws_ok($$ insert into public.ai_daily_caps (bucket, per_day) values ('made_up', 1) $$, '23514', null, 'only known buckets can be capped');

set local role authenticated;
select set_config('request.jwt.claims', '{"sub":"00000000-0000-0000-0000-00000000ca01","role":"authenticated"}', true);
select throws_ok($$ select * from public.ai_daily_caps $$, '42501', null, 'users cannot read the caps');
select throws_ok($$ update public.ai_daily_caps set per_day = 1000 $$, '42501', null, 'users cannot raise the caps');

select is((select count(*)::int from generate_series(1, 3) where public.check_rate('body_check_day', 3, interval '1 day')), 3, 'user 1 uses their 3 body checks');
select is(public.check_rate('body_check_day', 3, interval '1 day'), false, 'their own limit still answers false');

select set_config('request.jwt.claims', '{"sub":"00000000-0000-0000-0000-00000000ca02","role":"authenticated"}', true);
select ok(public.check_rate('body_check_day', 3, interval '1 day'), 'user 2 gets the 4th app-wide check');
select throws_ok($$ select public.check_rate('body_check_day', 3, interval '1 day') $$, 'P0001', 'ai_daily_cap', 'the 5th app-wide check hits the daily cap, though user 2 is under their own limit');
select throws_ok($$ select public.check_rate('generate_plan_day', 20, interval '1 day') $$, 'P0001', 'ai_daily_cap', 'a cap of 0 stops the bucket (kill switch)');
select ok(public.check_rate('coach_chat_hour', 30, interval '1 hour'), 'uncapped buckets work as before');

select * from finish();
rollback;
