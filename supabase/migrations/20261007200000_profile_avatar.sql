-- Profile picture: one of the built-in avatars, or 'photo' for the user's own picture stored at
-- progress-photos/<user id>/avatar.jpg (same private bucket and policy; delete-account already clears that folder).
alter table public.profiles add column if not exists avatar text
  check (avatar in ('barbell', 'run', 'bike', 'swim', 'flame', 'bolt', 'peak', 'trophy', 'photo'));
grant update (avatar) on public.profiles to authenticated;
