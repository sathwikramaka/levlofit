// POST /send-feedback  { message }
// In-app feedback: saves the message to app_feedback as the user (so the grant, RLS and the 5-a-day trigger apply),
// then emails it to the Levlofit team through Brevo's transactional email API. The save comes first: if the email
// fails, the feedback is still kept and the reply says { saved: true, emailed: false } so the app can say so.
// Secrets: BREVO_API_KEY (a Brevo API key, not the SMTP key), FEEDBACK_FROM (a sender verified in Brevo),
// FEEDBACK_TO (optional, defaults to the support inbox). Without them the feedback is saved and not emailed.
import { withSupabase } from 'npm:@supabase/server@1.9.1';

const SUPPORT = 'levlofit.app@gmail.com';
const fail = (status: number, error: string) => Response.json({ error }, { status });

async function emailTeam(message: string, uid: string, email: string | undefined): Promise<boolean> {
  const key = Deno.env.get('BREVO_API_KEY');
  const from = Deno.env.get('FEEDBACK_FROM');
  if (!key || !from) {
    console.error(JSON.stringify({ event: 'feedback_mail_config', missing: !key ? 'BREVO_API_KEY' : 'FEEDBACK_FROM' }));
    return false;
  }
  try {
    const res = await fetch('https://api.brevo.com/v3/smtp/email', {
      method: 'POST',
      headers: { 'api-key': key, 'content-type': 'application/json', accept: 'application/json' },
      body: JSON.stringify({
        sender: { email: from, name: 'Levlofit app' },
        to: [{ email: Deno.env.get('FEEDBACK_TO') || SUPPORT }],
        ...(email ? { replyTo: { email } } : {}),
        subject: 'Levlofit in-app feedback',
        textContent: `${message}\n\n--\nFrom: ${email ?? 'no email on the account'}\nUser ID: ${uid}\nSent: ${new Date().toISOString()}`,
      }),
      signal: AbortSignal.timeout(8000),
    });
    if (res.ok) return true;
    console.error(JSON.stringify({ event: 'feedback_mail_failed', status: res.status, uid }));
  } catch (e) {
    console.error(JSON.stringify({ event: 'feedback_mail_failed', error: String(e), uid }));
  }
  return false;
}

export default {
  fetch: withSupabase({ auth: 'user' }, async (req, ctx) => {
    if (req.method !== 'POST') return fail(405, 'Method not allowed');
    let message: unknown;
    try {
      ({ message } = await req.json());
    } catch {
      return fail(400, 'Write your feedback first.');
    }
    if (typeof message !== 'string' || message.trim().length < 3) return fail(400, 'Write a little more.');
    message = message.trim();
    if ((message as string).length > 2000) return fail(400, 'Keep it under 2000 characters.');

    const { error } = await ctx.supabase.from('app_feedback').insert({ message });
    if (error) {
      // P0001 is the limit_app_feedback trigger.
      if ((error as { code?: string }).code === 'P0001') return fail(429, 'You can send 5 feedback messages a day. Try again tomorrow.');
      console.error(JSON.stringify({ event: 'feedback_save_failed', code: (error as { code?: string }).code }));
      return fail(500, 'Could not send your feedback. Try again.');
    }
    const claims = ctx.userClaims!;
    return Response.json({ saved: true, emailed: await emailTeam(message as string, claims.id, claims.email) });
  }),
};
