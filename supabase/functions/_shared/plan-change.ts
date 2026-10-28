// Plan changes Levlofit AI may propose (B5): body goal, diet pace, training days a week. Pure functions; coach-chat
// does the I/O. Every option is run through the plan engine first, on the inputs the latest plan was built from, so
// the engine's own rules (medical hold, pregnancy, underweight, high BMI) decide what may be offered. Calories,
// protein and the rest come from the engine's preview; the model only names the setting and its value.
import { generatePlan, type Pace, PACES, type PlanInput, validateInput, type WeightGoal, WEIGHT_GOALS } from './plan-engine.ts';

export type PlanField = 'weight_goal' | 'diet_pace' | 'days_per_week';
export type PlanPreview = { weightGoal: string; energyKcal: number; proteinG: number; trainingDaysPerWeek: number };
export type PlanCheck =
  | { ok: true; field: PlanField; value: string; from: string | null; preview: PlanPreview }
  | { ok: false; reason: 'unknown' | 'unchanged' | 'invalid' | 'pace_needs_cut_or_bulk' | 'engine_overrides' | 'medical_hold'; detail?: string };

/** The model's proposal line, removed from the reply before it is shown. Field names as the model writes them. */
export const PLAN_LINE = /^\s*PLAN:\s*(weight_goal|pace|days)\s*=\s*([a-z0-9_]+)\s*$/gim;
const FIELD: Record<string, PlanField> = { weight_goal: 'weight_goal', pace: 'diet_pace', days: 'days_per_week' };

// Asking to change the plan's body goal, pace or training days.
const PLAN_TALK = /\b(cut|cutting|bulk|bulking|recomp\w*|maintenance|maintain|lose (weight|fat)|gain (weight|muscle)|pace|slower|faster|too (hard|aggressive|slow|fast)|change (my )?(plan|goal|target)|switch (to|my)|more days|fewer days|less days|days a week|days per week|train (\d|one|two|three|four|five|six|seven|more|less|fewer))\b/i;
export function isPlanChangeTalk(question: string, recentUserMessages: string[] = []): boolean {
  return [question, ...recentUserMessages.slice(0, 2)].some((t) => PLAN_TALK.test(t));
}

const current = (input: PlanInput, field: PlanField): string | null =>
  field === 'weight_goal' ? input.weightGoal : field === 'diet_pace' ? (input.pace ?? 'balanced') : input.daysPerWeek == null ? null : String(input.daysPerWeek);

const medicalHold = (input: PlanInput) => (input.healthFlags ?? []).some((f) => f !== 'pregnancy');

/**
 * Whether [field] = [value] may be proposed for [stored] (generated_plans.input of the latest plan), and the engine's
 * preview if so. Refused: unknown or unchanged values; a pace without a cut or bulk; more training days during a
 * medical hold; any body goal the engine would itself change (it names why).
 */
export function checkPlanChange(stored: unknown, field: string, value: string): PlanCheck {
  let input: PlanInput;
  try {
    input = validateInput(stored);
  } catch {
    return { ok: false, reason: 'invalid' };
  }
  const f = FIELD[field] ?? (Object.values(FIELD).includes(field as PlanField) ? (field as PlanField) : null);
  if (!f) return { ok: false, reason: 'unknown' };
  const from = current(input, f);
  if (from === value) return { ok: false, reason: 'unchanged' };
  let next: PlanInput;
  if (f === 'weight_goal') {
    if (!(WEIGHT_GOALS as readonly string[]).includes(value)) return { ok: false, reason: 'unknown' };
    next = { ...input, weightGoal: value as WeightGoal };
  } else if (f === 'diet_pace') {
    if (!(PACES as readonly string[]).includes(value)) return { ok: false, reason: 'unknown' };
    next = { ...input, pace: value as Pace };
  } else {
    const days = Number(value);
    if (!/^[1-7]$/.test(value)) return { ok: false, reason: 'unknown' };
    // Medical hold: light activity only until a doctor clears it, so no extra training days.
    if (medicalHold(input) && days > (input.daysPerWeek ?? 0)) return { ok: false, reason: 'medical_hold' };
    next = { ...input, daysPerWeek: days };
  }
  let plan;
  try {
    plan = generatePlan(validateInput(next));
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

/** Every change that passes checkPlanChange, for the model to choose from. */
export function planOptions(stored: unknown): { field: string; value: string; preview: PlanPreview }[] {
  const out: { field: string; value: string; preview: PlanPreview }[] = [];
  for (const [field, values] of [['weight_goal', WEIGHT_GOALS], ['pace', PACES], ['days', ['1', '2', '3', '4', '5', '6', '7']]] as const) {
    for (const v of values) {
      const c = checkPlanChange(stored, field, v);
      if (c.ok) out.push({ field, value: v, preview: c.preview });
    }
  }
  return out;
}

export function planChangeBlock(stored: unknown): string | null {
  const options = planOptions(stored);
  if (!options.length) return null;
  let input: PlanInput;
  try {
    input = validateInput(stored);
  } catch {
    return null;
  }
  const now = { weight_goal: input.weightGoal, pace: input.pace ?? 'balanced', days: input.daysPerWeek ?? null };
  return `PLAN CHANGES THAT PASS THE APP'S CHECKS (current: ${JSON.stringify(now)}; each with what the plan engine would set):\n${options.map((o) => `- ${o.field}=${o.value} -> ${JSON.stringify(o.preview)}`).join('\n')}`;
}

/** The person's words for a refused confirm. */
export const PLAN_REFUSAL: Record<Exclude<PlanCheck, { ok: true }>['reason'], string> = {
  unknown: 'This change is not available.',
  unchanged: 'Your plan already uses this setting.',
  invalid: 'Your plan details could not be checked. Rebuild your plan from Protocol, then try again.',
  pace_needs_cut_or_bulk: 'A pace only applies while cutting or bulking.',
  engine_overrides: 'Your plan\'s safety checks would not use this goal, so it was not changed.',
  medical_hold: 'Your plan stays light until a doctor clears you, so more training days were not added.',
};
