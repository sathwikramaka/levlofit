// POST /delete-account
// Deletes the caller's progress photos, then their auth user, then sweeps the photo folder once more for late uploads.
// Every table references auth.users with on delete cascade, so all of the user's data goes with it.
// The account is deleted only after the photo folder is confirmed empty: if storage cannot be listed or cleared,
// the request fails and the account stays, so no files are left behind without an owner. The user can retry.
import { withSupabase } from 'npm:@supabase/server@1.9.1';

const PAGE = 100; // storage list() returns at most this many entries per call (its default limit)
const MAX_LISTS = 200; // total list calls allowed for one deletion, across all folders: the cleanup always ends
const MAX_DEPTH = 3; // the user's folder plus two nested levels; the app itself stores files only at the top level

type Store = {
  list: (path: string, options: { limit: number; offset?: number }) => Promise<{ data: { name: string; id: string | null }[] | null; error: unknown }>;
  remove: (paths: string[]) => Promise<{ error: unknown }>;
};
type Cleanup = 'empty' | 'list_failed' | 'remove_failed' | 'too_deep' | 'too_many' | 'storage_error';

/** Removes every object under [prefix], folders included, until a fresh listing comes back empty. */
async function clearFolder(store: Store, prefix: string, depth: number, budget: { lists: number }): Promise<Cleanup> {
  for (;;) {
    if (budget.lists-- <= 0) return 'too_many';
    // Each round lists from the start: removed objects drop out, so the next page moves up.
    const { data, error } = await store.list(prefix, { limit: PAGE });
    if (error || !Array.isArray(data)) return 'list_failed'; // anything but a list of entries is a failed listing
    if (data.length === 0) return 'empty';
    // Files have an id; folder entries (prefixes that still hold objects) have no id (null, or missing) and are
    // cleared in turn.
    const files = data.filter((e) => e.id != null).map((e) => `${prefix}/${e.name}`);
    const folders = data.filter((e) => e.id == null).map((e) => `${prefix}/${e.name}`);
    if (files.length) {
      const removed = await store.remove(files);
      if (removed.error) return 'remove_failed';
    }
    for (const folder of folders) {
      if (depth + 1 >= MAX_DEPTH) return 'too_deep';
      const nested = await clearFolder(store, folder, depth + 1, budget);
      if (nested !== 'empty') return nested;
    }
  }
}

const NOT_DELETED: Record<Exclude<Cleanup, 'empty'>, string> = {
  list_failed: 'Could not check your photos, so your account was not deleted. Try again.',
  remove_failed: 'Could not delete your photos, so your account was not deleted. Try again.',
  too_deep: 'Could not finish deleting your photos, so your account was not deleted. Contact support.',
  too_many: 'Could not finish deleting your photos, so your account was not deleted. Try again.',
  storage_error: 'Could not reach photo storage, so your account was not deleted. Try again.',
};

export default {
  fetch: withSupabase({ auth: 'user' }, async (req, ctx) => {
    if (req.method !== 'POST') return Response.json({ error: 'Method not allowed' }, { status: 405 });

    const uid = ctx.userClaims!.id;
    // Storage files do not cascade with the user: clear the photo folder first, and stop if that fails.
    const photos = ctx.supabaseAdmin.storage.from('progress-photos') as unknown as Store;
    let cleanup: Cleanup;
    try {
      cleanup = await clearFolder(photos, uid, 0, { lists: MAX_LISTS });
    } catch {
      cleanup = 'storage_error'; // a thrown list/remove or a malformed entry: stop, the account stays
    }
    if (cleanup !== 'empty') {
      console.error(JSON.stringify({ event: 'delete_account_storage', result: cleanup }));
      return Response.json({ error: NOT_DELETED[cleanup], deleted: false }, { status: 500 });
    }

    const { error } = await ctx.supabaseAdmin.auth.admin.deleteUser(uid);
    // Already gone (a repeat request after a successful deletion): that is the outcome the user asked for.
    const gone = error != null && ((error as { status?: number }).status === 404 || (error as { code?: string }).code === 'user_not_found');
    if (error && !gone) return Response.json({ error: 'Could not delete account', deleted: false }, { status: 500 });

    // The access token stays valid until it expires, so an upload from another device can still land after the
    // first sweep. One more best-effort sweep removes it; the account is already deleted either way.
    let late: Cleanup;
    try {
      late = await clearFolder(photos, uid, 0, { lists: 20 });
    } catch {
      late = 'storage_error';
    }
    if (late !== 'empty') console.error(JSON.stringify({ event: 'delete_account_late_sweep', result: late }));

    return new Response(null, { status: 204 });
  }),
};
