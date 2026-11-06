# Levlofit: Implementation Plan

Last updated: 2026-11-07, for release 1.0.10. Keep current: see "Keeping these documents current" in `CLAUDE.md`.
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
| 3 | Review remaining screens in the new look: Build my plate, side menu, later onboarding, food diary, Handbook, library, Calendar | Claude | They shipped unreviewed |
| 4 | Finish, test and commit the update notification work (uncommitted in the folder) | Claude, owner | Requested; needs a phone test |
| 5 | Cooked rice and dal in the diary, from USDA values | Owner approves import | People log cooked food against raw values |
| 6 | Enforce the website CSP after a signed-in web app check | Owner, Claude | Report-only today |

## 3. Decisions waiting on the owner

- Portions on high-calorie plans (7 rotis, 10 idlis at a meal): cap them, add a meal, or leave.
- Merge duplicate soya chunk rows (touches existing diary rows).
- Ask birth month, to admit people turning 18 this year.
- The app's onboarding still says "never suggests beef or pork"; the website no longer does.

## 4. Blocked on others

| Item | Needs |
|---|---|
| Higher-BMI protein rule and other nutrition rules | Qualified dietitian (`docs/legal/OUTSTANDING_REVIEWS.md`) |
| IFCT food values for revenue | NIN written permission, or replacement |
| ExerciseDB media for revenue | Paid plan, or own media |
| iOS native app | A Mac |

## 5. Later, only with evidence

Retention work (challenges, timed prompts), more goals with sourced chapters, Hindi. Social features, leaderboards and
subscriptions wait until retention can be measured; accounts are still too few.

## 6. How work is done

1. Read the code first. Fix root causes. Smallest change that works.
2. Add a test for logic; run `bash tools/verify.sh` for what changed; pgTAP on a throwaway stack for schema.
3. Update the six documents in this folder when behaviour changes.
4. Commit when the owner asks. Production changes need approval each time.
5. Release: migrations, functions, then `tools/release_android.sh`; then the release record.
