# Release record

One row per check of what users actually get. Add a new dated section for every release; never edit an old one.

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
