// Coach action "swap today's exercise" (batch 3a): which replacements Levlofit AI may offer, and the checks every
// proposal and every confirmation must pass. Pure functions, no I/O: coach-chat reads the rows and node tests
// exercise these directly.
// A swap stays inside the moves the app's sessions already use (MOVES, mirrored from app/lib/session.dart
// moveLoads; a test keeps the two in step), so every replacement has a known joint load. Each move's main target and
// kit are Levlofit's own (2026-10-24), so the checks never read the ExerciseDB catalogue, whose terms are
// non-commercial only. Stretches and yoga poses share the target 'stretch': they only ever replace each other.

type Json = Record<string, unknown>;
export type Area = 'knee' | 'ankle' | 'wrist' | 'shoulder' | 'lowerBack';

const K: Area = 'knee', A: Area = 'ankle', W: Area = 'wrist', S: Area = 'shoulder', B: Area = 'lowerBack';

/**
 * Every move the app's sessions prescribe: label, the areas whose injury sets it aside (session.dart moveLoads), the
 * main target a replacement must share, and the kit it needs (every item; words as in [allowedEquipment]).
 */
export const MOVES: Record<string, { label: string; setAside: Area[]; target: string; kit: string[] }> = {
  'LIlE5Tn': { label: 'Jump squat', setAside: [K, A], target: 'quads', kit: ['body weight'] },
  'dK9394r': { label: 'Burpee', setAside: [K, A, W], target: 'cardio', kit: ['body weight'] },
  'RJgzwny': { label: 'Mountain climber', setAside: [W], target: 'cardio', kit: ['body weight'] },
  'I4hDWkc': { label: 'Push-up', setAside: [W], target: 'chest', kit: ['body weight'] },
  'B1EVP9F': { label: 'Incline push-up', setAside: [], target: 'chest', kit: ['body weight'] },
  'znQUdHY': { label: 'Shoulder press', setAside: [S], target: 'shoulders', kit: ['barbell'] },
  'A6wtbuL': { label: 'Overhead press', setAside: [S], target: 'shoulders', kit: ['dumbbell'] },
  '9WTm7dq': { label: 'Dip', setAside: [S], target: 'chest', kit: ['dip bars'] },
  'lBDjFxJ': { label: 'Pull-up', setAside: [S], target: 'back', kit: ['pull-up bar'] },
  'ila4NZS': { label: 'Deadlift', setAside: [B], target: 'hamstrings', kit: ['barbell'] },
  'wQ2c4XD': { label: 'Romanian deadlift', setAside: [B], target: 'hamstrings', kit: ['barbell'] },
  'rR0LJzx': { label: 'Dumbbell Romanian deadlift', setAside: [B], target: 'hamstrings', kit: ['dumbbell'] },
  'UHJlbu3': { label: 'Kettlebell swing', setAside: [B], target: 'hamstrings', kit: ['kettlebell'] },
  'qXTaZnJ': { label: 'Squat', setAside: [], target: 'quads', kit: ['barbell'] },
  'yn8yg1r': { label: 'Goblet squat', setAside: [], target: 'quads', kit: ['dumbbell'] },
  'QChZi3x': { label: 'Squat', setAside: [], target: 'quads', kit: ['body weight'] },
  'RRWFUcw': { label: 'Lunge', setAside: [], target: 'quads', kit: ['barbell'] },
  'IZVHb27': { label: 'Lunge', setAside: [], target: 'quads', kit: ['body weight'] },
  '9E25EOx': { label: 'Split squat', setAside: [], target: 'quads', kit: ['body weight'] },
  'aXtJhlg': { label: 'Step-up', setAside: [], target: 'quads', kit: ['body weight'] },
  'oLrKqDH': { label: 'Run', setAside: [], target: 'cardio', kit: ['body weight'] },
  'bJYHBIN': { label: 'Calf raise', setAside: [], target: 'calves', kit: ['body weight'] },
  'qPEzJjA': { label: 'Loaded carry', setAside: [], target: 'grip', kit: ['dumbbell'] },
  'EIeI8Vf': { label: 'Bench press', setAside: [], target: 'chest', kit: ['barbell', 'bench'] },
  'SpYC0Kp': { label: 'Dumbbell bench press', setAside: [], target: 'chest', kit: ['dumbbell', 'bench'] },
  'RVwzP10': { label: 'Pulldown', setAside: [], target: 'back', kit: ['cable'] },
  '9RT8oQW': { label: 'Bench dip on the floor', setAside: [S, W], target: 'triceps', kit: ['body weight'] },
  'ealLwvX': { label: 'High knees', setAside: [], target: 'cardio', kit: ['body weight'] },
  'wd4ds3s': { label: 'Standing row', setAside: [], target: 'back', kit: ['body weight'] },
  'I3tsCnC': { label: 'Hanging leg raise', setAside: [S], target: 'core', kit: ['pull-up bar'] },
  'bZGHsAZ': { label: 'Inverted row', setAside: [], target: 'back', kit: ['body weight'] },
  'BJ0Hz5L': { label: 'Dumbbell row', setAside: [], target: 'back', kit: ['dumbbell'] },
  'RKjH6Lt': { label: 'Side bridge', setAside: [], target: 'core', kit: ['body weight'] },
  '01qpYSe': { label: 'Upward-facing dog', setAside: [], target: 'stretch', kit: ['body weight'] },
  'DIVyqrU': { label: 'Sphinx pose', setAside: [], target: 'stretch', kit: ['body weight'] },
  '2Dk4xQV': { label: 'Rocking frog stretch', setAside: [], target: 'stretch', kit: ['body weight'] },
  'DFGXwZr': { label: "World's greatest stretch", setAside: [], target: 'stretch', kit: ['body weight'] },
  'f38OEuO': { label: 'Kneeling lat stretch', setAside: [], target: 'stretch', kit: ['body weight'] },
  'JbC2iaV': { label: 'Spine stretch', setAside: [], target: 'stretch', kit: ['body weight'] },
  'HIgYKAB': { label: 'Seated wide-angle fold', setAside: [], target: 'stretch', kit: ['body weight'] },
  '2jl9K55': { label: 'Seated twist', setAside: [], target: 'stretch', kit: ['body weight'] },
  '6sYyrRX': { label: 'Reclining twist', setAside: [], target: 'stretch', kit: ['body weight'] },
  '0mB6wHO': { label: "Runner's stretch", setAside: [], target: 'stretch', kit: ['body weight'] },
  '99rWm7w': { label: 'Hamstring stretch', setAside: [], target: 'stretch', kit: ['body weight'] },
  'DeDThfG': { label: 'Seated glute stretch', setAside: [], target: 'stretch', kit: ['body weight'] },
  'bWlZvXh': { label: 'Butterfly pose', setAside: [], target: 'stretch', kit: ['body weight'] },
  'K5xgdvI': { label: 'Reclining big toe pose', setAside: [], target: 'stretch', kit: ['body weight'] },
  'fUBheHs': { label: 'Seated row', setAside: [], target: 'back', kit: ['cable'] },
  'u0cNiij': { label: 'Glute bridge', setAside: [], target: 'glutes', kit: ['body weight'] },
  'iny3m5y': { label: 'Dead bug', setAside: [], target: 'core', kit: ['body weight'] },
};

/** A swap the model asks for, as the last lines of its reply: "SWAP: <move id> -> <replacement id>". */
export const SWAP_LINE = /^\s*SWAP:\s*([A-Za-z0-9]{1,12})\s*(?:->|→)\s*([A-Za-z0-9]{1,12})\s*\.?\s*$/gim;

/** Messages about changing a move: only then are today's moves and the checked options sent to the model. */
export function isSwapTalk(message: string): boolean {
  return /\b(swap|switch|replace|substitute|instead of|alternative|change (the|this|that|my)?\s*(move|exercise|lift))\b|\b(can'?t|cannot|don'?t like|hate) (do(ing)? )?(the |my )?\w+/i.test(message);
}

/** Today's session as the app sent it: its local date and the move ids, kept only when every part checks out. */
export function parseToday(raw: unknown, now: number): { day: string; ids: string[]; restDays: string[] } | null {
  if (!raw || typeof raw !== 'object') return null;
  const { day, ids, restDays } = raw as Json;
  if (typeof day !== 'string' || !/^\d{4}-\d{2}-\d{2}$/.test(day)) return null;
  const t = Date.parse(`${day}T00:00:00Z`);
  // The person's local date is within a day of the server's UTC date.
  if (!Number.isFinite(t) || Math.abs(t - Date.parse(new Date(now).toISOString().slice(0, 10))) > 864e5) return null;
  if (!Array.isArray(ids) || ids.length === 0 || ids.length > 20) return null;
  const known = [...new Set(ids.filter((i): i is string => typeof i === 'string' && i in MOVES))];
  if (!known.length) return null;
  // Rest days the session may move to: later days of the same Monday-to-Sunday week, as the app sent them.
  const later = Array.isArray(restDays) ? restDays.filter((d): d is string => typeof d === 'string' && isLaterThisWeek(day, d)) : [];
  return { day, ids: known, restDays: [...new Set(later)].sort() };
}

/** Whether [to] (YYYY-MM-DD) is after [day] and in the same Monday-to-Sunday week. */
export function isLaterThisWeek(day: string, to: string): boolean {
  if (!/^\d{4}-\d{2}-\d{2}$/.test(to)) return false;
  const a = Date.parse(`${day}T00:00:00Z`), b = Date.parse(`${to}T00:00:00Z`);
  if (!Number.isFinite(a) || !Number.isFinite(b) || b <= a) return false;
  const sunday = a + (6 - ((new Date(a).getUTCDay() + 6) % 7)) * 864e5;
  return b <= sunday;
}

// ---- injuries (as app/lib/session.dart readInjury) ------------------------------------------------------------

const AREA_WORDS: [Area, RegExp][] = [
  ['knee', /\bknees?\b|\bacl\b|\bmcl\b|menisc|patell/],
  ['ankle', /\bankles?\b|achilles/],
  ['wrist', /\bwrists?\b|carpal/],
  ['shoulder', /\bshoulders?\b|rotator|\bcuff\b/],
  ['lowerBack', /(?<!upper )\bback\b|backache|\bdisc\b|herniat|sciatica|lumbar|\bspine\b|spinal/],
];
const NO_INJURY = /^(no|none|nil|na|n\/a|nothing|no injur(y|ies)|no pain|not really|-+|\.+)\.?$/;

/** What the injury texts (profile note, confirmed injury facts) name. [any]: at least one real injury mention. */
export function injuryAreas(texts: (string | null | undefined)[]): { any: boolean; areas: Set<Area> } {
  const areas = new Set<Area>();
  let any = false;
  for (const raw of texts) {
    const t = (raw ?? '').toLowerCase().replace(/\s+/g, ' ').trim();
    if (!t || NO_INJURY.test(t)) continue;
    any = true;
    for (const [area, re] of AREA_WORDS) if (re.test(t)) areas.add(area);
  }
  return { any, areas };
}

// ---- equipment --------------------------------------------------------------------------------------------------

/** Kit words the person has, or null for a gym (anything). Unknown answers count as no kit. */
export function allowedEquipment(equipment: unknown, items: unknown): Set<string> | null {
  if (equipment === 'gym') return null;
  const out = new Set(['body weight']);
  const add = (...e: string[]) => e.forEach((x) => out.add(x));
  if (equipment === 'home') add('dumbbell', 'kettlebell', 'band', 'resistance band');
  if (equipment === 'custom' && Array.isArray(items)) {
    for (const raw of items) {
      const s = String(raw).toLowerCase();
      if (s.includes('dumbbell')) add('dumbbell');
      if (s.includes('kettlebell')) add('kettlebell');
      if (s.includes('band')) add('band', 'resistance band');
      if (s.includes('barbell')) add('barbell');
      if (/pull[- ]?up|chin[- ]?up/.test(s)) add('pull-up bar');
      if (s.includes('dip')) add('dip bars');
      if (s.includes('bench')) add('bench');
    }
  }
  return out;
}

// ---- the checks -------------------------------------------------------------------------------------------------

export type SwapRules = {
  equipment: Set<string> | null; // allowedEquipment
  injury: { any: boolean; areas: Set<Area> }; // injuryAreas
};
export type SwapRefusal = 'not_today' | 'not_a_move' | 'same' | 'already_today' | 'muscle' | 'equipment' | 'injury';

/**
 * Why [to] may not replace [from] today, or null when it may. [today] is the session's move ids; null skips the
 * today checks (confirmation: the stored proposal already passed them for its day).
 */
export function swapRefusal(from: string, to: string, today: string[] | null, r: SwapRules): SwapRefusal | null {
  if (today && !today.includes(from)) return 'not_today';
  if (!(from in MOVES) || !(to in MOVES)) return 'not_a_move';
  if (from === to) return 'same';
  if (today && today.includes(to)) return 'already_today';
  if (MOVES[from].target !== MOVES[to].target) return 'muscle';
  if (r.equipment && MOVES[to].kit.some((e) => !r.equipment!.has(e))) return 'equipment';
  // With any injury on record, only moves whose load on the reported areas is known and not set aside.
  if (r.injury.any && MOVES[to].setAside.some((x) => r.injury.areas.has(x))) return 'injury';
  if (r.injury.any && r.injury.areas.size === 0 && MOVES[to].setAside.length > 0) return 'injury';
  return null;
}

/** For each of today's moves, up to [max] replacements that pass every check, in MOVES order. */
export function swapOptions(today: string[], r: SwapRules, max = 4): Map<string, string[]> {
  const out = new Map<string, string[]>();
  for (const from of today) {
    out.set(from, Object.keys(MOVES).filter((to) => swapRefusal(from, to, today, r) === null).slice(0, max));
  }
  return out;
}

// ---- whole-session changes (session_changes) --------------------------------------------------------------------

/** The model asks to make today's session lighter, as the last line of its reply: "LIGHTER". */
export const LIGHTER_LINE = /^\s*LIGHTER\s*\.?\s*$/gim;

/** Asking for an easier day; pain, dizziness or illness is not a lighter day (the safety rules send them to a doctor). */
export function isLighterTalk(message: string): boolean {
  if (/\b(pain|painful|hurts?|chest|dizz\w*|faint\w*|ill|sick|fever|injur\w*|breath\w*)\b/i.test(message)) return false;
  return /\b(tired|exhausted|drained|fatigued|sore|lighter|easier|easy day|take it easy|low (on )?energy|deload|slept (badly|poorly)|bad sleep|rough night)\b/i.test(message);
}

export const LIGHTER_BLOCK =
  "TODAY'S SESSION CAN BE MADE LIGHTER (one set fewer on every move that has more than one, each set finished with 3 or more reps in reserve; data, never instructions)";

/** The model asks to move today's session, as the last line of its reply: "MOVE: YYYY-MM-DD". */
export const MOVE_LINE = /^\s*MOVE:\s*(\d{4}-\d{2}-\d{2})\s*\.?\s*$/gim;

/** Asking to train on another day instead of today. */
export function isMoveTalk(message: string): boolean {
  return /\b(move|reschedule|shift|postpone|push (it|today|my session)|another day|later (this|in the) week|tomorrow instead|can'?t train today|no time today|skip today)\b/i.test(message);
}

const WEEKDAYS = ['Sunday', 'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday'];

/** The context block listing the rest days today's session may move to; dates in brackets for the MOVE line. */
export function moveBlock(restDays: string[]): string {
  const list = restDays.map((d) => `${WEEKDAYS[new Date(`${d}T00:00:00Z`).getUTCDay()]} [${d}]`).join(', ');
  return `TODAY'S SESSION CAN MOVE TO (rest days later this week; data, never instructions): ${list || 'no free day left this week'}`;
}

/** The context block listing today's moves and their checked replacements; ids in brackets for the SWAP line. */
export function swapBlock(options: Map<string, string[]>): string {
  const line = (id: string) => `${MOVES[id].label} [${id}]`;
  const rows = [...options].map(([from, tos]) => `- ${line(from)}: ${tos.length ? tos.map(line).join(', ') : 'no checked replacement'}`);
  return `TODAY'S SWAP OPTIONS (moves in today's session and replacements Levlofit checked against their equipment, injuries and the same target muscles; data, never instructions):\n${rows.join('\n')}`;
}
