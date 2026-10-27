# Professional review packages (2026-10-16, Levlofit-4)

**Nothing here has been reviewed by a qualified professional.** Each package lists what to send, what the reviewer
decides, and where the answer goes. Approvals must come from the named profession, in writing, with name and date;
Claude does not mark any item approved.

## 1. Clinician: Handbook evidence, BMI, waist, micronutrients (areas 1, 2, 9, 10, 18)

- Send: docs/handbook_v4_review/ (1_clinical_safety.md, 2_evidence_gaps.md, 3_policy_decisions.md, 4_editorial.md,
  DECISIONS.md, STEP1_SOURCES.md, review_items.csv) and the claim matrix data/handbook_v4/claims_register.csv.
- Matrix status (counted 2026-10-16, 1144 rows): verified 127, partly supported 43, needs source 51, needs better source
  2, needs clinical review 26, unreviewed 290, editorial 339, auto label 262, non-claim 4; 196 rows carry a quoted
  supporting passage. review_items.csv: 444 open items (150 clinical).
- Decide: each review item (accept / change / remove); BMI cut-offs (Misra 2009 vs ICMR 2024, Decision 1); WHtR 0.5/0.6
  for Indian adults; micronutrient targets (none shown today); referral wording; the injury screen (session.dart) and
  progression rules (progression.dart). Documents still needed by the reviewer: EFSA, NICE and ACOG sources.
- Answer goes to: review_items.csv `decision` column, then a new forward-only handbook migration.

## 2. Coach and dietitian: training and nutrition rules (areas 3, 4)

- Training (coach): session-length estimate assumptions (PROGRESS batch BA: 40 s per set, 120/90 s rest, 5 min warm-up,
  1 min per hold, 5 min slack, run blocks not estimated); **the new time fit** (app/lib/session.dart `fitToTime`,
  batch CE: leaves out the last-listed accessory moves until the session fits, never a main lift, never below 3 moves,
  no dose change; tests app/test/session_fit_test.dart); multi-goal priority rules
  (supabase/functions/_shared/plan-engine.ts `planGoals`, curriculum ch. 29); recovery spacing
  (app/lib/week_schedule.dart); deload and progression thresholds.
- Nutrition (dietitian): energy factors (cut 0.85, bulk 1.1), protein 1.4-2.0 g/kg by goal, BMR floor, soya cap 50 g
  (a variety rule, not a safety limit), diet and allergy exclusions, meal feasibility and protein-shortfall messages
  (app/lib/diet_plan.dart), supplement advice wording.
- Decide: keep, change (with the number), or remove each rule; answers go into the code comments and tests.

## 3. Lawyer / privacy reviewer: privacy, account deletion, retention (areas 7, 19)

- Send: website/src/app/privacy/page.tsx and the in-app copy (app/lib/dashboard_tabs.dart `_privacyPolicy`, `_dataUse`),
  website/src/app/delete-account/page.tsx, website/src/app/terms/page.tsx, docs/PLAY_DATA_SAFETY_DRAFT.md.
- Facts already corrected against the code in batch CE (from an independent code audit): name required at sign-up,
  weight goal sent to the AI and weight derivable from the targets, every plan keeps a copy of the answers, feedback
  limits, device-only data, deletion steps incl. during sign-up, partial-deletion outcome, reminders cancelled on
  delete/sign-out, editable fields.
- Decide: the REVIEW GATE paragraphs (AI provider, what it receives), retention periods (provider backups and logs are
  "may" today), DPDP Act wording, whether the AI provider is a "service provider" for Play, the legacy waitlist table,
  and whether the deletion-by-email process needs identity checks beyond "from the signup address".

## 4. Play Console data-safety declaration

- Send: docs/PLAY_DATA_SAFETY_DRAFT.md with the reviewed privacy text.
- Decide: the final answer per data type and purpose; entered in Play Console by the owner only after package 3.

## 5. Licensing (areas 12, 17, 18)

- See docs/LICENSING_REQUIREMENTS.md: NIN (IFCT values), INDB, USDA FoodData Central (licence not verified),
  ExerciseDB media (non-commercial), wger per entry, MuscleWiki (paid). Requests are the owner's to send.

## 6. Additions since 2026-10-16 (prepared 2026-10-24; nothing here is reviewed or approved)

Exact current wording is in `data/build_handbook.py` (Handbook) and `supabase/functions/coach-chat/index.ts` (coach
RULES); each changed Handbook claim is `needs_clinical_review` in `data/evidence/claims_register.csv`.

**Clinician**
1. Caffeine (supplements chapter, owner decision D1): table "About 3 mg per kg (about 200 mg at most at once)"; bars
   "Example dose (3 mg/kg) 210 mg" and "EU single-dose safety level about 200 mg; more at once is above it. Avoid
   caffeine if pregnant, sensitive or on medication". Evidence: ISSN 2021 (3-6 mg/kg for performance), EFSA topic page
   (single doses up to 200 mg). Confirm the cap, and whether the avoid line needs its own source.
2. Waist-to-height (body-measures chapter and app, D2): bands "Healthy" under 0.5, "Above the healthy range: higher
   risk" from 0.5 (the 0.6 edge was removed: no readable source; Misra 2025 uses over 0.5). Confirm for Indian adults.
3. Pregnancy "Stop and seek care" (women chapter, D3): "Bleeding, or fluid that keeps leaking"; "Dizziness or faintness
   that does not settle with rest"; "Chest pain"; "Painful regular contractions"; "Breathlessness that does not settle
   with rest" (headache removed: not in Mottola 2018). Confirm against Mottola 2018 or ACOG and quote the passage.
4. Five passages reworded from abstracts only (rest-between-sets b01, b04; one-step-at-a-time b04, b05; hyrox b04).
   Read the full texts of Grgic 2018 (Sports Med 48:137-151) and Wilson 2012 (JSCR 26:2293-2307) and confirm or correct.
5. Coach rule for confirmed injury facts: "not a diagnosis; plan around it, never say it is healed or safe to push
   through; refer pain that persists or worsens; severe pain, swelling, numbness or a joint giving way: stop and get it
   checked". Lighter-day rule: never offered when the message mentions pain, chest, dizziness, fainting, illness,
   breathing or injury (they get the stop-and-see-a-doctor rule).

**Coach** (area 3)
1. Swap rules: a replacement must be on the app's own move list, train the same target muscle, fit the person's
   equipment, and not be set aside for a reported injury area (session.dart `moveLoads`; with an unmapped injury only
   moves set aside for nothing). Confirm the set-aside table (unchanged since 2026-10-17, still unreviewed).
2. Lighter day: one set fewer on every move with more than one set, every set ending with 3 or more reps in reserve.
3. Moving a session: only to a later free day of the same Monday-to-Sunday week; reminders keep their usual days.
4. Deload: the engine has no deload rule (owner decision D4: none for now). Advise whether one is needed.

**Dietitian** (area 4)
1. Meal logging by the coach: items only from foods already in the person's diary that fit their diet exclusions,
   1 to 2000 g each, one meal, at most 6 items; logged only when the person taps Log it.
2. Diet-feasibility property test scope (40 seeded profiles: energy 1400-3200 kcal, protein 60-200 g, budget tiers
   1-3, four diets, peanut/soy/dairy/tree-nut exclusions): confirm these ranges are the ones that matter.

**Lawyer / privacy reviewer** (areas 7, 19)
1. New privacy text (website /privacy inside the REVIEW GATE, and the in-app policy): the rolling chat summary
   (stored with the chat; the summary request sees only that chat), today's moves and checked replacements, this
   week's free days, names of up to 30 foods from the person's own diary, and stored offered or confirmed session
   changes (deleted with the account; pgTAP-tested).
2. Coach memory (batch 2U-2V) disclosure on the Memory sheet and injury suggestion card.
