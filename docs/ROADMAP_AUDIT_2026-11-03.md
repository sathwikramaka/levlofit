# Roadmap audit and implementation map (2026-11-03)

Brief: `Levlofit_Product_Roadmap_and_Implementation_Spec.md` (owner, 2026-11-03). This is deliverable 16.1-16.8 of
that brief: the audit that comes before implementation.

**Evidence level of this audit: source code and migration files on branch `levlo/stage1-fixes` at `9b6acce` plus
the uncommitted send-feedback work.** No production query, deploy, device test or live AI call was made for it.
Production facts quoted below come from `docs/RELEASE_RECORD.md` (read-only checks of 2026-10-29) and are marked as
such; they are not re-verified here.

Status keys: **Done** (implemented, tested in source) · **Partial** · **Missing** · **Defect** (implemented but
wrong) · **N/A** · **Blocked** (needs an owner, clinical, legal or licensing decision).

## 1. Repository and branch

- Branch `levlo/stage1-fixes`, head `9b6acce` (release 1.0.7 build 9 recorded). Working tree: send-feedback Edge
  Function, its test, app + privacy changes, CI/verify wiring (uncommitted, not deployed).
- Flutter app `app/lib` (40 files), Supabase `supabase/migrations` (55 files), Edge Functions `generate-plan`,
  `coach-chat`, `body-check`, `delete-account`, `send-feedback`; website Next.js static export on Cloudflare Pages.
- Existing audits this one builds on (not repeated): `PROJECT_COMPLETE_AUDIT.md`, `GAP_ANALYSIS_19.md`,
  `RELEASE_READINESS_AUDIT.md`, `BACKUP_RECOVERY_PLAN.md`, `LICENSING_REQUIREMENTS.md`, `PROGRESS.md`.

## 2. Feature map (brief section -> current state)

### Phase 0: foundation

| Item | Status | Evidence | Action |
|---|---|---|---|
| 4.1 Energy/macros | Done | `plan-engine.ts` Mifflin-St Jeor BMR, activity factor, pace; 1.4-2.0 g/kg ISSN clamp; tests in `plan-engine.test.ts` | none |
| 4.1 High-BMI protein | **Blocked** | `plan-engine.ts:718-719` protein = actual weight x g/kg (no adjusted weight) | Brief forbids a cutoff without dietitian review; owner decided 2026-10-27 no clinician. Keep formula, documented as limitation (section 5) |
| 4.2 IFCT foods in release | Done (prod per record) | `20261028100000_ifct_release.sql` sets `release_allowed` for ifct2017; `food_sources` provenance per row | Re-check live search for poha/ragi/paneer/rohu needs read-only prod approval |
| 4.2 Provenance in UI | Done | `food_sources`, FDC/IFCT labels, `kcal_estimated` | none |
| 4.3 Age | **Defect -> fixed in Stage 2** | Only `birth_year` stored. Server `generate-plan` used `year - birth_year`: someone born Dec 2008 passed the 18+ gate in Nov 2026 aged 17 | See Stage 2 |
| 4.4 Plan save atomic | **Defect -> fixed in Stage 2** | `generate-plan` inserted `generated_plans` then updated `profiles.onboarding_complete` in two calls; failure between left a plan with a 500; retry inserted a duplicate | See Stage 2 |
| 4.5 Groq handling | Done | `_shared/llm.ts`: timeout, bounded retry, Retry-After, error taxonomy, content-free logs; `ai_daily_caps` + `rate_events` per-user caps; key server-side secret `LLM_API_KEY` | Live limits/caps rows need prod read approval |
| 4.6 Photo backups | Partial | DB daily encrypted backup + weekly restore drill; `progress-photos` bucket only via manual `tools/backup_prod.sh` (RPO unbounded) | Blocked: scheduled Storage copy needs a Storage secret in GitHub Actions (owner) |
| 4.7 RLS/account | Done | own-row RLS, column grants, anon revokes, delete-account removes Storage first, signup guard | none |
| 4.7 Terms at signup | **Defect -> fixed in Stage 2** | `auth_screen.dart` linked privacy policy only; Terms only in Settings | See Stage 2 |
| 4.8 CSP | Partial | `website/public/_headers` is Report-Only | Enforce after a console-clean pass on every page + `/app/` (needs deploy, owner) |
| 4.9 Licensing | Blocked (documented) | IFCT reuse unconfirmed, ExerciseDB V1 non-commercial; `LICENSING_REQUIREMENTS.md`, owner decision 2026-10-27 | Must be cleared before any revenue |

### Phase 1: daily engagement

| Item | Status | Evidence | Action |
|---|---|---|---|
| 5.1 Dashboard | Done | `dashboard.dart` greeting, rings, today's workout, fuel, body, hydration, habits tiles; offline cache `offline_cache.dart` | none |
| 5.2 Daily check-in | **Done in Stage 3 (local)** | `daily_checkins` (migration 20261103300000), `app/lib/checkin.dart` card + sheet | Not used by plan rules or the AI yet (by design) |
| 5.3 Workout logging | Done (Stage 3 local) | `workout_logs` (duration, rpe, notes), `set_logs` reps/kg, `session_changes` skip/swap, rest timer; Calendar day sheet edits length (1-600 min), effort and pain of a logged day | none |
| 5.4 Meal logging | Done | `food_log` = actual intake, separate from plan; edit meal and grams (`food_diary.dart` update, grant in the food diary migration); add a whole meal at once; packaged foods | Correction 2026-11-03: the first version of this audit said grams could not be edited; wrong, the grant and UI exist |
| 5.5 Reminders | Done (quiet hours Stage 5 local) | `reminders.dart`, `reminder_prefs`, `custom_reminders`, opt-in, master switch; water reminder hours now chosen by the person (migration 20261103400000) | Workout, weigh-in and custom reminders keep the times the person picked |

### Phase 2: progress

| Item | Status | Evidence | Action |
|---|---|---|---|
| 6.1 Progress dashboard | Done | `dashboard_menu.dart` Progress: 12-week bars, weight trend (least squares over 6 weeks), measurements, photos | none |
| 6.2 Weekly report | **Done in Stage 4 (local)** | `app/lib/weekly_report.dart`: last full week on Progress, sessions vs plan, food-log days, check-ins, weight average difference (2+ weigh-ins each week), one observation and one next step by fixed rules; unknown data shown as unknown Stabilisation stage 1: average logged kcal and protein vs plan targets from 3 logged days (diaryTotals, same values as the diary), lifts vs their previous session (up/same/down) | Logged intake only; unlogged meals read low (stated on the card) |

### Phase 3: personalisation

| Item | Status | Evidence | Action |
|---|---|---|---|
| 7.1 Adaptive workouts | Done (Stage 5 local) | `progression.dart` double progression, deloads, pain stop; new rule fewerDaysOffer v1: 3 full weeks inside the current plan all below plan, at least one session -> dashboard offers the rounded-up average (person taps Switch; Keep hides it 4 weeks; old plan stays in generated_plans) | The reason is shown to the person but not stored server-side (plan_changes is server-written only) |
| 7.2 Adaptive nutrition | Done | `swaps.dart`, regions, budget, kitchen, cooking time, diet type, allergies | none |
| 7.3 Governance | Done | `plan_changes` proposed/confirmed with from_value; plan snapshots kept in `generated_plans` | none |

### Phase 4: AI coaching

| Item | Status | Evidence |
|---|---|---|
| 8.1-8.4 | Done | `coach-chat`: server context build (`coach-context.ts`), scope rules, no numbers from model, handbook grounding, caps, `_eval` strict 83/0, thread delete. Live model quality unverified |

### Phase 5 and analytics

| Item | Status | Evidence | Action |
|---|---|---|---|
| Flexible streaks | Done | weeks-on-plan streak, rest days not penalised | none |
| Milestones/challenges | Partial | `rewards.dart`, `level_up.dart` | defer per brief |
| Analytics (section 10) | Done in Stage 4 (local) | `tools/retention_metrics.sql`: activation, D1/D7/D30 by signup week, weekly active (meaningful action), food-logging and check-in share, workout adherence; read-only, aggregate, no client tracking | Run on production needs owner approval and the daily_checkins migration. AI success/error rate stays in Edge Function logs (`llm_error` events) |

## 3. Defects confirmed from current code

1. Age gate by calendar year lets a 17-year-old through (server and client).
2. Plan generation: two non-atomic writes, no idempotency on retry.
3. No Terms of Service link at sign-up.

## 4. Historical findings now fixed or not applicable

- Groq key in client: not present; key is an Edge Function secret only.
- IFCT hidden in release: fixed by `20261028100000_ifct_release.sql` (applied per RELEASE_RECORD).
- Orphan photos after deletion: delete-account removes Storage first; 0 orphans on 2026-10-29 (record).

## 5. Blocked decisions

| Decision | Owner of it |
|---|---|
| High-BMI protein rule (adjusted weight or cap) | Qualified dietitian; owner has none (2026-10-27). Current rule stays and is labelled |
| 18-year-olds born in the current calendar year are now asked to wait until 1 January (no full DOB stored). Collect birth month instead? | Owner (data minimisation vs accuracy) |
| Scheduled Storage backup (needs Storage secret in GitHub Actions) | Owner |
| Enforce CSP (needs deploy + console pass) | Owner approval to deploy |
| IFCT / ExerciseDB commercial rights | Owner, before revenue |
| Production migration + Edge Function deploy for Stage 2 | Owner approval, one action each |

## 6. Order and dependencies

1. Stage 2 (this round): age gate, atomic idempotent plan save (migration + function), Terms link.
2. Stage 3: daily check-in (`daily_checkins` table, RLS, pgTAP), edit logged meal grams and sessions.
3. Stage 4: weekly report screen (deterministic, from `workout_logs`, `food_log`, `body_metrics`, check-ins) and SQL
   cohort metrics in `ops_health.sql`.
4. Stage 5+: adaptive schedule offer from missed sessions, quiet hours, challenges (only after retention baseline).

## 7. Likely to change

`supabase/functions/generate-plan/index.ts`, `_shared/plan-engine.ts`, new migration `save_generated_plan`,
`app/lib/onboarding.dart`, `app/lib/auth_screen.dart`, then `dashboard*.dart`, new `daily_checkins` migration.

## 8. Tests and risks

- Node tests for the age helper and the generate-plan RPC path; pgTAP for the RPC (local throwaway stack only).
- Risk: the RPC migration must reach production before the new generate-plan is deployed; the function falls back
  to nothing, so deploy order is migration first, then function. Rollback: redeploy the previous function version;
  the RPC is additive (drop function to roll back).
