# Release record

One row per check of what users actually get. Add a new dated section for every release; never edit an old one.

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
