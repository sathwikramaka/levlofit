// Deno runtime smoke test for the Edge Function entry points (coach-chat, generate-plan, delete-account, body-check), using the real
// npm:@supabase/server. Run from supabase/functions:
//   deno run --no-lock --allow-env --allow-read --allow-net=127.0.0.1 _test/deno-smoke.ts
// Safety: every Supabase and model URL points at 127.0.0.1:9 (nothing listens) and network permission is limited to
// 127.0.0.1, so nothing can reach a real project. A throwaway ES256 key signs the test token; only its public key is
// given to the library. Exits 1 when any expectation fails.
import { exportJWK, generateKeyPair, SignJWT } from 'npm:jose@6.2.12';

const base = 'http://127.0.0.1:9';
const { publicKey, privateKey } = await generateKeyPair('ES256');
const jwk = { ...(await exportJWK(publicKey)), kid: 'local-test', alg: 'ES256', use: 'sig' };
const env: Record<string, string> = {
  SUPABASE_URL: base,
  SUPABASE_PUBLISHABLE_KEY: 'sb_publishable_dummy_local_only',
  SUPABASE_SECRET_KEY: 'sb_secret_dummy_local_only',
  SUPABASE_JWKS: JSON.stringify({ keys: [jwk] }),
  LLM_API_KEY: 'dummy-local-only',
  LLM_BASE_URL: `${base}/v1`,
  LLM_TIMEOUT_MS: '500',
  LLM_DATA_APPROVED: 'groq@127.0.0.1', // a configured deployment: the (local) endpoint, approved by host
};
for (const [k, v] of Object.entries(env)) Deno.env.set(k, v);
const now = Math.floor(Date.now() / 1000);
const token = await new SignJWT({ role: 'authenticated', aud: 'authenticated' })
  .setProtectedHeader({ alg: 'ES256', kid: 'local-test' })
  .setSubject('00000000-0000-0000-0000-0000000000d1')
  .setIssuer(`${base}/auth/v1`)
  .setIssuedAt(now)
  .setExpirationTime(now + 600)
  .sign(privateKey);

type Case = { fn: string; label: string; method: string; auth?: string; body?: string; headers?: Record<string, string>; status: number; code?: string };
const cases: Case[] = [];
for (const fn of ['coach-chat', 'generate-plan', 'delete-account', 'body-check']) {
  cases.push(
    { fn, label: 'CORS preflight', method: 'OPTIONS', status: 204 },
    { fn, label: 'no credentials', method: 'POST', body: '{}', status: 401, code: 'MISSING_CREDENTIALS' },
    { fn, label: 'invalid token', method: 'POST', auth: 'Bearer not-a-jwt', body: '{}', status: 401, code: 'INVALID_JWT' },
    { fn, label: 'wrong method (signed in)', method: 'GET', auth: `Bearer ${token}`, status: 405 },
  );
}
cases.push(
  { fn: 'coach-chat', label: 'bad JSON (signed in)', method: 'POST', auth: `Bearer ${token}`, body: 'not json', status: 400 },
  { fn: 'coach-chat', label: 'database unreachable: no reply, 503', method: 'POST', auth: `Bearer ${token}`, body: JSON.stringify({ message: 'Hi' }), status: 503 },
  { fn: 'generate-plan', label: 'rate store unreachable: 503 (fail closed)', method: 'POST', auth: `Bearer ${token}`, body: '{}', status: 503 },
  { fn: 'delete-account', label: 'storage unreachable: account kept', method: 'POST', auth: `Bearer ${token}`, body: '{}', status: 500 },
);

// Body check: every refusal happens before the rate limit and the model (both unreachable here, so a 503 shows the
// request got that far). A tiny JPEG header stands in for a photo.
const jpeg = btoa(String.fromCharCode(0xff, 0xd8, 0xff, 0xe0, 0, 16, 74, 70, 73, 70, 0, 1));
const signedIn = `Bearer ${token}`;
cases.push(
  { fn: 'body-check', label: 'not JSON content type: 415', method: 'POST', auth: signedIn, body: '{}', headers: { 'content-type': 'text/plain' }, status: 415 },
  { fn: 'body-check', label: 'declared size over the cap: 413', method: 'POST', auth: signedIn, body: '{}', headers: { 'content-length': '99999999' }, status: 413 },
  { fn: 'body-check', label: 'oversized body, no Content-Length: 413', method: 'POST', auth: signedIn, body: JSON.stringify({ mime: 'image/jpeg', image: 'A'.repeat(6 * 1024 * 1024) }), status: 413 },
  { fn: 'body-check', label: 'malformed JSON: 400', method: 'POST', auth: signedIn, body: '{"image":', status: 400 },
  { fn: 'body-check', label: 'invalid base64: 400', method: 'POST', auth: signedIn, body: JSON.stringify({ mime: 'image/jpeg', image: 'not*base64' }), status: 400 },
  { fn: 'body-check', label: 'type does not match bytes: 400', method: 'POST', auth: signedIn, body: JSON.stringify({ mime: 'image/png', image: jpeg }), status: 400 },
  { fn: 'body-check', label: 'decoded photo over 4 MB: 413', method: 'POST', auth: signedIn, body: JSON.stringify({ mime: 'image/jpeg', image: jpeg + 'A'.repeat(5_592_392) }), status: 413 }, // 4 MB + 2 bytes, request under the cap
  { fn: 'body-check', label: 'valid photo, rate store down: 503', method: 'POST', auth: signedIn, body: JSON.stringify({ mime: 'image/jpeg', image: jpeg }), status: 503 },
);
const killed: Case[] = [
  { fn: 'body-check', label: 'AI_DISABLED: 503 before any model call', method: 'POST', auth: signedIn, body: JSON.stringify({ mime: 'image/jpeg', image: jpeg }), status: 503 },
  { fn: 'coach-chat', label: 'AI_DISABLED: 503', method: 'POST', auth: signedIn, body: JSON.stringify({ message: 'Hi' }), status: 503 },
]; // run last, with the AI_DISABLED secret set

const quiet = { log: console.log, error: console.error };
let failures = 0;
for (const c of [...cases, ...killed]) {
  if (c === killed[0]) Deno.env.set('AI_DISABLED', '1');
  const mod = await import(new URL(`../${c.fn}/index.ts`, import.meta.url).href);
  const headers: Record<string, string> = c.method === 'OPTIONS'
    ? { origin: 'http://localhost:3000', 'access-control-request-method': 'POST' }
    : { 'content-type': 'application/json', ...(c.auth ? { authorization: c.auth } : {}), ...c.headers };
  console.log = () => {};
  console.error = () => {};
  let status = 0, text = '';
  try {
    const res = await mod.default.fetch(new Request(`http://localhost/${c.fn}`, { method: c.method, headers, body: c.body }));
    status = res.status;
    text = await res.text();
  } catch (e) {
    text = `threw: ${e}`;
  } finally {
    console.log = quiet.log;
    console.error = quiet.error;
  }
  const ok = status === c.status && (!c.code || text.includes(c.code)) && (c.fn !== 'delete-account' || c.status !== 500 || text.includes('"deleted":false'));
  if (!ok) failures++;
  console.log(`${ok ? 'PASS' : 'FAIL'}  ${c.fn.padEnd(15)} ${c.label.padEnd(40)} -> ${status}${ok ? '' : `  ${text.slice(0, 120)}`}`);
}
console.log(`${cases.length + killed.length - failures} passed, ${failures} failed`);
if (failures) Deno.exit(1);
