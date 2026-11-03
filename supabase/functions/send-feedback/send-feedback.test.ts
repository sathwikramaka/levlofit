// Run: node --test supabase/functions/send-feedback/send-feedback.test.ts
// Contract tests for send-feedback with a fake database and a fake Brevo endpoint. Nothing here talks to Supabase or
// Brevo. The rule under test: the feedback is saved first, then emailed; a failed email never loses the feedback.
import { test } from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { register } from 'node:module';
// @ts-ignore: plain JS test double
import { fakeClient } from '../_test/supabase-server-mock.mjs';

register('../_test/npm-loader.mjs', import.meta.url);

const UID = '00000000-0000-0000-0000-000000000001';
let env: Record<string, string> = {};
(globalThis as any).Deno = { env: { get: (k: string) => env[k] } };

type Mail = { url: string; headers: Record<string, string>; body: any };
function setup(opts: { insertError?: unknown; mail?: number | 'throw'; email?: string | null } = {}) {
  env = { BREVO_API_KEY: 'test-key', FEEDBACK_FROM: 'app@levlofit.test' };
  const ops: any[] = [];
  (globalThis as any).__supabaseCtx = {
    userClaims: { id: UID, email: opts.email === null ? undefined : opts.email ?? 'user@example.test' },
    supabase: fakeClient({ app_feedback: { insertError: opts.insertError } }, ops),
    supabaseAdmin: {},
  };
  const mails: Mail[] = [];
  globalThis.fetch = (async (url: string, init: RequestInit) => {
    mails.push({ url, headers: init.headers as Record<string, string>, body: JSON.parse(String(init.body)) });
    if (opts.mail === 'throw') throw new Error('network down');
    return new Response('{}', { status: opts.mail ?? 201 });
  }) as typeof fetch;
  return { ops, mails };
}

const fn = (await import('./index.ts')).default.fetch as (req: Request) => Promise<Response>;
const post = (body: unknown) => fn(new Request('http://local/send-feedback', { method: 'POST', body: JSON.stringify(body) }));
const saved = (ops: any[]) => ops.filter((o) => o.table === 'app_feedback' && o.op === 'insert').map((o) => o.args);

test('saves the trimmed message as the user, then emails the team with a reply-to', async () => {
  const { ops, mails } = setup();
  const res = await post({ message: '  The timer skips a set.  ' });
  assert.equal(res.status, 200);
  assert.deepEqual(await res.json(), { saved: true, emailed: true });
  assert.deepEqual(saved(ops), [{ message: 'The timer skips a set.' }], 'only the message column; user_id comes from auth.uid()');
  assert.equal(mails.length, 1);
  assert.equal(mails[0].url, 'https://api.brevo.com/v3/smtp/email');
  assert.equal(mails[0].headers['api-key'], 'test-key');
  assert.deepEqual(mails[0].body.to, [{ email: 'levlofit.app@gmail.com' }]);
  assert.deepEqual(mails[0].body.sender.email, 'app@levlofit.test');
  assert.deepEqual(mails[0].body.replyTo, { email: 'user@example.test' });
  assert.match(mails[0].body.textContent, /The timer skips a set\.[\s\S]*User ID: 00000000-0000-0000-0000-000000000001/);
});

test('FEEDBACK_TO overrides the inbox; no account email means no reply-to', async () => {
  const { mails } = setup({ email: null });
  env.FEEDBACK_TO = 'team@levlofit.test';
  assert.equal((await post({ message: 'hello' })).status, 200);
  assert.deepEqual(mails[0].body.to, [{ email: 'team@levlofit.test' }]);
  assert.equal(mails[0].body.replyTo, undefined);
});

for (const [what, mail] of [['Brevo refuses', 401], ['Brevo unreachable', 'throw']] as const) {
  test(`${what}: the feedback is still saved and the reply says it was not emailed`, async () => {
    const { ops } = setup({ mail });
    const res = await post({ message: 'Love the plans' });
    assert.equal(res.status, 200);
    assert.deepEqual(await res.json(), { saved: true, emailed: false });
    assert.equal(saved(ops).length, 1);
  });
}

test('mail secrets missing: saved, not emailed, no request to Brevo', async () => {
  const { ops, mails } = setup();
  env = {};
  assert.deepEqual(await (await post({ message: 'Love the plans' })).json(), { saved: true, emailed: false });
  assert.equal(saved(ops).length, 1);
  assert.equal(mails.length, 0);
});

test('daily limit (trigger P0001): 429 with a clear message, no email', async () => {
  const { mails } = setup({ insertError: { code: 'P0001', message: 'too many feedback messages today' } });
  const res = await post({ message: 'one more' });
  assert.equal(res.status, 429);
  assert.match((await res.json()).error, /5 feedback messages a day/);
  assert.equal(mails.length, 0);
});

test('save fails: 500, no email (nothing claims it was sent)', async () => {
  const { mails } = setup({ insertError: { code: '42501', message: 'permission denied' } });
  const res = await post({ message: 'hello there' });
  assert.equal(res.status, 500);
  assert.equal(mails.length, 0);
});

test('bad input is refused before anything is saved', async () => {
  for (const body of [{}, { message: 'hi' }, { message: 42 }, { message: 'x'.repeat(2001) }]) {
    const { ops, mails } = setup();
    assert.equal((await post(body)).status, 400, JSON.stringify(body).slice(0, 40));
    assert.equal(saved(ops).length + mails.length, 0);
  }
  const { ops } = setup();
  assert.equal((await fn(new Request('http://local/send-feedback', { method: 'GET' }))).status, 405);
  assert.equal(saved(ops).length, 0);
});

test('privacy texts: the website policy and the in-app policy name the feedback email flow', () => {
  const site = readFileSync(new URL('../../../website/src/app/privacy/page.tsx', import.meta.url), 'utf8').replace(/&rsquo;/g, "'").replace(/\s+/g, ' ');
  const app = readFileSync(new URL('../../../app/lib/dashboard_tabs.dart', import.meta.url), 'utf8').replace(/\\'/g, "'").replace(/'\s*\n\s*'/g, '').replace(/\s+/g, ' ');
  for (const [where, text] of [['website privacy page', site], ['in-app policy', app]]) {
    assert.match(text, /Brevo/, `${where}: names Brevo`);
    assert.match(text, /feedback[^.]*emailed[^.]*account email/i, `${where}: feedback is emailed with the account email`);
  }
});
