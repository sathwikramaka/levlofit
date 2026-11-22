// Protocol changes Levlofit AI may propose (B5, widened 2026-11-14 on the owner's request: "any protocol"): every
// Protocol setting, the protein powder kind, and supplements added or removed. Pure functions; coach-chat does the I/O.
// Settings the plan is built from run through the plan engine first, on the inputs of the latest plan, so the engine's
// own rules (medical hold, pregnancy, underweight, high BMI) decide what may be offered; calories, protein and days come
// from its preview. The model only names the setting and the value, and nothing changes until the person confirms.
import suppData from './supplements.json' with { type: 'json' };
import {
  ACTIVITY, type Activity, type Diet, DIETS, type Equipment, generatePlan, type Pace, PACES, type PlanInput, TRAINING_TIMES, type TrainingTime,
  validateInput, type WeightGoal, WEIGHT_GOALS,
} from './plan-engine.ts';

export type PlanField =
  | 'weight_goal' | 'diet_pace' | 'days_per_week' | 'session_minutes' | 'equipment' | 'daily_activity' | 'diet_type' | 'training_time'
  | 'budget_tier' | 'cook_time' | 'water_target_ml' | 'protein_powder' | 'supplement_add' | 'supplement_remove';
export type PlanPreview = { weightGoal: string; energyKcal: number; proteinG: number; trainingDaysPerWeek: number };
export type PlanCheck =
  | { ok: true; field: PlanField; value: string; from: string | null; preview: PlanPreview | null }
  | { ok: false; reason: 'unknown' | 'unchanged' | 'invalid' | 'pace_needs_cut_or_bulk' | 'engine_overrides' | 'medical_hold' | 'diet_conflict'; detail?: string };
/** The person's settings rows, for the settings the plan input does not hold. */
export type SettingsRows = { profile?: Record<string, unknown> | null; diet?: Record<string, unknown> | null };

const SUPPS = (suppData as unknown as { items: { id: string; name: string; aliases: string[] }[] }).items;
export const POWDERS = ['whey', 'plant', 'yeast', 'soy', 'pea', 'egg'] as const;
const WATER = ['auto', '1500', '2000', '2500', '3000', '3500', '4000', '4500', '5000'];
const ENGINE_LISTED = ['weight_goal', 'pace', 'days'];

type Spec = {
  field: PlanField;
  values: readonly string[];
  /** The plan input with the new value, for settings the engine reads; absent for the others. */
  engine?: (i: PlanInput, v: string) => PlanInput;
  now: (i: PlanInput, rows: SettingsRows) => string | null;
};
const str = (v: unknown) => (v == null ? null : String(v));
/** Field names as the model writes them. */
export const SPECS: Record<string, Spec> = {
  weight_goal: { field: 'weight_goal', values: WEIGHT_GOALS, engine: (i, v) => ({ ...i, weightGoal: v as WeightGoal }), now: (i) => i.weightGoal },
  pace: { field: 'diet_pace', values: PACES, engine: (i, v) => ({ ...i, pace: v as Pace }), now: (i) => i.pace ?? 'balanced' },
  days: { field: 'days_per_week', values: ['1', '2', '3', '4', '5', '6', '7'], engine: (i, v) => ({ ...i, daysPerWeek: Number(v) }), now: (i) => str(i.daysPerWeek) },
  minutes: { field: 'session_minutes', values: ['20', '30', '45', '60', '75', '90'], engine: (i, v) => ({ ...i, sessionMinutes: Number(v) }), now: (i) => str(i.sessionMinutes) },
  equipment: { field: 'equipment', values: ['none', 'home', 'gym'], engine: (i, v) => ({ ...i, equipment: v as Equipment, equipmentItems: undefined }), now: (i) => i.equipment ?? null },
  activity: { field: 'daily_activity', values: ACTIVITY, engine: (i, v) => ({ ...i, dailyActivity: v as Activity }), now: (i) => i.dailyActivity ?? null },
  diet: { field: 'diet_type', values: DIETS, engine: (i, v) => ({ ...i, diet: v as Diet }), now: (i) => i.diet },
  train_time: { field: 'training_time', values: TRAINING_TIMES, engine: (i, v) => ({ ...i, trainingTime: v as TrainingTime }), now: (i) => i.trainingTime ?? 'varies' },
  budget: { field: 'budget_tier', values: ['low', 'medium', 'high'], now: (_, r) => str(r.diet?.budget_tier) },
  cook_time: { field: 'cook_time', values: ['plenty', 'short', 'minimal'], now: (_, r) => str(r.diet?.cook_time) ?? 'plenty' },
  water: { field: 'water_target_ml', values: WATER, now: (_, r) => str(r.profile?.water_target_ml) ?? 'auto' },
  protein_powder: { field: 'protein_powder', values: POWDERS, now: (_, r) => str(r.diet?.protein_powder) },
  supplement_add: { field: 'supplement_add', values: SUPPS.map((s) => s.id), now: () => null },
  supplement_remove: { field: 'supplement_remove', values: SUPPS.map((s) => s.id), now: () => null },
};
const BY_FIELD = new Map(Object.values(SPECS).map((s) => [s.field, s]));

/** The model's proposal line, removed from the reply before it is shown. */
export const PLAN_LINE = new RegExp(`^\\s*PLAN:\\s*(${Object.keys(SPECS).join('|')})\\s*=\\s*([a-z0-9_]+)\\s*$`, 'gim');

// Asking to change any part of the protocol.
const PLAN_TALK = /\b(cut|cutting|bulk|bulking|recomp\w*|maintenance|maintain|lose (weight|fat)|gain (weight|muscle)|pace|slower|faster|too (hard|aggressive|slow|fast)|change|switch|replace|instead|update|edit|add|remove|drop|stop taking|protocol|settings?|more days|fewer days|less days|days a week|days per week|train (\d|one|two|three|four|five|six|seven|more|less|fewer)|minutes|shorter|longer|equipment|gym|vegan|vegetarian|eggitarian|non[- ]?veg\w*|budget|cook\w*|water|protein powder|whey|yeast|supplements?)\b/i;
export function isPlanChangeTalk(question: string, recentUserMessages: string[] = []): boolean {
  return [question, ...recentUserMessages.slice(0, 2)].some((t) => PLAN_TALK.test(t));
}

const medicalHold = (input: PlanInput) => (input.healthFlags ?? []).some((f) => f !== 'pregnancy');
const list = (v: unknown) => (Array.isArray(v) ? v.map(String) : []);
const norm = (s: string) => ` ${s.toLowerCase().replace(/[^a-z0-9]+/g, ' ').trim()} `;
/** The reference id a name in the person's own list stands for ("Vit D3 60k" -> vitamin_d): the longest alias wins. */
function idOf(typed: string): string | null {
  const t = norm(typed);
  let best: string | null = null, len = 0;
  for (const s of SUPPS) {
    for (const a of [s.name, ...s.aliases]) {
      const n = norm(a);
      if (n.trim() && t.includes(n) && n.length > len) [best, len] = [s.id, n.length];
    }
  }
  return best;
}
const planKey = (id: string) => (id === 'creatine' ? 'creatine' : id === 'whey' ? 'protein_powder' : null);

/** Whether reference supplement [id] is already in the person's lists (the plan's, or their own by name). */
export function hasSupplement(rows: SettingsRows, id: string): boolean {
  const s = SUPPS.find((x) => x.id === id);
  if (!s) return false;
  const pk = planKey(id);
  if (pk && list(rows.diet?.supplements).includes(pk)) return true;
  return list(rows.diet?.other_supplements).some((n) => idOf(n) === id);
}

/**
 * Whether [field] = [value] may be proposed for [stored] (generated_plans.input of the latest plan) and the person's
 * settings [rows], with the engine's preview for settings the plan is built from. Refused: unknown or unchanged
 * values; a pace without a cut or bulk; more training days or longer sessions during a medical hold; any body goal the
 * engine would itself change (it names why); adding a supplement already listed or removing one that is not.
 */
export function checkPlanChange(stored: unknown, field: string, value: string, rows: SettingsRows = {}): PlanCheck {
  let input: PlanInput;
  try {
    input = validateInput(stored);
  } catch {
    return { ok: false, reason: 'invalid' };
  }
  const spec = SPECS[field] ?? BY_FIELD.get(field as PlanField);
  if (!spec || !spec.values.includes(value)) return { ok: false, reason: 'unknown' };
  const f = spec.field;
  if (f === 'supplement_add' || f === 'supplement_remove') {
    return (f === 'supplement_add') !== hasSupplement(rows, value) ? { ok: true, field: f, value, from: null, preview: null } : { ok: false, reason: 'unchanged' };
  }
  const from = spec.now(input, rows);
  if (from === value) return { ok: false, reason: 'unchanged' };
  // A powder their diet rules out is never offered (whey is milk, egg protein is egg).
  if (f === 'protein_powder' && ((value === 'whey' && (input.diet === 'vegan' || input.restrictions.includes('lactose'))) ||
    (value === 'egg' && (input.diet === 'vegan' || input.diet === 'vegetarian' || input.restrictions.includes('egg'))) ||
    (value === 'soy' && input.restrictions.includes('soy')))) return { ok: false, reason: 'diet_conflict' };
  if (!spec.engine) return { ok: true, field: f, value, from, preview: null };
  // Medical hold: light activity only until a doctor clears it, so no extra training days or longer sessions.
  const more = Number(value) > Number(from ?? 0);
  if (medicalHold(input) && (f === 'days_per_week' || f === 'session_minutes') && more) return { ok: false, reason: 'medical_hold' };
  let plan;
  try {
    plan = generatePlan(validateInput(spec.engine(input, value)));
  } catch {
    return { ok: false, reason: 'invalid' };
  }
  if (f === 'diet_pace' && plan.weightGoal !== 'cut' && plan.weightGoal !== 'bulk') return { ok: false, reason: 'pace_needs_cut_or_bulk' };
  if (f === 'weight_goal' && plan.weightGoal !== value) {
    const why = plan.review.find((r) => r.level === 'change' || r.level === 'stop');
    return { ok: false, reason: 'engine_overrides', detail: why?.title };
  }
  return {
    ok: true, field: f, value, from,
    preview: { weightGoal: plan.weightGoal, energyKcal: plan.nutrition.energyKcal, proteinG: plan.nutrition.proteinG, trainingDaysPerWeek: plan.trainingDaysPerWeek },
  };
}

/** The table and columns a confirmed change writes. Supplement changes are worked out from the current [rows]. */
export function settingWrite(field: PlanField, value: string, rows: SettingsRows = {}): { table: 'profiles' | 'dietary_profiles'; values: Record<string, unknown> } {
  switch (field) {
    case 'days_per_week':
    case 'session_minutes':
      return { table: 'profiles', values: { [field]: Number(value) } };
    case 'water_target_ml':
      return { table: 'profiles', values: { water_target_ml: value === 'auto' ? null : Number(value) } };
    case 'equipment':
      return { table: 'profiles', values: { equipment: value, equipment_items: [] } };
    case 'weight_goal':
    case 'daily_activity':
    case 'training_time':
      return { table: 'profiles', values: { [field]: value } };
    case 'budget_tier':
      return { table: 'dietary_profiles', values: { budget_tier: value, budget_min_inr: null, budget_max_inr: null } };
    case 'supplement_add':
    case 'supplement_remove': {
      const s = SUPPS.find((x) => x.id === value)!;
      const plan = list(rows.diet?.supplements), own = list(rows.diet?.other_supplements), pk = planKey(value);
      // ponytail: whey and creatine live in the plan list; adding them as plan items also turns their plan dose on.
      if (field === 'supplement_add') {
        return { table: 'dietary_profiles', values: pk ? { supplements: [...plan, pk] } : { other_supplements: [...own, s.name] } };
      }
      return { table: 'dietary_profiles', values: { supplements: plan.filter((p) => p !== pk), other_supplements: own.filter((n) => idOf(n) !== value) } };
    }
    default: // diet_pace, diet_type, cook_time, protein_powder
      return { table: 'dietary_profiles', values: { [field]: value } };
  }
}

/** Every goal, pace and days change that passes checkPlanChange, with the engine's preview. */
export function planOptions(stored: unknown): { field: string; value: string; preview: PlanPreview }[] {
  const out: { field: string; value: string; preview: PlanPreview }[] = [];
  for (const field of ENGINE_LISTED) {
    for (const v of SPECS[field].values) {
      const c = checkPlanChange(stored, field, v);
      if (c.ok && c.preview) out.push({ field, value: v, preview: c.preview });
    }
  }
  return out;
}

/** The changes the model may propose: goal, pace and days with the engine's numbers, then every other setting with
 * its allowed values on one line (kept short: the whole request has an 8K-token budget). */
export function planChangeBlock(stored: unknown, rows: SettingsRows = {}): string | null {
  let input: PlanInput;
  try {
    input = validateInput(stored);
  } catch {
    return null;
  }
  const lines: string[] = planOptions(stored).map((o) => `- ${o.field}=${o.value} -> ${JSON.stringify(o.preview)}`);
  for (const [name, spec] of Object.entries(SPECS)) {
    if (ENGINE_LISTED.includes(name)) continue;
    const ok = spec.values.filter((v) => checkPlanChange(stored, name, v, rows).ok);
    if (!ok.length) continue;
    const now = name.startsWith('supplement') ? null : spec.now(input, rows);
    lines.push(`- ${name}: ${ok.join(' | ')}${now ? ` (now ${now})` : ''}`);
  }
  if (!lines.length) return null;
  const now = { weight_goal: input.weightGoal, pace: input.pace ?? 'balanced', days: input.daysPerWeek ?? null };
  return `PLAN CHANGES THAT PASS THE APP'S CHECKS (current: ${JSON.stringify(now)}; goal, pace and days with what the plan engine would set; supplement ids: ${SUPPS.map((x) => `${x.id}=${x.name}`).join(', ')}):\n${lines.join('\n')}`;
}

/** The person's words for a refused confirm. */
export const PLAN_REFUSAL: Record<Exclude<PlanCheck, { ok: true }>['reason'], string> = {
  unknown: 'This change is not available.',
  unchanged: 'Your plan already uses this setting.',
  invalid: 'Your plan details could not be checked. Rebuild your plan from Protocol, then try again.',
  pace_needs_cut_or_bulk: 'A pace only applies while cutting or bulking.',
  engine_overrides: 'Your plan\'s safety checks would not use this goal, so it was not changed.',
  medical_hold: 'Your plan stays light until a doctor clears you, so more training was not added.',
  diet_conflict: 'Your diet settings rule this out, so it was not changed.',
};
