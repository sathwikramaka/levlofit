// Run: node --test supabase/functions/_shared/llm.test.ts
// Contract tests for the model provider adapter, with an injected fetch and clock. No network, no keys.
import { test } from 'node:test';
import assert from 'node:assert/strict';
import { complete, completeWithFallback, configFromEnv, dataUseApproved, fallbackFromEnv, kindForStatus, statusForFailure, type LlmConfig } from './llm.ts';

const env = (vars: Record<string, string>) => (k: string) => vars[k];
const cfg = (over: Partial<LlmConfig> = {}): LlmConfig => ({
  provider: 'groq', baseUrl: 'https://llm.invalid/v1', model: 'openai/gpt-oss-120b', apiKey: 'k', timeoutMs: 1000, maxRetries: 1, ...over,
});
const req = { system: 'SYSTEM', turns: [{ role: 'user', content: 'hi' }] };
const ok = (text = 'Hello') => Response.json({ choices: [{ message: { content: text } }], usage: { prompt_tokens: 12, completion_tokens: 3 } });

/** A fetch that answers from a script of responses (or errors) and records every call. */
function scripted(...steps: (Response | Error | 'hang')[]) {
  const calls: { url: string; init: RequestInit; body: any }[] = [];
  const fetch = (async (url: string, init: RequestInit) => {
    calls.push({ url: String(url), init, body: JSON.parse(String(init.body)) });
    const step = steps[Math.min(calls.length - 1, steps.length - 1)];
    if (step === 'hang') return new Promise((_, reject) => init.signal?.addEventListener('abort', () => reject(new DOMException('aborted', 'AbortError'))));
    if (step instanceof Error) throw step;
    return step.clone();
  }) as typeof globalThis.fetch;
  return { fetch, calls };
}
const quiet = { sleep: async () => {}, log: () => {} };

// ---- configuration --------------------------------------------------------------------------------------------

test('config: defaults to Groq with its known model; existing LLM_BASE_URL and LLM_MODEL overrides still work', () => {
  const a = configFromEnv(env({ LLM_API_KEY: 'k' }));
  assert.ok(a.ok);
  assert.equal(a.config.provider, 'groq');
  assert.equal(a.config.baseUrl, 'https://api.groq.com/openai/v1');
  assert.equal(a.config.model, 'openai/gpt-oss-120b');
  assert.equal(a.config.timeoutMs, 25000);
  assert.equal(a.config.maxRetries, 1);
  const b = configFromEnv(env({ LLM_API_KEY: 'k', LLM_BASE_URL: 'https://x.invalid/v1/', LLM_MODEL: 'm' }));
  assert.ok(b.ok);
  assert.equal(b.config.baseUrl, 'https://x.invalid/v1', 'trailing slash trimmed');
  assert.equal(b.config.model, 'm');
});

test('data use: user data goes only to the provider the owner named in LLM_DATA_APPROVED', () => {
  assert.equal(dataUseApproved(env({}), 'groq'), false, 'unset: refused');
  assert.equal(dataUseApproved(env({ LLM_DATA_APPROVED: '' }), 'groq'), false);
  assert.equal(dataUseApproved(env({ LLM_DATA_APPROVED: 'openrouter' }), 'groq'), false, 'another provider: refused');
  assert.equal(dataUseApproved(env({ LLM_DATA_APPROVED: 'true' }), 'groq'), false, 'a yes-flag is not a provider name');
  assert.equal(dataUseApproved(env({ LLM_DATA_APPROVED: ' Groq ' }), 'groq'), true);
});

test('config: the old GROQ_API_KEY name still works for Groq only', () => {
  assert.ok(configFromEnv(env({ GROQ_API_KEY: 'k' })).ok);
  assert.equal(configFromEnv(env({ GROQ_API_KEY: 'k', LLM_PROVIDER: 'openrouter', LLM_MODEL: 'm' })).ok, false);
});

test('config: other providers need an explicit model; unknown providers and missing keys are refused', () => {
  for (const provider of ['openrouter', 'gemini']) {
    const r = configFromEnv(env({ LLM_API_KEY: 'k', LLM_PROVIDER: provider }));
    assert.equal(r.ok, false, provider);
    assert.match((r as { reason: string }).reason, /LLM_MODEL is required/);
    const s = configFromEnv(env({ LLM_API_KEY: 'k', LLM_PROVIDER: provider, LLM_MODEL: 'some-model' }));
    assert.ok(s.ok, provider);
  }
  assert.match((configFromEnv(env({ LLM_API_KEY: 'k', LLM_PROVIDER: 'acme' })) as { reason: string }).reason, /unknown LLM_PROVIDER/);
  assert.match((configFromEnv(env({})) as { reason: string }).reason, /missing LLM_API_KEY/);
});

test('config: timeout and retries are clamped to safe ranges', () => {
  const c = (vars: Record<string, string>) => (configFromEnv(env({ LLM_API_KEY: 'k', ...vars })) as { config: LlmConfig }).config;
  assert.equal(c({ LLM_TIMEOUT_MS: '5' }).timeoutMs, 100);
  assert.equal(c({ LLM_TIMEOUT_MS: '999999' }).timeoutMs, 60000);
  assert.equal(c({ LLM_TIMEOUT_MS: 'soon' }).timeoutMs, 25000);
  assert.equal(c({ LLM_MAX_RETRIES: '9' }).maxRetries, 2);
  assert.equal(c({ LLM_MAX_RETRIES: '0' }).maxRetries, 0);
  assert.equal(c({ LLM_MAX_RETRIES: '1.5' }).maxRetries, 1);
});

// ---- request shape --------------------------------------------------------------------------------------------

test('request: OpenAI-compatible body and bearer key; reasoning_effort only for gpt-oss models', async () => {
  const s = scripted(ok());
  const r = await complete(cfg(), req, { fetch: s.fetch, ...quiet });
  assert.ok(r.ok);
  assert.equal(s.calls[0].url, 'https://llm.invalid/v1/chat/completions');
  assert.equal((s.calls[0].init.headers as Record<string, string>).authorization, 'Bearer k');
  assert.deepEqual(s.calls[0].body.messages, [{ role: 'system', content: 'SYSTEM' }, { role: 'user', content: 'hi' }]);
  assert.equal(s.calls[0].body.reasoning_effort, 'medium');
  const t = scripted(ok());
  await complete(cfg({ model: 'meta/llama' }), req, { fetch: t.fetch, ...quiet });
  assert.equal('reasoning_effort' in t.calls[0].body, false);
  const g = scripted(ok());
  await complete(cfg({ provider: 'gemini', model: 'gemini-3.8-flash' }), req, { fetch: g.fetch, ...quiet });
  assert.equal(g.calls[0].body.reasoning_effort, 'medium', 'Gemini 3 reasons at the same level as gpt-oss');
  const o = scripted(ok());
  await complete(cfg({ provider: 'ollama', model: 'qwen3:8b' }), req, { fetch: o.fetch, ...quiet });
  assert.equal(o.calls[0].body.reasoning_effort, 'none', 'local models answer without thinking');
});

test('success: returns text, token usage, attempts, provider and model', async () => {
  const r = await complete(cfg(), req, { fetch: scripted(ok('Hi there')).fetch, ...quiet });
  assert.deepEqual(r, { ok: true, text: 'Hi there', usage: { promptTokens: 12, completionTokens: 3 }, attempts: 1, provider: 'groq', model: 'openai/gpt-oss-120b' });
});

// ---- errors and retries ---------------------------------------------------------------------------------------

test('errors: HTTP statuses map to kinds; only timeouts and config errors change the handler status', () => {
  assert.equal(kindForStatus(429), 'rate_limit');
  assert.equal(kindForStatus(401), 'auth');
  assert.equal(kindForStatus(403), 'auth');
  assert.equal(kindForStatus(400), 'bad_request');
  assert.equal(kindForStatus(503), 'upstream');
  assert.equal(statusForFailure('timeout'), 504);
  assert.equal(statusForFailure('config'), 503);
  for (const k of ['rate_limit', 'auth', 'bad_request', 'upstream', 'malformed', 'network'] as const) assert.equal(statusForFailure(k), 502, k);
});

test('retry: a rate limit, a provider error or a network error is retried once, then succeeds', async () => {
  for (const first of [new Response('', { status: 429 }), new Response('', { status: 503 }), new TypeError('fetch failed')]) {
    const s = scripted(first, ok('second time'));
    const r = await complete(cfg(), req, { fetch: s.fetch, ...quiet });
    assert.ok(r.ok);
    assert.equal(r.text, 'second time');
    assert.equal(r.attempts, 2);
    assert.equal(s.calls.length, 2);
  }
});

test('retry: never more than 1 + maxRetries attempts, and the last error kind is reported', async () => {
  const s = scripted(new Response('', { status: 503 }));
  const r = await complete(cfg(), req, { fetch: s.fetch, ...quiet });
  assert.deepEqual(r, { ok: false, kind: 'upstream', upstreamStatus: 503, attempts: 2 });
  const z = scripted(new Response('', { status: 503 }));
  assert.equal((await complete(cfg({ maxRetries: 0 }), req, { fetch: z.fetch, ...quiet })).attempts, 1);
});

test('no retry: auth errors, bad requests and malformed replies fail at once', async () => {
  const cases: [Response, string][] = [
    [new Response('', { status: 401 }), 'auth'],
    [new Response('', { status: 400 }), 'bad_request'],
    [Response.json({ choices: [{ message: { content: '   ' } }] }), 'malformed'],
    [Response.json({ nope: true }), 'malformed'],
    [new Response('not json', { status: 200 }), 'malformed'],
  ];
  for (const [res, kind] of cases) {
    const s = scripted(res, ok());
    const r = await complete(cfg(), req, { fetch: s.fetch, ...quiet });
    assert.equal(r.ok, false, kind);
    assert.equal((r as { kind: string }).kind, kind);
    assert.equal(s.calls.length, 1, `${kind}: one call`);
  }
});

test('timeout: a hung provider is aborted within the total budget and is not retried', { timeout: 2000 }, async () => {
  const s = scripted('hang');
  const t0 = Date.now();
  const r = await complete(cfg({ timeoutMs: 150 }), req, { fetch: s.fetch, ...quiet });
  assert.deepEqual(r, { ok: false, kind: 'timeout', upstreamStatus: null, attempts: 1 });
  assert.ok(Date.now() - t0 < 1000, 'ended near the budget');
  assert.equal(s.calls.length, 1);
});

test('timeout budget is shared: a retry gets only the time left, and the backoff never exceeds half of it', async () => {
  let clock = 0;
  const waits: number[] = [];
  const s = scripted(new Response('', { status: 429, headers: { 'retry-after': '30' } }), ok());
  const r = await complete(cfg({ timeoutMs: 1000 }), req, {
    fetch: s.fetch,
    now: () => clock,
    sleep: async (ms) => { waits.push(ms); clock += ms; },
    log: () => {},
  });
  assert.ok(r.ok);
  assert.deepEqual(waits, [500], 'Retry-After of 30 s capped at half the remaining 1000 ms');
});

test('no retry when the budget is nearly spent', async () => {
  let clock = 0;
  const s = scripted(new Response('', { status: 503 }), ok());
  const r = await complete(cfg({ timeoutMs: 1000 }), req, {
    fetch: (async (u: string, i: RequestInit) => { clock = 980; return s.fetch(u, i); }) as typeof fetch,
    now: () => clock,
    ...quiet,
  });
  assert.equal(r.ok, false);
  assert.equal(s.calls.length, 1);
});

// ---- logging --------------------------------------------------------------------------------------------------

test('logs: status, kind, timing and token counts only; never the prompt, the reply or the key', async () => {
  const lines: string[] = [];
  const log = (l: string) => lines.push(l);
  await complete(cfg({ apiKey: 'sk-secret' }), { system: 'PRIVATE SYSTEM', turns: [{ role: 'user', content: 'private question' }] }, {
    fetch: scripted(new Response('', { status: 503 }), ok('private reply')).fetch, sleep: async () => {}, log,
  });
  assert.equal(lines.length, 2);
  const all = lines.join('\n');
  for (const secret of ['PRIVATE SYSTEM', 'private question', 'private reply', 'sk-secret']) assert.ok(!all.includes(secret), secret);
  assert.deepEqual(JSON.parse(lines[0]).kind, 'upstream');
  assert.equal(JSON.parse(lines[1]).event, 'llm_ok');
  assert.equal(JSON.parse(lines[1]).promptTokens, 12);
});

// ---- fallback provider ----------------------------------------------------------------------------------------

test('data use: a base URL other than the provider\'s documented endpoint needs approval for that host by name', () => {
  // The preset endpoint: the provider name is enough.
  assert.equal(dataUseApproved(env({ LLM_DATA_APPROVED: 'groq' }), 'groq', 'https://api.groq.com/openai/v1'), true);
  // Overridden to another host: the name alone is not enough.
  assert.equal(dataUseApproved(env({ LLM_DATA_APPROVED: 'groq' }), 'groq', 'https://proxy.example.com/v1'), false);
  assert.equal(dataUseApproved(env({ LLM_DATA_APPROVED: 'groq@proxy.example.com' }), 'groq', 'https://proxy.example.com/v1'), true);
  assert.equal(dataUseApproved(env({ LLM_DATA_APPROVED: 'groq@other.example.com' }), 'groq', 'https://proxy.example.com/v1'), false);
  const fb = fallbackFromEnv(env({ LLM_FALLBACK_PROVIDER: 'openrouter', LLM_FALLBACK_API_KEY: 'f', LLM_FALLBACK_MODEL: 'm', LLM_FALLBACK_BASE_URL: 'https://x.example/v1', LLM_DATA_APPROVED: 'openrouter' }));
  assert.ok(fb && !fb.ok && /not approved/.test(fb.reason), 'the fallback follows the same rule');
});

test('data use: LLM_DATA_APPROVED may list several providers, each by name', () => {
  assert.equal(dataUseApproved(env({ LLM_DATA_APPROVED: 'groq, openrouter' }), 'openrouter'), true);
  assert.equal(dataUseApproved(env({ LLM_DATA_APPROVED: 'groq, openrouter' }), 'gemini'), false);
});

test('fallback config: off unless LLM_FALLBACK_PROVIDER is set; then it needs its own key and model, and it must be approved', () => {
  assert.equal(fallbackFromEnv(env({ LLM_DATA_APPROVED: 'groq' })), null, 'not configured: no fallback');
  const bad = fallbackFromEnv(env({ LLM_FALLBACK_PROVIDER: 'openrouter', LLM_DATA_APPROVED: 'groq,openrouter' }));
  assert.ok(bad && !bad.ok && /LLM_FALLBACK_API_KEY/.test(bad.reason));
  const unapproved = fallbackFromEnv(env({ LLM_FALLBACK_PROVIDER: 'openrouter', LLM_FALLBACK_API_KEY: 'f', LLM_FALLBACK_MODEL: 'm', LLM_DATA_APPROVED: 'groq' }));
  assert.ok(unapproved && !unapproved.ok && /not approved/.test(unapproved.reason), 'a fallback never receives user data unapproved');
  const good = fallbackFromEnv(env({ LLM_FALLBACK_PROVIDER: 'openrouter', LLM_FALLBACK_API_KEY: 'f', LLM_FALLBACK_MODEL: 'm', LLM_DATA_APPROVED: 'groq,openrouter', LLM_API_KEY: 'primary' }));
  assert.ok(good && good.ok);
  assert.equal(good.config.apiKey, 'f', 'the fallback never borrows the primary key');
  assert.equal(good.config.baseUrl, 'https://openrouter.ai/api/v1');
});

test('fallback: used once the primary fails for a transient reason (provider down, rate limit, timeout, network, malformed)', async () => {
  const fb = cfg({ provider: 'openrouter', baseUrl: 'https://fallback.invalid/v1', model: 'm', maxRetries: 0 });
  // The primary retries once for retryable kinds (two calls); a malformed reply is not retried (one call).
  for (const [failure, primaryCalls] of [[new Response('{}', { status: 503 }), 2], [new Response('{}', { status: 429 }), 2], [new Error('reset'), 2], [Response.json({ choices: [] }), 1]] as const) {
    const { fetch, calls } = scripted(...Array(primaryCalls).fill(failure), ok('From the fallback'));
    const r = await completeWithFallback(cfg(), fb, req, { fetch, ...quiet });
    assert.ok(r.ok, String(failure));
    assert.equal(r.ok && r.text, 'From the fallback');
    assert.equal(r.ok && r.provider, 'openrouter');
    assert.equal(r.usedFallback, true);
    assert.match(calls[calls.length - 1].url, /fallback\.invalid/);
  }
});

test('fallback: not used for errors a second provider cannot fix (bad request, auth), nor when none is configured', async () => {
  const fb = cfg({ provider: 'openrouter', baseUrl: 'https://fallback.invalid/v1', model: 'm' });
  for (const status of [400, 401]) {
    const { fetch, calls } = scripted(new Response('{}', { status }), ok());
    const r = await completeWithFallback(cfg(), fb, req, { fetch, ...quiet });
    assert.equal(r.ok, false);
    assert.equal(calls.length, 1, `status ${status}`);
  }
  const { fetch, calls } = scripted(new Response('{}', { status: 503 }));
  const r = await completeWithFallback(cfg({ maxRetries: 0 }), null, req, { fetch, ...quiet });
  assert.equal(r.ok, false);
  assert.equal(r.ok || r.kind, 'upstream');
  assert.equal(calls.length, 1);
});

test('deadline: a request-wide deadline caps each call, and a fallback only gets the time that is left', { timeout: 3000 }, async () => {
  // Primary hangs; total budget 400 ms although each provider allows 1000 ms.
  const fb = cfg({ provider: 'openrouter', baseUrl: 'https://fallback.invalid/v1', model: 'm', maxRetries: 0 });
  const { fetch, calls } = scripted('hang', 'hang');
  const t0 = Date.now();
  const r = await completeWithFallback(cfg({ maxRetries: 0 }), fb, { ...req, deadline: t0 + 400 }, { fetch, ...quiet });
  const took = Date.now() - t0;
  assert.equal(r.ok, false);
  assert.equal(calls.length, 2, 'the primary was cut short so the fallback still had time');
  assert.ok(took < 700, `took ${took} ms, budget 400`);
});

test('deadline: no call starts once the deadline has passed', async () => {
  const { fetch, calls } = scripted(ok());
  const r = await complete(cfg(), { ...req, deadline: Date.now() - 1 }, { fetch, ...quiet });
  assert.equal(r.ok || r.kind, 'timeout');
  assert.equal(calls.length, 0);
});

test('fallback: when both fail, the fallback failure is reported', async () => {
  const fb = cfg({ provider: 'openrouter', baseUrl: 'https://fallback.invalid/v1', model: 'm', maxRetries: 0 });
  const { fetch } = scripted(new Response('{}', { status: 503 }), new Response('{}', { status: 503 }), new Response('{}', { status: 401 }));
  const r = await completeWithFallback(cfg(), fb, req, { fetch, ...quiet });
  assert.equal(r.ok, false);
  assert.equal(r.ok || r.kind, 'auth');
});

