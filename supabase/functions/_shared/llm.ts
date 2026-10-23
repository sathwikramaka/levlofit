// Model provider adapter for Levlofit AI. One OpenAI-compatible chat call with a total time budget, one bounded
// retry on rate limits and provider errors, a small error taxonomy, and logs that never include content.
// Switching provider is configuration only (LLM_PROVIDER, LLM_MODEL, LLM_BASE_URL); no handler code changes.
// Pure TypeScript with injected fetch/env, so node tests run it without Deno or a network.

export type Turn = { role: string; content: string };
export type LlmErrorKind = 'config' | 'timeout' | 'rate_limit' | 'auth' | 'bad_request' | 'upstream' | 'malformed' | 'network';
export type LlmUsage = { promptTokens: number | null; completionTokens: number | null };
export type LlmResult =
  | { ok: true; text: string; usage: LlmUsage; attempts: number; provider: string; model: string }
  | { ok: false; kind: LlmErrorKind; upstreamStatus: number | null; attempts: number };

export type LlmConfig = { provider: string; baseUrl: string; model: string; apiKey: string; timeoutMs: number; maxRetries: number };

/**
 * Known providers. Only Groq has a default model: it is the one the app has been run with. For the others the owner
 * must set LLM_MODEL, because model ids change often and are not verified here. Base URLs are the providers'
 * OpenAI-compatible endpoints; check each provider's current docs and data terms before pointing real users at it.
 */
export const PRESETS: Record<string, { baseUrl: string; model: string | null }> = {
  groq: { baseUrl: 'https://api.groq.com/openai/v1', model: 'openai/gpt-oss-120b' },
  openrouter: { baseUrl: 'https://openrouter.ai/api/v1', model: null },
  gemini: { baseUrl: 'https://generativelanguage.googleapis.com/v1beta/openai', model: null },
  // Local models on the developer's machine (evaluation only; nothing leaves the laptop). Any key value works.
  ollama: { baseUrl: 'http://127.0.0.1:11434/v1', model: null },
};

const DEFAULT_TIMEOUT_MS = 25000;
const MIN_RETRY_BUDGET_MS = 50; // a retry needs at least this much of the time budget left

/** Reads the provider settings. Unknown provider, missing key or missing model is a config error, never a guess. */
export function configFromEnv(get: (k: string) => string | undefined): { ok: true; config: LlmConfig } | { ok: false; reason: string } {
  const provider = (get('LLM_PROVIDER') ?? 'groq').trim().toLowerCase();
  const preset = PRESETS[provider];
  if (!preset) return { ok: false, reason: `unknown LLM_PROVIDER "${provider}"` };
  const apiKey = get('LLM_API_KEY') ?? (provider === 'groq' ? get('GROQ_API_KEY') : undefined);
  if (!apiKey) return { ok: false, reason: 'missing LLM_API_KEY' };
  const model = get('LLM_MODEL') ?? preset.model;
  if (!model) return { ok: false, reason: `LLM_MODEL is required for provider "${provider}"` };
  const baseUrl = (get('LLM_BASE_URL') ?? preset.baseUrl).replace(/\/+$/, '');
  const t = Number(get('LLM_TIMEOUT_MS') ?? DEFAULT_TIMEOUT_MS);
  const timeoutMs = Number.isFinite(t) ? Math.min(Math.max(t, 100), 60000) : DEFAULT_TIMEOUT_MS;
  const r = Number(get('LLM_MAX_RETRIES') ?? 1);
  const maxRetries = Number.isInteger(r) ? Math.min(Math.max(r, 0), 2) : 1;
  return { ok: true, config: { provider, baseUrl, model, apiKey, timeoutMs, maxRetries } };
}

/**
 * Whether the owner has approved sending real user data to [provider]: LLM_DATA_APPROVED must name it (after
 * reviewing that provider's data terms). Unset, a yes-flag or another provider's name means no. When [baseUrl] is not
 * the provider's documented endpoint (an LLM_BASE_URL override), the entry must also name the host:
 * "groq@proxy.example.com", so an override can never send data somewhere nobody approved. The offline and live
 * evaluations use synthetic personas only.
 */
export function dataUseApproved(get: (k: string) => string | undefined, provider: string, baseUrl?: string): boolean {
  const approved = (get('LLM_DATA_APPROVED') ?? '').split(',').map((p) => p.trim().toLowerCase());
  const preset = PRESETS[provider]?.baseUrl;
  const host = (u: string) => { try { return new URL(u).hostname.toLowerCase(); } catch { return ''; } };
  if (!baseUrl || (preset && host(baseUrl) === host(preset))) return approved.includes(provider);
  return host(baseUrl) !== '' && approved.includes(`${provider}@${host(baseUrl)}`);
}

/**
 * The optional second provider, read from the same settings with an LLM_FALLBACK_ prefix (LLM_FALLBACK_PROVIDER,
 * LLM_FALLBACK_API_KEY, LLM_FALLBACK_MODEL, LLM_FALLBACK_BASE_URL). Null when no fallback provider is set. It never
 * borrows the primary key, and it must be named in LLM_DATA_APPROVED like the primary.
 */
export function fallbackFromEnv(get: (k: string) => string | undefined): { ok: true; config: LlmConfig } | { ok: false; reason: string } | null {
  if (!get('LLM_FALLBACK_PROVIDER')) return null;
  const only = (k: string) => (k === 'GROQ_API_KEY' ? undefined : get(k.replace(/^LLM_/, 'LLM_FALLBACK_')));
  const fb = configFromEnv((k) => (k === 'LLM_TIMEOUT_MS' || k === 'LLM_MAX_RETRIES' ? get(k) : only(k)));
  if (!fb.ok) return { ok: false, reason: `fallback: ${fb.reason.replace('LLM_', 'LLM_FALLBACK_')}` };
  if (!dataUseApproved(get, fb.config.provider, fb.config.baseUrl)) return { ok: false, reason: `fallback: data use not approved for "${fb.config.provider}"` };
  return fb;
}

/** Maps an HTTP status to an error kind. Only rate limits and provider-side errors are worth retrying. */
export function kindForStatus(status: number): LlmErrorKind {
  if (status === 429) return 'rate_limit';
  if (status === 401 || status === 403) return 'auth';
  if (status >= 500) return 'upstream';
  return 'bad_request';
}
const RETRYABLE = new Set<LlmErrorKind>(['rate_limit', 'upstream', 'network']);

/** Provider-specific request fields, kept here so the handler stays provider-neutral. */
function extraParams(cfg: LlmConfig): Record<string, unknown> {
  // gpt-oss reasons before answering; medium stays quick but careful. Gemini 3 models always reason (it cannot be
  // switched off) and bill it as output, so they get the same level: comparable answers and bounded cost. Only sent to
  // models that accept it.
  // Small local models think by default and can spend the whole token cap on it, leaving no answer: switched off.
  if (cfg.provider === 'ollama') return { reasoning_effort: 'none' };
  return cfg.model.startsWith('openai/gpt-oss') || cfg.model.startsWith('gemini-3') ? { reasoning_effort: 'medium' } : {};
}

export type LlmDeps = {
  fetch?: typeof fetch;
  now?: () => number;
  sleep?: (ms: number) => Promise<void>;
  random?: () => number;
  log?: (line: string, error: boolean) => void;
};

/** A chat request. [deadline] (epoch ms) is a request-wide limit shared by every call the handler makes. */
export type LlmRequest = { system: string; turns: Turn[]; temperature?: number; maxTokens?: number; deadline?: number };

/** One chat completion within cfg.timeoutMs (and the request deadline) in total, across at most 1 + cfg.maxRetries attempts. */
export async function complete(cfg: LlmConfig, req: LlmRequest, deps: LlmDeps = {}): Promise<LlmResult> {
  const doFetch = deps.fetch ?? fetch;
  const now = deps.now ?? Date.now;
  const sleep = deps.sleep ?? ((ms: number) => new Promise<void>((r) => setTimeout(r, ms)));
  const random = deps.random ?? Math.random;
  const log = deps.log ?? ((line: string, error: boolean) => (error ? console.error(line) : console.log(line)));
  const started = now();
  const deadline = Math.min(started + cfg.timeoutMs, req.deadline ?? Infinity);
  if (deadline - started <= MIN_RETRY_BUDGET_MS) {
    log(JSON.stringify({ event: 'llm_error', provider: cfg.provider, model: cfg.model, ms: 0, kind: 'timeout', upstreamStatus: null, attempts: 0, retrying: false }), true);
    return { ok: false, kind: 'timeout', upstreamStatus: null, attempts: 0 };
  }
  const body = JSON.stringify({
    model: cfg.model,
    temperature: req.temperature ?? 0.7,
    max_tokens: req.maxTokens ?? 1400,
    ...extraParams(cfg),
    messages: [{ role: 'system', content: req.system }, ...req.turns],
  });
  const record = (event: string, fields: Record<string, unknown>, error: boolean) =>
    log(JSON.stringify({ event, provider: cfg.provider, model: cfg.model, ms: now() - started, ...fields }), error);

  let attempts = 0;
  for (;;) {
    attempts++;
    const remaining = deadline - now();
    const abort = new AbortController();
    const timer = setTimeout(() => abort.abort(), Math.max(remaining, 0));
    let kind: LlmErrorKind;
    let upstreamStatus: number | null = null;
    let retryAfterMs: number | null = null;
    try {
      const res = await doFetch(`${cfg.baseUrl}/chat/completions`, {
        method: 'POST',
        signal: abort.signal,
        headers: { 'content-type': 'application/json', authorization: `Bearer ${cfg.apiKey}` },
        body,
      });
      if (res.ok) {
        // Only the fields read below; anything else in the provider's reply is ignored.
        type Completion = {
          choices?: { message?: { content?: unknown } }[];
          usage?: { prompt_tokens?: number | null; completion_tokens?: number | null };
        } | null;
        let out: Completion;
        try {
          out = (await res.json()) as Completion;
        } catch {
          out = null;
        }
        const text: unknown = out?.choices?.[0]?.message?.content;
        const usage = { promptTokens: out?.usage?.prompt_tokens ?? null, completionTokens: out?.usage?.completion_tokens ?? null };
        if (typeof text === 'string' && text.trim()) {
          record('llm_ok', { attempts, ...usage }, false);
          return { ok: true, text, usage, attempts, provider: cfg.provider, model: cfg.model };
        }
        kind = 'malformed';
      } else {
        upstreamStatus = res.status;
        kind = kindForStatus(res.status);
        const ra = Number(res.headers.get('retry-after'));
        if (Number.isFinite(ra) && ra >= 0) retryAfterMs = ra * 1000;
      }
    } catch (e) {
      kind = (e as Error).name === 'AbortError' ? 'timeout' : 'network';
    } finally {
      clearTimeout(timer);
    }

    const left = deadline - now();
    const canRetry = RETRYABLE.has(kind) && attempts <= cfg.maxRetries && left > MIN_RETRY_BUDGET_MS;
    record('llm_error', { kind, upstreamStatus, attempts, retrying: canRetry }, true);
    if (!canRetry) return { ok: false, kind, upstreamStatus, attempts };
    // Back off with jitter, honouring Retry-After when given, but never past half the time that is left.
    const wait = Math.min(retryAfterMs ?? 250 + random() * 500, left / 2);
    await sleep(wait);
  }
}

/** Failures a second provider may fix; a bad request or a bad key would fail there too, or hide a setup error. */
const FALLBACK_KINDS = new Set<LlmErrorKind>(['rate_limit', 'upstream', 'network', 'timeout', 'malformed']);

/** [complete] with the primary provider, then once with [fallback] (if any) when the primary failed transiently. */
export async function completeWithFallback(
  primary: LlmConfig,
  fallback: LlmConfig | null,
  req: LlmRequest,
  deps: LlmDeps = {},
): Promise<LlmResult & { usedFallback?: boolean }> {
  const now = deps.now ?? Date.now;
  // With a fallback and a deadline, the primary gets 60% of the time left, so the fallback is never starved.
  const left = req.deadline === undefined ? null : req.deadline - now();
  const first = await complete(primary, fallback && left !== null ? { ...req, deadline: now() + left * 0.6 } : req, deps);
  if (first.ok || !fallback || !FALLBACK_KINDS.has(first.kind)) return first;
  (deps.log ?? ((l: string) => console.error(l)))(JSON.stringify({ event: 'llm_fallback', primaryKind: first.kind }), true);
  const second = await complete(fallback, req, deps);
  return { ...second, usedFallback: true };
}

/** HTTP status the handler returns for a failed call: 504 for a timeout, 503 for misconfiguration, else 502. */
export function statusForFailure(kind: LlmErrorKind): number {
  return kind === 'timeout' ? 504 : kind === 'config' ? 503 : 502;
}
