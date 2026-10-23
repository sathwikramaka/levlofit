-- pgTAP tests for migration 20261023100000_coach_facts.sql: memory the person confirms, owner-only.
-- Run on a throwaway local stack: supabase test db --local --workdir <copy>
begin;
create extension if not exists pgtap with schema extensions;
select plan(24);

insert into auth.users (id, email) values
  ('00000000-0000-0000-0000-00000000aaaa', 'a@test.local'),
  ('00000000-0000-0000-0000-00000000bbbb', 'b@test.local');

-- Act as user A.
set local role authenticated;
select set_config('request.jwt.claims', '{"sub":"00000000-0000-0000-0000-00000000aaaa","role":"authenticated"}', true);

-- Suggestions can never be stored as confirmed.
insert into public.coach_facts (category, fact, status, source) values ('schedule', 'trains before work', 'confirmed', 'coach');
select is((select status from public.coach_facts where fact = 'trains before work'), 'suggested', 'a coach suggestion is stored unconfirmed even if the insert says confirmed');
select is((select confirmed_at from public.coach_facts where fact = 'trains before work'), null, 'an unconfirmed fact has no confirmation time');
insert into public.coach_facts (category, fact, status, source) values ('other', 'old note line', 'confirmed', 'migrated');
select is((select status from public.coach_facts where fact = 'old note line'), 'suggested', 'a migrated note is stored unconfirmed');

-- Approval, edit, rejection.
update public.coach_facts set status = 'confirmed' where fact = 'trains before work';
select is((select status from public.coach_facts where fact = 'trains before work'), 'confirmed', 'the owner can confirm a suggestion');
select isnt((select confirmed_at from public.coach_facts where fact = 'trains before work'), null, 'confirming sets the confirmation time');
update public.coach_facts set fact = 'trains before work, 30 minutes', category = 'schedule' where fact = 'trains before work';
select is((select status from public.coach_facts where fact = 'trains before work, 30 minutes'), 'confirmed', 'editing a confirmed fact keeps it confirmed');
delete from public.coach_facts where fact = 'old note line';
select is((select count(*)::int from public.coach_facts where fact = 'old note line'), 0, 'the owner can reject (delete) a suggestion');
insert into public.coach_facts (category, fact, status) values ('equipment', 'has a pull-up bar', 'confirmed');
select is((select source from public.coach_facts where fact = 'has a pull-up bar'), 'user', 'a fact the person adds is theirs (source user)');
select is((select status from public.coach_facts where fact = 'has a pull-up bar'), 'confirmed', 'a fact the person adds can be confirmed directly');

-- Columns the client must not set.
select throws_ok($$ update public.coach_facts set user_id = '00000000-0000-0000-0000-00000000bbbb' $$, '42501', null, 'a fact cannot be moved to another user');
select throws_ok($$ update public.coach_facts set source = 'user' $$, '42501', null, 'the source of a fact cannot be rewritten');
select throws_ok($$ update public.coach_facts set confirmed_at = now() $$, '42501', null, 'the confirmation time cannot be set by the client');
select throws_ok($$ insert into public.coach_facts (user_id, category, fact) values ('00000000-0000-0000-0000-00000000bbbb', 'goal', 'planted fact') $$,
  '42501', null, 'a fact cannot be inserted for another user');

-- Checks.
select throws_ok($$ insert into public.coach_facts (category, fact) values ('diagnosis', 'something') $$, '23514', null, 'unknown categories are refused');
select throws_ok($$ insert into public.coach_facts (category, fact) values ('goal', '  a ') $$, '23514', null, 'facts under 3 characters are refused');
select throws_ok($$ insert into public.coach_facts (category, fact) values ('goal', repeat('x', 201)) $$, '23514', null, 'facts over 200 characters are refused');

-- User B sees and changes nothing of A's.
select set_config('request.jwt.claims', '{"sub":"00000000-0000-0000-0000-00000000bbbb","role":"authenticated"}', true);
select is((select count(*)::int from public.coach_facts), 0, 'another user sees none of the facts');
update public.coach_facts set fact = 'hijacked', status = 'confirmed';
delete from public.coach_facts;
insert into public.coach_facts (category, fact) values ('goal', 'b own goal');
select is((select count(*)::int from public.coach_facts), 1, 'another user sees only their own fact');

-- Anonymous callers get nothing.
set local role anon;
select throws_ok($$ select * from public.coach_facts $$, '42501', null, 'anon cannot read facts');

-- Back as the table owner: A's facts survived B's attempts, and account deletion removes all of them.
reset role;
select is((select count(*)::int from public.coach_facts where user_id = '00000000-0000-0000-0000-00000000aaaa'), 2, 'A still has both facts after B tried to change them');
select is((select count(*)::int from public.coach_facts where fact = 'hijacked'), 0, 'B could not edit A''s facts');
delete from auth.users where id = '00000000-0000-0000-0000-00000000aaaa';
select is((select count(*)::int from public.coach_facts where user_id = '00000000-0000-0000-0000-00000000aaaa'), 0, 'deleting the account deletes every fact');
select is((select count(*)::int from public.coach_facts where user_id = '00000000-0000-0000-0000-00000000bbbb'), 1, 'other users'' facts are untouched');
select ok((select relrowsecurity from pg_class where oid = 'public.coach_facts'::regclass), 'row level security is on');

select * from finish();
rollback;
