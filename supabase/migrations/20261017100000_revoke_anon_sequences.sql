-- Defence in depth (low finding from the 2026-10-16 security review): the anon role (signed-out requests) held USAGE,
-- SELECT and UPDATE on the four public sequences. Each backs an identity column of a per-user table
-- (coach_messages, water_intake, set_logs, app_feedback); identity columns do not need sequence privileges to insert,
-- and anon has no access to those tables. Nothing signed-out uses a sequence, so anon keeps none, now or later.
-- The default privilege changed here is the migrating role's (postgres). The platform role supabase_admin keeps its own
-- default that grants anon on sequences it creates; postgres cannot change that on a hosted project, so the pgTAP test
-- anon_access (assertion 4) checks every public sequence instead. Verified 2026-10-17 on a fresh local database.
revoke all on all sequences in schema public from anon;
alter default privileges in schema public revoke all on sequences from anon;
