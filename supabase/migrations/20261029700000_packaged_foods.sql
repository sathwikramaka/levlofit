-- Packaged foods (audit 12.12): a person's own products, from a barcode looked up on Open Food Facts, typed from the
-- label, or entered by hand when nothing is found. Values are per 100 g as printed; energy, protein, fat and carbs are
-- required (FSSAI labels carry them), fibre may be unknown. The diary logs them through food_log.packaged_food_id.
create table public.packaged_foods (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null default auth.uid() references auth.users (id) on delete cascade,
  barcode text check (barcode ~ '^[0-9]{8,14}$'),
  name text not null check (char_length(btrim(name)) between 2 and 120),
  brand text check (char_length(brand) <= 80),
  kcal numeric(5, 1) not null check (kcal between 0 and 900),
  protein_g numeric(4, 1) not null check (protein_g between 0 and 100),
  fat_g numeric(4, 1) not null check (fat_g between 0 and 100),
  carb_g numeric(4, 1) not null check (carb_g between 0 and 100),
  fiber_g numeric(4, 1) check (fiber_g between 0 and 100),
  source text not null check (source in ('open_food_facts', 'label', 'manual')),
  source_date date,
  created_at timestamptz not null default now(),
  unique (user_id, barcode)
);
alter table public.packaged_foods enable row level security;
revoke all on public.packaged_foods from anon, authenticated;
grant select, delete on public.packaged_foods to authenticated;
grant insert (barcode, name, brand, kcal, protein_g, fat_g, carb_g, fiber_g, source, source_date) on public.packaged_foods to authenticated;
grant update (name, brand, kcal, protein_g, fat_g, carb_g, fiber_g, source, source_date) on public.packaged_foods to authenticated;
create policy "own packaged foods" on public.packaged_foods for all to authenticated
  using ((select auth.uid()) = user_id) with check ((select auth.uid()) = user_id);

-- At most 500 products per person: plenty for real use, bounded against runaway inserts.
create function public.packaged_foods_limit() returns trigger
language plpgsql set search_path = '' as $$
begin
  perform pg_advisory_xact_lock(hashtext('packaged_foods:' || new.user_id::text));
  if (select count(*) from public.packaged_foods where user_id = new.user_id) >= 500 then
    raise exception 'packaged food limit reached' using errcode = 'P0001';
  end if;
  return new;
end $$;
revoke execute on function public.packaged_foods_limit() from public, anon, authenticated;
create trigger packaged_foods_limit before insert on public.packaged_foods
  for each row execute function public.packaged_foods_limit();

-- A diary entry is a table food or one of the person's own packaged foods, never both.
alter table public.food_log
  alter column food_code drop not null,
  add column packaged_food_id uuid references public.packaged_foods (id) on delete cascade,
  add constraint food_log_one_food check (num_nonnulls(food_code, packaged_food_id) = 1);
grant insert (packaged_food_id) on public.food_log to authenticated;
create index food_log_packaged on public.food_log (packaged_food_id) where packaged_food_id is not null;

-- RLS on food_log checks the row's owner only, so the product must belong to the same person.
create function public.food_log_own_packaged() returns trigger
language plpgsql set search_path = '' as $$
begin
  if new.packaged_food_id is not null
     and not exists (select 1 from public.packaged_foods p where p.id = new.packaged_food_id and p.user_id = new.user_id) then
    raise exception 'packaged food not found' using errcode = '23503';
  end if;
  return new;
end $$;
revoke execute on function public.food_log_own_packaged() from public, anon, authenticated;
create trigger food_log_own_packaged before insert on public.food_log
  for each row execute function public.food_log_own_packaged();
