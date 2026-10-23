# Levlofit handoff for the next chat (2026-10-17, updated after batch 2O: reminder fix, phone checks, licences, evidence round 8)

Read this first, then docs/RELEASE_CHECKLIST.md (the single prioritized production checklist with every approval gate), docs/PROGRESS.md (batch log to CB), docs/GAP_ANALYSIS_19.md (per-area status by verification
level), docs/RELEASE_READINESS_AUDIT.md, docs/MIGRATION_RECONCILIATION.md, docs/PROD_MIGRATION_SAFETY_REVIEW.md and
docs/BACKUP_RECOVERY_PLAN.md. Project rules: CLAUDE.md (production changes and even read-only production inspection
need the owner's explicit approval; local database only).

## State in one paragraph

All implementation that can be done and verified locally is done; nothing is release-ready. **Production has not
been changed or accessed by Claude** (no migration, deployment, SQL, Storage copy or history change). The backup
tooling (v2 approved and applied, then hardened in batch BZ) is verified on local and synthetic data only; the
production backup itself has **not** been run. Nothing committed or pushed; no remote. Batch CB added `backup_seal.sh --legacy`
(for the unencrypted 2026-10-14 backup), the /delete-account website page (legal review pending), a local release-build
check, the 19-area release classification (GAP_ANALYSIS_19.md) and the rewritten RELEASE_CHECKLIST.md. No unblocked
implementation work remains: everything left needs an owner decision, credential, licence, professional review, the
phone, or production approval.

## Batch 2P (2026-10-22, latest): review, iOS deferred

iOS HealthKit deferred by the owner (no Apple device); not part of the current release. Plugin patch reviewed (one
file, licence kept); JUnit 4/4, reminder tests 24/24; device timing after the fix unverified. Provider recommendation
written (Groq gpt-oss-120b, ZDR). Licence replacements listed. No code changed.

## Batch 2O (2026-10-22): reminder double-delivery fixed at its root cause

flutter_local_notifications re-armed a daily reminder for the same day when Android delivered it early, so it was shown
twice (seen in forced Doze). Patched copy in app/third_party/flutter_local_notifications (LEVLOFIT_PATCH.md), JUnit 4/4,
fails without the fix. Device timing after the fix not re-verified. Reboot and package-update keep all 12 alarms (PASS).
Step stale label: code gap fixed (timer); device check blocked by interruptions. Licence register and provider
comparison written; Phosphor licence added to the app. Evidence round 8 recorded. Flutter 381/381, functions 163,
Deno 16, handbook PASS. Build note: run Gradle tests with JAVA_HOME set to Android Studio's jbr.

## Batch 2L (2026-10-18): owner decisions applied

Decisions in docs/OWNER_DECISIONS.md. Handbook: 630 mg caffeine example removed; 5 unsupported scientific claims removed
(plus one paired myth); 4 practical items labelled as Levlofit tips or rules; both v3 and v4 updated, registers re-synced
with reviews re-attached by text. Rate limits recorded as provisional. Provider comparison: docs/AI_PROVIDER_COMPARISON.md
(no provider chosen). Tests: handbook, handbook4, functions, Deno PASS. Pending: fresh-DB database tests and the new v3
handbook hash (Docker Desktop not running). **Done in 2N**: fresh DB 34 migrations, pgTAP 64/64 PASS, new handbook hash af1ea000.

## Batch 2K (2026-10-17): gap closure and fresh results

All suites rerun after the latest changes: verify 16/16 PASS (Flutter 379/379), functions and Deno rerun after the 2K
server change, fresh-DB pgTAP 64/64. Release reminders: notification icon now kept from shrinking; on the phone a
custom reminder for 16:18:00 arrived 16:19:44 (app in background) and sign-out cancelled all alarms. Coach error texts
made plain. Handbook registers cross-checked (no missing or orphan sources). Owner decisions: docs/OWNER_DECISIONS.md.

## Batch 2J (2026-10-17): the three approved phone checks

Debug-signed release build with R8 (local debug key, not distributed): PASS. Reboot: PASS. Deny path: PASS. New defect
found and fixed: a session for an account that no longer exists left the app stuck on 'Could not reach Levlofit';
it now says the account could not be loaded and offers Sign out (verified on the phone). Steps checklist: 15 pass,
1 partly, 2 not run. Phone left with READ_STEPS not granted and not locked; the release build is installed.

## Batch 2I (2026-10-17): fresh-database test, consolidated regression, phone pass

Details in PROGRESS.md. Security migration run on two fresh throwaway local stacks (all 34 migrations, pgTAP 64/64;
never on the dev DB or production). Phone (OnePlus 13, Android 16) against a throwaway stack: five defects found and
fixed (Health Connect permission crash on Android 14+, 'See my plan' no-op in debug builds, dashboard layout failure
at 360 dp, week-strip label breaking mid-word, unexplained 3-of-4-days plan). Owner approved grant + read of steps only;
the permission was removed again afterwards. Not approved and not run: deny path, reboot, debug-signed release build.
iOS HealthKit: not implemented (no Mac or Xcode). The phone now has the flagged debug build installed.

## Batch 2H (2026-10-17): implementation checkpoint for all 19 areas

The owner asked for all authorized local implementation first, then consolidated testing (only when the owner says
so), then hosting or release. This batch closed the last local items; the per-area table below is the checkpoint.
Done: handbook round 7 (8 decisions: 6 verified on abstracts, 2 partly supported); migration
`20261017100000_revoke_anon_sequences.sql` plus pgTAP assertion (**written, not run on any database** in 2H, then run on fresh throwaway DBs in 2I: Docker engine
would not start); `provider@host` approval when the LLM base URL is overridden; frozen Deno lock
(`supabase/functions/_test/deno.lock`) in verify.sh and CI; every prescribed move in the injury map, I3tsCnC identified
as the hanging leg raise (swaps to the dead bug without a bar); steps card refreshes on resume;
docs/STEP_COUNTER_DEVICE_CHECKLIST.md (18 phone checks, not run; HealthKit needs a Mac). Targeted tests only: handbook
4/4, functions 162, eval 43 strict, tsc, Deno 16/16 (frozen lock), Flutter analyze + 41/41 + 22/22. **Consolidated
regression not run** (every verify.sh step incl. db: full Flutter suite, website, pgTAP): the next step, on the owner's word.

## Batch 2G (2026-10-16): handbook evidence round 6

21 unsourced claims: 8 verified (6 on open full text), 3 partly supported, 7 still without a source, 3 left to the
owner (Decision 5). Six Zourdos claims now read in the accepted manuscript. Seven new sources (v4 draft citations only;
v3 migration unchanged). Open review items 439 (evidence 105, clinical 117, policy 82, editorial 135). Re-run:
`python data/handbook_v4/fetch_round6.py <dir>` then `python -I data/handbook_v4/audit_round6.py <dir>`.

## Batch 2F (2026-10-16): the seven remaining areas (details in PROGRESS.md)

| Area | State | Still external |
|---|---|---|
| Handbook audit (1) | Rounds 5-6; open items 439 (evidence 105) | Clinician (117), owner policy (82), editorial (135), full texts behind paywalls (source_access 71), 21 claims with no source |
| Handbook rewrite (2) | v4 draft reworded where evidence required (Nielsen, Kotarsky) | Clinical sign-off; v4 production migration (approval) |
| AI provider (5) | Approval gate, fallback, request deadline, reply validation, benchmark --out; tested offline | API key, data terms, LLM_DATA_APPROVED; live benchmark run |
| Exercise library (12) | All 10 ids identified; frog-pose naming defect fixed; injury map extended | Expert review of muscle lists; commercial licence before monetisation |
| Step counter (16) | Code complete behind -Plevlofit.healthConnect=true; builds verified (default has no permission) | Owner approvals (5 in STEP_COUNTER_PLAN.md); phone tests; Play declaration; legal text |
| Exercise knowledge + licensing (17) | 2 cited evidence notes; ExerciseDB terms verified; 1 claim hidden (no source) | Licences (commercial); MuscleWiki not used |
| Unified coach (19) | Lifts + consented steps in context, minimised and checked; privacy texts updated (gated) | Key, deploy, legal review |

Evidence: functions 161, eval 43, Deno 16, Flutter 363/363, handbook, website PASS; Android default/flagged debug and
flagged release builds inspected.

## Batch 2E (2026-10-16)

- Builds no longer reach production by default: the store build needs `--dart-define=LEVLOFIT_BACKEND=production`
  (proved by building with and without the define).
- coach-chat needs `LLM_DATA_APPROVED=<provider>` before any user data goes to a provider.
- Area 12: the 10 unidentified exercise ids are missing catalogue data (local table empty), not code defects.
- Release setup steps for the owner: docs/RELEASE_SETUP.md.
- Evidence: functions 138, eval 43, Deno 16, Flutter 339/339, website PASS.

## Batch 2D (2026-10-16)

Owner-approved local dev-DB refresh: CE versions of check_rate and food_log_limit applied after a dump
(C:/Projects/_backups/levlo-s30-devdb-pre-function-refresh-20261016). Dev DB pgTAP now 63/63.

## Batch 2C (2026-10-16)

Run days count as filling the session when placing add-ons; rest-day add-on sessions get the training reminder
(reminder engine unchanged). Flutter 337/337, analyze clean. 19-area reconciliation: docs/GAP_ANALYSIS_19.md, last
section. No unblocked local implementation work remains; every open item needs the owner, a reviewer, a licence, the
phone or production approval (list in that section).

## Batch 2B (2026-10-16; details and acceptance criteria in PROGRESS.md)

Integrated multi-goal programme, app only (no server, DB or reminder change; not committed).
- Add-on blocks now have real moves (that goal's own sessions, tier, kit, level), fit 20 min, never repeat a move of
  the day, and alternate variants. With a session length they join a training day with room, else become a short
  session on a rest day (hard blocks only where recovery allows), else join the best day with the reason stated.
- The session screen shows blocks as their own section at their own level; the day's time fit counts every add-on
  minute (main accessories trimmed first, then block moves; main lifts and doses never). Rest-day add-ons log their own
  minutes.
- Evidence: `tools/verify.sh flutter` PASS, Flutter 335/335, analyze clean; 23 new tests incl. 32,400-combination
  sweep; negative controls fail as expected; reviewer findings (2 medium, 4 low) fixed.
- Open: coach review of the block rules; run days have no estimate; rest-day add-on counts toward days ring/streak
  (owner decision); no reminder on add-on-only days; not checked on device/browser.

## Batch 2A (2026-10-16; details in PROGRESS.md)

Three local fixes, all tests green; nothing deployed, no dev-DB write, no commit.
- Food diary: the app stops at 730 days back (same as the food_log_limit trigger), notes the limit, and maps a server
  22008 to a clear message (add and recipe log).
- Coach chat: CoachApi test seam; mounted check after delete; no send into, reopening of, or second delete during a
  pending deletion; 8 lifecycle widget tests.
- coach-chat function: a duplicate whose saved turn cannot be read returns 409 (never the new draft with old ids); a
  saved message whose reply was deleted returns 409 replyMissing without a model call, and the app retries under a new
  id. Needs a function deploy (production approval) to take effect.
- Evidence: `tools/verify.sh functions deno flutter` 8/8 PASS (functions 136, eval 43, Deno smoke 16, Flutter 312/312).
- Recovery check before 2A: no git operation or process was left interrupted. Dev DB functions refreshed in 2D.
- Integrated multi-goal sessions: done in batch 2B (above).

## 19 work areas after batch 2I (2026-10-17)

Three different things: **implementation** (code done), **tested** (automated suites and the phone), and **production
readiness**, which is none for every area (no production migration, deploy, signed build or professional review yet).

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
| 13 | Reminders | Complete; 2K keeps the notification icon in release builds | Flutter tests | Release build: immediate and scheduled delivery PASS (16:18:00 -> 16:19:44), sign-out cancels all | Reboot and long-Doze delivery not run | Owner: alarm-clock mode (OWNER_DECISIONS.md) |
| 14 | Profile, settings | Complete; 2J adds Sign out on the start-screen error | Flutter tests | Profile screen, sign-out, stale-account escape PASS | None | None of its own |
| 15 | Daily rewards | Complete | Flutter tests | Daily goal card renders | None | Owner decision shared with area 3 |
| 16 | Step counter | Android complete (flag off by default); 2I fixed the Android 14+ permission crash. iOS: not implemented | steps 22/22 | 15 pass, 1 partly, 2 not run incl. deny, reboot, R8 release (STEP_COUNTER_DEVICE_CHECKLIST.md) | iOS HealthKit bridge (needs a Mac with Xcode; not possible here) | Play health declaration; legal text; owner approval to ship the flag |
| 17 | Exercise knowledge, licensing | Complete | Flutter tests | n/a | None | Commercial licences; MuscleWiki not used |
| 18 | Food diary | Complete | Flutter tests | Verified earlier (Part B, BO); not re-run | None | NIN (IFCT) permission; INDB licence; clinician on targets |
| 19 | Unified AI coach | Complete | Functions and eval | Not exercised (no key); steps sharing switch only | None | Areas 5 and 7; deploy; legal review |

## Latest verified evidence

- Batch 2I (2026-10-17), consolidated: `verify.sh handbook handbook4 functions deno flutter website` all steps PASS
  (handbook 518/533 reviewed, 203 with passages, migration = builder; draft book tests; functions 163; offline eval 43
  strict; strict tsc; Deno check/lint/smoke 16/16 with the frozen lock; Flutter analyze clean and 378/378 (379/379 after 2J); website
  lint/tsc/build). Database: pgTAP 64/64 on two fresh throwaway local stacks with all 34 migrations (the db step of
  verify.sh targets the dev DB and was not run). Phone: see docs/STEP_COUNTER_DEVICE_CHECKLIST.md and PROGRESS 2I.
- Batch 2H (2026-10-17), targeted only: handbook checks 4/4; functions 162 pass, offline eval 43 strict, strict tsc;
  Deno check, lint and smoke 16/16 with the frozen lock; Flutter analyze clean, 41/41 (session kit, injury, exercise
  guide) and steps 22/22. Not run: full Flutter suite, website, pgTAP (Docker engine down), phone, production. The last
  full suites were in 2F (Flutter 363/363, website, handbook PASS) and CE (fresh-DB pgTAP 63/63).
- Full local regression (2026-10-16 ~02:40 IST, batch CA): `tools/verify.sh handbook functions deno db flutter website`
  15/15 steps PASS (functions 124, eval 43 strict, Deno smoke 16, pgTAP LOCAL PASS, Flutter analyze clean + 286/286,
  website lint/tsc/build).
- Earlier full regression (2026-10-16, batch BQ): tools/verify.sh all PASS: handbook (register, freshness 477/533,
  migration = builder), functions 124/124, offline eval 43 strict, strict tsc, Deno check/lint/smoke 16/16, Flutter
  analyze clean and **286/286**, website lint/tsc/build; handbook4 OK; pgTAP LOCAL **59/59** (6 files).
- Android (OnePlus 13 CPH2649, Android 16, 360 dp, profile build 00ca7cc2 installed, local stack over `adb reverse
  tcp:54321`): Part A 13/13 and Part B 7/7 (batches BL, BM, 2026-10-15); batch BN fixes verified 3/3 (BO, 2026-10-16).
  Test rows always created by id and deleted by id with fingerprint checks. Not run on device: BMI, dashboard
  customise, daily goal, coach chat, session screen, reminder delivery with this build, permission revoke, reboot.
- Phone safety: all phone input went through a guard that refuses unless Levlofit is the focused window (one early
  tap landed in Instagram before the guard existed; recorded in batch BK).

## Git state

Branch `levlo/stage1-fixes`; last commit daaea96; **38 modified + 90 untracked** paths (after batch 2H) (incl. .gitattributes, website/src/app/delete-account/, docs/proposed_backup_changes*.diff, docs/backup_hardening_after_v2.diff, docs/PLAY_DATA_SAFETY_DRAFT.md) (all uncommitted work, must be
preserved); **no remote**; no stash. Nothing committed or pushed in these sessions.

## Eight pending production items (docs/MIGRATION_RECONCILIATION.md, "Pending production items"; the 8th added 2026-10-17)

| # | Migration | Nature | Risk |
|---|---|---|---|
| 1 | 20261007400000_handbook_v3 | deletes and reinserts 38 handbook rows; prod holds an unrecorded draft (hash 432c7c6f) not in git | Medium |
| 2 | 20261013100000_reliability_and_limits | new objects + goal_levels policy swap (levels capped at 3) + contact/feedback rate limits | Medium |
| 3 | 20261014100000_custom_reminders | additive table | Low |
| 4 | 20261016100000_food_diary | additive table (needs foods.code unique) | Low |
| 5 | 20261016200000_food_micronutrients | 8 columns + update of foods reference data | Low (licence open) |
| 6 | 20261016300000_recipes | additive tables + function | Low |
| 7 | 20261016400000_revoke_anon_user_tables | removes anon privileges on 6 tables | Low-Medium |
| 8 | 20261017100000_revoke_anon_sequences | removes anon privileges on the 4 public sequences and future ones; run only on fresh throwaway local DBs (pgTAP 64/64, batch 2I); never on the dev DB or production | Low |

`20261007500000_remove_pilates` is already applied in production. None of the files wraps itself in a transaction.
Production state was last inspected (read-only, owner-approved) on 2026-10-13; items 3-7 have never been checked
against production. 16 read-only production-state queries are written in docs/PROD_MIGRATION_SAFETY_REVIEW.md
(syntax-tested on the local stack only).

## Backup and recovery (docs/BACKUP_RECOVERY_PLAN.md is the current, tested description)

- Tools: tools/backup_prod.ps1 (owner entry point) -> tools/backup_prod.sh (dumps incl. platform schema and migration
  history, Storage copy per bucket with `--project-ref`, checks, BACKUP_PASS, SHA256SUMS) -> tools/backup_seal.sh
  (gpg AES-256, streaming verify, no plaintext written); tools/restore_preload.sql / restore_postload.sql;
  tools/schema_state.sql (12 kinds). History: v1 diff (never applied), v2 diff (approved, applied BW), hardening diff
  docs/backup_hardening_after_v2.diff (8 defects, BZ).
- Verified locally (BZ): failure suite 41/41, seal suite 36/36, PowerShell 16/16, real-CLI Storage layout with
  synthetic buckets (created and removed again; dev DB back to baseline), sealed backup restored into RAM inside an
  isolated container: 12/12 kinds, default ACLs (postgres + supabase_admin), migration history, Storage metadata,
  signed-out probe and 63/63 table counts identical; the no-preload control shows the grant explosion every time.
- Security finding kept in the procedure: a plain restore into any Supabase database re-grants anon/authenticated
  through default privileges (control: grant 54 -> 378, anon EXECUTE on 10 functions incl. 4 security-definer).
- Correction (BZ): Git Bash tolerates CRLF scripts; Linux/WSL/container bash does not. .gitattributes keeps
  tools/*.sh LF (proved in disposable repos without a commit).
- **Found, untouched:** C:/Projects/levlo-secure-backups/levlo-pre-migration-20261014T162118Z is an unencrypted,
  pre-v2 backup whose shape matches production (22 public tables, 1 storage object row); not recorded before. The
  backup root also grants BUILTIN\Administrators, so the hardened wrapper will stop until that entry is removed.
- **The migration plan is not declared safe** until a real production backup is restored in isolation and the seven
  items are rehearsed on that copy.

## Licensing and professional review blockers

- Clinician: handbook (444 items), BMI and WHtR cut-offs, micronutrient targets, referral wording.
- Coach: session-estimate assumptions (batch BA), thresholds. Dietitian: nutrition rules.
- Legal/privacy: policy text (REVIEW GATE markers in website/src/app/privacy/page.tsx and app/lib/dashboard_tabs.dart),
  retention periods, Play data-safety form.
- Licences: NIN for IFCT values (incl. micronutrients), INDB (licence unverified), wger per-entry, **ExerciseDB media
  (non-commercial)**, MuscleWiki (paid).

## Next steps that need the owner's approval (in order)

0. Protect the unencrypted 2026-10-14 production backup (attempted twice on 2026-10-16, paused by the owner; nothing written, source unchanged; PROGRESS CC, CD): `bash tools/backup_seal.sh --legacy
   /c/Projects/levlo-secure-backups/levlo-pre-migration-20261014T162118Z`, offline copy, `sha256sum -c` there; then
   remove the Administrators entry (`icacls C:\Projects\levlo-secure-backups /remove:g *S-1-5-32-544`). Deleting the
   plaintext afterwards needs a separate approval (RELEASE_CHECKLIST.md 0.1-0.3).
1. Done (BW, BY, BZ): backup tooling applied, hardened and verified locally.
2. Owner runs the production backup (`powershell -ExecutionPolicy Bypass -File tools\backup_prod.ps1`; Session pooler
   string + a personal access token made for this run) plus tools/schema_state.sql and the read-only Q0-Q8 checks in
   one quiet window. Credentials stay with the owner; no `supabase link`.
3. Owner seals it (`bash tools/backup_seal.sh <folder>`), copies the .tar.gpg + .sha256 offline, verifies there.
4. Approve restoring the real backup in the isolated RAM-only container (BACKUP_RECOVERY_PLAN.md sections 6-7).
5. Approve rehearsing items 1-7 on that restored copy with every pre/post check.
6. Approve cleanup of the drill copy and any plaintext.
7. Only then: choose Option A (re-align history) or B (forward-only) and authorise item 1 alone; then each later item
   separately; then function deploy, smoke test, privacy text publication.

Scratchpad folders holding local test data (session scratchpad, outside the repo; deletion needs approval):
`run2_20261015T202405Z/rehearsal` and `run3_20261015T203458Z/rehearsal` (local rehearsal backups incl. the 2 local
test accounts; run3 also has the sealed .tar.gpg of it). Everything else there is synthetic or derived (hashes, counts).

Independent decisions waiting: alarm-clock reminder mode (13), Health Connect (16), MuscleWiki or other source (17),
keep or replace ExerciseDB media, AI provider key (5), release keystore (owner-created), website host, creating a Git
remote and committing in reviewed batches.

## Local environment facts

- Local Supabase (Docker Desktop, containers `*_Fitness_App`, Postgres image public.ecr.aws/supabase/postgres:17.6.1.171)
  at 127.0.0.1:54321; Windows Firewall rule `Levlofit-Supabase-Isolation` (inbound block TCP 54321-54329) must stay
  enabled. Kept volume `supabase_db_levlo_ci_check` (old CI rehearsal) is intentional.
- Test account: tools/local-test-user.txt (git-ignored); never print the password. The accidental real-address local
  account must not be modified or reused.
- Latest local backups: C:/Projects/_backups/levlo-s18, s21, s23 (checksums verified 2026-10-16), s24 (docs).
- Never run `supabase db push`, `db reset --linked`, or link to production without explicit approval.

## Capability register (Levlofit-4, 2026-10-16)

"Invoked" = actually used in this chat. Listed-only capabilities are not claimed as used.

| Capability | Kind | Status | Invoked? |
|---|---|---|---|
| anthropics/skills marketplace (`anthropic-agent-skills`) | plugin marketplace | Already registered in ~/.claude/plugins (clone dbd4588, 2026-10-09). Plugins: document-skills (docx/pdf/pptx/xlsx, source-available), example-skills (12 incl. webapp-testing, mcp-builder, skill-creator), claude-api, academy-guide, discernment-nudge. **None installed by Levlofit-4**: docx/pdf/pptx/xlsx/skill-creator/claude-api are already available as app skills; webapp-testing overlaps the project playwright-cli skill and the built-in browser; the rest are irrelevant. No SE/security/testing/release skills exist in that repo. Install is a `/plugin install` terminal command (owner, if wanted) | Inspected only |
| supabase, supabase-postgres-best-practices, playwright-cli | project skills (.claude/skills) | Available | No |
| security-and-hardening, security-review, code-review-and-quality, doubt-driven-development, test-driven-development, debugging-and-error-recovery, ci-cd-and-automation, shipping-and-launch, deprecation-and-migration, git-workflow-and-versioning, documentation-and-adrs, engineering:deploy-checklist / incident-response | user / plugin skills | Available | No |
| caveman, ponytail | style skill / session hook | Active | Yes |
| Agent types: Explore, Plan, general-purpose, claude, ruflo-core:reviewer / researcher / coder | agents | Available | ruflo-core:reviewer: independent review of the backup diff (11 findings; batch BV) |
| Supabase MCP (d3d54a4f…: execute_sql, apply_migration, deploy_edge_function, list_migrations, get_advisors) | MCP | Connected; **production-capable** | **No** (needs owner approval; write tools not to be used) |
| GitHub, Linear, Notion, Slack, etc. | MCP | Need OAuth (owner) | No |
| ruflo MCP, pdf-viewer, Context7 docs, built-in browser, Claude in Chrome | MCP / tools | Available | No |
| WebFetch | tool | Available | Yes: github.com/anthropics/skills README |
| Docker 29, Supabase CLI 2.118.0 (2.121.0 available, not upgraded), GnuPG 2.4.9, GNU tar 1.35, Python 3.12, adb | local tools | Available | Yes: CLI (local schema dump, local read-only queries), Docker (read-only listing/psql query), tar |

## What the next chat should do first

1. Read this file (Batch 2H section and the checkpoint table first), then RELEASE_CHECKLIST.md section 0. The owner's
   sequence is implementation (done to the checkpoint), then consolidated testing (start only when the owner says so:
   start Docker Desktop, then `bash tools/verify.sh handbook functions deno db flutter website`), then hosting or
   release. The db step runs pgTAP against the running local DB, which does not have the 2H migration yet: test it
   first on a fresh throwaway local DB (as in batch CE); applying it to the dev DB is a DB write that needs approval.
2. The backup diffs are already applied (v2 in BW, hardening in BZ); the old step "approve proposed_backup_changes.diff"
   is done. Still open for the owner: seal the unencrypted 2026-10-14 backup (checklist 0.1-0.3).
3. Do not run anything against production until the owner explicitly approves the backup window (stage 2).

- 2026-10-22 (batch 2Q): coach personalisation audit and Groq gpt-oss-120b vs Gemini 3.8 Flash benchmark prepared, not run (docs/AI_PROVIDER_COMPARISON.md). 4 multi-turn eval cases, compare.ts, Gemini 3 reasoning_effort medium. Verified: node 164, offline eval strict 55/0, tsc, Deno smoke 16/0. Groq ZDR available to all customers per docs; account status not checked. No keys, no live calls.
- 2026-10-22 (batch 2R): provider facts re-verified on official pages (model IDs, prices, terms; free-tier limits only visible in each console). Gemini free tier may use content for improvement and human review: synthetic only. run.ts gained --pause-ms (test added). Smallest live test proposed: 52 calls, $0 on free tiers. Functions 165 pass, offline eval strict 55/0, tsc clean. No live calls, no keys handled.
- 2026-10-22 (batch 2S): pre-run review of the live benchmark. Fixed: harness counted only the last model call's tokens; now sums all calls and records requests and wall time (test added). Functions 166 pass, eval strict 55/0, tsc clean. No API calls; no key variables found in the user or machine environment.
- 2026-10-22 (batch 2T): Gemini deferred (free limits unconfirmed, no paid billing). Offline eval strict 55/0. Adapter preset `ollama` (localhost, thinking off; test added). Local benchmark, synthetic, 13 cases: qwen3 8B and qwen3.5 9B each 40/43 strict, both fail food exclusions in 2 of 5 cases (footer catches). Plan: docs/COACH_IMPLEMENTATION_PLAN.md. Functions 166 pass, tsc clean. No external calls.

- 2026-10-22 (batch 2U): confirmed, editable memory. New table coach_facts (migration 20261023100000; categories injury/schedule/equipment/preference/goal/other; status suggested/confirmed; owner-only RLS and column grants; a trigger forces coach and migrated rows to start unconfirmed and sets confirmation time). Existing coach_notes lines copied as unconfirmed suggestions; coach_notes kept unchanged, no longer read or written. Coach suggests with 'NOTE: <category>: <fact>' (max 3 per reply, 20 pending, no health conditions or instructions); only confirmed facts reach the model. App: 'Remember this?' card under replies (Remember / Edit / Not now) and Memory sheet (remembered vs waiting, edit, delete, forget everything). Tests: functions 170, eval strict 56/0 (new memory-scope check), tsc, Deno smoke 16/0, Flutter analyze clean + 389/389, pgTAP 88/88 on throwaway stack levlo_phone_2i (incl. 24 new memory tests), migration conversion checked there. Not applied to the dev or production database; not tested on a phone.

- 2026-10-22 (batch 2V): memory privacy pass. Confirmed injury facts sent only for training, movement or pain questions (isInjuryRelevant), newest 3 at most; injuryNoted flag also set by a confirmed injury fact; new rule: injury facts are not diagnoses, plan around them, refer persistent pain. Disclosure added to Memory sheet, injury suggestion card, in-app privacy policy and website privacy page (still behind the existing Groq review gate). Tests: functions 171, eval strict 56/0, tsc, Deno smoke 16/0, Flutter analyze + 389/389, website lint/tsc/build. Throwaway levlo_phone_2i: functions served with a local stub provider (scratch copy only); API dry run 10/10. Phone check steps: docs/COACH_MEMORY_DEVICE_CHECK.md (phone not connected, not run).

- 2026-10-23 (batch 2V phone check): PASS on device 358edd6b against throwaway levlo_phone_2i (adb reverse tcp:54321 tcp:54326). Cause of the earlier connection failures: Docker restarted and the stack came back without its function runtime (`supabase functions serve` is a foreground process, not restarted by Docker), so /functions/v1 returned 503; restarted with the scratch stub.env. Read-only proof of isolation: stub 200 on 54326, 503 on 54321; after sign-up memcheck@test.local exists only in the throwaway DB (6 users, dev DB unchanged at 2, memcheck=0). Steps: card shown without NOTE text, Remember stored a confirmed row; Not now stored nothing; coach received only the confirmed fact (stub log never saw burpees); edit persisted and reached the coach; Forget this removed the row and the coach then got (none yet). adb reverse removed afterwards. Side notes, not fixed: dashboard on the throwaway stack said "5 moves could not be loaded"; Forget this deletes without a confirm step; restart the function server after any Docker restart.
- 2026-10-23 (tooling): owner-approved setup. 55 unused global skills (convex*, gsap-*, vercel-*, deploy-to-vercel, 21st-*) moved to ~/.claude/skills-disabled (move back to re-enable); plugins ruflo-core, threejs-webgl, core-3d-animation, claude-mem-cowork, ecc set to false in ~/.claude/settings.json (backup settings.json.bak-2026-10-23). Added project skills dart-run-static-analysis, dart-add-unit-test, dart-fix-runtime-errors from dart-lang/skills @bf984f3 (BSD-3-Clause, LICENSE copied, local-rules note on top). Takes effect next session.
- 2026-10-23 (batch 2W): rolling chat summaries. Migration 20261023200000 adds coach_threads.summary (1-800 chars) and summary_upto (owner update grant; goes with the thread and with account deletion by cascade). coach-chat reads up to 40 messages; once more than 12 are not covered, one extra model call (SUMMARY_RULES: sees only the old summary and messages, never the context block) folds all but the newest 4, so it runs about every 5 turns; acceptSummary refuses any context header or JSON key, drops instruction-like lines, cuts at 800. Sent as the last context block "EARLIER IN THIS CHAT" before the 12 recent messages; editing a covered message clears it; failures keep the old summary; logs carry counts only. Tests: functions 176 (5 new), offline eval strict 59/0 (new memory-long-chat: 20 messages, fact from message 3 recalled, strict summary check incl. no context echo), tsc, Deno check/lint/smoke 16/0, pgTAP 96/96 on throwaway levlo_phone_2i (8 new; migration applied there only). Not done: dev/production DB, deploy, live-model run, phone check; app unchanged (summary not shown or exported).
- 2026-10-23 (batch 2W review): code and tests reviewed; not yet fixed. Verified: migration 20261023200000 only on throwaway levlo_phone_2i (columns + history row there; dev DB has neither); verify.sh functions PASS (node 176, offline eval strict 59/0, strict tsc clean), 2V memory tests inside that suite still pass; pgTAP 96/96 taken from the 2W run, not re-run. Rollover correct (summary_upto = newest folded id, nothing refolded, newest 4 kept, summary overlaps the 12-message window by design); owner-only RLS holds; thread and account deletion cascade; edits of covered messages clear it; app has no single-message delete. Findings: (1) the summary call runs before the reply and shares the 45 s request budget, so a slow summary call can turn a normal chat into a 504, and a persistently failing or refused summary is retried every turn; (2) the new grant lets the app user write any 800-character summary directly, which is placed in the system prompt without acceptSummary (self-only prompt injection, e.g. overriding safety rules for themselves); (3) more than 40 unsummarised messages (old chats, or about 14 failed turns in a row) are skipped silently. Missing tests: failed summary call keeps reply and old summary; forged summary. Fixes proposed, awaiting approval.
- 2026-10-23 (batch 2W fixes, owner-approved): (1) summary call capped at 8 s, one attempt, no fallback, skipped unless 30 s of the request budget is left; after a failure retried every 3rd turn (summaryDue), every turn only once 40 uncovered messages pile up; a failure never blocks the reply or overwrites the stored summary. (2) The summary is no longer in the system prompt: it opens the chat as a labelled, untrusted user-role message plus a fixed assistant acknowledgement, and the stored summary is run through acceptSummary on read (a refused one is ignored and rebuilt). (3) Count-only log summary_window_full when the 40-message read is full and nothing in it is covered. Files: _shared/coach-context.ts, coach-chat/index.ts, coach-chat/coach-chat.test.ts, _eval/score.ts (scorer now requires the summary as a message, never in the system prompt). Tests run: verify.sh functions PASS (node 182, 6 new: failure keeps reply and old summary, 8 s cap on a hanging call, budget skip, retry spacing, forged summary with instruction lines, window-full log), offline eval strict 59/0, strict tsc clean; verify.sh deno PASS (check, lint, smoke 16/0). No schema change, so pgTAP not re-run (96/96 from 2W). Not applied to dev or production; no live-model or phone check.
- 2026-10-24 (batch 3a): coach action "swap today's exercise". Migration 20261024100000_exercise_swaps (per-user, per-day proposed/confirmed swaps; app may only read and delete its own rows, writes by the server only; owner-only RLS; cascades with the account). coach-chat: on swap talk with today's session sent by the app, the model gets TODAY'S SWAP OPTIONS (replacements from the app's own move list, _shared/swap.ts, checked for same target muscle, equipment and injury set-aside, mirrored from session.dart and parity-tested); a "SWAP: id -> id" line is hidden, re-checked and stored only as a proposal; confirmSwap re-checks against current equipment, injuries and catalogue before confirming; refused, injected or out-of-session swaps store nothing. App: Swap / Not now card under the reply (swaps.dart), dashboard applies confirmed swaps to today's session and reloads after a swap. Tests: functions node 188 (13 new incl. every refusal reason, injection, confirm re-check, 404/400/expired), offline eval strict 62/0 (new swap-today case, 2 bad variants fail), strict tsc, Deno check/lint/smoke 16/0, Flutter analyze clean + 395/395 (6 new), pgTAP 108/108 on throwaway levlo_phone_2i (12 new; migration applied there only, dev DB checked: no table). Not applied to dev or production; no live-model or phone check; local catalogue is empty, so tests use synthetic catalogue rows.
- 2026-10-24 (batch 3b): coach action "make today's session lighter". Migration 20261024200000_session_changes (kinds lighter, move; per-day proposed/confirmed; server-written only, app reads/deletes its own; owner-only RLS). coach-chat: easier-day talk (tired, sore, poor sleep; never when the message mentions pain, chest, dizziness, illness or injury) with today's session sent offers TODAY'S SESSION CAN BE MADE LIGHTER; a hidden LIGHTER line is stored only as a proposal; confirmChange confirms it server-side (moves refused until 3c). App: Make it lighter / Not now card (generic action card in swaps.dart), a confirmed lighter day shows one set fewer per move (never below one) and 3+ reps in reserve with a notice. Tests: functions node 191, offline eval strict 65/0 (new lighter-today case, bad variant fails), strict tsc, Deno check/lint/smoke 16/0, Flutter analyze clean + 397/397, pgTAP 119/119 on throwaway levlo_phone_2i only. Not applied to dev or production; no live-model or phone check.
- 2026-10-24 (batch 3c): coach action "move today's session". No schema change (session_changes kind move, to_day within the same Monday-to-Sunday week). The app sends today's later free days (rest days this week not already holding a moved session) with today's session; on move talk the model sees TODAY'S SESSION CAN MOVE TO; a hidden MOVE: date line is kept only for an offered later day this week and stored as a proposal; confirmChange re-checks (later this week, not in the past). App: Move / Not now card; a confirmed move shows the session on its new day and leaves today as a rest day on the dashboard (week view and reminders keep the usual days: stated on the card). Tests: functions node 194, offline eval strict 68/0 (new move-today case works on any weekday; Sunday has no later day and expects nothing proposed), strict tsc, Deno check/lint/smoke 16/0, Flutter analyze clean + 399/399. pgTAP not re-run (no schema change; 119/119 from 3b). Not applied to dev or production; no live-model or phone check.
- 2026-10-24 (batch 3d): coach action "log a meal". No schema change: food_log is already the person's own diary (owner-only RLS, per-day cap). On logging talk coach-chat offers FOODS THEY CAN LOG (distinct foods from their own diary that fit their diet exclusions, _shared/meal.ts); hidden "MEAL: <meal> <code> <grams>" lines are checked (offered food, 1-2000 g, one meal, max 6, diet) and one bad item refuses the whole proposal; the server writes nothing. App: Log it / Not now card; entries are written to today's diary only on Log it. Tests: functions node 196, offline eval strict 72/0 (new log-meal case; bad variants: claims logged, avoided food), strict tsc, Deno check/lint/smoke 16/0, Flutter analyze clean + 401/401. Coach plan item 3 (all four actions) done locally. Not applied to dev or production; no live-model or phone check.
- 2026-10-24 (coach plan items 4-6): item 4 blocked on owner decisions (exclude or review the 5 'unreviewed' Handbook passages such as rest-between-sets:b04 before 'only reviewed passages are cited'; approval to download an open-source embedding model); a trial exclusion broke 5 Handbook tests and was reverted (handbook.ts unchanged). Item 5: seeded property test over 600 valid plans (energy >= BMR, protein 1.4-2.0 g/kg and grams, diet and restriction exclusions, soya 0 when soy excluded, clearance stop for medical flags, pregnancy stop and never a cut); clinical text items still wait for the owner; no deload rule exists in the engine. Item 6: confirmSwap/confirmChange rate limited with the existing chat buckets (no new owner-set values, no migration), log-privacy test for facts, suggestions and action proposals; action injection cases from 3a-3d. Tests: functions node 199 incl. plan-engine property test, offline eval strict 72/0, strict tsc, Deno check/lint/smoke 16/0. Not applied to dev or production.
- 2026-10-24 (item 4, Handbook review, owner-approved): five unreviewed coach passages fixed in data/build_handbook.py, migration 20261007400000_handbook_v3.sql regenerated (content only, not applied anywhere), claims register, sources register and handbook-passages.json resynced. rest-between-sets:b04 no longer says 'both trained and untrained' (Grgic 2018 abstract: over 2 min for trained lifters, 60-120 s enough for beginners); rest-between-sets:b01 bars: muscle building labelled 'evidence under review' (needs_better_source), 'Other exercises (Levlofit rule) about 90 s' matches the app timer (editorial); one-step-at-a-time:b04/b05 say 'Possible' interference, mainly power, strength and size mostly with running (Wilson 2012 abstract); hyrox:b04 is now a Levlofit tip with no source (wilson2012 dropped from the hyrox chapter sources). Four passages partly_checked, hyrox editorial; reviewed by Claude (AI, not a qualified reviewer) from Europe PMC abstracts PMID 28933024 and 22002517 only; full texts unread, review_needs keeps source_access and reviewer_confirm. No code depends on the wording (rest timer uses fixed 120/90 s). New test: no shipped passage may be unreviewed. Tests: handbook register tests OK, freshness check (521 of 526 claims reviewed), migration matches builder, functions node 200, offline eval strict 72/0, strict tsc. Backups of the old registers, passages and migration in the session scratchpad. The handbook hash noted in MIGRATION_RECONCILIATION.md (af1ea000) is now out of date; the dev DB still holds the previous chapter text until migrations are applied.
- 2026-10-24 (item 4 closure check): not closed. Met: no citation of unreviewed claims (no shipped passage is unreviewed, guard test; new strict eval check fails any citation of an unreviewed passage). Not met: paraphrase questions. Measured with the current keyword retrieval: 'How many minutes should I wait between sets?' ranks one-step-at-a-time first (rest-between-sets third), 'chill'/'break' variants miss the rest chapter, 'Does cardio kill muscle growth?' misses one-step-at-a-time; 'Will running ruin my gains?' works. Trials: five extra synonyms (barely helped) and letting synonyms anchor the ranking (fixed some, broke 2 existing Handbook tests and pulled safety passages into creatine answers); both reverted, handbook.ts unchanged. Embeddings skipped by the owner. Tests: functions node 200, offline eval strict 72/0, strict tsc, Handbook tests 21/21. Remaining coach-plan work: item 4 paraphrase gap (needs embeddings or a ranking redesign, owner's call); item 5 clinical text items (owner decisions).
- 2026-10-24 (item 4 ranking redesign, no downloads): handbook.ts adds TOPICS, a short explicit table of phrase patterns (a pause word with 'sets'; an endurance word with a gains word) that rank the answering chapter first and add its own words at full weight; synonyms and the rarest-word rule are unchanged. Results: 'wait', 'chill', 'break', 'pause' between sets and 'chill before my next set' now rank rest-between-sets first (before: one-step-at-a-time or calisthenics first, rest third or missing); 'Does cardio kill muscle growth?' and 'Will running ruin my gains?' rank one-step-at-a-time first; creatine questions stay in supplements; 'Is it safe to drive at night?' never reaches supplements; single everyday words ('take a break', 'go running tomorrow') trigger no topic. New strict eval check scoreRank and cases paraphrase-rest, paraphrase-cardio. Tests: Handbook 22/22, register tests, freshness check, migration matches builder, functions node 201, offline eval strict 80/0, strict tsc. No Handbook claims, evidence statuses, schema or migrations changed. Item 4 done locally without embeddings; limit: only the two topics are recognised.
- 2026-10-24 (item 4 closed; 3c follow-up): item 4 recorded done without embeddings; limit: only the two tested topic families (rest between sets; running or cardio versus gains) get special ranking, other paraphrases depend on keyword overlap; unreviewed-citation guard kept (data test + strict eval). 3c follow-up: the Workout week view now shows a moved session on its new day and 'Session moved to <day>' on the day it left (same A/B session numbering as the dashboard); reminders still keep the usual days (stated on the Move card). A new widget test caught and fixed a 15 px overflow of that label at phone width. Tests: flutter analyze clean, schedule_test 3/3, Flutter 402/402. All 19 areas in GAP_ANALYSIS_19 and coach-plan item 5 text now wait on owner decisions, professional review or production approval.
- 2026-10-24 (item 5, owner decisions D1-D4, local only): data/build_handbook.py: caffeine example capped at about 3 mg/kg (210 mg for 70 kg) beside the EFSA single-dose level of about 200 mg with an avoid-if-pregnant/sensitive/medication line (new source key efsa_caffeine); waist-to-height bands merged to 'Healthy' under 0.5 and 'Above the healthy range: higher risk' from 0.5; pregnancy 'Stop and seek care' now follows Mottola 2018 (persistent fluid loss, dizziness or faintness not settling with rest, chest pain, painful regular contractions, breathlessness not settling with rest; headache removed). Plan engine waistToHeightCategory: healthy/increased only (stored type keeps 'high' for old plans); app tools.dart whtrCheck: one cut at 0.5. Migration 20261007400000 regenerated (not applied); claims register: 9 changed claims set needs_clinical_review (passages kept where read: Misra 2025, ISSN, EFSA page), no passage unreviewed, the four blocks flagged for clinical review. D4: no deload rule added (coach-review topic). New tests: engine waist edges, diet-feasibility property test (40 seeded profiles x 2 days: truthful flag, no excluded or over-budget food, soya limit, suggestions never name an excluded food). Tests: Handbook register/freshness/builder match, functions node 201, offline eval strict 80/0, strict tsc, Deno check/lint/smoke 16/0, flutter analyze clean, tools/waist_history/phone_width_new_screens/diet_feasibility 66/66. Backups in the session scratchpad. Nothing here is clinically approved.
- 2026-10-24 (privacy texts after 2W and 3a-3d): website privacy page and in-app policy (dashboard_tabs _dataUse) now state what the new coach features send and store: the rolling chat summary (stored with the chat, deleted with it; the summary request sees only that chat's older messages and previous summary), today's moves and checked replacements for swaps, this week's free days for moves, the names of up to 30 foods from the person's own diary for meal logging, and stored offered/confirmed session changes (also listed under account deletion). New paragraph stays inside the existing REVIEW GATE (legal review and deployed-code match still required before publishing). New node test fails if either text stops naming any of these flows. Tests: website lint/tsc/build clean, functions node 202, offline eval strict 80/0, strict tsc, flutter analyze clean.
- 2026-10-24 (account deletion coverage): pgTAP now proves account deletion removes exercise_swaps and session_changes rows (one new check in each file), backing the privacy text. pgTAP 121/121 on throwaway levlo_phone_2i only (rolled-back transactions; dev DB untouched). Remaining local work needs an owner decision: a phone run of coach actions 3a-3d and chat summaries on the throwaway stack (writes chat rows for the existing synthetic account, needs synthetic catalogue rows inserted there, and the scratch stub and functions refreshed).
- 2026-10-24 (runbook accuracy): the expected Handbook data hash af1ea000 in MIGRATION_RECONCILIATION.md (3 places) and PROD_MIGRATION_SAFETY_REVIEW.md (1) is marked STALE: today's item 4 and item 5 edits changed the builder output. Recomputing needs the migration applied to a fresh throwaway DB, which the owner deferred (no database writes); do it before any production apply. Doc-only, no tests affected. No further local implementation found that is not blocked by owner decisions, reviews, licences, credentials, production approval or the deferred phone check. Not release-ready.
- 2026-10-24 (Handbook fingerprint, read-only): new tools/handbook_fingerprint_sql.py turns the handbook_v3 migration's VALUES into a read-only query (begin transaction read only ... rollback) with the table's column order, types and generated search expression. Validated: the commit 1803009 file gives af1ea000, the value the throwaway DB returned after actually applying it. Current builder output b3b87df6 (after item 4: 1295200f); runbooks updated (MIGRATION_RECONCILIATION.md x3, PROD_MIGRATION_SAFETY_REVIEW.md x1), STALE notes replaced. No migration applied, no write. Dev DB still holds 81a79a56, throwaway af1ea000.
