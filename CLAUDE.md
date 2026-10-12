# Levlofit project rules

## Database and Supabase safety (overrides any skill guidance)

- Database writes, production migrations, destructive database operations (DELETE, DROP, TRUNCATE, data rewrites) and any change to the live Supabase project (schema, data, policies, auth settings, secrets, Edge Function deploys) require the owner's explicit approval in chat first. Approval covers one action only.
- Read-only inspection of the live project (advisors, logs, listing tables) also needs approval before the first use in a session.
- Prefer a local database (`supabase start`, `supabase db reset`, `supabase test db`) for testing. Make schema changes only through reviewed migration files in `supabase/migrations/`.
- The project-local `supabase` skill suggests iterating with `execute_sql` / `supabase db query`. Here that applies to a local database only, never to the cloud project.
- Do not add plugins or remote MCP servers for Supabase without approval.
