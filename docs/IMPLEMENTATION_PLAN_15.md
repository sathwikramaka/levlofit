# Levlofit: master implementation plan, 15 workstreams

Date: 2026-10-14. Extends the approved 8-requirement plan (2026-10-12) and `docs/PROGRESS.md`. Local work only:
no commit, push, deploy, production migration or production data change. Each stage ends with a report (what
changed, tests actually run and their results, remaining issues, next stage). Backups of edited files go to
`C:\Projects\_backups\levlo-*` before edits; any local schema or data operation is preceded by a verified local
database dump.

## Status of the original eight (from PROGRESS.md)

| # | Workstream | State | Open |
|---|---|---|---|
| 1 | Evidence audit | Register, passages, checks done; Step 1 safety sources recorded (STEP1_SOURCES.md) | Clinical review of all `clinical` rows; blocked sources (EFSA, NICE, ACOG) |
| 2 | Handbook rewrite | v4 draft local; five decisions provisional | Reviewer sign-off; production migration held |
| 3 | Workout engine | Scheduling, kit, injury screen, progression, deloads done | Thresholds are Levlofit rules pending review |
| 4 | Nutrition and workout correctness | Feasibility, fat, duplicates done | Dietitian review |
| 5 | AI provider and evaluation | Adapter and harness done | Live eval needs a key |
| 6 | Grounded retrieval | Done locally | Production deploy |
| 7 | Security, privacy, reliability | Done locally | Not applied to cloud |
| 8 | Regression and delivery | verify.sh + CI workflow | CI never run on a remote |

The evidence and clinical review (1, 2) continues in parallel. It is not complete while `clinical`,
`source_needed`, `source_access` and `content_decision` items stay open, and the handbook is not published.

## New workstreams 9 to 15: what exists, what changes

### 9. BMI calculator fix
- **Exists**: `app/lib/tools.dart` `BmiScreen`, `bmi()`, `bmiBandIndia()` (Misra 2009: 18 / 23 / 25); tab in the
  side menu; `app/test/tools_test.dart` (bands at the boundaries). Engine `plan-engine.ts` `bmiOf` rounds to 1 dp
  then categorises; validates height 120 to 230 cm, weight 30 to 250 kg.
- **Defects found (code reading)**:
  1. The calculator categorises the unrounded value but shows it at 1 dp: BMI 22.96 shows "23.0 · NORMAL", while
     the plan engine calls the same person overweight. Same at 17.96 and 24.96.
  2. Out-of-range or partial input gives no message, only "Enter your measurements" (looks like missing questions).
  3. Accepts 100 to 250 cm and 25 to 300 kg; the rest of the app uses 120 to 230 and 30 to 250.
  4. Prefill comes from the profile only if the dashboard finished loading before the tab opened; opened earlier,
     the fields stay empty for good (controllers are created once).
  5. No age question: adult cut-offs are shown for any input, though they do not apply under 18.
  6. Metric only. Many Indian users know height in feet and inches.
  7. "Edit name, height and weight" silently ignores out-of-range values (no message).
- **Not changed**: the cut-off values. ICMR 2024 (Decision 1) is PROVISIONAL, pending clinical review.
- **Acceptance**: band always matches the displayed 1-dp value and the engine; clear message for each invalid
  field; same ranges as onboarding and engine; prefill after load; age under 18 shows no adult band and a referral
  note; feet/inches and pounds convert correctly; edit-details tells the user why a value was rejected.
- **Files**: `tools.dart`, `dashboard.dart` (tab wiring, edit dialog). **Tests**: `tools_test.dart` (rounding at each
  boundary, unit conversion, age), new widget test for messages and prefill.
- **Risk**: low; no data or schema change.

### 10. Body-fat calculator audit
- **Exists**: US Navy tape method (`navyBodyFat`), ACE bands, waist-to-height; tests for two worked cases.
- **Assessment**: needs 3 to 4 tape measurements taken to a protocol; error commonly cited as 3 to 4 points; ACE
  bands are not population-validated for Indians; the result is not used by the plan. Waist-to-height needs one tape
  measurement and has a stated cut-off (0.5; source to verify, in register as NICE 2022).
- **Recommendation**: replace with a "Waist check" tool (waist-to-height first, body fat as an optional expandable
  estimate), or remove body fat. Owner decision; no change until decided.
- **Risk**: medical-adjacent wording; sources to verify in workstream 1.

### 11. Customisable dashboard
- **Exists**: `_Bento` in `dashboard.dart` with fixed cards: rings, today, level prompt, review alerts, week strip,
  hydration + habits pair, fuel + body pair. `shared_preferences` already used for device settings.
- **Plan**: card ids, a pure `dashboardLayout(saved)` that merges saved order/visibility with the known cards
  (new cards appear, unknown ids dropped), "Customise" sheet with show/hide switches and reorder (ReorderableListView),
  saved per user. Safety cards (review alerts) cannot be hidden. Store: `shared_preferences` keyed by user id first
  (no schema change); a synced table later if wanted.
- **Acceptance**: hide, show, reorder survive restart; reset to default; unknown/new ids handled; tests for the pure
  merge and a widget test for the sheet.
- **Risk**: device-local only (not synced across devices) until a table is added.

### 12. Customisable reminders
- **Exists**: `reminders.dart` (pure `slotsFor`, scheduling via flutter_local_notifications with timezone, web
  in-app ticker, permission request, test notification), `reminder_prefs` table (workout time, water interval,
  weigh-in day), `_SettingsScreen` in `dashboard_tabs.dart` (titled "Your reminders"), drawer entry and profile entry.
- **Plan**: add user-created reminders (name, time, days of week or every day, on/off) alongside the three built-in
  ones. Storage: new table `custom_reminders` (additive migration, RLS own rows, limit 20 per user) applied locally
  only; app tolerates the table being absent. Notification ids in a reserved range (1000+) that cannot clash with
  built-in ids. Edit, delete (with confirm), toggle. Permission: request when the first reminder is enabled; show a
  clear state when denied.
- **Acceptance**: pure tests for slot generation and id ranges; widget test for the editor; pgTAP for RLS and limits;
  migration applied to the local DB after a verified local dump.
- **Risk**: Android exact alarms not used (inexact, as today); iOS 64-pending-notification cap; web is in-app only.

### 13. Exercise library expansion
- **Exists**: `exercises` table (ExerciseDB V1: body_parts, equipment, target_muscles, secondary_muscles,
  instructions; 1,500 rows in production, **0 rows in the local DB**), `ExerciseLibraryScreen` with search and
  body-part filter, `ExerciseScreen` detail. Media licence is non-commercial.
- **Plan**: a curated, reviewed metadata layer for the exercises Levlofit actually prescribes (`session.dart` ids,
  ~150 moves): muscle group, regional emphasis only where the literature supports it (e.g. pectoralis major
  clavicular vs sternocostal head; incline pressing shifts emphasis, does not isolate), equipment, variations,
  short own-words instructions. Wording says "more emphasis on", never "isolates". Additive table or a JSON asset.
- **Blocker**: local DB has no exercise rows; production read needs approval. The prescribed ids exist in code.
- **Risk**: anatomical accuracy needs a qualified reviewer; regional claims go into the evidence register.

### 14. Profile and settings navigation
- **Exists**: profile rows open Protocol, Reminders, Settings as shell tabs; those tabs show the menu button, and
  the back gesture returns to Home, not Profile. Settings opens Glossary the same way.
- **Plan**: a small back stack in the dashboard shell: tabs opened from a page get a back arrow and back gesture to
  the page that opened them; menu navigation resets the stack. Remove the Reminders row from Profile (the dedicated
  Reminders screen stays in the menu).
- **Acceptance**: widget tests: Profile > Settings > back returns to Profile; Settings > Glossary > back to Settings;
  menu navigation shows the menu button.

### 15. Daily rewards
- **Exists**: daily habits (`_habitList`: train-or-rest, water, protein, sleep, steps, mobility, no sugary drinks),
  `habit_logs` table (manual ticks, primary key prevents duplicates), training logs, water logs, weekly streak ring.
- **Plan**: user chooses which habits count toward the daily goal (default: train-or-rest + water); a day is
  "complete" when all chosen tasks are done; planned rest days count as done for training; a daily streak with
  one-per-day reward state derived from the logs (no separate points table, so rewards cannot be duplicated or
  farmed by toggling); celebration animation once per day per device. Honest: manual habits are self-reported.
- **Acceptance**: pure tests: rest day, partial day, untick after reward, timezone day boundary, streak breaks.
- **Risk**: motivational design must not push over-training or under-eating (no rewards for extra sessions or
  calorie cuts; rest days protect the streak).

## Order of local stages

| Stage | Content | Depends on |
|---|---|---|
| S1 | WS 9 BMI fix, WS 14 navigation back stack | none |
| S2 | WS 12 reminders (custom), WS 14 profile entry removal | S1 |
| S3 | WS 11 dashboard customisation | S1 |
| S4 | WS 13 exercise library metadata | owner decision on data access |
| S5 | WS 15 rewards | S3 (dashboard card) |
| S6 | WS 10 body fat (after owner decision) | S1 |
| Parallel | WS 1-2 evidence review continuing (Step 2+) | none |

Each stage runs `bash tools/verify.sh flutter` (analyze + tests) plus the suites it touches, and the handbook
suites stay green. Production file hashes are checked at the end of each stage.

## Status and validation plan (2026-10-15)

> Historical snapshot; superseded on 2026-10-16 by docs/RELEASE_READINESS_AUDIT.md and docs/GAP_ANALYSIS_19.md.
> Kept unchanged as evidence of what was known then.

| WS | State | Automated tests | Visual check (local web) | Still open |
|---|---|---|---|---|
| 9 BMI | Done locally | tools_test (rounding, ranges, age, units, unit-aware messages, widget) | Done at desktop width: prefill, units, messages | Phone-width BMI view; cut-offs await Decision 1 clinical review |
| 10 Waist check | Done locally; body-fat estimate removed | whtrCheck boundaries and units | Done | 0.5/0.6 boundaries (Ashwell 2016, UK adults) need clinical review for Indian adults; "talk to a doctor" wording is clinical-review text |
| 11 Dashboard | Done locally (device-local storage) | layout merge, codec, rows, customiser hide/reset/drag, bento hidden cards | Done: hide persists after reload | Sync across devices needs a table |
| 12 Reminders | Done locally; migration applied to LOCAL DB only | slots, ids, master switch, row codec, editor; pgTAP RLS/limit | Done: create, toggle, delete (DB confirmed) | Native notification delivery on Android/iOS untested (no device); production migration not applied |
| 13 Exercise guide | Done for 33 prescribed moves | coverage of every prescribed id, links, no isolation claims, widget | Done (Chest, Push-up fallback) | 17 ids missing metadata (local catalogue empty); expert review of muscle lists; 3 emphasis claims need sources |
| 14 Navigation | Done locally | back scope widget tests | Done: Profile > Settings > Glossary and back | System back gesture on Android untested |
| 15 Daily goal | Done locally | rewards pure tests, celebration once | Done: card, banner, persistence | Celebration flag is per device |

Visual checks used a local web build pointed at the local stack (verified: no production URL in the bundle), a
local-only test account (tools/local-test-user.txt) and a synthetic plan from the real engine. Remaining manual
checks before any release: Android and iOS builds (notifications, permission prompts, back gesture), phone-width
interaction (the browser pane's mobile emulation blocks input), catalogue animations with real exercise rows.

## Release-readiness audit (2026-10-15)

> Historical snapshot; superseded on 2026-10-16 by docs/RELEASE_READINESS_AUDIT.md and docs/GAP_ANALYSIS_19.md.
> Kept unchanged as evidence of what was known then.

**Verified in this audit (rerun, not carried over):** all 16 verify.sh steps pass: handbook, handbook4, functions
120/120, eval 43 strict, tsc, Deno check/lint/smoke 16/16, pgTAP 24/24 (2 files), Flutter analyze clean and
190/190, website lint, tsc and build. check_step1.py: 45 passages present in their sources, claim wording unchanged.
Backups: S2 and S3 SHA256SUMS verify (5 and 6 files); S1 has no sums file but its copies equal git HEAD (tools_test)
or are pre-edit states; files untouched since HEAD (tools.dart, exercises.dart, reminders.dart) equal HEAD apart
from CRLF. Local DB dump: complete, 24 public tables, taken before custom_reminders. Review flags unchanged.

**Not verified after the final edits:** the local web bundle (built 00:05) predates the last exercise-guide edits
(00:09: "No equipment", versions on the fallback page, list separator), so those three are test-covered only.

**Commit safety:** tools/local-test-user.txt was NOT git-ignored (all of tools/ is untracked); one ignore rule added
(.gitignore backup in levlo-s3 folder). `git add -A --dry-run` now excludes it; no other credential found in tracked
or untracked files. Backups, the local DB, scratch sources and app/build live outside the repo or are ignored.
Note: app/lib/main.dart defaults SUPABASE_URL to the production project, so any `flutter run` without
--dart-define talks to production; local checks must always pass the local URL (verify.sh does not run the app).

### Open before any release

| Area | Item | Depends on |
|---|---|---|
| Device | Android back gesture through Profile > Settings > Glossary; notification permission (allow and deny); built-in and custom reminders firing at time; iOS same; phone-width BMI and Reminders interaction; final exercise-guide tweaks on screen | Android emulator or phone; local build with local defines |
| Evidence | 444 open review items (clinical 150, source_needed 75, source_access 71, content_decision 81, summary_check 127); Step 1: 8 claims not found, 30 partly; EFSA 2010/2015, NICE NG69, ACOG 804 unavailable | Qualified reviewer; manual source downloads |
| Clinical | Decisions 1-4 provisional, Decision 5 applied pending reviewer; caffeine 6 mg/kg vs EFSA 200 mg single dose; heat emergency wording; pregnancy stop signs; eating-disorder referral | Qualified reviewer |
| BMI/waist | BMI cut-offs 18/23/25 unchanged (Decision 1, ICMR 2024 provisional); WHtR 0.5/0.6 from UK adults (Ashwell 2016), NICE source blocked; waist "talk to a doctor" text unreviewed | Clinical review |
| Exercises | 17 prescribed ids without metadata (local catalogue empty); muscle lists pending expert review; 3 emphasis claims need sources | Reviewed catalogue export (needs approval) |
| Production | Migration history mismatch; handbook_v3 applied without record (pre-correction content); 20261013100000 reliability and 20261014100000 custom_reminders not applied; Free plan, no scheduled backups, owner-run backup not yet taken; db push unsafe until reconciled | Owner approval per action; backup first |

### Next three priorities
(Updated 2026-10-15 after the Android attempt: blocked on tooling; see docs/ANDROID_TEST_PLAN.md.)
1. Real-device pass on Android (emulator or phone, local stack): back navigation, notification permission and
   delivery for built-in and custom reminders, phone-width BMI and Reminders, exercise-guide tweaks.
2. Clinical and evidence review handoff: send the reviewer package plus STEP1_SOURCES.md and the new items
   (BMI/WHtR guidance, waist text, muscle lists); obtain EFSA, NICE and ACOG documents manually.
3. Production preflight (no writes): owner runs backup_prod.ps1; then a written, approved forward-only plan for the
   reliability and custom_reminders migrations and the handbook reconciliation.

## Update 2026-10-15 (19-area loop)

The 19-area status is now tracked in docs/MASTER_CHECKLIST_19.md. Done in this loop, all local: food diary (area 18), food diary totals in the coach (area 19), and waist-to-height next to waist history (area 10). Evaluated, waiting on the owner: step counter (area 16, `health` plugin, MIT) and exercise sources (area 12, wger per-entry CC licences). Full regression: all PASS (Flutter 237, functions 124, pgTAP PASS).

## Update 2026-10-16 (batch BQ)

Current numbers: verify.sh all PASS, Flutter analyze clean and 286/286, functions 124, eval 43 strict, Deno 16/16,
pgTAP LOCAL 59/59, website lint/tsc/build. The exercise guide covers 40 prescribed moves; 10 ids still lack an
identity (was 17). The Android device pass ran on a OnePlus 13 (PROGRESS batches BJ-BO), so the device priority above
is done except reminder delivery with the new build, permission revoke and reboot. Seven production items are pending
(docs/MIGRATION_RECONCILIATION.md, "Pending production items"). Release status: docs/RELEASE_READINESS_AUDIT.md.
