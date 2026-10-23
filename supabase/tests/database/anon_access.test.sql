-- Signed-out (anon) requests hold no privilege on any per-user table (tables with a user_id column, and profiles);
-- RLS is on everywhere; account deletion cascades to every per-user table.
begin;
create extension if not exists pgtap with schema extensions;
select plan(4);

select is(
  (select coalesce(string_agg(distinct t.table_name || ':' || g.privilege_type, ', '), '')
     from information_schema.columns t
     join information_schema.role_table_grants g on g.table_schema = t.table_schema and g.table_name = t.table_name and g.grantee = 'anon'
    where t.table_schema = 'public' and (t.column_name = 'user_id' or t.table_name = 'profiles')),
  '', 'anon has no privileges on per-user tables');

select is(
  (select count(*)::int from pg_class c join pg_namespace n on n.oid = c.relnamespace
    where n.nspname = 'public' and c.relkind = 'r' and not c.relrowsecurity),
  0, 'every public table has row level security on');

select is(
  (select coalesce(string_agg(conrelid::regclass::text, ', '), '') from pg_constraint
    where confrelid = 'auth.users'::regclass and connamespace = 'public'::regnamespace and confdeltype <> 'c'),
  '', 'every reference to auth.users cascades, so deleting an account leaves no rows behind');

select is(
  (select coalesce(string_agg(c.relname || ':' || p.privilege_type, ', ' order by c.relname, p.privilege_type), '')
     from pg_class c join pg_namespace n on n.oid = c.relnamespace,
     lateral aclexplode(coalesce(c.relacl, acldefault('S', c.relowner))) p
    where n.nspname = 'public' and c.relkind = 'S' and p.grantee = 'anon'::regrole),
  '', 'anon has no privileges on any public sequence');

select * from finish();
rollback;
