// Deno runtime smoke test for the Edge Function entry points (coach-chat, generate-plan, delete-account), using the real
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

type Case = { fn: string; label: string; method: string; auth?: string; body?: string; status: number; code?: string };
const cases: Case[] = [];
for (const fn of ['coach-chat', 'generate-plan', 'delete-account']) {
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
  { fn: 'generate-plan', label: 'database unreachable: 500, nothing saved', method: 'POST', auth: `Bearer ${token}`, body: '{}', status: 500 },
  { fn: 'delete-account', label: 'storage unreachable: account kept', method: 'POST', auth: `Bearer ${token}`, body: '{}', status: 500 },
);

const quiet = { log: console.log, error: console.error };
let failures = 0;
for (const c of cases) {
  const mod = await import(new URL(`../${c.fn}/index.ts`, import.meta.url).href);
  const headers: Record<string, string> = c.method === 'OPTIONS'
    ? { origin: 'http://localhost:3000', 'access-control-request-method': 'POST' }
    : { 'content-type': 'application/json', ...(c.auth ? { authorization: c.auth } : {}) };
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
console.log(`${cases.length - failures} passed, ${failures} failed`);
if (failures) Deno.exit(1);
