-- Reminders the user creates: a name, a time, which days (empty = every day) and an on/off switch.
-- Additive only. The app tolerates this table being absent, so it can ship before or after the migration.
create table public.custom_reminders (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null default auth.uid() references auth.users (id) on delete cascade,
  name text not null check (char_length(btrim(name)) between 1 and 60),
  remind_at time not null,
  weekdays smallint[] not null default '{}' check (weekdays <@ array[1, 2, 3, 4, 5, 6, 7]::smallint[]),
  enabled boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create index custom_reminders_user on public.custom_reminders (user_id, created_at);

alter table public.custom_reminders enable row level security;
revoke all on public.custom_reminders from anon, authenticated;
grant select, delete on public.custom_reminders to authenticated;
grant insert (name, remind_at, weekdays, enabled),
  update (name, remind_at, weekdays, enabled, updated_at) on public.custom_reminders to authenticated;
create policy "own custom reminders" on public.custom_reminders for all to authenticated
  using ((select auth.uid()) = user_id) with check ((select auth.uid()) = user_id);

-- At most 20 per user: keeps scheduling bounded (iOS holds 64 pending notifications in total).
create function public.custom_reminders_limit() returns trigger
language plpgsql set search_path = '' as $$
begin
  perform pg_advisory_xact_lock(hashtext('custom_reminders:' || new.user_id::text));
  if (select count(*) from public.custom_reminders where user_id = new.user_id) >= 20 then
    raise exception 'custom reminder limit reached' using errcode = 'P0001';
  end if;
  return new;
end $$;
revoke execute on function public.custom_reminders_limit() from public, anon, authenticated;
create trigger custom_reminders_limit before insert on public.custom_reminders
  for each row execute function public.custom_reminders_limit();
