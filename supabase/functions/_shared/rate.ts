// Per-user rate limits through the check_rate() database function (migrations 20261013100000, 20261027200000,
// 20261102100000). Failure policy (remediation 2026-11-02): every limit fails closed. If the database cannot answer
// (outage, missing function, unknown bucket) the request is refused as 'unavailable' (callers answer 503) and logged,
// so an outage of the rate-limit store can never lift the cap on paid model calls. check_rate also enforces an
// optional app-wide daily cap per bucket (table ai_daily_caps), the spend ceiling across all users: once reached it
// raises 'ai_daily_cap', which lands here as 'unavailable' and is logged as ai_daily_cap_reached.

type Rpc = { rpc: (name: string, args: Record<string, unknown>) => PromiseLike<{ data: unknown; error: { code?: string; message?: string } | null }> };

export type Limit = { bucket: string; limit: number; window: string };

/** Chat: 30 messages an hour and 150 a day per user. Plan rebuilds: 20 a day (feedback: 5 a day, in the database).
 * Kept by the owner on 2026-10-18 as provisional values until real usage data supports revisiting them.
 * The database enforces its own copy of these values (check_rate ignores the limit and window sent here, so a caller
 * cannot reset its limit through the API); a test checks that both lists stay equal. */
export const LIMITS = {
  chatHour: { bucket: 'coach_chat_hour', limit: 30, window: '1 hour' },
  chatDay: { bucket: 'coach_chat_day', limit: 150, window: '1 day' },
  planDay: { bucket: 'generate_plan_day', limit: 20, window: '1 day' },
  bodyCheckDay: { bucket: 'body_check_day', limit: 3, window: '1 day' },
} satisfies Record<string, Limit>;

/** 'ok' to continue, 'limited' when the caller (or the whole app) is over a limit, 'unavailable' when the database
 * could not say. Checks the limits in order and stops at the first that is not 'ok'. */
export async function checkLimits(db: Rpc, limits: Limit[], log: (line: string) => void = console.error): Promise<'ok' | 'limited' | 'unavailable'> {
  for (const l of limits) {
    let reply: Awaited<ReturnType<Rpc['rpc']>>;
    try {
      reply = await db.rpc('check_rate', { p_bucket: l.bucket, p_limit: l.limit, p_window: l.window });
    } catch {
      reply = { data: null, error: { code: 'fetch_failed' } };
    }
    const { data, error } = reply;
    if (error || typeof data !== 'boolean') {
      const event = error?.message?.includes('ai_daily_cap') ? 'ai_daily_cap_reached' : error?.code === 'PGRST202' ? 'rate_limit_unavailable' : 'rate_limit_error';
      log(JSON.stringify({ event, bucket: l.bucket, code: error?.code ?? null }));
      return 'unavailable';
    }
    if (!data) return 'limited';
  }
  return 'ok';
}

/** Required update (2026-11-03): the Android app sends its build number in x-levlofit-build (app/lib/main.dart).
 * With the MIN_APP_BUILD secret set, older builds, including those from before the header (1.0.3 and earlier,
 * which have no update check of their own), get 426 and a message every version shows in place of a reply.
 * Browser calls (the web app, always the newest build) carry an Origin header and are never refused here.
 * Unset or 0 = no check. tools/release_android.sh sets it to each new build once the APK is live. */
export const UPDATE_MESSAGE = 'A new version of Levlofit is out. Download it from levlofit.pages.dev to keep using this.';

const env = (k: string) => (globalThis as { Deno?: { env: { get(k: string): string | undefined } } }).Deno?.env.get(k);

export function outdatedApp(req: Request, minBuild = Number(env('MIN_APP_BUILD') ?? 0)): Response | null {
  if (!(minBuild > 0) || req.headers.get('origin')) return null;
  const build = Number(req.headers.get('x-levlofit-build') ?? 0) || 0;
  return build >= minBuild ? null : Response.json({ error: UPDATE_MESSAGE, updateRequired: true }, { status: 426 });
}

/** The refusal for a check that was not 'ok': 429 with [limitedMessage] when over a limit, 503 when the limits could
 * not be checked or the app-wide daily cap is reached. Never carries database or provider details. */
export function rateRefusal(result: 'limited' | 'unavailable', limitedMessage: string): Response {
  return result === 'limited'
    ? Response.json({ error: limitedMessage }, { status: 429 })
    : Response.json({ error: 'This is not available right now. Try again later.' }, { status: 503 });
}
