-- Soya chunks: how most Indians eat soya. IFCT 2017 lists only whole soya beans, so the values come from
-- USDA FoodData Central, "Soy flour, defatted" (FDC 174275, SR Legacy 16117): soya chunks are extruded defatted soy flour.
insert into foods (code, name, name_hi, food_group, tags, kcal, protein_g, fat_g, carb_g, fiber_g, suggestible, kcal_estimated)
values ('X001', 'Soya chunks', 'Soya badi', 'Grain Legumes', array['soy']::text[], 327, 51.46, 1.22, 33.92, 17.5, true, false)
on conflict (code) do nothing;
