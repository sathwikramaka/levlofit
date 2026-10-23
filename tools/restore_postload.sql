-- Isolated restore, last step (after data.sql and the deferred trigger). The dumps never contain supabase_admin's
-- default privileges, so put back the image's own values revoked by restore_preload.sql. Then run
-- tools/schema_state.sql here and compare with the source taken in the backup window: every kind must match,
-- including grant, colgrant, fngrant and defacl.
alter default privileges for role supabase_admin in schema public grant all on tables    to anon, authenticated;
alter default privileges for role supabase_admin in schema public grant all on sequences to anon, authenticated;
alter default privileges for role supabase_admin in schema public grant all on functions to anon, authenticated;
