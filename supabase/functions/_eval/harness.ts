// Drives the real coach-chat handler for one evaluation case, with the fake Supabase client from the tests and either
// a scripted provider (default, deterministic, no network) or the live provider from the environment (opt-in).
// Captures what reached the provider and what the handler wrote, then scores it. Nothing here prints content.
import { register } from 'node:module';
// @ts-ignore: plain JS test double
import { fakeClient } from '../_test/supabase-server-mock.mjs';
import type { Case, Step } from './cases.ts';
import { PERSONAS } from './personas.ts';
import type { Observed, Score } from './score.ts';

register('../_test/npm-loader.mjs', import.meta.url);

let envGet: (k: string) => string | undefined = () => undefined;
(globalThis as any).Deno = { env: { get: (k: string) => envGet(k) } };
const handler = (await import('../coach-chat/index.ts')).default.fetch as (req: Request) => Promise<Response>;

const THREAD = '11111111-1111-1111-1111-111111111111';
// The personas are synthetic, so the evaluation stands in for the owner's data-use approval (LLM_DATA_APPROVED).
const SCRIPTED_ENV: Record<string, string> = { LLM_API_KEY: 'eval-scripted-key', LLM_BASE_URL: 'https://llm.invalid/v1', LLM_TIMEOUT_MS: '300', LLM_DATA_APPROVED: 'groq@llm.invalid' };

export type Metrics = { attempts: number | null; ms: number | null; promptTokens: number | null; completionTokens: number | null; errorKinds: string[] };
export type CaseResult = { id: string; about: string; persona: string; mode: 'scripted' | 'live'; scores: Score[]; metrics: Metrics; skipped?: string };

function scriptedFetch(steps: Step[], seen: unknown[]) {
  return (async (_url: string, init: RequestInit) => {
    seen.push(JSON.parse(String(init.body)));
    const step = steps[Math.min(seen.length - 1, steps.length - 1)];
    if (step === 'hang') {
      return new Promise((_, reject) => init.signal?.addEventListener('abort', () => reject(new DOMException('aborted', 'AbortError'))));
    }
    if (typeof step === 'string') return Response.json({ choices: [{ message: { content: step } }], usage: { prompt_tokens: 0, completion_tokens: 0 } });
    if ('raw' in step) return new Response(step.raw, { status: 200, headers: { 'content-type': 'application/json' } });
    return new Response('{"error":"scripted"}', { status: step.status, headers: step.retryAfter ? { 'retry-after': step.retryAfter } : {} });
  }) as typeof fetch;
}

// The handler reads globals (fetch, Deno.env, the Supabase context), so cases run one at a time even if called together.
let queue: Promise<unknown> = Promise.resolve();

/** Runs one case. `steps` overrides the case's good replies (used to prove bad replies are caught). */
export function runCase(c: Case, opts: { live?: boolean; steps?: Step[] } = {}): Promise<CaseResult> {
  const run = queue.then(() => runOne(c, opts));
  queue = run.catch(() => undefined);
  return run;
}

async function runOne(c: Case, opts: { live?: boolean; steps?: Step[] }): Promise<CaseResult> {
  const persona = PERSONAS[c.persona];
  const mode = opts.live ? 'live' : 'scripted';
  const metrics: Metrics = { attempts: null, ms: null, promptTokens: null, completionTokens: null, errorKinds: [] };
  if (opts.live && !c.liveOk) return { id: c.id, about: c.about, persona: c.persona, mode, scores: [], metrics, skipped: 'scripted-only case' };

  const ops: any[] = [];
  const tables = structuredClone(persona.tables) as Record<string, any>;
  // Earlier turns of this chat, as the handler reads them: newest first (it reverses them).
  if (c.history) tables.coach_messages = { data: c.history.map((m, i) => ({ id: i + 1, ...m })).reverse() };
  if (c.thread) tables.coach_threads = { data: c.thread };
  const client = fakeClient(tables, ops);
  (globalThis as any).__supabaseCtx = { userClaims: { id: '00000000-0000-0000-0000-0000000000e1' }, supabase: client, supabaseAdmin: client };

  const bodies: any[] = [];
  const realFetch = globalThis.fetch;
  if (opts.live) {
    // The existing configuration (LLM_PROVIDER, LLM_API_KEY, LLM_MODEL, ...); synthetic personas only, so approved.
    const provider = (process.env.LLM_PROVIDER ?? 'groq').trim().toLowerCase();
    const host = process.env.LLM_BASE_URL ? `@${new URL(process.env.LLM_BASE_URL).hostname}` : '';
    envGet = (k) => (k === 'LLM_DATA_APPROVED' ? `${provider},${provider}${host}` : process.env[k]);
    globalThis.fetch = (async (url: string, init: RequestInit) => {
      bodies.push(JSON.parse(String(init.body)));
      return realFetch(url, init);
    }) as typeof fetch;
  } else {
    const env = { ...SCRIPTED_ENV, ...c.env };
    envGet = (k) => env[k];
    globalThis.fetch = scriptedFetch(opts.steps ?? c.good, bodies);
  }

  // The adapter logs one JSON line per call (status, timing, token counts; never content). Collect it, print nothing.
  const { log, error } = console;
  const collect = (line: unknown) => {
    try {
      const e = JSON.parse(String(line));
      // A reply can take several model calls (draft, rewrite, food fix): tokens add up over all of them.
      if (e.event === 'llm_ok') {
        const add = (a: number | null, b: unknown) => (typeof b === 'number' ? (a ?? 0) + b : a);
        Object.assign(metrics, { promptTokens: add(metrics.promptTokens, e.promptTokens), completionTokens: add(metrics.completionTokens, e.completionTokens) });
      }
      if (e.event === 'llm_error') metrics.errorKinds.push(e.kind);
    } catch {
      // not an adapter line
    }
  };
  console.log = collect;
  console.error = collect;
  let status = 0, body: Record<string, unknown> | null = null;
  const started = Date.now();
  try {
    const res = await handler(new Request('http://local/coach-chat', { method: 'POST', body: JSON.stringify({ message: c.message, threadId: THREAD }) }));
    status = res.status;
    body = await res.json().catch(() => null);
  } finally {
    // What the person waits for, and every HTTP request sent (retries and rewrites included).
    metrics.ms = Date.now() - started;
    metrics.attempts = bodies.length;
    console.log = log;
    console.error = error;
    globalThis.fetch = realFetch;
    envGet = () => undefined;
  }

  const observed: Observed = {
    status,
    body,
    reply: typeof body?.reply === 'string' ? body.reply : null,
    requests: bodies.map((b) => ({ system: String(b.messages?.[0]?.content ?? ''), turns: (b.messages ?? []).slice(1) })),
    writes: ops.filter((o) => o.op !== 'select').map((o) => ({ table: o.table, op: o.op, args: o.args })),
  };
  return { id: c.id, about: c.about, persona: c.persona, mode, scores: c.score(observed, persona), metrics };
}
