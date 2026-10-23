# Usage: python -I -X utf8 tools/handbook_fingerprint_sql.py supabase/migrations/20261007400000_handbook_v3.sql | docker exec -i <local db container> psql -U postgres -tA
# Prints a read-only SQL query (begin transaction read only ... rollback) returning the runbook fingerprint the given
# migration would produce, without applying it. Verified 2026-10-24: reproduces af1ea000 for the commit 1803009 file.
"""Turn the handbook_v3 migration's INSERT into a read-only SELECT that computes the runbook fingerprint
left(md5(string_agg(h::text, '' order by h::text)), 8) over rows shaped exactly like public.handbook_chapters
(column order and types from information_schema; search = the table's generated-column expression)."""
import sys

sql = open(sys.argv[1], encoding="utf-8").read()
head = "insert into public.handbook_chapters (id, slug, part, part_title, title, summary, minutes, body_md, sources, blocks) values"
i = sql.index(head) + len(head)
j = sql.rindex(";")
values = sql[i:j]
print(f"""begin transaction read only;
select left(md5(string_agg(h::text, '' order by h::text)), 8) from (
  select id::smallint as id, part::text as part, title::text as title, body_md::text as body_md, sources::text[] as sources,
         (setweight(to_tsvector('english'::regconfig, title::text), 'A'::"char") || setweight(to_tsvector('english'::regconfig, body_md::text), 'B'::"char")) as search,
         slug::text as slug, part_title::text as part_title, summary::text as summary, minutes::smallint as minutes, blocks::jsonb as blocks
  from (values {values}) v(id, slug, part, part_title, title, summary, minutes, body_md, sources, blocks)
) h;
rollback;""")
