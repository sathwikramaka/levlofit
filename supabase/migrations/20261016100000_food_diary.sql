-- Food diary: what the user ate, as a food from the IFCT 2017 table and an edible-portion weight in grams.
-- Nutrients are not copied here: totals are worked out from public.foods at read time, so every number keeps the
-- IFCT provenance and a corrected food value fixes past days too. Additive only; the app tolerates its absence.
create table public.food_log (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null default auth.uid() references auth.users (id) on delete cascade,
  day date not null,
  meal text not null check (meal in ('breakfast', 'lunch', 'dinner', 'snack')),
  food_code text not null references public.foods (code),
  grams numeric(6, 1) not null check (grams > 0 and grams <= 2000),
  created_at timestamptz not null default now()
);
create index food_log_user_day on public.food_log (user_id, day);

alter table public.food_log enable row level security;
revoke all on public.food_log from anon, authenticated;
grant select, delete on public.food_log to authenticated;
grant insert (day, meal, food_code, grams) on public.food_log to authenticated;
grant update (meal, grams) on public.food_log to authenticated;
create policy "own food log" on public.food_log for all to authenticated
  using ((select auth.uid()) = user_id) with check ((select auth.uid()) = user_id);

-- At most 60 entries per user per day (and only for real days): plenty for real eating, bounded against runaway inserts.
create function public.food_log_limit() returns trigger
language plpgsql set search_path = '' as $$
begin
  -- A diary day is today (one day of slack for time zones) or up to two years back: otherwise the per-day cap below
  -- could be bypassed by spreading inserts over thousands of made-up dates. The app only offers past days and today.
  if new.day > current_date + 1 or new.day < current_date - 730 then
    raise exception 'diary day out of range' using errcode = '22008';
  end if;
  perform pg_advisory_xact_lock(hashtext('food_log:' || new.user_id::text || ':' || new.day::text));
  if (select count(*) from public.food_log where user_id = new.user_id and day = new.day) >= 60 then
    raise exception 'food log limit reached for this day' using errcode = 'P0001';
  end if;
  return new;
end $$;
revoke execute on function public.food_log_limit() from public, anon, authenticated;
create trigger food_log_limit before insert on public.food_log
  for each row execute function public.food_log_limit();
