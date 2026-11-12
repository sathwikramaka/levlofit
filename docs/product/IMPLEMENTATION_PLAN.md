# Levlofit: Implementation Plan

Last updated: 2026-11-12, for release 1.1.0. Keep current: see "Keeping these documents current" in `CLAUDE.md`.
Detail: `docs/PROGRESS.md` (log), `docs/release/RELEASE_RECORD.md` (what shipped), `docs/archive/ROADMAP_AUDIT_2026-11-03.md` (roadmap).

Status labels are kept apart: Source, Automated, CI, Deployed, Production verified, Real device.

## 1. Done

| Work | State |
|---|---|
| Core app, plan engine, diet planner, coach, Handbook, website | Deployed |
| Roadmap stages: audit, age gate, safe plan save, Terms link, check-in, weekly report, fewer-days offer, water hours | Deployed in 1.0.9 |
| Food vs targets and lift trend in the report, session length edit, welcome back, midnight check-in fix | Deployed in 1.0.9 |
| Diet accuracy: rice in grams, real servings, raw and dry names | Deployed in 1.0.9 |
| Custom supplements, Supplements card, pre- and post-workout meals | Deployed in 1.0.9 |
| Soft card look, floating bottom bar | Deployed in 1.0.10 (CI green) |
| Steps on Today, plan-sheet Workout and Diet, floating Levlofit AI, chapter buttons, workout settings, Progress activity map, coach week and meal sheets | Deployed in 1.1.0, coach-chat v42 |
| Settings as its own row in More; notification when a new version is out; Handbook book (69 chapters) in app, coach and website | Deployed in 1.0.12, migration and coach-chat 2026-11-12 |
| Habit features: personal bests, forgiving streak, level-up screen, nudges, share pictures, short starter, Today's read, photo reveal, home widget | Deployed in 1.0.11 |
| Handbook update: 77 chapters with figures and the wiki's facts in own words, healthy plate check on Diet | Built 2026-11-12; migration 20261112100000 not applied, release 1.1.1 not built |
| Encrypted Storage backup job and restore drill | Source and drill only: **inactive, see below** |

## 2. Next, in order

| # | Task | Owner | Why now |
|---|---|---|---|
| 1 | Run the device checklist (`docs/operations/DEVICE_CHECKLIST_1_0_12.md`) on 1.1.0, plus steps on Today, screen on and a coach plan question: widget, share sheet, notification taps, update notice, the book | Owner | Nothing since 1.0.10 has run on a real phone |
| 2 | Add `STORAGE_S3_KEY_ID`, `STORAGE_S3_SECRET`; run "Daily Storage backup" once | Owner | Photos are not backed up automatically; the job fails nightly |
| 3 | Finish the 2026-11-07 redesign review (not shipped): later onboarding, Build my plate, coach replies, then a release build on a phone | Claude, owner for the phone | Main screens tested on a phone with a debug build |
| 5 | Cooked rice and dal in the diary, from USDA values | Owner approves import | People log cooked food against raw values |
| 6 | Enforce the website CSP after a signed-in web app check | Owner, Claude | Report-only today |
| 7 | Handbook book review: 1,735 of 2,737 claims unreviewed (the coach cannot cite them); no clinical review. The book itself is live since 2026-11-12 (migration applied, coach-chat v40, website with the 29 old addresses redirected) | Claude, clinician | Owner shipped the book before review, 2026-11-12 |

## 3. Decisions waiting on the owner

- Handbook book: add a vitamins and minerals section to the supplements chapter (needs a book migration). The
  Supplement guide already covers them in the app.
- Export and gym check-in were removed on 2026-11-12 (owner: data is tied to the account email).

- Not built from the 2026-11-12 screenshots: language (Hindi is later), kg or lb, week starting Sunday, several equipment
  profiles, accent colour (the brand keeps orange), body diagram choice, and effort per set (RIR or RPE per set needs a
  `set_logs` column, so a migration).

- Portions on high-calorie plans (7 rotis, 10 idlis at a meal): cap them, add a meal, or leave.
- Merge duplicate soya chunk rows (touches existing diary rows).
- Ask birth month, to admit people turning 18 this year.
- Training buddy: two people linked by an invite code, each seeing only the other's sessions this week. Needs a new
  table, RLS, a function that returns only that count, and a privacy decision (what a buddy may see, how to unlink).
- The app's onboarding still says "never suggests beef or pork"; the website no longer does.

## 4. Blocked on others

| Item | Needs |
|---|---|
| Higher-BMI protein rule and other nutrition rules | Qualified dietitian (`docs/legal/OUTSTANDING_REVIEWS.md`) |
| IFCT food values for revenue | NIN written permission, or replacement |
| ExerciseDB media for revenue | Paid plan, or own media |
| iOS native app | A Mac |

## 5. Later, only with evidence

Retention measures: `tools/retention_metrics.sql` (D1, D7, D30, adherence, sessions per week), run with approval. More goals with sourced chapters, Hindi. Social features, leaderboards and
subscriptions wait until retention can be measured; accounts are still too few.

## 6. How work is done

1. Read the code first. Fix root causes. Smallest change that works.
2. Add a test for logic; run `bash tools/verify.sh` for what changed; pgTAP on a throwaway stack for schema.
3. Update the six documents in this folder when behaviour changes.
4. Commit when the owner asks. Production changes need approval each time.
5. Release: migrations, functions, then `tools/release_android.sh`; then the release record.
