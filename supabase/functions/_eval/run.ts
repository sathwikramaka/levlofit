// Levlofit AI evaluation runner.
//
//   node supabase/functions/_eval/run.ts           scripted provider: deterministic, offline, no key needed
//   node supabase/functions/_eval/run.ts --live    the provider configured in the environment (LLM_PROVIDER,
//                                                  LLM_API_KEY, LLM_MODEL, LLM_BASE_URL), synthetic personas only
//   options: --runs N (live: repeat each case), --case ID (one case), --out FILE (JSON record for comparing runs)
//            --pause-ms N (live: wait N ms between calls, to stay under free-tier per-minute token limits)
//
// The report shows, per case and check, PASS / FAIL / N/A, whether the rule is strict or indicative, and the reason.
// It never prints the API key, prompts or replies. Exit 1 when a strict check fails, 2 for a usage error.
// A scripted run tests the harness and the handler's contract, not any model. Only live runs on the same cases,
// settings and dates can compare providers.
import { CASES } from './cases.ts';
import { type CaseResult, runCase } from './harness.ts';
import { createHash } from 'node:crypto';
import { configFromEnv } from '../_shared/llm.ts';

/** Owner-entered prices in US dollars per million tokens, from the provider's current price page; never built in. */
export type Prices = { inputPerMTok: number; outputPerMTok: number };

/** Reads LLM_PRICE_INPUT_PER_MTOK and LLM_PRICE_OUTPUT_PER_MTOK; null unless both are valid non-negative numbers. */
export function pricesFromEnv(env: Record<string, string | undefined>): Prices | null {
  const i = Number(env.LLM_PRICE_INPUT_PER_MTOK), o = Number(env.LLM_PRICE_OUTPUT_PER_MTOK);
  if (env.LLM_PRICE_INPUT_PER_MTOK == null || env.LLM_PRICE_OUTPUT_PER_MTOK == null || !(i >= 0) || !(o >= 0)) return null;
  return { inputPerMTok: i, outputPerMTok: o };
}

/** Live-run totals for comparing providers on the same cases: reliability, token use and, with prices, cost. */
export function liveSummary(results: CaseResult[], prices: Prices | null): string[] {
  const live = results.filter((r) => r.mode === 'live' && !r.skipped);
  if (!live.length) return [];
  const retried = live.filter((r) => (r.metrics.attempts ?? 1) > 1).length;
  const kinds = new Map<string, number>();
  for (const r of live) for (const k of r.metrics.errorKinds) kinds.set(k, (kinds.get(k) ?? 0) + 1);
  const known = live.filter((r) => r.metrics.promptTokens != null && r.metrics.completionTokens != null);
  const pIn = known.reduce((s, r) => s + r.metrics.promptTokens!, 0), pOut = known.reduce((s, r) => s + r.metrics.completionTokens!, 0);
  const lines = [
    `reliability: ${live.length} live call(s), ${retried} needed a retry, errors: ${kinds.size ? [...kinds].map(([k, n]) => `${k} ${n}`).join(', ') : 'none'}`,
    `tokens: ${pIn} prompt + ${pOut} completion over ${known.length} call(s) that reported usage${known.length < live.length ? ` (${live.length - known.length} did not)` : ''}`,
  ];
  if (prices && known.length) {
    const usd = (pIn * prices.inputPerMTok + pOut * prices.outputPerMTok) / 1e6;
    lines.push(`estimated cost: $${usd.toFixed(4)} for these calls, $${(usd / known.length).toFixed(5)} per call, at the prices entered in LLM_PRICE_* (check the provider's current price page)`);
  }
  return lines;
}

export function formatReport(results: CaseResult[], header: string, prices: Prices | null = null): string {
  const lines = [header, ''];
  for (const r of results) {
    if (r.skipped) {
      lines.push(`- ${r.id}: skipped (${r.skipped})`);
      continue;
    }
    const m = r.metrics;
    const timing = r.mode === 'live' && m.ms != null ? `  [${m.ms} ms, ${m.attempts} attempt(s), tokens ${m.promptTokens ?? '?'}/${m.completionTokens ?? '?'}]` : '';
    lines.push(`- ${r.id} (${r.persona}): ${r.about}${timing}`);
    for (const s of r.scores) lines.push(`    ${s.status.toUpperCase().padEnd(4)} ${s.check.padEnd(11)} ${s.strength.padEnd(10)} ${s.reason}`);
  }
  const all = results.flatMap((r) => r.scores);
  const count = (strength: string, status: string) => all.filter((s) => s.strength === strength && s.status === status).length;
  lines.push('', `strict: ${count('strict', 'pass')} pass, ${count('strict', 'fail')} fail, ${count('strict', 'na')} n/a`);
  lines.push(`indicative (heuristic, read the replies before drawing conclusions): ${count('indicative', 'pass')} pass, ${count('indicative', 'fail')} fail`);
  const ms = results.map((r) => r.metrics.ms).filter((n): n is number => n != null && results[0]?.mode === 'live').sort((a, b) => a - b);
  if (ms.length) lines.push(`latency: median ${ms[Math.floor(ms.length / 2)]} ms, max ${ms[ms.length - 1]} ms over ${ms.length} live call(s)`);
  lines.push(...liveSummary(results, prices));
  return lines.join('\n');
}

export async function main(argv: string[], env: Record<string, string | undefined> = process.env): Promise<{ code: number; report: string }> {
  const live = argv.includes('--live');
  const runsAt = argv.indexOf('--runs');
  const runs = runsAt >= 0 ? Number(argv[runsAt + 1]) : 1;
  const caseAt = argv.indexOf('--case');
  const only = caseAt >= 0 ? argv[caseAt + 1] : null;
  if (!Number.isInteger(runs) || runs < 1 || runs > 10) return { code: 2, report: '--runs must be 1 to 10' };
  const pauseAt = argv.indexOf('--pause-ms');
  const pauseMs = pauseAt >= 0 ? Number(argv[pauseAt + 1]) : 0;
  if (!Number.isInteger(pauseMs) || pauseMs < 0 || pauseMs > 600000) return { code: 2, report: '--pause-ms must be 0 to 600000' };
  const cases = CASES.filter((c) => !only || c.id === only);
  if (!cases.length) return { code: 2, report: `no case "${only}"` };

  let header = `Levlofit AI evaluation, scripted provider (${cases.length} cases). Tests the handler and the harness, not a model.`;
  if (live) {
    const cfg = configFromEnv((k) => env[k]);
    if (!cfg.ok) return { code: 2, report: `live mode needs the provider configuration in the environment: ${cfg.reason}` };
    header = `Levlofit AI evaluation, LIVE provider ${cfg.config.provider} / model ${cfg.config.model}, ${runs} run(s), ${new Date().toISOString().slice(0, 10)}. Synthetic personas only.`;
  }
  const outAt = argv.indexOf('--out');
  const out = outAt >= 0 ? argv[outAt + 1] : null;
  if (outAt >= 0 && (!out || out.startsWith('--'))) return { code: 2, report: '--out needs a file path' };
  const results: CaseResult[] = [];
  for (let i = 0; i < (live ? runs : 1); i++) for (const c of cases) {
    const r = await runCase(c, { live });
    results.push(r);
    if (live && pauseMs && !r.skipped) await new Promise((ok) => setTimeout(ok, pauseMs));
  }
  const strictFail = results.some((r) => r.scores.some((s) => s.strength === 'strict' && s.status === 'fail'));
  if (out) {
    const cfg = live ? configFromEnv((k) => env[k]) : null;
    const record = benchmarkRecord(results, cases, {
      mode: live ? 'live' : 'scripted',
      provider: cfg?.ok ? cfg.config.provider : null,
      model: cfg?.ok ? cfg.config.model : null,
      runs: live ? runs : 1,
    });
    const { writeFileSync } = await import('node:fs');
    writeFileSync(out, JSON.stringify(record, null, 2) + '\n');
  }
  return { code: strictFail ? 1 : 0, report: formatReport(results, header, live ? pricesFromEnv(env) : null) };
}

/**
 * A machine-readable record of one benchmark run, so live runs of different providers can be compared on the same
 * case set (the fingerprint changes whenever a case changes). Settings, scores and metrics only: never replies,
 * prompts, personal data or keys.
 */
export function benchmarkRecord(results: CaseResult[], cases: typeof CASES, meta: { mode: string; provider: string | null; model: string | null; runs: number }) {
  return {
    schema: 'levlofit-ai-benchmark/1',
    date: new Date().toISOString(),
    ...meta,
    casesFingerprint: createHash('sha256').update(JSON.stringify(cases)).digest('hex'),
    cases: results.map((r) => ({
      id: r.id,
      skipped: r.skipped ?? null,
      scores: r.scores.map((s) => ({ check: s.check, strength: s.strength, status: s.status })),
      metrics: { ms: r.metrics.ms ?? null, attempts: r.metrics.attempts ?? null, promptTokens: r.metrics.promptTokens ?? null, completionTokens: r.metrics.completionTokens ?? null, errorKinds: r.metrics.errorKinds },
    })),
  };
}

if (/[\\/]_eval[\\/]run\.ts$/.test(process.argv[1] ?? '')) {
  const { code, report } = await main(process.argv.slice(2));
  console.log(report);
  process.exitCode = code;
}
