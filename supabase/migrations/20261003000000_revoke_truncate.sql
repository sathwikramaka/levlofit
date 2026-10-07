-- Defence in depth: TRUNCATE ignores row-level security. PostgREST cannot issue it, but no API role should hold it.
revoke truncate, references, trigger on all tables in schema public from anon, authenticated;
alter default privileges in schema public revoke truncate, references, trigger on tables from anon, authenticated;
