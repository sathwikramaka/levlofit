// Usage: node tools/coach_actions_api_check.mjs <throwaway stack scratch dir with key.env and test-users.txt>
// THROWAWAY ONLY: talks to 127.0.0.1:54326 (levlo_phone_2i) as memcheck@test.local; needs the synthetic catalogue rows.
// Synthetic API check of coach actions and chat summaries against the THROWAWAY stack only (Kong 127.0.0.1:54326).
// Reads the publishable key and the synthetic password from the scratch files; prints neither.
import { readFileSync } from 'node:fs';

const DIR = process.argv[2];
const BASE = 'http://127.0.0.1:54326';
const env = readFileSync(`${DIR}/key.env`, 'utf8');
const KEY = (env.match(/(?:ANON|PUBLISHABLE)[A-Z_]*=\s*(\S+)/) ?? env.match(/=\s*(\S+)/))[1];
const PW = readFileSync(`${DIR}/test-users.txt`, 'utf8').split('\n').map((l) => l.trim()).filter((l) => l.startsWith('memcheck@test.local ')).pop().split(' ')[1];

const results = [];
const check = (id, ok, evidence) => { results.push({ id, status: ok ? 'PASS' : 'FAIL', evidence }); };

async function call(path, { method = 'GET', body, token, headers = {} } = {}) {
  const res = await fetch(`${BASE}${path}`, {
    method, body: body === undefined ? undefined : JSON.stringify(body),
    headers: { apikey: KEY, 'Content-Type': 'application/json', ...(token ? { Authorization: `Bearer ${token}` } : {}), ...headers },
  });
  const text = await res.text();
  let json = null;
  try { json = text ? JSON.parse(text) : null; } catch { /* not json */ }
  return { status: res.status, json };
}

const signIn = await call('/auth/v1/token?grant_type=password', { method: 'POST', body: { email: 'memcheck@test.local', password: PW } });
if (signIn.status !== 200) { console.log(JSON.stringify({ fatal: 'sign-in failed', status: signIn.status })); process.exit(1); }
const T = signIn.json.access_token;
const uid = signIn.json.user.id;
const chat = (body) => call('/functions/v1/coach-chat', { method: 'POST', body, token: T });
const rest = (path, opts = {}) => call(`/rest/v1/${path}`, { token: T, ...opts });

const day = new Date().toISOString().slice(0, 10);
const plus = (n) => new Date(Date.parse(`${day}T00:00:00Z`) + n * 864e5).toISOString().slice(0, 10);
const sunday = 6 - ((new Date(`${day}T00:00:00Z`).getUTCDay() + 6) % 7);
const restDays = Array.from({ length: sunday }, (_, i) => plus(i + 1));
const today = { day, ids: ['qXTaZnJ', 'EIeI8Vf', 'fUBheHs', 'wQ2c4XD', 'iny3m5y'], restDays };

// 1 swap: proposal only, then Not now, then confirm.
let r = await chat({ message: 'Can I swap the squat today?', today });
const swap1 = r.json?.swap;
let rows = (await rest(`exercise_swaps?select=id,status,from_exercise,to_exercise&id=eq.${swap1?.id ?? 0}`)).json ?? [];
check('swap: proposal card, line hidden, stored unconfirmed', r.status === 200 && swap1 && !/SWAP:/.test(r.json.reply) && rows[0]?.status === 'proposed',
  `${r.status}; ${swap1 ? `${swap1.from.name} -> ${swap1.to.name}` : 'no swap'}; row ${rows[0]?.status ?? 'none'}`);
const del = await rest(`exercise_swaps?id=eq.${swap1?.id ?? 0}`, { method: 'DELETE', headers: { Prefer: 'return=representation' } });
rows = (await rest(`exercise_swaps?select=id&id=eq.${swap1?.id ?? 0}`)).json ?? [];
check('swap: Not now deletes the proposal, nothing confirmed', del.status === 200 && rows.length === 0, `delete ${del.status}; remaining ${rows.length}`);
r = await chat({ message: 'Please swap the squat', today });
const swap2 = r.json?.swap;
const conf = await chat({ confirmSwap: swap2?.id ?? 0 });
rows = (await rest(`exercise_swaps?select=status&id=eq.${swap2?.id ?? 0}`)).json ?? [];
check('swap: Swap confirms on the server', conf.status === 200 && conf.json?.swapped === true && rows[0]?.status === 'confirmed', `confirm ${conf.status}; row ${rows[0]?.status ?? 'none'}`);

// 2 ownership and bypass attempts.
const ins = await rest('exercise_swaps', { method: 'POST', body: { user_id: uid, day, from_exercise: 'iny3m5y', to_exercise: 'QChZi3x' } });
const upd = await rest(`exercise_swaps?id=eq.${swap2?.id ?? 0}`, { method: 'PATCH', body: { to_exercise: 'LIlE5Tn' } });
const insCh = await rest('session_changes', { method: 'POST', body: { user_id: uid, day, kind: 'lighter' } });
check('ownership: app cannot insert or edit swaps or session changes', [ins.status, upd.status, insCh.status].every((s) => s === 401 || s === 403),
  `insert swap ${ins.status}, update swap ${upd.status}, insert change ${insCh.status}`);
const anon = await call('/rest/v1/exercise_swaps?select=id', {});
check('ownership: signed-out read returns nothing', anon.status === 401 || (anon.status === 200 && (anon.json ?? []).length === 0), `anon ${anon.status}, rows ${(anon.json ?? []).length ?? '-'}`);
const missing = await chat({ confirmSwap: 999999999 });
const bad = await chat({ confirmSwap: '1' });
const missingCh = await chat({ confirmChange: 999999999 });
check('failure: unknown or malformed confirms write nothing', missing.status === 404 && bad.status === 400 && missingCh.status === 404,
  `unknown swap ${missing.status}, malformed ${bad.status}, unknown change ${missingCh.status}`);

// 3 lighter day, and the pain guard.
r = await chat({ message: 'I am tired today, can we take it easy?', today });
const lighter = r.json?.change;
const confL = await chat({ confirmChange: lighter?.id ?? 0 });
check('lighter: proposed, then confirmed on the server', r.status === 200 && lighter?.kind === 'lighter' && !/LIGHTER/.test(r.json.reply) && confL.json?.changed === true,
  `${r.status}; change ${lighter?.kind ?? 'none'}; confirm ${confL.status}`);
r = await chat({ message: 'I have chest pain, can we take it easy?', today });
check('lighter: never offered when the message mentions pain', r.status === 200 && !r.json?.change, `${r.status}; change ${r.json?.change ? 'offered' : 'none'}`);

// 4 move to a later free day.
if (restDays.length) {
  r = await chat({ message: 'No time today, can I move my session?', today });
  const mv = r.json?.change;
  const confM = await chat({ confirmChange: mv?.id ?? 0 });
  check('move: proposed for a later free day, then confirmed', r.status === 200 && mv?.kind === 'move' && restDays.includes(mv.toDay) && confM.json?.changed === true,
    `${r.status}; to ${mv?.toDay ?? 'none'}; confirm ${confM.status}`);
} else results.push({ id: 'move', status: 'BLOCKED', evidence: 'Sunday: no later day this week' });

// 5 meal logging from the person's own diary.
const foods = (await rest('foods?select=code,name,tags&limit=200')).json ?? [];
const ok = foods.find((f) => !(f.tags ?? []).some((t) => ['beef', 'pork', 'meat', 'poultry', 'fish', 'shellfish', 'egg'].includes(t)));
const add = await rest('food_log', { method: 'POST', body: { day, meal: 'breakfast', food_code: ok.code, grams: 50 }, headers: { Prefer: 'return=minimal' } });
const before = ((await rest(`food_log?select=id&day=eq.${day}`)).json ?? []).length;
r = await chat({ message: 'Log my lunch please', today });
const meal = r.json?.meal;
const after = ((await rest(`food_log?select=id&day=eq.${day}`)).json ?? []).length;
check('meal: proposal from own diary foods; server writes nothing', add.status === 201 && meal?.items?.[0]?.code === ok.code && after === before && !/MEAL:/.test(r.json.reply),
  `diary add ${add.status}; proposal ${meal ? `${meal.meal} ${meal.items.map((i) => `${i.code} ${i.grams} g`).join(', ')}` : 'none'}; diary ${before} -> ${after}`);
const logIt = await rest('food_log', { method: 'POST', body: meal ? meal.items.map((i) => ({ day, meal: meal.meal, food_code: i.code, grams: i.grams })) : [], headers: { Prefer: 'return=minimal' } });
const final = ((await rest(`food_log?select=id&day=eq.${day}`)).json ?? []).length;
check('meal: Log it writes the diary entry (as the app does)', logIt.status === 201 && final === after + (meal?.items.length ?? 0), `log ${logIt.status}; diary ${after} -> ${final}`);

// 6 chat summary on the longest existing synthetic thread.
const threads = (await rest('coach_threads?select=id,summary').json) ?? (await rest('coach_threads?select=id,summary')).json;
let target = null, most = -1;
for (const t of threads) {
  const n = ((await rest(`coach_messages?select=id&thread_id=eq.${t.id}`)).json ?? []).length;
  if (n > most) { most = n; target = t.id; }
}
let summary = null, sends = 0;
while (!summary && sends < 8) {
  await chat({ message: `Quick check-in ${sends + 1}, all fine.`, threadId: target });
  sends++;
  summary = ((await rest(`coach_threads?select=summary&id=eq.${target}`)).json ?? [])[0]?.summary ?? null;
}
const msgs = await rest(`coach_messages?select=id&thread_id=eq.${target}`);
check('summary: a long chat gets a stored summary', !!summary, `thread had ${most} messages; ${sends} sends; summary ${summary ? `${summary.length} chars` : 'none'}; now ${(msgs.json ?? []).length} messages`);

for (const x of results) console.log(`${x.status}  ${x.id}  (${x.evidence})`);
console.log(JSON.stringify({ day, restDays, uidPrefix: uid.slice(0, 8), foodCode: ok?.code, swapIds: [swap1?.id, swap2?.id], summaryThread: target?.slice(0, 8) }));
