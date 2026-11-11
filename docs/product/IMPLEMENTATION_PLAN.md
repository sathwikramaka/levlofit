# Levlofit: Implementation Plan

Last updated: 2026-11-11, for release 1.0.10. Keep current: see "Keeping these documents current" in `CLAUDE.md`.
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
| Encrypted Storage backup job and restore drill | Source and drill only: **inactive, see below** |

## 2. Next, in order

| # | Task | Owner | Why now |
|---|---|---|---|
| 1 | Run the device checklist on 1.0.10 (`docs/operations/DEVICE_CHECKLIST_1_0_8.md`) | Owner | Nothing recent has run on a real phone |
| 2 | Add `STORAGE_S3_KEY_ID`, `STORAGE_S3_SECRET`; run "Daily Storage backup" once | Owner | Photos are not backed up automatically; the job fails nightly |
| 3 | Finish the 2026-11-07 redesign review (not shipped): later onboarding, Build my plate, coach replies, then a release build on a phone | Claude, owner for the phone | Main screens tested on a phone with a debug build |
| 4 | Finish, test and commit the update notification work (uncommitted in the folder) | Claude, owner | Requested; needs a phone test |
| 4a | Phone-test and ship the 2026-11-11 habit work (source and tests only): personal bests, forgiving streak, level-up screen, recap, check-in and meal nudges, share pictures, 20-minute starter, Today's read, photo reveal, Android home widget | Owner for the phone, Claude | Built without a phone; the widget and sharing need a real device |
| 5 | Cooked rice and dal in the diary, from USDA values | Owner approves import | People log cooked food against raw values |
| 6 | Enforce the website CSP after a signed-in web app check | Owner, Claude | Report-only today |
| 7 | Rebuild the Handbook as a 69-chapter book in six volumes: 55 on the APS chapters with text checked against sources, plus 14 Levlofit chapters APS does not cover, kept at the owner's choice (`data/handbook_book/`). All volumes drafted. Website and app readers built and tested locally, not on a phone. Evidence register started (`data/handbook_book/claims_register.csv`): 1,002 of 2,381 claims reviewed, 316 with a quoted source passage; 1,379 still unreviewed, which the coach cannot cite. Coach code reads the book passages locally. Migration `20261107300000_handbook_book` tested on a throwaway local stack, not applied. Release order: app with the book reader and forced update (older apps show lists, tables and notes blank), then the migration, then `coach-chat` and the website. Website shows only the book, with the 29 old addresses redirected (`website/public/_redirects`). Clinical review is not done | Claude, owner approves | Owner decision 2026-11-07; the 43-chapter Handbook stays live until the book is finished |

## 3. Decisions waiting on the owner

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
