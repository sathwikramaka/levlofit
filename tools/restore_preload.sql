-- Isolated restore, step 1 of docs/BACKUP_RECOVERY_PLAN.md section 5 (run as supabase_admin before any dump file).
-- Isolated container only: on a hosted project the postgres role cannot alter supabase_admin's defaults; there run
-- just the three "for role postgres" lines (section 5 explains).
-- Supabase databases grant anon and authenticated every privilege on new public objects through default privileges.
-- pg_dump emits only the grants the source had and never a REVOKE for the rest, so without this every restored
-- table, sequence and function would also be granted to anon and authenticated (drill BS: 324 extra privileges).
-- schema.sql re-creates the postgres defaults at its end; restore_postload.sql puts back the supabase_admin ones.
alter default privileges for role postgres       in schema public revoke all on tables    from anon, authenticated;
alter default privileges for role postgres       in schema public revoke all on sequences from anon, authenticated;
alter default privileges for role postgres       in schema public revoke all on functions from anon, authenticated;
alter default privileges for role supabase_admin in schema public revoke all on tables    from anon, authenticated;
alter default privileges for role supabase_admin in schema public revoke all on sequences from anon, authenticated;
alter default privileges for role supabase_admin in schema public revoke all on functions from anon, authenticated;
