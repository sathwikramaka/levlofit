// POST /delete-account
// Deletes the caller's progress photos, then their auth user. Every table references auth.users with
// on delete cascade, so all of the user's data goes with it.
import { withSupabase } from 'npm:@supabase/server@^1';

export default {
  fetch: withSupabase({ auth: 'user' }, async (req, ctx) => {
    if (req.method !== 'POST') return Response.json({ error: 'Method not allowed' }, { status: 405 });

    const uid = ctx.userClaims!.id;
    // Storage files do not cascade with the user: remove the progress photos first.
    const photos = ctx.supabaseAdmin.storage.from('progress-photos');
    for (;;) {
      const { data } = await photos.list(uid, { limit: 100 });
      if (!data?.length) break;
      const { error } = await photos.remove(data.map((f) => `${uid}/${f.name}`));
      if (error) return Response.json({ error: 'Could not delete your photos' }, { status: 500 });
    }

    const { error } = await ctx.supabaseAdmin.auth.admin.deleteUser(uid);
    if (error) return Response.json({ error: 'Could not delete account' }, { status: 500 });

    return new Response(null, { status: 204 });
  }),
};
