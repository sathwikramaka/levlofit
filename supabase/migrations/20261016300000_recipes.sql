-- Recipes: the user's own dishes, as IFCT 2017 foods with raw gram weights and a number of servings. Logging a
-- recipe adds its ingredients to food_log (scaled to the servings eaten), so totals keep the IFCT provenance.
-- Additive only; the app tolerates its absence.
create table public.recipes (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null default auth.uid() references auth.users (id) on delete cascade,
  name text not null check (char_length(btrim(name)) between 1 and 60),
  servings smallint not null check (servings between 1 and 20),
  created_at timestamptz not null default now()
);
create index recipes_user on public.recipes (user_id);

create table public.recipe_items (
  id uuid primary key default gen_random_uuid(),
  recipe_id uuid not null references public.recipes (id) on delete cascade,
  user_id uuid not null default auth.uid() references auth.users (id) on delete cascade,
  food_code text not null references public.foods (code),
  grams numeric(6, 1) not null check (grams > 0 and grams <= 2000)
);
create index recipe_items_recipe on public.recipe_items (recipe_id);

alter table public.recipes enable row level security;
alter table public.recipe_items enable row level security;
revoke all on public.recipes, public.recipe_items from anon, authenticated;
grant select, delete on public.recipes, public.recipe_items to authenticated;
grant insert (name, servings) on public.recipes to authenticated;
grant insert (recipe_id, food_code, grams) on public.recipe_items to authenticated;
create policy "own recipes" on public.recipes for all to authenticated
  using ((select auth.uid()) = user_id) with check ((select auth.uid()) = user_id);
-- Items: own rows, and only into the user's own recipe.
create policy "own recipe items" on public.recipe_items for all to authenticated
  using ((select auth.uid()) = user_id)
  with check ((select auth.uid()) = user_id
    and exists (select 1 from public.recipes r where r.id = recipe_id and r.user_id = (select auth.uid())));

-- At most 50 recipes per user and 30 ingredients per recipe.
create function public.recipe_limits() returns trigger
language plpgsql set search_path = '' as $$
begin
  if tg_table_name = 'recipes' then
    perform pg_advisory_xact_lock(hashtext('recipes:' || new.user_id::text));
    if (select count(*) from public.recipes where user_id = new.user_id) >= 50 then
      raise exception 'recipe limit reached' using errcode = 'P0001';
    end if;
  else
    perform pg_advisory_xact_lock(hashtext('recipe_items:' || new.recipe_id::text));
    if (select count(*) from public.recipe_items where recipe_id = new.recipe_id) >= 30 then
      raise exception 'ingredient limit reached' using errcode = 'P0001';
    end if;
  end if;
  return new;
end $$;
revoke execute on function public.recipe_limits() from public, anon, authenticated;
create trigger recipe_limit before insert on public.recipes for each row execute function public.recipe_limits();
create trigger recipe_item_limit before insert on public.recipe_items for each row execute function public.recipe_limits();

-- Saves a recipe and its ingredients in one transaction, as the calling user (RLS and grants apply).
-- items: [{"food_code": "A013", "grams": 150}, ...]
create function public.save_recipe(p_name text, p_servings int, p_items jsonb) returns uuid
language plpgsql security invoker set search_path = '' as $$
declare
  rid uuid;
begin
  if jsonb_typeof(p_items) is distinct from 'array' or jsonb_array_length(p_items) = 0 then
    raise exception 'a recipe needs at least one ingredient' using errcode = '22023';
  end if;
  insert into public.recipes (name, servings) values (btrim(p_name), p_servings) returning id into rid;
  insert into public.recipe_items (recipe_id, food_code, grams)
    select rid, i ->> 'food_code', (i ->> 'grams')::numeric from jsonb_array_elements(p_items) i;
  return rid;
end $$;
revoke execute on function public.save_recipe(text, int, jsonb) from public, anon;
grant execute on function public.save_recipe(text, int, jsonb) to authenticated;
