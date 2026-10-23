// Run: node --test supabase/functions/_shared/plan-engine.test.ts
// Guards every cited bound. A failure here means a plan would ship outside the science.
import { test } from 'node:test';
import assert from 'node:assert/strict';
import { bmiCategory, buildRoadmap, DIETS, EXPERIENCE, type Experience, generatePlan, type GoalInput, validateInput, WEIGHT_GOALS, type PlanInput } from './plan-engine.ts';

// Fixture mirroring goal_catalog rows: every session kind, plus coach-led combat.
const CATALOG: Omit<GoalInput, 'experience'>[] = [
  { goal: 'strength', name: 'Strength', kind: 'strength', coachLedFromLevel: null },
  { goal: 'bodybuilding', name: 'Muscle building', kind: 'strength', coachLedFromLevel: null },
  { goal: 'running', name: 'Running', kind: 'endurance', coachLedFromLevel: null },
  { goal: 'swimming', name: 'Swimming', kind: 'endurance', coachLedFromLevel: null },
  { goal: 'hyrox', name: 'HYROX', kind: 'hybrid', coachLedFromLevel: null },
  { goal: 'boxing', name: 'Boxing', kind: 'skill', coachLedFromLevel: 4 },
  { goal: 'cricket', name: 'Cricket', kind: 'skill', coachLedFromLevel: null },
  { goal: 'kabaddi', name: 'Kabaddi', kind: 'skill', coachLedFromLevel: null },
  { goal: 'yoga', name: 'Yoga', kind: 'mobility', coachLedFromLevel: null },
  { goal: 'mobility', name: 'Mobility', kind: 'mobility', coachLedFromLevel: null },
];
const g = (id: string, experience: Experience = 'beginner'): GoalInput => ({ ...CATALOG.find((c) => c.goal === id)!, experience });

const base: PlanInput = {
  ageYears: 28,
  sex: 'male',
  heightCm: 175,
  weightKg: 72,
  weightGoal: 'maintain',
  goals: [g('strength')],
  diet: 'vegetarian',
  restrictions: [],
  otherRestrictions: [],
};

test('validateInput rejects out-of-range and malformed input', () => {
  assert.throws(() => validateInput(null));
  assert.throws(() => validateInput({ ...base, ageYears: 17 }));
  assert.throws(() => validateInput({ ...base, heightCm: 300 }));
  assert.throws(() => validateInput({ ...base, weightKg: Number.NaN }));
  assert.throws(() => validateInput({ ...base, goals: [] }));
  assert.throws(() => validateInput({ ...base, goals: CATALOG.slice(0, 7).map((c) => g(c.goal)) }));
  assert.doesNotThrow(() => validateInput({ ...base, goals: CATALOG.slice(0, 6).map((c) => g(c.goal)) }));
  assert.throws(() => validateInput({ ...base, goals: [base.goals[0], base.goals[0]] }));
  assert.throws(() => validateInput({ ...base, goals: [{ ...g('strength'), goal: 'Bad Id!' }] }));
  assert.throws(() => validateInput({ ...base, goals: [{ ...g('strength'), kind: 'magic' }] }));
  assert.throws(() => validateInput({ ...base, goals: [{ ...g('boxing'), coachLedFromLevel: 9 }] }));
  assert.throws(() => validateInput({ ...base, diet: 'beef' }));
  assert.throws(() => validateInput({ ...base, restrictions: ['pollen'] }));
  assert.deepEqual(validateInput(base), base);
});

test('free-text allergies: validated, normalised, deduped, carried into the plan', () => {
  assert.throws(() => validateInput({ ...base, otherRestrictions: ['x'] }));
  assert.throws(() => validateInput({ ...base, otherRestrictions: Array(11).fill('sesame') }));
  assert.throws(() => validateInput({ ...base, otherRestrictions: [42] }));
  const input = validateInput({ ...base, otherRestrictions: [' Sesame ', 'sesame', 'Mustard'] });
  assert.deepEqual(input.otherRestrictions, ['sesame', 'mustard']);
  assert.deepEqual(generatePlan(input).nutrition.customExclusions, ['sesame', 'mustard']);
});

test('self-reported experience never starts above level 3; coach rule and name carried through', () => {
  for (const experience of EXPERIENCE) {
    const plan = generatePlan({ ...base, goals: [g('strength', experience)] });
    assert.ok(plan.goals[0].startLevel <= 3);
  }
  const boxing = generatePlan({ ...base, goals: [g('boxing', 'advanced')] });
  assert.equal(boxing.goals[0].coachLedFromLevel, 4);
  assert.equal(boxing.goals[0].name, 'Boxing');
});

test('protein stays inside ISSN 1.4-2.0 g/kg and energy never drops below BMR', () => {
  for (const weightGoal of WEIGHT_GOALS) {
    for (const sex of ['male', 'female'] as const) {
      const plan = generatePlan({ ...base, weightGoal, sex, weightKg: 45, heightCm: 150, ageYears: 70 });
      assert.ok(plan.nutrition.proteinPerKg >= 1.4 && plan.nutrition.proteinPerKg <= 2.0);
      assert.ok(plan.nutrition.energyKcal >= plan.nutrition.bmrKcal - 5); // rounding to 10 kcal
    }
  }
});

test('soya chunks capped at 50 g dry, zero with a soy restriction', () => {
  assert.equal(generatePlan(base).nutrition.maxSoyaChunksDryG, 50);
  assert.equal(generatePlan({ ...base, restrictions: ['soy'] }).nutrition.maxSoyaChunksDryG, 0);
});

test('beef and pork are excluded for every diet', () => {
  for (const diet of DIETS) {
    const tags = generatePlan({ ...base, diet }).nutrition.excludedFoodTags;
    assert.ok(tags.includes('beef') && tags.includes('pork'), diet);
  }
});

test('vegan excludes all animal products, restrictions add their tags', () => {
  const tags = generatePlan({ ...base, diet: 'vegan', restrictions: ['gluten'] }).nutrition.excludedFoodTags;
  for (const t of ['meat', 'poultry', 'fish', 'shellfish', 'egg', 'dairy', 'honey', 'wheat', 'barley', 'rye']) {
    assert.ok(tags.includes(t), t);
  }
  assert.ok(generatePlan({ ...base, diet: 'eggitarian' }).nutrition.excludedFoodTags.includes('egg') === false);
});

test('every combination of 1 to 6 goals x every days-per-week: fits the days, every goal scheduled, WHO strength', () => {
  const combos: string[][] = [];
  const pick = (start: number, acc: string[]) => {
    if (acc.length) combos.push(acc);
    if (acc.length === 6) return;
    for (let i = start; i < CATALOG.length; i++) pick(i + 1, [...acc, CATALOG[i].goal]);
  };
  pick(0, []);

  for (const ids of combos) {
    for (const experience of ['none', 'advanced'] as const) {
      for (const daysPerWeek of [undefined, 1, 2, 3, 4, 5, 6, 7]) {
        const plan = generatePlan({ ...base, goals: ids.map((id) => g(id, experience)), ...(daysPerWeek ? { daysPerWeek } : {}) });
        const label = `${ids.join('+')} days=${daysPerWeek}`;
        const cap = Math.min(6, daysPerWeek ?? 6);
        assert.ok(plan.trainingDaysPerWeek <= cap, label);
        // Active goals are scheduled; queued goals wait with a reason and take no training time.
        assert.ok(plan.goals.filter((p) => p.status === 'active').every((p) => p.sessionsPerWeek >= 1 || p.addOnBlocksPerWeek >= 1), label);
        assert.ok(plan.goals.filter((p) => p.status === 'queued').every((p) => p.sessionsPerWeek === 0 && p.addOnBlocksPerWeek === 0 && p.unlockWhen), label);
        assert.ok(plan.goals.filter((p) => p.status === 'active').length <= 3, label);
        if (experience === 'none') assert.equal(plan.goals.filter((p) => p.status === 'active').length, 1, label);
        assert.ok(plan.goals[0].sessionsPerWeek >= Math.min(2, cap), label);
        const strength = plan.goals.filter((p) => p.kind === 'strength').reduce((s, p) => s + p.sessionsPerWeek, 0);
        assert.ok(strength + plan.extraStrengthSessions + plan.strengthAddOns >= 2, label);
      }
    }
  }
});

test('Indian BMI cut-offs (Misra 2009)', () => {
  assert.equal(bmiCategory(17.9), 'underweight');
  assert.equal(bmiCategory(18.0), 'normal');
  assert.equal(bmiCategory(22.9), 'normal');
  assert.equal(bmiCategory(23.0), 'overweight');
  assert.equal(bmiCategory(24.9), 'overweight');
  assert.equal(bmiCategory(25.0), 'obese');
  assert.equal(generatePlan(base).bmi.value, 23.5);
});

// ---- 2.0 coach review: the engine analyses the answers before planning ----
const finding = (plan: ReturnType<typeof generatePlan>, id: string) => plan.review.find((f) => f.id === id);

test('review: underweight user asking to cut is moved to maintenance, with a reason and source', () => {
  const plan = generatePlan({ ...base, weightKg: 50, heightCm: 175, weightGoal: 'cut' }); // BMI 16.3
  assert.equal(plan.chosenWeightGoal, 'cut');
  assert.equal(plan.weightGoal, 'maintain');
  const f = finding(plan, 'cut_underweight')!;
  assert.equal(f.level, 'change');
  assert.ok(f.why.length > 20 && f.source.includes('Misra'));
  assert.ok(plan.nutrition.energyKcal >= plan.nutrition.bmrKcal); // no deficit applied
});

test('review: high body fat and bulking becomes recomp for novices, cut for trained lifters', () => {
  const heavy = { ...base, weightKg: 95, heightCm: 170, weightGoal: 'bulk' as const }; // BMI 32.9
  assert.equal(generatePlan({ ...heavy, goals: [g('strength', 'none')] }).weightGoal, 'recomp');
  assert.equal(generatePlan({ ...heavy, goals: [g('strength', 'advanced')] }).weightGoal, 'cut');
  // waist alone can trigger it too
  assert.equal(generatePlan({ ...base, weightGoal: 'bulk', waistCm: 110, goals: [g('strength', 'none')] }).weightGoal, 'recomp');
});

test('review: slim-but-soft novice bulking becomes recomp; lean user cutting gets advice only', () => {
  assert.equal(generatePlan({ ...base, weightGoal: 'bulk', bodyType: 'slim_soft', goals: [g('strength', 'beginner')] }).weightGoal, 'recomp');
  const lean = generatePlan({ ...base, weightKg: 62, weightGoal: 'cut', bodyType: 'lean' }); // BMI 20.2
  assert.equal(lean.weightGoal, 'cut');
  assert.equal(finding(lean, 'cut_lean')?.level, 'advice');
});

test('review: health screen flags stop hard training advice and block supplement suggestions', () => {
  const plan = generatePlan({ ...base, healthFlags: ['chest_pain'], supplements: ['creatine', 'protein_powder'] });
  assert.equal(finding(plan, 'medical_clearance')?.level, 'stop');
  assert.ok(!plan.nutrition.supplements.some((s) => s.name.startsWith('Creatine')));
  assert.ok(plan.nutrition.supplements.some((s) => s.name === 'Ask your doctor first'));
  const pregnant = generatePlan({ ...base, sex: 'female', weightGoal: 'cut', healthFlags: ['pregnancy'] });
  assert.equal(pregnant.weightGoal, 'maintain');
});

test('review: too many goals, few days, short sleep and injuries are explained', () => {
  const plan = generatePlan({
    ...base,
    goals: ['strength', 'running', 'hyrox', 'yoga'].map((id) => g(id)),
    daysPerWeek: 2,
    sleepHours: 5.5,
    injuries: 'left knee pain on stairs',
  });
  for (const id of ['too_many_goals', 'few_days', 'short_sleep', 'injuries']) assert.ok(finding(plan, id), id);
  assert.ok(plan.trainingDaysPerWeek <= 2);
  assert.equal(plan.snapshot.sleep, 'short');
});

test('review: a week shorter than the days offered says why (beginner strength: 3 of 4)', () => {
  const plan = generatePlan({ ...base, goals: [g('strength'), g('mobility')], daysPerWeek: 4 });
  assert.equal(plan.trainingDaysPerWeek, 3);
  const f = finding(plan, 'days_fewer');
  assert.ok(f, 'days_fewer');
  assert.equal(f.title, '3 of your 4 days');
  assert.match(f.why, /Strength at Level 1 gets 3 a week/);
  assert.equal(f.level, 'info');
  // Using every offered day, or no day count given, says nothing.
  assert.equal(finding(generatePlan({ ...base, daysPerWeek: 3 }), 'days_fewer'), undefined);
  assert.equal(finding(generatePlan({ ...base }), 'days_fewer'), undefined);
});

test('supplements: creatine only when willing and training strength; protein powder type follows the diet', () => {
  assert.ok(generatePlan({ ...base, supplements: ['creatine'] }).nutrition.supplements[0].how.startsWith('3'));
  assert.equal(generatePlan({ ...base, goals: [g('yoga')], supplements: ['creatine'] }).nutrition.supplements.length, 0);
  assert.equal(generatePlan({ ...base }).nutrition.supplements.length, 0);
  const vegan = generatePlan({ ...base, diet: 'vegan', restrictions: ['soy'], supplements: ['protein_powder'] });
  assert.ok(vegan.nutrition.supplements[0].how.includes('pea protein') && !vegan.nutrition.supplements[0].how.includes('soy'));
  assert.ok(generatePlan({ ...base, supplements: ['protein_powder'] }).nutrition.supplements[0].how.includes('whey'));
});

test('snapshot: strengths, gaps and waist-to-height are reported', () => {
  const plan = generatePlan({ ...base, waistCm: 90, goals: [g('strength', 'advanced'), g('running', 'none')] });
  assert.deepEqual(plan.snapshot.strengths, ['Strength']);
  assert.deepEqual(plan.snapshot.gaps, ['Running']);
  assert.equal(plan.snapshot.waistToHeight?.category, 'increased'); // 90/175 = 0.51
});

test('validateInput: 2.0 fields validated and round-tripped', () => {
  const full = { ...base, bodyType: 'average', waistCm: 82, daysPerWeek: 4, sessionMinutes: 45, dailyActivity: 'light', sleepHours: 7.5, healthFlags: [], equipment: 'custom', equipmentItems: ['pull-up bar'], supplements: ['creatine'] } as const;
  assert.deepEqual(validateInput(full), full);
  assert.throws(() => validateInput({ ...base, weightGoal: 'lose' }));
  assert.throws(() => validateInput({ ...base, daysPerWeek: 9 }));
  assert.throws(() => validateInput({ ...base, healthFlags: ['flu'] }));
  assert.throws(() => validateInput({ ...base, supplements: ['steroids'] }));
});

test('3.0 level first: no basics means a foundation phase with only the main goal', () => {
  const plan = generatePlan({ ...base, goals: ['strength', 'running', 'yoga'].map((id) => g(id, 'none')), daysPerWeek: 5 });
  assert.equal(plan.phase.id, 'foundation');
  assert.deepEqual(plan.goals.map((p) => p.status), ['active', 'queued', 'queued']);
  assert.equal(plan.goals[1].unlockWhen, 'Strength reaches Level 2');
  assert.equal(plan.goals[2].unlockWhen, 'Strength reaches Level 3');
  assert.ok(plan.review.some((f) => f.id === 'goals_queued' && f.level === 'change'));
  assert.equal(plan.trainingDaysPerWeek, plan.goals[0].sessionsPerWeek + plan.extraStrengthSessions);
});

test('3.0 extras unlock one at a time as the main goal levels up; the assessed level wins', () => {
  const goals = (lvl: number) => ['running', 'strength', 'yoga', 'mobility'].map((id, i) => ({ ...g(id, 'none'), ...(i === 0 ? { currentLevel: lvl } : {}) }));
  const active = (lvl: number) => generatePlan({ ...base, goals: goals(lvl) }).goals.filter((p) => p.status === 'active').length;
  assert.equal(active(1), 1);
  assert.equal(active(2), 2);
  assert.equal(active(3), 3);
  assert.equal(active(5), 3); // never more than one main goal plus two
  const plan = generatePlan({ ...base, goals: goals(4) });
  assert.equal(plan.phase.id, 'build');
  assert.equal(plan.goals[0].startLevel, 4);
  assert.match(plan.goals[3].unlockWhen!, /finish or drop/);
  assert.throws(() => validateInput({ ...base, goals: [{ ...g('strength'), currentLevel: 6 }] }), /bad level/);
  assert.equal(validateInput({ ...base, goals: [{ ...g('strength'), currentLevel: 2 }] }).goals[0].currentLevel, 2);
});

test('coach roadmap: assess first, main goal level by level, then waiting goals; no model involved', () => {
  const plan = generatePlan({ ...base, goals: ['strength', 'running'].map((id) => g(id, 'none')) });
  const rows = [0, 1, 2].map((level) => ({ goal: 'strength', level, title: `S${level}`, practice: [`practise ${level}`], advance_when: `pass ${level}` }));
  const fresh = buildRoadmap(plan, rows, new Set());
  assert.deepEqual(fresh.steps.map((s) => s.title), ['Check your real level', 'Strength, Level 0: S0', 'Strength, Level 1: S1', 'Add Running']);
  assert.equal(fresh.steps[1].moveOnWhen, 'pass 0');
  assert.match(fresh.steps[3].moveOnWhen, /Strength reaches Level 2/);
  const checked = buildRoadmap(plan, rows, new Set(['strength']));
  assert.equal(checked.steps[0].title, 'Strength, Level 0: S0');
});
