-- pgTAP tests for migration 20261024100000_exercise_swaps.sql: swaps are written by the server only, owner-only.
-- Run on a throwaway local stack: supabase test db --local --workdir <copy>
begin;
create extension if not exists pgtap with schema extensions;
select plan(13);

insert into auth.users (id, email) values
  ('00000000-0000-0000-0000-00000000aaaa', 'a@test.local'),
  ('00000000-0000-0000-0000-00000000bbbb', 'b@test.local');
-- Synthetic catalogue rows (the real catalogue lives only in the cloud project).
insert into public.exercises (id, name, gif_url, equipment, target_muscles) values
  ('tstSqat', 'test squat', 'https://example.invalid/a.gif', '{body weight}', '{quads}'),
  ('tstSplt', 'test split squat', 'https://example.invalid/b.gif', '{body weight}', '{quads}'),
  ('tstPush', 'test push-up', 'https://example.invalid/c.gif', '{body weight}', '{pectorals}');

-- The server (service role, as coach-chat writes) stores a proposal for A.
insert into public.exercise_swaps (user_id, day, from_exercise, to_exercise)
  values ('00000000-0000-0000-0000-00000000aaaa', '2026-10-24', 'tstSqat', 'tstSplt');
select is((select status from public.exercise_swaps), 'proposed', 'a new swap starts as a proposal');
select throws_ok($$ insert into public.exercise_swaps (user_id, day, from_exercise, to_exercise) values ('00000000-0000-0000-0000-00000000aaaa', '2026-10-24', 'tstSqat', 'tstSqat') $$,
  '23514', null, 'a move cannot be swapped for itself');
select throws_ok($$ insert into public.exercise_swaps (user_id, day, from_exercise, to_exercise) values ('00000000-0000-0000-0000-00000000aaaa', '2026-10-24', 'tstSqat', 'noSuchX') $$,
  '23503', null, 'only catalogue moves');
select throws_ok($$ insert into public.exercise_swaps (user_id, day, from_exercise, to_exercise, status) values ('00000000-0000-0000-0000-00000000aaaa', '2026-10-24', 'tstSqat', 'tstPush', 'confirmed') $$,
  '23514', null, 'confirmed needs a confirmation time');

-- A, through the app.
set local role authenticated;
select set_config('request.jwt.claims', '{"sub":"00000000-0000-0000-0000-00000000aaaa","role":"authenticated"}', true);
select is((select count(*)::int from public.exercise_swaps), 1, 'the owner sees the proposal');
select throws_ok($$ insert into public.exercise_swaps (user_id, day, from_exercise, to_exercise) values ('00000000-0000-0000-0000-00000000aaaa', '2026-10-24', 'tstPush', 'tstSqat') $$,
  '42501', null, 'the app cannot insert a swap (no skipping the checks)');
select throws_ok($$ update public.exercise_swaps set status = 'confirmed', confirmed_at = now() $$,
  '42501', null, 'the app cannot confirm a swap itself');
select throws_ok($$ update public.exercise_swaps set to_exercise = 'tstPush' $$,
  '42501', null, 'the app cannot change the replacement');

-- B sees and deletes nothing of A's.
select set_config('request.jwt.claims', '{"sub":"00000000-0000-0000-0000-00000000bbbb","role":"authenticated"}', true);
select is((select count(*)::int from public.exercise_swaps), 0, 'another user sees no swap');
delete from public.exercise_swaps;
select set_config('request.jwt.claims', '{"sub":"00000000-0000-0000-0000-00000000aaaa","role":"authenticated"}', true);
select is((select count(*)::int from public.exercise_swaps), 1, 'another user cannot delete it');
-- Not now: the owner deletes the proposal.
delete from public.exercise_swaps;
select is((select count(*)::int from public.exercise_swaps), 0, 'the owner can dismiss it');

set local role anon;
select throws_ok($$ select * from public.exercise_swaps $$, '42501', null, 'anon cannot read swaps');

-- delete-account deletes the auth user; every swap of that user goes with it.
reset role;
insert into public.exercise_swaps (user_id, day, from_exercise, to_exercise, status, confirmed_at)
  values ('00000000-0000-0000-0000-00000000aaaa', '2026-10-24', 'tstSqat', 'tstSplt', 'confirmed', now());
delete from auth.users where id = '00000000-0000-0000-0000-00000000aaaa';
select is((select count(*)::int from public.exercise_swaps), 0, 'account deletion removes the swaps');

select * from finish();
rollback;
