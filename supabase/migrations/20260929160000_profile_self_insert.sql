-- Replace the SECURITY DEFINER ensure_profile() (advisor lint 0029) with plain RLS:
-- a signed-in user may insert only their own profile row and only the id column,
-- so onboarding_complete keeps its default (false) and stays server-controlled.
drop function public.ensure_profile();

grant insert (id) on public.profiles to authenticated;
create policy "create own profile" on public.profiles for insert to authenticated
  with check ((select auth.uid()) = id);
