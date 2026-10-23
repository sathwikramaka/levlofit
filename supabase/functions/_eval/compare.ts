// Compares two live benchmark records written by `run.ts --live --runs N --out FILE` (for example Groq and Gemini on
// the same cases). Measured numbers only: pass rates per check, consistency across runs, latency and tokens. Cost is an
// estimate from the measured tokens and prices you pass in; it is labelled as such. Refuses records from different
// case sets.
//
//   node supabase/functions/_eval/compare.ts a.json b.json [--price-a in,out] [--price-b in,out] [--messages 1000]
//   prices are US dollars per 1M input and output tokens, from each provider's pricing page on the day.
import { readFileSync } from 'node:fs';

type Rec = {
  schema: string; mode: string; provider: string | null; model: string | null; runs: number; casesFingerprint: string;
  cases: { id: string; skipped: string | null; scores: { check: string; strength: string; status: string }[];
    metrics: { ms: number | null; promptTokens: number | null; completionTokens: number | null; errorKinds: string[] } }[];
};

const pct = (n: number, d: number) => (d ? `${Math.round((100 * n) / d)}%` : 'n/a');
const median = (xs: number[]) => (xs.length ? [...xs].sort((a, b) => a - b)[Math.floor(xs.length / 2)] : null);
const p90 = (xs: number[]) => (xs.length ? [...xs].sort((a, b) => a - b)[Math.min(xs.length - 1, Math.floor(xs.length * 0.9))] : null);

export function summarise(r: Rec, price: [number, number] | null, messages: number) {
  const ran = r.cases.filter((c) => !c.skipped);
  const checks = new Map<string, { pass: number; total: number; strength: string }>();
  for (const c of ran) for (const s of c.scores) {
    if (s.status === 'na') continue;
    const e = checks.get(s.check) ?? { pass: 0, total: 0, strength: s.strength };
    e.total++;
    if (s.status === 'pass') e.pass++;
    checks.set(s.check, e);
  }
  // Consistency: for each case, the share of runs whose pass/fail pattern equals that case's most common pattern.
  const byCase = new Map<string, string[]>();
  for (const c of ran) byCase.set(c.id, [...(byCase.get(c.id) ?? []), c.scores.map((s) => `${s.check}:${s.status}`).join('|')]);
  let same = 0, all = 0;
  for (const patterns of byCase.values()) {
    const counts = new Map<string, number>();
    for (const p of patterns) counts.set(p, (counts.get(p) ?? 0) + 1);
    same += Math.max(...counts.values());
    all += patterns.length;
  }
  const ms = ran.map((c) => c.metrics.ms).filter((n): n is number => n != null);
  const tin = ran.map((c) => c.metrics.promptTokens).filter((n): n is number => n != null);
  const tout = ran.map((c) => c.metrics.completionTokens).filter((n): n is number => n != null);
  const avg = (xs: number[]) => (xs.length ? xs.reduce((a, b) => a + b, 0) / xs.length : null);
  const ain = avg(tin), aout = avg(tout);
  const cost = price && ain != null && aout != null ? ((ain * price[0] + aout * price[1]) / 1e6) * messages : null;
  const errors = ran.flatMap((c) => c.metrics.errorKinds).length;
  return { label: `${r.provider ?? '?'} / ${r.model ?? '?'}`, runs: r.runs, calls: ran.length, checks, consistency: pct(same, all),
    msMedian: median(ms), msP90: p90(ms), tokensIn: ain, tokensOut: aout, cost, errors };
}

export function compare(a: Rec, b: Rec, pa: [number, number] | null, pb: [number, number] | null, messages = 1000): string {
  for (const r of [a, b]) if (r.schema !== 'levlofit-ai-benchmark/1' || r.mode !== 'live') throw new Error('both files must be live benchmark records');
  if (a.casesFingerprint !== b.casesFingerprint) throw new Error('different case sets: re-run both on the same cases');
  const A = summarise(a, pa, messages), B = summarise(b, pb, messages);
  const n = (x: number | null, d = 0) => (x == null ? 'n/a' : x.toFixed(d));
  const lines = [`| Measure | ${A.label} | ${B.label} |`, '|---|---|---|',
    `| Runs x calls | ${A.runs} x ${A.calls} | ${B.runs} x ${B.calls} |`,
    `| Provider errors | ${A.errors} | ${B.errors} |`,
    `| Consistency (same result across runs) | ${A.consistency} | ${B.consistency} |`,
    `| Latency median / p90 (ms) | ${n(A.msMedian)} / ${n(A.msP90)} | ${n(B.msMedian)} / ${n(B.msP90)} |`,
    `| Tokens per call in / out (mean) | ${n(A.tokensIn)} / ${n(A.tokensOut)} | ${n(B.tokensIn)} / ${n(B.tokensOut)} |`,
    `| Estimated cost for ${messages} messages (USD, from measured tokens and the prices given) | ${n(A.cost, 2)} | ${n(B.cost, 2)} |`];
  const names = [...new Set([...A.checks.keys(), ...B.checks.keys()])].sort();
  for (const c of names) {
    const x = A.checks.get(c), y = B.checks.get(c);
    const strength = (x ?? y)!.strength;
    lines.push(`| ${c} (${strength}) pass rate | ${x ? `${pct(x.pass, x.total)} of ${x.total}` : 'n/a'} | ${y ? `${pct(y.pass, y.total)} of ${y.total}` : 'n/a'} |`);
  }
  lines.push('', 'Indicative checks are text heuristics: read the replies before drawing conclusions. Cost is an estimate.');
  return lines.join('\n');
}

function price(argv: string[], flag: string): [number, number] | null {
  const i = argv.indexOf(flag);
  if (i < 0) return null;
  const [inp, out] = String(argv[i + 1]).split(',').map(Number);
  if (!Number.isFinite(inp) || !Number.isFinite(out)) throw new Error(`${flag} needs "input,output" prices per 1M tokens`);
  return [inp, out];
}

if (/[\\/]_eval[\\/]compare\.ts$/.test(process.argv[1] ?? '')) {
  const argv = process.argv.slice(2);
  const [fa, fb] = argv.filter((x) => x.endsWith('.json'));
  const m = argv.indexOf('--messages');
  const read = (f: string) => JSON.parse(readFileSync(f, 'utf8')) as Rec;
  console.log(compare(read(fa), read(fb), price(argv, '--price-a'), price(argv, '--price-b'), m >= 0 ? Number(argv[m + 1]) : 1000));
}
