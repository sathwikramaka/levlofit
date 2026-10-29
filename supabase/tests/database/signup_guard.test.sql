-- pgTAP tests for 20261030100000_signup_guard.sql. Run locally: supabase test db (throwaway stack).
begin;
create extension if not exists pgtap with schema extensions;
select plan(9);

select is(public.hook_before_user_created('{"user":{"email":"goose9836186a@mailinator.com"}}'),
  '{"error":{"http_code":400,"message":"Please sign up with a permanent email address."}}'::jsonb, 'mailinator refused');
select ok(public.hook_before_user_created('{"user":{"email":"Bot@Sub.YopMail.com"}}') ? 'error', 'subdomain and case refused');
select is(public.hook_before_user_created('{"user":{"email":"someone@gmail.com"}}'), '{}'::jsonb, 'gmail allowed');
select is(public.hook_before_user_created('{"user":{"email":"a@notmailinator.com.in"}}'), '{}'::jsonb, 'lookalike domain allowed');
select is(public.hook_before_user_created('{"user":{"phone":"+911234567890"}}'), '{}'::jsonb, 'no email allowed');

insert into auth.users (id, email, created_at, email_confirmed_at) values
  ('00000000-0000-0000-0000-0000000005a1', 'old-unconfirmed@test.local', now() - interval '3 days', null),
  ('00000000-0000-0000-0000-0000000005a2', 'new-unconfirmed@test.local', now() - interval '1 hour', null),
  ('00000000-0000-0000-0000-0000000005a3', 'old-confirmed@test.local', now() - interval '30 days', now() - interval '30 days');

select is(public.purge_unconfirmed_users(), 1, 'one stale unconfirmed user purged');
select is((select count(*)::int from auth.users where id::text like '00000000-0000-0000-0000-0000000005a%'), 2,
  'fresh unconfirmed and confirmed users kept');
select ok(exists (select 1 from cron.job where jobname = 'purge-unconfirmed-users'), 'hourly purge scheduled');

set local role authenticated;
select throws_ok($$ select public.purge_unconfirmed_users() $$, '42501', null, 'users cannot call the purge');

select * from finish();
rollback;
