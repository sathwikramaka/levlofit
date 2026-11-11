# Release record

One row per check of what users actually get. Add a new dated section for every release; never edit an old one. Older entries name paths from before docs were sorted into folders (2026-11-07); see `docs/README.md`.

## 2026-11-12: release 1.0.12, Handbook book live, Settings row, update notice (owner-approved: Handbook migration, coach-chat deploy, APK, website, MIN_APP_BUILD secret)

| What | Value | How checked |
|---|---|---|
| Source | 2ce625d (Settings row ccf5d9a, update notice 2ce625d) plus the version bump, built from the main folder with nothing uncommitted | git status empty before the build |
| Checks before release | flutter analyze clean, 663 pass + 1 skip; debug APK with workmanager built; functions node 285/0, offline eval 85/0 strict, tsc clean | flutter test, tools/verify.sh functions |
| Backup | The 43 live `handbook_chapters` rows saved as JSON in the private folder before the migration (rollback: reload them, or re-apply the v4 book migration, checklist 3.7m) | row count 43 in the file |
| Migration | 20261107300000_handbook_book (file sha256 7a25f76f...), one transaction through `supabase db query --linked`; history not written (forward-only). Before: 43 rows, no goal_catalog link. After: 69 rows, ids 1 to 69, every row has blocks, fingerprint c3d91b22 as expected | read-only queries before and after |
| Function | coach-chat v40 ACTIVE (book passages); unauthenticated call 401 | supabase functions list, curl |
| Android APK | com.levlofit.app 1.0.12, versionCode 2014, 13,882,404 bytes (13.9 MB), release certificate 7c510c35...4c431384 | aapt2, apksigner on the live file |
| APK SHA-256 | d4837e36eb96136be3750e998a9a26c185b8d1033c50cef79c37905297d4894f, equal on the live download and /version.json | sha256sum of the live file |
| Website | Cloudflare Pages deployment 635fc9a7; /version.json = 1.0.12 build 14, min_build 14; /handbook lists 69 chapters; /handbook/warm-up 301 to /handbook/warmup-mobility; /app/ 200 | curl |
| Secret | MIN_APP_BUILD = 14 (digest equals sha256 of "14") | supabase secrets list |
| Not verified | Nothing on a real phone (docs/operations/DEVICE_CHECKLIST_1_0_12.md). The book is not clinician-reviewed and 1,379 claims are unreviewed: the owner chose to ship it now | - |

## 2026-11-11: release 1.0.11, habit features (owner-approved: APK, website, MIN_APP_BUILD secret)

| What | Value | How checked |
|---|---|---|
| Source | 79ed8e2 plus the version bump 86c92e4, built from a clean git worktree; the uncommitted update-notification work in the main folder is not shipped. Website pages built from the 1.0.10 sources (30c848e), without `_redirects` and the book JSON: the 43-chapter Handbook stays live until the book is finished (owner decision 2026-11-07) | git worktree; `git diff 30c848e -- website` empty |
| Checks before release | flutter analyze clean, 663 pass + 1 skip; release helper tests 6/6; debug APK built; walk-through of the web app on a throwaway local stack (synthetic user): starter, set logging, personal best, finish and minutes, Today's read, weekly report and share, level check and level-up share, Profile levels, reminder switches, photo reveal (by widget test, the pane was hidden) | flutter test, browser pane |
| CI | Not run on the last commits before release | - |
| Android APK | com.levlofit.app 1.0.11, versionCode 2013, 13,720,503 bytes (13.7 MB), release certificate 7c510c35...4c431384 (CN=Levlofit); manifest has the TodayWidget receiver | aapt2, apksigner on the live file |
| APK SHA-256 | 3f05fca435713c6586cb323d9bb33290a903cd8c350d11be3dd492c69fd22305, equal on the live download and /version.json | sha256sum of the live file |
| Website | Cloudflare Pages deployment 12fe7fc5; home links levlofit-1.0.11.apk; /version.json = 1.0.11 build 13, min_build 13; /handbook lists 43 chapters; /app/ 200 | curl |
| Secret | MIN_APP_BUILD = 13 (digest equals sha256 of "13") | supabase secrets list |
| Not verified | Nothing on a real phone: the home screen widget, the Android share sheet, notification taps (recap, check-in, meals), haptics, the in-app update from 1.0.10. Database and functions unchanged; the book migration is still not applied | - |

## 2026-11-07: release 1.0.10, soft card look (owner-approved: APK, website, MIN_APP_BUILD secret)

| What | Value | How checked |
|---|---|---|
| Source | 0bcc2a2 (look 518841f, 8e1e4a2; website FAQ and search without the beef and pork entries 0bcc2a2) plus the version bump, built from a clean git worktree; the uncommitted update-notification work in the main folder is not shipped | git worktree; pubspec has no workmanager; marker string absent from the live APK's libapp.so |
| Checks before release | flutter analyze clean, 635 pass + 1 skip; node 283/0, offline AI eval 85/0 strict, tsc, Deno 30/0; website lint/build/tsc; Handbook and food data tests. Layout only, no database or function change | tools/verify.sh in the release worktree |
| CI | Not run on these commits: they were not pushed before the release | - |
| Android APK | com.levlofit.app 1.0.10, versionCode 2012, 13,661,523 bytes (13.7 MB), release certificate 7c510c35...4c431384 (CN=Levlofit) | aapt2, apksigner on the live file |
| APK SHA-256 | 9dbf1b35d2f5df3eb41b79f32235998115c615c80745c52108c97bd2386062ac, equal on the live download and /version.json | sha256sum of the live file |
| Website | Cloudflare Pages deployment 9cfb0d8b; home links levlofit-1.0.10.apk; /version.json = 1.0.10 build 12, min_build 12; home page HTML has no beef or pork text | curl |
| Secret | MIN_APP_BUILD = 12 (digest equals sha256 of "12") | supabase secrets list |
| Not verified | Nothing on a real phone: the new look, bottom bar, status bar and keyboard behaviour, the in-app update from 1.0.9. Not looked at in the new style: later onboarding steps, Build my plate, side menu, food diary, Handbook, exercise library, Calendar | - |

## 2026-11-07: release 1.0.9, diet accuracy, supplements, workout meals (owner-approved: backup, push, 2 migrations, generate-plan and coach-chat deploys, APK, website, MIN_APP_BUILD secret)

| What | Value | How checked |
|---|---|---|
| Source | 6b791ca (stabilisation 43270ea, 5ded4c7, 3601f29; diet 816084a, 6b791ca) plus the version bump | git |
| Checks before release | flutter analyze clean, 632 pass + 1 skip; node 283/0, offline AI eval 85/0 strict, tsc, Deno 30/0; website lint/build/tsc; Handbook and food data tests; pgTAP 259/259 on a throwaway stack | Local runs on the same source |
| CI | Run 42281607472 on 6b791ca: all 6 jobs green, including pgTAP | gh run view |
| Backup before changes | db-backup run 42281151814, encrypted dump levlofit-db-20261106T193649Z, 311,364 bytes | GitHub Actions |
| Migrations | foods_raw_dry_names (20261107100000): 12 names; kcal total 90532 and 577 foods before and after, rice still 365 kcal. other_supplements (20261107200000): column present, default empty, authenticated may update, anon may not read; 11 profiles, none changed | apply_migration results, read-only checks before and after |
| Edge Functions | generate-plan v36 and coach-chat v36 ACTIVE, verify_jwt true, signed-out POST 401; no signed-in call verified on these versions | Function list, curl |
| Android APK | com.levlofit.app 1.0.9, versionCode 2011, 13,656,203 bytes (13.7 MB), release certificate 7c510c35...4c431384 (CN=Levlofit) | aapt2, apksigner on the live file |
| APK SHA-256 | 796cd82d29c37fb521cf1c1f1262d61e844519a010075b648d68d03fc3ee0a54, equal on the live download, the site and /version.json | Hash of the live file |
| Website | Cloudflare Pages deployment 915ec92b; home links levlofit-1.0.9.apk; /version.json = 1.0.9 build 11, min_build 11; privacy page names supplements you add | Live fetch |
| Secret | MIN_APP_BUILD = 11 (digest equals sha256 of "11") | supabase secrets list |
| Not verified | Nothing in this release has run on a real phone: the update from 1.0.8, the Supplements and Training day cards, custom supplements, rice labels, weekly report additions, welcome back, a signed-in plan rebuild or coach reply on the new functions | - |
| Known | storage-backup.yml is on GitHub without its two S3 secrets, so it fails nightly and photos are not backed up automatically until the owner adds them | docs/BACKUP_RECOVERY_PLAN.md |

## 2026-11-03: release 1.0.8, roadmap stages 2-5 (owner-approved: send-feedback deploy, APK, website, MIN_APP_BUILD secret)

| What | Value | How checked |
|---|---|---|
| Source | 8123372 (stages a446a72, 4f8670e, 6e6955b) plus the version bump; clean tree apart from a local tool lock file | git |
| Checks before release | flutter analyze clean, 601 tests pass + 1 skip; node 283/0, offline AI eval 85/0 strict, tsc, Deno 30/0; website lint/build/tsc; pgTAP 254/254 on a throwaway stack; release_helpers_test in the script | Local runs on the stage commits |
| Edge Function | send-feedback v1 ACTIVE, verify_jwt true, deployed first so the new feedback sheet works; no BREVO_API_KEY / FEEDBACK_FROM yet, so it saves feedback and answers emailed false (app says "saved, not emailed yet"); signed-out POST 401 | Function list, curl |
| Android APK | com.levlofit.app 1.0.8, versionCode 2010, 13,633,127 bytes (13.6 MB), release certificate 7c510c35...4c431384 (CN=Levlofit) | aapt2, apksigner on the live file |
| APK SHA-256 | 869a69aab4957f7c94efe4fb68526186bbc41af955dcc50e23a13d893af48015, equal on the live download, the site and /version.json | sha256sum of the live file |
| Website | Cloudflare Pages deployment 6bd8a8a0; home links levlofit-1.0.8.apk; /version.json = 1.0.8 build 10, min_build 10; privacy page names the check-in and the feedback email flow | curl |
| Secret | MIN_APP_BUILD = 10 (digest equals sha256 of "10") | supabase secrets list |
| Not verified | on a real phone: the in-app update from 1.0.7, check-in card, weekly report, plan-fit card, water hours, Terms link, feedback save; a plan rebuild on generate-plan v29 | - |

## 2026-11-03: migrations daily_checkins and reminder_water_window (owner-approved: these two)

| What | Value | How checked |
|---|---|---|
| Source | 7e4f134 (files 20261103300000_daily_checkins.sql, 20261103400000_reminder_water_window.sql) | git |
| Preflight | daily_checkins absent; reminder_prefs without water_from/water_to, 0 rows | execute_sql, read-only |
| Backup before changes | none: both only add (a new empty table; two nullable columns and a check on an empty table). Rollback in RELEASE_CHECKLIST 3.7x, 3.7y | - |
| Migrations | daily_checkins, then reminder_water_window, applied with apply_migration | apply_migration results |
| Verify | daily_checkins: RLS on, 1 policy, anon no select, authenticated select yes, insert of user_id no, update of energy yes. reminder_prefs: water_from, water_to present, authenticated may update them, reminder_prefs_water_window check present | pg_class, pg_policies, has_*_privilege, read-only |
| Security advisor | nothing on the new objects; unchanged older notes: ai_daily_caps and rate_events have RLS with no policy (service-only by design), check_rate callable by authenticated (the functions call it as the user), leaked password protection off (Pro plan; sign-in is email code or Google) | get_advisors |
| Not verified | the check-in card and water hours on a phone (needs the next app release) | - |

## 2026-11-03: generate-plan deploy (owner-approved: this deploy only)

| What | Value | How checked |
|---|---|---|
| Source | d648818 (plan saved with save_generated_plan in one transaction; age from year of birth = youngest possible age); not pushed | git, clean tree apart from a local tool lock file |
| Checks before deploy | node tests 283/0, offline AI eval 85/0 strict, strict tsc, Deno check/lint/smoke 30/0 (on the same source, Stage 2-5 runs) | Local runs |
| Edge Function | generate-plan v29 ACTIVE, verify_jwt true, deployed with `supabase functions deploy --use-api`; needs save_generated_plan (applied earlier today) | Function list |
| Probe | signed-out POST answers 401 | curl |
| Logs | no generate-plan errors since the deploy; the only call is the probe, refused at the gateway, so the new code has not yet run for a signed-in user | query_logs, read-only |
| Not verified | a real onboarding or plan rebuild on the new version (one plan row, dashboard opens) | - |

## 2026-11-03: migration save_generated_plan (owner-approved: this migration only)

| What | Value | How checked |
|---|---|---|
| Source | 6e6955b (file 20261103200000_save_generated_plan.sql from a446a72); not pushed | git |
| Preflight | function absent; profiles.onboarding_complete and the five generated_plans columns it uses present; daily_checkins absent | execute_sql, read-only |
| Backup before changes | none taken: the migration only adds a function (no table or data change). Rollback in RELEASE_CHECKLIST 3.7w | - |
| Migration | save_generated_plan applied with apply_migration | apply_migration result |
| Verify | function exists; execute: service_role yes, authenticated no, anon no | has_function_privilege, read-only |
| Not done | generate-plan still the deployed version that does two writes (deploy is the next, separately approved step); no live onboarding run | - |

## 2026-11-03: release 1.0.7, simpler diet section (owner-approved: migration, generate-plan, APK, website, MIN_APP_BUILD secret)

| What | Value | How checked |
|---|---|---|
| Source | 4481226 (diet plate view and 3-step Build my plate 2a8da3e, restyled to the app theme 35ede93; APK size in decimal MB a963854) plus version bump; clean worktree, uncommitted send-feedback work not shipped | git worktree at HEAD |
| Checks before release | flutter analyze clean, 576 tests; website lint/build/tsc; 263 node tests, offline AI eval 85/85 strict; Deno check, lint, smoke 30/30; Python register and builder tests, generated migrations in sync; pgTAP 230/230 on a throwaway local stack (deleted after) | Local runs on 4481226 |
| Backup before changes | db-backup run 41587435151, encrypted dump levlofit-db-20261103T060258Z | GitHub Actions log |
| Migration | foods_fdc_breakfast (file 20261103100000) applied with apply_migration: foods.source_note, six USDA FDC breakfast foods (rolled oats, corn flakes, muesli, daliya, rava, besan), older usda_fdc duplicates aligned | apply_migration result; not re-queried live |
| Edge Function | generate-plan deployed from 4481226 (oats counted under gluten; flagged for professional review); signed-out POST answers 401 | Deploy result, probe |
| Android APK | com.levlofit.app 1.0.7, versionCode 2009, 13,614,691 bytes (13.6 MB), release certificate 7c510c35...4c431384 | aapt2, apksigner |
| APK SHA-256 | 7faae96a0978f464cd4d3990bfa4622c54670e77f8a4995dc4de018a736dff32, equal on the live download, the site and /version.json | sha256sum of the live file |
| Website | Cloudflare Pages deployment 84438668; "Version 1.0.7 · 13.6 MB"; /version.json = 1.0.7 build 9, min_build 9; Open on iPhone and the Google verification tag present | curl |
| Secret | MIN_APP_BUILD = 9 | supabase secrets list (digest) |
| Not verified | The restyled diet screens and the in-app install on a real phone (first in-app update: 1.0.6 to 1.0.7) | - |

## 2026-11-03: release 1.0.6, in-app update (owner-approved: APK, website, MIN_APP_BUILD secret)

| What | Value | How checked |
|---|---|---|
| Source | 405ae8d (Update downloads, SHA-256-checks and installs inside the app; browser fallback) plus version bump; clean worktree, uncommitted send-feedback work not shipped | git worktree at HEAD |
| App checks | flutter analyze clean; 570 tests passed, 1 skipped; release APK builds | Release worktree |
| Android APK | com.levlofit.app 1.0.6, versionCode 2008, 13.0 MB, release certificate 7c510c35...4c431384; adds REQUEST_INSTALL_PACKAGES and a FileProvider (com.levlofit.app.updates, cache/updates only) | aapt2, apksigner |
| APK SHA-256 | f9a9e2372f4a091655d0f1f573992855db8a8cd5a30c92ae7b6705ec01cc592b, equal on the live download, the site and /version.json sha256 | sha256sum of the live file |
| Website | Cloudflare Pages deployment 2c2e7d1c; /version.json = 1.0.6 build 8, min_build 8, sha256 set | curl |
| Secret | MIN_APP_BUILD = 8 | supabase secrets list (digest) |
| Not verified | The in-app install on a real phone (no device here); first exercised by the 1.0.7 update. 1.0.0 and 1.0.1 have no update check and need one manual install | - |

## 2026-11-03: release 1.0.5, version shown in the menu (owner-approved: APK, website, MIN_APP_BUILD secret)

| What | Value | How checked |
|---|---|---|
| Source | 294aa70 (menu row and licence page show appVersion/appBuild instead of a fixed 1.0 / 1.0.0) plus version bump; clean worktree, uncommitted send-feedback work not shipped | git worktree at HEAD |
| App checks | flutter analyze clean; 569 tests passed, 1 skipped | Release worktree |
| Android APK | com.levlofit.app 1.0.5, versionCode 2007, 13.0 MB, release certificate 7c510c35...4c431384; sends x-levlofit-build | aapt2, apksigner, libapp.so string check |
| APK SHA-256 | ef05990056b100b7eb890e767442d1d76046c4c010d6b06c25b9e6b0f1e30d25, equal on the live download and the site | sha256sum of the live file |
| Website | Cloudflare Pages deployment 82beeec6; /version.json = 1.0.5 build 7, min_build 7; Google verification tag still on the home page | curl |
| Secret | MIN_APP_BUILD = 7: 1.0.0-1.0.4 are told to update (coach, plan, body check answer 426; 1.0.2+ show the update card, required on 1.0.4) | supabase secrets list (digest) |

## 2026-11-03: release 1.0.4, required updates (owner-approved: functions, APK, website, MIN_APP_BUILD secret)

| What | Value | How checked |
|---|---|---|
| Source | b2b396d plus version bump b76e6ee, built from a clean worktree (uncommitted send-feedback work not shipped) | git worktree at HEAD |
| Edge Functions | coach-chat v26, generate-plan v24, body-check v5 (each deployed, then restarted by the secret change; delete-account v14 restarted only). Builds below MIN_APP_BUILD, and requests without x-levlofit-build (1.0.0-1.0.3), get 426 with the update message; browser requests pass | Function list; node test rate.test.ts. Not exercised live: needs a signed-in test account |
| Secret | MIN_APP_BUILD = 6 (digest matches) | supabase secrets list |
| App checks | flutter analyze clean; 573 app tests, 191 Edge Function node tests, 30 Deno smoke tests passed | Local runs before b2b396d |
| Android APK | com.levlofit.app 1.0.4, versionCode 2006, 13.0 MB, release certificate 7c510c35...4c431384; sends x-levlofit-build; update check compiled in | aapt2, apksigner, libapp.so string check |
| APK SHA-256 | 4e8be9808b769df3dd96319538a58fdf06bf631022e35a5222b5be4fdfc83f8c, equal on the live download and the site | sha256sum of the live file |
| Website | Cloudflare Pages deployment 0a92b7a8; /version.json = 1.0.4 build 6, min_build 6, so 1.0.2 and 1.0.3 show an update card with no Later button | curl |

## 2026-11-03: release 1.0.3 (owner-approved: remediation migration, functions, APK, website)

| What | Value | How checked |
|---|---|---|
| Source | 3b0f7d3 (remediation commits 2da6b38..3b0f7d3) plus the version bump ef19091, built from a clean worktree so uncommitted send-feedback work was not shipped | git worktree at HEAD |
| CI | Run 41500241783 on 3b0f7d3: all jobs green | gh run list |
| Backup before changes | db-backup run 41500242618, encrypted dump levlofit-db-20261102T182425Z | GitHub Actions log |
| Migration | ai_daily_caps (file 20261102100000) applied with apply_migration: ai_daily_caps table (no rows, so no app-wide cap yet), rate_events_bucket_at index, check_rate with the cap check | apply_migration result |
| Edge Functions | coach-chat v24, generate-plan v22, body-check v3 deployed with `supabase functions deploy --use-api` (rate limits fail closed, AI_DISABLED kill switch, body-check byte cap and image checks); all ACTIVE, signed-out POST answers 401, no function errors logged since deploy. delete-account v13 unchanged; send-feedback not deployed | Function list, signed-out probe, function logs |
| App checks | flutter analyze: no issues; flutter test: 568 passed, 1 skipped | Release worktree |
| Android APK | com.levlofit.app 1.0.3, versionCode 2005, 13.0 MB, release certificate 7c510c35...4c431384, update check compiled in, no send-feedback call | aapt2, apksigner, libapp.so string check |
| APK SHA-256 | 52a5c5e245d576f09983e50e0fa3785c091cc33f241cf49e093114a7ce9f6f81, equal on the live download and the site | sha256sum of the live file |
| Website | Cloudflare Pages deployment 240091ba (branch main); home links levlofit-1.0.3.apk; /version.json = 1.0.3 build 5, so 1.0.2 phones show "Update ready" | curl |

## 2026-10-30: release 1.0.2 (owner-approved: signup guard migration, APK, website)

| What | Value | How checked |
|---|---|---|
| Migration | signup_guard (file 20261030100000) applied with apply_migration: before-user-created hook function, hourly purge-unconfirmed-users cron job. The hook is not active until the owner selects it under Authentication > Auth Hooks | apply_migration result; pgTAP on a throwaway stack (215 tests) |
| Android APK | com.levlofit.app 1.0.2, versionCode 2004, 13.0 MB, release certificate 7c510c35...4c431384. First build with the update check compiled in (levlofit.pages.dev/version.json); 1.0.0 and 1.0.1 never checked, so their users must install 1.0.2 by hand once | aapt2, apksigner, libapp.so string check |
| APK SHA-256 | 0bb3b03c08bbcd1f6e97e5a39321b78ff356511e2f4705c2db6bd38e44a9cbbb, equal on the live download and the site | sha256sum of the live file |
| Website | Cloudflare Pages deployment 2017e667 (branch main) by tools/release_android.sh; home links levlofit-1.0.2.apk; /version.json = 1.0.2 build 4 | curl |

## 2026-10-29: release 1.0.1 (owner-approved: migrations, functions, APK, website)

| What | Value | How checked |
|---|---|---|
| Backup before changes | db-backup run 40777558939: 5 dumps, AES-256, decrypt round trip OK | GitHub Actions log |
| Migrations | 20261029600000_mixed_regions, 20261029700000_packaged_foods applied with apply_migration; preflight: no multi-region values, 0 food_log rows without food_code | Read-only preflight; schema fingerprint after = local stack (colgrant 523 2949448d1566, column 274 8f4ad631d3a6, constraint 201 1f6f1a812d91, function 15 8ff793963657, index 65, policy 38 43717f6f6703, trigger 11) |
| Android APK | com.levlofit.app 1.0.1, versionCode 2003, 13.0 MB (native libraries now compressed: Cloudflare Pages refuses files over 25 MiB), same release certificate 7c510c35...4c431384, not debuggable, allowBackup false; permissions add CAMERA (barcode scan only), no microphone or storage | aapt2, apksigner |
| APK SHA-256 | 8dd9f45c1d86ba30b5acabd726afd0b2178a5c606ef9097c87c9a2fef3dcc3a4, equal on the live download and the site. Replaces build 52c849f4..., live for about 20 minutes, whose app_version.dart still said 1.0.0+2 (its update notice would keep offering 1.0.1; installing the fixed file over it ends that). CI caught it in release_helpers_test | sha256sum of the live file |
| Website | Cloudflare Pages deployment 17d5b336 (branch main, replaces 083cc000): /, /handbook (43 chapters), /privacy, /terms, /delete-account, /app/, /version.json = 1.0.1 build 3; report-only CSP served, no violations on the home page; search opens Handbook chapters | curl and browser |
| Edge Functions | body-check v2 and coach-chat v23 deployed from 0911278 with `supabase functions deploy --use-api` after the owner logged in; both booted without errors (35-41 ms) and refuse signed-out calls (401); delete-account v13 and generate-plan v21 unchanged | Function list, function logs, signed-out probe |
| CI | Run 40777242775 on 6b274a9: all 6 jobs green | gh run view |

## 2026-10-29: state of the live release (read-only checks, owner-approved)

| What | Value | How checked |
|---|---|---|
| Website | https://levlofit.pages.dev, serves /, /privacy, /terms, /delete-account and /download/levlofit-1.0.0.apk (200, application/vnd.android.package-archive) | Browser fetch |
| Live headers | HSTS max-age=31536000; includeSubDomains, X-Content-Type-Options nosniff, X-Frame-Options DENY, Referrer-Policy strict-origin-when-cross-origin, Permissions-Policy camera=(), microphone=(), geolocation=(), payment=(), usb=(). No CSP yet (report-only CSP added in website/public/_headers, ships with the next site deploy) | Response headers of / |
| Android APK | com.levlofit.app 1.0.0, versionCode 2002, targetSdk 36, allowBackup false, not debuggable | aapt2 dump badging and xmltree |
| APK signature | APK Signature Scheme v2, signer CN=Levlofit, OU=Levlofit, O=Levlofit, L=Hyderabad, ST=Telangana, C=IN; certificate SHA-256 7c510c3524ede1844d4081b8890663bd25b4f1ec02495a648bb3e3bd4c431384 (release key, not the Android debug key) | apksigner verify --print-certs |
| APK file SHA-256 | 7aa7e737d1a8fc5bafea4b631b0673b16e83ad80bbb7a11b82e27137b2c39f54, equal to the checksum shown on the website | sha256sum of the downloaded file |
| Database schema | Equal to all local migrations up to 20261029500000 (12/12 fingerprint kinds); history table not updated since 20261007092712, see docs/MIGRATION_RECONCILIATION.md "Production state" | tools/schema_state.sql, read-only |
| Reference data | foods 571, goal_catalog 12, curriculum_levels 36, handbook_chapters 43, food_sources 3: hashes equal to local; exercises 1500 catalogue rows | Read-only hashes |
| Edge Functions | delete-account v13, generate-plan v21, coach-chat v22, body-check v1, all last updated 2026-10-28 | Supabase function list |
| Rate limits | check_rate knows body_check_day (3 a day) | ops_health.sql |
| Operations | 0 orphan progress photos (1 photo in total), 0 app errors in 7 days, 0 users at the body-check cap | ops_health.sql |
| Funnel | 6 accounts, 5 new in 7 days, 5 finished onboarding, 2 active in 7 days | ops_health.sql (counts only) |
| CI | Hosted on GitHub; every push since 2026-10-28 failed only the "Handbook evidence register" job (stale .pyc in a same-second test edit); fixed locally in data/evidence/extract_claims.py, proven on the next push | gh run list / view |

### Waiting for the next release (built and tested locally, not deployed)

- Edge Functions: body-check fails closed on rate-limit errors and refuses oversized uploads; coach-chat assumption rule and packaged foods in diary totals. Deploy needs the owner's approval (CLAUDE.md).
- Migrations 20261029600000_mixed_regions and 20261029700000_packaged_foods (docs/RELEASE_CHECKLIST.md 3.7s, 3.7t).
- App: secure session storage, offline read-only copy, health-change hold, strength card, Level check guide, muscle map tap slop, mixed regions, barcode lookup.
- Website: Handbook pages, estimate, search fix, report-only CSP, accessibility fixes.
- Workflows: ops-health.yml (daily) and restore-drill.yml (weekly) need the SUPABASE_DB_URL secret, which the backup already uses.

### Rollback

- Website: redeploy the previous `website/out` build (`npx wrangler pages deploy` of the earlier commit) or roll back in the Cloudflare Pages dashboard.
- App: users keep 1.0.0 until they install a newer APK; an APK update cannot be rolled back on a phone, so a bad release is fixed forward with a higher versionCode signed with the same key.
- Database: each migration's rollback is in docs/RELEASE_CHECKLIST.md; take a backup first (db-backup workflow, workflow_dispatch).
- Edge Functions: redeploy the previous commit's function source.
