# Levlofit: Technical Requirements Document

Last updated: 2026-11-07, for release 1.0.10. Keep current: see "Keeping these documents current" in `CLAUDE.md`.

## 1. Architecture

```
Flutter app (Android APK, web at /app/)  ──> Supabase (Postgres + RLS, Auth, Storage)
        │                                          │
        └── Edge Functions (Deno) ─────────────────┘
              generate-plan   rule engine, saves the plan
              coach-chat      context + Groq (LLM provider)
              body-check      one photo, nothing stored
              send-feedback   saves, emails through Brevo
              delete-account  removes files, then the account
Next.js static site on Cloudflare Pages: marketing, Handbook, APK, /version.json
```

## 2. Stack

| Layer | Choice | Where |
|---|---|---|
| App | Flutter, package `levlo`, id `com.levlofit.app` | `app/` |
| Backend | Supabase project `ndeozgxowggkljluaccz` (ap-south-1, free plan) | `supabase/` |
| Plan engine | TypeScript, deterministic, version 3.5.0 | `supabase/functions/_shared/plan-engine.ts` |
| Diet planner | Dart, deterministic, runs on the phone | `app/lib/diet_plan.dart` |
| LLM | Groq `openai/gpt-oss-120b`; `LLM_BASE_URL`, `LLM_MODEL` switch it | `_shared/llm.ts` |
| Website | Next.js 16, React 19, Tailwind 4, static export | `website/` |
| CI and jobs | GitHub Actions | `.github/workflows/` |

Zero-cost rule: free tiers and open-source only. Say the price and offer the free route for anything paid.

## 3. Requirements

**Accuracy.** Numbers come from rules and stored food values, with sources in code. The LLM gets the plan as context.
**Reliability.** LLM calls: 1 retry on 429, 5xx and network; timeouts; malformed replies regenerated once then refused;
`AI_DISABLED` kill switch; optional approved fallback. Plan save is one transaction and retry-safe (`save_generated_plan`).
**Security.** RLS on every table, column-level grants, no anon access to personal data, `verify_jwt` on all functions, fail
closed on rate-limit errors, session in secure storage, secrets only in Supabase and GitHub secrets.
**Limits.** Per user: 30 chats an hour, 150 a day, 20 plan rebuilds a day, 3 body checks a day. App-wide (`ai_daily_caps`):
500 chats, 100 rebuilds, 30 body checks a day. Groq's own limits: read them in the Groq console.
**Privacy.** Logs hold no content. Allowlisted context to the AI provider, with `LLM_DATA_APPROVED` required. Daily
check-ins and own supplements are not sent. Deleting an account removes its files and all rows (cascade).
**Accessibility.** 48 dp targets, text scaling tested to 1.5, meaning never by colour alone, reduced-motion respected.
**Devices.** Works at 320 dp and up; light and dark. Android `targetSdk 36`.
**Offline.** Encrypted per-account copy of the last plan; read-only.
**Time.** All logs key on the phone's local day. The server takes `localDay` from the app.

## 4. Secrets (names only, never values)

Supabase: `LLM_API_KEY`, `LLM_DATA_APPROVED`, `MIN_APP_BUILD`, `BREVO_API_KEY`, `FEEDBACK_FROM`.
GitHub: `SUPABASE_DB_URL`, `BACKUP_PASSPHRASE`, and, **not yet set**, `STORAGE_S3_KEY_ID`, `STORAGE_S3_SECRET`.
Local: `app/android/key.properties` (ignored by git); keystore in `C:\Projects\Levlofit-private\levlofit-signing\`, with production
backups beside it, both outside this public repository. Never commit or delete the keystore: losing it means no updates
for installed apps. If it moves, update `storeFile` in `key.properties`.

## 5. Testing

| Check | Command |
|---|---|
| Everything but the database | `bash tools/verify.sh` |
| One area | `bash tools/verify.sh flutter` (`functions`, `deno`, `website`, `handbook`) |
| Database (pgTAP) | A throwaway stack, never the dev or cloud database |
| Photo backup drill | `bash tools/storage_restore_drill.sh` |

Keep evidence labels apart: automated, CI, production, real device. Never claim one as another.

## 6. Release

`tools/release_android.sh` (Git Bash, repo root) bumps past the live version, builds the signed APK, deploys the site,
checks `/version.json`, sets `MIN_APP_BUILD` so older builds are told to update (`MIN_BUILD=<n>` to allow them).
Build from a clean worktree when the folder holds uncommitted work. Then commit the bump and add a dated section to
`docs/release/RELEASE_RECORD.md`. Order: migrations, then functions, then app.

Production changes need the owner's approval each time (`CLAUDE.md`). Migrations only through `supabase/migrations/`.

## 7. Operations

| Job | Schedule | Failure |
|---|---|---|
| `db-backup.yml` | Daily, encrypted, 30 days | GitHub email |
| `storage-backup.yml` | Daily, encrypted, 30 days. **Fails until the S3 secrets are set** | GitHub email |
| `restore-drill.yml` | Weekly | GitHub email |
| `ops-health.yml` | Daily, counts only | GitHub email |
| `keep-alive.yml` | Keeps the free Supabase project and GitHub schedules from pausing | GitHub email |

Recovery: `docs/operations/BACKUP_RECOVERY_PLAN.md`. The repository is public: logs print counts only, and no real metrics go in docs.

## 8. Live versions

App 1.0.10 build 12; `generate-plan` and `coach-chat` from 2026-11-06; `send-feedback` from 2026-11-03; `body-check` from
2026-11-02; `delete-account` from 2026-10-27. History: `docs/release/RELEASE_RECORD.md`.
