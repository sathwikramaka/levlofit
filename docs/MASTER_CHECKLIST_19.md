# Levlofit master checklist: 19 work areas

Started 2026-10-15 (session after the alarm-clock experiment). Statuses follow the completion rules: Complete only when
implementation and relevant tests are verified locally. Nothing here is deployed; "local" means this repository and the
isolated local Supabase stack. Evidence for earlier work is in docs/PROGRESS.md (batches J to AO).

Baseline at start of this loop: tools/verify.sh all suites 16/16 PASS (Flutter analyze clean, 225 tests; functions 120;
eval 43 strict; Deno check/lint/smoke 16; pgTAP pass; website lint/tsc/build).

| ID | Work area | Status | Evidence | Remaining / blocker |
|---|---|---|---|---|
| 1 | Handbook audit | Blocked (clinical review) | Claim register, quoted passages (160 v3, 196+ v4), Step 1 safety sources, checks pass | 444 open review items (clinical 150); EFSA, NICE, ACOG unavailable; qualified reviewer needed |
| 2 | Handbook rewrite | Blocked (review and owner decisions) | v4 draft local, decisions 1-5 recorded (provisional), tests pass | Clinical sign-off; production migration held (reconciliation) |
| 3 | Multi-goal training engine | Partially complete | Scheduling consumes all sessions, kit, injury screen, progression, deloads, missed sessions; session length estimate + over-time notice, validated over every prescribable session (session_time_test 8); prescriptions unchanged | Integrated programme generator and time-budget trimming not built; COACH REVIEW of the estimate assumptions (PROGRESS batch BA) and thresholds |
| 4 | Workout and nutrition correctness | Partially complete | Meal feasibility, fat guidance, duplicates, level lock; tests | Dietitian and coach review of rules |
| 5 | AI provider integration | Blocked (API key) | Provider adapter, error taxonomy, harness, offline eval 43 strict | Live provider comparison needs keys |
| 6 | Grounded AI retrieval | Complete (local) | Passage retrieval, citation validation; retrieval 20 and chat 28 tests | Production deploy only |
| 7 | Security, privacy, reliability | Partially complete | RLS everywhere, pgTAP 59 incl. anon_access (no anon privilege on per-user tables, cascades), allowlist, rate limits, transactional chat, delete-account, headers, signing config, secret scan clean, storage policy checked; anon grants revoked (local) | Production migration reconciliation and backup (owner-run); privacy text review gate; legal/privacy review |
| 8 | Regression testing and delivery | Partially complete | verify.sh all suites; CI with database job verified locally from scratch (33 migrations, pgTAP pass), generated-migration checks, actions pinned to SHAs; Android device plan and results | CI never run on GitHub (no remote); device Part A/B and the BO fixes passed, reminder delivery with the new build, permission revoke and reboot untested |
| 9 | BMI | Complete (local) | Rounding, ranges, age, units, unit-aware messages; widget and phone-width tests; visual check | Cut-offs await clinical review (Decision 1) |
| 10 | Waist measurements | Complete (local) | Waist-to-height tool (tests); waist history in Progress with latest and first ratio from profile height (waist_history_test 3) | WHtR boundaries need clinical review (UK-derived cut-offs) |
| 11 | Custom dashboard | Complete (local) | Layout merge, codec, customiser, hidden cards; visual check (persistence after reload) | Device-local only (not synced) |
| 12 | Exercise library | Partially complete | Guide for 40 prescribed moves (7 yoga poses added as Mobility/STRETCHES), regions, versions, fallback page; tests | 10 ids missing identity (6 stretches, row variation, skill basics move, running drills, frog pose); needs the catalogue export or a licensed source; expert review of muscle lists; wger per-entry CC licence review; licensed media for commercial use |
| 13 | Reminders | Partially complete | Custom reminders (stable order), diff scheduling, exact timing, onboarding, alarm-clock experiment; tests; device measurements | Owner decision on alarm-clock mode (deferred); OnePlus widens permission-based exact alarms (35.7 s, 51.8 s) |
| 14 | Profile and settings | Complete (local) | Back stack, settings entries, validation messages; tests; device back-gesture pass | none known |
| 15 | Daily rewards | Complete (local) | Derived from logs, rest days, once-per-day celebration; tests; visual check | Celebration flag device-local |
| 16 | Step counter | Blocked (owner approval) | Evaluated pub.dev `health` 13.3.2 (MIT; Health Connect on Android, HealthKit iOS 15+; STEPS via getTotalStepsInInterval). No code added | Needs approval to add the dependency (network download), Health Connect permissions (READ_STEPS, ACTIVITY_RECOGNITION), privacy-policy rationale screen, Play health-permission declaration, and granting permissions on the phone for device tests |
| 17 | Exercise knowledge (MuscleWiki) | Blocked (paid licence) | MuscleWiki API: free tier is playground only, API keys from $10/month; terms forbid redistribution or caching data as a dataset | Owner approval for a paid plan, or another authorised source |
| 18 | Food diary | Partially complete | food_log + RLS + limits; IFCT search, grams, meals, totals vs plan; vitamins and minerals (8, IFCT; missing values counted, not zero; pgTAP food_micros 5); recipes (recipes + recipe_items, RLS, limits, atomic save_recipe; pgTAP 13; Flutter recipes_test 8; local REST check incl. anon 401 and rollback on bad food); entries editable (weight, meal; pgTAP + Flutter) | Household portions (no licensed source with gram equivalents found); B12/vitamin D absent from IFCT package; no micronutrient targets (needs review); NIN permission for IFCT values in a commercial app (device check done: Part B, BO) |
| 19 | Unified AI coach | Partially complete | Coach grounded in profile, plan, 14-day logs, passages, notes; 7-day food diary totals for food questions (disclosed in app and website privacy text); functions 124 | No activity/step data (area 16); live provider eval blocked (area 5); privacy text review gate unchanged |

## Loop order (dependency-ready, highest value first)

1. [done] 18 Food diary: table + RLS + limits (local migration after a verified dump), pure totals, diary screen, tests.
2. [done] 19 Coach: add a minimal, allowlisted food-diary summary to the coach context, with tests.
3. [done] 10 Waist: show waist-to-height ratio next to waist history, with tests.
4. [blocked] 16 Step counter: evaluate a plugin; implement behind an interface only if it can be added without new paid services.
5. [blocked, licence] 12 Exercise library: authorised open sources for the missing metadata (evaluation).
6. Final full regression, document update.

## Loop 2 (2026-10-15)

Done: 18 micronutrients, 12 yoga guide, 3 session estimate, 8 CI database job, 18 recipes, 19 disclosure. Deferred by owner: reminder alarm-clock mode (13), health permissions (16), paid sources (17).

## Loop 3 (2026-10-16)

Done: 7 local audit + anon revoke, 8 CI db job verified + SHA pins, 3 estimate validation (coach review recorded), 13 stable order, 18 entry edit.

## Final gap analysis (2026-10-16)

See docs/GAP_ANALYSIS_19.md. No area is release-ready. Phone-width layout tests for the new screens added (5). Local web visual check done (batches BD-BF).

## Status levels (2026-10-16, batch BQ)

Verification levels (kept separate; none implies the next): **Local** = implemented and passing local tests
against the isolated local stack; **Device** = exercised on the owner's OnePlus 13 with a local build; **Reviewed** =
signed off by a qualified external professional (none yet); **Licensed** = third-party data or media cleared for
commercial use; **Production** = deployed to the live project and smoke-tested (none yet). Release-ready needs every
level that applies to the area.

"Complete (local)" above means the Local level only. Per-level status for every area: docs/GAP_ANALYSIS_19.md.
Latest run: verify.sh all PASS (Flutter 286/286, functions 124, eval 43, Deno 16, pgTAP 59/59, website, handbook).
Release blockers and the proposed checklist: docs/RELEASE_READINESS_AUDIT.md.
