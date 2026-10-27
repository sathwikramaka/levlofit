-- Food data provenance and licence gate (2026-10-24).
-- Every food row names its source. public.food_sources records each source's licence, attribution and review date,
-- and whether its values may be shown (release_allowed). The read policy on foods shows only rows from allowed sources,
-- so the app and the coach (both read as the signed-in person) never show values whose licence is not confirmed.
--
-- IFCT 2017 (ICMR-NIN): no licence grant found (nin.res.in: "All Rights Reserved"; checked 2026-10-24), so it is not
-- allowed. The rows stay in the table (food_log and recipe_items reference them), hidden from app roles. Local
-- development turns it on in supabase/seed.sql, which db push does not apply unless run with --include-seed (never for
-- production). Turning it on in production needs NIN's written permission and an owner-approved update.
-- USDA FoodData Central: CC0 1.0 (fdc.nal.usda.gov/api-guide, checked 2026-10-24). No rows yet: the import needs the
-- owner-approved download (data/build_foods_fdc.py).

create table public.food_sources (
  source text primary key check (source ~ '^[a-z0-9_]{2,30}$'),
  name text not null,
  licence text not null,
  url text not null,
  attribution text not null,
  verified_on date not null,
  release_allowed boolean not null default false,
  note text
);
alter table public.food_sources enable row level security;
create policy "food sources are public" on public.food_sources for select to anon, authenticated using (true);
revoke insert, update, delete on public.food_sources from anon, authenticated;

insert into public.food_sources (source, name, licence, url, attribution, verified_on, release_allowed, note) values
('ifct2017', 'Indian Food Composition Tables 2017, ICMR-National Institute of Nutrition',
 'No licence grant found. The NIN website states All Rights Reserved and requires written permission for reproduction.',
 'https://www.nin.res.in/', 'Food values: IFCT 2017, ICMR-NIN', '2026-10-24', false,
 'Values via the npm package @ifct2017/compositions 2.0.9 (code MIT; data NIN). Hidden until NIN grants permission.'),
('usda_fdc', 'USDA FoodData Central', 'Public domain, CC0 1.0 Universal',
 'https://fdc.nal.usda.gov/', 'U.S. Department of Agriculture, Agricultural Research Service. FoodData Central. fdc.nal.usda.gov',
 '2026-10-24', true, 'USDA requests that users list FoodData Central as the source.'),
('levlofit_recipe', 'Levlofit recipes', 'Levlofit''s own work: ingredient-level sums of allowed sources',
 'https://levlofit.app/', 'Recipe values: Levlofit, calculated from FoodData Central', '2026-10-24', true,
 'Each recipe lists its ingredients and grams; values are the sum of allowed ingredient rows.');

alter table public.foods
  add column source text not null default 'ifct2017' references public.food_sources (source),
  add column source_ref text;
update public.foods set source_ref = code where source = 'ifct2017';
-- Soya chunks were never IFCT: 20261007100000_soya_chunks took them from FDC "Soy flour, defatted" (FDC 174275).
update public.foods set source = 'usda_fdc', source_ref = '174275' where code = 'X001';
alter table public.foods alter column source drop default;
create index foods_source_idx on public.foods (source);

drop policy "foods are public" on public.foods;
create policy "foods from allowed sources" on public.foods for select to anon, authenticated
  using (exists (select 1 from public.food_sources s where s.source = foods.source and s.release_allowed));
