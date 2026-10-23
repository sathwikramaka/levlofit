// Run: node --test supabase/functions/delete-account/delete-account.test.ts
// Contract tests for the delete-account Edge Function, run in node with a fake storage bucket and a fake auth admin.
// Nothing here talks to Supabase. The rule under test: the account is deleted only after the user's photo folder
// is confirmed empty; any storage failure leaves the account in place.
import { test } from 'node:test';
import assert from 'node:assert/strict';
import { register } from 'node:module';
// @ts-ignore: plain JS test double
import { fakeStorage } from '../_test/supabase-server-mock.mjs';

register('../_test/npm-loader.mjs', import.meta.url);

const UID = '00000000-0000-0000-0000-000000000001';
const OTHER = '00000000-0000-0000-0000-000000000002';

function setup(paths: string[], options: Record<string, unknown> = {}, deleteError: unknown = null) {
  const storage = fakeStorage(paths, options);
  const deleted: string[] = [];
  (globalThis as any).__supabaseCtx = {
    userClaims: { id: UID },
    supabase: {},
    supabaseAdmin: {
      storage,
      auth: { admin: { deleteUser: async (id: string) => (deleted.push(id), { data: {}, error: deleteError }) } },
    },
  };
  return { storage, deleted };
}

const fn = (await import('./index.ts')).default.fetch as (req: Request) => Promise<Response>;
const post = () => fn(new Request('http://local/delete-account', { method: 'POST' }));
const photos = (n: number, prefix = UID) => Array.from({ length: n }, (_, i) => `${prefix}/${String(i).padStart(4, '0')}.jpg`);

test('empty folder: the account is deleted (204)', async () => {
  const { deleted } = setup([]);
  const res = await post();
  assert.equal(res.status, 204);
  assert.deepEqual(deleted, [UID]);
});

test('photos and avatar across several pages are all removed before the account is deleted', async () => {
  const { storage, deleted } = setup([...photos(250), `${UID}/avatar`, ...photos(3, OTHER)]);
  const res = await post();
  assert.equal(res.status, 204);
  assert.deepEqual(deleted, [UID]);
  assert.deepEqual([...storage.objects].filter((p: string) => p.startsWith(`${UID}/`)), [], 'the user folder is empty');
  assert.equal([...storage.objects].filter((p: string) => p.startsWith(`${OTHER}/`)).length, 3, 'another user is untouched');
  assert.ok(storage.calls.remove.every((batch: string[]) => batch.length <= 100), 'one page per remove call');
  assert.ok(storage.calls.list.length >= 4, `listed until empty (${storage.calls.list.length} calls)`);
});

test('list failure: the account is not deleted and the error says so', async () => {
  const { storage, deleted } = setup(photos(5), { listError: () => true });
  const res = await post();
  assert.equal(res.status, 500);
  const body = await res.json();
  assert.equal(body.deleted, false);
  assert.match(body.error, /not deleted/);
  assert.deepEqual(deleted, []);
  assert.equal(storage.objects.size, 5, 'nothing removed');
});

test('a list failure after some photos were removed still stops before deleting the account', async () => {
  const { deleted } = setup(photos(150), { listError: (n: number) => n === 2 });
  const res = await post();
  assert.equal(res.status, 500);
  assert.deepEqual(deleted, []);
});

test('remove failure: the account is not deleted', async () => {
  const { storage, deleted } = setup(photos(5), { removeError: true });
  const res = await post();
  assert.equal(res.status, 500);
  assert.match((await res.json()).error, /not deleted/);
  assert.deepEqual(deleted, []);
  assert.equal(storage.objects.size, 5);
});

test('a folder that never empties stops after a bounded number of listings and keeps the account', async () => {
  const { storage, deleted } = setup(photos(5), { stuck: true });
  const res = await post();
  assert.equal(res.status, 500);
  assert.deepEqual(deleted, []);
  assert.ok(storage.calls.list.length <= 200, `bounded (${storage.calls.list.length} list calls)`);
});

test('nested folders (non-file entries) are cleared too before the account is deleted', async () => {
  const { storage, deleted } = setup([`${UID}/a.jpg`, `${UID}/old/b.jpg`, `${UID}/old/2025/c.jpg`]);
  const res = await post();
  assert.equal(res.status, 204);
  assert.deepEqual(deleted, [UID]);
  assert.equal(storage.objects.size, 0);
});

test('nesting deeper than the limit fails safely and keeps the account', async () => {
  const { storage, deleted } = setup([`${UID}/a/b/c/d.jpg`]);
  const res = await post();
  assert.equal(res.status, 500);
  assert.deepEqual(deleted, []);
  assert.equal(storage.objects.size, 1);
});

test('auth deletion failure is reported after the photos are gone', async () => {
  const { storage } = setup(photos(2), {}, { message: 'boom' });
  const res = await post();
  assert.equal(res.status, 500);
  assert.equal((await res.json()).deleted, false);
  assert.equal(storage.objects.size, 0);
});

test('a repeat request after the account is already gone (user not found) reports success', async () => {
  const { deleted } = setup([], {}, { status: 404, code: 'user_not_found', message: 'User not found' });
  const res = await post();
  assert.equal(res.status, 204);
  assert.deepEqual(deleted, [UID]);
});

test('an upload that lands while the account is being deleted is removed by the final sweep', async () => {
  const { storage, deleted } = setup(photos(2));
  (globalThis as any).__supabaseCtx.supabaseAdmin.auth.admin.deleteUser = async (id: string) => {
    deleted.push(id);
    storage.objects.add(`${UID}/late-upload.jpg`); // another device, token still valid
    return { data: {}, error: null };
  };
  const res = await post();
  assert.equal(res.status, 204);
  assert.equal(storage.objects.size, 0);
});

test('a failing final sweep is only logged: the account is already deleted, so the answer stays 204', async () => {
  let lists = 0;
  const { storage } = setup([], { listError: () => ++lists > 1 });
  const logged: string[] = [];
  const realError = console.error;
  console.error = (line: string) => logged.push(line);
  try {
    const res = await post();
    assert.equal(res.status, 204);
  } finally {
    console.error = realError;
  }
  assert.ok(logged.some((l) => l.includes('delete_account_late_sweep')));
  assert.equal(storage.objects.size, 0);
});

test('only POST is accepted', async () => {
  const { deleted } = setup([]);
  const res = await fn(new Request('http://local/delete-account', { method: 'GET' }));
  assert.equal(res.status, 405);
  assert.deepEqual(deleted, []);
});

// ---- robustness: thrown errors, malformed listings, entries without an id, partial removal -------------------

/** Installs a hand-written bucket API ({list, remove}) and returns the ids passed to deleteUser. */
function setupStore(store: { list: (...a: any[]) => Promise<any>; remove: (...a: any[]) => Promise<any> }) {
  const deleted: string[] = [];
  (globalThis as any).__supabaseCtx = {
    userClaims: { id: UID },
    supabase: {},
    supabaseAdmin: { storage: { from: () => store }, auth: { admin: { deleteUser: async (id: string) => (deleted.push(id), { data: {}, error: null }) } } },
  };
  return deleted;
}

test('a thrown list error gives a controlled 500 and keeps the account', async () => {
  const deleted = setupStore({ list: async () => { throw new Error('network down'); }, remove: async () => ({ error: null }) });
  const res = await post();
  assert.equal(res.status, 500);
  const body = await res.json();
  assert.equal(body.deleted, false);
  assert.match(body.error, /not deleted/);
  assert.deepEqual(deleted, []);
});

test('a thrown remove error gives a controlled 500 and keeps the account', async () => {
  const deleted = setupStore({
    list: async () => ({ data: [{ name: 'a.jpg', id: '1' }], error: null }),
    remove: async () => { throw new Error('network down'); },
  });
  const res = await post();
  assert.equal(res.status, 500);
  assert.match((await res.json()).error, /not deleted/);
  assert.deepEqual(deleted, []);
});

test('listing data that is not an array counts as a failed listing and keeps the account', async () => {
  for (const data of [{ items: [] }, 'oops', 42, undefined]) {
    const deleted = setupStore({ list: async () => ({ data, error: null }), remove: async () => ({ error: null }) });
    const res = await post();
    assert.equal(res.status, 500, `data ${JSON.stringify(data)}`);
    assert.match((await res.json()).error, /not deleted/);
    assert.deepEqual(deleted, []);
  }
});

test('a malformed entry inside the listing gives a controlled 500 and keeps the account', async () => {
  const deleted = setupStore({ list: async () => ({ data: [null], error: null }), remove: async () => ({ error: null }) });
  const res = await post();
  assert.equal(res.status, 500);
  assert.deepEqual(deleted, []);
});

test('folder entries with no id field at all are cleared like folders, then the account is deleted', async () => {
  const storage = fakeStorage([`${UID}/a.jpg`, `${UID}/old/b.jpg`, `${UID}/old/c.jpg`]);
  const bucket = storage.from();
  const deleted = setupStore({
    // Same bucket, but folder entries come back without an id property instead of id: null.
    list: async (prefix: string, opts: any) => {
      const r = await bucket.list(prefix, opts);
      return { ...r, data: r.data?.map((e: any) => (e.id === null ? { name: e.name, metadata: null } : e)) };
    },
    remove: bucket.remove,
  });
  const res = await post();
  assert.equal(res.status, 204);
  assert.deepEqual(deleted, [UID]);
  assert.equal(storage.objects.size, 0);
  assert.ok(storage.calls.list.length < 10, `cleared promptly (${storage.calls.list.length} list calls), not by running out the limit`);
});

test('partial removal without an error keeps listing until the folder is empty, then deletes the account', async () => {
  const storage = fakeStorage(photos(5));
  const bucket = storage.from();
  const deleted = setupStore({
    list: bucket.list,
    remove: async (paths: string[]) => bucket.remove(paths.slice(0, 1)), // storage removes only one object per call
  });
  const res = await post();
  assert.equal(res.status, 204);
  assert.deepEqual(deleted, [UID]);
  assert.equal(storage.objects.size, 0);
  assert.equal(storage.calls.list.length, 7, 'five rounds that each remove one photo, one empty listing, then the final sweep after deletion');
});
