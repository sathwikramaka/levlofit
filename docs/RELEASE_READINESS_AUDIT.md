# Levlofit release-readiness audit (2026-10-16)

Read-only audit. No code, database data, phone, production, migration, deployment, signing, Git history or remote
was changed. Sources: docs/PROGRESS.md (to batch BO), docs/GAP_ANALYSIS_19.md, docs/MASTER_CHECKLIST_19.md,
docs/IMPLEMENTATION_PLAN_15.md, docs/ANDROID_TEST_PLAN.md, docs/MIGRATION_RECONCILIATION.md, and checks rerun today.

**Verdict: not release-ready.** No area has production evidence; several need external sign-off or a licence.

## Evidence rerun today (2026-10-16)

| Check | Result |
|---|---|
| tools/verify.sh (all 14 steps) + handbook4 + db | All PASS: handbook register, freshness (477/533 reviewed, 160 with quoted passage), migration = builder; functions node 124/124; offline eval 43 strict; strict tsc clean; Deno check, lint, smoke 16/16; Flutter analyze clean, **286/286**; website lint, tsc, build; handbook4 OK; pgTAP LOCAL 59/59 (6 files) |
| Local DB after the run | Fingerprints of food_log, recipes, recipe_items, body_metrics, custom_reminders, reminder_prefs, test profile, exercises identical to the batch BO baseline |
| Working tree | 31 modified + 63 untracked paths; last commit daaea96; **no Git remote**; tools/local-test-user.txt ignored |
| Release signing | app/android/key.properties absent (only key.properties.example); version 1.0.0+1 |
| Device | OnePlus 13 profile build 00ca7cc2 installed (batches BN, BO); Part A 13/13, Part B 7/7, three UI fixes verified |

## Update 2026-10-16 (Levlofit-4; local evidence only, PROGRESS BU-CA)

- R1 tooling: backup scripts v2 applied and hardened (8 defects fixed); verified on local/synthetic data only:
  failure suite 41/41, seal suite 36/36, PowerShell wrapper 16/16, real-CLI Storage layout with synthetic buckets,
  sealed backup restored in an isolated RAM-only container with 12/12 fingerprint kinds, default ACLs, history,
  Storage metadata, signed-out probe and 63/63 table counts identical; negative control detected. R1 itself (a
  production backup) is still **not done**. See docs/BACKUP_RECOVERY_PLAN.md.
- Found: an unencrypted pre-v2 backup folder from 2026-10-14 in C:/Projects/levlo-secure-backups (shape matches
  production); owner decision needed.
- R10 input: docs/PLAY_DATA_SAFETY_DRAFT.md (draft, unreviewed). New blocker for R10: Play needs a web URL for
  account-deletion requests; none exists.
- .gitattributes keeps tools/*.sh LF (protects Linux/WSL/container bash; Git Bash tolerates CRLF).
- Regression 2026-10-16: tools/verify.sh all 15 steps PASS incl. pgTAP LOCAL and Flutter 286/286.

## 1. Verified complete locally (implementation + tests; not production)

| ID | Area | Evidence | Still needed before release |
|---|---|---|---|
| 6 | Grounded AI retrieval | Passage retrieval and citation validation; retrieval 20 and chat 28 tests within functions 124 | Deploy functions (R6); live answers need the provider key (area 5) |
| 9 | BMI | Rounding, ranges, units, age, messages; widget and phone-width tests; web visual check | Clinical review of cut-offs (Decision 1, ICMR 2024 provisional); not exercised on the phone |
| 10 | Waist | WHtR tool and Progress line; waist_history_test 3; seen on the phone (B7, batch BM) | Clinical review of the 0.5/0.6 boundaries for Indian adults |
| 11 | Custom dashboard | Layout codec, customiser, hide/reorder; web visual check | Device-local by design; not exercised on the phone |
| 14 | Profile and settings | Back stack, validation; phone back gesture passed (A10 and earlier) | none known |
| 15 | Daily rewards | Derived from logs, once-per-day celebration; web visual check | Not exercised on the phone |

## 2. Partially complete

| ID | Area | Done (evidence) | Exact gap | Next action | Depends on | Needs |
|---|---|---|---|---|---|---|
| 3 | Training engine | Scheduling, kit, injury screen, progression, deloads; session estimate + notice (session_time_test 8) | Integrated programme generator and time-budget trimming not built; estimate assumptions unreviewed | Coach reviews PROGRESS batch BA assumptions; then decide whether to build trimming | Coach review | External coach; your decision |
| 4 | Workout/nutrition correctness | Meal feasibility, fat guidance, level lock; tests | Rules unreviewed | Dietitian + coach review of the rule set | Reviewers | External dietitian, coach |
| 7 | Security, privacy | RLS everywhere, pgTAP 59 incl. anon_access, cascades, storage policy, secret scan, anon grants revoked (local) | Privacy text behind a REVIEW GATE (1 marker in privacy/page.tsx, 1 in dashboard_tabs.dart); production reconciliation and backup not done | Legal/privacy review of the policy; confirm retention periods; production steps R1-R5 | Deployed coach must match the text | External legal/privacy; your approval for production |
| 8 | Regression and delivery | verify.sh all PASS; CI file with DB job verified locally, actions pinned; device Part A/B + BO | CI never run on GitHub (no remote); reminder delivery with the new build, permission revoke, reboot untested | Create the remote and push to a branch (R8); optional device reminder test | Your approval (push, phone settings) | You |
| 12 | Exercise library | Guide for 40 moves incl. 7 yoga poses; Mobility verified on phone | 10 prescribed ids without identity; muscle lists unreviewed; **ExerciseDB media is non-commercial (exercises.dart header)** | Reviewed catalogue export or licensed source; expert review; licensed media before monetisation | Licensing | External expert; licence (you) |
| 13 | Reminders | Diff scheduling, exact timing, onboarding, custom reminders; 12 alarms re-registered after update (A13) | Alarm-clock mode decision; OnePlus delays permission-based exact alarms 35-52 s | Decide mode; then device delivery test | Your decision | You |
| 18 | Food diary | Diary, micronutrients, recipes, edit, search fixes; pgTAP + Flutter + REST; verified on phone (Part B, BO) | No household portions; B12/vitamin D absent; no micronutrient targets; IFCT redistribution permission unconfirmed | Ask NIN about IFCT reuse; clinical decision on targets; licensed portion source | Licensing, clinical | External (NIN, clinician) |
| 19 | AI coach | Grounded context incl. 7-day food totals, disclosed; functions 124 | No activity data (16); no live evaluation (5); privacy review gate | Follows 5, 16, 7 | Areas 5, 16, 7 | Key (you), reviews |

## 3. Blocked (external review, licensing, credentials or your decision)

| ID | Area | Exact blocker | Evidence | Next action | Needs |
|---|---|---|---|---|---|
| 1 | Handbook audit | 444 open review items (review_items.csv), clinical 150; EFSA, NICE, ACOG documents unavailable | docs/handbook_v4_review/ package | Send the package to a qualified reviewer; obtain the three documents manually | External clinician |
| 2 | Handbook rewrite | Clinical sign-off; Decisions 1-5 provisional; production handbook_v3 partly applied, unrecorded | DECISIONS.md, MIGRATION_RECONCILIATION.md | After review, ship v4 as a new forward-only migration | External clinician; your approval |
| 5 | AI provider | No API key; provider data terms unverified | Adapter + offline eval 43 | You supply a key on your machine; run `_eval/run.ts --live` | You (credential) |
| 16 | Step counter | Approval for `health` plugin, Health Connect permissions, Play declaration | Evaluation only, no code | Decide; if yes, implement behind tests, then device test | You |
| 17 | MuscleWiki | Paid API; terms forbid caching/redistribution | Recorded evaluation | Decide paid plan or another licensed source | You (purchase) |

## 4. Release engineering still outstanding (none executed)

| # | Task | Blocker / dependency | Needs |
|---|---|---|---|
| R1 | Owner-run production backup (tools/backup_prod.ps1 or dashboard) and verification | Free plan has no scheduled backups | You |
| R2 | Reconcile cloud migration history (MIGRATION_RECONCILIATION.md Option B, forward-only) | R1 | Your approval |
| R3 | Apply pending migrations: handbook_v3 correction, 20261013100000, **and the five not yet in the reconciliation doc**: 20261014100000, 20261016100000, 20261016200000, 20261016300000, 20261016400000 | R1, R2, reviewed plan | Your approval |
| R4 | Deploy coach-chat, generate-plan, delete-account; check secrets (LLM_BASE_URL, LLM_MODEL, LLM_API_KEY) | R3 (functions tolerate absence), area 5 key | Your approval |
| R5 | Production smoke test with a test account (chat, resend, plan rebuild, feedback, food diary, recipes) | R3, R4 | Your approval |
| R6 | Publish privacy text after legal review and confirmed retention | Area 7 review, R4 | External legal; you |
| R7 | Release keystore + key.properties (owner-held, never in repo), signed release build, versionCode bump | You create the keystore | You |
| R8 | Git remote, commit in reviewed batches, first CI run | Your approval to commit/push | You |
| R9 | Website hosting and security headers check on the real host | Host choice | You |
| R10 | Play Console listing, data-safety form, content rating; internal testing track | R6, R7 | You |
| R11 | Licences for commercial use: ExerciseDB media, IFCT values, wger entries | Licensing answers | You / licensors |

## Consistency check: contradictions and outdated statuses (reported, not changed)

1. **Pending migrations undercounted.** MIGRATION_RECONCILIATION.md and the PROGRESS runbook (step 1) list only 20261007400000 and 20261013100000. Five later migrations (20261014100000, 20261016100000/200000/300000/400000) are applied locally but absent from the reconciliation plan. Earlier session reports said "5 pending migrations"; the full production set is 7 items (5 new + 20261013100000 + the handbook_v3 correction).
2. **GAP_ANALYSIS_19.md header** says evidence runs to "batches J to BB" and "89 changed or untracked paths"; evidence now runs to BO and the tree has 94 (31 M + 63 ??).
3. **GAP_ANALYSIS_19.md table, Device column:** area 8 still lists "Full Android device pass" (done except reminders/revoke/reboot); areas 10, 12 and 18 list "Phone pass" (done: B7, A8-A10, Part B + BO). Areas 9, 11, 15 and 3 (session screen) were genuinely not exercised on the phone.
4. **MASTER_CHECKLIST_19.md:** last section says "Local web visual check pending owner sign-in" (done in BD/BF); area 18 lists "device check" as remaining (done); area 8 "full device pass incomplete" is now partial only.
5. **IMPLEMENTATION_PLAN_15.md:** "Release-readiness audit (2026-10-15)" numbers (Flutter 190, pgTAP 24) and "Next three priorities" (device pass blocked on tooling) are superseded; workstream 13 row says 17 ids missing (now 10); the 19-area update line says Flutter 237 (now 286).
6. **ANDROID_TEST_PLAN.md:** "Why this did not run here" (no device) is obsolete; the "Open defects" line describes problems fixed in batch AL; "After the reminder reliability fix (not yet run)" is partly superseded by the delay diagnosis; check 5 still expects "No Equipment" (now "No equipment" by design, batch BE); batch BO results are not appended.
7. **PROGRESS.md header** says "Last updated: 2026-10-13 (batch M)"; the environment table says "supabase test db 12/12" (now 59). The batch log itself is current.
8. **Latest test numbers:** the last PROGRESS checkpoint (after BH) says Flutter 282; BN/BO added 4 tests. Today's run: 286/286, all other suites unchanged. Batch BO is recorded in PROGRESS and GAP_ANALYSIS; not in ANDROID_TEST_PLAN or MASTER_CHECKLIST.

No contradiction was found between the docs and the code for the items checked (test counts, migration files, signing files, privacy disclosures of Google Fonts, ExerciseDB and the coach's food totals).

## Proposed ordered release checklist (not executed)

**A. Local, safe now (no approval beyond documentation edits)**
1. Correct the outdated statuses listed above (docs only).
2. Extend MIGRATION_RECONCILIATION.md's forward-only plan to all 7 pending items, with read-only preflight queries and per-migration rollback notes.
3. Write the Play data-safety answers and a store-listing draft from the current privacy text (draft only).
4. Optional device checks that need no data: BMI, dashboard customise and daily goal on the phone (guarded taps, no saves).

**B. Your decisions or credentials**
5. Alarm-clock mode (13); Health Connect (16); MuscleWiki or another source (17); keep or replace ExerciseDB media.
6. Provider API key on your machine for the live evaluation (5, 19).
7. Create the release keystore yourself (R7); choose website host (R9).
8. Create the Git remote and approve committing in reviewed batches; then run CI (R8).

**C. External professionals**
9. Clinician: handbook package (444 items), BMI/WHtR cut-offs, micronutrient targets, referral wording.
10. Coach: session-estimate assumptions (batch BA), thresholds. Dietitian: nutrition rules.
11. Legal/privacy: policy text, retention periods, data-safety form. Licensing: NIN (IFCT), INDB, wger, ExerciseDB.

**D. Production (each step needs your explicit approval; owner-run)**
12. Backup and verify (R1) -> reconcile history (R2) -> apply the 7 pending items (R3) -> deploy functions and check secrets (R4) -> smoke test (R5) -> publish reviewed privacy text (R6).
13. Signed release build -> Play internal testing (R10) -> device pass on the release build, including reminder delivery.
