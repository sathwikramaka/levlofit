# Levlofit project rules

## Android releases

- Any app change that users should get ships with `tools/release_android.sh` (Git Bash, repo root): it bumps the version past the live `/version.json`, builds the signed APK, deploys the site, checks it, then sets the `MIN_APP_BUILD` secret so every older version is told to update (`MIN_BUILD=<n>` to keep older builds allowed). Deploying is outward-facing, so ask the owner before running it. Then commit the bump and add a dated section to `docs/release/RELEASE_RECORD.md`.

## Keeping these documents current

`docs/product/` holds the six living documents: `PRD.md`, `TRD.md`, `APP_FLOW.md`, `UI_UX_DESIGN_BRIEF.md`, `BACKEND_SCHEMA.md`, `IMPLEMENTATION_PLAN.md`. In the same change as the work, update each one the change affects, and their "Last updated" line:

- Features or rules: PRD. Stack, limits, secrets, jobs, release: TRD. Screens or navigation: App Flow. Look or wording rules: Design Brief (and `DESIGN.md`). Tables, functions, Storage: Backend Schema. Anything finished, started or decided: Implementation Plan.
- Each release: the version on those lines. `tools/release_docs.test.mjs` fails if a migration, table or version is missing.
- The repository is public: no real user metrics, secrets or personal data in these files.

## Database and Supabase safety (overrides any skill guidance)

- Database writes, production migrations, destructive database operations (DELETE, DROP, TRUNCATE, data rewrites) and any change to the live Supabase project (schema, data, policies, auth settings, secrets, Edge Function deploys) require the owner's explicit approval in chat first. Approval covers one action only.
- Read-only inspection of the live project (advisors, logs, listing tables) also needs approval before the first use in a session.
- Prefer a local database (`supabase start`, `supabase db reset`, `supabase test db`) for testing. Make schema changes only through reviewed migration files in `supabase/migrations/`.
- The project-local `supabase` skill suggests iterating with `execute_sql` / `supabase db query`. Here that applies to a local database only, never to the cloud project.
- Do not add plugins or remote MCP servers for Supabase without approval.
