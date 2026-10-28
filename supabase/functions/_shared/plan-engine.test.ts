// Run: node --test supabase/functions/_shared/plan-engine.test.ts
// Guards every cited bound. A failure here means a plan would ship outside the science.
import { test } from 'node:test';
import assert from 'node:assert/strict';
import { bmiCategory, CUT_FLOOR_KCAL, MEDICAL_MAX_LEVEL, buildRoadmap, DIETS, EXPERIENCE, type Experience, generatePlan, type GoalInput, validateInput, WEIGHT_GOALS, type PlanInput } from './plan-engine.ts';

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

test('WHO adult BMI bands, as the app calculator shows them', () => {
  assert.equal(bmiCategory(18.4), 'underweight');
  assert.equal(bmiCategory(18.5), 'normal');
  assert.equal(bmiCategory(24.9), 'normal');
  assert.equal(bmiCategory(25.0), 'overweight');
  assert.equal(bmiCategory(29.9), 'overweight');
  assert.equal(bmiCategory(30.0), 'obese');
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
  assert.ok(f.why.length > 20 && f.source.includes('WHO'));
  assert.ok(plan.nutrition.energyKcal >= plan.nutrition.bmrKcal); // no deficit applied
});

test('review: high body fat and bulking becomes recomp for novices, cut for trained lifters', () => {
  const heavy = { ...base, weightKg: 95, heightCm: 170, weightGoal: 'bulk' as const }; // BMI 32.9
  assert.equal(generatePlan({ ...heavy, goals: [g('strength', 'none')] }).weightGoal, 'recomp');
  assert.equal(generatePlan({ ...heavy, goals: [g('strength', 'advanced')] }).weightGoal, 'cut');
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

test('3.2 medical hold: a flag with self-rated advanced and no level check trains at Level 1 or below, no deficit', () => {
  const plan = generatePlan({
    ...base, weightGoal: 'cut', daysPerWeek: 5, healthFlags: ['heart_condition'],
    goals: [g('strength', 'advanced'), g('running', 'advanced'), g('yoga', 'intermediate')],
  });
  assert.equal(plan.medicalHold, true);
  assert.ok(plan.goals.every((x) => x.startLevel <= MEDICAL_MAX_LEVEL), JSON.stringify(plan.goals.map((x) => x.startLevel)));
  assert.equal(plan.phase.id, 'foundation');
  assert.ok(plan.goals.slice(1).every((x) => x.status === 'queued'));
  assert.equal(plan.weightGoal, 'maintain');
  assert.equal(plan.chosenWeightGoal, 'cut');
  assert.equal(finding(plan, 'medical_clearance')?.level, 'stop');
  assert.equal(finding(plan, 'medical_hold')?.level, 'change');
  // Energy at maintenance: the same as the identical unflagged plan asked to maintain at Level 1.
  const maint = generatePlan({ ...base, weightGoal: 'maintain', daysPerWeek: 5, goals: [g('strength', 'beginner'), g('running', 'advanced'), g('yoga', 'intermediate')] });
  assert.equal(plan.nutrition.energyKcal, maint.nutrition.energyKcal);
  // An assessed level is capped too, and a bulk also becomes maintenance.
  const assessed = generatePlan({ ...base, weightGoal: 'bulk', healthFlags: ['dizziness'], goals: [{ ...g('strength', 'advanced'), currentLevel: 3 }] });
  assert.equal(assessed.goals[0].startLevel, 1);
  assert.equal(assessed.weightGoal, 'maintain');
  // Level 0 stays 0; recomp is already maintenance energy and is kept.
  const zero = generatePlan({ ...base, weightGoal: 'recomp', healthFlags: ['other_medical'], goals: [g('strength', 'none')] });
  assert.equal(zero.goals[0].startLevel, 0);
  assert.equal(zero.weightGoal, 'recomp');
});

test('3.2 medical hold: pregnancy alone and no flags leave the hold off and levels unchanged', () => {
  const pregnant = generatePlan({ ...base, sex: 'female', healthFlags: ['pregnancy'], goals: [g('strength', 'advanced')] });
  assert.equal(pregnant.medicalHold, false);
  assert.equal(pregnant.goals[0].startLevel, 3);
  assert.equal(finding(pregnant, 'medical_hold'), undefined);
  const clear = generatePlan({ ...base, goals: [g('strength', 'advanced')] });
  assert.equal(clear.medicalHold, false);
  assert.equal(clear.goals[0].startLevel, 3);
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

test('snapshot: strengths and gaps are reported, no waist-to-height', () => {
  const plan = generatePlan({ ...base, goals: [g('strength', 'advanced'), g('running', 'none')] });
  assert.deepEqual(plan.snapshot.strengths, ['Strength']);
  assert.deepEqual(plan.snapshot.gaps, ['Running']);
  assert.equal('waistToHeight' in plan.snapshot, false); // feature removed 2026-10-27 (owner)
  assert.equal(plan.review.some((f) => f.id === 'waist_to_height'), false);
});

test('validateInput: 2.0 fields validated and round-tripped', () => {
  const full = { ...base, bodyType: 'average', daysPerWeek: 4, sessionMinutes: 45, dailyActivity: 'light', sleepHours: 7.5, healthFlags: [], equipment: 'custom', equipmentItems: ['pull-up bar'], supplements: ['creatine'] } as const;
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

// ---- property tests (coach plan item 5): the cited bounds hold for any valid answers ----------------------------

test('properties: across 600 random valid inputs, energy never falls below BMR, protein stays 1.4-2.0 g/kg, exclusions hold, flags stop hard training', () => {
  // Small deterministic generator, so a failure always reproduces.
  let seed = 20261024;
  const rnd = () => ((seed = (seed * 1103515245 + 12345) % 2147483648) / 2147483648);
  const int = (lo: number, hi: number) => lo + Math.floor(rnd() * (hi - lo + 1));
  const pick = <T>(xs: readonly T[]): T => xs[int(0, xs.length - 1)];
  const subset = <T>(xs: readonly T[]): T[] => xs.filter(() => rnd() < 0.25);
  // Expected exclusions, written out from the plan engine's sources (DIET_EXCLUDES, RESTRICTION_EXCLUDES).
  const dietEx: Record<string, string[]> = {
    vegetarian: ['meat', 'poultry', 'fish', 'shellfish', 'egg'], eggitarian: ['meat', 'poultry', 'fish', 'shellfish'],
    vegan: ['meat', 'poultry', 'fish', 'shellfish', 'egg', 'dairy', 'honey'], non_vegetarian: [],
  };
  const restrictionEx: Record<string, string[]> = {
    lactose: ['dairy'], gluten: ['wheat', 'barley', 'rye'], peanut: ['peanut'], tree_nut: ['tree_nut'], soy: ['soy'], egg: ['egg'], fish: ['fish'], shellfish: ['shellfish'],
  };
  const restrictions = ['lactose', 'gluten', 'peanut', 'tree_nut', 'soy', 'egg', 'fish', 'shellfish'] as const;
  const flags = ['heart_condition', 'chest_pain', 'dizziness', 'pregnancy', 'other_medical'] as const;
  for (let i = 0; i < 600; i++) {
    const goals = [...new Set(Array.from({ length: int(1, 3) }, () => pick(CATALOG).goal))].map((id) => g(id, pick(EXPERIENCE)));
    const sex = pick(['male', 'female'] as const);
    const input = validateInput({
      ...base, ageYears: int(18, 80), sex, heightCm: int(145, 205), weightKg: int(42, 140), weightGoal: pick(WEIGHT_GOALS), goals,
      diet: pick(DIETS), restrictions: subset(restrictions), daysPerWeek: int(1, 7), sessionMinutes: pick([20, 30, 45, 60, 90]),
      healthFlags: subset(flags).filter((f) => f !== 'pregnancy' || sex === 'female'),
    });
    const plan = generatePlan(input);
    const n = plan.nutrition;
    const at = `case ${i}: ${JSON.stringify({ age: input.ageYears, sex, h: input.heightCm, w: input.weightKg, goal: input.weightGoal })}`;
    assert.ok(n.energyKcal >= n.bmrKcal - 5, `${at}: energy ${n.energyKcal} below BMR ${n.bmrKcal}`);
    assert.ok(n.proteinPerKg >= 1.4 && n.proteinPerKg <= 2.0, `${at}: protein ${n.proteinPerKg} g/kg`);
    assert.ok(Math.abs(n.proteinG - input.weightKg * n.proteinPerKg) <= 0.5, `${at}: protein grams`);
    for (const tag of ['beef', 'pork', ...dietEx[input.diet], ...input.restrictions.flatMap((r) => restrictionEx[r])]) {
      assert.ok(n.excludedFoodTags.includes(tag), `${at}: ${tag} not excluded`);
    }
    if (n.excludedFoodTags.includes('soy')) assert.equal(n.maxSoyaChunksDryG, 0, `${at}: soya allowed despite soy exclusion`);
    const f = input.healthFlags ?? [];
    if (f.some((x) => x !== 'pregnancy')) {
      assert.ok(plan.review.some((r) => r.id === 'medical_clearance' && r.level === 'stop'), `${at}: no clearance stop`);
      assert.ok(plan.medicalHold && plan.goals.every((x) => x.startLevel <= MEDICAL_MAX_LEVEL), `${at}: medical hold not applied`);
      assert.ok(plan.weightGoal !== 'cut' && plan.weightGoal !== 'bulk', `${at}: deficit or surplus under a medical hold`);
    }
    if (f.includes('pregnancy')) {
      assert.ok(plan.review.some((r) => r.id === 'pregnancy' && r.level === 'stop'), `${at}: no pregnancy stop`);
      assert.notEqual(plan.weightGoal, 'cut', `${at}: cutting in pregnancy`);
    }
    assert.ok(plan.trainingDaysPerWeek >= 1 && plan.trainingDaysPerWeek <= 7, `${at}: ${plan.trainingDaysPerWeek} days`);
  }
});

test('pace moves only cut and bulk energy; balanced matches 3.0', () => {
  const kcal = (weightGoal: 'cut' | 'bulk' | 'maintain', pace?: 'easy' | 'balanced' | 'hard') =>
    generatePlan({ ...base, weightGoal, ...(pace ? { pace } : {}) }).nutrition.energyKcal;
  assert.equal(kcal('cut', 'balanced'), kcal('cut'));
  assert.ok(kcal('cut', 'easy') > kcal('cut', 'balanced') && kcal('cut', 'balanced') > kcal('cut', 'hard'));
  assert.ok(kcal('bulk', 'easy') < kcal('bulk', 'balanced') && kcal('bulk', 'balanced') < kcal('bulk', 'hard'));
  assert.equal(kcal('maintain', 'hard'), kcal('maintain', 'easy'));
  assert.equal(validateInput({ ...base, pace: 'hard' }).pace, 'hard');
  assert.throws(() => validateInput({ ...base, pace: 'extreme' }));
});

test('a cut never drops below the sex floor, and the floor never exceeds maintenance', () => {
  // Small, older, sedentary woman: 0.8 x maintenance would fall under 1,200 kcal.
  const small = { ...base, sex: 'female' as const, weightKg: 45, heightCm: 150, ageYears: 60, weightGoal: 'cut' as const, pace: 'hard' as const, dailyActivity: 'sedentary' as const };
  const cut = generatePlan(small).nutrition.energyKcal;
  const maintain = generatePlan({ ...small, weightGoal: 'maintain' }).nutrition.energyKcal;
  assert.ok(cut >= Math.min(CUT_FLOOR_KCAL.female, maintain) - 1, `cut ${cut}, maintenance ${maintain}`);
  assert.ok(cut <= maintain);
});

test('3.3 Build my plate conditions: kidney disease removes creatine; pregnancy applies the pregnancy rule', () => {
  const kidney = generatePlan({ ...base, supplements: ['creatine', 'protein_powder'], conditions: ['kidney'] });
  assert.ok(!kidney.nutrition.supplements.some((s) => s.name.startsWith('Creatine')));
  assert.ok(kidney.nutrition.supplements.find((s) => s.name === 'Ask your doctor first')?.why.includes('kidney'));
  assert.equal(kidney.medicalHold, false, 'kidney disease alone does not put training on hold');
  const pregnant = generatePlan({ ...base, sex: 'female', weightGoal: 'cut', supplements: ['creatine'], conditions: ['pregnancy'] });
  assert.equal(pregnant.weightGoal, 'maintain');
  assert.equal(finding(pregnant, 'pregnancy')?.level, 'stop');
  assert.ok(!pregnant.nutrition.supplements.some((s) => s.name.startsWith('Creatine')));
  // A note-only condition changes nothing in the plan.
  const plain = generatePlan({ ...base, supplements: ['creatine'] });
  const noted = generatePlan({ ...base, supplements: ['creatine'], conditions: ['thyroid'] });
  assert.deepEqual(noted.nutrition, plain.nutrition);
  assert.throws(() => validateInput({ ...base, conditions: ['cancer'] }));
  assert.deepEqual(validateInput({ ...base, conditions: ['kidney', 'kidney'] }).conditions, ['kidney']);
});

test('3.4 schedule: chosen weekdays cap the week and are copied to the plan; none chosen changes nothing', () => {
  const free = generatePlan({ ...base, daysPerWeek: 5, goals: [g('strength', 'intermediate'), g('running', 'beginner')] });
  assert.deepEqual(free.schedule, { preferredDays: [], trainingTime: 'varies' });
  const fixed = generatePlan({ ...base, daysPerWeek: 5, trainingDays: [6, 1, 3], trainingTime: 'evening', goals: [g('strength', 'intermediate'), g('running', 'beginner')] });
  assert.deepEqual(fixed.schedule, { preferredDays: [1, 3, 6], trainingTime: 'evening' });
  assert.ok(fixed.trainingDaysPerWeek <= 3, `${fixed.trainingDaysPerWeek} days on 3 weekdays`);
  assert.equal(finding(fixed, 'days_by_weekday')?.level, 'info');
  assert.ok(free.trainingDaysPerWeek > 3);
  assert.throws(() => validateInput({ ...base, trainingDays: [0] }));
  assert.throws(() => validateInput({ ...base, trainingTime: 'whenever' }));
  assert.deepEqual(validateInput({ ...base, trainingDays: [5, 5, 2] }).trainingDays, [2, 5]);
});

test('protein for BMI 30 or more stays on body weight until a reference-weight source is approved (B6 blocker)', () => {
  // No source in data/handbook_v4/sources_register.csv supports a reference or adjusted body weight, so the engine
  // keeps g/kg of actual weight (ISSN). This test records today's behaviour; change it with a sourced rule only.
  const heavy = generatePlan({ ...base, heightCm: 170, weightKg: 110, weightGoal: 'cut' }); // BMI 38.1
  assert.equal(heavy.nutrition.proteinG, Math.round(110 * heavy.nutrition.proteinPerKg));
});

test('3.5 energy working: maintenance, activity factor and goal factor are stored and match the target', () => {
  const cut = generatePlan({ ...base, weightGoal: 'cut', daysPerWeek: 4, dailyActivity: 'light', goals: [g('strength', 'intermediate')] });
  const e = cut.nutrition.energy;
  const bmr = 10 * 72 + 6.25 * 175 - 5 * 28 + 5;
  assert.equal(e.activity.factor, 1.55);
  assert.equal(e.activity.from, 'training_days');
  assert.equal(e.maintenanceKcal, Math.round((bmr * 1.55) / 10) * 10);
  assert.equal(e.goalFactor, 0.85);
  assert.equal(e.floor, null);
  assert.equal(cut.nutrition.energyKcal, Math.round((bmr * 1.55 * 0.85) / 10) * 10, 'the target is maintenance x goal factor');
  assert.ok(cut.nutrition.energyKcal < e.maintenanceKcal);
  // A busy day job beats few training days, and the plan says so.
  const job = generatePlan({ ...base, daysPerWeek: 2, dailyActivity: 'very_active' });
  assert.deepEqual([job.nutrition.energy.activity.factor, job.nutrition.energy.activity.from], [1.725, 'daily_activity']);
  assert.equal(job.nutrition.energyKcal, job.nutrition.energy.maintenanceKcal, 'maintain: target = maintenance');
  // A small, inactive person cutting hard hits the cut minimum; the plan names the floor.
  const small = generatePlan({ ...base, sex: 'female', heightCm: 150, weightKg: 45, ageYears: 60, weightGoal: 'cut', pace: 'hard', daysPerWeek: 1, dailyActivity: 'sedentary' });
  assert.notEqual(small.nutrition.energy.floor, null);
  assert.ok(small.nutrition.energyKcal >= small.nutrition.bmrKcal - 5);
  // Across many inputs, the stored working always reproduces the stored target.
  for (const weightGoal of ['cut', 'bulk', 'recomp', 'maintain', 'general'] as const) {
    for (const daysPerWeek of [1, 3, 5, 7]) {
      const p = generatePlan({ ...base, weightGoal, daysPerWeek, dailyActivity: 'active' });
      const w = p.nutrition.energy;
      if (w.floor === null) {
        const raw = (10 * 72 + 6.25 * 175 - 5 * 28 + 5) * w.activity.factor * w.goalFactor;
        assert.equal(p.nutrition.energyKcal, Math.round(raw / 10) * 10, `${weightGoal} ${daysPerWeek}`);
      }
    }
  }
});

test('own exclusion words name whole food groups: "milk" leaves out all dairy; plant milks and peanut butter do not', () => {
  const plan = (otherRestrictions: string[]) => generatePlan({ ...base, otherRestrictions, supplements: ['protein_powder'] });
  assert.ok(plan(['milk']).nutrition.excludedFoodTags.includes('dairy'));
  assert.ok(plan(['no dairy please']).nutrition.excludedFoodTags.includes('dairy'));
  assert.match(plan(['milk']).nutrition.supplements.find((s) => s.name === 'Protein powder')!.how, /pea or soy protein/, 'never whey');
  assert.ok(!plan(['coconut milk']).nutrition.excludedFoodTags.includes('dairy'));
  assert.ok(!plan(['peanut butter']).nutrition.excludedFoodTags.includes('dairy'));
  assert.ok(plan(['peanut butter']).nutrition.excludedFoodTags.includes('peanut'));
  assert.ok(plan(['prawns']).nutrition.excludedFoodTags.includes('shellfish'));
  assert.deepEqual(plan(['sesame']).nutrition.excludedFoodTags, plan([]).nutrition.excludedFoodTags, 'unknown words only match food names');
});
