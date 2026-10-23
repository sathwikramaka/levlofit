-- Read-only schema/data fingerprint of the public schema (one SELECT). Compare cloud vs local after any reconciliation step.
-- Local:  supabase db query --local -f tools/schema_state.sql     Cloud (owner-authorised): supabase db query --project-ref <ref> -f tools/schema_state.sql
-- Prints per-kind counts and hashes; data rows are hashed, never printed.
with items as (
  select 'column' k, table_name||'.'||column_name n, md5(concat_ws('|',data_type,is_nullable,column_default,character_maximum_length)) d
    from information_schema.columns where table_schema='public'
  union all select 'policy', tablename||'.'||policyname, md5(concat_ws('|',cmd,roles::text,qual,with_check)) from pg_policies where schemaname='public'
  union all select 'function', p.proname||'('||pg_get_function_identity_arguments(p.oid)||')', md5(pg_get_functiondef(p.oid)) from pg_proc p join pg_namespace s on s.oid=p.pronamespace where s.nspname='public'
  union all select 'index', indexname, md5(indexdef) from pg_indexes where schemaname='public'
  union all select 'trigger', event_object_table||'.'||trigger_name, md5(action_statement||action_timing||event_manipulation) from information_schema.triggers where trigger_schema='public'
  union all select 'constraint', conrelid::regclass::text||'.'||conname, md5(pg_get_constraintdef(oid)) from pg_constraint where connamespace='public'::regnamespace
  union all select 'grant', table_name||'.'||grantee||'.'||privilege_type, '' from information_schema.role_table_grants where table_schema='public' and grantee in ('anon','authenticated')
  union all select 'colgrant', table_name||'.'||column_name||'.'||grantee||'.'||privilege_type, '' from information_schema.column_privileges where table_schema='public' and grantee in ('anon','authenticated')
  -- Effective EXECUTE (incl. via PUBLIC) and public-schema default privileges: a restore can change both silently.
  union all select 'fngrant', p.proname||'('||pg_get_function_identity_arguments(p.oid)||').'||r, '' from pg_proc p join pg_namespace s on s.oid=p.pronamespace cross join unnest(array['anon','authenticated']) r where s.nspname='public' and has_function_privilege(r, p.oid, 'EXECUTE')
  union all select 'seqgrant', c.relname||'.'||r||'.'||pr, '' from pg_class c cross join unnest(array['anon','authenticated']) r cross join unnest(array['SELECT','USAGE','UPDATE']) pr where c.relnamespace='public'::regnamespace and c.relkind='S' and has_sequence_privilege(r, c.oid, pr)
  union all select 'defacl', pg_get_userbyid(defaclrole)||'.'||defaclobjtype::text, md5(array(select unnest(defaclacl)::text order by 1)::text) from pg_default_acl where defaclnamespace='public'::regnamespace
  union all select 'data', 'foods', md5(string_agg(f::text, '' order by f::text)) from public.foods f
  union all select 'data', 'goal_catalog', md5(string_agg(g::text, '' order by g::text)) from public.goal_catalog g
  union all select 'data', 'curriculum_levels', md5(string_agg(c::text, '' order by c::text)) from public.curriculum_levels c
  union all select 'data', 'exercises', md5(string_agg(e::text, '' order by e::text)) from public.exercises e
  union all select 'data', 'handbook_chapters', md5(string_agg(h::text, '' order by h::text)) from public.handbook_chapters h
)

, l as (select k, k||'|'||n||'|'||left(coalesce(d,''),8) line from items)
select k, count(*) as n, left(md5(string_agg(line, E'\n' order by line collate "C")),12) as h from l group by k order by k;
