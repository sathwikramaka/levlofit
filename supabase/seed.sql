-- Local development only. supabase db reset / start load this file; db push does not unless --include-seed, which must
-- never be used against production. IFCT 2017 has no licence grant (20261025100000_food_sources.sql), so release data
-- keeps it hidden; local stacks show it so development and tests can use the existing food codes.
update public.food_sources set release_allowed = true where source = 'ifct2017';
