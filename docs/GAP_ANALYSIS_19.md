# Levlofit final gap analysis: 19 work areas (2026-10-16)

Evidence base (updated 2026-10-16, batch BQ): current working tree (31 modified + 64 untracked paths, nothing
committed since daaea96), docs/PROGRESS.md (batches J to BQ), docs/RELEASE_READINESS_AUDIT.md and the test run under
"Test evidence". Nothing here has been deployed or run against production.

Verification levels (kept separate; none implies the next): **Local** = implemented and passing local tests
against the isolated local stack; **Device** = exercised on the owner's OnePlus 13 with a local build; **Reviewed** =
signed off by a qualified external professional (none yet); **Licensed** = third-party data or media cleared for
commercial use; **Production** = deployed to the live project and smoke-tested (none yet). Release-ready needs every
level that applies to the area.

No area is release-ready: every area still needs at least one of production deployment, device testing or external
review, as listed below.

Remaining work types: **Impl** = implementation, **Auto** = automated verification, **Device** = testing on a phone,
**Review** = external (clinical, coach, dietitian, legal, privacy, licensing) or owner decision.

| ID | Area | Local | Device (OnePlus 13) | Reviewed | Licensed | Production | Remaining work and who |
|---|---|---|---|---|---|---|---|
| 1 | Handbook audit | Blocked (checks pass) | n/a | No: 444 open items, clinical 150 | n/a | No | Qualified clinician; EFSA, NICE, ACOG documents (owner) |
| 2 | Handbook rewrite | v4 draft local, tests pass | n/a | No: Decisions 1-5 provisional | n/a | No (v3 partly applied, unrecorded) | Clinician sign-off; owner-approved forward-only migration |
| 3 | Training engine | Partial: estimate + notice (session_time_test 8) | Not exercised (dashboard only, A1) | No: coach review of batch BA | n/a | No | Coach review; then owner decides on time-budget trimming |
| 4 | Workout/nutrition rules | Partial: rules + tests | Diary totals on device (Part B) | No | n/a | No | Dietitian and coach review |
| 5 | AI provider | Adapter + offline eval 43 | n/a | n/a | n/a | No | Owner supplies API key; provider data terms |
| 6 | Grounded retrieval | Complete (functions 124) | Coach chat not exercised | n/a (content via 1/2) | n/a | No | Deploy functions (owner); live answers need area 5 |
| 7 | Security, privacy | Partial: RLS, pgTAP 59, secret scan, anon revoke | n/a | No: privacy text behind REVIEW GATE | n/a | No | Legal/privacy review; production backup and reconciliation |
| 8 | Regression, delivery | verify.sh all PASS; CI DB job verified locally | Part A 13/13, Part B 7/7, BO 3/3 | n/a | n/a | No CI run (no remote) | Owner creates remote and approves commits; reminder delivery, revoke, reboot untested |
| 9 | BMI | Complete | Not exercised | No: cut-offs (Decision 1) | n/a | No | Clinician |
| 10 | Waist | Complete | Waist line verified (B7) | No: WHtR 0.5/0.6 for Indian adults | n/a | No | Clinician |
| 11 | Custom dashboard | Complete | Not exercised | n/a | n/a | No | Optional device check |
| 12 | Exercise library | Partial: 40 moves; 10 ids without identity | Mobility and pose detail (A8-A10) | No: muscle lists | **No: ExerciseDB media non-commercial; wger per-entry** | No | Expert; licensed media or catalogue source (owner) |
| 13 | Reminders | Partial | 12 alarms re-registered (A13); delivery measured 2026-10-15 | n/a | n/a | No | Owner decision on alarm-clock mode; delivery re-test |
| 14 | Profile and settings | Complete | Back gesture passed | n/a | n/a | No | none |
| 15 | Daily rewards | Complete | Not exercised | n/a | n/a | No | Optional device check |
| 16 | Step counter | Blocked (no code) | n/a | n/a | n/a | No | Owner approval: plugin, Health Connect permissions, Play declaration |
| 17 | MuscleWiki | Blocked | n/a | n/a | No: paid API, no caching | No | Owner: paid plan or another source |
| 18 | Food diary | Partial: diary, micros, recipes, edit, search | Part B 7/7 + BO fibre line | No: micronutrient targets | **No: IFCT (NIN) reuse unconfirmed; INDB licence unverified** | No | NIN and INDB answers; clinician on targets |
| 19 | AI coach | Partial | Not exercised | No: privacy review gate | n/a | No | Areas 5, 7, 16 |

## Local visual check (owner-approved, 2026-10-16; details in PROGRESS batch BD)

- Verified in the local web build: food diary empty state and targets, food search (IFCT, Hindi names, no-match
  state), weight validation, recipes empty state, recipe editor validation and ingredient sheet, Mobility group and
  pose detail, session screen without the notice, Progress without a waist reading.
- Found (fixed in batch BE): recipe editor name error overlaps the next field's label; stale name error; editor discards input
  without asking; recipe screens not width-constrained on desktop; title-cased 'A Strap Or Towel'; exercise detail
  blames the connection when the local catalogue is empty.
- Not visually verified (needs a database write, the catalogue, or stopping the stack): populated diary, vitamins and
  minerals totals, entry edit dialog, recipe list and log dialog, waist-to-height line with data, over-time notice,
  offline and error states. Covered by widget tests, pgTAP and local REST checks only.
- All six findings fixed and re-checked in the local web build (PROGRESS batch BE).
- Controlled data test (owner-approved, PROGRESS batch BF): populated diary, vitamins and minerals totals and
  missing-value note, entry edit, recipe creation, recipe logging and the waist-to-height line all verified on screen
  against SQL-computed values; the 10 test rows were removed by id and the four tables match the pre-test fingerprints.
- Both minor findings fixed (PROGRESS batch BG): comma/space-normalised food search; stable newest-first diary order.
  The Food library's client-side filter now uses the same normalisation (batch BH).
- Still not visually verified: over-time notice (needs a catalogue and a session-length change, both excluded by the
  owner), offline/error states (would need stopping the stack). Covered by widget tests only.
- Android device pass (PROGRESS batches BJ-BM, OnePlus 13, profile build, local stack via USB): Part A 13/13 and
  Part B 7/7 passed; test rows removed by id, tables match the pre-test fingerprints. Minor device-only findings: unit
  wrap in the macro line, keyboard reopening after the ingredient sheet, truncated Progress stat labels.
- Still untested on device: reminder delivery with this build, permission revoke, reboot (phone-setting changes).
- The three minor device findings are fixed (PROGRESS batch BN) and verified on the OnePlus 13 (batch BO).
- Next checkpoint: the external reviews and the production steps (backup, reconciliation, migrations, function
  deploy, release signing, CI on GitHub).

## Test evidence (local, 2026-10-16, batch BQ)

tools/verify.sh all PASS: handbook (register, freshness 477/533 reviewed, migration = builder), functions node 124/124,
offline eval 43 strict, strict tsc, Deno check/lint/smoke 16/16, Flutter analyze clean and 286/286, website
lint/tsc/build; handbook4 OK; pgTAP LOCAL 59/59 (6 files). Production: nothing deployed, nothing verified.

## Release classification (2026-10-16, Levlofit-4)

Categories: **Ready** = no open item of its own (still ships only with the signed build and the production steps in
docs/RELEASE_CHECKLIST.md); **Incomplete** = local work or a device check is missing; **External decision** = owner
decision, credential, purchase or licence; **Professional review** = clinician, coach, dietitian or legal sign-off.
No area is release-ready today: the production backup, migrations, function deploy and signed build are outstanding
for all of them.

| ID | Area | Class | What exactly is missing |
|---|---|---|---|
| 1 | Handbook audit | Professional review | Clinician on 444 items; EFSA, NICE, ACOG documents |
| 2 | Handbook rewrite | Professional review | Clinical sign-off of v4; Decisions 1-5 provisional |
| 3 | Training engine | Professional review + External decision | Coach review of batch BA assumptions; owner decides on time-budget trimming |
| 4 | Workout/nutrition rules | Professional review | Dietitian and coach |
| 5 | AI provider | External decision | API key, provider data terms, live evaluation |
| 6 | Grounded retrieval | External decision | Function deploy approval; live answers need area 5 |
| 7 | Security, privacy | Professional review + External decision | Legal review of privacy text, retention, /delete-account; production backup and reconciliation |
| 8 | Regression, delivery | External decision + Incomplete | Git remote and CI run; device reminder delivery, revoke, reboot (no phone connected 2026-10-16) |
| 9 | BMI | Professional review + Incomplete | Cut-offs (clinician); not exercised on the phone |
| 10 | Waist | Professional review | WHtR boundaries for Indian adults |
| 11 | Custom dashboard | Incomplete | Device check only |
| 12 | Exercise library | External decision + Professional review | Licensed media/catalogue (ExerciseDB non-commercial), 10 ids, expert review |
| 13 | Reminders | External decision | Alarm-clock mode decision; delivery re-test on the signed build |
| 14 | Profile, settings | Ready | none of its own |
| 15 | Daily rewards | Incomplete | Device check only |
| 16 | Step counter | External decision | Health Connect approval and Play declaration (no code) |
| 17 | MuscleWiki | External decision | Paid plan or another licensed source |
| 18 | Food diary | External decision + Professional review | NIN (IFCT), INDB licence; micronutrient targets |
| 19 | AI coach | External decision + Professional review | Areas 5, 7, 16 |

Local evidence for this classification (2026-10-16): tools/verify.sh 15/15 PASS (Flutter 286/286, pgTAP LOCAL
PASS); debug-signed local release APK builds; /delete-account page builds and renders at 375 px. Nothing here has
been deployed or reviewed externally.

## Update after batch CE (2026-10-16, local evidence only)

| ID | Change in CE | Class now |
|---|---|---|
| 3 | Sessions fit the person's minutes (fitToTime; 8 exhaustive tests); multi-goal priority, days and recovery spacing already tested | Professional review (coach: estimate assumptions and the time-fit rule) |
| 5 | Live eval reports retries, error kinds, tokens and cost from owner-entered prices; still no key | External decision (key: LLM_API_KEY, optional LLM_PROVIDER/LLM_MODEL/LLM_BASE_URL, prices LLM_PRICE_INPUT_PER_MTOK/OUTPUT) |
| 7 | check_rate limit-reset hole fixed (HIGH), food_log day range, delete-account final sweep, coach race/UUID, exclusion caps; privacy texts corrected to the code; fresh-DB pgTAP 63/63 | Professional review (legal) + production gates |
| 8 | Flutter 300/300, functions 132, eval 43, Deno 16, website, handbook; fresh-DB pgTAP 63/63; dev-DB pgTAP shows the 6 new assertions failing until the dev DB gets the fixed functions | External decision (remote, CI, phone) |
| 11, 15 | Switches labelled for screen readers; +250 ml guarded; rewards day boundaries checked (no defect) | Incomplete: device check only |
| 13 | Reminders cancelled on delete and sign-out; a failed read no longer cancels custom alarms or offers savable defaults; apply serialised | External decision (alarm-clock mode) + device delivery test |
| 14 | Delete account during onboarding; blocking progress while deleting; sign-out clears reminders | Ready (none of its own) |
| 18 | Diary stale-response guard; weigh-in no longer saves an old weight; food_log day range | External decision + professional review (unchanged blockers) |
| 19 | Concurrent duplicate returns the saved turn; context exclusions capped; set dates local | External decision + professional review |
| 16, 17, 12 | docs/STEP_COUNTER_PLAN.md and docs/LICENSING_REQUIREMENTS.md prepared; no code by design | External decision |

## Reconciliation after batches 2A-2C (2026-10-16, code + current test evidence)

Classes: **Complete locally** = implemented and covered by passing local tests (not release-ready: production steps,
signed build and device pass still apply to all); **Partial** = local implementation incomplete; **Blocked** = the next
step needs something external. **Release-ready: none.** Evidence: Flutter 337/337 + analyze clean (2C), functions 136,
eval 43, Deno 16 (2A), fresh-DB pgTAP 63/63 (CE), website and handbook PASS (CE).

| ID | Area | Status | What is needed from outside |
|---|---|---|---|
| 1 | Handbook audit | Blocked | Clinician (444 items); EFSA, NICE, ACOG documents |
| 2 | Handbook rewrite | Blocked | Clinical sign-off of v4 |
| 3 | Training engine | Complete locally (2B, 2C) | Coach review of estimate (BA) and add-on rules (2B); owner: should a rest-day add-on count toward the days ring/streak |
| 4 | Workout/nutrition rules | Complete locally | Dietitian and coach review |
| 5 | AI provider | Blocked | Owner's API key and provider data terms |
| 6 | Grounded retrieval | Complete locally | Function deploy (production approval) |
| 7 | Security, privacy | Complete locally | Legal review; production backup, migrations (dev DB refreshed in 2D, pgTAP 63/63) |
| 8 | Regression, delivery | Complete locally | Git remote + CI run; signed build |
| 9 | BMI | Complete locally | Clinician (cut-offs) |
| 10 | Waist | Complete locally | Clinician (WHtR) |
| 11 | Dashboard | Complete locally | Phone check |
| 12 | Exercise library | Partial (code complete; 10 ids lack catalogue data, 2E) | Production export or OK to fetch ExerciseDB V1 for 10 ids; licensed media; expert review |
| 13 | Reminders | Complete locally | Owner: alarm-clock mode; phone delivery/revoke/reboot test |
| 14 | Profile, settings | Complete locally | none of its own |
| 15 | Daily rewards | Complete locally | Phone check |
| 16 | Step counter | Blocked | Owner approval: plugin, Health Connect, Play declaration |
| 17 | MuscleWiki | Blocked | Paid licence or other source |
| 18 | Food diary | Complete locally | NIN (IFCT) and INDB licences; clinician on targets |
| 19 | AI coach | Complete locally (data-use gate 2E) | API key + LLM_DATA_APPROVED (5), privacy review, deploy |

Owner decisions found during reconciliation (not changed): app/lib/main.dart defaults SUPABASE_URL to production for
any build without --dart-define; anon still holds USAGE/SELECT/UPDATE on 4 public sequences (a fix would be an 8th
production migration).

## Reconciliation after batch 2F (2026-10-16): the seven remaining areas

Same classes as above. Release-ready: none. Evidence: functions 161, eval 43 strict, Deno 16, Flutter 363/363,
handbook and website PASS; Android default and Health Connect builds inspected (no phone).

| ID | Area | Status | Implemented and tested locally | What is still needed from outside |
|---|---|---|---|---|
| 1 | Handbook audit | Partial (blocked) | Rounds 5-6: 36 claims vs abstracts; 21 unsourced claims searched (8 verified, 3 partly) | Clinician (117), owner decisions (82), editorial review (135), paywalled full texts (source_access 70), 10 evidence claims still without a source |
| 2 | Handbook rewrite | Partial (blocked) | Evidence-required rewordings in the v4 draft | Clinical sign-off; v4 production migration (approval) |
| 5 | AI provider | Complete locally | Approval gate, fallback, deadline, reply validation, benchmark record | API key, provider data terms, live benchmark |
| 12 | Exercise library | Complete locally | 10 identities, naming defect fixed, injury map | Expert review; commercial licence before monetisation |
| 16 | Step counter | Complete locally (flagged off) | Dart and Kotlin, builds verified | Owner approvals, phone tests, Play declaration, legal text |
| 17 | Exercise knowledge and licensing | Complete locally | 2 cited evidence notes; terms verified | Licences for commercial use; 1 claim without an open source |
| 19 | AI coach | Complete locally | Lifts and consented steps, minimised and validated | Key, deploy, legal review of the updated texts |

## Implementation checkpoint after batch 2H (2026-10-17): all 19 areas

Every authorized local implementation item is done; the one local item left that is not implementation is running the
new pgTAP assertion and migration (Docker engine would not start), which belongs to consolidated testing. Release-ready:
none. Evidence this batch is targeted only (handbook 4/4, functions 162, eval 43 strict, tsc, Deno 16/16 with the frozen
lock, Flutter analyze + 41/41 + 22/22); the consolidated regression has not been run and waits for the owner.
Owner decisions resolved since the 2A-2C reconciliation: the production default in main.dart (2E: opt-in only) and the
anon sequence grants (2H: migration written, not run).

| ID | Area | Status | Implemented locally (evidence) | Remaining implementation | External dependencies |
|---|---|---|---|---|---|
| 1 | Handbook audit | Local work done; blocked | Rounds 5-7 against downloaded texts; 518/533 v3 claims reviewed, 203 with a quoted passage; handbook checks 4/4 | None that open sources allow | Clinician (117 items); owner policy (82, incl. Decision 5); editorial reviewer (135); paywalled full texts (56 evidence items read on abstracts only); 12 evidence claims need a source (6 have none: owner picks source, labelled Levlofit rule, or removal) |
| 2 | Handbook rewrite | Local work done; blocked | v4 draft with every evidence-required rewording; v3 migration byte-identical | None | Clinical sign-off; Decisions 1-5; v4 production migration (approval) |
| 3 | Multi-goal engine | Complete locally | Multi-goal days, add-on blocks, time fit, recovery notices (2B/2C tests) | None | Coach review of estimates and block rules; owner: does a rest-day add-on count for streaks |
| 4 | Workout/nutrition correctness | Complete locally | Diet feasibility, fat, week tests; every prescribed move in the injury map (2H, 41/41) | None | Dietitian and coach review |
| 5 | AI provider | Complete locally | Adapter, approval gate (provider and provider@host), fallback, shared deadline, reply validation, offline eval 43 strict, benchmark --out | None | API key; provider data terms; LLM_DATA_APPROVED; live benchmark (never run; no results exist) |
| 6 | Grounded retrieval | Complete locally | Handbook passages in coach context; eval 43 strict | None | Function deploy (approval); needs area 5 |
| 7 | Security, privacy, reliability | Complete locally, one test unrun | RLS, pgTAP 63/63 (CE), check_rate fix, delete-account sweep, data-use gate; anon-sequence migration + assertion written (2H) | Run the new pgTAP assertion and migration locally once Docker starts (consolidated testing) | Legal review of privacy texts (REVIEW GATEs); production backup; 8 production migrations (approval each) |
| 8 | Regression tests, safe delivery | Complete locally; consolidated run pending | verify.sh and CI with frozen Deno lock; targeted suites green in 2H | Consolidated regression (every verify.sh step incl. db: full Flutter, website, pgTAP) on the owner's word | Git remote and first CI run; signed build; phone pass |
| 9 | BMI | Complete locally | BMI tests | None | Clinician on cut-offs; phone check |
| 10 | Waist-to-height, measurements | Complete locally | WHtR line verified on phone (BO) | None | Clinician on WHtR for Indian adults (NICE text returned 403) |
| 11 | Customizable dashboard | Complete locally | Dashboard layout tests | None | Phone check |
| 12 | Exercise library | Complete locally | All ids identified; I3tsCnC = hanging leg raise with kit swap (2H) | None | Expert review of muscle lists; ExerciseDB media is non-commercial (commercial licence before monetising); wger per-entry licences |
| 13 | Custom reminders | Complete locally | Reminder tests; delivery measured on phone 2026-10-15 | None | Owner: alarm-clock mode; phone delivery, revoke and reboot with the release build |
| 14 | Profile and settings | Complete locally | Navigation tests; back gesture verified on phone | None | None of its own |
| 15 | Daily rewards | Complete locally | Rewards tests | None | Phone check; owner decision shared with area 3 |
| 16 | Step counter | Android complete locally (flag off by default); iOS not started | Permission, denial, revoke, stale data, account isolation, resume refresh, R8 keep rule; steps 22/22; default and flagged builds inspected | iOS HealthKit bridge (needs a Mac with Xcode; cannot be built here) | Owner approvals (STEP_COUNTER_PLAN.md); 18 phone checks (STEP_COUNTER_DEVICE_CHECKLIST.md); Play health declaration; legal text |
| 17 | Exercise knowledge, licensing | Complete locally | 2 cited evidence notes; licensing requirements documented (LICENSING_REQUIREMENTS.md); unsupported claim hidden | None | Commercial licences (ExerciseDB, wger entries); MuscleWiki not used (paid) |
| 18 | Food diary, nutrition | Complete locally | 730-day window, micros, recipes, edit, search; verified on phone (Part B, BO) | None | NIN permission for IFCT reuse; INDB licence; clinician on targets |
| 19 | Unified AI coach | Complete locally | Grounded handbook, lift summaries, consented steps (strict schema), minimised context, consent gate, reply validation | None | Areas 5 and 7 externals; deploy; legal review of updated texts |

## After batch 2I (2026-10-17): fresh-database test, consolidated regression, phone pass

Implementation, testing and production readiness are separate. Production-ready: none. Every authorized local
implementation item is done except the iOS HealthKit bridge, which needs a Mac with Xcode (not available). Evidence:
consolidated regression all steps PASS (Flutter 378/378), pgTAP 64/64 on fresh throwaway databases, phone checks as
listed. Five defects were found on the phone and fixed in this batch (see PROGRESS 2I).

| ID | Area | Implementation | Automated tests (local, 2026-10-17) | Phone (OnePlus 13, Android 16) | Remaining local work | External dependencies |
|---|---|---|---|---|---|---|
| 1 | Handbook audit | Done as far as open sources allow (rounds 5-7) | Handbook 4/4; 518/533 claims reviewed, 203 with a quoted passage | n/a | None | Clinician (117); owner policy (82, incl. Decision 5); editor (135); 56 claims read on abstracts only; 12 claims need a source (6 have none) |
| 2 | Handbook rewrite | v4 draft with every evidence-required rewording | handbook4 draft tests PASS | n/a | None | Clinical sign-off; Decisions 1-5; v4 production migration |
| 3 | Multi-goal engine | Complete; 2I adds the 'days_fewer' explanation | Engine 22/22 (functions 163) | Onboarding x3 built plans on a local stack | None | Coach review; owner: rest-day add-on and streaks |
| 4 | Workout/nutrition | Complete; every prescribed move in the injury map | Flutter suite; engine bounds tests | Plan review shown | None | Dietitian and coach review |
| 5 | AI provider | Complete (gate incl. provider@host, fallback, deadline, validation, benchmark output) | Functions 163, eval 43 strict, tsc, Deno 16 | Not exercised (no key) | None | API key; provider data terms; LLM_DATA_APPROVED; live benchmark never run |
| 6 | Grounded retrieval | Complete | Eval 43 strict | Not exercised | None | Function deploy; area 5 |
| 7 | Security, privacy | Complete; anon-sequence migration tested | pgTAP 64/64 on two fresh local DBs; negative check fails as expected | n/a | None | Legal review of privacy texts; production backup; 8 production migrations (one approval each) |
| 8 | Regression, delivery | Complete; frozen Deno lock; 360 dp layout tests; setState guard test | Consolidated regression PASS (see evidence) | Phone pass done for the parts below | None | Git remote and first CI run; signed build |
| 9 | BMI | Complete | Flutter tests | Shown on plan review (23.7, Asian cut-off) | None | Clinician on cut-offs |
| 10 | Waist-to-height | Complete | Flutter tests | Shown on plan review (0.48) | None | Clinician on WHtR for Indian adults |
| 11 | Dashboard | Complete; 2I fixed 360 dp layout and the week-strip label | Dashboard tests 29/29 at 390 and 360 dp | Cards render; customise not exercised | None | None of its own |
| 12 | Exercise library | Complete | Flutter tests | Media not exercised (throwaway DB has no catalogue) | None | Expert review; ExerciseDB media non-commercial; wger per-entry licences |
| 13 | Reminders | Complete | Flutter tests | Delivery not re-run this batch | None | Owner: alarm-clock mode; phone delivery/revoke/reboot with the release build |
| 14 | Profile, settings | Complete | Flutter tests | Profile screen and sign-out PASS | None | None of its own |
| 15 | Daily rewards | Complete | Flutter tests | Daily goal card renders | None | Owner decision shared with area 3 |
| 16 | Step counter | Android complete (flag off by default); 2I fixed the Android 14+ permission crash. iOS: not implemented | steps 22/22 | 11 pass, 1 partly, 6 not run (STEP_COUNTER_DEVICE_CHECKLIST.md) | iOS HealthKit bridge (needs a Mac with Xcode; not possible here) | Approval for deny path, reboot, debug-signed release check; Play health declaration; legal text |
| 17 | Exercise knowledge, licensing | Complete | Flutter tests | n/a | None | Commercial licences; MuscleWiki not used |
| 18 | Food diary | Complete | Flutter tests | Verified earlier (Part B, BO); not re-run | None | NIN (IFCT) permission; INDB licence; clinician on targets |
| 19 | Unified AI coach | Complete | Functions and eval | Not exercised (no key); steps sharing switch only | None | Areas 5 and 7; deploy; legal review |

## After batch 2J (2026-10-17): approved phone checks

Changes to the 2I table: area 16 phone checks now 15 pass, 1 partly, 2 not run (deny path, reboot and the R8 release
build all PASS); area 14 gains a Sign out escape for a session whose account no longer exists (defect found on the
phone, fixed and verified). Flutter 379/379. Still not implemented: iOS HealthKit bridge (needs a Mac with Xcode).
Production-ready: none.

## After batch 2K (2026-10-17): gap closure and fresh results

| Layer | Status |
|---|---|
| Implementation | Done for all 19 areas except the iOS HealthKit bridge (area 16; needs a Mac with Xcode; not written) |
| Automated tests | Current: verify 16/16 PASS, Flutter 379/379, functions 163, eval 43, Deno 16, pgTAP 64/64 (fresh DB) |
| Phone (Android 16) | Steps 15 pass, 1 partly, 2 not run; reminders delivered in a release build; onboarding, dashboard, profile, sign-out checked |
| External approval | See docs/OWNER_DECISIONS.md (15 items) plus clinician, dietitian, coach, legal and licence reviews |
| Production readiness | None: no production migration, deploy, store-signed build, hosting or professional sign-off |

## After batch 2L (2026-10-18): owner decisions applied

Areas 1 and 2: handbook content changed per the owner's decisions (caffeine example and unsupported claims removed,
practical items labelled); reviewer still confirms each label. Area 5/19: provider comparison prepared, no provider
chosen. Area 7: rate limits confirmed as provisional. Areas 3, 13, 15, 16: behaviour confirmed as is (no code change).
Implementation still missing: iOS HealthKit only. Fresh-DB database tests not re-run after the v3 migration file
changed (Docker down). Production-ready: none.

## After batch 2N (2026-10-18)

Fresh-DB database tests re-run after the handbook change: 34 migrations, pgTAP 64/64 PASS; new expected handbook hash af1ea000 recorded in the runbooks. Handbook, functions and Deno suites PASS. Production-ready: none.

## After batch 2O (2026-10-22)

Area 13 (reminders): double delivery after an early alarm fixed in a patched plugin copy, unit-tested (4/4, fails without
the fix); reboot and package-update keep alarms (phone PASS); device timing after the fix not re-verified. Area 16: stale
label code gap fixed; device check 15 blocked. Areas 12, 17, 18: licence register written; IFCT needs NIN permission.
Area 5/19: provider comparison and recommendation, not chosen. Areas 1/2: evidence round 8. Production-ready: none.

## After batch 2P (2026-10-22)

Area 16 completion criteria now cover Android only: iOS HealthKit deferred by the owner (no Apple device). Area 13:
plugin fix unit-tested, device timing after the fix unverified. Remaining implementation gaps for local use: none known;
open items are verification on the device, professional and legal review, licences, and the provider choice.

## Status 2026-10-24 (after commit efc2c02; evidence in PROGRESS.md entries dated 2026-10-22 to 2026-10-24)

| # | Area | Status | Evidence | What is left |
|---|---|---|---|---|
| 1 | Handbook audit | Blocked (external) | register check 521/526 reviewed by AI, 0 shipped passages unreviewed (guard test) | Clinician review of clinical items |
| 2 | Handbook rewrite | Blocked (external) | v3 builder = migration (b3b87df6); v4 draft tests | Clinician sign-off; v4 decisions 1-5 |
| 3 | Training engine | Implemented, not fully verified | engine tests + 600-plan property test; swap/lighter/move rules tested | Coach review; device pass |
| 4 | Workout/nutrition rules | Implemented, not fully verified | diet-feasibility property test (40 profiles x 2 days); engine property test | Dietitian and coach review |
| 5 | AI provider | Blocked (external) | adapter, offline eval 80/0 strict | Key, data terms, live eval |
| 6 | Grounded retrieval | Complete and verified locally | Handbook tests 22/22, paraphrase eval cases, unreviewed-citation guard | Live answers need area 5; function deploy |
| 7 | Security, privacy | Implemented, not fully verified | pgTAP 121/121 (RLS, server-only writes, deletion cascade), log-privacy and privacy-text guard tests | Legal review; production backup and reconciliation |
| 8 | Regression, delivery | Implemented, not fully verified | verify.sh suites pass locally | Git remote and first CI run; device reminder re-test |
| 9 | BMI | Blocked (external): clinician | tool tests; **phone PASS 2026-10-24**: 175 cm/72 kg = 23.5 Overweight, 60 kg = 19.6 Normal (Asian-Indian cut-offs) | Clinician on cut-offs |
| 10 | Waist | Blocked (external): clinician | single band from 0.5 (D2); **phone PASS 2026-10-24**: 80/175 = 0.46 no increased risk, 90/175 = 0.51 above the healthy range | Clinician on WHtR for Indian adults |
| 11 | Custom dashboard | Complete and verified locally and on the phone | Flutter tests; **phone PASS 2026-10-24**: Water tile off hides the card, on restores it, the setting survives an app restart | none of its own |
| 12 | Exercise library | Implemented and verified on the phone (licensed mode) | Release mode shows Levlofit names, muscles, cues and the Everkinetic drawings (15 moves), no ExerciseDB content. **Phone PASS 2026-10-24** (debug build with LEVLOFIT_EXERCISEDB=false, throwaway): dashboard tiles, library, move pages, session screen. A phone defect (cut-off version names) was fixed and re-verified | Expert review of cues and muscles; drawings for the other 35 moves |
| 13 | Reminders | Blocked (external) | plugin patch, reminder tests | Alarm-clock mode decision; delivery re-test on device |
| 14 | Profile and settings | Complete and verified locally | Flutter tests; back gesture passed on device | none of its own |
| 15 | Daily rewards | Implemented; display verified on the phone | Flutter tests; **phone 2026-10-24**: the card reads "1 of 2 today" on a rest day (the rest counts, water 0 of 2.0 L does not) | Completing a task on the phone (a habit or water write on the throwaway stack) not yet run |
| 16 | Step counter | Implemented, not fully verified (the "no code" row above is outdated: steps.dart and the Health Connect module exist, device results 2026-10-17) | steps tests; STEP_COUNTER_DEVICE_CHECKLIST.md | Health Connect approval, Play declaration, device re-check |
| 17 | Exercise content licensing | Implemented, licence-checked locally | ExerciseDB is out of every release path (app, coach-chat, both privacy texts; tests). Everkinetic CC BY-SA 3(a) attribution is on the Licences page (test) | Owner decision on the production `public.exercises` content (plan in LICENSING_REQUIREMENTS.md; set_logs and exercise_swaps cascade from it) |
| 18 | Food diary | Implemented on licensed data, verification incomplete | USDA FDC (CC0) import of 28 planner foods (migration 20261025200000), licence gate 20261025100000, planner on USDA rows; FDC builder 6/6, diet_fdc_test 7/7, pgTAP 134/134 (disposable stack), Flutter 426/426. One profile (1760 kcal, 140 g protein, lactose-free eggitarian) drops from 7/7 to 0/7 days on target and says so | Library and diary search cover only 29 USDA foods in a release (NIN permission or more mapping); poha, ragi, paneer and rohu have no licensed values; dietitian on targets; production apply of items 13-14 |
| 19 | AI coach | Implemented, not fully verified | + rule and eval case: ask one clarifying question rather than guessing (eval 83/0 strict); functions 204; coach no longer reads the exercise catalogue | On-screen swap, lighter and move cards (rest day); provider key and live evaluation; privacy review |

Not release-ready: no area depends only on local code any more; every remaining item needs a review, licence, credential,
device check or production approval.
