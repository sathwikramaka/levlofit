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
