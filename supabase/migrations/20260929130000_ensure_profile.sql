-- Self-heal: every signed-in user must have a profile row (the sign-up trigger creates it,
-- but a missing row would lock the user out of the dashboard check).
insert into public.profiles (id)
select u.id from auth.users u
where not exists (select 1 from public.profiles p where p.id = u.id);

-- Callable by the app: creates the caller's own profile if missing. Only ever touches auth.uid().
create function public.ensure_profile()
returns void
language sql
security definer
set search_path = ''
as $$
  insert into public.profiles (id) values ((select auth.uid())) on conflict (id) do nothing;
$$;

revoke execute on function public.ensure_profile() from public, anon;
grant execute on function public.ensure_profile() to authenticated;
