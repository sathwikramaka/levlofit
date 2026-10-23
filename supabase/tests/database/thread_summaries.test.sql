-- pgTAP tests for migration 20261023200000_thread_summaries.sql: a chat's rolling summary, owner-only.
-- Run on a throwaway local stack: supabase test db --local --workdir <copy>
begin;
create extension if not exists pgtap with schema extensions;
select plan(8);

insert into auth.users (id, email) values
  ('00000000-0000-0000-0000-00000000aaaa', 'a@test.local'),
  ('00000000-0000-0000-0000-00000000bbbb', 'b@test.local');
insert into public.coach_threads (id, user_id, title) values
  ('00000000-0000-0000-0000-0000000000a1', '00000000-0000-0000-0000-00000000aaaa', 'A chat');

set local role authenticated;
select set_config('request.jwt.claims', '{"sub":"00000000-0000-0000-0000-00000000aaaa","role":"authenticated"}', true);
update public.coach_threads set summary = 'They play badminton on Saturdays.', summary_upto = 8;
select is((select summary from public.coach_threads), 'They play badminton on Saturdays.', 'the owner can store a summary');
select throws_ok($$ update public.coach_threads set summary = repeat('x', 801) $$, '23514', null, 'summaries over 800 characters are refused');
select throws_ok($$ update public.coach_threads set summary = '' $$, '23514', null, 'an empty summary is refused (null clears it)');
update public.coach_threads set summary = null, summary_upto = null;
select is((select summary from public.coach_threads), null, 'the owner can clear the summary');
update public.coach_threads set summary = 'They play badminton on Saturdays.', summary_upto = 8;

-- User B neither sees nor changes A's summary.
select set_config('request.jwt.claims', '{"sub":"00000000-0000-0000-0000-00000000bbbb","role":"authenticated"}', true);
select is((select count(*)::int from public.coach_threads), 0, 'another user sees no thread or summary');
update public.coach_threads set summary = 'hijacked';

set local role anon;
select throws_ok($$ select summary from public.coach_threads $$, '42501', null, 'anon cannot read summaries');

reset role;
select is((select summary from public.coach_threads where user_id = '00000000-0000-0000-0000-00000000aaaa'), 'They play badminton on Saturdays.', 'A''s summary survived B''s update');
-- delete-account deletes the auth user; the thread and its summary cascade with it.
delete from auth.users where id = '00000000-0000-0000-0000-00000000aaaa';
select is((select count(*)::int from public.coach_threads where summary is not null), 0, 'account deletion removes the summary');

select * from finish();
rollback;
