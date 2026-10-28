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

test('levels read fails: answers 500 and stores nothing (never plans from the self-rating instead)', async () => {
  useDb({ goal_levels: { data: null, error: { message: 'read failed' } } });
  assert.equal((await post()).status, 500);
  assert.equal(ops.filter((o) => o.op === 'insert' || o.op === 'update').length, 0);
});

test('goal without its catalogue row: answers 409 and stores nothing', async () => {
  useDb({ user_goals: { data: [{ goal: 'strength', experience: 'beginner', goal_catalog: null }] } });
  const res = await post();
  assert.equal(res.status, 409);
  assert.match((await res.json()).error, /no longer available/);
  assert.equal(ops.filter((o) => o.op === 'insert' || o.op === 'update').length, 0);
});

test('medical hold: a health flag with an assessed Level 3 trains at Level 1 at maintenance', async () => {
  useDb({
    profiles: {
      data: {
        display_name: 'Test User', birth_year: 1996, sex: 'male', height_cm: 175, weight_kg: 72, weight_goal: 'cut', body_type: null,
        waist_cm: null, days_per_week: 4, session_minutes: 45, daily_activity: 'light', sleep_hours: 7, health_flags: ['heart_condition'], injuries: null,
        equipment: 'gym', equipment_items: [],
      },
    },
    goal_levels: { data: [{ goal: 'strength', level: 3 }] },
  });
  const res = await post();
  assert.equal(res.status, 201);
  const { plan } = await res.json();
  assert.equal(plan.medicalHold, true);
  assert.equal(plan.goals[0].startLevel, 1);
  assert.equal(plan.weightGoal, 'maintain');
});

test('Build my plate conditions from the account reach the engine: kidney disease removes creatine', async () => {
  useDb({ dietary_profiles: { data: { diet_type: 'vegetarian', restrictions: [], other_restrictions: [], supplements: ['creatine'], health_conditions: ['kidney'] } } });
  const res = await post();
  assert.equal(res.status, 201);
  assert.deepEqual(savedInput().conditions, ['kidney']);
  const { plan } = await res.json();
  assert.ok(!plan.nutrition.supplements.some((s: { name: string }) => s.name.startsWith('Creatine')));
});

test('training weekdays and time from the profile reach the plan', async () => {
  useDb({
    profiles: {
      data: {
        display_name: 'Test User', birth_year: 1996, sex: 'male', height_cm: 175, weight_kg: 72, weight_goal: 'recomp', body_type: null,
        waist_cm: null, days_per_week: 4, session_minutes: 45, daily_activity: 'light', sleep_hours: 7, health_flags: [], injuries: null,
        equipment: 'gym', equipment_items: [], training_days: [2, 4], training_time: 'night',
      },
    },
  });
  const res = await post();
  assert.equal(res.status, 201);
  assert.deepEqual(savedInput().trainingDays, [2, 4]);
  const { plan } = await res.json();
  assert.deepEqual(plan.schedule, { preferredDays: [2, 4], trainingTime: 'night' });
  assert.ok(plan.trainingDaysPerWeek <= 2);
});

test('3.5: the stored plan carries the energy working behind the target', async () => {
  useDb();
  assert.equal((await post()).status, 201);
  const stored = ops.find((o) => o.table === 'generated_plans' && o.op === 'insert')?.args.plan;
  assert.equal(stored.engineVersion, '3.5.0');
  assert.equal(typeof stored.nutrition.energy.maintenanceKcal, 'number');
  assert.equal(stored.nutrition.energy.activity.from, 'training_days');
});
