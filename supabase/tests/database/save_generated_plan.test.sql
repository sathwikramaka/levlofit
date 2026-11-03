-- pgTAP tests for 20261103200000_save_generated_plan.sql.
-- Run locally: supabase test db (throwaway stack).
begin;
create extension if not exists pgtap with schema extensions;
select plan(9);

insert into auth.users (id, email) values
  ('00000000-0000-0000-0000-0000000000c1', 'p1@test.local'),
  ('00000000-0000-0000-0000-0000000000c2', 'p2@test.local');
insert into public.profiles (id) values ('00000000-0000-0000-0000-0000000000c1'), ('00000000-0000-0000-0000-0000000000c2')
  on conflict (id) do nothing;

-- Users cannot call it: the gate column must only open through generate-plan.
set local role authenticated;
select set_config('request.jwt.claims', '{"sub":"00000000-0000-0000-0000-0000000000c1","role":"authenticated"}', true);
select throws_ok($$ select * from public.save_generated_plan('00000000-0000-0000-0000-0000000000c1', 'e1', '{}', '{}') $$,
  '42501', null, 'a signed-in user cannot call it');
reset role;

set local role service_role;
select is((select reused from public.save_generated_plan('00000000-0000-0000-0000-0000000000c1', 'e1', '{"a":1}', '{"p":1}')),
  false, 'first save stores a new plan');
select is((select onboarding_complete from public.profiles where id = '00000000-0000-0000-0000-0000000000c1'), true,
  'the same transaction opens the dashboard gate');
select is((select reused from public.save_generated_plan('00000000-0000-0000-0000-0000000000c1', 'e1', '{"a":1}', '{"p":1}')),
  true, 'a retry with the same input reuses the stored plan');
select is((select count(*)::int from public.generated_plans where user_id = '00000000-0000-0000-0000-0000000000c1'), 1,
  'no duplicate plan after the retry');
select is((select reused from public.save_generated_plan('00000000-0000-0000-0000-0000000000c1', 'e1', '{"a":2}', '{"p":2}')),
  false, 'changed answers store a new plan');
select is((select count(*)::int from public.generated_plans where user_id = '00000000-0000-0000-0000-0000000000c1'), 2,
  'two plans now, history kept');
select throws_ok($$ select * from public.save_generated_plan('00000000-0000-0000-0000-0000000000c9', 'e1', '{}', '{}') $$,
  'P0002', null, 'no profile: refused, nothing stored');
select is((select count(*)::int from public.generated_plans where user_id = '00000000-0000-0000-0000-0000000000c2'), 0,
  'another person is untouched');
reset role;

select * from finish();
rollback;
