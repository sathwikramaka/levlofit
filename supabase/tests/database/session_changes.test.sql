-- pgTAP tests for migration 20261024200000_session_changes.sql: written by the server only, owner-only.
-- Run on a throwaway local stack: supabase test db --local --workdir <copy>
begin;
create extension if not exists pgtap with schema extensions;
select plan(12);

insert into auth.users (id, email) values
  ('00000000-0000-0000-0000-00000000aaaa', 'a@test.local'),
  ('00000000-0000-0000-0000-00000000bbbb', 'b@test.local');

-- The server (service role) stores a proposal for A.
insert into public.session_changes (user_id, day, kind) values ('00000000-0000-0000-0000-00000000aaaa', '2026-10-24', 'lighter');
select is((select status from public.session_changes), 'proposed', 'a new change starts as a proposal');
select throws_ok($$ insert into public.session_changes (user_id, day, kind, to_day) values ('00000000-0000-0000-0000-00000000aaaa', '2026-10-24', 'lighter', '2026-10-25') $$,
  '23514', null, 'a lighter session has no target day');
select throws_ok($$ insert into public.session_changes (user_id, day, kind) values ('00000000-0000-0000-0000-00000000aaaa', '2026-10-24', 'move') $$,
  '23514', null, 'a move needs a target day');
select throws_ok($$ insert into public.session_changes (user_id, day, kind, to_day) values ('00000000-0000-0000-0000-00000000aaaa', '2026-10-24', 'move', '2026-11-24') $$,
  '23514', null, 'a move stays within the week');
select throws_ok($$ insert into public.session_changes (user_id, day, kind) values ('00000000-0000-0000-0000-00000000aaaa', '2026-10-24', 'deload') $$,
  '23514', null, 'only known kinds');

set local role authenticated;
select set_config('request.jwt.claims', '{"sub":"00000000-0000-0000-0000-00000000aaaa","role":"authenticated"}', true);
select is((select count(*)::int from public.session_changes), 1, 'the owner sees the proposal');
select throws_ok($$ insert into public.session_changes (user_id, day, kind) values ('00000000-0000-0000-0000-00000000aaaa', '2026-10-25', 'lighter') $$,
  '42501', null, 'the app cannot insert a change');
select throws_ok($$ update public.session_changes set status = 'confirmed', confirmed_at = now() $$,
  '42501', null, 'the app cannot confirm a change itself');

select set_config('request.jwt.claims', '{"sub":"00000000-0000-0000-0000-00000000bbbb","role":"authenticated"}', true);
select is((select count(*)::int from public.session_changes), 0, 'another user sees nothing');
select set_config('request.jwt.claims', '{"sub":"00000000-0000-0000-0000-00000000aaaa","role":"authenticated"}', true);
delete from public.session_changes;
select is((select count(*)::int from public.session_changes), 0, 'the owner can dismiss it');

set local role anon;
select throws_ok($$ select * from public.session_changes $$, '42501', null, 'anon cannot read session changes');

-- delete-account deletes the auth user; every session change of that user goes with it.
reset role;
insert into public.session_changes (user_id, day, kind, to_day, status, confirmed_at)
  values ('00000000-0000-0000-0000-00000000aaaa', '2026-10-21', 'move', '2026-10-23', 'confirmed', now());
delete from auth.users where id = '00000000-0000-0000-0000-00000000aaaa';
select is((select count(*)::int from public.session_changes), 0, 'account deletion removes the session changes');

select * from finish();
rollback;
