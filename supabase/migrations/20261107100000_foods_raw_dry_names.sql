-- Owner report 2026-11-07. The diary listed raw and dry staples under bare names: "Rice" holds USDA values for raw rice
-- (365 kcal per 100 g), so 250 g of cooked rice logged against it counted about 910 kcal. Same for dals, beans, oats,
-- semolina, broken wheat, soya chunks and raw chicken. The values were right; the names did not say what they describe.
-- Names only: no values, codes, tags or diary rows change, and a search for "rice" or "moong" still finds them.
update public.foods set name = v.name
  from (values
    ('FDC169756', 'Rice (raw, uncooked)'),
    ('FDC174284', 'Masoor dal (red lentils, dry, uncooked)'),
    ('FDC174256', 'Moong (mung beans, dry, uncooked)'),
    ('FDC172436', 'Toor (pigeon peas, dry, uncooked)'),
    ('FDC173744', 'Rajma (kidney beans, dry, uncooked)'),
    ('FDC173756', 'Kala chana (chickpeas, dry, uncooked)'),
    ('FDC174275', 'Soya chunks (defatted soy, dry, uncooked)'),
    ('X001', 'Soya chunks (dry, uncooked)'),
    ('FDC173904', 'Rolled oats (dry, uncooked)'),
    ('FDC168933', 'Rava (semolina, dry, uncooked)'),
    ('FDC170688', 'Daliya (broken wheat, dry, uncooked)'),
    ('FDC171077', 'Chicken breast (raw)')
  ) as v(code, name)
  where foods.code = v.code;

-- Rollback: set the names back: Rice; Masoor dal (red lentils); Moong (mung beans); Toor (pigeon peas);
-- Rajma (kidney beans); Kala chana (chickpeas); Soya chunks (defatted soy); Soya chunks; Rolled oats; Rava (semolina);
-- Daliya (broken wheat); Chicken breast.
