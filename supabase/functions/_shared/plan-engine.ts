// Levlofit plan engine. Pure functions, no I/O, so the same code runs in the
// Edge Function (Deno) and in Node tests. Every number cites its source.
//
// 2.0: the engine no longer just echoes the user's choices. reviewInput() analyses the answers
// first (safety, body composition vs phase, goal load, schedule, recovery, equipment) and may
// change the training phase; every finding carries a plain reason and a source. generatePlan()
// then builds the plan from the reviewed choices. The LLM assistant may explain these findings
// but never produces numbers.
//
// 3.0: level first, one step at a time. Each goal trains from the user's assessed level (goal_levels),
// falling back to self-reported experience. Without the basics in the main goal (Level 0 or 1) the plan is a
// foundation phase: only the main goal, plus the WHO strength minimum. Extra goals unlock one at a time as the
// main goal climbs (Level 2 unlocks one, Level 3 a second); anything beyond waits, with the reason shown.

export const ENGINE_VERSION = '3.0.0';
export const MAX_GOALS = 6; // one primary + up to five optional extras

// Goals live in the goal_catalog table; generate-plan passes each goal's kind and coach rule in.
export const SESSION_KINDS = ['strength', 'endurance', 'hybrid', 'skill', 'mobility'] as const;
export const EXPERIENCE = ['none', 'beginner', 'intermediate', 'advanced'] as const;
export const DIETS = ['vegetarian', 'eggitarian', 'vegan', 'non_vegetarian'] as const;
export const RESTRICTIONS = ['lactose', 'gluten', 'peanut', 'tree_nut', 'soy', 'egg', 'fish', 'shellfish'] as const;
export const WEIGHT_GOALS = ['cut', 'bulk', 'recomp', 'maintain', 'general'] as const;
export const SEXES = ['male', 'female'] as const;
export const BODY_TYPES = ['lean', 'average', 'extra_fat', 'muscular', 'slim_soft'] as const;
export const ACTIVITY = ['sedentary', 'light', 'active', 'very_active'] as const;
export const EQUIPMENT = ['none', 'home', 'gym', 'custom'] as const;
export const HEALTH_FLAGS = ['heart_condition', 'chest_pain', 'dizziness', 'pregnancy', 'other_medical'] as const;
export const SUPPLEMENTS = ['protein_powder', 'creatine'] as const;

export type Experience = (typeof EXPERIENCE)[number];
export type Diet = (typeof DIETS)[number];
export type Restriction = (typeof RESTRICTIONS)[number];
export type WeightGoal = (typeof WEIGHT_GOALS)[number];
export type Sex = (typeof SEXES)[number];
export type SessionKind = (typeof SESSION_KINDS)[number];
export type BodyType = (typeof BODY_TYPES)[number];
export type Activity = (typeof ACTIVITY)[number];
export type Equipment = (typeof EQUIPMENT)[number];
export type HealthFlag = (typeof HEALTH_FLAGS)[number];
export type Supplement = (typeof SUPPLEMENTS)[number];

export interface GoalInput {
  goal: string; // goal_catalog.id
  name: string;
  kind: SessionKind;
  coachLedFromLevel: number | null;
  experience: Experience;
  currentLevel?: number; // assessed level, 0 to 5; wins over experience
}

export interface PlanInput {
  ageYears: number;
  sex: Sex;
  heightCm: number;
  weightKg: number;
  weightGoal: WeightGoal;
  goals: GoalInput[]; // index 0 is the primary goal
  diet: Diet;
  restrictions: Restriction[];
  otherRestrictions?: string[]; // free text, e.g. "sesame"; matched against food names
  // 2.0 intake. All optional so older saved answers still produce a plan.
  bodyType?: BodyType;
  waistCm?: number;
  daysPerWeek?: number; // days the user can train
  sessionMinutes?: number;
  dailyActivity?: Activity; // outside training
  sleepHours?: number;
  healthFlags?: HealthFlag[];
  injuries?: string;
  equipment?: Equipment;
  equipmentItems?: string[];
  supplements?: Supplement[]; // what the user is willing to use
}

export type FindingLevel = 'stop' | 'change' | 'advice' | 'info';

export interface Finding {
  id: string;
  level: FindingLevel; // stop: see a professional first; change: the engine changed a choice
  title: string;
  why: string;
  source: string;
}

export interface GoalPlan {
  goal: string;
  name: string;
  experience: Experience;
  startLevel: number;
  coachLedFromLevel: number | null;
  sessionsPerWeek: number; // 0 when the goal only fits as an add-on block
  addOnBlocksPerWeek: number; // 20-minute blocks attached to other sessions
  kind: SessionKind;
  status: 'active' | 'queued'; // queued goals wait for the main goal to level up
  unlockWhen: string | null;
}

export interface SupplementAdvice {
  name: string;
  how: string;
  why: string;
  source: string;
}

export interface Plan {
  engineVersion: string;
  chosenWeightGoal: WeightGoal; // what the user picked
  weightGoal: WeightGoal; // what the plan uses after review
  phase: { id: 'foundation' | 'build'; title: string; why: string; source: string };
  review: Finding[];
  snapshot: {
    bmi: { value: number; category: 'underweight' | 'normal' | 'overweight' | 'obese' };
    waistToHeight: { value: number; category: 'healthy' | 'increased' | 'high' } | null;
    strengths: string[]; // goal names where the user already trains with a plan
    gaps: string[]; // goal names starting from zero or basics
    sleep: 'enough' | 'short' | 'unknown';
  };
  bmi: { value: number; category: 'underweight' | 'normal' | 'overweight' | 'obese' }; // kept for older clients
  goals: GoalPlan[];
  extraStrengthSessions: number;
  strengthAddOns: number;
  trainingDaysPerWeek: number;
  activityGuideline: { moderateMinutesPerWeek: [number, number] };
  nutrition: {
    bmrKcal: number;
    energyKcal: number;
    proteinPerKg: number;
    proteinG: number;
    maxSoyaChunksDryG: number;
    excludedFoodTags: string[];
    customExclusions: string[];
    supplements: SupplementAdvice[];
  };
  sources: string[];
}

// Curriculum ch.2 + ch.31: self-reported experience only sets the entry level.
// Levels 4 and 5 must be earned by passing tests, never self-assigned.
const ENTRY_LEVEL: Record<Experience, number> = { none: 0, beginner: 1, intermediate: 2, advanced: 3 };

// Curriculum ch.28: keep at least one real rest day; ch.29 caps total load.
const MAX_TRAINING_DAYS = 6;
// Curriculum ch.8: 2 full sessions a week is the minimum that still progresses a skill.
const PRIMARY_MIN_SESSIONS = 2;
// WHO 2020 guidelines: muscle-strengthening activity on 2 or more days a week.
const MIN_STRENGTH_DAYS = 2;
// WHO 2020 guidelines: 150-300 min of moderate aerobic activity a week.
const WHO_MODERATE_MINUTES: [number, number] = [150, 300];
// Curriculum p.2 and ch.29: 1 primary + 1-2 secondary goals.
const RECOMMENDED_MAX_GOALS = 3;

// ISSN protein position stand (Jäger 2017): 1.4-2.0 g/kg/day; the top of the range is most useful
// in an energy deficit and when trying to gain muscle while losing fat (recomposition).
const PROTEIN_PER_KG: Record<WeightGoal, number> = { cut: 2.0, recomp: 2.0, bulk: 1.6, maintain: 1.6, general: 1.4 };
const PROTEIN_RANGE: [number, number] = [1.4, 2.0];

// ISSN diets and body composition (Aragon 2017): moderate deficit for fat loss, small surplus for
// lean gain, maintenance intake with high protein for recomposition.
const ENERGY_FACTOR: Record<WeightGoal, number> = { cut: 0.85, bulk: 1.1, recomp: 1.0, maintain: 1.0, general: 1.0 };

// Standard activity multipliers used with Mifflin-St Jeor. The higher of the training-based and
// the lifestyle-based factor is used, so an active job is not ignored and nothing is counted twice.
const ACTIVITY_FACTOR: Record<Activity, number> = { sedentary: 1.2, light: 1.375, active: 1.55, very_active: 1.725 };

// Soya chunks: 50 g dry a day is a Levlofit variety cap, not a safety limit. Clinical meta-analyses find no
// effect of soy on male hormones at any tested dose (Reed et al. 2021, Reprod Toxicol 100:60-67).
const MAX_SOYA_CHUNKS_DRY_G = 50;

// Product rule for an India-first app: never offered, for any diet.
const ALWAYS_EXCLUDED = ['beef', 'pork'];

const DIET_EXCLUDES: Record<Diet, string[]> = {
  vegetarian: ['meat', 'poultry', 'fish', 'shellfish', 'egg'],
  eggitarian: ['meat', 'poultry', 'fish', 'shellfish'],
  vegan: ['meat', 'poultry', 'fish', 'shellfish', 'egg', 'dairy', 'honey'],
  non_vegetarian: [],
};

const RESTRICTION_EXCLUDES: Record<Restriction, string[]> = {
  lactose: ['dairy'],
  gluten: ['wheat', 'barley', 'rye'],
  peanut: ['peanut'],
  tree_nut: ['tree_nut'],
  soy: ['soy'],
  egg: ['egg'],
  fish: ['fish'],
  shellfish: ['shellfish'],
};

const SRC = {
  curriculum: 'Self-Coaching Athlete Master Curriculum (2026)',
  acsmScreen: 'ACSM pre-participation health screening (Riebe et al., Med Sci Sports Exerc 2015)',
  who: 'WHO Guidelines on Physical Activity and Sedentary Behaviour (2020)',
  issnProtein: 'ISSN Position Stand: Protein and Exercise (Jäger et al., 2017)',
  issnDiet: 'ISSN Position Stand: Diets and Body Composition (Aragon et al., 2017)',
  issnCreatine: 'ISSN Position Stand: Creatine supplementation (Kreider et al., 2017)',
  recomp: 'Body recomposition review (Barakat et al., Strength Cond J 2020)',
  bmiIndia: 'Consensus BMI cut-offs for Asian Indians (Misra et al., 2009, JAPI 57:163)',
  whtr: 'NICE guideline: waist-to-height ratio 0.5 and 0.6 boundaries (2022)',
  sleep: 'Recommended sleep for adults, 7 h or more (Watson et al., AASM/SRS consensus 2015)',
  mifflin: 'Mifflin-St Jeor equation (Mifflin et al., 1990)',
  acsmRt: 'ACSM Position Stand: Resistance Training Prescription (2026), PMID 41843416',
};

export function validateInput(raw: unknown): PlanInput {
  const x = raw as Record<string, unknown>;
  if (!x || typeof x !== 'object') throw new Error('Body must be a JSON object');
  const num = (k: string, min: number, max: number) => {
    const v = x[k];
    if (typeof v !== 'number' || !Number.isFinite(v) || v < min || v > max) throw new Error(`${k} must be a number between ${min} and ${max}`);
    return v;
  };
  const optNum = (k: string, min: number, max: number) => (x[k] == null ? undefined : num(k, min, max));
  const oneOf = <T extends string>(k: string, allowed: readonly T[]) => {
    const v = x[k];
    if (typeof v !== 'string' || !allowed.includes(v as T)) throw new Error(`${k} must be one of ${allowed.join(', ')}`);
    return v as T;
  };
  const optOneOf = <T extends string>(k: string, allowed: readonly T[]) => (x[k] == null ? undefined : oneOf(k, allowed));
  const listOf = <T extends string>(k: string, allowed: readonly T[]) => {
    const v = x[k] ?? [];
    if (!Array.isArray(v) || v.some((i) => !allowed.includes(i as T))) throw new Error(`${k} must only contain ${allowed.join(', ')}`);
    return [...new Set(v as T[])];
  };
  const textList = (k: string, maxItems: number, maxLen: number) => {
    const v = x[k] ?? [];
    if (!Array.isArray(v) || v.length > maxItems || v.some((o) => typeof o !== 'string' || o.trim().length < 2 || o.trim().length > maxLen)) {
      throw new Error(`${k} must be up to ${maxItems} items of 2 to ${maxLen} characters`);
    }
    return [...new Set((v as string[]).map((o) => o.trim().toLowerCase()))];
  };

  const goals = x.goals;
  if (!Array.isArray(goals) || goals.length < 1 || goals.length > MAX_GOALS) throw new Error(`goals must list 1 to ${MAX_GOALS} goals`);
  const seen = new Set<string>();
  const parsedGoals = goals.map((g): GoalInput => {
    const { goal, name, kind, coachLedFromLevel, experience, currentLevel } = (g ?? {}) as Record<string, unknown>;
    if (typeof goal !== 'string' || !/^[a-z_]{2,40}$/.test(goal)) throw new Error(`Unknown goal: ${String(goal)}`);
    if (typeof name !== 'string' || !name || name.length > 60) throw new Error(`Goal ${goal} needs a name`);
    if (!SESSION_KINDS.includes(kind as SessionKind)) throw new Error(`Goal ${goal} has an unknown kind`);
    const coach = coachLedFromLevel ?? null;
    if (coach !== null && !(typeof coach === 'number' && coach >= 1 && coach <= 5)) throw new Error(`Goal ${goal} has a bad coach level`);
    if (!EXPERIENCE.includes(experience as Experience)) throw new Error(`Unknown experience: ${String(experience)}`);
    if (currentLevel != null && !(Number.isInteger(currentLevel) && (currentLevel as number) >= 0 && (currentLevel as number) <= 5)) {
      throw new Error(`Goal ${goal} has a bad level`);
    }
    if (seen.has(goal)) throw new Error(`Duplicate goal: ${goal}`);
    seen.add(goal);
    return {
      goal,
      name,
      kind: kind as SessionKind,
      coachLedFromLevel: coach,
      experience: experience as Experience,
      ...(currentLevel == null ? {} : { currentLevel: currentLevel as number }),
    };
  });

  const injuries = x.injuries;
  if (injuries != null && (typeof injuries !== 'string' || injuries.length > 300)) throw new Error('injuries must be up to 300 characters');

  const input: PlanInput = {
    ageYears: num('ageYears', 18, 80), // adults only: the curriculum and ISSN guidance cover adults
    sex: oneOf('sex', SEXES),
    heightCm: num('heightCm', 120, 230),
    weightKg: num('weightKg', 30, 250),
    weightGoal: oneOf('weightGoal', WEIGHT_GOALS),
    goals: parsedGoals,
    diet: oneOf('diet', DIETS),
    restrictions: listOf('restrictions', RESTRICTIONS),
    otherRestrictions: textList('otherRestrictions', 10, 40),
  };
  // Optional 2.0 fields: only set when present, so older inputs round-trip unchanged.
  const optional: Partial<PlanInput> = {
    bodyType: optOneOf('bodyType', BODY_TYPES),
    waistCm: optNum('waistCm', 40, 200),
    daysPerWeek: optNum('daysPerWeek', 1, 7),
    sessionMinutes: optNum('sessionMinutes', 20, 90),
    dailyActivity: optOneOf('dailyActivity', ACTIVITY),
    sleepHours: optNum('sleepHours', 3, 12),
    healthFlags: x.healthFlags == null ? undefined : listOf('healthFlags', HEALTH_FLAGS),
    injuries: typeof injuries === 'string' && injuries.trim() ? injuries.trim() : undefined,
    equipment: optOneOf('equipment', EQUIPMENT),
    equipmentItems: x.equipmentItems == null ? undefined : textList('equipmentItems', 20, 40),
    supplements: x.supplements == null ? undefined : listOf('supplements', SUPPLEMENTS),
  };
  for (const [k, v] of Object.entries(optional)) if (v !== undefined) (input as unknown as Record<string, unknown>)[k] = v;
  return input;
}

export function bmiCategory(bmi: number): Plan['bmi']['category'] {
  if (bmi < 18.0) return 'underweight';
  if (bmi < 23.0) return 'normal';
  if (bmi < 25.0) return 'overweight';
  return 'obese';
}

export function waistToHeightCategory(ratio: number): 'healthy' | 'increased' | 'high' {
  if (ratio < 0.5) return 'healthy';
  if (ratio < 0.6) return 'increased';
  return 'high';
}

const bmiOf = (input: PlanInput) => Math.round((input.weightKg / (input.heightCm / 100) ** 2) * 10) / 10;

/** Analyse the answers before planning. Returns findings and the training phase the plan should use. */
export function reviewInput(input: PlanInput): { weightGoal: WeightGoal; findings: Finding[] } {
  const findings: Finding[] = [];
  const bmi = bmiOf(input);
  const category = bmiCategory(bmi);
  const whtr = input.waistCm ? input.waistCm / input.heightCm : null;
  const primaryLevel = levelOf(input.goals[0]);
  let weightGoal = input.weightGoal;

  // Safety first: any symptom or condition on the screen means clearance before hard training.
  const flags = input.healthFlags ?? [];
  if (flags.some((f) => f !== 'pregnancy')) {
    findings.push({
      id: 'medical_clearance',
      level: 'stop',
      title: 'Check with a doctor before hard training',
      why: 'You reported a heart condition, chest pain, dizziness or another medical condition. Start with light activity only until a doctor clears you for harder training.',
      source: SRC.acsmScreen,
    });
  }
  if (flags.includes('pregnancy')) {
    findings.push({
      id: 'pregnancy',
      level: 'stop',
      title: 'Train with your doctor’s guidance during pregnancy',
      why: 'Regular moderate activity is recommended in pregnancy, but intensity, heavy lifting and any cutting phase should be agreed with your doctor. The plan keeps energy at maintenance.',
      source: SRC.who,
    });
    if (weightGoal === 'cut' || weightGoal === 'bulk') weightGoal = 'maintain';
  }

  // Phase versus body composition.
  if (weightGoal === 'cut' && category === 'underweight') {
    weightGoal = 'maintain';
    findings.push({
      id: 'cut_underweight',
      level: 'change',
      title: 'Cutting changed to maintenance',
      why: `Your BMI is ${bmi}, below the healthy range for Indian adults (18.0). Eating less would take you further below it, so the plan keeps you at maintenance and builds strength instead.`,
      source: SRC.bmiIndia,
    });
  }
  if (weightGoal === 'bulk' && (category === 'obese' || (whtr !== null && whtr >= 0.6))) {
    weightGoal = primaryLevel <= 1 ? 'recomp' : 'cut';
    findings.push({
      id: 'bulk_high_fat',
      level: 'change',
      title: primaryLevel <= 1 ? 'Bulking changed to recomposition' : 'Bulking changed to cutting',
      why:
        primaryLevel <= 1
          ? 'Your BMI or waist measurement is already high. New lifters carrying extra fat can build muscle while losing fat at maintenance calories with high protein, so a surplus is not needed.'
          : 'Your BMI or waist measurement is already high. Losing some fat first makes a later muscle-gain phase healthier and more effective.',
      source: primaryLevel <= 1 ? SRC.recomp : SRC.issnDiet,
    });
  } else if (weightGoal === 'bulk' && input.bodyType === 'slim_soft' && primaryLevel <= 1) {
    weightGoal = 'recomp';
    findings.push({
      id: 'bulk_slim_soft',
      level: 'change',
      title: 'Bulking changed to recomposition',
      why: 'You describe yourself as slim but soft and you are new to training. At this stage lifting with high protein at maintenance usually adds muscle and reduces fat together, without the extra fat a surplus brings.',
      source: SRC.recomp,
    });
  }
  if (weightGoal === 'cut' && input.bodyType === 'lean' && category === 'normal') {
    findings.push({
      id: 'cut_lean',
      level: 'advice',
      title: 'You are already lean',
      why: 'A cut from an already lean start mostly costs strength and energy. Consider maintenance or recomposition unless you have a specific event.',
      source: SRC.issnDiet,
    });
  }
  if (whtr !== null && whtr >= 0.5) {
    findings.push({
      id: 'waist_to_height',
      level: 'info',
      title: `Waist-to-height ratio ${whtr.toFixed(2)}`,
      why:
        whtr >= 0.6
          ? 'Above 0.6 means a high health risk from fat around the middle. Training plus a modest calorie deficit is the most effective way to bring it down.'
          : 'Between 0.5 and 0.6 means increased health risk from fat around the middle. Keeping your waist below half your height is a good long-term target.',
      source: SRC.whtr,
    });
  }

  // Goal load and schedule.
  if (input.goals.length > RECOMMENDED_MAX_GOALS) {
    findings.push({
      id: 'too_many_goals',
      level: 'advice',
      title: `${input.goals.length} goals at once`,
      why: `The curriculum recommends one main goal plus one or two others. Your plan puts ${input.goals[0].name} first and gives the rest the minimum that keeps them moving; progress on each extra will be slower.`,
      source: `${SRC.curriculum}, p.2 and ch. 29`,
    });
  }
  const days = input.daysPerWeek;
  if (days !== undefined && days <= 2) {
    findings.push({
      id: 'few_days',
      level: 'info',
      title: `${days} training ${days === 1 ? 'day' : 'days'} a week`,
      why: 'The plan fits into your days by folding extra goals into short blocks. Two strength sessions a week is the minimum recommended for adults, so strength work is kept in every session.',
      source: SRC.who,
    });
  }
  if (input.sessionMinutes !== undefined && input.sessionMinutes <= 30 && input.goals.length > 2) {
    findings.push({
      id: 'short_sessions',
      level: 'advice',
      title: 'Short sessions for several goals',
      why: 'With 30 minutes or less per session, add-on blocks for extra goals do not fit well. Consider fewer goals or a longer session on one or two days.',
      source: `${SRC.curriculum}, ch. 29`,
    });
  }

  // Recovery.
  if (input.sleepHours !== undefined && input.sleepHours < 7) {
    findings.push({
      id: 'short_sleep',
      level: 'advice',
      title: 'Sleep is below 7 hours',
      why: 'Adults need 7 hours or more. Short sleep slows recovery and progress more than most programme details do.',
      source: SRC.sleep,
    });
  }
  if (input.dailyActivity === 'sedentary') {
    findings.push({
      id: 'sedentary',
      level: 'info',
      title: 'Mostly sitting outside training',
      why: 'Break up long sitting with light movement through the day. It adds to health benefits on top of your sessions.',
      source: SRC.who,
    });
  }
  if (input.injuries) {
    findings.push({
      id: 'injuries',
      level: 'advice',
      title: 'Train around your injury',
      why: `You mentioned: "${input.injuries}". Skip movements that cause pain and choose pain-free variations. Pain that persists needs a professional assessment.`,
      source: `${SRC.curriculum}, ch. 1 and 7`,
    });
  }

  // Equipment versus goals.
  if (input.equipment === 'none' && input.goals.some((g) => g.goal === 'powerlifting')) {
    findings.push({
      id: 'powerlifting_no_equipment',
      level: 'advice',
      title: 'Powerlifting needs a barbell',
      why: 'Squat, bench press and deadlift need a barbell and plates. Until you have gym access, the plan builds the same patterns with bodyweight and single-leg work.',
      source: `${SRC.curriculum}, ch. 8`,
    });
  }

  return { weightGoal, findings };
}

/// The level a goal trains at: the assessed level when there is one, else the self-reported entry level.
export function levelOf(g: GoalInput): number {
  return g.currentLevel ?? ENTRY_LEVEL[g.experience];
}

// Level first: Level 0-1 in the main goal means the basics are not there yet, so only the main goal trains.
// Curriculum p.2 and ch.29: one main goal plus one or two others, added as the main goal matures.
const FOUNDATION_MAX_LEVEL = 1;
const extrasAllowed = (primaryLevel: number) => (primaryLevel <= FOUNDATION_MAX_LEVEL ? 0 : primaryLevel === 2 ? 1 : RECOMMENDED_MAX_GOALS - 1);

function planGoals(input: PlanInput, maxDays: number): GoalPlan[] {
  const primary = input.goals[0];
  const allowed = extrasAllowed(levelOf(primary));
  const plans = input.goals.map((g, i): GoalPlan => {
    const level = levelOf(g);
    const active = i <= allowed;
    // Curriculum ch.8: beginners train 2-3 full-body sessions a week.
    // Ch.29: the primary goal gets the main volume, others the minimum effective dose.
    const sessions = !active ? 0 : i === 0 ? (level <= 1 ? 3 : 4) : level <= 1 ? 1 : 2;
    return {
      goal: g.goal,
      name: g.name,
      experience: g.experience,
      startLevel: level,
      coachLedFromLevel: g.coachLedFromLevel,
      sessionsPerWeek: Math.min(sessions, maxDays),
      addOnBlocksPerWeek: 0,
      kind: g.kind,
      status: active ? 'active' : 'queued',
      // Extra number i unlocks when the main goal reaches Level i + 1; past the cap, a slot must free up.
      unlockWhen: active
        ? null
        : i < RECOMMENDED_MAX_GOALS
          ? `${primary.name} reaches Level ${i + 1}`
          : `you finish or drop one of your ${RECOMMENDED_MAX_GOALS} active goals`,
    };
  });

  // Ch.29 priority model over the active goals, applied until the week fits in maxDays:
  // 1. extras drop to 1 session (lowest priority first), 2. primary drops to its minimum,
  // 3. lowest-priority extras become one add-on block instead of a session.
  let total = plans.reduce((s, p) => s + p.sessionsPerWeek, 0);
  for (let i = plans.length - 1; i > 0 && total > maxDays; i--) {
    while (plans[i].sessionsPerWeek > 1 && total > maxDays) {
      plans[i].sessionsPerWeek--;
      total--;
    }
  }
  const primaryCut = Math.min(total - maxDays, plans[0].sessionsPerWeek - Math.min(PRIMARY_MIN_SESSIONS, maxDays));
  if (primaryCut > 0) {
    plans[0].sessionsPerWeek -= primaryCut;
    total -= primaryCut;
  }
  for (let i = plans.length - 1; i > 0 && total > maxDays; i--) {
    if (plans[i].status !== 'active' || plans[i].sessionsPerWeek === 0) continue;
    total -= plans[i].sessionsPerWeek;
    plans[i].sessionsPerWeek = 0;
    plans[i].addOnBlocksPerWeek = 1;
  }
  return plans;
}

function supplementAdvice(input: PlanInput, proteinG: number, excluded: Set<string>): SupplementAdvice[] {
  const willing = input.supplements ?? [];
  const medical = (input.healthFlags ?? []).length > 0;
  const out: SupplementAdvice[] = [];
  if (willing.includes('creatine') && !medical && input.goals.some((g) => g.kind === 'strength' || g.kind === 'hybrid')) {
    out.push({
      name: 'Creatine monohydrate',
      how: '3–5 g a day, any time, with water or food. No loading phase needed.',
      why: 'The most researched supplement for strength and muscle gain, and safe for healthy adults. Skip it if you have kidney disease.',
      source: SRC.issnCreatine,
    });
  }
  if (willing.includes('protein_powder')) {
    const type = excluded.has('dairy') ? (excluded.has('soy') ? 'a pea protein' : 'a pea or soy protein') : 'a whey protein';
    out.push({
      name: 'Protein powder',
      how: `Only on days food falls short of ${proteinG} g protein; ${type} fits your diet.`,
      why: 'Food first. A scoop is a convenient top-up, not a requirement.',
      source: SRC.issnProtein,
    });
  }
  if (medical && willing.length > 0) {
    out.push({
      name: 'Ask your doctor first',
      how: 'Check any supplement with your doctor before starting.',
      why: 'You reported a medical condition on the health screen.',
      source: SRC.acsmScreen,
    });
  }
  return out;
}

export function generatePlan(input: PlanInput): Plan {
  const { weightGoal, findings } = reviewInput(input);
  const maxDays = Math.min(MAX_TRAINING_DAYS, input.daysPerWeek ?? MAX_TRAINING_DAYS);
  const goals = planGoals(input, maxDays);
  const goalDays = goals.reduce((s, g) => s + g.sessionsPerWeek, 0);

  const primary = goals[0];
  const queued = goals.filter((g) => g.status === 'queued');
  const foundation = primary.startLevel <= FOUNDATION_MAX_LEVEL;
  const phase = foundation
    ? {
        id: 'foundation' as const,
        title: 'Foundation phase',
        why: `You are at Level ${primary.startLevel} in ${primary.name}. The plan builds your basics there first, with full-body strength at least twice a week, before adding anything else.`,
        source: `${SRC.curriculum}, p.2, ch. 2 and 8; ${SRC.who}`,
      }
    : {
        id: 'build' as const,
        title: 'Build phase',
        why: `Your basics are in place (Level ${primary.startLevel} in ${primary.name}). ${primary.name} keeps the main volume and extra goals train at the minimum that still moves them forward.`,
        source: `${SRC.curriculum}, p.2 and ch. 29`,
      };
  if (queued.length) {
    findings.push({
      id: 'goals_queued',
      level: 'change',
      title: foundation ? 'Foundation first, other goals later' : `${queued.length} ${queued.length === 1 ? 'goal waits' : 'goals wait'} for now`,
      why: `${queued.map((g) => g.name).join(', ')} ${queued.length === 1 ? 'is' : 'are'} on hold so your training is not split thin. The next one switches on when ${queued[0].unlockWhen}${queued.length > 1 ? ', and the rest follow one at a time' : ''}.`,
      source: `${SRC.curriculum}, p.2 and ch. 29`,
    });
  }

  // WHO minimum of 2 strength days: add standalone sessions while there is room,
  // otherwise attach 20-minute strength blocks to existing sessions.
  const strengthDays = goals.filter((g) => g.kind === 'strength').reduce((s, g) => s + g.sessionsPerWeek, 0);
  const missing = Math.max(0, MIN_STRENGTH_DAYS - strengthDays);
  const extraStrengthSessions = Math.min(missing, maxDays - goalDays);
  const strengthAddOns = missing - extraStrengthSessions;
  const trainingDaysPerWeek = goalDays + extraStrengthSessions;

  const bmiValue = bmiOf(input);
  const whtr = input.waistCm ? Math.round((input.waistCm / input.heightCm) * 100) / 100 : null;

  const bmr = 10 * input.weightKg + 6.25 * input.heightCm - 5 * input.ageYears + (input.sex === 'male' ? 5 : -161);
  // Standard physical-activity multipliers for 1-3, 3-5 and 6-7 training days a week.
  const trainingFactor = trainingDaysPerWeek <= 3 ? 1.375 : trainingDaysPerWeek <= 5 ? 1.55 : 1.725;
  const activity = Math.max(trainingFactor, input.dailyActivity ? ACTIVITY_FACTOR[input.dailyActivity] : 0);
  // Safety floor: never prescribe intake below estimated BMR.
  const energy = Math.max(bmr, bmr * activity * ENERGY_FACTOR[weightGoal]);

  const proteinPerKg = Math.min(PROTEIN_RANGE[1], Math.max(PROTEIN_RANGE[0], PROTEIN_PER_KG[weightGoal]));
  const proteinG = Math.round(input.weightKg * proteinPerKg);

  const excluded = new Set<string>([
    ...ALWAYS_EXCLUDED,
    ...DIET_EXCLUDES[input.diet],
    ...input.restrictions.flatMap((r) => RESTRICTION_EXCLUDES[r]),
  ]);

  const levels = input.goals.map((g) => ({ name: g.name, level: levelOf(g) }));
  const bmi = { value: bmiValue, category: bmiCategory(bmiValue) };

  return {
    engineVersion: ENGINE_VERSION,
    chosenWeightGoal: input.weightGoal,
    weightGoal,
    phase,
    review: findings,
    snapshot: {
      bmi,
      waistToHeight: whtr === null ? null : { value: whtr, category: waistToHeightCategory(whtr) },
      strengths: levels.filter((l) => l.level >= 2).map((l) => l.name),
      gaps: levels.filter((l) => l.level <= 1).map((l) => l.name),
      sleep: input.sleepHours === undefined ? 'unknown' : input.sleepHours >= 7 ? 'enough' : 'short',
    },
    bmi,
    goals,
    extraStrengthSessions,
    strengthAddOns,
    trainingDaysPerWeek,
    activityGuideline: { moderateMinutesPerWeek: WHO_MODERATE_MINUTES },
    nutrition: {
      bmrKcal: Math.round(bmr),
      energyKcal: Math.round(energy / 10) * 10,
      proteinPerKg,
      proteinG,
      maxSoyaChunksDryG: excluded.has('soy') ? 0 : MAX_SOYA_CHUNKS_DRY_G,
      excludedFoodTags: [...excluded].sort(),
      customExclusions: input.otherRestrictions ?? [],
      supplements: supplementAdvice(input, proteinG, excluded),
    },
    sources: [
      `${SRC.curriculum}, ch. 2, 8, 23-25, 28, 29, 31`,
      SRC.acsmRt,
      SRC.who,
      SRC.issnProtein,
      SRC.issnDiet,
      SRC.mifflin,
      SRC.bmiIndia,
      ...findings.map((f) => f.source),
    ].filter((s, i, all) => all.indexOf(s) === i),
  };
}

export interface LevelRow {
  goal: string;
  level: number;
  title: string;
  practice: string[];
  advance_when: string;
}

export interface Roadmap {
  intro: string;
  steps: { title: string; focus: string; moveOnWhen: string }[];
}

/**
 * The coach's path: written from rules and the curriculum's level checks, never by a language model.
 * Assess first, then the main goal level by level, then each waiting goal as it unlocks.
 */
export function buildRoadmap(plan: Plan, rows: LevelRow[], assessed: Set<string>): Roadmap {
  const row = (goal: string, level: number) => rows.find((r) => r.goal === goal && r.level === level);
  const steps: Roadmap['steps'] = [];
  const [primary, ...rest] = plan.goals;
  if (!assessed.has(primary.goal) && row(primary.goal, 0)) {
    steps.push({
      title: 'Check your real level',
      focus: `Answer the level check for ${primary.name} so training starts exactly where you are, not where a guess put you.`,
      moveOnWhen: 'Done once. Repeat it whenever you believe you have moved up.',
    });
  }
  for (const level of [primary.startLevel, primary.startLevel + 1]) {
    const r = row(primary.goal, level);
    if (!r) continue;
    steps.push({ title: `${primary.name}, Level ${level}: ${r.title}`, focus: r.practice.join('. '), moveOnWhen: r.advance_when });
  }
  if (!steps.some((s) => s.title.startsWith(primary.name))) {
    steps.push({
      title: `${primary.name}, Level ${primary.startLevel}`,
      focus: `${primary.sessionsPerWeek} sessions a week at your level, adding a little each week.`,
      moveOnWhen: 'Your sessions feel controlled at the top of every rep range.',
    });
  }
  for (const g of rest.filter((x) => x.status === 'active')) {
    const r = row(g.goal, g.startLevel);
    steps.push({
      title: `Alongside: ${g.name}, Level ${g.startLevel}`,
      focus: r ? r.practice.join('. ') : `The minimum that keeps ${g.name} moving while the main goal leads.`,
      moveOnWhen: r ? r.advance_when : 'Keep it steady while the main goal leads.',
    });
  }
  for (const g of rest.filter((x) => x.status === 'queued')) {
    steps.push({
      title: `Add ${g.name}`,
      focus: `Starts at Level ${g.startLevel} with the basics of ${g.name}, building on the base you have made.`,
      moveOnWhen: `Unlocks when ${g.unlockWhen}.`,
    });
  }
  return {
    intro: `${plan.phase.why} Each step comes from the Levlofit curriculum. You move on by passing its check, not by the calendar.`,
    steps,
  };
}
