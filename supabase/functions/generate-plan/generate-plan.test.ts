// Run: node --test supabase/functions/generate-plan/generate-plan.test.ts
// Contract tests for the generate-plan Edge Function with a fake Supabase client. Synthetic data only.
import { test } from 'node:test';
import assert from 'node:assert/strict';
import { register } from 'node:module';
// @ts-ignore: plain JS test double
import { fakeClient } from '../_test/supabase-server-mock.mjs';

register('../_test/npm-loader.mjs', import.meta.url);

const UID = '00000000-0000-0000-0000-0000000000a1';
const ops: any[] = [];

function useDb(over: Record<string, unknown> = {}) {
  ops.length = 0;
  const tables = {
    profiles: {
      data: {
        display_name: 'Test User', birth_year: 1996, sex: 'male', height_cm: 175, weight_kg: 72, weight_goal: 'recomp', body_type: null,
        waist_cm: null, days_per_week: 3, session_minutes: 45, daily_activity: 'light', sleep_hours: 7, health_flags: [], injuries: null,
        equipment: 'gym', equipment_items: [],
      },
    },
    user_goals: { data: [{ goal: 'strength', experience: 'beginner', goal_catalog: { name: 'Strength', kind: 'strength', coach_led_from_level: null } }] },
    dietary_profiles: { data: { diet_type: 'vegetarian', restrictions: [], other_restrictions: [], supplements: null } },
    goal_levels: { data: [] },
    curriculum_levels: { data: [] },
    generated_plans: { data: null, nextId: 100 },
    ...over,
  };
  const client = fakeClient(tables, ops);
  (globalThis as any).__supabaseCtx = { userClaims: { id: UID }, supabase: client, supabaseAdmin: client };
}

const fn = (await import('./index.ts')).default.fetch as (req: Request) => Promise<Response>;
const post = () => fn(new Request('http://local/generate-plan', { method: 'POST' }));
const savedInput = () => ops.find((o) => o.table === 'generated_plans' && o.op === 'insert')?.args.input;

test('control: a complete profile builds and stores a plan, then opens the dashboard gate', async () => {
  useDb();
  const res = await post();
  assert.equal(res.status, 201);
  assert.ok(savedInput(), 'plan snapshot stored');
  assert.ok(ops.some((o) => o.table === 'profiles' && o.op === 'update'));
});

test('level lock: a stored level above 3 is trained as 3 (4 and 5 need a tested pass)', async () => {
  useDb({ goal_levels: { data: [{ goal: 'strength', level: 5 }] } });
  assert.equal((await post()).status, 201);
  assert.equal(savedInput().goals[0].currentLevel, 3);
});

test('level lock: levels 0 to 3 pass through unchanged', async () => {
  for (const level of [0, 2, 3]) {
    useDb({ goal_levels: { data: [{ goal: 'strength', level }] } });
    await post();
    assert.equal(savedInput().goals[0].currentLevel, level);
  }
});

test('rate limit: over the daily limit answers 429 and stores nothing', async () => {
  useDb({ 'rpc:check_rate': { data: false, error: null } });
  const res = await post();
  assert.equal(res.status, 429);
  assert.equal(ops.filter((o) => o.op === 'insert' || o.op === 'update').length, 0);
});

test('rate limit: before the migration (function missing) plans still build', async () => {
  useDb();
  assert.equal((await post()).status, 201);
  assert.ok(ops.some((o) => o.table === 'rpc:check_rate'));
});

test('onboarding not finished answers 409 and stores nothing', async () => {
  useDb({ dietary_profiles: { data: null } });
  assert.equal((await post()).status, 409);
  assert.equal(ops.filter((o) => o.op === 'insert').length, 0);
});

test('curriculum read fails: answers 500 and stores nothing (no plan saved without its level checks)', async () => {
  useDb({ curriculum_levels: { data: null, error: { message: 'read failed' } } });
  assert.equal((await post()).status, 500);
  assert.equal(ops.filter((o) => o.op === 'insert' || o.op === 'update').length, 0);
});
