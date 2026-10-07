-- Exercise catalogue. v1 media: ExerciseDB free V1 dataset by AscendAPI (https://oss.exercisedb.dev).
-- Terms: non-commercial use only, credit to AscendAPI required, 180p GIFs, strict rate limits.
-- Before Levlofit charges money, switch to a paid licence or own renders: the app reads gif_url from here only.

-- array_to_string is only STABLE; the generated search column needs an IMMUTABLE join.
create function public.words(text[]) returns text
language sql immutable parallel safe set search_path = ''
as $$ select coalesce(array_to_string($1, ' '), '') $$;
revoke execute on function public.words(text[]) from public, anon, authenticated;

create table public.exercises (
  id text primary key,
  name text not null,
  gif_url text not null,
  body_parts text[] not null default '{}',
  equipment text[] not null default '{}',
  target_muscles text[] not null default '{}',
  secondary_muscles text[] not null default '{}',
  instructions text[] not null default '{}',
  source text not null default 'exercisedb-v1',
  search tsvector generated always as (
    setweight(to_tsvector('english', name), 'A')
    || setweight(to_tsvector('english', public.words(target_muscles || body_parts || equipment)), 'B')
  ) stored
);
create index exercises_search_idx on public.exercises using gin (search);
alter table public.exercises enable row level security;
create policy "exercises are public" on public.exercises for select to anon, authenticated using (true);
revoke insert, update, delete on public.exercises from anon, authenticated;

-- One-time import (run 2026-09-29, 1,500 rows). Kept here so it can be repeated; the API pages 25 at a time in
-- case-insensitive id order and rate-limits hard, so run `select public.import_exercisedb_batch();` until it
-- returns "done", then drop the function and the extension as below.
--
-- create extension if not exists http with schema extensions;
-- create or replace function public.import_exercisedb_batch(max_pages int default 10, pause float default 2.5)
-- returns text language plpgsql set search_path = '' as $fn$
-- declare
--   cur text := (select id from public.exercises order by lower(id) desc, id desc limit 1);
--   res extensions.http_response; body jsonb; pages int := 0;
-- begin
--   loop
--     res := extensions.http(('GET', 'https://oss.exercisedb.dev/api/v1/exercises?limit=25' || coalesce('&after=' || cur, ''),
--       array[extensions.http_header('User-Agent', 'Mozilla/5.0 (Levlofit catalogue import)'),
--             extensions.http_header('Accept', 'application/json')], null, null)::extensions.http_request);
--     if res.status = 429 then return format('rate limited after %s pages', pages); end if;
--     if res.status <> 200 or res.content_type not like 'application/json%' then raise exception 'status %', res.status; end if;
--     body := res.content::jsonb;
--     insert into public.exercises (id, name, gif_url, body_parts, equipment, target_muscles, secondary_muscles, instructions)
--     select e->>'exerciseId', e->>'name', e->>'gifUrl',
--            array(select jsonb_array_elements_text(e->'bodyParts')), array(select jsonb_array_elements_text(e->'equipments')),
--            array(select jsonb_array_elements_text(e->'targetMuscles')), array(select jsonb_array_elements_text(e->'secondaryMuscles')),
--            array(select regexp_replace(s, '^Step:\s*\d+\s*', '') from jsonb_array_elements_text(e->'instructions') s)
--     from jsonb_array_elements(body->'data') e
--     on conflict (id) do nothing;
--     pages := pages + 1;
--     if not coalesce((body->'meta'->>'hasNextPage')::boolean, false) then return format('done after %s pages', pages); end if;
--     if pages >= max_pages then return format('batch of %s pages', pages); end if;
--     cur := body->'meta'->>'nextCursor';
--     perform pg_sleep(pause);
--   end loop;
-- end $fn$;
--
-- drop function if exists public.import_exercisedb_batch(int, float);
-- drop extension if exists http;
