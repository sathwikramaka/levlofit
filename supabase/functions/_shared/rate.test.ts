import { test } from 'node:test';
import assert from 'node:assert/strict';
import { checkLimits, LIMITS } from './rate.ts';

const db = (reply: { data: unknown; error: { code?: string } | null }) => ({ rpc: async () => reply });
const quiet = () => {};

test('allowed and over-limit answers pass straight through', async () => {
  assert.equal(await checkLimits(db({ data: true, error: null }), [LIMITS.chatHour], quiet), 'ok');
  assert.equal(await checkLimits(db({ data: false, error: null }), [LIMITS.bodyCheckDay], quiet), 'limited');
});

test('chat and plan limits fail open on a database error; the body check fails closed (unknown bucket, missing function)', async () => {
  for (const code of ['22023', 'PGRST202']) {
    const lines: string[] = [];
    assert.equal(await checkLimits(db({ data: null, error: { code } }), [LIMITS.chatHour, LIMITS.planDay], (l) => lines.push(l)), 'ok', code);
    assert.equal(await checkLimits(db({ data: null, error: { code } }), [LIMITS.bodyCheckDay], (l) => lines.push(l)), 'limited', code);
    assert.equal(lines.length, 3);
    assert.match(lines[2], /"bucket":"body_check_day".*"failClosed":true/);
  }
});

test('LIMITS match the buckets in check_rate (migration 20261027200000)', () => {
  assert.deepEqual(Object.values(LIMITS).map((l) => [l.bucket, l.limit]), [
    ['coach_chat_hour', 30], ['coach_chat_day', 150], ['generate_plan_day', 20], ['body_check_day', 3],
  ]);
});
