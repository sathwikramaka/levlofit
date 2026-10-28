// Per-user rate limits through the check_rate() database function (migration 20261013100000).
// Before that migration is applied the function does not exist: then the limit is skipped and logged, so deploying
// the functions first never locks users out. Any other database error also lets the request through and is logged:
// a rate limit is abuse protection, not an access control. Exception: a limit marked failClosed (body check, a paid
// vision call with a 3-a-day cap) refuses the request on any error, so a missing migration cannot lift its cap.

type Rpc = { rpc: (name: string, args: Record<string, unknown>) => PromiseLike<{ data: unknown; error: { code?: string; message?: string } | null }> };

export type Limit = { bucket: string; limit: number; window: string; failClosed?: boolean };

/** Chat: 30 messages an hour and 150 a day per user. Plan rebuilds: 20 a day (feedback: 5 a day, in the database).
 * Kept by the owner on 2026-10-18 as provisional values until real usage data supports revisiting them.
 * The database enforces its own copy of these values (check_rate ignores the limit and window sent here, so a caller
 * cannot reset its limit through the API); a test checks that both lists stay equal. */
export const LIMITS = {
  chatHour: { bucket: 'coach_chat_hour', limit: 30, window: '1 hour' },
  chatDay: { bucket: 'coach_chat_day', limit: 150, window: '1 day' },
  planDay: { bucket: 'generate_plan_day', limit: 20, window: '1 day' },
  bodyCheckDay: { bucket: 'body_check_day', limit: 3, window: '1 day', failClosed: true },
} satisfies Record<string, Limit>;

/** 'ok' to continue, 'limited' when the caller is over a limit. Checks the limits in order and stops at the first hit. */
export async function checkLimits(db: Rpc, limits: Limit[], log: (line: string) => void = console.error): Promise<'ok' | 'limited'> {
  for (const l of limits) {
    const { data, error } = await db.rpc('check_rate', { p_bucket: l.bucket, p_limit: l.limit, p_window: l.window });
    if (error) {
      log(JSON.stringify({ event: error.code === 'PGRST202' ? 'rate_limit_unavailable' : 'rate_limit_error', bucket: l.bucket, code: error.code ?? null, failClosed: !!l.failClosed }));
      if (l.failClosed) return 'limited';
      continue;
    }
    if (data === false) return 'limited';
  }
  return 'ok';
}
