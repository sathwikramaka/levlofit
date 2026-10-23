# Release setup: what is ready locally, and the actions only the owner can take

Prepared 2026-10-16 (batch 2E). Nothing here touches production. Each owner action needs your own account or a
credential, and Claude never sees or stores it.

## Ready locally

| Item | State |
|---|---|
| Backend selection | No build reaches the cloud project by default (app/lib/main.dart). The store build needs `--dart-define=LEVLOFIT_BACKEND=production`. Debug and profile builds only run against the local stack. A release build with no backend shows a message and makes no network call (test/backend_guard_test.dart). |
| Android signing | android/app/build.gradle.kts reads the keystore from environment variables or android/key.properties (git-ignored, template in key.properties.example). Without either, a release build stops. |
| Git hygiene | key.properties, *.jks, *.keystore, website/.env* and tools/local-test-user.txt are git-ignored (checked with `git check-ignore`). A secret scan of every file that would be pushed found no service keys, JWTs, provider keys or private keys. The Supabase publishable key in the code is public by design. |
| CI | .github/workflows/ci.yml: 6 jobs (flutter, website, functions, deno, handbook, database). Actions are pinned to commit SHAs, and the workflow needs no secrets. It has never run, because the repository has no remote. |
| Website | Fully static (no API routes, no middleware). It builds with `next build`. Security headers live in next.config.ts for a Node/Vercel host and in public/_headers for a static host. |
| AI coach | coach-chat refuses to send user data until `LLM_DATA_APPROVED` names the provider (batch 2E). |

## Owner actions, in order

1. **Release keystore** (your machine, once; back it up offline, because losing it means no app updates):
   ```
   keytool -genkeypair -v -keystore C:\path\outside\repo\levlofit-release.jks -keyalg RSA -keysize 4096 -validity 10000 -alias levlofit
   ```
   Then copy app/android/key.properties.example to app/android/key.properties and fill in its four values.
2. **Store build** (after the production steps in RELEASE_CHECKLIST.md):
   ```
   flutter build appbundle --release --dart-define=LEVLOFIT_BACKEND=production
   ```
   Check the signature with `apksigner verify --print-certs` on the APK. It must not be the debug certificate.
3. **Git remote and CI** (GitHub account):
   - Create an empty **private** repository with no README, no licence and no .gitignore.
   - Tell Claude its URL. Claude will propose the commit batches for your approval, and you push.
   - Commands, once the commits are approved:
     ```
     git remote add origin <url>
     git push -u origin levlo/stage1-fixes
     ```
   - The workflow needs no repository secrets.
4. **Website host**: pick one (all have free tiers; check each provider's current terms):
   - **Cloudflare Pages**: static export. Needs `output: "export"` in next.config.ts, a one-line change Claude makes when you choose it. public/_headers already applies.
   - **Netlify**: static export as above. public/_headers applies.
   - **Vercel Hobby**: serves Next directly, and next.config.ts headers apply. Vercel's Hobby plan is for non-commercial use: check the terms against your plans.
   - In every case: connect the Git repository, then check headers on the live URL with `curl -I`.
5. **AI provider** (batch 2F additions: an optional fallback provider and one time budget per request):
   - Optional second provider for outages: `LLM_FALLBACK_PROVIDER`, `LLM_FALLBACK_API_KEY`, `LLM_FALLBACK_MODEL`, and optionally `LLM_FALLBACK_BASE_URL`. It is used only when it is also listed in `LLM_DATA_APPROVED` (comma-separated, for example `groq,openrouter`), and only after the privacy texts name it (REVIEW GATE in both policies).
   - `LLM_REQUEST_BUDGET_MS` (default 45000, allowed 5000 to 120000) caps every model call in one coach message, including regeneration and fallback.
   - Approval is by provider name while the provider's preset endpoint is used. If `LLM_BASE_URL` or `LLM_FALLBACK_BASE_URL` points to another host (or the provider has no preset), `LLM_DATA_APPROVED` must name `<provider>@<host>` instead, for example `openrouter@gateway.example.com` (batch 2H); otherwise that provider is refused. Set an override only to the provider's documented endpoint.
   - Reproducible live benchmark (synthetic personas, never real users): `node supabase/functions/_eval/run.ts --live --runs 3 --out benchmark-<provider>.json`. Compare providers on files with the same `casesFingerprint`.
   - Choose the provider and review its data terms.
   - Set these secrets on the project yourself: `LLM_API_KEY`, `LLM_PROVIDER` (if not Groq), `LLM_MODEL` (if not Groq), and `LLM_DATA_APPROVED=<provider>`.
   - This takes effect only after the coach-chat deploy (RELEASE_CHECKLIST 3.9, approval needed).
6. **Play Console**: create the developer account, then the app. Use the reviewed data-safety draft (docs/PLAY_DATA_SAFETY_DRAFT.md) and `<website>/delete-account` as the deletion URL.
