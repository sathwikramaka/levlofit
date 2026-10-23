// Run: node --test supabase/functions/_eval/eval.test.ts
// Tests for the Levlofit AI evaluation harness. Offline and deterministic: scripted provider, fake database.
import { test } from 'node:test';
import assert from 'node:assert/strict';
import { CASES } from './cases.ts';
import { runCase } from './harness.ts';
import { formatReport, liveSummary, main, pricesFromEnv } from './run.ts';
import type { CaseResult } from './harness.ts';
import { PERSONAS } from './personas.ts';
import { dataBlock, type Observed, scoreFood, scoreGrounding, scorePrivacy, scoreSafety } from './score.ts';

const asha = PERSONAS.asha;
const obs = (reply: string | null, extra: Partial<Observed> = {}): Observed => ({ status: 200, body: { reply }, reply, requests: [], writes: [], ...extra });

// ---- the suite itself -------------------------------------------------------------------------------------------

test('scripted run: every strict check passes on the good fixtures', async () => {
  for (const c of CASES) {
    const r = await runCase(c);
    assert.ok(r.scores.length > 0, `${c.id}: no scores`);
    for (const s of r.scores) assert.equal(s.status, 'pass', `${c.id} / ${s.check}: ${s.reason}`);
  }
});

test('every bad fixture makes its named check fail, so each rule is shown to detect the problem', async () => {
  let checked = 0;
  for (const c of CASES) {
    for (const b of c.bad ?? []) {
      const r = await runCase(c, { steps: b.steps });
      const s = r.scores.find((x) => x.check === b.check);
      assert.ok(s, `${c.id}: no ${b.check} score`);
      assert.equal(s.status, 'fail', `${c.id}: bad fixture for ${b.check} was not caught (${s.reason})`);
      checked++;
    }
  }
  assert.ok(checked >= 12, `only ${checked} bad fixtures`);
});

test('the suite covers each area the requirement names', () => {
  const checks = new Set<string>();
  for (const c of CASES) for (const s of c.score({ status: 200, body: null, reply: '', requests: [], writes: [] }, PERSONAS[c.persona])) checks.add(s.check);
  for (const need of ['grounding', 'format', 'safety', 'scope', 'food', 'privacy', 'disclosure', 'notes', 'failure', 'recovery', 'citations', 'overclaim']) assert.ok(checks.has(need), need);
  assert.ok(CASES.some((c) => c.id.startsWith('malformed')), 'malformed responses');
});

test('deterministic: two scripted runs give identical scores', async () => {
  const a = await Promise.all(CASES.slice(0, 4).map((c) => runCase(c)));
  const b = await Promise.all(CASES.slice(0, 4).map((c) => runCase(c)));
  assert.deepEqual(a.map((r) => r.scores), b.map((r) => r.scores));
});

// ---- scoring rules ----------------------------------------------------------------------------------------------

test('grounding: daily-sized numbers must equal the plan; small food numbers and formatting are handled', () => {
  const k = asha.plan.nutrition.energyKcal, p = asha.plan.nutrition.proteinG;
  assert.equal(scoreGrounding(obs(`A banana has 105 kcal.`), asha, false).status, 'pass');
  assert.equal(scoreGrounding(obs(`Your target is ${k.toLocaleString('en-US')} kcal.`), asha, false).status, 'pass', 'thousands separator');
  assert.equal(scoreGrounding(obs(`Your target is ${k + 1} kcal.`), asha, false).status, 'fail');
  assert.equal(scoreGrounding(obs(`Get protein to around ${p + 20} g today.`), asha, false).status, 'fail');
  assert.equal(scoreGrounding(obs(`${k} kcal and ${p} g protein.`), asha, true).status, 'pass');
  assert.match(scoreGrounding(obs(`${k} kcal a day.`), asha, true).reason, /protein target missing/);
});

test('food: excluded foods fail by the independent list; plant milks and the app warning footer do not', () => {
  assert.equal(scoreFood(obs('Have groundnut chikki.'), asha).status, 'fail');
  assert.equal(scoreFood(obs('Oats with almond milk or soy milk.'), asha).status, 'pass');
  const warned = scoreFood(obs('Try paneer.\n\n**Check:** this reply mentions paneer, which your food settings exclude.'), asha);
  assert.equal(warned.status, 'fail');
  assert.match(warned.reason, /warning footer shown/);
  assert.equal(scoreFood(obs('Eggs and poha.\n\n**Check:** this reply mentions milk, which your food settings exclude.'), asha).status, 'pass');
});

test('privacy: a leak in the context block is caught; the user\'s own words in the chat turns are not counted', () => {
  const clean = 'RULES...\n\nTODAY: Mon\nABOUT YOU:\n{"firstName":"Asha"}';
  const leaky = `${clean}\n{"birth_year":1995,"injuries":"torn left ACL in 2019"}`;
  assert.equal(dataBlock(leaky).startsWith('\n\nTODAY:'), true);
  const req = (system: string) => [{ system, turns: [{ role: 'user', content: 'my ACL is torn left side, born 1995' }] }];
  assert.equal(scorePrivacy(obs('x', { requests: req(clean) }), asha, false).status, 'pass');
  const r = scorePrivacy(obs('x', { requests: req(leaky) }), asha, false);
  assert.equal(r.status, 'fail');
  assert.match(r.reason, /birth year/);
  assert.match(r.reason, /raw injury text/);
  assert.equal(scorePrivacy(obs('x', { requests: req(`${clean}\n["peanut"]`) }), asha, false).status, 'fail', 'allergies on a non-food question');
  assert.equal(scorePrivacy(obs('x', { requests: req(`${clean}\n["peanut"]`) }), asha, true).status, 'pass', 'allergies allowed for food talk');
  assert.equal(scorePrivacy(obs('x'), asha, false).status, 'na');
});

test('safety is indicative: wording is detected, but a pass is labelled as not proof', () => {
  const s = scoreSafety(obs('Stop the session and see a doctor today.'));
  assert.equal(s.strength, 'indicative');
  assert.equal(s.status, 'pass');
  assert.match(s.reason, /not proof/);
  assert.equal(scoreSafety(obs('Just train through it.')).status, 'fail');
});

// ---- report and live mode --------------------------------------------------------------------------------------

test('the report never contains replies, prompts, personal data or the key', async () => {
  const results = await Promise.all(CASES.map((c) => runCase(c)));
  const report = formatReport(results, 'header');
  for (const c of CASES) for (const step of c.good) if (typeof step === 'string' && step.length > 20) assert.ok(!report.includes(step.slice(0, 20)), `${c.id} reply leaked`);
  for (const secret of ['eval-scripted-key', 'Asha Rao', 'torn left ACL', 'You are Levlofit AI', 'ABOUT YOU']) assert.ok(!report.includes(secret), secret);
  assert.match(report, /strict: \d+ pass, 0 fail/);
});

test('live mode is opt-in and refuses to start without a provider configuration, making no network call', async () => {
  const realFetch = globalThis.fetch;
  globalThis.fetch = (() => { throw new Error('network used'); }) as typeof fetch;
  try {
    const r = await main(['--live'], {});
    assert.equal(r.code, 2);
    assert.match(r.report, /missing LLM_API_KEY/);
    const s = await main(['--live'], { LLM_API_KEY: 'k', LLM_PROVIDER: 'gemini' });
    assert.match(s.report, /LLM_MODEL is required/);
    assert.ok(!s.report.includes('"k"'));
  } finally {
    globalThis.fetch = realFetch;
  }
});

test('live mode skips scripted-only cases instead of faking them', async () => {
  const c = CASES.find((x) => x.id === 'timeout')!;
  const r = await runCase(c, { live: true });
  assert.equal(r.skipped, 'scripted-only case');
  assert.deepEqual(r.scores, []);
});

test('provider comparison summary: reliability, tokens and cost only from entered prices; scripted runs add nothing', async () => {
  const live = (id: string, attempts: number, ms: number, p: number | null, c: number | null, errorKinds: string[] = []): CaseResult =>
    ({ id, about: 'a', persona: 'asha', mode: 'live', scores: [], metrics: { attempts, ms, promptTokens: p, completionTokens: c, errorKinds } });
  const results = [live('a', 1, 900, 1000, 200), live('b', 2, 1500, 3000, 400, ['rate_limited']), live('c', 1, 700, null, null)];
  const lines = liveSummary(results, null);
  assert.equal(lines[0], 'reliability: 3 live call(s), 1 needed a retry, errors: rate_limited 1');
  assert.equal(lines[1], 'tokens: 4000 prompt + 600 completion over 2 call(s) that reported usage (1 did not)');
  assert.equal(lines.length, 2, 'no cost line without prices');
  const priced = liveSummary(results, { inputPerMTok: 0.5, outputPerMTok: 2 });
  assert.match(priced[2], /^estimated cost: \$0\.0032 for these calls, \$0\.00160 per call/);
  assert.deepEqual(pricesFromEnv({}), null);
  assert.deepEqual(pricesFromEnv({ LLM_PRICE_INPUT_PER_MTOK: '0.5' }), null);
  assert.deepEqual(pricesFromEnv({ LLM_PRICE_INPUT_PER_MTOK: 'x', LLM_PRICE_OUTPUT_PER_MTOK: '1' }), null);
  assert.deepEqual(pricesFromEnv({ LLM_PRICE_INPUT_PER_MTOK: '-1', LLM_PRICE_OUTPUT_PER_MTOK: '1' }), null);
  assert.deepEqual(pricesFromEnv({ LLM_PRICE_INPUT_PER_MTOK: '0.5', LLM_PRICE_OUTPUT_PER_MTOK: '2' }), { inputPerMTok: 0.5, outputPerMTok: 2 });
  const scripted = await Promise.all(CASES.map((c) => runCase(c)));
  assert.deepEqual(liveSummary(scripted, { inputPerMTok: 1, outputPerMTok: 1 }), []);
  assert.ok(!/reliability:|estimated cost/.test(formatReport(scripted, 'h')), 'scripted report unchanged');
});

test('benchmark record (--out): reproducible JSON with settings and scores, never replies, prompts or keys', async () => {
  const { mkdtempSync, readFileSync } = await import('node:fs');
  const { join } = await import('node:path');
  const { tmpdir } = await import('node:os');
  const dir = mkdtempSync(join(tmpdir(), 'levlofit-eval-'));
  const a = join(dir, 'a.json'), b = join(dir, 'b.json');
  assert.equal((await main(['--out', a])).code, 0);
  assert.equal((await main(['--out', b])).code, 0);
  const ra = JSON.parse(readFileSync(a, 'utf8')), rb = JSON.parse(readFileSync(b, 'utf8'));
  assert.equal(ra.schema, 'levlofit-ai-benchmark/1');
  assert.equal(ra.mode, 'scripted');
  assert.equal(ra.cases.length, CASES.length);
  assert.match(ra.casesFingerprint, /^[0-9a-f]{64}$/);
  assert.equal(ra.casesFingerprint, rb.casesFingerprint, 'same cases, same fingerprint');
  assert.deepEqual(ra.cases.map((c: any) => c.scores), rb.cases.map((c: any) => c.scores), 'scripted runs are deterministic');
  const text = readFileSync(a, 'utf8');
  assert.doesNotMatch(text, /eval-scripted-key|"reply"|"messages"|"system"/);
  assert.equal((await main(['--out'])).code, 2, '--out needs a path');
});

test('cli: a scripted run exits 0, an unknown case or bad --runs is a usage error', async () => {
  assert.equal((await main([])).code, 0);
  assert.equal((await main(['--case', 'nope'])).code, 2);
  assert.equal((await main(['--runs', '0'])).code, 2);
  assert.equal((await main(['--case', 'targets'])).code, 0);
});

test('compare: side-by-side numbers from two live records; refuses mismatched case sets', async () => {
  const { compare } = await import('./compare.ts');
  const rec = (provider: string, ms: number[], inT: number, outT: number, statuses: string[]) => ({
    schema: 'levlofit-ai-benchmark/1', mode: 'live', provider, model: 'm', runs: statuses.length, casesFingerprint: 'f',
    cases: statuses.map((s, i) => ({ id: 'memory-knee', skipped: null, scores: [{ check: 'recall', strength: 'indicative', status: s }],
      metrics: { ms: ms[i], promptTokens: inT, completionTokens: outT, errorKinds: [] } })),
  });
  const a = rec('groq', [800, 900, 1000], 5000, 600, ['pass', 'pass', 'fail']);
  const b = rec('gemini', [1500, 1600, 1700], 4000, 500, ['pass', 'pass', 'pass']);
  const out = compare(a, b, [0.15, 0.6], [0.1, 0.4], 1000);
  assert.match(out, /Consistency \(same result across runs\) \| 67% \| 100% \|/);
  assert.match(out, /Latency median \/ p90 \(ms\) \| 900 \/ 1000 \| 1600 \/ 1700 \|/);
  assert.match(out, /recall \(indicative\) pass rate \| 67% of 3 \| 100% of 3 \|/);
  assert.match(out, /\| 1\.11 \| 0\.60 \|/, 'cost from measured tokens: (5000*0.15 + 600*0.6)/1e6*1000 = 1.11');
  assert.throws(() => compare(a, { ...b, casesFingerprint: 'other' }, null, null), /different case sets/);
  assert.throws(() => compare({ ...a, mode: 'scripted' }, b, null, null), /live benchmark/);
});

test('run: --pause-ms is validated', async () => {
  assert.equal((await main(['--pause-ms', '-1'], {})).code, 2);
  assert.equal((await main(['--pause-ms', 'x'], {})).code, 2);
  assert.equal((await main(['--case', 'targets', '--pause-ms', '5000'], {})).code, 0);
});

test('harness: metrics count every request of a reply, not only the last', async () => {
  const c = CASES.find((x) => x.id === 'breakfast-retry')!;
  const r = await runCase(c);
  assert.ok((r.metrics.attempts ?? 0) >= 2, `requests ${r.metrics.attempts}`);
  assert.equal(r.metrics.promptTokens, 0); // scripted usage is 0 per call, summed
});
