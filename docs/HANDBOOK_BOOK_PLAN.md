# Handbook v4: one book (local draft, held for review)

Status 2026-10-14: draft only. Production is unchanged; `supabase/migrations/20261007400000_handbook_v3.sql`,
`data/build_handbook.py`, the v3 evidence registers and `supabase/functions/_shared/handbook-passages.json` are
untouched (a test checks their hashes). Nothing here may be copied into `supabase/migrations/` before review.

## Files
- `data/handbook_v4/build_handbook_v4.py`: imports the v3 content and applies the book edits; writes only
  `data/handbook_v4/handbook_v4_draft.sql` (header: DRAFT FOR REVIEW, NOT A MIGRATION).
- `data/handbook_v4/claims_register.csv`, `sources_register.csv`, `handbook-passages.json`: the v4 evidence register,
  produced with `extract_claims.py --sync --builder data/handbook_v4/build_handbook_v4.py --claims ... --sources ...
  --passages ...`, then `data/handbook_v4/carry_over.py` (review decisions copied from v3 only for identical text).
- `data/handbook_v4/test_book.py` (also `bash tools/verify.sh handbook4`).
- App: `app/lib/handbook.dart` renders the new `part`, `keypoints` and `next` blocks; chapters open by slug from
  "Up next" links; `app/test/handbook_blocks_test.dart`.
- `data/evidence/extract_claims.py`: `ref` (a chapter link) added to the fields that are not claim text.

## Book structure (43 chapters; slugs unchanged; ids renumbered in reading order)
Each part opens with a short part introduction in its first chapter. Every chapter ends with Key points and Up next.

| New id | Part | Slug | Title | v3 id | Part change |
|---|---|---|---|---|---|
| 1 | A | welcome | Welcome to the Handbook | new | new |
| 2 | A | safety-first | Safe to start | 1 |  |
| 3 | A | how-levlofit-works | How Levlofit builds your plan | 38 | E to A |
| 4 | A | how-training-works | How training works | 2 |  |
| 5 | A | cardio-intensity | Easy, moderate and hard cardio | new | new |
| 6 | A | effort-and-rir | How hard to push | 3 |  |
| 7 | A | technique | Learning a lift | new | new |
| 8 | A | warm-up | Warming up | 4 |  |
| 9 | A | sets-reps-progress | Sets, reps and progress | 5 |  |
| 10 | A | rest-between-sets | Rest between sets | 12 | B to A |
| 11 | A | sleep-recovery | Sleep and recovery | 9 |  |
| 12 | B | one-step-at-a-time | One goal at a time | 11 |  |
| 13 | B | tracking-progress | Tracking that tells the truth | 14 |  |
| 14 | B | plateaus-deloads | Plateaus and lighter weeks | 32 | E to B |
| 15 | B | daily-steps | Daily steps | 13 |  |
| 16 | B | habits | Building habits that last | 15 |  |
| 17 | C | food-basics | Food for training | 6 | A to C |
| 18 | C | water | Water, sweat and heat | 7 | A to C |
| 19 | C | carbs-fibre-fats | Carbs, fibre and fats | 19 |  |
| 20 | C | veg-protein | Vegetarian and vegan protein | 20 |  |
| 21 | C | meal-timing | When to eat around training | 21 |  |
| 22 | C | body-measures | Reading your body numbers | 8 | A to C |
| 23 | C | calories | Calories and energy balance | 16 |  |
| 24 | C | fat-loss | Losing fat, keeping muscle | 17 |  |
| 25 | C | muscle-gain | Gaining muscle and weight | 18 |  |
| 26 | C | under-eating | Eating too little | new | new |
| 27 | C | supplements | Supplements that work | 10 | A to C |
| 28 | D | general-fitness | General fitness and heart health | 30 |  |
| 29 | D | build-muscle | Building muscle | 22 |  |
| 30 | D | get-stronger | Getting stronger and powerlifting | 23 |  |
| 31 | D | physique | Building an aesthetic physique | 24 |  |
| 32 | D | calisthenics | Calisthenics | 25 |  |
| 33 | D | mobility | Mobility and yoga | 28 |  |
| 34 | D | kettlebells | Kettlebell training | 29 |  |
| 35 | D | running | Running | 26 |  |
| 36 | D | hyrox | HYROX and functional fitness | 27 |  |
| 37 | E | soreness-pain-injury | Soreness, pain and injuries | 31 |  |
| 38 | E | busy-weeks | Missed sessions, travel and busy weeks | 33 |  |
| 39 | E | home-training | Training at home | 34 |  |
| 40 | E | women | Training as a woman | 35 |  |
| 41 | E | over-40 | Training after 40 | 36 |  |
| 42 | E | mind-motivation | Mood, stress and motivation | 37 |  |
| 43 | E | putting-it-together | Putting it together: your first 12 weeks | new | new |

New: welcome (introduction, map of the five parts, how to read evidence grades and Levlofit rules, glossary, age
scope), cardio-intensity (WHO 0 to 10 effort scale, worked mixed week), technique (six patterns, learning a lift,
labelled Levlofit coaching rules), under-eating (BMR floor, signs to slow down, signs to see a doctor, Tele-MANAS),
putting-it-together (ten principles, sample 12-week journey, after week 12). Part E renamed "Staying with it, for life".

Other content changes: water gains heat guidance and the daily water target (moved from habits); women gains the WHO
pregnancy and postpartum guidance and a plain statement that the app has no after-birth setting; over-40 states the
18 to 80 plan range; worked examples in calories (BMR to target) and food-basics (protein for 60 kg); "workout" changed
to "session" in busy-weeks and soreness-pain-injury (HYROX keeps its official wording).

## Ids, links and references
- Slugs are unchanged and are the stable identifier. Ids follow reading order (1 to 43).
- App: the chapter list sorts by id and opens chapters by id from the same rows, so renumbering is safe; "Up next" opens
  by slug. No other app code, the plan engine or Edge Functions refer to chapter ids. Coach chat reads titles only.
  `goal_catalog.handbook_chapter` (the only foreign key) is null in every row (cloud check 2026-10-13); recheck before
  applying.
- Retrieval passage ids are `slug:bNN` (block index); they change with the new blocks. The draft passages file is
  separate; the deployed function keeps the v3 file until v4 is approved.
- Release order when approved: ship the app update (new block renderers) first; older app builds show nothing for the
  new block types. Then copy the reviewed draft into a NEW migration file and apply it in one transaction.

## Review gates (explicit, none resolved silently)
See the summary in docs/PROGRESS.md (Batch U) and `review_needs` in `data/handbook_v4/claims_register.csv`.
