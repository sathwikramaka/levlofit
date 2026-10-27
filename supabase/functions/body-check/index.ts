// POST /body-check  { image: base64, mime: image/jpeg | image/png | image/webp }
// Optional body-photo check (_shared/body-check.ts): the photo goes to the configured provider's vision model with a
// strict prompt and is never stored or logged. Returns { observations, focus } or an error message.
// Same provider settings and data-use approval as coach-chat (LLM_API_KEY, LLM_DATA_APPROVED, LLM_BASE_URL). The vision
// model is BODY_CHECK_MODEL (default below; check it is still offered by the provider before deploying).
import { withSupabase } from 'npm:@supabase/server@1.9.1';
import { base64Bytes, IMAGE_TYPES, MAX_IMAGE_BYTES, parseBodyCheck, visionRequest } from '../_shared/body-check.ts';
import { configFromEnv, dataUseApproved } from '../_shared/llm.ts';
import { checkLimits, LIMITS } from '../_shared/rate.ts';

const DEFAULT_MODEL = 'meta-llama/llama-4-scout-17b-16e-instruct';
const fail = (status: number, error: string) => Response.json({ error }, { status });

export default {
  fetch: withSupabase({ auth: 'user' }, async (req, ctx) => {
    if (req.method !== 'POST') return fail(405, 'Method not allowed');
    let body: { image?: unknown; mime?: unknown };
    try {
      body = await req.json();
    } catch {
      return fail(400, 'Send a photo.');
    }
    const { image, mime } = body;
    if (typeof image !== 'string' || typeof mime !== 'string' || !(IMAGE_TYPES as readonly string[]).includes(mime) || !/^[A-Za-z0-9+/]+={0,2}$/.test(image)) {
      return fail(400, 'Send a JPEG, PNG or WebP photo.');
    }
    if (base64Bytes(image) > MAX_IMAGE_BYTES) return fail(413, 'That photo is too large. Try a smaller one.');

    const llm = configFromEnv((k) => Deno.env.get(k));
    if (!llm.ok || !dataUseApproved((k) => Deno.env.get(k), llm.config.provider, llm.config.baseUrl)) {
      console.error(JSON.stringify({ event: 'body_check_config', reason: llm.ok ? 'data use not approved' : llm.reason }));
      return fail(503, 'The body check is not available yet.');
    }
    if ((await checkLimits(ctx.supabase, [LIMITS.bodyCheckDay])) === 'limited') {
      return fail(429, 'You can run the body check 3 times a day. Try again tomorrow.');
    }

    const cfg = llm.config;
    const model = Deno.env.get('BODY_CHECK_MODEL') ?? DEFAULT_MODEL;
    const started = Date.now();
    try {
      const res = await fetch(`${cfg.baseUrl}/chat/completions`, {
        method: 'POST',
        headers: { 'content-type': 'application/json', authorization: `Bearer ${cfg.apiKey}` },
        body: JSON.stringify(visionRequest(model, mime, image)),
        signal: AbortSignal.timeout(30000),
      });
      // Logs carry status and timing only, never the photo or the reply.
      console.log(JSON.stringify({ event: 'body_check', provider: cfg.provider, model, status: res.status, ms: Date.now() - started }));
      if (!res.ok) return fail(502, 'The body check could not finish. Try again later.');
      const json = await res.json();
      const result = parseBodyCheck(String(json?.choices?.[0]?.message?.content ?? ''));
      if (!result) return fail(502, 'The body check could not give a safe answer for this photo. Try another one.');
      return Response.json(result);
    } catch {
      console.error(JSON.stringify({ event: 'body_check', provider: cfg.provider, model, status: null, ms: Date.now() - started }));
      return fail(504, 'The body check took too long. Try again later.');
    }
  }),
};
