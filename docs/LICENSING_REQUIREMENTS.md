# Third-party content and data: licensing requirements (2026-10-16, Levlofit-4)

**No licence has been obtained, accepted or purchased.** Status per source, from the repository and the checks
listed. "Verified" means read on the licensor's own page in this or an earlier recorded session; anything else is
marked unverified. A commercial release needs every row marked "Needed before release" cleared in writing.

| Source | Used for (where) | What is known | Needed before release | Who |
|---|---|---|---|---|
| IFCT 2017, National Institute of Nutrition (ICMR) | All 543 foods: energy, macros, 8 micronutrients (migrations 20260929170000_foods_ifct2017, 20261016200000_food_micronutrients; data/build_foods.py, build_food_micros.py) | Values taken from the npm package @ifct2017/compositions 2.0.9, whose **code** is MIT; the **data** is NIN's publication. Reuse permission for a commercial app is **unconfirmed** (GAP_ANALYSIS area 18) | Written permission from NIN for storing and displaying the values in a commercial app, and the exact attribution text | Owner -> NIN |
| INDB (Indian Nutrient Databank) | Considered for recipes/portions; **not imported** | Licence unverified | Licence check before any import | Owner |
| USDA FoodData Central | Not used | Downloads offered: Foundation, SR Legacy (final 2018), FNDDS, Branded. The download and FAQ pages checked on 2026-10-16 state **no licence**; FAQ: no automatic portion conversion, Foundation foods mostly per 100 units. Public-domain status is commonly reported but **not verified here** | Confirm the licence on the dataset's official record before any import; note Indian dishes are poorly covered | Claude can check; owner decides |
| ExerciseDB V1 by AscendAPI | Exercise animations, names, instructions (public.exercises; credit line `exerciseMediaCredit` in app/lib/exercises.dart); the 10 guide identities added 2026-10-16 (app/lib/exercise_guide.dart) | **Verified 2026-10-16** on the API's own OpenAPI description (oss.exercisedb.dev/swagger, "Usage Restrictions"): allowed for personal projects, prototypes, educational tools and non-commercial apps; not allowed for commercial products, SaaS or any monetised use without a paid plan via RapidAPI; 180p GIFs only; strict rate limits; credit to AscendAPI required. Levlofit today: free, no ads or payments, credit shown, so current use is within these terms. The repository holds no copy of the dataset (10 single-id lookups were used only to name moves). | **Before any monetisation** (subscription, ads, paid features): either a paid AscendAPI plan via RapidAPI that covers the planned use, or the full v1 dataset licence offered at go.exercisedb.dev/shop (terms to be read before purchase), or replace `exercises.gif_url` with licensed or own media. Purchase is the owner's decision. | Owner |
| wger | Considered as exercise catalogue | Code AGPL-3.0; data "Creative Commons, see individual entries" (batch AS); terms page bot-protected, not bypassed | Per-entry licence review (CC-BY-SA entries need attribution and share-alike) before any import | Owner / Claude |
| MuscleWiki | Considered (area 17) | Paid API (from about $10/month), terms forbid caching or redistribution (batch AS) | A paid plan whose terms allow the planned use, or another licensed source | Owner (purchase) |
| Google Fonts | App fonts via the google_fonts package (runtime download disclosed in the privacy text) | Fonts are under the SIL Open Font License (verify per family) | Confirm the families used; consider bundling the font files to avoid runtime requests | Claude can prepare |
| Handbook sources (WHO, ACSM, ISSN, NICE, ICMR and papers) | Cited in the handbook and plan engine | Levlofit text paraphrases and cites; 160 claims carry a quoted passage in the evidence register (data/evidence) | Keep quotations short and attributed; reviewer checks that no long verbatim extracts ship in the app | Clinical/legal reviewer |

## What the code already does to stay within these limits

- Every screen with exercise animations shows the ExerciseDB credit (`exerciseMediaCredit`).
- Missing nutrient values are stored and shown as missing, never as zero (pgTAP food_micros; MASTER_CHECKLIST area 18).
- No portion conversions are invented: the diary works in grams only.

## Integration seams for a licensed replacement (no code needed yet)

- Exercise media: the app reads `gif_url` per exercise from public.exercises; a licensed set can replace the URLs (or
  point to Supabase Storage) with one data migration, without app changes. The credit string is one constant.
- Exercise catalogue: session lists in app/lib/session.dart reference catalogue ids; a new source needs an id
  mapping table, reviewed per move (10 prescribed ids still lack an identity, MASTER_CHECKLIST area 12).
- Foods: the foods table has a `code` per source row; a second source would add a source column and its own
  attribution line in the food screens.
