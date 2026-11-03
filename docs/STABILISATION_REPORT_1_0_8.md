# Stabilisation and release readiness: Levlofit 1.0.8 (2026-11-03)

Evidence labels, never mixed: **Automated** (tests run on this machine), **CI** (GitHub Actions), **Production** (read-only
checks of the live Supabase project or website), **Device** (a real Android phone). A row without a label was not verified.

## Stage 1: remaining small improvements (commit 43270ea, local, not released)

| Item | Where | Evidence |
|---|---|---|
| Edit session length | Calendar day sheet "Edit length, effort and pain" (`HowItWentSheet` askMinutes), workout_logs.duration_min 1-600 | Automated: how_it_went_test 8/8 |
| Food vs targets in the weekly report | `weekly_report.dart` Intake, Progress reads food_log + diaryTotals | Automated: weekly_report_test 10/10 |
| Lift trend in the weekly report | `strengthTrend()` | Automated: weekly_report_test |
| Welcome back | `progression.dart welcomeBack()`, dashboard card | Automated: fewer_days_test, dashboard_test |

No database change. These reach users only with the next release (1.0.9); 1.0.8 on phones does not have them.

## Stage 2: testing

### 2.1 Groq against the live model
- **Production (logs, last 24 h before 10:20 UTC):** 6 calls, all `llm_ok`, provider groq, model `openai/gpt-oss-120b`,
  1.1-2.6 s, 1 attempt each, 792-1329 prompt tokens; no `llm_error`. All were onboarding level-check (`assess`) calls.
- **Not verified:** a coach chat message on the live model in this window (no traffic). Device checklist step D7 covers it.

### 2.2 429, timeouts, malformed replies, fallback
- **Automated:** `_shared/llm.test.ts` and `coach-chat.test.ts` (node 283/0): one retry on 429 / 5xx / network, never more
  than 1 + maxRetries, Retry-After honoured, no retry on auth / bad request / malformed, hung provider aborted within the
  budget (504), shared deadline, fallback only if configured and data-use approved, AI_DISABLED kill switch, app rate limit
  429 before any model call, rate store down -> 503, malformed or context-echo replies regenerated once then refused.
  Offline AI eval 85/0 strict.
- **Not verified live:** a real Groq 429 or outage (cannot be triggered safely on the free tier).

### 2.3 Offline
- **Automated:** offline_cache_test (per-account copy in secure storage, expiry, future-dated clock, corrupt data, clear).
- **Behaviour from the code:** without a connection the dashboard opens the last plan read-only with a "saved copy" banner;
  logging (workouts, food, check-ins, water) needs a connection and says "Could not save. Check your connection" - nothing
  is queued. That is a known limit, not a defect.
- **Device:** checklist D9.

### 2.4 Time zone and date boundaries
- **Automated, new (date_boundary_test 7):** check-in at 23:59:59 vs 00:00, month and year end, weekly report Sunday 23:59
  vs Monday 00:00, a week across 31 Dec, welcome back counts calendar days not hours, fewer-days weeks independent of the
  hour. Server: coach-chat F7 test (`localDayOf` uses the phone's day within a day of UTC).
- **Defect found and fixed:** the check-in card computed "today" once, so with the app left open past midnight a check-in
  at 00:10 was saved to the previous day. It now re-reads the day on every tap and reloads when it changed (test "app left
  open past midnight").
- **Known, harmless:** coach-chat's 7- and 14-day read windows start from the UTC date, so between 00:00 and 05:30 IST they
  start a few hours earlier than the local day; today's logs are always included.

### 2.5 Real device
No phone was connected to this machine (adb: no devices). See `docs/DEVICE_CHECKLIST_1_0_8.md`; results go in the table
there. **Device: not yet tested** apart from the owner's feedback test on 1.0.8 (2026-11-03: saved, email delivered to
Promotions).

### 2.6 CSP before enforcing
- **Production (browser, report-only header live):** `/`, `/handbook`, `/privacy`, `/terms`, `/delete-account` load only
  same-origin and `data:` resources; `/app/` before sign-in loads same-origin and `www.gstatic.com` (CanvasKit). Every
  loaded resource is inside the policy; no console errors.
- **Not verified:** `/app/` after sign-in (Supabase REST and realtime, ExerciseDB GIFs, Google sign-in redirect). Needs the
  owner to sign in to the web app once with the console open (checklist W1) before the header is switched to enforcing.
- The Android app is not affected by the website's CSP.

### Automated totals (this stage, on the working tree)
functions node 283/0, offline eval 85/0 strict, strict tsc, Deno check / lint / smoke 30/0, Flutter analyze clean,
Flutter 619 pass + 1 skip, website lint / build / tsc.
