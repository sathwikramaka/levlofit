// Run: node --test tools/release_docs.test.mjs
// Release runbooks must list every migration that production still lacks, so a new migration cannot be forgotten
// at release. Pending = every file from 20261007400000_handbook_v3 on, except the ones MIGRATION_RECONCILIATION.md's
// history table marks "Applied" in the cloud (read-only inspection, 2026-10-13).
import { test } from 'node:test';
import assert from 'node:assert/strict';
import { readdirSync, readFileSync } from 'node:fs';

const root = new URL('../', import.meta.url);
const read = (p) => readFileSync(new URL(p, root), 'utf8');
const applied = new Set([...read('docs/MIGRATION_RECONCILIATION.md').matchAll(/^\| (\d{14}_[a-z0-9_]+) \|[^|]*\| Applied/gm)].map((m) => m[1]));
const pending = readdirSync(new URL('supabase/migrations/', root))
  .filter((f) => f.endsWith('.sql') && f >= '20261007400000')
  .map((f) => f.replace(/\.sql$/, ''))
  .filter((m) => !applied.has(m));

test('every pending migration is in the release checklist and the reconciliation runbook', () => {
  assert.ok(pending.length >= 12, `found ${pending.length} pending migrations`);
  const checklist = read('docs/RELEASE_CHECKLIST.md');
  const reconciliation = read('docs/MIGRATION_RECONCILIATION.md');
  for (const m of pending) {
    assert.ok(checklist.includes(m), `RELEASE_CHECKLIST.md does not list ${m}`);
    assert.ok(reconciliation.includes(m), `MIGRATION_RECONCILIATION.md does not list ${m}`);
  }
  const count = reconciliation.match(/## Pending production items \((\d+)\)/)?.[1];
  assert.equal(Number(count), pending.length, 'the "Pending production items" count matches the files');
});
