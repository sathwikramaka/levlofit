// Run: node --test tools/release_docs.test.mjs
// Release runbooks must list every migration that production still lacks, so a new migration cannot be forgotten
// at release. Pending = every file from 20261007400000_handbook_v3 on, except the ones MIGRATION_RECONCILIATION.md's
// history table marks "Applied" in the cloud (read-only inspections 2026-10-13 and 2026-10-29).
import { test } from 'node:test';
import assert from 'node:assert/strict';
import { readdirSync, readFileSync } from 'node:fs';

const root = new URL('../', import.meta.url);
const read = (p) => readFileSync(new URL(p, root), 'utf8');
const applied = new Set([...read('docs/release/MIGRATION_RECONCILIATION.md').matchAll(/^\| (\d{14}_[a-z0-9_]+) \|[^|]*\| Applied/gm)].map((m) => m[1]));
const pending = readdirSync(new URL('supabase/migrations/', root))
  .filter((f) => f.endsWith('.sql') && f >= '20261007400000')
  .map((f) => f.replace(/\.sql$/, ''))
  .filter((m) => !applied.has(m));

test('every pending migration is in the release checklist and the reconciliation runbook', () => {
  const checklist = read('docs/release/RELEASE_CHECKLIST.md');
  const reconciliation = read('docs/release/MIGRATION_RECONCILIATION.md');
  for (const m of pending) {
    assert.ok(checklist.includes(m), `RELEASE_CHECKLIST.md does not list ${m}`);
    assert.ok(reconciliation.includes(m), `MIGRATION_RECONCILIATION.md does not list ${m}`);
  }
  const count = reconciliation.match(/## Pending production items \((\d+)\)/)?.[1];
  assert.equal(Number(count), pending.length, 'the "Pending production items" count matches the files');
});

test('living documents: the schema names the latest migration and every table; the others name the current version', () => {
  const files = readdirSync(new URL('supabase/migrations/', root)).filter((f) => f.endsWith('.sql')).sort();
  const schema = read('docs/product/BACKEND_SCHEMA.md');
  assert.ok(schema.includes(files.at(-1).replace(/\.sql$/, '')), `BACKEND_SCHEMA.md does not name the latest migration ${files.at(-1)}`);
  const all = files.map((f) => read(`supabase/migrations/${f}`)).join('\n');
  const dropped = new Set([...all.matchAll(/drop table (?:if exists )?public\.(\w+)/g)].map((m) => m[1]));
  for (const [, table] of all.matchAll(/create table (?:if not exists )?public\.(\w+)/g)) {
    if (!dropped.has(table)) assert.ok(schema.includes(`\`${table}\``), `BACKEND_SCHEMA.md does not list table ${table}`);
  }
  const version = read('app/pubspec.yaml').match(/^version: *([\d.]+)\+/m)[1];
  for (const doc of ['PRD', 'TRD', 'APP_FLOW', 'UI_UX_DESIGN_BRIEF', 'IMPLEMENTATION_PLAN']) {
    assert.ok(read(`docs/product/${doc}.md`).includes(`release ${version}`), `${doc}.md is not updated for release ${version}`);
  }
});

