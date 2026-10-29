-- Signup guard (2026-10-30): bots were creating email accounts on throwaway inboxes (goose…@mailinator.com) that never
-- confirm. Unconfirmed accounts already cannot sign in (Confirm email is on in the cloud project); this stops the
-- signups at the door and clears out the ones that never confirm.
--
-- 1. hook_before_user_created: Auth calls it before inserting any user (email or Google). Rejects disposable domains
--    and their subdomains. Enable it in the dashboard: Authentication > Auth Hooks > Before User Created > Postgres,
--    function public.hook_before_user_created.
-- 2. purge_unconfirmed_users: deletes email signups still unconfirmed after 2 days, run hourly by pg_cron. They never
--    signed in, so they own no app data.

create or replace function public.hook_before_user_created(event jsonb)
returns jsonb
language plpgsql
stable
set search_path = ''
as $$
declare
  domain text := lower(split_part(coalesce(event->'user'->>'email', ''), '@', 2));
  -- ponytail: hand-kept list of the common throwaway services; add domains here when new ones show up in Auth > Users.
  blocked text[] := array[
    'mailinator.com', 'mailinator.net', 'mailinator2.com', 'guerrillamail.com', 'guerrillamail.net',
    'guerrillamail.info', 'guerrillamail.org', 'sharklasers.com', 'grr.la', 'pokemail.net', 'spam4.me',
    '10minutemail.com', '10minutemail.net', 'tempmail.com', 'temp-mail.org', 'temp-mail.io', 'tempmail.dev',
    'yopmail.com', 'yopmail.net', 'yopmail.fr', 'trashmail.com', 'trashmail.de', 'getnada.com', 'nada.email',
    'dispostable.com', 'maildrop.cc', 'mailnesia.com', 'mintemail.com', 'throwawaymail.com', 'fakeinbox.com',
    'emailondeck.com', 'mohmal.com', 'tempail.com', 'tempr.email', 'discard.email', 'moakt.com', 'mailcatch.com',
    'mail.tm', '1secmail.com', '1secmail.org', '1secmail.net', 'emailfake.com', 'burnermail.io', 'inboxkitten.com',
    'mytemp.email', 'tmpmail.org', 'tmpmail.net', 'spamgourmet.com', 'mailpoof.com', 'linshiyouxiang.net',
    'dropmail.me', 'emltmp.com', 'tmpeml.com', 'byom.de', 'mailsac.com', 'getairmail.com', 'fexbox.org'
  ];
begin
  if exists (select 1 from unnest(blocked) b where domain = b or domain like '%.' || b) then
    return jsonb_build_object('error', jsonb_build_object(
      'http_code', 400,
      'message', 'Please sign up with a permanent email address.'));
  end if;
  return '{}'::jsonb;
end;
$$;

revoke execute on function public.hook_before_user_created(jsonb) from public, anon, authenticated;
grant execute on function public.hook_before_user_created(jsonb) to supabase_auth_admin;

create or replace function public.purge_unconfirmed_users()
returns integer
language sql
set search_path = ''
as $$
  with gone as (
    delete from auth.users
    where email_confirmed_at is null
      and phone_confirmed_at is null
      and not is_anonymous
      and not is_sso_user
      and created_at < now() - interval '2 days'
    returning 1
  )
  select count(*)::int from gone;
$$;

revoke execute on function public.purge_unconfirmed_users() from public, anon, authenticated;

create extension if not exists pg_cron;
select cron.schedule('purge-unconfirmed-users', '17 * * * *', 'select public.purge_unconfirmed_users()');
