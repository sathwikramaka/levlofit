# USDA FoodData Central: provenance

- Licence: public domain, CC0 1.0 Universal ("USDA FoodData Central data are in the public domain and they are not
  copyrighted"; fdc.nal.usda.gov/api-guide/, checked 2026-10-24). USDA asks users to name FoodData Central as the source.
- Citation: U.S. Department of Agriculture, Agricultural Research Service. FoodData Central, 2018 (SR Legacy).
  fdc.nal.usda.gov.
- Downloaded 2026-10-24 with the owner's approval, into a scratch folder outside the repository (not committed):

| File | Bytes | SHA-256 |
|---|---|---|
| FoodData_Central_sr_legacy_food_csv_2018-04.zip | 6,074,592 | b80817294b8850530aaedf2e515c02593b1824f763a0ff356e5c2081643e6fd0 |
| FoodData_Central_foundation_food_csv_2026-04-30.zip | 3,825,741 | 70457ee9d9342f43bda2010318c85f04210c689fdeb9cd2da4c513b0e8dbc655 |

- Built with `python -I data/build_foods_fdc.py <sr folder> <foundation folder>` into
  supabase/migrations/20261025200000_foods_usda_fdc.sql. All 28 rows come from SR Legacy. Three names (cauliflower,
  cucumber, whole milk) also occur in the Foundation release, and the builder takes the SR Legacy record so that
  every value comes from one dataset.
- Derivations, all in the builder:
  - carb_g = carbohydrate by difference (1005) minus total dietary fibre (1079). This is available carbohydrate, the
    same meaning as the IFCT column (CHOAVLDF).
  - Energy is nutrient 1008.
  - Nothing else is changed. A USDA 0 is a measured value and is kept.
- The match decisions (exact, close with disclosure, none) and their reasons are in planner_map.csv.
- Known effect: USDA lists more energy per 100 g for dry pulses than IFCT (chickpeas 378 vs 287 kcal). With IFCT
  hidden, a 1760 kcal, 140 g protein, lactose-free eggitarian profile no longer meets its targets: 0 of 7 days, against
  7 of 7 on IFCT. The planner reports those days as not meeting target and does not alter values.
