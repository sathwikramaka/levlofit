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

## 2026-10-24 check (coach actions and Handbook edits)
No new third-party data or media. Coach swaps use only the exercise ids and animations the sessions already used
(ExerciseDB, still non-commercial: unchanged blocker). Meal logging uses the person's own diary foods (IFCT/INDB terms
unchanged: still open). New Handbook source key `efsa_caffeine` is a citation of a public EFSA page, not reused content.

## 2026-10-24 licensed-content mode and source checks (supersedes the ExerciseDB and USDA rows above where they differ)

**Implemented (local tests pass, not yet seen on the phone):**
- Release builds no longer show ExerciseDB content. `exerciseDbContent` in app/lib/exercises.dart is false whenever
  `kReleaseMode` is true; no dart-define can turn it on in a release. In that mode the library shows only the Levlofit
  moves guide, each move page shows Levlofit's own name, muscles, versions and technique cues (`moveCues` in
  app/lib/exercise_guide.dart, written 2026-10-24, pending expert review), the sessions take names from the guide
  without reading public.exercises, and picture tiles show a plain icon rather than a network GIF. Debug and profile
  builds still show ExerciseDB for development. A debug build can preview release mode with
  `--dart-define=LEVLOFIT_EXERCISEDB=false`.
- The coach-chat server no longer reads the catalogue. Swap checks use each move's Levlofit target and kit
  (`MOVES` in supabase/functions/_shared/swap.ts), and lift summaries use the Levlofit labels. Side effect: a stretch
  can no longer replace a lift. That was possible before, when both shared a catalogue target such as "hamstrings".
- Still from ExerciseDB: the public.exercises table, which development builds read. The muscle lists for 10 guide
  moves were taken from catalogue fields; they are facts, not catalogue text, but a reviewer should confirm them.
  The table itself needs an owner decision before the production release: keep it unused, or empty it in a reviewed
  migration.

**Sources checked:**

| Source | Result | Decision |
|---|---|---|
| USDA FoodData Central | **Verified 2026-10-24** on fdc.nal.usda.gov/api-guide/: "public domain", "CC0 1.0 Universal". Requested citation: U.S. Department of Agriculture, Agricultural Research Service. FoodData Central, <year>. fdc.nal.usda.gov. API: 1,000 requests/hour per IP. **Corrects the row above** | Usable. It does not cover most Indian dishes, so it cannot replace IFCT on its own. Importing it means downloading a dataset, which needs the owner's approval |
| IFCT 2017 (ICMR-NIN) | nin.res.in, checked 2026-10-24: footer says "ICMR-National Institute of Nutrition © 2018, All Rights Reserved" and requires written permission for reproducing the website. No IFCT-specific licence found. ifct2017.com could not be fetched (certificate error) | **Still a release blocker.** Per the owner's rule, the diary values stay gated until NIN grants written permission (contact listed: director.nin@icmr.gov.in), or until they are replaced with CC0 FDC values plus Levlofit-measured recipes |
| everkinetic/data (Greg Priday) | LICENSE.md: CC BY-SA 4.0, 293 exercises with SVG and PNG drawings | **Adopted 2026-10-24 (owner-approved download):** 30 unmodified SVGs for 15 moves, from commit 446bb9a, in app/assets/drawings/everkinetic with SOURCE.md (provenance, mapping, checks) and the licence text, which is also on the Licences page. Credit line `drawingCredit`. 3 matched moves have no files in the repository and keep the icon |
| yuhonas/free-exercise-db, wrkout/exercises.json | The repository says Unlicense, but the upstream contributing notes say the images were scraped and the authors do not own their copyright; several issues confirm this | **Rejected** |
| wger | Code AGPL-3.0; per-entry and per-image licences (CC-BY-SA 3/4, CC0, CC-BY 4, ODbL) | Possible future source, entry by entry. Not imported |

### Release-path audit and database plan for public.exercises (2026-10-24, later)

Audit (grep of app/lib, supabase/functions and website/src, plus the phone check below):
- App: every catalogue read (`from('exercises')`) and every `Image.network` GIF sits behind `exerciseDbContent`, which is
  false in release builds. Release builds use Levlofit names (`moveGuide`), cues (`moveCues`) and the bundled drawings.
- Server: coach-chat no longer reads `public.exercises` (swap checks and lift summaries use `MOVES`).
- Privacy: the in-app "Who else handles it" text and website/src/app/privacy/page.tsx no longer name ExerciseDB (test
  `privacy texts no longer name ExerciseDB`). Both texts stay behind their legal REVIEW GATE.
- Phone, 2026-10-24: a debug build with `LEVLOFIT_EXERCISEDB=false` against the throwaway stack showed the dashboard
  tiles, the library, the move pages and the session screen with Levlofit text, Everkinetic drawings and the credit.
  No GIF and no catalogue text appeared. Screenshots were taken locally and not kept in the repo.
- Exercise ids are still the 7-character ExerciseDB ids. An id is a key, not catalogue content, so it stays.

Everkinetic obligations (CC BY-SA 4.0, section 3):
- 3(a)(1)(A) creator and link: `drawingNotice` on the Licences page names Greg Priday, http://everkinetic.com and the
  repository, and states "Used unmodified". The short credit `drawingCredit` is on every drawing screen except the
  dashboard tiles, which credit through the plan's Sources section.
- 3(a)(1)(C) licence: the URI and the full licence text, including its disclaimer, are on the Licences page (test in
  backend_guard_test).
- 3(b) share-alike applies only to adapted material. The files are unmodified, so nothing of Levlofit's is subject to it.
  If a drawing is ever edited (recoloured or cropped into new art), that version must also be released under CC BY-SA.
- No technological measures restrict the files (3(a)/2(a)(5)): they are plain SVG assets in the APK.

Database plan (not applied; it needs the owner's approval as a production migration):
- `set_logs.exercise_id` and `exercise_swaps.from_exercise/to_exercise` reference `public.exercises(id)` **ON DELETE
  CASCADE**. Deleting catalogue rows would therefore delete people's set logs and swaps. Rows must not be deleted blindly.
- Necessary for release: nothing, for the app's behaviour. Release builds do not read the table.
- Recommended before charging money, so that no non-commercial content is hosted: one reviewed migration that
  1. preflights by counting set_logs and exercise_swaps rows whose id is not one of the 50 prescribed moves (expected 0),
  2. for the 50 prescribed ids, sets name to the Levlofit name, empties instructions and secondary_muscles, sets
     gif_url to '' and source to 'levlofit',
  3. deletes the other rows only if the preflight count is 0.

  Rollback is a restore from the pre-migration backup, since the catalogue data is not in the repository. Development
  builds would then lose their ExerciseDB preview, which is acceptable.

### Food data plan (2026-10-24; replaces IFCT for release unless NIN grants permission)

Implemented (local, tested; migration not applied anywhere but disposable stacks):
- `20261025100000_food_sources.sql`: `public.food_sources` records each source's licence, URL, attribution, review date
  and `release_allowed`. `foods.source` and `foods.source_ref` give every row its provenance; soya chunks (X001) are
  recorded as FDC 174275. The `foods` read policy shows app roles only rows from allowed sources, so the app, the diet
  planner and the coach (all reading as the person) never see IFCT values while `ifct2017` is not allowed.
  `supabase/seed.sql` enables IFCT on local stacks only. pgTAP `food_sources.test.sql` (9 checks); full suite 130/130 on
  the disposable stack levlo_mig_fs.
- App: with no visible food row, the diet plan shows the day's calorie and protein targets and the note
  `foodDataPendingText`, and food search says the same instead of "nothing found". Every food credit is now `FoodCredit`,
  which names only the sources whose rows are visible (no hard-coded IFCT credit; test `food_sources_test`).
- `data/build_foods_fdc.py` and `data/fdc/planner_map.csv` build the planner foods from an FDC CSV release:
  - Matches are by exact FDC description, and each must occur exactly once, so nothing is guessed.
  - Only SR Legacy and Foundation records are used, never branded ones.
  - Missing nutrients stay null. Energy comes from 1008, then 2047/2048, else an Atwater estimate flagged as such.
  - "Close" matches carry a disclosure.
  - Tests: `data/fdc/test_build_foods_fdc.py`, 4 cases on synthetic rows. It also runs in verify.sh and CI.

Coverage of the 32 planner foods (map, before the real data confirms each description):
- Exact (22): rice, whole-wheat flour, sorghum flour, red lentils, kidney beans, peanuts, boiled egg, chicken breast,
  banana, papaya, guava, apple, orange, cauliflower, okra, cabbage, spinach, carrot, cucumber, tomato, sunflower oil and
  mustard oil.
- Close, disclosed (6):
  - bajra ("millet", species unnamed)
  - toor and moong (whole seeds, not split dal)
  - kala chana (USDA chickpeas are mostly kabuli)
  - soya chunks (defatted soy flour)
  - whole milk (USDA's is vitamin-D fortified)
- No licensed record (4): poha, ragi flour, paneer and rohu. They are left out of release plans; nothing is substituted.
  The safe alternatives are measured Levlofit recipes (ingredient sums from allowed rows), an INDB or NIN licence, or
  lab values.

Still needed (owner):
1. Approve downloading `FoodData_Central_sr_legacy_food_csv_2018-04.zip` (6.7 MB zipped, 54 MB unzipped) and
   `FoodData_Central_foundation_food_csv_2026-04-30.zip` (3.7 MB, 32 MB) from fdc.nal.usda.gov/fdc-datasets/ into a
   scratch folder outside the repository.
2. Then Claude runs the builder. The new migration `20261025200000_foods_usda_fdc.sql` holds only the extracted values.
   The planner's code mapping is switched to the FDC codes, and the result is tested.
3. Decide whether to write to NIN for IFCT permission (it would restore about 500 Indian foods).

#### Update 2026-10-24 (later): USDA import done locally
- The download was approved and done (sizes and hashes in data/fdc/SOURCE.md).
- Builder fixes found against the real data:
  - three map names corrected (whole-wheat flour, chicken breast, apple)
  - a name present in both releases takes the SR Legacy record
  - carb_g is available carbohydrate (1005 minus 1079), matching IFCT's meaning
  - soya chunks X001 corrected from 33.92 to 16.42 g carbohydrate
- `20261025200000_foods_usda_fdc.sql` (28 rows; pending production item 14). The planner now takes the USDA row for
  each food (`plannerFdcCodes` and `plannerFoods` in app/lib/diet_plan.dart) and falls back to IFCT only where the
  database shows it. In a release, poha, ragi, paneer and rohu drop out.
- Tests:
  - FDC builder 6/6
  - diet_fdc_test 7/7 (map equals the migration; USDA-only planning keeps tags and honest feasibility)
  - pgTAP 134/134 on a disposable stack, since deleted
  - Flutter 426/426
- Not yet covered by USDA: the food library and diary search, which list about 500 IFCT foods. In a release they show
  only the 29 USDA rows plus the pending-data note for anything else. Wider coverage needs more mapped USDA foods,
  Levlofit recipes, or NIN's permission.

### Exercise demonstrations restored on licensed media (2026-10-27)

Cause of the missing animations:
- Every exercise GIF came from the ExerciseDB V1 catalogue: `public.exercises.gif_url`, loaded from
  static.exercisedb.dev by `ExerciseGif` (Image.network). Screens that used it: the library grid, move detail, the
  session move cards and the dashboard/protocol move strips.
- On 2026-10-24 `exerciseDbContent` turned that off in every release build. ExerciseDB's own API page
  (oss.exercisedb.dev/swagger, re-checked 2026-10-27) allows "non-commercial apps" and excludes "Commercial products ...
  or any monetised use without a paid plan", and names no redistribution licence.
- The phone build used for testing was made with `LEVLOFIT_EXERCISEDB=false`, so it showed release behaviour.
- Debug builds still show the ExerciseDB GIFs. No asset or database row was removed.

Implemented (rights verified; details in app/assets/animations/SOURCE.md):
- `MoveDemo` plays from the app bundle and works offline:
  - a public-domain CDC "Growing Stronger" animated GIF for 6 moves: squat, lunge, step-up, incline push-up,
    overhead press and calf raise. Each file is unmodified, its SHA-1 matches Commons, and each was checked frame by
    frame. A caption appears where the GIF differs from Levlofit's description (chair, rail, wall, seated).
  - otherwise the two Everkinetic CC BY-SA drawings shown in turn every 1.2 s, for 13 more moves
  - otherwise a plain icon (31 moves)
- With Android's "remove animations" setting on, the drawings hold one position.
- Credit line `animationCredit`; Licences page `animationNotice`, which covers CDC's conditions: attribution, no
  implied endorsement, no changes, and that the material is free from CDC.
- Excluded after inspection: CDC hamstring stretch (instruction text drawn into the GIF) and chest press (a floor
  press, not a bench press).

Phone check 2026-10-27:
- PASS: the CDC GIF plays, the drawing loop alternates, and the icon fallback works on the library, detail, dashboard
  and session screens; with the backend cut, an open session keeps showing the bundled drawings.
- NOT RUN: a CDC move inside a session (no such move in the test plan), a cold start offline (the app gate stops it
  first), and a missing asset on the device (unit test only).

Trade-offs and limits:
- The Everkinetic drawings are a two-frame loop, not continuous motion.
- 31 moves still show the icon.
- Residual rights risk on the CDC set: it was co-authored with Tufts University and the original CDC page is gone.
  The evidence is the Commons public-domain tags and the CDC Stacks record ("Rights: Public Domain").
- Options not pursued:
  - Lottie and video sources: none with verified per-asset commercial rights were found in this pass.
  - wger: per-entry licences, mostly CC BY-SA; not yet surveyed for animations.
  - Paid ExerciseDB plan: costs money, and its redistribution terms are unverified.

### Levlofit's own figure animations (2026-10-27)

- Free sources re-checked for monetised use: ExerciseDB free tier still excludes "any monetised use without a paid
  plan"; API Ninjas says "Commercial use of the Exercises API is not permitted on the free tier" and its images are
  premium only; wger offers CC BY-SA still images and 78 CC BY-SA 4 real-person videos, no animations.
- So Levlofit now draws its own: ten moves painted in Flutter from code (app/lib/move_animation.dart,
  move_animations.dart). Original work, no third-party art, no download, nothing to license or credit beyond Levlofit.
  Eight guide moves use them; the CDC GIFs and Everkinetic drawings remain for the others. Details, frame checks and
  phone results: docs/EXERCISE_ANIMATIONS.md.
