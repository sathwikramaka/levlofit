import { test } from 'node:test';
import assert from 'node:assert/strict';
import { checkLimits, LIMITS, rateRefusal } from './rate.ts';

const db = (reply: { data: unknown; error: { code?: string } | null }) => ({ rpc: async () => reply });
const quiet = () => {};

test('allowed and over-limit answers pass straight through', async () => {
  assert.equal(await checkLimits(db({ data: true, error: null }), [LIMITS.chatHour], quiet), 'ok');
  assert.equal(await checkLimits(db({ data: false, error: null }), [LIMITS.bodyCheckDay], quiet), 'limited');
});

test('every limit fails closed: a database error, a missing function, an unknown bucket or a network failure is unavailable', async () => {
  for (const code of ['22023', 'PGRST202', '08006']) {
    const lines: string[] = [];
    for (const l of Object.values(LIMITS)) assert.equal(await checkLimits(db({ data: null, error: { code } }), [l], (x) => lines.push(x)), 'unavailable', `${code} ${l.bucket}`);
    assert.equal(lines.length, Object.values(LIMITS).length);
    assert.ok(lines.every((x) => JSON.parse(x).code === code));
  }
  const thrown = { rpc: async () => { throw new TypeError('fetch failed'); } };
  assert.equal(await checkLimits(thrown, [LIMITS.chatHour], quiet), 'unavailable');
  assert.equal(await checkLimits(db({ data: null, error: null }), [LIMITS.chatHour], quiet), 'unavailable', 'no answer is not a yes');
});

test('the app-wide daily cap is logged as its own event for alerting', async () => {
  const lines: string[] = [];
  assert.equal(await checkLimits(db({ data: null, error: { code: 'P0001', message: 'ai_daily_cap' } as never }), [LIMITS.bodyCheckDay], (x) => lines.push(x)), 'unavailable');
  assert.equal(JSON.parse(lines[0]).event, 'ai_daily_cap_reached');
});

test('the first limit that is not ok stops the check; later limits are not counted', async () => {
  const calls: string[] = [];
  const seq = { rpc: async (_: string, a: Record<string, unknown>) => { calls.push(a.p_bucket as string); return { data: false, error: null }; } };
  assert.equal(await checkLimits(seq, [LIMITS.chatHour, LIMITS.chatDay], quiet), 'limited');
  assert.deepEqual(calls, ['coach_chat_hour']);
});

test('refusals: 429 with the caller message when limited, a generic 503 otherwise', async () => {
  const limited = rateRefusal('limited', 'Slow down.');
  assert.equal(limited.status, 429);
  assert.deepEqual(await limited.json(), { error: 'Slow down.' });
  const down = rateRefusal('unavailable', 'Slow down.');
  assert.equal(down.status, 503);
  assert.doesNotMatch(JSON.stringify(await down.json()), /PGRST|P0001|cap|database/i);
});

test('LIMITS match the buckets in check_rate (migration 20261027200000)', () => {
  assert.deepEqual(Object.values(LIMITS).map((l) => [l.bucket, l.limit]), [
    ['coach_chat_hour', 30], ['coach_chat_day', 150], ['generate_plan_day', 20], ['body_check_day', 3],
  ]);
});
