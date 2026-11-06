# Remediation report (2026-11-02)

Brief: `Levlofit_Claude_Remediation_Instructions.md` (13 findings). Branch `levlo/stage1-fixes`, starting at 1d55b9c
(release 1.0.2, build 4). Work is in commits 2da6b38..79b8514 plus this report. **Nothing was deployed and nothing on the
live Supabase project was read or changed.** The live website was only read (public pages, `/version.json`,
response headers) and the live search was used in the browser pane.

## Executive summary

All four P0 findings are fixed in code and tested locally. Two of them only take effect after owner-approved
deployment: the encrypted offline cache ships in a new APK, and the fail-closed AI limits ship with three Edge
Function deploys plus one new migration. Release metadata for 1.0.2 is consistent: the local APK, the live site and
the release record agree. The nutrition logic now has a single source and is pinned by tests, but it has not been
clinically reviewed. Protein for high BMI is still calculated on actual body weight, and that is flagged for review,
not changed. Two shipped data sources still lack commercial permission: IFCT, kept by the owner's decision, and
ExerciseDB. Backups of the photo storage have never been run against production. **Recommendation: READY FOR
INTERNAL TEST.** It is not ready for a staged release until the deployments below are approved and verified on
production, and the clinical and licensing items have an owner decision.

## Finding status

| # | Finding | Status | Evidence |
|---|---|---|---|
| 2 (P0) | Offline cache encryption, expiry, isolation | FIXED IN CODE — NOT VERIFIED IN PRODUCTION | `app/lib/offline_cache.dart`: the cache moved from SharedPreferences to `flutter_secure_storage`, which was already a dependency (Android Keystore-backed AES, iOS Keychain). There is one entry, tagged `{v, uid, at}`. A wrong account, an entry older than 14 days, a future date, a format mismatch, a decrypt failure or a parse failure deletes the entry and reads as no cache. Old plain-text `offline_dashboard_*` keys are removed on clear. `app/lib/main.dart`: the cache is cleared on any auth change (sign-out, session loss, account switch). The existing clear paths still run on sign-out and on deletion (`account.dart`). The offline dashboard is still read-only. Tests: `app/test/offline_cache_test.dart`, 9 cases including A then B on the same phone, expired, corrupt, undecryptable and legacy keys. The fix reaches phones only with the next APK. |
| 3 (P0) | Body-check real body limit | FIXED IN CODE — NOT VERIFIED IN PRODUCTION | `_shared/body-check.ts` `readCapped` counts streamed bytes and cancels once it passes `MAX_REQUEST_BYTES` (5,593,432 bytes, the base64 of a 4 MiB photo plus 1 KiB of JSON). A declared Content-Length over the cap is refused before anything is read. The function checks for a JSON content type (415), the base64 alphabet and length, the decoded size (413) and the JPEG/PNG/WebP signature (400). It does these checks before the rate limit and the model call, and it stores nothing. Image dimensions are not checked; the provider handles that. Tests: `body-check.test.ts` covers a stream with no Content-Length, a false Content-Length, a body at the exact boundary and signatures. `_test/deno-smoke.ts` adds 8 body-check cases against the real runtime. The deployed function is still v2 (old code). |
| 4 (P0) | AI rate-limit failure policy, spend controls | FIXED IN CODE — NOT VERIFIED IN PRODUCTION | Policy: every limit fails closed. `_shared/rate.ts` returns `'unavailable'` (HTTP 503 with a generic message) on any `check_rate` error, a thrown call or a non-boolean answer. Callers in coach-chat (3 places), generate-plan and body-check use `rateRefusal`. App-wide spend ceiling: migration `20261102100000_ai_daily_caps` adds an optional 24-hour cap per bucket; a cap of 0 stops that bucket. Kill switch: the `AI_DISABLED=1` secret makes every model call answer 503 without a code change. Monitoring: these log events are available to alert on: `rate_limit_error`, `rate_limit_unavailable`, `ai_daily_cap_reached`, and the existing `body_check`/LLM status and timing lines. No alert is wired up yet. Timeouts were already in place: LLM 25 s per call, a 45 s request budget, retries capped at 2, body-check 30 s. Tests: `rate.test.ts`, `llm.test.ts` (kill switch), coach-chat and generate-plan tests for the outage case, smoke tests (outage gives 503, AI_DISABLED gives 503), pgTAP `ai_daily_caps.test.sql` (9). |
| 13 (P0) | Account deletion and storage lifecycle | FIXED AND VERIFIED (code and local tests); production run not repeated | The delete-account flow was already correct and is unchanged. It clears `progress-photos/<uid>` (progress photos and avatar) and deletes the account only once that folder is empty. Any storage failure gives 500 with `deleted:false` and the account stays. A repeat call after success counts as success. A late sweep runs after deletion. The app then clears reminders and the offline cache. Body-check photos are never stored. New pgTAP `account_deletion.test.sql` checks the schema catalogue: every public foreign key to `auth.users` cascades, every `user_id` column cascades, and no bucket is public. It also checks that rows are removed when the user is deleted. The existing node tests (19 cases) cover partial failures. The privacy page (sections at lines 208–220) matches this behaviour. Gap: no end-to-end run with real Storage on an isolated stack, and AI messages already sent to Groq cannot be deleted (the policy says so). |
| 7 (P1) | Release version consistency | FIXED AND VERIFIED (1.0.2) | Every source agrees on 1.0.2, build 4: `app_version.dart`, `pubspec.yaml`, Gradle (`flutter.versionCode`), aapt2 on the local `app-arm64-v8a-release.apk` (versionCode 2004), live `/version.json`, the live home page (`levlofit-1.0.2.apk`, 13.0 MB) and `RELEASE_RECORD.md`. The local APK's SHA-256 is `0bb3b03c…cbbb`, the same value the live page shows. I did not re-download the live APK; the release record of 2026-10-30 hashed that file. The fixes in this report need a 1.0.3 release. |
| 5 (P1) | High-BMI protein | OUTSTANDING (clinical decision) | There is one calculation: `plan-engine.ts` (`proteinG = round(weightKg × 1.4–2.0 g/kg)`). The website copy is generated from the same file (`npm run engine`, byte-identical), and the app only displays `plan.nutrition.proteinG`. Adjusted body weight is **not** implemented, and the existing test records that this is deliberate until a source is approved. Kidney disease only adds a see-your-doctor note and removes creatine; protein is not lowered. No change was made. Flagged in `REVIEW_PACKAGES.md` section 7. |
| 6 (P1) | Normal-BMI body composition ("skinny-fat") | PARTIALLY FIXED | The only signal is the body type the user picks (`slim_soft`), together with a beginner level and a bulk goal. Nothing is inferred from BMI and there is no automatic deficit (recomposition is maintenance energy). The label was changed from "Skinny-fat" to the neutral "Slim but soft" (`onboarding.dart`, finding copy). The goal change is shown on the review step but is not asked for confirmation; that needs a product and professional decision. A new test covers every branch. |
| 8 (P1) | Food-data licensing | PARTIALLY FIXED (documented, not cleared) | `LICENSING_REQUIREMENTS.md` now has a current-state section. IFCT 2017 ships by owner decision of 2026-10-27 (migration `20261028100000_ifct_release`); NIN permission has not been requested. ExerciseDB is allowed for non-commercial use only. Open Food Facts (ODbL, per-person) and USDA (CC0) are fine. Credits are in place (`SOURCE_LICENCE_REGISTER.md`). This is not legal clearance. |
| 9 (P1) | Backup and restore including photo storage | PARTIALLY FIXED (documented) | The daily backup and the weekly drill cover the database only. Photos are covered only by the manual `tools/backup_prod.sh`, which has been rehearsed on synthetic data and never run against production. `BACKUP_RECOVERY_PLAN.md` now states RPO and RTO, that the bucket stays private, and the coverage gaps. |
| 10 (P1) | Professional review and AI evaluation | PARTIALLY FIXED | The review backlog is `REVIEW_PACKAGES.md`, now with section 7 added. No professional review has happened. The offline eval has a new `extreme-goal` case (crash diet or water fast is refused). The existing cases cover medical holds, allergies, injuries, ambiguity, prompt injection and confirm-only changes. The live-provider eval was **not run** (no approval or credentials). No real-device or manual accessibility pass was done this session. |
| 11 (P2) | Website, handbook, accessibility | PARTIALLY FIXED | Checked live: all 43 chapter slugs return 200, an unknown slug returns 404, a trailing slash redirects with 308, and search → chapter works with the keyboard (Ctrl+K or the button, typing, arrows, Enter). Fixed: the search input now has combobox semantics (`aria-activedescendant`), so screen readers announce the selected result (`search.tsx`; not deployed). Contrast and WCAG were **not** re-checked; no WCAG AA claim is made. |
| 12 (P2) | MuscleMap hit testing | FIXED IN CODE — NOT VERIFIED IN PRODUCTION | `muscle_map.dart`: the near-miss fallback now measures distance to the nearest outline edge instead of the bounding box. A tap in a gap no longer picks a muscle whose box merely covers it. Ties go to list order, and the slop is still 22 dp, clamped to 2–6 canvas units. Non-precision alternatives already exist: a group chip list (`exercises.dart:801`) and per-group semantics buttons. Tests cover exact hits, gaps, nearest of two, ties and misses. |
| 14 (P2) | Barcode and packaged food | FIXED IN CODE — NOT VERIFIED IN PRODUCTION | Values are kept per 100 g only. The user checks and edits them and enters the grams eaten (`packaged_food.dart`). Range and sum checks already existed (`packagedProblem`). Added: GS1 check-digit validation, so a misread or mistyped code is refused before the Open Food Facts lookup. Not covered: whether kcal is consistent with the macros. Provenance is in `SOURCE_LICENCE_REGISTER.md`. |

## Files changed (this work)

- `app/lib/offline_cache.dart`, `main.dart`, `dashboard.dart`, `test/offline_cache_test.dart`: secure, account-bound, expiring cache.
- `supabase/functions/_shared/rate.ts`, `rate.test.ts`, `llm.ts`, `llm.test.ts`; `coach-chat/index.ts` and its test; `generate-plan/index.ts` and its test; `_test/supabase-server-mock.mjs`: fail-closed limits and kill switch.
- `supabase/migrations/20261102100000_ai_daily_caps.sql`, `supabase/tests/database/ai_daily_caps.test.sql`: app-wide caps.
- `supabase/functions/body-check/index.ts`, `_shared/body-check.ts`, `body-check.test.ts`, `_test/deno-smoke.ts`: byte cap and validation.
- `supabase/tests/database/account_deletion.test.sql`: cascade and private-bucket coverage.
- `supabase/functions/_shared/plan-engine.ts`, `plan-engine.test.ts`, `app/lib/onboarding.dart`: neutral wording and branch tests.
- `supabase/functions/_eval/cases.ts`, `score.ts`: extreme-goal case.
- `app/lib/muscle_map.dart`, `app/test/muscle_map_test.dart`: outline-distance hit testing.
- `app/lib/barcode.dart`, `packaged_food.dart`, `app/test/packaged_food_test.dart`: GS1 check digit.
- `website/src/components/search.tsx`: combobox semantics.
- `docs/release/RELEASE_CHECKLIST.md` (3.7u), `MIGRATION_RECONCILIATION.md` (new pending item; signup_guard row recorded from RELEASE_RECORD), `LICENSING_REQUIREMENTS.md`, `BACKUP_RECOVERY_PLAN.md`, `REVIEW_PACKAGES.md`, this report.

Another session's uncommitted work was left untouched and is not part of these commits: send-feedback, `dashboard_tabs.dart`, `ci.yml`, `verify.sh`, the privacy page and `PROGRESS.md`. That work's tests are included in the runs below.

## Tests and checks (2026-11-02, local)

| Check | Result |
|---|---|
| `flutter analyze --no-pub` (app/) | No issues |
| `flutter test --no-pub` | 572 passed, 1 skipped, 0 failed |
| node:test (the 11 files listed in ci.yml) | 271/271 |
| Offline AI eval `_eval/run.ts` | strict 85/85, indicative 8/8 |
| Strict tsc of `_shared` and eval modules | clean |
| `deno check` (5 entry points), `deno lint`, Deno smoke | clean; smoke 30/30 |
| Website `npm run lint`, `npm run build`, `tsc --noEmit` | clean (52 static pages) |
| pgTAP, throwaway stack `levlofit_remed_throwaway` (ports 54335/54339, stopped afterwards) | 22 files, 228/228 |
| Handbook and FDC builder checks (ci.yml handbook job) | OK; builders leave the migrations unchanged |
| `tools/release_docs.test.mjs` | pass. Before this work it failed because signup_guard was not recorded; fixed. |

Not run: the live AI provider eval, Android device tests, the APK build, automated contrast and WCAG checks, and an end-to-end deletion test against real Storage.

## Migrations and Edge Functions

| Item | Local / throwaway | Production |
|---|---|---|
| Migration 20261102100000_ai_daily_caps | Applied on the throwaway stack; pgTAP passes | **Not applied** (needs approval; RELEASE_CHECKLIST 3.7u) |
| Migration 20261027200000_body_check_rate | unchanged | Already live per RELEASE_RECORD; not re-applied or re-inspected |
| coach-chat, generate-plan, body-check | New code is type-checked and smoke-tested | **Not deployed** (live: coach-chat v23, generate-plan v21, body-check v2) |
| delete-account | unchanged | v13, unchanged |
| Website (search a11y) | built locally | **Not deployed** |
| App (offline cache, wording, map, barcode) | tests pass | **Not built or released** (live: 1.0.2 / 2004) |

## Owner manual steps (each needs its own approval)

1. Apply `20261102100000_ai_daily_caps` (take a backup first), then deploy coach-chat, generate-plan and body-check from the same commit. The functions fail closed, so the migration must be live before they deploy. Then probe: a signed-out call returns 401, and a normal chat still works.
2. Decide the app-wide caps (`insert into public.ai_daily_caps (bucket, per_day) values (...)`). There are none until you add them. Test the kill switch once with `supabase secrets set AI_DISABLED=1`, then unset it.
3. Wire an alert on `ai_daily_cap_reached`, `rate_limit_error` and provider-error log events (for example in ops-health.yml).
4. Release 1.0.3 with `tools/release_android.sh`, then add a dated RELEASE_RECORD section.
5. Deploy the website.
6. Run `tools/backup_prod.sh` against production once, so the photos are covered. Decide on a scheduled photo backup.
7. Enable the signup_guard hook under Authentication > Auth Hooks (still pending from 2026-10-30).
8. Clinical review: `REVIEW_PACKAGES.md` sections 1, 2 and 7 (protein for high BMI, the body-type switch, kidney and pregnancy).
9. Licensing: NIN permission for IFCT or remove it; an ExerciseDB plan or replacement before any revenue.

## Remaining risks

- **Security and privacy:** until 1.0.3 is installed, phones on 1.0.2 keep the plain-text offline copy. It is deleted on the first clear after updating, on sign-out, or when it fails to read. Until the functions are deployed, production coach-chat and generate-plan still fail open on rate-limit errors.
- **Cost:** no app-wide cap is active until the owner sets one, and no alert is wired.
- **Clinical:** protein on actual weight at high BMI (a 110 kg cut gets about 220 g a day); the automatic goal switch without confirmation; no algorithm has had a professional review.
- **Licensing:** IFCT and ExerciseDB ship without commercial rights (free launch only).
- **Recovery:** photos have no tested production backup.
- **Accessibility:** contrast and screen-reader passes were not done this session.

## Release recommendation

**READY FOR INTERNAL TEST.** This is not a staged release: the P0 fixes are not on production or on phones yet, and
clinical review, licensing and photo backup are still open. Passing automated tests do not make the release ready.
