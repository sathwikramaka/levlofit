-- Levlofit AI memory as structured facts the person controls. The coach may only SUGGEST a fact; it reaches the
-- coach's context only after the person confirms it in the app. Each fact can be viewed, edited and deleted.
-- Existing free-text notes are copied in as unconfirmed suggestions (source 'migrated'); coach_notes itself is left
-- unchanged (no data removed) and is no longer read by the coach.
create table public.coach_facts (
  id bigint generated always as identity primary key,
  user_id uuid not null default auth.uid() references auth.users (id) on delete cascade,
  category text not null default 'other' check (category in ('injury', 'schedule', 'equipment', 'preference', 'goal', 'other')),
  fact text not null check (char_length(btrim(fact)) between 3 and 200),
  status text not null default 'suggested' check (status in ('suggested', 'confirmed')),
  source text not null default 'user' check (source in ('coach', 'user', 'migrated')),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  confirmed_at timestamptz,
  check ((status = 'confirmed') = (confirmed_at is not null))
);
create index coach_facts_user on public.coach_facts (user_id, status, id);

-- Suggestions from the coach or the migration always start unconfirmed, whatever the insert says; confirmation
-- time and update time are set by the database, never by the client.
create function public.coach_facts_stamp() returns trigger
language plpgsql set search_path = '' as $$
begin
  if tg_op = 'INSERT' and new.source in ('coach', 'migrated') then
    new.status := 'suggested';
  end if;
  if tg_op = 'UPDATE' then
    new.user_id := old.user_id;
    new.source := old.source;
    new.created_at := old.created_at;
    new.updated_at := now();
  end if;
  new.confirmed_at := case
    when new.status <> 'confirmed' then null
    when tg_op = 'UPDATE' and old.status = 'confirmed' then old.confirmed_at
    else now() end;
  return new;
end $$;
create trigger coach_facts_stamp before insert or update on public.coach_facts
  for each row execute function public.coach_facts_stamp();

alter table public.coach_facts enable row level security;
revoke all on public.coach_facts from anon, authenticated;
grant select, delete on public.coach_facts to authenticated;
grant insert (category, fact, status, source), update (category, fact, status) on public.coach_facts to authenticated;
create policy "own facts" on public.coach_facts for all to authenticated
  using ((select auth.uid()) = user_id) with check ((select auth.uid()) = user_id);

-- Existing notes, one line per suggestion. Lines too short are skipped; long ones are cut to the column limit.
insert into public.coach_facts (user_id, category, fact, status, source)
select n.user_id, 'other', left(btrim(regexp_replace(l.line, '^[\s#>*-]+', '')), 200), 'suggested', 'migrated'
from public.coach_notes n
cross join lateral regexp_split_to_table(n.notes, E'\n') as l(line)
where char_length(btrim(regexp_replace(l.line, '^[\s#>*-]+', ''))) >= 3;
