-- Crash log (2026-10-27): the app reports unexpected errors from signed-in users so they can be fixed in updates.
-- Write-only for users (no select), at most 30 reports per user per day, rows older than 90 days are removed on the
-- user's next report, and everything goes with the account (on delete cascade). Read by the owner in the dashboard.
create table public.app_errors (
  id bigint generated always as identity primary key,
  user_id uuid not null default auth.uid() references auth.users (id) on delete cascade,
  created_at timestamptz not null default now(),
  app_version text not null check (char_length(app_version) between 1 and 20),
  platform text not null check (platform in ('android', 'ios', 'web', 'other')),
  message text not null check (char_length(message) between 1 and 1000),
  stack text check (char_length(stack) <= 4000)
);
create index app_errors_user_time on public.app_errors (user_id, created_at);

alter table public.app_errors enable row level security;
revoke all on public.app_errors from anon, authenticated;
grant insert (app_version, platform, message, stack) on public.app_errors to authenticated;
create policy "own error reports" on public.app_errors for insert to authenticated
  with check ((select auth.uid()) = user_id);

create or replace function public.app_errors_limit() returns trigger
language plpgsql security definer set search_path = ''
as $$
begin
  delete from public.app_errors e where e.user_id = new.user_id and e.created_at < now() - interval '90 days';
  if (select count(*) from public.app_errors e where e.user_id = new.user_id and e.created_at > now() - interval '1 day') >= 30 then
    return null; -- over the daily cap: drop the report quietly, the app never waits on it
  end if;
  return new;
end;
$$;
revoke execute on function public.app_errors_limit() from public, anon, authenticated;
create trigger app_errors_limit before insert on public.app_errors for each row execute function public.app_errors_limit();
